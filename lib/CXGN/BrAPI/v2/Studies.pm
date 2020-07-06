package CXGN::BrAPI::v2::Studies;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Trial::Search;
use CXGN::Trial::TrialLayout;
use CXGN::Trait;
use CXGN::Stock;
use CXGN::Phenotypes::SearchFactory;
use CXGN::Phenotypes::PhenotypeMatrix;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::FileResponse;
use CXGN::BrAPI::JSONResponse;
use JSON;

extends 'CXGN::BrAPI::v2::Common';

sub seasons {
    my $self = shift;
    my $year_filter = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;

    my @data;
    my $total_count = 0;
    my $year_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema,'project year', 'project_property')->cvterm_id();
    my $project_years_rs = $self->bcs_schema()->resultset("Project::Project")->search_related('projectprops', {'projectprops.type_id'=>$year_cvterm_id});
    my %unique_years;
    while (my $p_year = $project_years_rs->next()) {
        $unique_years{$p_year->value} = $p_year->projectprop_id;
    }
    my @sorted_years;
    foreach (sort keys %unique_years){
        my ($year, $season) = split '\|', $_;
        if ($year_filter){
            if ($year eq $year_filter){
                push @sorted_years, [$year, $season, $_];
            }
        } else {
            push @sorted_years, [$year, $season, $_];
        }
    }

    my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array(\@sorted_years, $page_size, $page);
    foreach (@$data_window){
        my $year = $_->[0] ? $_->[0] : '';
        my $season = $_->[1] ? $_->[1] : '';
        my $projectprop_id = $_->[2] ? $_->[2] : '';
        push @data, {
            seasonDbId=>qq|$projectprop_id|,
            season=>$season,
            year=>$year
        };
    }
    my %result = (data=>\@data);
    my @data_files;
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Seasons list result constructed');
}

sub study_types {
	my $self = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my @data;
	my @data_files;
	my @project_type_ids = CXGN::Trial::get_all_project_types($self->bcs_schema());
	my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array(\@project_type_ids, $page_size, $page);
	foreach (@$data_window){
		push @data, $_->[1];
	}
	my %result = (data=>\@data);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'StudyTypes list result constructed');
}

sub search {
    my $self = shift;
    my $search_params = shift;
	my $c = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $schema = $self->bcs_schema;
    my $supported_crop = $c->config->{"supportedCrop"};

    my @program_dbids = $search_params->{programDbIds} ? @{$search_params->{programDbIds}} : ();
 	my @program_names = $search_params->{programNames} ? @{$search_params->{programNames}} : ();
	my @study_dbids = $search_params->{studyDbIds} ? @{$search_params->{studyDbIds}} : ();
	my @study_names = $search_params->{studyNames} ? @{$search_params->{studyNames}} : ();
	my @folder_dbids = $search_params->{trialDbIds} ? @{$search_params->{trialDbIds}} : ();
	my @folder_names = $search_params->{trialNames} ? @{$search_params->{trialNames}} : ();
	my @location_ids = $search_params->{locationDbIds} ? @{$search_params->{locationDbIds}} : ();
	my @location_names = $search_params->{studyLocationNames} ? @{$search_params->{studyLocationNames}} : ();
	my @study_type_list = $search_params->{studyType} ? @{$search_params->{studyTypes}} : ();
	my @germplasm_dbids = $search_params->{germplasmDbIds} ? @{$search_params->{germplasmDbIds}} : ();
	my @germplasm_names = $search_params->{germplasmNames} ? @{$search_params->{germplasmNames}} : ();
	my @year_list = $search_params->{seasonDbIds} ? @{$search_params->{seasonDbIds}} : ();
	my @obs_variable_ids = $search_params->{observationVariableDbIds} ? @{$search_params->{observationVariableDbIds}} : ();
	my @study_puis = $search_params->{studyPUI} ? @{$search_params->{studyPUIs}} : ();
	my @externalReferenceID = $search_params->{externalReferenceID} ? @{$search_params->{externalReferenceIDs}} : ();
	my @externalReferenceSource = $search_params->{externalReferenceSource} ? @{$search_params->{externalReferenceSources}} : ();
    my @crop = $search_params->{commonCropNames} ? @{$search_params->{commonCropNames}} : ();
    my $active = $search_params->{active} || undef;
    my $sortBy = $search_params->{sortBy} || undef;
    my $sortOrder = $search_params->{sortOrder} || undef;

    if (scalar(@crop)>0 && !grep { lc($_) eq lc($supported_crop) } @crop ){
    	return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('commonCropName not found!'));
    }
    if ($active && lc($active) ne 'true'){
    	return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('Not found!'));
    }

    if (scalar(@study_puis)>0 || scalar(@externalReferenceID)>0  || scalar(@externalReferenceSource)>0 ){
        push @$status, { 'error' => 'The following search parameters are not implemented: studyPUI, externalReferenceID, externalReferenceSource' };
    }

    my ($data_out,$total_count) = _search($self,$schema,$page_size,$page,$supported_crop,\@study_dbids,\@location_names,\@location_ids,\@study_type_list,\@study_names,\@program_names,\@program_dbids,\@folder_dbids,\@folder_names,\@obs_variable_ids,\@germplasm_dbids,\@germplasm_names, \@year_list,$sortBy,$sortOrder);

    my %result = (data=>$data_out);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Studies search result constructed');
}

