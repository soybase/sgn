package SGN::Controller::solGS::TraininingPop;

use Moose;
use namespace::autoclean;

use String::CRC;
use URI::FromHash 'uri';
use File::Path qw / mkpath  /;
use File::Spec::Functions qw / catfile catdir/;
use File::Temp qw / tempfile tempdir /;
use File::Slurp qw /write_file read_file :edit prepend_file append_file/;
use File::Copy;
use File::Basename;
use Cache::File;
use Try::Tiny;
use List::MoreUtils qw /uniq/;
use Scalar::Util qw /weaken reftype/;
use Statistics::Descriptive;
use Math::Round::Var;
use Algorithm::Combinatorics qw /combinations/;
use Array::Utils qw(:all);
use CXGN::Tools::Run;
use JSON;
use Storable qw/ nstore retrieve /;
use Carp qw/ carp confess croak /;

BEGIN { extends 'Catalyst::Controller' }



sub population : Regex('^solgs/population/([\w|\d]+)(?:/([\w+]+))?') {
    my ($self, $c) = @_;
  
    my ($pop_id, $action) = @{$c->req->captures};
   
    my $list_reference = $c->req->param('list_reference');
    $c->stash->{list_reference} = $list_reference;

    if ($list_reference) 
    {
        $pop_id = $c->req->param('model_id');

        $c->stash->{model_id}   = $c->req->param('model_id'),
        $c->stash->{list_name} = $c->req->param('list_name'),
    }

    if ($pop_id )
    {   
        if($pop_id =~ /list/) 
        {
            $c->stash->{list_reference} = 1;
            $list_reference = 1;
        }

        $c->stash->{pop_id} = $pop_id; 
       
        $c->controller('solGS::solGS')->phenotype_file($c); 
        $c->controller('solGS::solGS')->genotype_file($c); 
        $c->controller('solGS::solGS')->get_all_traits($c);  
        $c->controller('solGS::solGS')->project_description($c, $pop_id);
 
        $c->stash->{template} = $c->controller('solGS::Files')->template('/population.mas');
      
        if ($action && $action =~ /selecttraits/ ) {
            $c->stash->{no_traits_selected} = 'none';
        }
        else {
            $c->stash->{no_traits_selected} = 'some';
        }

        my $acronym = $c->controller('solGS::solGS')->get_acronym_pairs($c);
        $c->stash->{acronym} = $acronym;
    }
 
    my $pheno_data_file = $c->stash->{phenotype_file};
    
    if ($list_reference) 
    {
	my $ret->{status} = 'failed';
	if ( !-s $pheno_data_file )
	{
	    $ret->{status} = 'failed';
            
	    $ret = to_json($ret);
                
	    $c->res->content_type('application/json');
	    $c->res->body($ret); 
	}
    }
} 


sub check_genotype_data_population :Path('/solgs/check/genotype/data/population/') Args(1) {
    my ($self, $c, $pop_id) = @_;

    $c->stash->{pop_id} = $pop_id;
    $self->check_population_has_genotype($c);
       
    my $ret->{has_genotype} = $c->stash->{population_has_genotype};
    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}


sub check_phenotype_data_population :Path('/solgs/check/phenotype/data/population/') Args(1) {
    my ($self, $c, $pop_id) = @_;

    $c->stash->{pop_id} = $pop_id;
    $self->check_population_has_phenotype($c);
       
    my $ret->{has_phenotype} = $c->stash->{population_has_phenotype};
    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}


sub check_population_exists :Path('/solgs/check/population/exists/') Args(0) {
    my ($self, $c) = @_;
    
    my $name = $c->req->param('name');

    my $rs = $c->model("solGS::solGS")->project_details_by_name($name);

    my $pop_id;
    while (my $row = $rs->next) {  
        $pop_id =  $row->id;
    }
  
    my $ret->{population_id} = $pop_id;    
    $ret = to_json($ret);     
   
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}


sub check_training_population :Path('/solgs/check/training/population/') Args(1) {
    my ($self, $c, $pop_id) = @_;

    $c->stash->{pop_id} = $pop_id;

    $self->check_population_is_training_population($c);
    my $is_training_pop = $c->stash->{is_training_population};

    my $training_pop_data;
    if ($is_training_pop) 
    {
	my $pr_rs = $c->model('solGS::solGS')->project_details($pop_id);
	$self->projects_links($c, $pr_rs);
	$training_pop_data = $c->stash->{projects_pages};
    }
   
    my $ret->{is_training_population} =  $is_training_pop; 
    $ret->{training_pop_data} = $training_pop_data; 
    $ret = to_json($ret);     
   
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}


