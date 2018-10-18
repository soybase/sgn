=head1 NAME

SGN::Controller::solQTL::Population- controller for a qtl population

=cut

package SGN::Controller::solQTL::Population;

use Moose;
use namespace::autoclean;
use File::Spec::Functions;
use List::MoreUtils qw /uniq/;
use File::Temp qw / tempfile /;
use File::Path qw / mkpath  /;
use File::Copy;
use File::Basename;
use File::Slurp qw /write_file read_file/;
use Try::Tiny;
use URI::FromHash 'uri';
use Cache::File;
use Path::Class;
use Bio::Chado::Schema;
use CXGN::Phenome::Qtl;
use CXGN::Phenome::Population;
use CXGN::Login;

BEGIN { extends 'Catalyst::Controller'}  


sub view : Path('/qtl/view') Args(1) {
    my ($self, $c, $id) = @_;
    $c->res->redirect("/qtl/population/$id");
  
}


sub population : Path('/qtl/population') Args() {
    my ( $self, $c, $pop_id, $action) = @_;

    $c->stash->{pop_id} = $pop_id;
 
    if (!$c->user()) {
	# redirect to login page
	$c->res->redirect( uri( path => '/user/login/', query => { goto_url => $c->req->uri->path_query } ) );
	return;
    }
    
    if ($pop_id)
    {
        $self->is_qtl_pop($c, $pop_id);
	my $qtl_pop = 1;#$c->stash->{is_qtl_pop};
        if ($qtl_pop) 
        {
 	    $c->controller('solGS::solGS')->phenotype_file($c);
	    my $pheno_file = $c->stash->{phenotype_file};
	    
	    $c->controller('solGS::solGS')->genotype_file($c);
	    my $geno_file = $c->stash->{genotype_file}; 
	  
	    my $qtl_dir = $c->stash->{solqtl_cache_dir};
	    $c->controller('solGS::Files')->copy_file($pheno_file, $qtl_dir);
	    $c->controller('solGS::Files')->copy_file($geno_file, $qtl_dir);

	    my $userid = $c->user()->get_object->get_sp_person_id() if $c->user;
	    	    
            $c->stash(template     => '/qtl/population/index.mas',                              
                      referer      => $c->req->path,             
		      userid       => $userid,
		      referer      => 
                );
           
	    $self->_get_links($c);
            #$self->_show_data($c);           
            
	    $self->genetic_map($c);
	    $c->controller('solGS::solGS')->project_description($c, $pop_id);

	    $c->controller('solGS::solGS')->get_project_owners($c, $pop_id);       
	    $c->stash->{owner} = $c->stash->{project_owners};

	    $c->controller('solGS::solGS')->get_all_traits($c);

	    $self->_list_traits($c);

	    if ($action && $action =~ /selecttraits/ ) 
	    {		
		$c->stash->{no_traits_selected} = 'none';
	    }
	    else 
	    {
		$c->stash->{no_traits_selected} = 'some';
	    }

	    my $acronym = $c->controller('solGS::solGS')->get_acronym_pairs($c);
	    $c->stash->{acronym} = $acronym;
	} 
	else 
	{
	    $c->stash->{message} = "$pop_id is not a QTL population.";
	}
    }
    else 
    {
	$c->stash->{message} = "There is no QTL population for $pop_id";
    }

    if ($c->stash->{message})
    {
	$c->stash->{template} = "/generic_message.mas"; 
    }  
}


sub _list_traits {
    my ($self, $c) = @_;  

    my $pop_id = $c->stash->{pop_id};
    my $pop =  CXGN::Phenome::Population->new($c->dbc->dbh, $pop_id);
    
    $c->controller('solGS::solGS')->get_all_traits($c);
    my $traits_file = $c->stash->{all_traits_file};

    my @traits_details = read_file($traits_file);
    shift(@traits_details);
    
    my @phenotype;
	
    foreach my $tr_detail ( @traits_details )
    {
	my ($trait_id, $trait_name, $acronym) = split('\t', $tr_detail);

	$c->stash->{trait_name} = $trait_name;
	$c->stash->{trait_id} = $trait_id;

	$self->_get_links($c);	    
	my $analysis_page = $c->stash->{qtl_analysis_page};
	   
	#my ($min, $max, $avg, $std, $count)= $pop->get_pop_data_summary($trait_id);
         
	push  @phenotype,  [$trait_id, $analysis_page];
	    	    
    }
    
    $c->stash->{traits_list} = \@phenotype;
}

