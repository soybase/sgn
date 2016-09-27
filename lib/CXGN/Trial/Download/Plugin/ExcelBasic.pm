package CXGN::Trial::Download::Plugin::ExcelBasic;

use Moose::Role;
use JSON;
use Data::Dumper;

sub verify {
    my $self = shift;
    return 1;
}


sub download {
    my $self = shift;

    my $schema = $self->bcs_schema();
    my $trial_id = $self->trial_id();
    my @trait_list = @{$self->trait_list()};
    my $spreadsheet_metadata = $self->file_metadata();

    my $trial = CXGN::Trial->new({bcs_schema => $schema, trial_id => $trial_id} );
    my $design_type = $trial->get_design_type();
    print STDERR $design_type."\n";

    my $workbook = Spreadsheet::WriteExcel->new($self->filename());
    my $ws = $workbook->add_worksheet();

    # generate worksheet headers
    #
    my $bold = $workbook->add_format();
    $bold->set_bold();

    my @predefined_columns;
    my $submitted_predefined_columns;
    my $json = JSON->new();
    if ($self->predefined_columns) {
        $submitted_predefined_columns = $self->predefined_columns;
        foreach (@$submitted_predefined_columns) {
            foreach my $header_predef_col (keys $_) {
                if ($_->{$header_predef_col}) {
                    push @predefined_columns, $header_predef_col;
                }
            }
        }
    }
    #print STDERR Dumper \@predefined_columns;

    my $predefined_columns_json = $json->encode(\@predefined_columns);

    $ws->write(0, 0, 'Spreadsheet ID'); $ws->write('0', '1', 'ID'.$$.time());
    $ws->write(0, 2, 'Spreadsheet format'); $ws->write(0, 3, "BasicExcel");
    $ws->write(1, 0, 'Trial name'); $ws->write(1, 1, $trial->get_name(), $bold);
    $ws->write(3, 2, 'Design Type'); $ws->write(3, 3, $design_type, $bold);
    $ws->write(2, 0, 'Description'); $ws->write(2, 1, $trial->get_description(), $bold);
    $ws->write(3, 0, "Trial location");  $ws->write(3, 1, $trial->get_location()->[1], $bold);
    $ws->write(4, 0, "Predefined Columns");  $ws->write(4, 1, $predefined_columns_json, $bold);
    $ws->write(1, 2, 'Operator');       $ws->write(1, 3, "Enter operator here");
    $ws->write(2, 2, 'Date');           $ws->write(2, 3, "Enter date here");
    $ws->data_validation(2,3, { validate => "date", criteria => '>', value=>'1000-01-01' });


    my $num_col_before_traits;
    my $line = 7;

    if ($self->data_level eq 'plots') {
        $num_col_before_traits = 6;
        my @column_headers = qw | plot_name accession_name plot_number block_number is_a_control rep_number |;
        for(my $n=0; $n<@column_headers; $n++) {
            $ws->write(6, $n, $column_headers[$n]);
        }

        my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id} );
        my $design = $trial_layout->get_design();

        if (! $design) {
            return "No design found for this trial.";
        }

        my %design = %{$design};
        my @plot_names = @{$trial_layout->get_plot_names};

        my @ordered_plots = sort { $a <=> $b} keys(%design);
        for(my $n=0; $n<@ordered_plots; $n++) {
            my %design_info = %{$design{$ordered_plots[$n]}};

            $ws->write($n+7, 0, $design_info{plot_name});
            $ws->write($n+7, 1, $design_info{accession_name});
            $ws->write($n+7, 2, $design_info{plot_number});
            $ws->write($n+7, 3, $design_info{block_number});
            $ws->write($n+7, 4, $design_info{is_a_control});
            $ws->write($n+7, 5, $design_info{rep_number});
            $line++;
        }

    } elsif ($self->data_level eq 'plants') {

        if ($design_type eq 'greenhouse') {
            $num_col_before_traits = 1;
            my @column_headers = qw | plant_name |;
            if (scalar(@predefined_columns) > 0) {
                push (@column_headers, @predefined_columns);
                $num_col_before_traits += scalar(@predefined_columns);
            }
            for(my $n=0; $n<scalar(@column_headers); $n++) {
                $ws->write(6, $n, $column_headers[$n]);
            }

            my @plants = map $_->[1], @{ $trial->get_plants() };
            @plants = sort @plants;
            print STDERR "PLANTS:" . Dumper(@plants);
            my $sample_number;
            if ($self->sample_number) {
                $sample_number = $self->sample_number;
            }
            foreach my $plant_name (@plants) {
              #  my $plant_name = $plant->[1];
                if ($sample_number) {
                    $plant_name =~ m/_plant_(\d+)/;
                    if ($1 > $sample_number) {
                        next;
                    }
                }
                $ws->write($line, 0, $plant_name);
                if (scalar(@predefined_columns) > 0) {
                    my $pre_col_ind = 1;
                    foreach (@$submitted_predefined_columns) {
                        foreach my $header_predef_col (keys $_) {
                            if ($_->{$header_predef_col}) {
                                $ws->write($line, $pre_col_ind, $_->{$header_predef_col});
                                $pre_col_ind++;
                            }
                        }
                    }
                }

                $line++;
            }
        } else {
            $num_col_before_traits = 7;
            my @column_headers = qw | plant_name plot_name accession_name plot_number block_number is_a_control rep_number |;
            if (scalar(@predefined_columns) > 0) {
                push (@column_headers, @predefined_columns);
                $num_col_before_traits += scalar(@predefined_columns);
            }
            for(my $n=0; $n<scalar(@column_headers); $n++) {
                $ws->write(6, $n, $column_headers[$n]);
            }
            my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id} );
            my $design = $trial_layout->get_design();

            if (! $design) {
                return "No design found for this trial.";
            }

            my %design = %{$design};
            my @plot_names = @{$trial_layout->get_plot_names};
            my @ordered_plots = sort { $a <=> $b} keys(%design);
            for(my $n=0; $n<@ordered_plots; $n++) {
                my %design_info = %{$design{$ordered_plots[$n]}};
                my $plant_names = $design_info{plant_names};

                my $sampled_plant_names;
                if ($self->sample_number) {
                    my $sample_number = $self->sample_number;
                    foreach (@$plant_names) {
                        if ( $_ =~ m/_plant_(\d+)/) {
                            if ($1 <= $sample_number) {
                                push @$sampled_plant_names, $_;
                            }
                        }
                    }
                } else {
                    $sampled_plant_names = $plant_names;
                }

                foreach (@$sampled_plant_names) {
                    $ws->write($line, 0, $_);
                    $ws->write($line, 1, $design_info{plot_name});
                    $ws->write($line, 2, $design_info{accession_name});
                    $ws->write($line, 3, $design_info{plot_number});
                    $ws->write($line, 4, $design_info{block_number});
                    $ws->write($line, 5, $design_info{is_a_control});
                    $ws->write($line, 6, $design_info{rep_number});

                    if (scalar(@predefined_columns) > 0) {
                        my $pre_col_ind = 7;
                        foreach (@$submitted_predefined_columns) {
                            foreach my $header_predef_col (keys $_) {
                                if ($_->{$header_predef_col}) {
                                    $ws->write($line, $pre_col_ind, $_->{$header_predef_col});
                                    $pre_col_ind++;
                                }
                            }
                        }
                    }

                    $line++;
                }
            }
        }
    }

    # write traits and format trait columns
    #
    my $lt = CXGN::List::Transform->new();

    my $transform = $lt->transform($schema, "traits_2_trait_ids", \@trait_list);

    if (@{$transform->{missing}}>0) {
    	print STDERR "Warning: Some traits could not be found. ".join(",",@{$transform->{missing}})."\n";
    }
    my @trait_ids = @{$transform->{transform}};

    my %cvinfo = ();
    foreach my $t (@trait_ids) {
        my $trait = CXGN::Trait->new( { bcs_schema=> $schema, cvterm_id => $t });
        $cvinfo{$trait->display_name()} = $trait;
        print STDERR "**** Trait = " . $trait->display_name . "\n\n";
    }

    for (my $i = 0; $i < @trait_list; $i++) {
        #if (exists($cvinfo{$trait_list[$i]})) {
            #$ws->write(5, $i+6, $cvinfo{$trait_list[$i]}->display_name());
            $ws->write(6, $i+$num_col_before_traits, $trait_list[$i]);
        #}
        #else {
        #    print STDERR "Skipping output of trait $trait_list[$i] because it does not exist\n";
        #    next;
        #}

        for (my $n = 0; $n < $line; $n++) {
            if ($cvinfo{$trait_list[$i]}) {
                my $format = $cvinfo{$trait_list[$i]}->format();
                if ($format eq "numeric") {
                    $ws->data_validation($n+7, $i+$num_col_before_traits, { validate => "any" });
                }
                elsif ($format =~ /\,/) {  # is a list
                    $ws->data_validation($n+7, $i+$num_col_before_traits, {
                        validate => 'list',
                        value    => [ split ",", $format ]
                    });
                }
            }
        }
    }

    $workbook->close();

}

1;
