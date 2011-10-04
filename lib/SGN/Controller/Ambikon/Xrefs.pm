package SGN::Controller::Ambikon::Xrefs;
use Moose;
use namespace::autoclean;
use SGN::View::Mason::CrossReference 'resolve_xref_component';

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

sub search_xrefs :
      ActionClass('REST')
      Path('/api/v1/feature_xrefs')
      Path('/ambikon/xrefs/search')
      Args(0) {
}

sub search_xrefs_GET {
    my ( $self, $c ) = @_;

    no warnings 'uninitialized';

    # process our query parameters to figure out what we're doing,
    # unless this has already been done by something else
    $c->stash->{xref_queries} ||= [ $c->req->param('q') ];
    $c->stash->{xref_hints}   ||= {
        render_type => $c->req->params->{'render_type'} || 'link',
        exclude     => [ split /,/, $c->req->param('exclude') ],
    };

    my $hints = $c->stash->{xref_hints};
    my $type = $hints->{render_type} || 'link';

    my $xref_set = Ambikon::XrefSet->new({ xrefs => [ map $c->feature_xrefs( $_, $hints ), @{$c->stash->{xref_queries}} ] });

    $_->tags( [ $_->feature->description || $_->feature->name ] ) for @{$xref_set->xrefs};

    $c->stash(
        template => "/ambikon/xrefs/mixed/xref_set/$type.mas",

        xrefs => $xref_set->xrefs,
        rest  => $xref_set,
       );

    if( my $renderings = $c->req->param('renderings') ) {
        my %r = map { lc $_ => 1 } ( ref $renderings eq 'ARRAY' ? @$renderings : ( $renderings ) );
        if( $r{'text/html'} ) {
            my $mason = $c->view('BareMason');

            # render the whole resultset
            $xref_set->renderings->{'text/html'} = $mason->render( $c, $c->stash->{template} );

            # and also render each individual xref
            for my $x ( @{ $xref_set->xrefs } ) {
                my $comp =
                      resolve_xref_component( $mason->interp, $x->tags, '/ambikon/xrefs/%f/xref/rich.mas' )
                   || resolve_xref_component( $mason->interp, $x->tags, '/ambikon/xrefs/%f/xref/link.mas' );

                $x->renderings->{'text/html'} = $mason->render( $c, $comp, { xref => $x } );
            }
        }
    }

}

=head1 AUTHOR

Robert Buels

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