sub detail {
	my $self = shift;
	my $study_id = shift;
    my $main_production_site_url = shift;
	my $supported_crop = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;

	my $total_count = 0;
	my %result;
	my $study_check = $self->bcs_schema->resultset('Project::Project')->find({project_id=>$study_id});
	if ($study_check) {
		my $t = CXGN::Trial->new({ bcs_schema => $self->bcs_schema, trial_id => $study_id });
		$total_count = 1;
		my $folder = CXGN::Trial::Folder->new( { folder_id => $study_id, bcs_schema => $self->bcs_schema } );
		if ($folder->folder_type eq 'trial') {

			my @season = ($t->get_year());

			my %additional_info = ();
			my $project_type = '';
			if ($t->get_project_type()) {
				$project_type = $t->get_project_type()->[1];
			}
			my $location_id = '';
			my $location_name = '';
			if ($t->get_location()) {
				$location_id = $t->get_location()->[0];
				$location_name = $t->get_location()->[1];
			}
			my $planting_date;
			if ($t->get_planting_date()) {
				$planting_date = $t->get_planting_date();
				my $t = Time::Piece->strptime($planting_date, "%Y-%B-%d");
				$planting_date = $t->strftime("%Y-%m-%d");
			}
			my $harvest_date;
			if ($t->get_harvest_date()) {
				$harvest_date = $t->get_harvest_date();
				my $t = Time::Piece->strptime($harvest_date, "%Y-%B-%d");
				$harvest_date = $t->strftime("%Y-%m-%d");
			}
			my $contacts = $t->get_trial_contacts();
			my $brapi_contacts;
			foreach (@$contacts){
				push @$brapi_contacts, {
					contactDbId => $_->{sp_person_id},
					name => $_->{salutation}." ".$_->{first_name}." ".$_->{last_name},
                    instituteName => $_->{organization},
					email => $_->{email},
					type => $_->{user_type},
					orcid => ''
				};
			}
			my $location = CXGN::Trial::get_all_locations($self->bcs_schema, $location_id)->[0];

            my $additional_files = $t->get_additional_uploaded_files();
            my @data_links;
            foreach (@$additional_files){
                push @data_links, {
                    scientificType => 'Additional File',
                    name => $_->[4],
                    url => $main_production_site_url.'/breeders/phenotyping/download/'.$_->[0],
                    provenance => undef,
                    dataFormat => undef,
                    description => undef,
                    fileFormat => undef,
                    version => undef
                };
            }

            my $phenotype_files = $t->get_phenotype_metadata();
            foreach (@$additional_files){
                push @data_links, {
                    scientificType => 'Uploaded Phenotype File',
                    name => $_->[4],
                    url => $main_production_site_url.'/breeders/phenotyping/download/'.$_->[0],
                    provenance => undef,
                    dataFormat => undef,
                    description => undef,
                    fileFormat => undef,
                    version => undef
                };
            }

            my $data_agreement = $t->get_data_agreement() ? $t->get_data_agreement() : '';
            my $study_db_id = $t->get_trial_id();
            my $folder_db_id = $folder->project_parent->project_id();
            my $breeding_program_id = $folder->breeding_program->project_id();
			%result = (
				active=>JSON::true,
				additionalInfo=>\%additional_info,
				commonCropName => $supported_crop,
				contacts => $brapi_contacts,
				culturalPractices => undef,
				dataLinks =>\@data_links,
				documentationURL => "",
				endDate => $harvest_date ? $harvest_date :  undef ,
				environmentParameters => undef,
				experimentalDesign => $t->get_design_type(),
				externalReferences => undef,
				growthFacility => undef,
				lastUpdate => undef,
				license => $data_agreement,
				locationDbId => $location_id,
				locationName => $location_name,
				observationLevels => undef,
				observationUnitsDescription => undef,
				seasons => \@season,
				startDate => $planting_date ? $planting_date : undef,
				studyDbId=>qq|$study_db_id|,
				studyDescription=>$t->get_description(),
				studyName=>$t->get_name(),
				studyType=>$project_type,
				trialDbId=>qq|$folder_db_id|,
				trialName=>$folder->project_parent->name(),
				studyCode => qq|$study_db_id|,
				studyPUI => undef,
			);
		} else {
			return CXGN::BrAPI::JSONResponse->return_error($status, 'StudyDbId not a study');
		}
	} else {
		return CXGN::BrAPI::JSONResponse->return_error($status, 'StudyDbId not found');
	}
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Studies detail result constructed');
}

