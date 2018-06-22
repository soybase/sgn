package SGN::Controller::HaplotypeVis::Database;

use Moose;
use Data::Dumper;
use Bio::Chado::Schema;


BEGIN {extends 'Catalyst::Controller::REST'}

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub post_markers : Path('/ajax/haplotype_vis/markers') Args(0) {

    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $dbh = $c->dbc->dbh();
    my $marker_name = $c->request->param('marker_alias_fragment');
    my @accession_list = @{$c->request->data->{"accession_list"}};
    my ($marker_alias, @marker_alias_array);

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

    print STDERR Dumper (@marker_alias_array);
    $c->stash->{rest} = { marker_alias_array => \@marker_alias_array};
}

1;
