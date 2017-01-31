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
#use Storable qw | nstore retrieve freeze thaw |;
use JSON;
use Bio::Chado::Schema;
use CXGN::Metadata::Schema;
use CXGN::Phenome::Schema;

our ($opt_i, $opt_D, $opt_U, $opt_p);

getopts('i:D:U:p:');

if (!$opt_i || !$opt_D || !$opt_U || !$opt_p) {
    die "Must provide options -i (input) -D (database name) -U (db user) -p (dbpass) \n";
}

my $bcs_schema = Bio::Chado::Schema->connect(
    "dbi:Pg:database=$opt_D", # DSN Line
    $opt_U,                    # Username
    $opt_p           # Password
);
my $metadata_schema = CXGN::Metadata::Schema->connect(
    "dbi:Pg:database=$opt_D", # DSN Line
    $opt_U,                    # Username
    $opt_p           # Password
);
my $phenome_schema = CXGN::Phenome::Schema->connect(
    "dbi:Pg:database=$opt_D", # DSN Line
    $opt_U,                    # Username
    $opt_p           # Password
);

my $input_hash = decode_json($opt_i);

my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
    bcs_schema=>$bcs_schema,
    metadata_schema=>$metadata_schema,
    phenome_schema=>$phenome_schema,
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

print STDOUT $verified_warning."\n";
print STDOUT $verified_error."\n";
