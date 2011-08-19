package SGN::Controller::Ambikon::Xrefs;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'text/html',
    stash_key => 'rest',
    map       => {
        'text/html' => [ 'View', 'BareMason' ],
    },
   );

=head1 NAME

SGN::Controller::Ambikon::Xrefs - controller for emitting Ambikon
xrefs with the Ambikon subsite web service API

=head1 PUBLIC ACTIONS

=head2 search_xrefs

Public paths: /ambikon/xrefs/search /api/v1/feature_xrefs

Ambikon-compatible web service interface to C<$c-E<gt>feature_xrefs>.
Depending on the requested Content-Type, will return HTML, JSON, etc,
for the xrefs.

=cut

sub search_xrefs : Path('/api/v1/feature_xrefs') Path('/ambikon/xrefs/search') :Args(0) {
    my ( $self, $c ) = @_;

    no warnings 'uninitialized';

    my $type = $c->req->param('render_type') || 'link';

    my $args = {};
    if( my @exclude = split /,/, $c->req->param('exclude') ) {
        $args->{exclude} = \@exclude;
    }

    my $xrefs = [ map $c->feature_xrefs( $_, $args ), $c->req->param('q') ];
    $c->stash(
        template => "/ambikon/xrefs/mixed/xref_set/$type.mas",

        xrefs => $xrefs,
        rest  => $xrefs,
       );
}

=head1 AUTHOR

Robert Buels

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

