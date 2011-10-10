use strict;
use warnings;

use Test::More;

use JSON ();
my $json = JSON->new;

use lib 't/lib';
use SGN::Test::WWW::Mechanize;

my $mech =  SGN::Test::WWW::Mechanize->new;

$mech->get_ok( '/ambikon/xrefs/search?q=Solyc03g063760&content-type=text/html&renderings=text/html&render_type=rich' );
$mech->content_contains('gene feature details');
$mech->content_contains('href="/feature');
$mech->content_contains('Tomato locus');
$mech->content_contains('<a ');


$mech->get_ok( '/ambikon/xrefs/search?q=Solyc03g063760&content-type=application/json&renderings=text/html&render_type=rich' );
my $data = $json->decode( $mech->content );
is( $data->{xrefs}[0]{is_empty}, 0 );

done_testing;
