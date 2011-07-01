use strict;
use warnings;
use Test::More;

use lib 't/lib';
use SGN::Test::WWW::Mechanize skip_cgi => 1;

my $mech = SGN::Test::WWW::Mechanize->new;
$mech->get_ok(
    '/api/v1/feature_xrefs?q=Solyc05g005010',
    { 'Content-Type' => 'text/html' },
    'feature_xrefs requests should succeed' );

diag $mech->content;


done_testing;
