package SGN::Controller::AJAX::Async;

use Moose;
use Data::Dumper;
use Try::Tiny;
use CXGN::Async;

BEGIN { extends 'Catalyst::Controller::REST'; };

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub check : Path('/async/check') Args(2) { 
    my $self = shift;
    my $c = shift;
    my $job_type = shift;
    my $job_id = shift;
    my $job = CXGN::Async->new({
        job_type=>$job_type,
        cluster_shared_tempdir=>$c->config->{cluster_shared_tempdir},
        tempfiles_subdir=>$c->tempfiles_subdir('phenotype_upload_verify'),
        basepath=>$c->config->{basepath}
    });
    my $status = $job->get_status($job_id);
    if ($status ne 'Running' && $status ne 'Complete'){
        $c->stash->{rest} = { error => 'Job status unknown!' };
        $c->detach();
    }
    $c->stash->{rest} = { status => $status};
}

sub result : Path('/async/result') Args(2) { 
    my $self = shift;
    my $c = shift;
    my $job_type = shift;
    my $job_id = shift;
    my $job = CXGN::Async->new({
        job_type=>$job_type,
        cluster_shared_tempdir=>$c->config->{cluster_shared_tempdir},
        tempfiles_subdir=>$c->tempfiles_subdir('phenotype_upload_verify'),
        basepath=>$c->config->{basepath}
    });
    my $lines = $job->get_result($job_id);
    if (scalar(@$lines) > 0){
        $c->stash->{rest} = {success => 1, result => $lines};
    } else {
        $c->stash->{rest} = {error => 1};
    }
}

1;
