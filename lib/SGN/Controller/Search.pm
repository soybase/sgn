package SGN::Controller::Search;

use Moose;
use namespace::autoclean;

use HTML::FormFu;
use YAML::Any qw | LoadFile |;

use CXGN::Search::CannedForms;
use CXGN::Page::Toolbar::SGN;
use CXGN::Glossary qw(get_definitions create_tooltips_from_text);

# this is suboptimal
#use CatalystX::GlobalContext qw( $c );

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

SGN::Controller::Search - SGN Search Controller

=head1 DESCRIPTION

SGN Search Controller. Most, but not all, search code interacts with this
controller. This controller defines the general search interface that used to
live at direct_search.pl, and links to all other kinds of search.

=cut

sub auto : Private {
    $_[1]->stash->{template} = '/search/stub.mas';
}

=head1 PUBLIC ACTIONS

=cut



=head2 search_index

Public path: /search/index.pl, /search/

Display a search index page.

=cut

sub search_index : Path('/search/index.pl') Path('/search') Args(0) {
    my ( $self, $c ) = @_;
    my $mode = $c->req->param("mode") || "loci";
    $c->stash->{mode} = $mode;
#    $c->stash(
#        content  => $c->view('Toolbar')->index_page('search'),
#     );
#    $c->forward('View::Mason');




    $c->stash->{template} = '/search/index.mas';
}

### search tabs

sub gene_tab :Path('/search/tabs/genes') :Arg(0) { 
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/search/tabs/genes.mas';
}



sub stock_tab :Path('/search/tabs/stock') :Arg(0) { 
    my $self = shift;
    my $c = shift;
    
    my $form = HTML::FormFu->new(LoadFile($c->path_to(qw{forms stock stock_search.yaml})));
    my $db_name = $c->config->{trait_ontology_db_name} || 'SP'; 
    $c->stash(
	form     => $form,
	schema   => $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado'),
	trait_db_name => $db_name,
	);
    $c->stash->{template} = '/search/tabs/stocks.mas';
}

sub feature_tab :Path('/search/tabs/features') :Arg(0) { 
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/search/tabs/features.mas';
}

sub transcript_tab :Path('/search/tabs/unigenes') :Arg(0) { 
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/search/tabs/unigenes.mas';
}

sub family_tab :Path('/search/tabs/families') :Arg(0) { 
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/search/tabs/families.mas';
}

sub markers_tab :Path('/search/tabs/markers') :Arg(0) { 
    my $self = shift;
    my $c = shift;
    $c->stash->{dbh} = $c->dbc->dbh();
    $c->stash->{template} = '/search/tabs/markers.mas';
}

sub bac_tab :Path('/search/tabs/bacs') :Arg(0) { 
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/search/tabs/bacs.mas';
}

sub image_tab :Path('/search/tabs/images') :Arg(0) { 
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/search/tabs/images.mas';
}

sub expression_tab :Path('/search/tabs/expression') :Arg(0) { 
    my $self = shift;
    my $c = shift;
    $c->stash->{submode} = $c->req->param("mode");
    $c->stash->{template} = '/search/tabs/expression.mas';
}

sub expression_template_tab :Path('/search/tabs/gem/expression_templates') Args(0) { 
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/search/tabs/gem/expression_templates.mas';
}

sub expression_experiment_tab : Path('/search/tabs/gem/expression_experiments') Args(0) { 
    my $self  = shift;
    my $c = shift;
    $c->stash->{template} = '/search/tabs/gem/expression_experiments.mas';
}

sub expression_platforms_tab : Path('/search/tabs/gem/expression_platforms') Args(0) { 
    my $self  = shift;
    my $c = shift;
    $c->stash->{template} = '/search/tabs/gem/expression_platforms.mas';
}

sub people_tab :Path('/search/tabs/people') :Arg(0) { 
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/search/tabs/people.mas';
}




#####
##### DEPRECATED STUFF
#####
sub family_search : Path('/search/family') Args(0) {
    $_[1]->stash->{content} = CXGN::Search::CannedForms->family_search_form();
}

sub marker_search : Path('/search/markers') Args(0) {
    my ( $self, $c ) = @_;
    my $dbh   = $c->dbc->dbh;
    my $mform = CXGN::Search::CannedForms::MarkerSearch->new($dbh);
    $c->stash->{content} =
        '<form action="/search/markers/markersearch.pl">'
        . $mform->to_html()
        . '</form>';

}

sub bac_search : Path('/search/genomic/clones') Args(0) {
    $_[1]->stash->{content} = CXGN::Search::CannedForms->clone_search_form();
}

sub directory_search : Path('/search/directory') Args(0) {
    $_[1]->stash->{content} = CXGN::Search::CannedForms->people_search_form();
}

sub gene_search : Path('/search/loci') Args(0) {
    $_[1]->stash->{content} = CXGN::Search::CannedForms->gene_search_form();
}

sub images_search : Path('/search/images') Args(0) {
    $_[1]->stash->{content} = CXGN::Search::CannedForms->image_search_form();
}


=head2 glossary

Public path: /search/glossary

Runs the glossary search.

=cut

sub glossary : Path('/search/glossary') :Args() {
    my ( $self, $c, $term ) = @_;
    my $response;
    if($term){
        my @defs = get_definitions($term);
        unless (@defs){
            $response = "<p>Your term was not found. <br> The term you searched for was $term.</p>";
        } else {
            $response = "<hr /><dl><dt>$term</dt>";
            for my $d (@defs){
                $response .= "<dd>$d</dd><br />";
            }
            $response .= "</dl>";
        }
    } else {
        $response =<<DEFAULT;
<hr />
<h2>Glossary search</h2>
<form action="#" method='get' name='glossary'>
<b>Search the glossary by term:</b>
<input type = 'text' name = 'getTerm' size = '50' tabindex='0' />
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<input type = 'submit' value = 'Lookup' /></form>
<script type="text/javascript" language="javascript">
document.glossary.getTerm.focus();
</script>

DEFAULT
    }

    $c->stash(
        content  => $response,
    );

}


=head2 old_direct_search

Public path: /search/direct_search.pl

Redirects to the new search functionality.

=cut

sub old_direct_search : Path('/search/direct_search.pl') {
    my ( $self, $c ) = @_;

    my $term = $c->req->param('search');
    # map the old direct_search param to the new scheme
    $term = {
        cvterm_name => 'qtl',

        qtl         => 'phenotypes/qtl',
        marker      => 'markers',

        # expression
        platform    => 'expression/platform',
        template    => 'expression/template',
        experiment  => 'expression/experiment',

        # transcripts
        est_library => 'transcripts/est_library',
        est         => 'transcripts/est',
        unigene     => 'transcripts/unigene',
        library     => 'transcripts/est_library',

        template_experiment_platform => 'expression',

        bacs        => 'genomic/clones',

        phenotype_qtl_trait => 'phenotypes',


    }->{$term} || $term;
    $c->res->redirect('/search/'.$term, 301 );
}



=head1 AUTHOR

Converted to Catalyst by Jonathan "Duke" Leto, then heavily refactored
by Robert Buels

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
