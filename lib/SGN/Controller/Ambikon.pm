package SGN::Controller::Ambikon;
use Moose;

BEGIN { extends 'Catalyst::Controller' }

use Ambikon::ServerHandle;

=head1 NAME

SGN::Controller::Ambikon - support for running the SGN app as an
Ambikon subsite.

=head1 PUBLIC ACTIONS

=head2 theme_template

Public path: /ambikon/theme_template

Serves a bare page with no content, suitable for use by Ambikon
theming postprocessors that consume the
L<Ambikon::IntegrationServer::Role::TemplateTheme> role.

=cut

sub theme_template : Path('/ambikon/theme_template') {
    my ( $self, $c ) = @_;
    $c->stash->{template} = '/ambikon/theme_template.mas';
}

=head1 PRIVATE ACTIONS

=head2 server

Returns the L<Ambikon::ServerHandle> for the current Ambikon Integration Server
(AIS) in use.  Also stashes it in C<< $c->stash->{ambikon_server} >>.
Returns nothing if not running under an AIS.

=cut

sub server : Private {
    my ( $self, $c, $server_url ) = @_;

    if( my $u = $c->req->header('X-Ambikon-Server-Url') ) {
        $server_url ||= $u;
    }

    return if not $server_url;

    return $c->stash->{ambikon_server} =
        Ambikon::ServerHandle->new( base_url => $server_url );
}

=head2 search_xrefs

Shortcut to call the search_xrefs method on the server handle returned
by server() above.

=cut

sub search_xrefs : Private {
    my ( $self, $c, @args ) = @_;
    $self->server( $c )->search_xrefs( @args );
}

1;