#given $c and a population id, checks if it is a qtl population and stashes true or false
sub is_qtl_pop {
    my ($self, $c, $id) = @_;
    my $qtltool = CXGN::Phenome::Qtl::Tools->new();
    my @qtl_pops = $qtltool->has_qtl_data();

    foreach my $qtl_pop ( @qtl_pops )
    {
        my $pop_id = $qtl_pop->get_population_id();
        $pop_id == $id ? $c->stash(is_qtl_pop => 1) && last 
                       : $c->stash(is_qtl_pop => 0)
                       ;
    }
}


sub _get_links {
    my ($self, $c) = @_;
 
    my $pop_id     = $c->stash->{pop_id};
    #my $pop =  CXGN::Phenome::Population->new($c->dbc->dbh, $id);
     
    {
        no warnings 'uninitialized';
        my $trait_id   = $c->stash->{trait_id};
        my $trait_name = $c->stash->{trait_name};
        #my $term_id    = $trait_id ? $trait_id : $cvterm_id;
        my $graph_icon = qq | <img src="/documents/img/pop_graph.png" alt="run solqtl"/> |;
    
        $self->_get_owner_details($c);
        my $owner_name = $c->stash->{owner_name};
        my $owner_id   = $c->stash->{owner_id};   
    
        $c->stash( cvterm_page        => qq |<a href="/cvterm/$trait_id/view">$trait_name</a> |,
                   trait_page         => qq |<a href="/phenome/trait.pl?trait_id=$trait_id">$trait_name</a> |,
                   owner_page         => qq |<a href="/solpeople/personal-info.pl?sp_person_id=$owner_id">$owner_name</a> |,
                   guideline          => qq |<a href="/qtl/submission/guide">Guideline</a> |,
                   phenotype_download => qq |<a href="/qtl/download/phenotype/$pop_id">Phenotype data</a> |,
                   genotype_download  => qq |<a href="/qtl/download/genotype/$pop_id">Genotype data</a> |,
                   corre_download     => qq |<a href="/download/phenotypic/correlation/population/$pop_id">Correlation data</a> |,
                   acronym_download   => qq |<a href="/qtl/download/acronym/$pop_id">Trait-acronym key</a> |,
                   qtl_analysis_page  => qq |<a href="/phenome/qtl_analysis.pl?population_id=$pop_id&amp;trait_id=$trait_id" onclick="Qtl.waitPage()">$trait_name</a> |,
            );
    }
    
}


sub _get_owner_details {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};
    my $pop = CXGN::Phenome::Population->new($c->dbc->dbh, $pop_id);
    
    my $owner_id   = $pop->get_sp_person_id();
    my $owner      = CXGN::People::Person->new($c->dbc->dbh, $owner_id);
    my $owner_name = $owner->get_first_name()." ".$owner->get_last_name();    
    
    $c->stash( owner_name => $owner_name,
               owner_id   => $owner_id
        );
    
}


sub _show_data {
    my ($self, $c) = @_;
    my $user_id    = $c->stash->{userid};
    my $user_type  = $c->user->get_object->get_user_type() if $c->user;
    my $is_public  = $c->stash->{pop}->get_privacy_status();
    my $owner_id   = $c->stash->{pop}->get_sp_person_id();
    
    if ($user_id) 
    {        
        ($user_id == $owner_id || $user_type eq 'curator') ? $c->stash(show_data => 1) 
                  :                                          $c->stash(show_data => undef)
                  ;
    } else
    { 
        $is_public ? $c->stash(show_data => 1) 
                   : $c->stash(show_data => undef)
                   ;
    }            
}

sub set_stat_option : PathPart('qtl/stat/option') Chained Args(0) {
    my ($self, $c)  = @_;
    my $pop_id      = $c->req->param('pop_id');
    my $stat_params = $c->req->param('stat_params');
    my $file        = $self->stat_options_file($c, $pop_id);

    if ($file) 
    {
        my $f = file( $file )->openw
            or die "Can't create file: $! \n";

        if ( $stat_params eq 'default' ) 
        {
            $f->print( "default parameters\tYes" );
        } 
        else 
        {
            $f->print( "default parameters\tNo" );
        }  
    }
    $c->res->content_type('application/json');
    $c->res->body({undef});                

}

