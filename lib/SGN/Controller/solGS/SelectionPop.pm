package SGN::Controller::solGS::SelectionPop;

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


sub check_selection_pops_list :Path('/solgs/check/selection/populations') Args(1) {
    my ($self, $c, $tr_pop_id) = @_;

    $c->stash->{training_pop_id} = $tr_pop_id;

    $c->controller('solGS::Files')->list_of_prediction_pops_file($c, $tr_pop_id);
    my $pred_pops_file = $c->stash->{list_of_prediction_pops_file};
   
    my $ret->{result} = 0;
   
    if (-s $pred_pops_file) 
    {  
	$self->list_of_prediction_pops($c, $tr_pop_id);
	$ret->{data} =  $c->stash->{list_of_prediction_pops};                
    }    

    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}


sub check_selection_population_relevance :Path('/solgs/check/selection/population/relevance') Args() {
    my ($self, $c) = @_;

    my $data_set_type      = $c->req->param('data_set_type');  
    my $training_pop_id    = $c->req->param('training_pop_id');
    my $selection_pop_name = $c->req->param('selection_pop_name');
    my $trait_id           = $c->req->param('trait_id');    
    
    $c->stash->{data_set_type} = $data_set_type;

    my $pr_rs = $c->model("solGS::solGS")->project_details_by_exact_name($selection_pop_name);
   
    my $selection_pop_id;
    while (my $row = $pr_rs->next) {  
	$selection_pop_id = $row->project_id;
    }
       
    my $ret = {};

    if ($selection_pop_id !~ /$training_pop_id/)
    {
	my $has_genotype;
	if ($selection_pop_id)
	{
	    $c->stash->{pop_id} = $selection_pop_id;
	    $self->check_population_has_genotype($c);
	    $has_genotype = $c->stash->{population_has_genotype};
	}  

	my $similarity;
	if ($has_genotype)
	{
	    $c->stash->{pop_id} = $selection_pop_id;

	    $self->first_stock_genotype_data($c, $selection_pop_id);
	    my $selection_pop_geno_file = $c->stash->{first_stock_genotype_file};

	    my $training_pop_geno_file;
	
	    if ($training_pop_id =~ /list/) 
	    {	  	
		my $dir = $c->stash->{solgs_lists_dir};
		my $user_id = $c->user->id;
		my $tr_geno_file = "genotype_data_${training_pop_id}";
		$training_pop_geno_file = $c->controller('solGS::Files')->grep_file($dir,  $tr_geno_file);  	
	    }
	    else 
	    {
		my $dir = $c->stash->{solgs_cache_dir}; 
		my $tr_geno_file;
	
		if ($data_set_type =~ /combined populations/) 
		{
		    $self->get_trait_details($c, $trait_id);
		    my $trait_abbr = $c->stash->{trait_abbr}; 
		    $tr_geno_file  = "genotype_data_${training_pop_id}_${trait_abbr}";
		}
		else
		{
		    $tr_geno_file = "genotype_data_${training_pop_id}";
		}
		
		$training_pop_geno_file = $c->controller('solGS::Files')->grep_file($dir,  $tr_geno_file); 
	    }

	    $similarity = $self->compare_marker_set_similarity([$selection_pop_geno_file, $training_pop_geno_file]);
	} 

	my $selection_pop_data;
	if ($similarity >= 0.5 ) 
	{	
	    $c->stash->{training_pop_id} = $training_pop_id;
	    $self->format_selection_pops($c, [$selection_pop_id]);
	    $selection_pop_data = $c->stash->{selection_pops_list};
	    $self->save_selection_pops($c, [$selection_pop_id]);
	}
	
	$ret->{selection_pop_data} = $selection_pop_data;
	$ret->{similarity}         = $similarity;
	$ret->{has_genotype}       = $has_genotype;
	$ret->{selection_pop_id}   = $selection_pop_id;
    }
    else
    {
	$ret->{selection_pop_id}   = $selection_pop_id;
    }
 
    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}


