=pod

=head1 NAME

lib/SGN/AJAX/HaplotypeVis/Webpage.pm

=head1 DESCRIPTION

A component for displaying haplotypes alongside pedigree for accessions

=head1 AUTHOR

Thomas Chan <nm249@cornell.edu>

=cut

package SGN::Controller::HaplotypeVis;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }
use URI::FromHash 'uri';

# Controller module for website
sub haplotype_vis_input :Path('/haplotype_visualizer') Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->user) {
	$c->res->redirect(uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
	return;
    }
    $c->stash->{template} = '/haplotype_vis.mas';
}

1;