sub store {
	my $self = shift;
    my $data = shift;
    my $user_id =shift;
    my $c = shift;

    if (!$user_id){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('You must be logged in to add a seedlot!'));
    }

	my $dbh = $self->bcs_schema()->storage()->dbh();
	my $schema = $self->bcs_schema;
    my $person = CXGN::People::Person->new($dbh, $user_id);
    my $user_name = $person->get_username;

    my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;

    my @project_type_ids = CXGN::Trial::get_all_project_types($self->bcs_schema());
    my %project_type_ids;
	foreach (@project_type_ids) {
		$project_type_ids{$_->[1]} = $_->[0];
    }

    my @study_dbids;

    foreach my $params (@{$data}) {
    	my $trial_name = $params->{studyName} ? $params->{studyName} : undef;
	    my $trial_description = $params->{studyDescription} ? $params->{studyDescription} : undef;
	    my $trial_year = $params->{seasons} ? $params->{seasons}->[0] : undef;
	    my $trial_location = $params->{locationName} ? $params->{locationName} : undef;
	    my $trial_design_method = $params->{experimentalDesign} ? $params->{experimentalDesign}->{PUI} : undef; #Design type must be either: genotyping_plate, CRD, Alpha, Augmented, Lattice, RCBD, MAD, p-rep, greenhouse, or splitplot;
	    my $folder_id = $params->{trialDbId} ? $params->{trialDbId} : undef;
	    my $study_type = $params->{studyType} ? $params->{studyType} : undef;
	    my $trial_type = $project_type_ids{$study_type};
	    my $field_size = $params->{additionalInfo}->{field_size} ? $params->{additionalInfo}->{field_size} : undef;
	    my $plot_width = $params->{additionalInfo}->{plot_width} ? $params->{additionalInfo}->{plot_width} : undef;
	    my $plot_length = $params->{additionalInfo}->{plot_length} ? $params->{additionalInfo}->{plot_length} : undef;

	    if(!$trial_type){
	    	return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('Study type name: ' . $study_type . ' does not exist. Check study types supported!'));
	    }
	    my $folder = CXGN::Trial::Folder->new(bcs_schema=>$self->bcs_schema(), folder_id=>$folder_id);
	    my $program = $folder->breeding_program->name();

	    my $save;
		my $coderef = sub {

		    my %trial_info_hash = (
	            chado_schema => $schema,
	            dbh => $dbh,
	            trial_year => $trial_year,
	            trial_description => $trial_description,
	            trial_location => $trial_location,
	            trial_type => $trial_type,
	            trial_name => $trial_name,
	            user_name => $user_name, #not implemented
	            design_type => $trial_design_method,
	            design => {},
	            program => $program,
	            # upload_trial_file => $upload,
	            operator => $user_name,
				trial_stock_type => 'accession' #can be cross or family name, not implemented
	        );

	        print STDERR "Trial type is ".$trial_info_hash{'trial_type'}."\n";

	        if ($field_size){
	            $trial_info_hash{field_size} = $field_size;
	        }
	        if ($plot_width){
	            $trial_info_hash{plot_width} = $plot_width;
	        }
	        if ($plot_length){
	            $trial_info_hash{plot_length} = $plot_length;
	        }

	        my $trial_create = CXGN::Trial::TrialCreate->new(\%trial_info_hash);
	        $save = _save_trial($trial_create);
	        my $error = $save->{error};
	        if ($error){
	            $schema->txn_rollback();
	           	return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('There was an error storing studies. %s', $error));
	        }
	        return $save->{project_id};
	    };

	    #save data
	    eval {
	        my $trial_id = $schema->txn_do($coderef);

	        if (ref \$trial_id eq 'SCALAR'){
		    	push @study_dbids, $trial_id;
			}
	    };

	}

	my $data_out;
	my $total_count=0;
	if (scalar(@study_dbids)>0){
		my $dbh = $c->dbc->dbh();
		my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
		my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

		my $supported_crop = $c->config->{"supportedCrop"};

	    ($data_out,$total_count) = _search($self,$schema,$page_size,$page,$supported_crop,\@study_dbids);
	}
	
    my %result = (data=>$data_out);

	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Studies result constructed');
}

