package CXGN::Async;

=head1 NAME

CXGN::Async - an object to handle running a job asynchronously

=head1 USAGE

my $job = CXGN::Async->new({
    job_type=>type1,
    inputs=>$input_hash,
    cluster_shared_tempdir=>$c->config->{cluster_shared_tempdir},
    basepath=>$c->config->{basepath}
});
my $job_id = $job->run_job();
my $status = $job->status($job_id);

=head1 DESCRIPTION


=head1 AUTHORS

 Nicolas Morales <nm529@cornell.edu>

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;
use Storable qw | nstore retrieve |;
use File::Temp qw | tempfile |;
use File::Basename qw | basename |;
use File::Copy qw | copy |;
use File::Spec qw | catfile |;
use File::Slurp qw | read_file write_file |;
use File::NFSLock qw | uncache |;
use CXGN::Tools::Run;

has 'job_type' => ( isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'inputs' => ( isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'cluster_shared_tempdir' => ( isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'basepath' => ( isa => 'Str',
    is => 'rw',
    required => 1,
);

sub BUILD {
    my $self = shift;
    my $job_type = $self->job_type();
    if ($job_type ne 'blast' && $job_type ne 'phenotype_upload_verify'){
        die "job_type must be blast or phenotype_upload_verify\n";
    }
}

sub run_job {
    my $self = shift;
    my $job_type = $self->job_type();

    my $tmp_output = $self->cluster_shared_tempdir()."/$job_type";
    mkdir $tmp_output if ! -d $tmp_output;
    
    my ($fh, $file) = tempfile( 
      $job_type."_XXXXXX",
      DIR=> $tmp_output,
    );

    my $job_id = basename($file);
    my @command = ('perl');
    if ($job_type eq 'phenotype_upload_verify'){
        push @command, $self->basepath().'/bin/async/phenotype_upload_verify.pl';
        push @command, '-i';
        push @command, $self->inputs();
    }

    my $job;
    eval {
        $job = CXGN::Tools::Run->run_cluster(
            @command,
            {
                temp_base => $tmp_output,
                #queue => $c->config->{'web_cluster_queue'},
                #working_dir => $tmp_output,

                # temp_base => $c->config->{'cluster_shared_tempdir'},
                # queue => $c->config->{'web_cluster_queue'},
                # working_dir => $c->config->{'cluster_shared_tempdir'},

                # don't block and wait if the cluster looks full
                max_cluster_jobs => 1_000_000_000,
                backend => 'slurm'
            }
        );

        print STDERR "Saving job state to $file.job for id ".$job->job_id()."\n";

        $job->do_not_cleanup(1);
        nstore( $job, $file.".job" ) or die 'could not serialize job object';
    };

    if ($@) {
        die "An error occurred! $@\n";
    }
    return $job_id;
}

sub status {
    my $self = shift;
    my $job_id = shift;
    my $job_type = $self->job_type();

    my $tmp_output = $self->cluster_shared_tempdir()."/$job_type";
    my $job = retrieve($tmp_output."/".$job_id.".job");

    if ( $job->alive ){
        return "Running";
    } else {
        return "Complete";
    }
}

1;
