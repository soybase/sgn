package CXGN::Pedigree::ParseUpload::Plugin::CrossInfoCSV;

use Moose::Role;
use Text::CSV;
use CXGN::List::Validate;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();

    my $delimiter = ',';
    my @error_messages;
    my %errors;

    my $csv = Text::CSV->new({ sep_char => ',' });

    open(my $fh, '<', $filename)
        or die "Could not open file '$filename' $!";

    if (!$fh) {
        push @error_messages, "Could not read file. Make sure it is a valid CSV file.";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $header_row = <$fh>;
    my @column_headers;
    if ($csv->parse($header_row)) {
        @column_headers = $csv->fields();
    } else {
        push @error_messages, "Could not parse header row. Make sure it is a valid CSV file.";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }


    my $num_cols = scalar(@column_headers);
    if ($num_cols < 4){
        push @error_messages, 'Header row must contain: "cross_name","female_parent","male_parent" and at least one column of cross info';
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    if ($column_headers[0] ne "cross_name" &&
        $column_headers[1] ne "female_parent" &&
        $column_headers[2] ne "male_parent") {
            push @error_messages, 'File contents incorrect. Header row must contain: "cross_name","female_parent","male_parent"';
            $errors{'error_messages'} = \@error_messages;
            $self->_set_parse_errors(\%errors);
            return;
        }

    my %valid_properties;
    my @properties = @{$cross_properties};
    foreach my $property(@properties){
        $valid_properties{$property} = 1;
    }

    for (my $i = 3; $i < @column_headers; $i++) {
        my $header_string = $column_headers[$i];

        if (!$valid_properties{$header_string}){
            push @error_messages, "Invalid info type: $header_string";
        }
    }

    my %seen_cross_names;
    $csv->column_names($csv->getline($fh));

    while (my $row = $csv->getline_hr($fh)){
        my @columns;
        if ($csv->parse($row)) {
            @columns = $csv->fields();
        } else {
            push @error_messages, "Could not parse row $row.";
            $errors{'error_messages'} = \@error_messages;
            $self->_set_parse_errors(\%errors);
            return;
        }

        if (!$columns[0] || $columns[0] eq ''){
            push @error_messages, 'The first column must contain cross name on row: '.$row;
        } elsif ($seen_cross_names{$column[0]}) {
            push @error_messages, 'Duplicate cross name on row: '. $row;
        } else {
            $seen_cross_names{$column[0]}++;
        }

        foreach my $header (@column_headers){
            my $value = $row->{$header}
            if ( ($header =~ m/days/  || $header =~ m/number/) && !($value =~ /^\d+?$/) ) {
              push @error_messages, "Cell $header:$row: is not a positive integer: $value";
          }
          elsif ( $header =~ m/date/ && ! $value =~ m/(\d{4})\/(\d{2})\/(\d{2})/) ) {
              push @error_messages, "Cell $header:$row: is not a valid date: $value. Dates need to be of form YYYY/MM/DD";
          }
        }
    }

    my @crosses = keys %seen_cross_names;
    my $cross_validator = CXGN::List::Validate->new();
    my @crosses_missing = @{$cross_validator->validate($schema,'crosses',\@crosses)->{'missing'}};

    if (scalar(@crosses_missing) > 0){
        push @error_messages, "The following crosses are not in the database as uniquenames or synonyms: ".join(',',@crosses_missing);
        $errors{'missing_crosses'} = \@crosses_missing;
    }

    #store any errors found in the parsed file to parse_errors accessor
    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    return 1; #returns true if validation is passed

}


sub _parse_with_plugin {
    print STDERR "Parsing genotype trial file upload\n";
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $delimiter = ',';
    my %parse_result;
    my @error_messages;
    my %errors;

    my $csv = Text::CSV->new({ sep_char => ',' });

    open(my $fh, '<', $filename)
        or die "Could not open file '$filename' $!";

    if (!$fh) {
        push @error_messages, "Could not read file. Make sure it is a valid CSV file.";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $header_row = <$fh>;
    my @column_headers;
    if ($csv->parse($header_row)) {
        @column_headers = $csv->fields();
    } else {
        push @error_messages, "Could not parse header row. Make sure it is a valid CSV file.";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    $csv->column_names($csv->getline($fh));

    while ( my $row = <$fh> ){
        my @columns;
        if ($csv->parse($row)) {
            @columns = $csv->fields();
        } else {
            push @error_messages, "Could not parse row $row.";
            $errors{'error_messages'} = \@error_messages;
            $self->_set_parse_errors(\%errors);
            return;
        }

        my $cross_name = $row->{cross_name};

        for (my $i = 3; $i < @column_headers; $i++) {
            my $info_type = $column_headers[$i];
            $parsed_result{$info_type} = $row->{$info_type};
        }
    }

    $self->_set_parsed_data(\%parsed_result);

    return 1;
}

1;
