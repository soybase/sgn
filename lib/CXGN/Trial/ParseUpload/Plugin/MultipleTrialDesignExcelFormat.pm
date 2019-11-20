package CXGN::Trial::ParseUpload::Plugin::MultipleTrialTrialExcelFormat;

use Moose::Role;
use Spreadsheet::ParseExcel;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::Stock::Seedlot;

sub _validate_with_plugin {
    print STDERR "Check 3.1.1 ".localtime();
  my $self = shift;
  my $filename = $self->get_filename();
  my $schema = $self->get_chado_schema();
  my %errors;
  my @error_messages;
  my %warnings;
  my @warning_messages;
  my %missing_accessions;
  my $parser   = Spreadsheet::ParseExcel->new();
  my $excel_obj;
  my $worksheet;

  #try to open the excel file and report any errors
  $excel_obj = $parser->parse($filename);
  if ( !$excel_obj ) {
    push @error_messages, $parser->error();
    $errors{'error_messages'} = \@error_messages;
    $self->_set_parse_errors(\%errors);
    return;
  }

    print STDERR "Check 3.1.2 ".localtime();

  $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
  if (!$worksheet) {
      push @error_messages, "Spreadsheet must be on 1st tab in Excel (.xls) file";
      $errors{'error_messages'} = \@error_messages;
      $self->_set_parse_errors(\%errors);
      return;
  }
  my ( $row_min, $row_max ) = $worksheet->row_range();
  my ( $col_min, $col_max ) = $worksheet->col_range();
  if (($col_max - $col_min)  < 2 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of plot data
    push @error_messages, "Spreadsheet is missing header or contains no rows";
    $errors{'error_messages'} = \@error_messages;
    $self->_set_parse_errors(\%errors);
    return;
  }

  $header_errors = parse_header($worksheet);
  foreach my $error (@{$header_errors}) {
    push @error_messages, $error;
  }

  my @treatment_names;
  for (24 .. $col_max){
      if ($worksheet->get_cell(0,$_)){
          push @treatment_names, $worksheet->get_cell(0,$_)->value();
      }
  }

  my $calendar_funcs = CXGN::Calendar->new({});
  my @pairs;
  my %seen_trial_names;
  my %seen_breeding_programs;
  my %seen_locations;
  my $seen_trial_types;
  my $seen_design_types;
  my %seen_plot_names;
  my %seen_accession_names;
  my %seen_seedlot_names;
  my %seen_plot_numbers;
  my $trial_name;
  my $breeding_program;
  my $location;
  my $trial_type;
  my $year;
  my $plot_width;
  my $plot_length;
  my $field_size;
  my $description;
  my $design_type;
  my $planting_date;
  my $harvest_date;

  for my $row ( 1 .. $row_max ) {
      #print STDERR "Check 01 ".localtime();
    my $row_name = $row+1;
    my current_trial_name;
    my $working_on_new_trial;
    my $plot_name;
    my $accession_name;
    my $seedlot_name;
    my $num_seed_per_plot = 0;
    my $weight_gram_seed_per_plot = 0;
    my $plot_number;
    my $block_number;
    my $is_a_control;
    my $rep_number;
    my $range_number;
    my $row_number;
    my $col_number;

    if ($worksheet->get_cell($row,0)) {
      $current_trial_name = $worksheet->get_cell($row,0)->value();
    } else {
        $current_trial_name = undef;
    }

    if ($current_trial_name ne $trial_name) {
      $trial_name = $current_trial_name;
      $working_on_new_trial = 1;
      if ($worksheet->get_cell($row,1)) {
          $breeding_program = $worksheet->get_cell($row,1)->value();
      } else {
          $breeding_program = undef;
      }

      if ($worksheet->get_cell($row,2)) {
        $location = $worksheet->get_cell($row,2)->value();
      } else {
          $location = undef;
      }

      if ($worksheet->get_cell($row,3)) {
        $trial_type = $worksheet->get_cell($row,3)->value();
      } else {
        $trial_type = undef;
      }

      if ($worksheet->get_cell($row,4)) {
        $year = $worksheet->get_cell($row,4)->value();
      } else {
        $year = undef;
      }

      if ($worksheet->get_cell($row,5)) {
        $plot_width = $worksheet->get_cell($row,5)->value();
      } else {
        $plot_width = undef;
      }

      if ($worksheet->get_cell($row,6)) {
        $plot_length = $worksheet->get_cell($row,6)->value();
      } else {
        $plot_length = undef;
      }

      if ($worksheet->get_cell($row,7)) {
        $field_size = $worksheet->get_cell($row,7)->value();
      } else {
        $field_size = undef;
      }

      if ($worksheet->get_cell($row,8)) {
        $description = $worksheet->get_cell($row,8)->value();
      } else {
        $description = undef;
      }

      if ($worksheet->get_cell($row,9)) {
        $design_type = $worksheet->get_cell($row,9)->value();
      } else {
        $design_type = undef;
      }

      if ($worksheet->get_cell($row,10)) {
        $planting_date = $worksheet->get_cell($row,10)->value();
      } else {
        $planting_date = undef;
      }

      if ($worksheet->get_cell($row,11)) {
        $harvest_date = $worksheet->get_cell($row,11)->value();
      } else {
        $harvest_date = undef;
      }
    }

    if ($worksheet->get_cell($row,12)) {
      $plot_name = $worksheet->get_cell($row,12)->value();
    }
    if ($worksheet->get_cell($row,13)) {
      $accession_name = $worksheet->get_cell($row,13)->value();
    }
    if ($worksheet->get_cell($row,14)) {
      $plot_number =  $worksheet->get_cell($row,14)->value();
    }
    if ($worksheet->get_cell($row,15)) {
      $block_number =  $worksheet->get_cell($row,15)->value();
    }
    if ($worksheet->get_cell($row,16)) {
      $is_a_control =  $worksheet->get_cell($row,16)->value();
    }
    if ($worksheet->get_cell($row,17)) {
      $rep_number =  $worksheet->get_cell($row,17)->value();
    }
    if ($worksheet->get_cell($row,18)) {
      $range_number =  $worksheet->get_cell($row,18)->value();
    }
    if ($worksheet->get_cell($row,19)) {
	     $row_number = $worksheet->get_cell($row,19)->value();
    }
    if ($worksheet->get_cell($row,20)) {
	     $col_number = $worksheet->get_cell($row,20)->value();
    }
    if ($worksheet->get_cell($row,21)) {
      $seedlot_name = $worksheet->get_cell($row,21)->value();
    }
    if ($worksheet->get_cell($row,22)) {
      $num_seed_per_plot = $worksheet->get_cell($row,22)->value();
    }
    if ($worksheet->get_cell($row,23)) {
      $weight_gram_seed_per_plot = $worksheet->get_cell($row,23)->value();
    }

    #skip blank lines
    if (!$trial_name && !$breeding_program && !$location && !$trial_type && !$year && !$description && !$design_type && !plot_name && !$accession_name && !$plot_number && !$block_number !$plot_name && !$accession_name && !$plot_number && !$block_number) {
      next;
    }

    print STDERR "Check 02 ".localtime();

    if ($working_on_new_trial) {

      ## TRIAL NAME CHECK
      if (!$trial_name || $trial_name eq '' ) {
          push @error_messages, "Cell A$row_name: trial_name missing.";
      }
      elsif ($trial_name =~ /\s/ ) {
          push @error_messages, "Cell A$row_name: trial_name must not contain spaces.";
      }
      elsif ($trial_name =~ /\// || $trial_name =~ /\\/) {
          push @warning_messages, "Cell A$row_name: trial_name contains slashes. Note that slashes can cause problems for third-party applications; however, plotnames can be saved with slashes.";
      } else {
          $trial_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
          $seen_trial_names{$trial_name} = $row_name;
      }

      ## BREEDING PROGRAM CHECK
      if (!$breeding_program || $breeding_program eq '' ) {
          push @error_messages, "Cell B$row_name: breeding_program missing.";
      }
      else {
        $breeding_program =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $seen_breeding_programs{$breeding_program}=$row_name;
      }

      ## LOCATION CHECK
      if (!$location || $location eq '' ) {
          push @error_messages, "Cell C$row_name: location missing.";
      }
      else {
        $location =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $seen_locations{$location}=$row_name;
      }

      ## TRIAL TYPE CHECK
      if (!$trial_type || $trial_type eq '' ) {
          push @error_messages, "Cell D$row_name: trial_type missing.";
      }
      else {
        $trial_type =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $seen_trial_types{$trial_type}=$row_name;
      }

      ## YEAR CHECK
      if (!($year =~ /^\d{4}$/)) {
          push @error_messages, "Cell E$row_name: $year is not a valid year, must be a 4 digit positive integer.";
      }

      ## PLOT WIDTH CHECK
      if ($plot_width && !($plot_width =~ /^([\d]*)([\.]?)([\d]+)$/)){
          push @error_messages, "Cell F$row_name: plot_width must be a positive number: $plot_width";
      }

      ## PLOT LENGTH CHECK
      if ($plot_length && !($plot_length =~ /^([\d]*)([\.]?)([\d]+)$/)){
          push @error_messages, "Cell G$row_name: plot_length must be a positive number: $plot_length";
      }

      ## FIELD SIZE CHECK
      if ($field_size && !($field_size =~ /^([\d]*)([\.]?)([\d]+)$/)){
          push @error_messages, "Cell H$row_name: field_size must be a positive number: $field_size";
      }

      ## DESCRIPTION CHECK
      # It's a description . . . anything goes?

      ## DESIGN TYPE CHECK
      if (!$design_type || $design_type eq '' ) {
          push @error_messages, "Cell J$row_name: design_type missing.";
      }
      else {
        $trial_type =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $seen_design_types{$design_type}=$row_name;
      }

      ## PLANTING DATE CHECK
      if (my $planting_event = $calendar_funcs->check_value_format($planting_date) ) {
      } else {
        push @error_messages, "Cell K$row_name: planting_date must be in the format YYYY-MM-DD: $planting_date";
      }

      ## HARVEST DATE CHECK
      if (my $harvest_event = $calendar_funcs->check_value_format($harvest_date) ) {
      } else {
        push @error_messages, "Cell L$row_name: harvest_date must be in the format YYYY-MM-DD: $harvest_date";
      }

      $working_on_new_trial = 0;
    }

    ## PLOT NAME CHECK
    if (!$plot_name || $plot_name eq '' ) {
        push @error_messages, "Cell M$row_name: plot name missing.";
    }
    elsif ($plot_name =~ /\s/ ) {
        push @error_messages, "Cell M$row_name: plot name must not contain spaces.";
    }
    elsif ($plot_name =~ /\// || $plot_name =~ /\\/) {
        push @warning_messages, "Cell M$row_name: plot name contains slashes. Note that slashes can cause problems for third-party applications; however, plotnames can be saved with slashes.";
    }
    else {
        $plot_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        #file must not contain duplicate plot names
        if ($seen_plot_names{$plot_name}) {
            push @error_messages, "Cell M$row_name: duplicate plot name at cell A".$seen_plot_names{$plot_name}.": $plot_name";
        }
        $seen_plot_names{$plot_name}=$row_name;
    }

      #print STDERR "Check 03 ".localtime();

    #accession name must not be blank
    if (!$accession_name || $accession_name eq '') {
      push @error_messages, "Cell N$row_name: accession name missing";
    } else {
      #accession name must exist in the database
      $accession_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
      $seen_accession_names{$accession_name}++;
    }

      #print STDERR "Check 04 ".localtime();

    #plot number must not be blank
    if (!$plot_number || $plot_number eq '') {
        push @error_messages, "Cell O$row_name: plot number missing";
    }
    #plot number must be a positive integer
    if (!($plot_number =~ /^\d+?$/)) {
        push @error_messages, "Cell O$row_name: plot number is not a positive integer: $plot_number";
    }
    #plot number must be unique in file
    if (exists($seen_plot_numbers{$plot_number})){
        push @error_messages, "Cell O$row_name: plot number must be unique in your file. You already used this plot number in row".$seen_plot_numbers{$plot_number};
    } else {
        $seen_plot_numbers{$plot_number} = $row_name;
    }

    #block number must not be blank
    if (!$block_number || $block_number eq '') {
        push @error_messages, "Cell P$row_name: block number missing";
    }
    #block number must be a positive integer
    if (!($block_number =~ /^\d+?$/)) {
        push @error_messages, "Cell P$row_name: block number is not a positive integer: $block_number";
    }
    if ($is_a_control) {
      #is_a_control must be either yes, no 1, 0, or blank
      if (!($is_a_control eq "yes" || $is_a_control eq "no" || $is_a_control eq "1" ||$is_a_control eq "0" || $is_a_control eq '')) {
          push @error_messages, "Cell Q$row_name: is_a_control is not either yes, no 1, 0, or blank: $is_a_control";
      }
    }
    if ($rep_number && !($rep_number =~ /^\d+?$/)){
        push @error_messages, "Cell R$row_name: rep_number must be a positive integer: $rep_number";
    }
    if ($range_number && !($range_number =~ /^\d+?$/)){
        push @error_messages, "Cell S$row_name: range_number must be a positive integer: $range_number";
    }
    if ($row_number && !($row_number =~ /^\d+?$/)){
        push @error_messages, "Cell T$row_name: row_number must be a positive integer: $row_number";
    }
    if ($col_number && !($col_number =~ /^\d+?$/)){
        push @error_messages, "Cell U$row_name: col_number must be a positive integer: $col_number";
    }

    if ($seedlot_name){
        $seedlot_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $seen_seedlot_names{$seedlot_name}++;
        push @pairs, [$seedlot_name, $accession_name];
    }
    if (defined($num_seed_per_plot) && $num_seed_per_plot ne '' && !($num_seed_per_plot =~ /^\d+?$/)){
        push @error_messages, "Cell W$row_name: num_seed_per_plot must be a positive integer: $num_seed_per_plot";
    }
    if (defined($weight_gram_seed_per_plot) && $weight_gram_seed_per_plot ne '' && !($weight_gram_seed_per_plot =~ /^\d+?$/)){
        push @error_messages, "Cell X$row_name: weight_gram_seed_per_plot must be a positive integer: $weight_gram_seed_per_plot";
    }

    my $treatment_col = 12;
    foreach my $treatment_name (@treatment_names){
        if($worksheet->get_cell($row,$treatment_col)){
            my $apply_treatment = $worksheet->get_cell($row,$treatment_col)->value();
            if (defined($apply_treatment) && $apply_treatment ne '1'){
                push @error_messages, "Treatment value in row $row_name should be either 1 or empty";
            }
        }
        $treatment_col++;
    }

  }

    # Add checks for seen trials, breeding_programs, locations, trial_types and design_types here

    my @accessions = keys %seen_accession_names;
    my $accession_validator = CXGN::List::Validate->new();
    my @accessions_missing = @{$accession_validator->validate($schema,'accessions',\@accessions)->{'missing'}};

    if (scalar(@accessions_missing) > 0) {
        $errors{'missing_accessions'} = \@accessions_missing;
        push @error_messages, "The following accessions are not in the database as uniquenames or synonyms: ".join(',',@accessions_missing);
    }

    my @seedlot_names = keys %seen_seedlot_names;
    if (scalar(@seedlot_names)>0){
        my $seedlot_validator = CXGN::List::Validate->new();
        my @seedlots_missing = @{$seedlot_validator->validate($schema,'seedlots',\@seedlot_names)->{'missing'}};

        if (scalar(@seedlots_missing) > 0) {
            $errors{'missing_seedlots'} = \@seedlots_missing;
            push @error_messages, "The following seedlots are not in the database: ".join(',',@seedlots_missing);
        }

        my $return = CXGN::Stock::Seedlot->verify_seedlot_accessions($schema, \@pairs);
        if (exists($return->{error})){
            push @error_messages, $return->{error};
        }
    }

    my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my @plots = keys %seen_plot_names;
    my $rs = $schema->resultset("Stock::Stock")->search({
        'type_id' => $plot_type_id,
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@plots }
    });
    while (my $r=$rs->next){
        push @error_messages, "Cell A".$seen_plot_names{$r->uniquename}.": plot name already exists: ".$r->uniquename;
    }

    if (scalar(@warning_messages) >= 1) {
        $warnings{'warning_messages'} = \@warning_messages;
        $self->_set_parse_warnings(\%warnings);
    }

    #store any errors found in the parsed file to parse_errors accessor
    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    print STDERR "Check 3.1.3 ".localtime();

    return 1; #returns true if validation is passed

}