sub stat_options_file {
    my ($self, $c, $pop_id) = @_;
    my $login_id            = $c->user()->get_object->get_sp_person_id() if $c->user;
    
    if ($login_id) 
    {
        my $qtl = CXGN::Phenome::Qtl->new($login_id);
        my ($temp_qtl_dir, $temp_user_dir) = $qtl->create_user_qtl_dir($c);
        return  catfile( $temp_user_dir, "stat_options_pop_${pop_id}.txt" );
    }
    else 
    {
        return;
    }
}

    
sub qtl_form : PathPart('qtl/form') Chained Args {
    my ($self, $c, $type, $pop_id) = @_;  
    
    my $userid = $c->user()->get_object->get_sp_person_id() if $c->user;
    
    unless ($userid) 
    {
       $c->res->redirect( '/user/login' );
    }
    
    $type = 'intro' if !$type; 
   
    if (!$pop_id and $type !~ /intro|pop_form/ ) 
    {
     $c->throw_404("Population id argument is missing");   
    }

    if ($pop_id and $pop_id !~ /^([0-9]+)$/)  
    {
        $c->throw_404("<strong>$pop_id</strong> is not an accepted argument. 
                        This form expects an all digit population id, instead of 
                        <strong>$pop_id</strong>"
                     );   
    }

    $c->stash( template => $self->get_template($c, $type),
               pop_id   => $pop_id,
               guide    => qq |<a href="/qtl/submission/guide">Guideline</a> |,
               referer  => $c->req->path,
               userid   => $userid
            );   
 
}

sub templates {
    my $self = shift;
    my %template_of = ( intro      => '/qtl/qtl_form/intro.mas',
                        pop_form   => '/qtl/qtl_form/pop_form.mas',
                        pheno_form => '/qtl/qtl_form/pheno_form.mas',
                        geno_form  => '/qtl/qtl_form/geno_form.mas',
                        trait_form => '/qtl/qtl_form/trait_form.mas',
                        stat_form  => '/qtl/qtl_form/stat_form.mas',
                        confirm    => '/qtl/qtl_form/confirm.mas'
                      );
        return \%template_of;
}


sub get_template {
    my ($self, $c, $type) = @_;        
    return $self->templates->{$type};
}


sub submission_guide : PathPart('qtl/submission/guide') Chained Args(0) {
    my ($self, $c) = @_;
    $c->stash(template => '/qtl/submission/guide/index.mas');
}


sub genetic_map {
    my ($self, $c)  = @_;
    
    my $pop_id = $c->stash->{pop_id};
   
    my $pop         = CXGN::Phenome::Population->new($c->dbc->dbh, $pop_id);
    my $mapv_id     = $pop->mapversion_id();

    my $map         = CXGN::Map->new( $c->dbc->dbh, { map_version_id => $mapv_id } );

    my $map_name;
    my $map_sh_name;
    if ($map)
    {
	$map_name    = $map->get_long_name();
	$map_sh_name = $map->get_short_name();
	
	$c->stash->{genetic_map} = qq | <a href=/cview/map.pl?map_version_id=$mapv_id>$map_name ($map_sh_name)</a> |;
    }
    else
    {
	$c->stash->{genetic_map} = 'There is no genetic map for this QTL population.';
    }
  
}


sub search_help : PathPart('qtl/search/help') Chained Args(0) {
    my ($self, $c) = @_;
    $c->stash(template => '/qtl/search/help/index.mas');
}

sub show_search_results : PathPart('qtl/search/results') Chained Args(0) {
    my ($self, $c) = @_;
    my $trait = $c->req->param('trait');
    $trait =~ s/(^\s+|\s+$)//g;
    $trait =~ s/\s+/ /g;
               
    my $rs = $self->search_qtl_traits($c, $trait);

    if ($rs)
    {
        my $rows = $self->mark_qtl_traits($c, $rs);
                                                        
        $c->stash(template   => '/qtl/search/results.mas',
                  data       => $rows,
                  query      => $c->req->param('trait'),
                  pager      => $rs->pager,
                  page_links => sub {uri ( query => { trait => $c->req->param('trait'), page => shift } ) }
            );
    }
    else 
    {
        $c->stash(template   => '/qtl/search/results.mas',
                  data       => undef,
                  query      => undef,
                  pager      => undef,
                  page_links => undef,
            );
    }
}

