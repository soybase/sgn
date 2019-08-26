package SGN::Controller::solGS::SelectionIndex;

use Moose;
use namespace::autoclean;

use File::Slurp qw /write_file read_file :edit prepend_file append_file/;
use List::MoreUtils qw /uniq/;

use JSON;

BEGIN { extends 'Catalyst::Controller' }



sub selection_index_form :Path('/solgs/selection/index/form') Args(0) {
    my ($self, $c) = @_;
    
    my $selection_pop_id = $c->req->param('selection_pop_id');
    my $training_pop_id = $c->req->param('training_pop_id');
    my @traits_ids  = $c->req->param('training_traits_ids[]');
   
    $c->stash->{model_id} = $training_pop_id;
    $c->stash->{training_pop_id} = $training_pop_id;
    $c->stash->{selection_pop_id} = $selection_pop_id;
    $c->stash->{training_traits_ids} = \@traits_ids;
    
    my @traits;
    if (!$selection_pop_id) 
    {    
        $c->controller('solGS::solGS')->analyzed_traits($c);
        @traits = @{ $c->stash->{selection_index_traits} }; 
    }
    else  
    {
        $c->controller('solGS::solGS')->prediction_pop_analyzed_traits($c, $training_pop_id, $selection_pop_id);
        @traits = @{ $c->stash->{prediction_pop_analyzed_traits} };
    }

    my $ret->{status} = 'success';
    $ret->{traits} = \@traits;
     
    $ret = to_json($ret);       
    $c->res->content_type('application/json');
    $c->res->body($ret);
    
}


sub calculate_selection_index :Path('/solgs/calculate/selection/index') Args() {
    my ($self, $c) = @_;

    my $selection_pop_id = $c->req->param('selection_pop_id');
    my $training_pop_id = $c->req->param('training_pop_id');
   
    my @training_traits_ids = $c->req->param('training_traits_ids[]');
        
    my $traits_wts = $c->req->param('rel_wts');
    my $json = JSON->new();
    my $rel_wts = $json->decode($traits_wts);

    $c->stash->{pop_id} = $training_pop_id;
    $c->stash->{model_id} = $training_pop_id;
    $c->stash->{training_pop_id} = $training_pop_id;
    $c->stash->{selection_pop_id} = $selection_pop_id;

    $c->stash->{training_traits_ids} = \@training_traits_ids;
   
    my @traits = keys (%$rel_wts);    
    @traits    = grep {$_ ne 'rank'} @traits;
   
    my @values;
    foreach my $tr (@traits)
    {
        push @values, $rel_wts->{$tr};
    }
    
    my $ret->{status} = 'Selection index failed.';
    if (@values) 
    {
        $c->controller('solGS::TraitsGebvs')->get_gebv_files_of_traits($c);
    
        $self->gebv_rel_weights($c, $rel_wts);         
        $self->calc_selection_index($c);
	
	my $ranked_genos = $c->stash->{top_10_selection_indices};
        my $geno = $c->controller('solGS::Utils')->convert_arrayref_to_hashref($ranked_genos);
        
        my $link         = $c->stash->{ranked_genotypes_download_url};                    
        my $index_file   = $c->stash->{selection_index_only_file};
       
        $ret->{status} = 'No GEBV values to rank.';

        if (@$ranked_genos) 
        {
            $ret->{status}     = 'success';
            $ret->{genotypes}  = $geno;
            $ret->{link}       = $link;
            $ret->{index_file} = $index_file;
        }                     
    }  
    else
    {
	$ret->{status} = 'No relative weights submitted';
    }

    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);
}


