package SGN::View::Mason::CrossReference;
use strict;
use warnings;

use Carp;

use base 'Exporter';
our @EXPORT_OK = qw( resolve_xref_component );

sub resolve_xref_component {
    my ( $m, $tags, $comp_pattern ) = @_;

    my @tags = ref $tags ? @$tags : ( $tags );
    tr/A-Z /a-z_/ for @tags; # lowercase and replace spaces with underscores

    for my $fname ( @tags, 'default' ) {
        my $comp = $comp_pattern;
        $comp =~ s/(?<!%)%f/$fname/g;

        return $comp if $m->comp_exists( $comp );
    }

    return;
}


1;
