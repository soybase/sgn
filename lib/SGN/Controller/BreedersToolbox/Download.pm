#!/usr/bin/perl

package SGN::Controller::BreedersToolbox::Download;

use strict;
use warnings;
use JSON qw( decode_json );
use Data::Dumper;
use CGI;
use File::Slurp qw | read_file |;


use Moose;

BEGIN { extends 'Catalyst::Controller'; }

use URI::FromHash 'uri';
use CXGN::List::Transform;
 
sub breeder_download : Path('/breeders/download/') Args(0) { 
    my $self = shift;
    my $c = shift;

    if (!$c->user()) { 	
	# redirect to login page
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) ); 
	return;
    }
    
    $c->stash->{template} = '/breeders_toolbox/download.mas';
}

sub download_action : Path('/breeders/download_action') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $accession_list_id = $c->req->param("accession_list_list_select");
    my $trial_list_id     = $c->req->param("trial_list_list_select");
    my $trait_list_id     = $c->req->param("trait_list_list_select");
    my $data_type         = $c->req->param("data_type")|| "phenotype";

   # my $data_type         = $c->req->param("data_type") || "genotype";

    #my $data_type         = "phenotype" || "genotype";

    #my $data_type         = "phenotype" || "genotype";


    my $format            = $c->req->param("format");


    print STDERR "IDS: $accession_list_id, $trial_list_id, $trait_list_id\n";

    my $accession_data = [];
    if ($accession_list_id) { $accession_data = SGN::Controller::AJAX::List->retrieve_list($c, $accession_list_id); }
    my $trial_data = [];
    if ($trial_list_id) { $trial_data = SGN::Controller::AJAX::List->retrieve_list($c, $trial_list_id); } 
    
    my $trait_data = [];
    if ($trait_list_id) { $trait_data = SGN::Controller::AJAX::List->retrieve_list($c, $trait_list_id); } 

    print STDERR Dumper($accession_data);
    print STDERR Dumper($trial_data);
    print STDERR Dumper($trait_data);
    

    my @accession_list = map { $_->[1] } @$accession_data;
    my @trial_list = map { $_->[1] } @$trial_data;
    my @trait_list = map { $_->[1] } @$trait_data;

        my $tf = CXGN::List::Transform->new();
    my $unique_transform = $tf->can_transform("accession_synonyms", "accession_names");
    
    my $unique_list = $tf->transform($c->dbic_schema("Bio::Chado::Schema"), $unique_transform, \@accession_list);
    
    my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh() });

    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $t = CXGN::List::Transform->new();
    
    print STDERR Data::Dumper::Dumper(\@accession_list);
    print STDERR Data::Dumper::Dumper(\@trial_list);
    print STDERR Data::Dumper::Dumper(\@trait_list);

    my $acc_t = $t->can_transform("accessions", "accession_ids");
    my $accession_id_data = $t->transform($schema, $acc_t, $unique_list->{transform});

    my $trial_t = $t->can_transform("trials", "trial_ids");
    my $trial_id_data = $t->transform($schema, $trial_t, \@trial_list);
    
    my $trait_t = $t->can_transform("traits", "trait_ids");
    my $trait_id_data = $t->transform($schema, $trait_t, \@trait_list);

    print STDERR Dumper($accession_id_data);
    print STDERR Dumper($trial_id_data);
    print STDERR Dumper($trait_id_data);

    my $accession_sql = join ",", map { "\'$_\'" } @{$accession_id_data->{transform}};
    my $trial_sql = join ",", map { "\'$_\'" } @{$trial_id_data->{transform}};
    my $trait_sql = join ",", map { "\'$_\'" } @{$trait_id_data->{transform}};

    print STDERR "SQL-READY: $accession_sql | $trial_sql | $trait_sql \n";

    my $data; 
    my $output = "";
    
    #if($data_type eq ""){

    # print STDERR "Please define data type \n";

    # print "Please define data type \n";
    #
    #}


    if ($data_type eq "phenotype") { 
	$data = $bs->get_phenotype_info($accession_sql, $trial_sql, $trait_sql);
	
	$output = "";
	foreach my $d (@$data) { 
	    $output .= join ",", @$d;
	    $output .= "\n";
	}
    }

    if ($data_type eq "genotype") { 
		

        print STDERR "Download genotype data\n";

	$data = $bs->get_genotype_info($accession_sql, $trial_sql);
	
	$output = "";
	foreach my $d (@$data) { 
	    $output .= join "\t", @$d;
	    $output .= "\n";
	}


    }
    $c->res->content_type("text/plain");
   $c->res->body($output);

}

