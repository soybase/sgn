#!/usr/bin/perl

=head1

phenotype_upload.pl 

=head1 SYNOPSIS

    phenotype_upload.pl  -i [stored inputs file]

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
 -i input file

=head1 DESCRIPTION


=head1 AUTHOR

 Nicolas Morales (nm529@cornell.edu)

=cut

use strict;

use Getopt::Std;
use Data::Dumper;
use Carp qw /croak/ ;
use Pod::Usage;
use CXGN::Phenotypes::StorePhenotypes;
use Storable qw | nstore retrieve freeze thaw |;
$Storable::Eval = 1;
$Storable::forgive_me = 1;

our ($opt_i);

getopts('i:');

if (!$opt_i) {
    die "Must provide options -i (input)\n";
}

my $input_hash = thaw($opt_i);

my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
    bcs_schema=>$input_hash->{bcs_schema},
    metadata_schema=>$input_hash->{metadata_schema},
    phenome_schema=>$input_hash->{phenome_schema},
    user_id=>$input_hash->{user_id},
    stock_list=>$input_hash->{stock_list},
    trait_list=>$input_hash->{trait_list},
    values_hash=>$input_hash->{values_hash},
    has_timestamps=>$input_hash->{has_timestamps},
    overwrite_values=>$input_hash->{overwrite_values},
    metadata_hash=>$input_hash->{metadata_hash},
    image_zipfile_path=>$input_hash->{image_zipfile_path}
);
my ($verified_warning, $verified_error) = $store_phenotypes->verify();

return ($verified_warning, $verified_error);