sub update {
	my $self = shift;
	my $params = shift;
	my $user_id =shift;
	my $c = shift;

	if (!$user_id){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('You must be logged in to add a seedlot!'));
    }

	my $trial_id = $params->{studyDbId};
	my $schema = $self->bcs_schema;
	my $metadata_schema = $self->metadata_schema;
	my $phenome_schema = $self->phenome_schema;

	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;

	my $dbh = $self->bcs_schema()->storage()->dbh();
    my $person = CXGN::People::Person->new($dbh, $user_id);
    my @user_roles = $person->get_roles;
 
	# get program roles
	my $program_object = CXGN::BreedersToolbox::Projects->new( { schema => $schema });
	my $program_ref = $program_object->get_breeding_programs_by_trial($trial_id);

	my $program_array = @$program_ref[0];
	my $breeding_program_name = @$program_array[1];

	my %has_roles = ();
	map { $has_roles{$_} = 1; } @user_roles;

	print STDERR "my user roles = @user_roles and trial breeding program = $breeding_program_name \n";

	if (!exists($has_roles{$breeding_program_name})) {
	  return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf("You need to be associated with breeding program $breeding_program_name to change the details of this trial." ));
	}

	#Get project type
	my @project_type_ids = CXGN::Trial::get_all_project_types($self->bcs_schema());
    my %project_type_ids;
	foreach (@project_type_ids) {
		$project_type_ids{$_->[1]} = $_->[0];
    }

    # set each new detail that is defined
	my $study_name = $params->{studyName} ? $params->{studyName} : undef;
	my $study_description = $params->{studyDescription} ? $params->{studyDescription} : undef;
	my $study_year = $params->{seasons} ? $params->{seasons}->[0] : undef;
	my $study_location = $params->{locationDbId} ? $params->{locationDbId} : undef;
	my $study_design_method = $params->{experimentalDesign} ? $params->{experimentalDesign}->{PUI} : undef; #Design type must be either: genotyping_plate, CRD, Alpha, Augmented, Lattice, RCBD, MAD, p-rep, greenhouse, or splitplot;
	my $folder_id = $params->{trialDbId} ? $params->{trialDbId} : undef;
	my $study_t = $params->{studyType} ? $params->{studyType} : undef;
	my $study_type = $project_type_ids{$study_t};
	my $field_size = $params->{additionalInfo}->{field_size} ? $params->{additionalInfo}->{field_size} : undef;
	my $plot_width = $params->{additionalInfo}->{plot_width} ? $params->{additionalInfo}->{plot_width} : undef;
	my $plot_length = $params->{additionalInfo}->{plot_length} ? $params->{additionalInfo}->{plot_length} : undef;
	my $planting_date = $params->{startDate} ? $params->{startDate} : undef;
	my $harvest_date = $params->{endDate} ? $params->{endDate} : undef;

	if(!$study_type && $study_t){
		return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('Study type name: ' . $study_t . ' does not exist. Check study types supported!'));
	}
	my $folder = CXGN::Trial::Folder->new(bcs_schema=>$self->bcs_schema(), folder_id=>$folder_id);
	my $program = $folder->breeding_program->name();


    eval {
    	my $trial_name_exists = CXGN::Trial::Search->new({
	        bcs_schema => $schema,
	        metadata_schema => $metadata_schema,
	        phenome_schema => $phenome_schema,
	        trial_name_list => [$study_name]
	    });
	    my ($data, $total_count) = $trial_name_exists->search();
	    
	    if($total_count>0){
	    	return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf("Can't create trial: Trial name already exists\n"));
		}
    	my $trial = CXGN::Trial->new({
	        bcs_schema => $schema,
	        metadata_schema => $metadata_schema,
	        phenome_schema => $phenome_schema,
	        trial_id => $trial_id
	    }); 
		if ($study_name) { $trial->set_name($study_name); }
		if ($folder_id) { $trial->set_breeding_program($program); }
		if ($study_location) { $trial->set_location($study_location); }
		if ($study_year) { $trial->set_year($study_year); }
		if ($study_type) { $trial->set_project_type($study_type); }
		if ($planting_date) {
			if ($planting_date eq '') { $trial->remove_planting_date($trial->get_planting_date()); }
			else { $trial->set_planting_date($planting_date); }
		}
		if ($harvest_date) {
			if ($harvest_date eq '') { $trial->remove_harvest_date($trial->get_harvest_date()); }
			else { $trial->set_harvest_date($harvest_date); }
		}
		if ($study_description) { $trial->set_description($study_description); }
		if ($field_size) { $trial->set_field_size($field_size); }
		if ($plot_width) { $trial->set_plot_width($plot_width); }
		if ($plot_length) { $trial->set_plot_length($plot_length); }
		if ($study_design_method) { $trial->set_design_type($study_design_method); }
    };

    my $data_out;
	my $total_count=0;

	my $supported_crop = $c->config->{"supportedCrop"};

    ($data_out,$total_count) = _search($self,$schema,$page_size,$page,$supported_crop,[$trial_id]);

    my %result = (data=>$data_out);

	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Studies result constructed');

}