sub search_qtl_traits {
    my ($self, $c, $trait) = @_;
    
    my $rs;
    if ($trait)
    {
        my $schema    = $c->dbic_schema("Bio::Chado::Schema");
        my $cv_id     = $schema->resultset("Cv::Cv")->search(
            {name => 'solanaceae_phenotype'}
            )->single->cv_id;

        $rs = $schema->resultset("Cv::Cvterm")->search(
            { name  => { 'LIKE' => '%'.$trait .'%'},
              cv_id => $cv_id,            
            },          
            {
              columns => [ qw/ cvterm_id name definition / ] 
            },    
            { 
              page     => $c->req->param('page') || 1,
              rows     => 10,
              order_by => 'name'
            }
            );       
    }
    return $rs;      
}

sub mark_qtl_traits {
    my ($self, $c, $rs) = @_;
    my @rows =();
    
    if (!$rs->single) 
    {
        return undef;
    }
    else 
    {  
        my $qtltool  = CXGN::Phenome::Qtl::Tools->new();
        my $yes_mark = qq |<font size=4 color="#0033FF"> &#10003;</font> |;
        my $no_mark  = qq |<font size=4 color="#FF0000"> X </font> |;

        while (my $cv = $rs->next) 
        {
            my $id   = $cv->cvterm_id;
            my $name = $cv->name;
            my $def  = $cv->definition;

            if (  $qtltool->is_from_qtl( $id ) ) 
            {                         
                push @rows, [ qq | <a href="/cvterm/$id/view">$name</a> |, $def, $yes_mark ];
           
            }
            else 
            {
                push @rows, [ qq | <a href="/cvterm/$id/view">$name</a> |, $def, $no_mark ];
            }      
        } 
        return \@rows;
    } 
}


sub qtl_traits : PathPart('qtl/traits') Chained Args(1) {
    my ($self, $c, $index) = @_;
    
    if ($index =~ /^\w{1}$/) 
    {
        my $traits_list = $self->map_qtl_traits($c, $index);
    
        $c->stash( template    => '/qtl/traits/index.mas',
                   index       => $index,
                   traits_list => $traits_list
            );
    }
    else 
    {
        $c->res->redirect('/search/qtl');
    }
}

sub all_qtl_traits : PathPart('qtl/traits') Chained Args(0) {
    my ($self, $c) = @_;
    $c->res->redirect('/search/qtl');
}

sub filter_qtl_traits {
    my ($self, $index) = @_;

    my $qtl_tools = CXGN::Phenome::Qtl::Tools->new();
    my ( $all_traits, $all_trait_d ) = $qtl_tools->all_traits_with_qtl_data();

    return [
        sort { $a cmp $b  }
        grep { /^$index/i }
        uniq @$all_traits
    ];
}

sub map_qtl_traits {
    my ($self, $c, $index) = @_;

    my $traits_list = $self->filter_qtl_traits($index);
    
    my @traits_urls;
    if (@{$traits_list})
    {
        foreach my $trait (@{$traits_list})
        {
            my $cvterm = CXGN::Chado::Cvterm::get_cvterm_by_name( $c->dbc->dbh, $trait );
            my $cvterm_id = $cvterm->get_cvterm_id();
            if ($cvterm_id)
            {
                push @traits_urls,
                [
                 map { $_ } 
                 (
                  qq |<a href=/cvterm/$cvterm_id/view>$trait</a> |
                 )
                ];
            }
            else
            {
                my $t = CXGN::Phenome::UserTrait->new_with_name( $c->dbc->dbh, $trait );
                my $trait_id = $t->get_user_trait_id();
                push @traits_urls,
                [
                 map { $_ } 
                 (
                  qq |<a href=/phenome/trait.pl?trait_id=$trait_id>$trait</a> |
                 )
                ];
            }
        }
    }
   
    return \@traits_urls;
}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);
  
}

__PACKAGE__->meta->make_immutable;
####
1;
####