sub check_training_pop_size : Path('/solgs/check/training/pop/size') Args(0) {
    my ($self, $c) = @_;

    my $pop_id = $c->req->param('training_pop_id');
    my $type   = $c->req->param('data_set_type');

    my $count;
    if ($type =~ /single/)
    {
	$count = $self->training_pop_member_count($c, $pop_id);
    }
    elsif ($type =~ /combined/)
    {
	$count = $c->controller('solGS::combinedTrials')->count_combined_trials_members($c, $pop_id);	
    }
    
    my $ret->{status} = 'failed';
  
    if ($count) 
    {
	$ret->{status} = 'success';
	$ret->{member_count} = $count;
    }
        
    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);
       
}


sub traits_to_analyze :Regex('^solgs/analyze/traits/population/([\w|\d]+)(?:/([\d+]+))?') {
    my ($self, $c) = @_; 
   
    my ($pop_id, $prediction_id) = @{$c->req->captures};
 
    my $req = $c->req->param('source');
    
    $c->stash->{pop_id} = $pop_id;
    $c->stash->{prediction_pop_id} = $prediction_id;
   
    $self->build_multiple_traits_models($c);
  
    my $referer    = $c->req->referer;   
    my $base       = $c->req->base;
    $referer       =~ s/$base//;
    my ($tr_id)    = $referer =~ /(\d+)/;
    my $trait_page = "solgs/trait/$tr_id/population/$pop_id";

    my $error = $c->stash->{script_error};
  
    if ($error) 
    {
        $c->stash->{message} = "$error can't create prediction models for the selected traits. 
                                 There are problems with the datasets of the traits.
                                 <p><a href=\"/solgs/population/$pop_id\">[ Go back ]</a></p>";

        $c->stash->{template} = "/generic_message.mas"; 
    } 
    elsif ($req =~ /AJAX/)
    {     
    	my $ret->{status} = 'success';
  
        $ret = to_json($ret);
        
        $c->res->content_type('application/json');
        $c->res->body($ret);       
    }
     else
    {
        if ($referer =~ m/$trait_page/) 
        { 
            $c->res->redirect("/solgs/trait/$tr_id/population/$pop_id");
            $c->detach(); 
        }
        else 
        {
            $c->res->redirect("/solgs/traits/all/population/$pop_id/$prediction_id");
            $c->detach(); 
        }
    }

}


sub all_traits_output :Regex('^solgs/traits/all/population/([\w|\d]+)(?:/([\d+]+))?') {
     my ($self, $c) = @_;
         
     my ($pop_id, $pred_pop_id) = @{$c->req->captures};

     my @traits = $c->req->param; 
     @traits    = grep {$_ ne 'rank'} @traits;
     $c->stash->{training_pop_id} = $pop_id;
     $c->stash->{pop_id} = $pop_id;
          
     if ($pred_pop_id)
     {
         $c->stash->{prediction_pop_id} = $pred_pop_id;
         $c->stash->{population_is} = 'prediction population';
         $c->controller('solGS::Files')->selection_population_file($c, $pred_pop_id);
        
         my $pr_rs = $c->model('solGS::solGS')->project_details($pred_pop_id);
         
         while (my $row = $pr_rs->next) 
         {
             $c->stash->{prediction_pop_name} = $row->name;
         }
     }
     else
     {
         $c->stash->{prediction_pop_id} = undef;
         $c->stash->{population_is} = 'training population';
     }
    
     $c->stash->{model_id} = $pop_id; 
     
     my @trait_pages;
          
     $self->traits_with_valid_models($c);
     my @traits_with_valid_models = @{$c->stash->{traits_with_valid_models}};
     
     if (!@traits_with_valid_models)
     {
	 $c->res->redirect("/solgs/population/$pop_id/selecttraits/");
	 $c->detach();
     }

    foreach my $trait_abbr (@traits_with_valid_models)
    {
	$c->stash->{trait_abbr} = $trait_abbr;
        $self->get_trait_details_of_trait_abbr($c);

	my $trait_id = $c->stash->{trait_id};
	
	$self->get_model_accuracy_value($c, $pop_id, $trait_abbr);        
	my $accuracy_value = $c->stash->{accuracy_value};
	
	$c->controller("solGS::Heritability")->get_heritability($c);
	my $heritability = $c->stash->{heritability};

	push @trait_pages,  [ qq | <a href="/solgs/trait/$trait_id/population/$pop_id">$trait_abbr</a>|, $accuracy_value, $heritability];
       
    }

     $self->project_description($c, $pop_id);
     my $project_name = $c->stash->{project_name};
     my $project_desc = $c->stash->{project_desc};
   
     my @model_desc = ([qq | <a href="/solgs/population/$pop_id">$project_name</a> |, $project_desc, \@trait_pages]);
     
     $c->stash->{template}    = $c->controller('solGS::Files')->template('/population/multiple_traits_output.mas');
     $c->stash->{trait_pages} = \@trait_pages;
     $c->stash->{model_data}  = \@model_desc;
    
     my $acronym = $self->get_acronym_pairs($c);
     $c->stash->{acronym} = $acronym;
 
}



