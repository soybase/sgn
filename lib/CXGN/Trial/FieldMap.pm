
package CXGN::Trial::FieldMap;

use CXGN::Chado::Cvterm;
use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::Trial;
use CXGN::Trial::TrialLayout;
use List::Util 'max';
use Bio::Chado::Schema;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
	is => 'rw',
	required => 1,
);

has 'trial_id' => (isa => "Int",
	is => 'rw',
);

has 'first_plot_selected' => (isa => "Int",
	is => 'rw',
);

has 'second_plot_selected' => (isa => "Int",
	is => 'rw',
);

has 'first_accession_selected' => (isa => "Str",
	is => 'rw',
);

has 'second_accession_selected' => (isa => "Str",
	is => 'rw',
);

has 'new_accession' => (isa => "Str",
	is => 'rw',
	);

has 'old_accession' => (isa => "Str",
		is => 'rw',
	);

has 'old_plot_id' => (isa => "Int",
			is => 'rw',
	);

has 'old_accession_id' => (isa => "Int",
				is => 'rw',
	);

sub display_fieldmap {
	my $self = shift;
	my $schema = $self->bcs_schema;
	my $trial_id = $self->trial_id;

	my $layout = CXGN::Trial::TrialLayout->new({
		schema => $schema,
		trial_id => $trial_id
	});

	my $design = $layout-> get_design();

#  print STDERR Dumper($design);

	my @layout_info;
	foreach my $plot_number (keys %{$design}) {
		push @layout_info, {
		plot_id => $design->{$plot_number}->{plot_id},
		plot_number => $plot_number,
		row_number => $design->{$plot_number}->{row_number},
		col_number => $design->{$plot_number}->{col_number},
		block_number=> $design->{$plot_number}-> {block_number},
		rep_number =>  $design->{$plot_number}-> {rep_number},
		plot_name => $design->{$plot_number}-> {plot_name},
		accession_name => $design->{$plot_number}-> {accession_name},
		plant_names => $design->{$plot_number}-> {plant_names},
		};
		#print STDERR Dumper(@layout_info);
	}

	my @row_numbers = ();
	my @col_numbers = ();
	my @rep_numbers = ();
	my @block_numbers = ();
	my @accession_name = ();
	my @plot_name = ();
	my @plot_id = ();
	my @acc_name = ();
	my @blk_no = ();
	my @rep_no = ();
	my @array_msg = ();
	my @plot_number = ();
	my $my_hash;

	foreach $my_hash (@layout_info) {
		if ($my_hash->{'row_number'}) {
			if ($my_hash->{'row_number'} =~ m/\d+/) {
				if (scalar(@{$my_hash->{"plant_names"}}) < 1) {
					$array_msg[$my_hash->{'row_number'}-1][$my_hash->{'col_number'}-1] = "rep_number: ".$my_hash->{'rep_number'}."\nblock_number: ".$my_hash->{'block_number'}."\nrow_number: ".$my_hash->{'row_number'}."\ncol_number: ".$my_hash->{'col_number'}."\naccession_name: ".$my_hash->{'accession_name'};
				}
				else{
					$array_msg[$my_hash->{'row_number'}-1][$my_hash->{'col_number'}-1] = "rep_number: ".$my_hash->{'rep_number'}."\nblock_number: ".$my_hash->{'block_number'}."\nrow_number: ".$my_hash->{'row_number'}."\ncol_number: ".$my_hash->{'col_number'}."\naccession_name: ".$my_hash->{'accession_name'}."\nnumber_of_plants:".scalar(@{$my_hash->{"plant_names"}});
				}

				$plot_id[$my_hash->{'row_number'}-1][$my_hash->{'col_number'}-1] = $my_hash->{'plot_id'};
				#$plot_id[$my_hash->{'plot_number'}] = $my_hash->{'plot_id'};
				$plot_number[$my_hash->{'row_number'}-1][$my_hash->{'col_number'}-1] = $my_hash->{'plot_number'};
				#$plot_number[$my_hash->{'plot_number'}] = $my_hash->{'plot_number'};
				$acc_name[$my_hash->{'row_number'}-1][$my_hash->{'col_number'}-1] = $my_hash->{'accession_name'};
				$blk_no[$my_hash->{'row_number'}-1][$my_hash->{'col_number'}-1] = $my_hash->{'block_number'};
				$rep_no[$my_hash->{'row_number'}-1][$my_hash->{'col_number'}-1] = $my_hash->{'rep_number'};
				$plot_name[$my_hash->{'row_number'}-1][$my_hash->{'col_number'}-1] = $my_hash->{'plot_name'};
			}
		}
	}
	# Looping through the hash and printing out all the hash elements.
	my @plot_numbers_not_used;
	my @plotcnt;
	foreach $my_hash (@layout_info) {
		push @col_numbers, $my_hash->{'col_number'};
		push @row_numbers, $my_hash->{'row_number'};
		#push @plot_id, $my_hash->{'plot_id'};
		push @plot_numbers_not_used, $my_hash->{'plot_number'};
		push @rep_numbers, $my_hash->{'rep_number'};
		push @block_numbers, $my_hash->{'block_number'};
		push @accession_name, $my_hash->{'accession_name'};
		#push @plot_name, $my_hash->{'plot_name'};
	}

	my $plotcounter_nu = 0;
	if ($plot_numbers_not_used[0] =~ m/^\d{3}/){
		foreach my $plot (@plot_numbers_not_used) {
			$plotcounter_nu++;
		}
		for my $n (1..$plotcounter_nu){
			push @plotcnt, $n;
		}
	}

	my @sorted_block = sort@block_numbers;
	#my @uniq_block = uniq(@sorted_block);

	my $max_col = 0;
	$max_col = max( @col_numbers ) if (@col_numbers);
	#print "$max_col\n";
	my $max_row = 0;
	$max_row = max( @row_numbers ) if (@row_numbers);
	#print "$max_row\n";
	my $max_rep = 0;
	$max_rep = max(@rep_numbers) if (@rep_numbers);
	my $max_block = 0;
	$max_block = max(@block_numbers) if (@block_numbers);

	#print STDERR Dumper \@layout_info;

	my $trial = CXGN::Trial->new({
		bcs_schema => $schema,
		trial_id => $trial_id
	});
	my $data = $trial->get_controls();

	#print STDERR Dumper($data);

	my @control_name;
	foreach my $cntrl (@{$data}) {
		push @control_name, $cntrl->{'accession_name'};
	}
	#print STDERR Dumper(@control_name);

	my %return = (
		coord_row =>  \@row_numbers,
		coords =>  \@layout_info,
		coord_col =>  \@col_numbers,
		max_row => $max_row,
		max_col => $max_col,
		plot_msg => \@array_msg,
		rep => \@rep_numbers,
		block => \@sorted_block,
		accessions => \@accession_name,
		plot_name => \@plot_name,
		plot_id => \@plot_id,
		plot_number => \@plot_number,
		max_rep => $max_rep,
		max_block => $max_block,
		sudo_plot_no => \@plotcnt,
		controls => \@control_name,
		blk => \@blk_no,
		acc => \@acc_name,
		rep_no => \@rep_no
	);
	return \%return;
}