sub save_selection_pops {
    my ($self, $c, $selection_pop_id) = @_;

    my $training_pop_id  = $c->stash->{training_pop_id};

    $c->controller('solGS::Files')->list_of_prediction_pops_file($c, $training_pop_id);
    my $selection_pops_file = $c->stash->{list_of_prediction_pops_file};

    my @existing_pops_ids = split(/\n/, read_file($selection_pops_file));
   
    my @uniq_ids = unique(@existing_pops_ids, @$selection_pop_id);
    my $formatted_ids = join("\n", @uniq_ids);
       
    write_file($selection_pops_file, $formatted_ids);

}


sub search_selection_pops :Path('/solgs/search/selection/populations/') {
    my ($self, $c, $tr_pop_id) = @_;
    
    $c->stash->{training_pop_id} = $tr_pop_id;
 
    $self->search_all_relevant_selection_pops($c, $tr_pop_id);
    my $selection_pops_list = $c->stash->{all_relevant_selection_pops};
  
    my $ret->{selection_pops_list} = 0;
    if ($selection_pops_list) 
    {
	$ret->{data} = $selection_pops_list;           
    }    

    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret); 
   
}


sub list_of_prediction_pops {
    my ($self, $c, $training_pop_id) = @_;

    $c->controller('solGS::Files')->list_of_prediction_pops_file($c, $training_pop_id);
    my $pred_pops_file = $c->stash->{list_of_prediction_pops_file};
  
    my @pred_pops_ids = split(/\n/, read_file($pred_pops_file));
 
    $self->format_selection_pops($c, \@pred_pops_ids); 

    $c->stash->{list_of_prediction_pops} = $c->stash->{selection_pops_list};

}


sub search_all_relevant_selection_pops {
    my ($self, $c, $training_pop_id) = @_;
  
    my @pred_pops_ids = @{$c->model('solGS::solGS')->prediction_pops($training_pop_id)};
  
    $self->save_selection_pops($c, \@pred_pops_ids);
   
    $self->format_selection_pops($c, \@pred_pops_ids); 

    $c->stash->{all_relevant_selection_pops} = $c->stash->{selection_pops_list};

}


sub format_selection_pops {
    my ($self, $c, $pred_pops_ids) = @_;
    
    my $training_pop_id = $c->stash->{training_pop_id};
  
    my @pred_pops_ids = @{$pred_pops_ids};    
    my @data;

    if (@pred_pops_ids) {

        foreach my $prediction_pop_id (@pred_pops_ids)
        {
          my $pred_pop_rs = $c->model('solGS::solGS')->project_details($prediction_pop_id);
          my $pred_pop_link;

          while (my $row = $pred_pop_rs->next)
          {
              my $name = $row->name;
              my $desc = $row->description;
            
             # unless ($name =~ /test/ || $desc =~ /test/)   
             # {
                  my $id_pop_name->{id}    = $prediction_pop_id;
                  $id_pop_name->{name}     = $name;
                  $id_pop_name->{pop_type} = 'selection';
                  $id_pop_name             = to_json($id_pop_name);

                  $pred_pop_link = qq | <a href="/solgs/model/$training_pop_id/prediction/$prediction_pop_id" 
                                      onclick="solGS.waitPage(this.href); return false;"><input type="hidden" value=\'$id_pop_name\'>$name</data> 
                                      </a> 
                                    |;

                  my $pr_yr_rs = $c->model('solGS::solGS')->project_year($prediction_pop_id);
                  my $project_yr;

                  while ( my $yr_r = $pr_yr_rs->next )
                  {
                      $project_yr = $yr_r->value;
                  }
		 
                  $self->download_prediction_urls($c, $training_pop_id, $prediction_pop_id);
                  my $download_prediction = $c->stash->{download_prediction};

                  push @data,  [$pred_pop_link, $desc, $project_yr, $download_prediction];
             # }
          }
        }
    }

    $c->stash->{selection_pops_list} = \@data;

}



=head1 AUTHOR

Isaak Y Tecle <iyt2@cornell.edu>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
