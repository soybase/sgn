
package SGN::Controller::BreedersToolbox::Genotypes;

use Moose;

BEGIN { extends "Catalyst::Controller"; }

sub index : Path('/breeders/genotypes') { 
    my $self = shift;
    my $c = shift;
    
    $c->stash->{template} = '/breeders_toolbox/genotyping/index.mas';
}

1;