sub delete_fieldmap {
	my $self = shift;
	my $error;
	my $trial_id = $self->trial_id;
	my $dbh = $self->bcs_schema->storage->dbh();

  my $h = $dbh->prepare("delete from stockprop where stockprop.stockprop_id IN (select stockprop.stockprop_id from project join nd_experiment_project using(project_id) join nd_experiment_stock using(nd_experiment_id) join stock using(stock_id) join stockprop on(stock.stock_id=stockprop.stock_id) where (stockprop.type_id IN (select cvterm_id from cvterm where name='col_number') or stockprop.type_id IN (select cvterm_id from cvterm where name='row_number')) and project.project_id=? and stock.type_id IN (select cvterm_id from cvterm join cv using(cv_id) where cv.name = 'stock_type' and cvterm.name ='plot'));");
  $h->execute($trial_id);
	return $error;
}

sub update_fieldmap_precheck {
	my $self = shift;
	my $error;
	my $trial_id = $self->trial_id;

	my $trial = CXGN::Trial->new({
		bcs_schema => $self->bcs_schema,
		trial_id => $trial_id
	});
	my $triat_name = $trial->get_traits_assayed();
	print STDERR Dumper($triat_name);

	if (scalar(@{$triat_name}) != 0)  {
	 $error = "One or more traits have been assayed for this trial; Map/Layout can not be modified.";
	}
	return $error;
}