sub check_population_is_training_population {
    my ($self, $c) = @_;

    my $pr_id = $c->stash->{pop_id};
    my $is_gs = $c->model("solGS::solGS")->get_project_type($pr_id);

    my $has_phenotype;
    my $has_genotype;

    if ($is_gs !~ /genomic selection/) 
    {
	$self->check_population_has_phenotype($c);    
	$has_phenotype = $c->stash->{population_has_phenotype};

	if ($has_phenotype) 
	{
	    $self->check_population_has_genotype($c);   
	    $has_genotype = $c->stash->{population_has_genotype};
	}
    }

    if ($is_gs || ($has_phenotype && $has_genotype))
    {
	$c->stash->{is_training_population} = 1;
    }
 
}


sub check_population_has_phenotype {
    my ($self, $c) = @_;

    my $pr_id = $c->stash->{pop_id};
    my $is_gs = $c->model("solGS::solGS")->get_project_type($pr_id);
    my $has_phenotype = 1 if $is_gs;

    if ($is_gs !~ /genomic selection/)
    {
	my $cache_dir  = $c->stash->{solgs_cache_dir};
	my $pheno_file = $c->controller('solGS::Files')->grep_file($cache_dir, "phenotype_data_${pr_id}.txt");		 		 

	if (!-s $pheno_file)
	{
	    $has_phenotype = $c->model("solGS::solGS")->has_phenotype($pr_id);
	}
	else
	{
	    $has_phenotype = 1;
	}
    }
 
    $c->stash->{population_has_phenotype} = $has_phenotype;

}


sub check_population_has_genotype {
    my ($self, $c) = @_;
    
    my $pop_id = $c->stash->{pop_id};

    my $has_genotype;
   
    my $geno_file;
    if ($pop_id =~ /list/) 
    {	  	
	my $dir       = $c->stash->{solgs_lists_dir};
	my $user_id   = $c->user->id;
	my $file_name = "genotype_data_${pop_id}";
	$geno_file    = $c->controller('solGS::Files')->grep_file($dir,  $file_name);
	$has_genotype = 1 if -s $geno_file;  	
    }

    unless ($has_genotype) 
    {
	$has_genotype = $c->model('solGS::solGS')->has_genotype($pop_id);
    }	
  
    $c->stash->{population_has_genotype} = $has_genotype;

}

sub training_pop_member_count {
    my ($self, $c, $pop_id) = @_;

    $c->stash->{pop_id} = $pop_id if $pop_id;
     
    $c->controller("solGS::Files")->trait_phenodata_file($c);
    my $trait_pheno_file  = $c->stash->{trait_phenodata_file};
    my @trait_pheno_lines = read_file($trait_pheno_file) if $trait_pheno_file;

    my @geno_lines;
    if (!@trait_pheno_lines) 
    {
	$c->controller('solGS::Files')->genotype_file_name($c);
	my $geno_file  = $c->stash->{genotype_file_name};
	@geno_lines = read_file($geno_file);
    }
    
    my $count = @trait_pheno_lines ? scalar(@trait_pheno_lines) - 1 : scalar(@geno_lines) - 1;

    return $count;
}



=head1 AUTHOR

Isaak Y Tecle <iyt2@cornell.edu>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
