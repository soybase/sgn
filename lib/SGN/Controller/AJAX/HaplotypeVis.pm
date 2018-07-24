=pod

=head1 NAME

lib/SGN/AJAX/HaplotypeVis/Database.pm

=head1 DESCRIPTION

A component for displaying haplotypes alongside pedigree for accessions

=head1 AUTHOR

Thomas Chan <nm249@cornell.edu>

=cut

package SGN::Controller::AJAX::HaplotypeVis;

use Moose;
use Bio::Chado::Schema;
use Data::Dumper;
use SGN::Model::Cvterm;


BEGIN {extends 'Catalyst::Controller::REST'}

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

# Retrieve Accessions Module:
# Gets accessions from population id
# retrieved from database using population name
sub retrieve_population_id : Path('/ajax/haplotype_vis/population_id') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $dbh = $c->dbc->dbh();
    my $population_name = $c->request->data->{"population"};
    my ($population_id, @accession_id_list);
    my $population_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'population', 'stock_type')->cvterm_id();
    my $query = $dbh->prepare("select stock_id from stock where uniquename = ? and type_id = ?");
    $query->execute($population_name, $population_cvterm_id);
    $population_id = $query->fetchrow_array();

    $c->stash->{rest} = { population_id => $population_id};
}

# Retrieve Markers Module:
# Gets markers from database using accession list
# and marker fragment
sub retrieve_markers : Path('/ajax/haplotype_vis/markers') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $dbh = $c->dbc->dbh();

    my $marker_fragment = $c->request->data->{"marker_alias_fragment"};
    $marker_fragment =~ s/(^\s+|\s+)$//g;
    $marker_fragment =~ s/\s+/ /g;
    my @accession_list = @{$c->request->data->{"accession_list"}};

    my ($marker_alias, @marker_alias_array);

    # Constructing PostgreSQL query for markers present in every accession
    my $query_start = "select marker_name
                        from (
                            select distinct uniquename as accession_name, jsonb_object_keys(value) as marker_name
                            from stock
                            join nd_experiment_stock
                            using (stock_id)
                            join nd_experiment_genotype
                            using (nd_experiment_id)
                            join genotypeprop
                            using (genotype_id)
                            where stock_id in (".'?';
    for (my $i = 1; $i < scalar @accession_list; $i++) {
        $query_start .= ",".'?';
    }
    $query_start .= ")) as data
                    group by marker_name
                    having count(marker_name) = ".scalar @accession_list."
                    order by marker_name;";

    my $query = $dbh->prepare($query_start);
    $query->execute(@accession_list);

    while (my ($marker_alias) = $query->fetchrow_array()) {
        push @marker_alias_array, $marker_alias;
    }

    # Searching from markers in every accession using marker alias fragment
    my @matches = grep { /^$marker_fragment/i } @marker_alias_array;

    $c->stash->{rest} = { matches => \@matches};
}

# Retrieve Markers Values Module:
# Gets marker values from database using accession list
# and marker list
sub retrieve_marker_values : Path('/ajax/haplotype_vis/marker_values') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $dbh = $c->dbc->dbh();

    my @marker_list = @{$c->request->data->{"marker_list"}};
    my @accession_list = @{$c->request->data->{"accession_list"}};
    my ($stock_id, @stock_ids, $markers, @marker_values);

    # Constructing PostgreSQL query for marker values of given markers for each accession
    my $query_start = "select stock_id, jsonb_object_agg(data.key, data.value) as markers
                        from stock
                        join nd_experiment_stock
                        using (stock_id)
                        join nd_experiment_genotype
                        using (nd_experiment_id)
                        join genotypeprop
                        using (genotype_id)
                        join jsonb_each(value) data on true
                        where data.key in (".'?';
    for (my $i = 1; $i < scalar @marker_list; $i++) {
        $query_start .= ",".'?';
    }
    $query_start .= ")
                    and stock_id in (".'?';
    for (my $i = 1; $i < scalar @accession_list; $i++) {
        $query_start .= ",".'?';
    }
    $query_start .= ")
                    group by stock_id
                    order by stock_id;";

    my $query = $dbh->prepare($query_start);
    $query->execute(@marker_list, @accession_list);

    while (my ($stock_id, $markers) = $query->fetchrow_array()) {
        push @stock_ids, $stock_id;
        push @marker_values, $markers;
    }

    $c->stash->{rest} = { stock_ids => \@stock_ids, marker_values => \@marker_values};
}

1;