sub format_date {

	my $str_date = shift;
	my $date;
	if ($str_date) {
		my  $formatted_time = Time::Piece->strptime($str_date, '%Y-%B-%d');
		$date =  $formatted_time->strftime("%Y-%m-%d");
	}

	return $date;
}

sub _search {
	my $self = shift;
	my $schema = shift;
	my $page_size = shift;
	my $page = shift;
	my $supported_crop = shift;
	my $study_dbids = shift;
	my $location_names = shift;
	my $location_ids = shift;
	my $study_type_list = shift;	
	my $study_names = shift;
	my $program_names = shift;
	my $program_dbids = shift;
	my $folder_dbids = shift;
	my $folder_names = shift;
	my $obs_variable_ids = shift;
	my $germplasm_dbids = shift;
	my $germplasm_names = shift;
	my $year_list = shift;
	my $sort_by = shift;
	my $sort_order = shift;

	# my $c = shift;
	my $page_obj = CXGN::Page->new();
    my $main_production_site_url = $page_obj->get_hostname();

	my $trial_search = CXGN::Trial::Search->new({
        bcs_schema=>$schema,
        location_list=>$location_names,
        location_id_list=>$location_ids,
        trial_type_list=>$study_type_list,
        # trial_type_ids=>$study_type_ids,
        trial_id_list=>$study_dbids,
        trial_name_list=>$study_names,
        trial_name_is_exact=>1,
        program_list=>$program_names,
        program_id_list=>$program_dbids,
        folder_id_list => $folder_dbids,
        folder_name_list => $folder_names,
        trait_list => $obs_variable_ids,
        accession_list => $germplasm_dbids,
        accession_name_list => $germplasm_names,
        year_list => $year_list,
        limit => $page_size,
        offset => $page_size*$page,
        sort_by => $sort_by,
        order_by => $sort_order,
        field_trials_only => 1
    });
    my ($data, $total_count) = $trial_search->search();
    #print STDERR Dumper $data;

    my @data_out;
    foreach (@$data){

        my %additional_info = (
            programDbId => qq|$_->{breeding_program_id}|,
			programName => $_->{breeding_program_name},
        );
		my @seasons = ( $_->{"year"} );

		my $planting_date;
		if ($_->{project_planting_date}) {
			$planting_date = format_date($_->{project_planting_date});
		}
		my $harvest_date;
		if ($_->{project_harvest_date}) {
			$harvest_date = format_date($_->{project_harvest_date});
		}

		my $t = CXGN::Trial->new({ bcs_schema => $self->bcs_schema, trial_id => $_->{trial_id} });
		my $contacts = $t->get_trial_contacts();
		my $brapi_contacts;
		foreach (@$contacts){
			push @$brapi_contacts, {
				contactDbId => $_->{sp_person_id},
				name => $_->{salutation}." ".$_->{first_name}." ".$_->{last_name},
                instituteName => $_->{organization},
				email => $_->{email},
				type => $_->{user_type},
				orcid => ''
			};
		}
		my $additional_files = $t->get_additional_uploaded_files();
        my @data_links;
        foreach (@$additional_files){
            push @data_links, {
                scientificType => 'Additional File',
                name => $_->[4],
                url => $main_production_site_url.'/breeders/phenotyping/download/'.$_->[0],
                provenance => undef,
                dataFormat => undef,
                description => undef,
                fileFormat => undef,
                version => undef
            };
        }

        my $phenotype_files = $t->get_phenotype_metadata();
        foreach (@$additional_files){
            push @data_links, {
                scientificType => 'Uploaded Phenotype File',
                name => $_->[4],
                url => $main_production_site_url.'/breeders/phenotyping/download/'.$_->[0],
                provenance => undef,
                dataFormat => undef,
                description => undef,
                fileFormat => undef,
                version => undef
            };
        }
        my $data_agreement = $t->get_data_agreement() ? $t->get_data_agreement() : '';

        my %data_obj = (
			active=>JSON::true,
			additionalInfo=>\%additional_info,
			commonCropName => $supported_crop,
			contacts => $brapi_contacts,
			culturalPractices => undef,
			dataLinks => \@data_links,
			documentationURL => "",
			endDate => $harvest_date ? $harvest_date :  undef ,
			environmentParameters => undef,
			experimentalDesign => qq|$_->{design}|,
			externalReferences => undef,
			growthFacility => undef,
			lastUpdate => undef,
			license => $data_agreement,
			locationDbId => $_->{location_id},
			locationName => $_->{location_name},
			observationLevels => undef,
			observationUnitsDescription => undef,
			seasons => \@seasons,
			startDate => $planting_date ? $planting_date : undef,
			studyCode => qq|$_->{trial_id}|,
            studyDbId => qq|$_->{trial_id}|,
            studyDescription => $_->{description},
			studyName => $_->{trial_name},
			studyPUI => undef,
			studyType => $_->{trial_type},
            trialDbId => qq|$_->{folder_id}|,
            trialName => $_->{folder_name},
        );
        push @data_out, \%data_obj;
    }
    return (\@data_out,$total_count);
}