#=pod
sub download_gbs_action : Path('/breeders/download_gbs_action') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $accession_list_id = $c->req->param("genotype_accession_list_list_select");
    my $trial_list_id     = $c->req->param("genotype_trial_list_list_select");
  #  my $trait_list_id     = $c->req->param("trait_list_list_select");
    my $data_type         = $c->req->param("data_type") || "genotype";
    my $format            = $c->req->param("format");


    print STDERR "IDS: $accession_list_id, $trial_list_id \n";

    my $accession_data = SGN::Controller::AJAX::List->retrieve_list($c, $accession_list_id);
    my $trial_data = SGN::Controller::AJAX::List->retrieve_list($c, $trial_list_id);
   # my $trait_data = SGN::Controller::AJAX::List->retrieve_list($c, $trait_list_id);

    my @accession_list = map { $_->[1] } @$accession_data;
    my @trial_list = map { $_->[1] } @$trial_data;
   # my @trait_list = map { $_->[1] } @$trait_data;

    my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh() });

    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $t = CXGN::List::Transform->new();
    
#    print STDERR Data::Dumper::Dumper(\@accession_list);
#    print STDERR Data::Dumper::Dumper(\@trial_list);
#    print STDERR Data::Dumper::Dumper(\@trait_list);

    my $acc_t = $t->can_transform("accessions", "accession_ids");
    my $accession_id_data = $t->transform($schema, $acc_t, \@accession_list);

    my $trial_t = $t->can_transform("trials", "trial_ids");
    my $trial_id_data = $t->transform($schema, $trial_t, \@trial_list);
    
    #my $trait_t = $t->can_transform("traits", "trait_ids");
    #my $trait_id_data = $t->transform($schema, $trait_t, \@trait_list);

    my $accession_sql = join ",", map { "\'$_\'" } @{$accession_id_data->{transform}};
    my $trial_sql = join ",", map { "\'$_\'" } @{$trial_id_data->{transform}};
    #my $trait_sql = join ",", map { "\'$_\'" } @{$trait_id_data->{transform}};

    print STDERR "SQL-READY: $accession_sql | $trial_sql \n";

    my $data; 
    my $output = "";


    my $fh000="out_test000.txt";

    my ($tempfile, $uri) = $c->tempfile( { TEMPLATE => "download_XXXXX.txt", UNLINK=> 0 } );

        #$fh000 = File::Spec->catfile($c->config->{gbs_temp_data}, $fh000);
    open my $TEMP, '>', $tempfile or die "Cannot open output_test00.txt: $!";




    #$fh000 = File::Spec->catfile($c->config->{gbs_temp_data}, $fh000);
    $tempfile = File::Spec->catfile($c->config->{gbs_temp_data}, $tempfile);


    if ($data_type eq "genotype") { 
		
        print "Download genotype data\n";

	$data = $bs->get_genotype_info($accession_sql, $trial_sql);        
	$output = "";

#	say "Your list has ", scalar(@$x), " elements" 

       print STDERR "your list has ", scalar(@$data)," element \n";
      
       #my @myGBS = ();
       
     
       my @AoH = ();

     for (my $i=0; $i < scalar(@$data) ; $i++) 
#      for my $i ( 0 .. $#data )
     {
      my $decoded = decode_json($data->[$i][1]);
      push(@AoH, $decoded); 
      #print "$i\n";
     }
      # push(@myGBS, 'Moe'); 

	print STDERR "your array has ", scalar(@AoH)," element \n";
	


        my @k=();
	for my $i ( 0 .. $#AoH ){
	   @k = keys   %{ $AoH[$i] }
	}

	


        print STDERR "Output file is ", $fh000,"\n";
	
   #     open my $fh00, '>', "output_test00.txt" or die "Cannot open output_test00.txt: $!";

        open my $fh00, '>', $fh000 or die "Cannot open output_test00.txt: $!";

        for my $j (0 .. $#k){

	    #print $fh00 "$k[$j]\t";
 print $TEMP "$k[$j]\t";

	    for my $i ( 0 .. $#AoH ) {
             
            if($i == $#AoH ){  
            #print $fh00 "$AoH[$i]{$k[$j]}";
print $TEMP "$AoH[$i]{$k[$j]}";

            }else{
	    #print $fh00 "$AoH[$i]{$k[$j]}\t";
 print $TEMP "$AoH[$i]{$k[$j]}\t";
	    }
             
            }

           # print $fh00 "\n";
 print $TEMP "\n";

	}

    }


    
   # my $contents = read_file("output_test00.txt");

    # print STDERR "Output file is ", $fh00,"\n";
    # print STDERR "Output file is ", $fh000,"\n";


     my $contents = read_file($tempfile);


    $c->res->content_type("text/plain");

    $c->res->body($contents);

