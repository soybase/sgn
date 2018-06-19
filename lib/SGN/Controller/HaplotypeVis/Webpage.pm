package SGN::Controller::HaplotypeVis::Webpage;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }
use URI::FromHash 'uri';

sub haplotype_vis_input :Path('/haplotype_visualizer') Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->user) {
	$c->res->redirect(uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
	return;
    }
    $c->stash->{template} = '/haplotype_vis/index.mas';
}

1;
