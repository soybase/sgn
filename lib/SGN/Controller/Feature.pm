package SGN::Controller::Feature;

=head1 NAME

SGN::Controller::Feature - Catalyst controller for pages dealing with
Chado (i.e. Bio::Chado::Schema) features

=cut

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

=head1 PUBLIC ACTIONS

=cut

# deprecated old paths are now redirects
sub view_by_name :Path('/feature/view/name') Path('/feature/view/id') Args(1) {
    my ( $self, $c, $id ) = @_;
    $c->res->redirect("/feature/$id/details",301);
}

#######################################

sub feature_details :PathPart('details') :Chained('get_feature') Args(0) {
    my ( $self, $c ) = @_;

       $c->forward('get_type_specific_data')
    && $c->forward('choose_view');
}

sub choose_view :Private {
    my ( $self, $c ) = @_;
    my $feature   = $c->stash->{feature};
    my $type_name = lc $feature->type->name;
    my $template  = "/feature/types/default.mas";

    $c->stash->{feature}     = $feature;
    $c->stash->{featurelocs} = $feature->featureloc_features;

    # look up xrefs for this feature
    $c->stash->{xrefs} = $c->forward(
        '/ambikon/search_xrefs',
        # look up xrefs for:
        [ queries => [
            # the feature's name
            $feature->name,
            # all the feature's synonyms
            $feature->synonyms->get_column('name')->all,
            # and all the feature's locations (formatted as strings)
            ( map {
                $_->srcfeature->name.':'.($_->fmin+1).'..'.$_->fmax
              }
              $c->stash->{featurelocs}->all
            ),
          ],
          hints => {
              renderings  => 'text/html',
              exclude     => 'featurepages',
              render_type => 'rich',
          },
        ],
      );

    if ($c->view('Mason')->component_exists("/feature/types/$type_name.mas")) {
        $template         = "/feature/types/$type_name.mas";
        $c->stash->{type} = $type_name;
    }
    $c->stash->{template} = $template;

    return 1;
}

sub get_feature : Chained('/') CaptureArgs(1) PathPart('feature') {
    my ($self, $c, $id ) = @_;

    $c->stash->{blast_url} = '/tools/blast/index.pl';

    my $identifier_type = $c->stash->{identifier_type}
        || $id =~ /[^-\d]/ ? 'name' : 'feature_id';

    if( $identifier_type eq 'feature_id' ) {
        $id > 0
            or $c->throw_client_error( public_message => 'Feature ID must be a positive integer.' );
    }

    my $matching_features =
        $c->dbic_schema('Bio::Chado::Schema','sgn_chado')
          ->resultset('Sequence::Feature')
          ->search(
              { 'me.'.$identifier_type => $id },
              { prefetch => [ 'organism', 'type', 'featureloc_features'  ] },
            );

    if( $matching_features->count > 1 ) {
        $c->throw_client_error( public_message => 'Multiple matching features' );
    }

    my ( $feature ) = $matching_features->all;
    $c->stash->{feature} = $feature
        or $c->throw_404( "Feature not found" );

    return 1;
}

sub get_type_specific_data :Private {
    my ( $self, $c ) = @_;

    my $type_name = $c->stash->{feature}->type->name;

    # look for an action with private path /feature/types/<type>/get_specific_data
    my $action = $c->get_action( 'get_specific_data', $self->action_namespace."/types/$type_name" );
    if( $action ) {
        $c->forward( $action ) or return;
    }

    return 1;
}

1;
