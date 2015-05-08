package CXGN::Stock::AddStocks;

=head1 NAME

CXGN::Stock::AddStocks - a module to add a list of stocks.

=head1 USAGE

 my $stock_add = CXGN::Stock::AddStocks->new({ schema => $schema, stocks => \@stocks, species => $species_name, owner_name => $owner_name, accession_panel => $accession_panel_name} );
 my $validated = $stock_add->validate_stocks(); #is true when none of the stock names in the array exist in the database.
 $stock_add->add_accessions();

=head1 DESCRIPTION

Adds an array of stocks. The stock names must not already exist in the database, and the verify function does this check.   This module is intended to be used in independent loading scripts and interactive dialogs.  Stock types "accession" and "plot" are supported by the methods add_accessions() and add_plots().

=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)

=cut

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use CXGN::People::Person;

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 lazy_build => 1,
		 predicate => 'has_schema',
		);
has 'stocks' => (isa => 'ArrayRef', is => 'rw', predicate => 'has_stocks');
has 'species' => (isa => 'Str', is => 'rw', predicate => 'has_species');
has 'accession_panel' => (isa => 'Str', is => 'rw', predicate => 'has_accession_panel');
has 'owner_name' => (isa => 'Str', is => 'rw', predicate => 'has_owner_name',required => 1,);
has 'dbh' => (is  => 'rw',predicate => 'has_dbh', required => 1,);
has 'phenome_schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 predicate => 'has_phenome_schema',
		 required => 1,
		);

sub add_accessions {
  my $self = shift;
  my $added = $self->_add_stocks('accession');
  return $added;
}

sub add_plots {
  my $self = shift;
  my $added = $self->_add_stocks('plot');
  return $added;
}

sub _add_stocks {
  my $self = shift;
  my $stock_type = shift;
  if (!$self->validate_stocks()) {
    return;
  }
  my $schema = $self->get_schema();
  my $species = $self->get_species();
  my $stocks_rs = $self->get_stocks();
  my @stocks = @$stocks_rs;
  my @added_stock_ids;
  my $phenome_schema = $self->get_phenome_schema();

  print STDERR "Species: $species\n";
#  my $organism_id = $schema->resultset("Organism::Organism")
#    ->search({
#	'lower(me.species)' => {  like => '%'.lc( $species ).'%' }
#	    species => $species,
#	   } )->first()->organism_id();
#  my $organism_id = $organism->organism_id();

  #my $organism_rs = $schema->resultset('Organism::Organism')
#                                 ->search({ 'lower(species)' => { -ilike => '%'.$species.'%' }});
  #my $organism_id = $organism_rs->first({prefetch => 'organism_id'})->organism_id();
  #my $organism_id = $organism_rs->get_column('organism_id')->first();
  #my $organism = $schema->resultset("Organism::Organism")->find({species => $species});
  #my $organism_id = $organism;

#  my $s = $schema->resultset('Organism::Organism');
#  my @results = $s->search({ species => { ilike => '%'.$species.'%' }},
#                           { rows => 15 },
#                          )
#                  ->get_column('species')
#                  ->all;

  my $organism_id = 47476;

  print STDERR "Organism id: $organism_id\n";
  #my $organism_id = $organism_rs->search({ 'me.organism_id' => { -in => $organism_rs->get_column('organism_id')->as_query } });

  #lookup user by name
  my $owner_name = $self->get_owner_name();;
  my $dbh = $self->get_dbh();
  my $owner_sp_person_id = CXGN::People::Person->get_person_by_username($dbh, $owner_name); #add person id as an option.

  my $coderef = sub {

    my $stock_cvterm = $schema->resultset("Cv::Cvterm")
      ->create_with({
		     name   => $stock_type,
		     cv     => 'stock type',
		     db     => 'null',
		     dbxref => $stock_type,
		    });

    my $panel_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
      { name   => 'accession_panel',
      cv     => 'stock type',
      db     => 'null',
      dbxref => 'accession_panel',
    });

    my $panel_member_cvterm = $schema->resultset("Cv::Cvterm")->create_with({
	name   => 'panel_member_of',
	cv     => 'stock relationship',
	db     => 'null',
	dbxref => 'panel_member_of',
       });



    my $accession_panel;
    if ($self->has_accession_panel()) {
	$accession_panel = $schema->resultset("Stock::Stock")
	    ->find_or_create({
		uniquename => $self->get_accession_panel(),
		name => $self->get_accession_panel(),
		organism_id => $organism_id,
		type_id => $panel_cvterm->cvterm_id(),
		   });
	if (!$accession_panel){
	    print STDERR "Could not find accession panel $accession_panel\n";
	    return;
	}
    }

    foreach my $stock_name (@stocks) {
      my $stock = $schema->resultset("Stock::Stock")
	->create({
		  organism_id => $organism_id,
		  name       => $stock_name,
		  uniquename => $stock_name,
		  type_id     => $stock_cvterm->cvterm_id,
		 } );
      if ($accession_panel) {
	  $stock
	  ->find_or_create_related('stock_relationship_objects', {
								  type_id => $panel_member_cvterm->cvterm_id(),
								  object_id => $accession_panel->stock_id(),
								  subject_id => $stock->stock_id(),
								 } );
      }
      push (@added_stock_ids,  $stock->stock_id());
    }
  };

  my $transaction_error;
  try {
    $schema->txn_do($coderef);
  } catch {
    $transaction_error =  $_;
  };
  if ($transaction_error) {
    print STDERR "Transaction error storing stocks: $transaction_error\n";
    return;
  }

  foreach my $stock_id (@added_stock_ids) {
    #add the owner for this stock
    $phenome_schema->resultset("StockOwner")
      ->find_or_create({
			stock_id     => $stock_id,
			sp_person_id =>  $owner_sp_person_id,
		       });
  }

  return 1;
}

sub validate_stocks {
  my $self = shift;
  if (!$self->has_schema() || !$self->has_species() || !$self->has_stocks()) {
    return;
  }
  my $schema = $self->get_schema();
  my $species = $self->get_species();
  my $stocks_rs = $self->get_stocks();
  my @stocks = @$stocks_rs;

  my $name_conflicts = 0;
  foreach my $stock_name (@stocks) {
    my $stock_search = $schema->resultset("Stock::Stock")
      ->search({
		uniquename => $stock_name,
	       } );
    if ($stock_search->first()) {
      $name_conflicts++;
      print STDERR "Stock name conflict for: $stock_name\n";
    }
  }

  if ($name_conflicts > 0) {
    print STDERR "There were $name_conflicts conflict(s)\n";
    return;
  }

  return 1;
}

#######
1;
#######