#   system("rm output_test*.txt");
#  system("rm qc_output.txt");

}
#=pod

#=cut
sub gbs_qc_action : Path('/breeders/gbs_qc_action') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $accession_list_id = $c->req->param("genotype_accession_list_list_select");
    my $trial_list_id     = $c->req->param("genotype_trial_list_list_select");
  #  my $trait_list_id     = $c->req->param("trait_list_list_select");
    my $data_type         = $c->req->param("data_type") || "genotype";
    my $format            = $c->req->param("format");


    print STDERR "IDS: $accession_list_id, $trial_list_id \n";

    my $accession_data = SGN::Controller::AJAX::List->retrieve_list($c, $accession_list_id);
    my $trial_data = SGN::Controller::AJAX::List->retrieve_list($c, $trial_list_id);
   # my $trait_data = SGN::Controller::AJAX::List->retrieve_list($c, $trait_list_id);

    my @accession_list = map { $_->[1] } @$accession_data;
    my @trial_list = map { $_->[1] } @$trial_data;
   # my @trait_list = map { $_->[1] } @$trait_data;

    my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh() });

    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $t = CXGN::List::Transform->new();
    
#    print STDERR Data::Dumper::Dumper(\@accession_list);
#    print STDERR Data::Dumper::Dumper(\@trial_list);
#    print STDERR Data::Dumper::Dumper(\@trait_list);

    my $acc_t = $t->can_transform("accessions", "accession_ids");
    my $accession_id_data = $t->transform($schema, $acc_t, \@accession_list);

    my $trial_t = $t->can_transform("trials", "trial_ids");
    my $trial_id_data = $t->transform($schema, $trial_t, \@trial_list);
    
    #my $trait_t = $t->can_transform("traits", "trait_ids");
    #my $trait_id_data = $t->transform($schema, $trait_t, \@trait_list);

    my $accession_sql = join ",", map { "\'$_\'" } @{$accession_id_data->{transform}};
    my $trial_sql = join ",", map { "\'$_\'" } @{$trial_id_data->{transform}};
    #my $trait_sql = join ",", map { "\'$_\'" } @{$trait_id_data->{transform}};

    print STDERR "SQL-READY: $accession_sql | $trial_sql \n";

    my $data; 
    my $output = "";

    if ($data_type eq "genotype") { 
		
        print "Download genotype data\n";

	$data = $bs->get_genotype_info($accession_sql, $trial_sql);        
	$output = "";

#	say "Your list has ", scalar(@$x), " elements" 

       print STDERR "your list has ", scalar(@$data)," element \n";
      
       #my @myGBS = ();
       
     
       my @AoH = ();

     for (my $i=0; $i < scalar(@$data) ; $i++) 
#      for my $i ( 0 .. $#data )
     {
      my $decoded = decode_json($data->[$i][1]);
      push(@AoH, $decoded); 
      #print "$i\n";
     }
      # push(@myGBS, 'Moe'); 

	print STDERR "your array has ", scalar(@AoH)," element \n";
	
	my $fh000="out_test000.txt";

	$fh000 = File::Spec->catfile($c->config->{gbs_temp_data}, $fh000);


        print STDERR "Output file is ", $fh000,"\n";
	
   #     open my $fh00, '>', "output_test00.txt" or die "Cannot open output_test00.txt: $!";

        open my $fh00, '>', $fh000 or die "Cannot open output_test00.txt: $!";


        my @k=();
	for my $i ( 0 .. $#AoH ){
	   @k = keys   %{ $AoH[$i] }
	}

#        open my $fh00, '>', "output_test00.txt" or die "Cannot open output_test00.txt: $!";

        for my $j (0 .. $#k){

	    print $fh00 "$k[$j]\t";
	    for my $i ( 0 .. $#AoH ) {
             
            if($i == $#AoH ){  
            print $fh00 "$AoH[$i]{$k[$j]}";
            }else{
	    print $fh00 "$AoH[$i]{$k[$j]}\t";
	    }
             
            }

            print $fh00 "\n";

	}
    }

    #system("R --slave --args output_test00.txt qc_output.txt < /home/aiminy/code/code_R/GBS_QC.R"); ok
    #system("R --slave --args output_test00.txt qc_output.txt < ./R/GBS_QC.R"); ok
     system("R --slave --args /data/prod/public/out_test000.txt /data/prod/public/qc_output.txt < R/GBS_QC.R");
    #system("R --slave --args output_test00.txt qc_output.txt < /R/GBS_QC.R"); path is not ok


    my $contents = read_file("/data/prod/public/qc_output.txt");

    $c->res->content_type("text/plain");

    $c->res->body($contents);

   system("rm output_test*.txt");
   system("rm qc_output.txt");

}
#=pod
1;