sub _parse_with_plugin {
  my $self = shift;
  my $filename = $self->get_filename();
  my $schema = $self->get_chado_schema();
  my $parser   = Spreadsheet::ParseExcel->new();
  my $excel_obj;
  my $worksheet;
  my %design;

  $excel_obj = $parser->parse($filename);
  if ( !$excel_obj ) {
    return;
  }

  $worksheet = ( $excel_obj->worksheets() )[0];
  my ( $row_min, $row_max ) = $worksheet->row_range();
  my ( $col_min, $col_max ) = $worksheet->col_range();

  my @treatment_names;
  for (12 .. $col_max){
      if ($worksheet->get_cell(0,$_)){
          push @treatment_names, $worksheet->get_cell(0,$_)->value();
      }
  }

  my %seen_accession_names;
  for my $row ( 1 .. $row_max ) {
      my $accession_name;
      if ($worksheet->get_cell($row,1)) {
          $accession_name = $worksheet->get_cell($row,1)->value();
          $accession_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
          $seen_accession_names{$accession_name}++;
      }
  }
  my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
  my $synonym_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();

  my @accessions = keys %seen_accession_names;
  my $acc_synonym_rs = $schema->resultset("Stock::Stock")->search({
      'me.is_obsolete' => { '!=' => 't' },
      'stockprops.value' => { -in => \@accessions},
      'me.type_id' => $accession_cvterm_id,
      'stockprops.type_id' => $synonym_cvterm_id
  },{join => 'stockprops', '+select'=>['stockprops.value'], '+as'=>['synonym']});
  my %acc_synonyms_lookup;
  while (my $r=$acc_synonym_rs->next){
      $acc_synonyms_lookup{$r->get_column('synonym')}->{$r->uniquename} = $r->stock_id;
  }

  for my $row ( 1 .. $row_max ) {
    my $plot_name;
    my $accession_name;
    my $plot_number;
    my $block_number;
    my $is_a_control;
    my $rep_number;
    my $range_number;
    my $row_number;
    my $col_number;
    my $seedlot_name;
    my $num_seed_per_plot = 0;
    my $weight_gram_seed_per_plot = 0;

    if ($worksheet->get_cell($row,0)) {
      $plot_name = $worksheet->get_cell($row,0)->value();
    }
    $plot_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
    if ($worksheet->get_cell($row,1)) {
      $accession_name = $worksheet->get_cell($row,1)->value();
    }
    $accession_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
    if ($worksheet->get_cell($row,2)) {
      $plot_number =  $worksheet->get_cell($row,2)->value();
    }
    if ($worksheet->get_cell($row,3)) {
      $block_number =  $worksheet->get_cell($row,3)->value();
    }
    if ($worksheet->get_cell($row,4)) {
      $is_a_control =  $worksheet->get_cell($row,4)->value();
    }
    if ($worksheet->get_cell($row,5)) {
      $rep_number =  $worksheet->get_cell($row,5)->value();
    }
    if ($worksheet->get_cell($row,6)) {
      $range_number =  $worksheet->get_cell($row,6)->value();
    }
    if ($worksheet->get_cell($row,7)) {
	     $row_number = $worksheet->get_cell($row, 7)->value();
    }
    if ($worksheet->get_cell($row,8)) {
	     $col_number = $worksheet->get_cell($row, 8)->value();
    }
    if ($worksheet->get_cell($row,9)) {
        $seedlot_name = $worksheet->get_cell($row, 9)->value();
    }
    if ($seedlot_name){
        $seedlot_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
    }
    if ($worksheet->get_cell($row,10)) {
        $num_seed_per_plot = $worksheet->get_cell($row, 10)->value();
    }
    if ($worksheet->get_cell($row,11)) {
        $weight_gram_seed_per_plot = $worksheet->get_cell($row, 11)->value();
    }

    #skip blank lines
    if (!$plot_name && !$accession_name && !$plot_number && !$block_number) {
      next;
    }

    my $treatment_col = 12;
    foreach my $treatment_name (@treatment_names){
        if($worksheet->get_cell($row,$treatment_col)){
            if($worksheet->get_cell($row,$treatment_col)->value()){
                push @{$design{treatments}->{$treatment_name}}, $plot_name;
            }
        }
        $treatment_col++;
    }

    if ($acc_synonyms_lookup{$accession_name}){
        my @accession_names = keys %{$acc_synonyms_lookup{$accession_name}};
        if (scalar(@accession_names)>1){
            print STDERR "There is more than one uniquename for this synonym $accession_name. this should not happen!\n";
        }
        $accession_name = $accession_names[0];
    }

    my $key = $row;
    $design{$key}->{plot_name} = $plot_name;
    $design{$key}->{stock_name} = $accession_name;
    $design{$key}->{plot_number} = $plot_number;
    $design{$key}->{block_number} = $block_number;
    if ($is_a_control) {
      $design{$key}->{is_a_control} = 1;
    } else {
      $design{$key}->{is_a_control} = 0;
    }
    if ($rep_number) {
      $design{$key}->{rep_number} = $rep_number;
    }
    if ($range_number) {
      $design{$key}->{range_number} = $range_number;
    }
    if ($row_number) {
	     $design{$key}->{row_number} = $row_number;
    }
    if ($col_number) {
	     $design{$key}->{col_number} = $col_number;
    }
    if ($seedlot_name){
        $design{$key}->{seedlot_name} = $seedlot_name;
        $design{$key}->{num_seed_per_plot} = $num_seed_per_plot;
        $design{$key}->{weight_gram_seed_per_plot} = $weight_gram_seed_per_plot;
    }

  }
  #print STDERR Dumper \%design;
  $self->_set_parsed_data(\%design);

  return 1;

}