sub substitute_accession_fieldmap {
	my $self = shift;
	my $error;
	my $plot_1_id = $self->first_plot_selected;
	my $plot_2_id = $self->second_plot_selected;
	my $dbh = $self->bcs_schema->storage->dbh;

	my @plot_1_objectIDs;
	my @plot_2_objectIDs;
	my $h = $dbh->prepare("select object_id from stock_relationship where subject_id=?;");
	$h->execute($plot_1_id);
	while (my $plot_1_objectID = $h->fetchrow_array()) {
		push @plot_1_objectIDs, $plot_1_objectID;
	}

	my $h1 = $dbh->prepare("select object_id from stock_relationship where subject_id=?;");
	$h1->execute($plot_2_id);
	while (my $plot_2_objectID = $h1->fetchrow_array()) {
		push @plot_2_objectIDs, $plot_2_objectID;
	}

	for (my $n=0; $n<scalar(@plot_2_objectIDs); $n++) {
		my $h2 = $dbh->prepare("update stock_relationship set object_id =? where object_id=? and subject_id=?;");
		$h2->execute($plot_1_objectIDs[$n],$plot_2_objectIDs[$n],$plot_2_id);
	}

	for (my $n=0; $n<scalar(@plot_2_objectIDs); $n++) {
		my $h2 = $dbh->prepare("update stock_relationship set object_id =? where object_id=? and subject_id=?;");
		$h2->execute($plot_2_objectIDs[$n],$plot_1_objectIDs[$n],$plot_1_id);
	}
	return $error;
}

sub replace_plot_accession_fieldMap {
	my $self = shift;
	my $error;
	my $schema = $self->bcs_schema;
	my $dbh = $self->bcs_schema->storage->dbh;
	my $new_accession = $self->new_accession;
	my $old_accession = $self->old_accession;
	my $old_plot_id = $self->old_plot_id;

	print "New Accession: $new_accession, Old Accession: $old_accession, Old Plot Id: $old_plot_id\n";

	my $new_accession_id = $schema->resultset("Stock::Stock")->search({uniquename => $new_accession})->first->stock_id();
	my $old_accession_id = $schema->resultset("Stock::Stock")->search({uniquename => $old_accession})->first->stock_id();
  print "NEWID.....: $new_accession_id and OLDID......: $old_accession_id\n";

	my $h_old_plot_id = $dbh->prepare("select object_id from stock_relationship where subject_id=?;");
	$h_old_plot_id->execute($old_plot_id);
	while (my $old_plot_objectID = $h_old_plot_id->fetchrow_array()) {

		my $h_replace = $dbh->prepare("update stock_relationship set object_id =? where object_id=? and subject_id=?;");
		$h_replace->execute($new_accession_id,$old_plot_objectID,$old_plot_id);
	}

	return $error;

}


sub replace_trial_accession_fieldMap {
	my $self = shift;
	my $error;
	my $schema = $self->bcs_schema;
	my $dbh = $self->bcs_schema->storage->dbh;
	my $new_accession = $self->new_accession;
	my $old_accession_id = $self->old_accession_id;
	my $trial_id = $self->trial_id;

	print "New Accession: $new_accession and OLD Accession: $old_accession_id\n";

	my $new_accession_id = $schema->resultset("Stock::Stock")->search({uniquename => $new_accession})->first->stock_id();
	my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type' )->cvterm_id();
	my $field_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "field_layout", "experiment_type")->cvterm_id();
	my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "plot_of", "stock_relationship")->cvterm_id();
	my $plant_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "plant_of", "stock_relationship")->cvterm_id();

	my $h_update = $dbh->prepare("update stock_relationship set object_id=? where stock_relationship_id in (SELECT stock_relationship.stock_relationship_id FROM stock as accession JOIN stock_relationship on (accession.stock_id = stock_relationship.object_id) JOIN stock as plot on (plot.stock_id = stock_relationship.subject_id) JOIN nd_experiment_stock on (plot.stock_id=nd_experiment_stock.stock_id) JOIN nd_experiment using(nd_experiment_id) JOIN nd_experiment_project using(nd_experiment_id) JOIN project using(project_id) WHERE accession.type_id =? AND stock_relationship.type_id IN ($plot_of_cvterm_id, $plant_of_cvterm_id) AND project.project_id =? and nd_experiment.type_id=?) and object_id=?;");
	$h_update->execute($new_accession_id,$accession_cvterm_id,$trial_id,$field_trial_cvterm_id,$old_accession_id);

	return $error;
}

1;
