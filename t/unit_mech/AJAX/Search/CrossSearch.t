
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;

use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;
my $response;


$mech->post_ok('http://localhost:3010/ajax/search/pedigree_male_parents',["pedigree_female_parent" => "test_accession4"] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data' => [
['test_accession5']
]},'male parent search');

$mech->post_ok('http://localhost:3010/ajax/search/progenies',["pedigree_female_parent" => "test_accession4","pedigree_male_parent" => "test_accession5"] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data' => [['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38846/view">new_test_crossP001</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38847/view">new_test_crossP002</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38848/view">new_test_crossP003</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38849/view">new_test_crossP004</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38850/view">new_test_crossP005</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38851/view">new_test_crossP006</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38852/view">new_test_crossP007</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38853/view">new_test_crossP008</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38854/view">new_test_crossP009</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38855/view">new_test_crossP010</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38873/view">test5P001</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38874/view">test5P002</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38875/view">test5P003</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38876/view">test5P004</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38877/view">test5P005</a>', undef]]}, 'progeny search');

$mech->post_ok('http://localhost:3010/ajax/search/progenies',["pedigree_female_parent" => "test_accession4"] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data' => [['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38846/view">new_test_crossP001</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38847/view">new_test_crossP002</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38848/view">new_test_crossP003</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38849/view">new_test_crossP004</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38850/view">new_test_crossP005</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38851/view">new_test_crossP006</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38852/view">new_test_crossP007</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38853/view">new_test_crossP008</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38854/view">new_test_crossP009</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38855/view">new_test_crossP010</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38873/view">test5P001</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38874/view">test5P002</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38875/view">test5P003</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38876/view">test5P004</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38877/view">test5P005</a>', undef]]}, 'all progeny search');


$mech->post_ok('http://localhost:3010/ajax/search/cross_male_parents',["female_parent" => "TestAccession1"] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data' => [
['TestAccession1'],
['TestAccession2'],
['TestAccession3'],
['TestAccession4'],
['TestPopulation1'],
['TestPopulation2']
]},'male parent search');


done_testing();