sub parse_header() {
  #get column headers
  my $trial_name_head;
  my $breeding_program_head;
  my $location_head;
  my $trial_type_head;
  my $year_head;
  my $plot_width_head;
  my $plot_length_head;
  my $field_size_head;
  my $description_head;
  my $design_type_head;
  my $planting_date_head;
  my $harvest_date_head;
  my $plot_name_head;
  my $accession_name_head;
  my $seedlot_name_head;
  my $num_seed_per_plot_head;
  my $weight_gram_seed_per_plot_head;
  my $plot_number_head;
  my $block_number_head;
  my $is_a_control_head;
  my $rep_number_head;
  my $range_number_head;
  my $row_number_head;
  my $col_number_head;

  if ($worksheet->get_cell(0,0)) {
    $trial_name_head= $worksheet->get_cell(0,0)->value();
  }
  if ($worksheet->get_cell(0,1)) {
    $breeding_program_head= $worksheet->get_cell(0,1)->value();
  }
  if ($worksheet->get_cell(0,2)) {
    $location_head= $worksheet->get_cell(0,2)->value();
  }
  if ($worksheet->get_cell(0,3)) {
    $trial_type_head= $worksheet->get_cell(0,3)->value();
  }
  if ($worksheet->get_cell(0,4)) {
    $year_head= $worksheet->get_cell(0,4)->value();
  }
  if ($worksheet->get_cell(0,5)) {
    $plot_width_head= $worksheet->get_cell(0,5)->value();
  }
  if ($worksheet->get_cell(0,6)) {
    $plot_length_head= $worksheet->get_cell(0,6)->value();
  }
  if ($worksheet->get_cell(0,7)) {
    $field_size_head= $worksheet->get_cell(0,7)->value();
  }
  if ($worksheet->get_cell(0,8)) {
    $description_head= $worksheet->get_cell(0,8)->value();
  }
  if ($worksheet->get_cell(0,9)) {
    $design_type_head= $worksheet->get_cell(0,9)->value();
  }
  if ($worksheet->get_cell(0,10)) {
    $planting_date_head= $worksheet->get_cell(0,10)->value();
  }
  if ($worksheet->get_cell(0,11)) {
    $harvest_date_head= $worksheet->get_cell(0,11)->value();
  }
  if ($worksheet->get_cell(0,12)) {
    $plot_name_head  = $worksheet->get_cell(0,12)->value();
  }
  if ($worksheet->get_cell(0,13)) {
    $accession_name_head  = $worksheet->get_cell(0,13)->value();
  }
  if ($worksheet->get_cell(0,14)) {
    $plot_number_head  = $worksheet->get_cell(0,14)->value();
  }
  if ($worksheet->get_cell(0,15)) {
    $block_number_head  = $worksheet->get_cell(0,15)->value();
  }
  if ($worksheet->get_cell(0,16)) {
    $is_a_control_head  = $worksheet->get_cell(0,16)->value();
  }
  if ($worksheet->get_cell(0,17)) {
    $rep_number_head  = $worksheet->get_cell(0,17)->value();
  }
  if ($worksheet->get_cell(0,18)) {
    $range_number_head  = $worksheet->get_cell(0,18)->value();
  }
  if ($worksheet->get_cell(0,19)) {
      $row_number_head  = $worksheet->get_cell(0,19)->value();
  }
  if ($worksheet->get_cell(0,20)) {
      $col_number_head  = $worksheet->get_cell(0,20)->value();
  }
  if ($worksheet->get_cell(0,21)) {
    $seedlot_name_head  = $worksheet->get_cell(0,21)->value();
  }
  if ($worksheet->get_cell(0,22)) {
    $num_seed_per_plot_head = $worksheet->get_cell(0,22)->value();
  }
  if ($worksheet->get_cell(0,23)) {
    $weight_gram_seed_per_plot_head = $worksheet->get_cell(0,23)->value();
  }

  my @error_messages = [];

  if (!$trial_name_head || $trial_name_head ne 'trial_name' ) {
    push @error_messages, "Cell A1: trial_name is missing from the header";
  }
  if (!$breeding_program_head || $breeding_program_head ne 'breeding_program' ) {
    push @error_messages, "Cell B1: breeding_program is missing from the header";
  }
  if (!$location_head || $location_head ne 'location' ) {
    push @error_messages, "Cell C1: location is missing from the header";
  }
  if (!$trial_type_head || $trial_type_head ne 'trial_type' ) {
    push @error_messages, "Cell D1: trial_type is missing from the header";
  }
  if (!$year_head || $year_head ne 'year' ) {
    push @error_messages, "Cell E1: year is missing from the header";
  }
  if (!$plot_width_head || $plot_width_head ne 'plot_width' ) {
    push @error_messages, "Cell F1: plot_width is missing from the header";
  }
  if (!$plot_length_head || $plot_length_head ne 'plot_length' ) {
    push @error_messages, "Cell G1: plot_length is missing from the header";
  }
  if (!$field_size_head || $field_size_head ne 'field_size' ) {
    push @error_messages, "Cell H1: field_size is missing from the header";
  }
  if (!$description_head || $description_head ne 'description' ) {
    push @error_messages, "Cell I1: description is missing from the header";
  }
  if (!$design_type_head || $design_type_head ne 'design_type' ) {
    push @error_messages, "Cell J1: design_type is missing from the header";
  }
  if (!$planting_date_head || $planting_date_head ne 'planting_date' ) {
    push @error_messages, "Cell K1: planting_date is missing from the header";
  }
  if (!$harvest_date_head || $harvest_date_head ne 'harvest_date' ) {
    push @error_messages, "Cell L1: harvest_date is missing from the header";
  }
  if (!$plot_name_head || $plot_name_head ne 'plot_name' ) {
    push @error_messages, "Cell M1: plot_name is missing from the header";
  }
  if (!$accession_name_head || $accession_name_head ne 'accession_name') {
    push @error_messages, "Cell N1: accession_name is missing from the header";
  }
  if (!$plot_number_head || $plot_number_head ne 'plot_number') {
    push @error_messages, "Cell O1: plot_number is missing from the header";
  }
  if (!$block_number_head || $block_number_head ne 'block_number') {
    push @error_messages, "Cell P1: block_number is missing from the header";
  }
  if (!$is_a_control_head || $is_a_control_head ne 'is_a_control') {
    push @error_messages, "Cell Q1: is_a_control is missing from the header. (Header is required, but values are optional)";
  }
  if (!$rep_number_head || $rep_number_head ne 'rep_number') {
    push @error_messages, "Cell R1: rep_number is missing from the header. (Header is required, but values are optional)";
  }
  if (!$range_number_head || $range_number_head ne 'range_number') {
    push @error_messages, "Cell S1: range_number is missing from the header. (Header is required, but values are optional)";
  }
  if (!$row_number_head || $row_number_head ne 'row_number') {
    push @error_messages, "Cell T1: row_number is missing from the header. (Header is required, but values are optional)";
  }
  if (!$col_number_head || $col_number_head ne 'col_number') {
    push @error_messages, "Cell U1: col_number is missing from the header. (Header is required, but values are optional)";
  }
  if (!$seedlot_name_head || $seedlot_name_head ne 'seedlot_name') {
    push @error_messages, "Cell V1: seedlot_name is missing from the header. (Header is required, but values are optional)";
  }
  if (!$num_seed_per_plot_head || $num_seed_per_plot_head ne 'num_seed_per_plot') {
    push @error_messages, "Cell W1: num_seed_per_plot is missing from the header. (Header is required, but values are optional)";
  }
  if (!$weight_gram_seed_per_plot_head || $weight_gram_seed_per_plot_head ne 'weight_gram_seed_per_plot') {
    push @error_messages, "Cell X1: weight_gram_seed_per_plot is missing from the header. (Header is required, but values are optional)";
  }

  return \@error_messages;

}


1;