sub _save_trial {
	my $self = shift;
	my $chado_schema = $self->get_chado_schema();
    my $trial_name = $self->get_trial_name();
    $trial_name =~ s/^\s+|\s+$//g; #trim whitespace from both ends

	if (!$trial_name) {
		print STDERR "Trial not saved: Can't create trial without a trial name\n";
		return { error => "Trial not saved: Can't create trial without a trial name" };
	}

    if ($self->trial_name_already_exists()) {
		print STDERR "Can't create trial: Trial name already exists\n";
		return { error => sprintf("Trial not saved: Trial name %s already exists.", $trial_name) };
	}

	if (!$self->get_breeding_program_id()) {
		print STDERR "Can't create trial: Breeding program does not exist\n";
		return { error => "Trial not saved: breeding program does not exist" };
	}

	my $geolocation;
	my $geolocation_lookup = CXGN::Location::LocationLookup->new(schema => $chado_schema);
	$geolocation_lookup->set_location_name($self->get_trial_location());
	$geolocation = $geolocation_lookup->get_geolocation();
	if (!$geolocation) {
		print STDERR "Can't create trial: Location not found\n";
		return { error => "Trial not saved: location not found" };
	}

	my $project_year_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'project year', 'project_property');
	my $project_design_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'design', 'project_property');
	my $field_size_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'field_size', 'project_property');
	my $plot_width_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot_width', 'project_property');
	my $plot_length_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot_length', 'project_property');
	my $field_trial_is_planned_to_be_genotyped_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'field_trial_is_planned_to_be_genotyped', 'project_property');
	my $field_trial_is_planned_to_cross_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'field_trial_is_planned_to_cross', 'project_property');
	my $has_plant_entries_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'project_has_plant_entries', 'project_property');
	my $has_subplot_entries_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'project_has_subplot_entries', 'project_property');
	my $trial_stock_type_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'trial_stock_type', 'project_property');

	my $project = $chado_schema->resultset('Project::Project')
	->create({
		name => $trial_name,
		description => $self->get_trial_description(),
	});

    my $t = CXGN::Project->new({
		bcs_schema => $chado_schema,
		trial_id => $project->project_id()
	});

	print STDERR "TRIAL TYPE = ".ref($t)."!!!!\n";
	my $nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'field_layout', 'experiment_type')->cvterm_id();

	my $nd_experiment = $chado_schema->resultset('NaturalDiversity::NdExperiment')
	->create({
		nd_geolocation_id => $geolocation->nd_geolocation_id(),
		type_id => $nd_experiment_type_id,
	});

    my $source_field_trial_ids = $t->set_field_trials_source_field_trials($self->get_field_trial_from_field_trial);

	$t->set_location($geolocation->nd_geolocation_id()); # set location also as a project prop
	$t->set_breeding_program($self->get_breeding_program_id);
	if ($self->get_trial_type){
		$t->set_project_type($self->get_trial_type);
	}
	if ($self->get_planting_date){
		$t->set_planting_date($self->get_planting_date);
	}
	if ($self->get_harvest_date){
		$t->set_harvest_date($self->get_harvest_date);
	}

	#link to the project
	$nd_experiment->find_or_create_related('nd_experiment_projects',{project_id => $project->project_id()});

	$project->create_projectprops({
		$project_year_cvterm->name() => $self->get_trial_year(),
		$project_design_cvterm->name() => $self->get_design_type()
	});
    if ($self->has_field_size && $self->get_field_size){
		$project->create_projectprops({
			$field_size_cvterm->name() => $self->get_field_size
		});
	}
    if ($self->has_plot_width && $self->get_plot_width){
		$project->create_projectprops({
			$plot_width_cvterm->name() => $self->get_plot_width
		});
	}
    if ($self->has_plot_length && $self->get_plot_length){
		$project->create_projectprops({
			$plot_length_cvterm->name() => $self->get_plot_length
		});
	}
    if ($self->has_trial_stock_type && $self->get_trial_stock_type){
	    $project->create_projectprops({
		    $trial_stock_type_cvterm->name() => $self->get_trial_stock_type
	    });
    }

	return { project_id => $project->project_id() };
}

1;