sub calc_selection_index {
    my ($self, $c) = @_;

    my $input_files = join("\t", 
                           $c->stash->{rel_weights_file},
                           $c->stash->{gebv_files_of_traits}
        );
   
    $self->gebvs_selection_index_file($c);
    $self->selection_index_file($c);

    my $output_files = join("\t",
                            $c->stash->{gebvs_selection_index_file},
                            $c->stash->{selection_index_only_file}
        );
    
   
    $c->controller('solGS::Files')->create_file_id($c);
    my $file_id = $c->stash->{file_id};
    
    my $out_name = "output_files_selection_index_${file_id}";
    my $temp_dir = $c->stash->{selection_index_temp_dir};
    my $output_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, $out_name);
    write_file($output_file, $output_files);
       
    my $in_name = "input_files_selection_index_${file_id}";
    my $input_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, $in_name);
    write_file($input_file, $input_files);

    $c->stash->{analysis_tempfiles_dir} = $c->stash->{selection_index_temp_dir};
    $c->stash->{output_files} = $output_file;
    $c->stash->{input_files}  = $input_file;   
    $c->stash->{r_temp_file}  = "selection_index_${file_id}";  
    $c->stash->{r_script}     = 'R/solGS/selection_index.r';
    
    $c->controller('solGS::solGS')->run_r_script($c);
    $c->controller('solGS::solGS')->download_urls($c);
    $self->get_top_10_selection_indices($c);
}


sub get_top_10_selection_indices {
    my ($self, $c) = @_;
    
    my $si_file = $c->stash->{selection_index_only_file};
  
    my $si_data = $c->controller('solGS::Utils')->read_file($c, $si_file);
    my @top_genotypes = @$si_data[0..9];
    
    $c->stash->{top_10_selection_indices} = \@top_genotypes;
}


sub gebv_rel_weights {
    my ($self, $c, $rel_wts) = @_;
         
    my @si_id;
    my $rel_wts_txt = "trait" . "\t" . 'relative_weight' . "\n";
    
    foreach my $tr (keys %$rel_wts)
    {      
        my $wt = $rel_wts->{$tr};
        unless ($tr eq 'rank')
        {
            $rel_wts_txt .= $tr . "\t" . $wt;
            $rel_wts_txt .= "\n";
	    push @si_id, $tr, $wt;
        }
    }

    my $si_id = join('-', @si_id);
    $c->stash->{selection_index_id} = $si_id;

    $self->rel_weights_file($c);
    my $file = $c->stash->{rel_weights_file};
    write_file($file, $rel_wts_txt);
    
   ### $c->stash->{rel_weights_file} = $file;
    
}


sub gebvs_selection_index_file {
    my ($self, $c) = @_;

   $c->controller('solGS::Files')->create_file_id($c);
    my $file_id = $c->stash->{file_id};
  
    my $name = "gebvs_selection_index_${file_id}";
    my $dir = $c->stash->{selection_index_cache_dir};
 
    my $cache_data = { key       => $name, 
		       file      => $name . '.txt',
		       stash_key => 'gebvs_selection_index_file',
		       cache_dir => $dir
    };
   
    $c->controller('solGS::Files')->cache_file($c, $cache_data);
    
}


sub selection_index_file {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->create_file_id($c);
    my $file_id = $c->stash->{file_id};
    
    my $name = "selection_index_only_${file_id}";
    my $dir = $c->stash->{selection_index_cache_dir};
 
    my $cache_data = { key       => $name, 
		       file      => $name . '.txt',
		       stash_key => 'selection_index_only_file',
		       cache_dir => $dir
    };
    
    $c->controller('solGS::Files')->cache_file($c, $cache_data);
    
}


sub rel_weights_file {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->create_file_id($c);
    my $file_id = $c->stash->{file_id};

    my $dir = $c->stash->{selection_index_cache_dir};
    my $name =  "rel_weights_${file_id}";
   
    my $cache_data = { key       => $name, 
    		       file      => $name . '.txt',
    		       stash_key => 'rel_weights_file',
    		       cache_dir => $dir
    };
    
    $c->controller('solGS::Files')->cache_file($c, $cache_data);
}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);
  
}



####
1;
#
