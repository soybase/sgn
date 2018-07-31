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
use JSON;
use SGN::Model::Cvterm;


BEGIN {extends 'Catalyst::Controller::REST'}

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

# Retrieve Accessions Module:
# Gets accessions from population id,
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

# Retrieve Protocols Module:
# Gets protocols retrieved from database
# using accession_list
sub retrieve_protocols : Path('/ajax/haplotype_vis/protocols') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $dbh = $c->dbc->dbh();

    my @accession_list = @{$c->request->data->{"accession_list"}};
    my ($protocol_name, $protocol_id, @protocol_array, @protocol_id_array);

    my $protocols = CXGN::Genotype::Protocol::list(
        $schema,
        undef,
        \@accession_list
    );
    foreach (@$protocols){
        push @protocol_array, $_->{protocol_name};
        push @protocol_id_array, $_->{protocol_id};
    }

    $c->stash->{rest} = { protocol_array => \@protocol_array, protocol_id_array => \@protocol_id_array};
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
    my $protocol = $c->request->data->{"protocol"};

    my $protocols = CXGN::Genotype::Protocol::list(
        $schema,
        [$protocol],
        \@accession_list
    );
    my $selected_protocol = $protocols->[0];
    my @marker_alias_array = @{$selected_protocol->{marker_names}};

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

    my @accession_list = @{$c->request->data->{"accession_list"}};
    my $protocol = $c->request->data->{"protocol"};
    my ($markers, @marker_values);

    my $genotype_search = CXGN::Genotype::Search->new({
        bcs_schema => $schema,
        accession_list => \@accession_list,
        protocol_id_list => [$protocol]
    });
    my ($total_count, $results) = $genotype_search->get_genotype_info();

    my %marker_results;
    foreach (@$results){
        my $accession_id = $_->{germplasmDbId};
        my $genotype_results = $_->{full_genotype_hash};
        while (my($marker_name, $value) = each %$genotype_results){
            # push @{$marker_results{$accession_id}}, {$marker_name => $value};
            $marker_results{$accession_id}{$marker_name} =  $value;

        }
    }

    print STDERR Dumper \%marker_results;
    $c->stash->{rest} = { marker_values => \%marker_results};
}

1;
