
package CXGN::BreedersToolbox::Accessions;

=head1 NAME

CXGN::BreedersToolbox::Accessions - functions for managing accessions

=head1 USAGE

 my $accession_manager = CXGN::BreedersToolbox::Accessons->new(schema=>$schema);

=head1 DESCRIPTION


=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)

=cut

use strict;
use warnings;
use Moose;

has 'schema' => ( isa => 'Bio::Chado::Schema',
                  is => 'rw');

sub get_all_accessions { 
    my $self = shift;
    my $schema = $self->schema();

    my $accession_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
      { name   => 'accession',
      cv     => 'stock type',
      db     => 'null',
      dbxref => 'accession',
    });

    my $rs = $self->schema->resultset('Stock::Stock')->search({type_id => $accession_cvterm->cvterm_id});
    #my $rs = $self->schema->resultset('Stock::Stock')->search( { 'projectprops.type_id'=>$breeding_program_cvterm_id }, { join => 'projectprops' }  );
    my @accessions = ();



    while (my $row = $rs->next()) { 
	push @accessions, [ $row->stock_id, $row->name, $row->description ];
    }

    return \@accessions;
}

sub get_all_panels { 
    my $self = shift;
    my $schema = $self->schema();

    my $panel_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
      { name   => 'accession_panel',
      cv     => 'stock type',
      db     => 'null',
      dbxref => 'accession_panel',
    });

    my $rs = $self->schema->resultset('Stock::Stock')->search({type_id => $panel_cvterm->cvterm_id});
    #my $rs = $self->schema->resultset('Stock::Stock')->search( { 'projectprops.type_id'=>$breeding_program_cvterm_id }, { join => 'projectprops' }  );
    my @panels = ();



    while (my $row = $rs->next()) { 
	push @panels, [ $row->stock_id, $row->name, $row->description ];
    }

    return \@panels;
}

sub get_accessions_by_panel {
    my $self = shift;
    my $panel_id = shift;
    my $panels;
    $panels = $self->_get_all_accessions_by_panel($panel_id);
    return $panels;
}

sub _get_all_accessions_by_panel { 
    my $self = shift;
    my $panel_id = shift;
    my $schema = $self->schema();
    my @accessions = ();

    my $accession_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
      { name   => 'accession',
      cv     => 'stock type',
      db     => 'null',
      dbxref => 'accession',
    });

    my $panel_member_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
      { name   => 'panel_member_of',
      cv     => 'stock relationship',
      db     => 'null',
      dbxref => 'panel_member_of',
    });

    # get the panel stock object
    my $panel_stock = $self->schema->resultset("Stock::Stock")->find({stock_id => $panel_id});

    # get all related stock relatonships of type panel_member_of
    my $panel_relationships = $panel_stock->search_related("stock_relationship_subjects",{type_id => $panel_member_cvterm->cvterm_id()});
 
    if ($panel_relationships) {
	while (my $panel_relationship = $panel_relationships->next) {
	    # get the accession that is a member of the panel
	    my $panel_accession = $self->schema->resultset("Stock::Stock")->find({stock_id => $panel_relationship->subject_id()});
	    push @accessions, [ $panel_accession->stock_id, $panel_accession->name, $panel_accession->description ];
	}
    }

    return \@accessions;
}



1;
