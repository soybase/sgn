package SGN::Feature::GBrowse::DataSource;
use Moose;
use namespace::autoclean;
use Carp;
use MooseX::Types::Path::Class;
use URI;
use URI::Escape;
use URI::QueryParam;

use Bio::Graphics::FeatureFile;

with 'Ambikon::Role::Serializable';


has 'name' => ( documentation => <<'',
name of the data source

    is  => 'ro',
    isa => 'Str',
    required => 1,
  );

has 'description' => ( documentation => <<'',
short description of this data source - one line

    is => 'ro',
    isa => 'Str',
    required => 1,
  );

has 'extended_description' => ( documentation => <<'',
fuller description of this data source, 1-2 sentences

    is => 'ro',
    isa => 'Maybe[Str]',
  );

has 'organism' => ( documentation => <<'',
string name of the organism(s) the *reference sequences* for this set
are from.  Usually species name.

    is => 'ro',
    isa => 'Maybe[Str]',
  );

has 'gbrowse' => ( documentation => <<'',
GBrowse Feature object this data source belongs to

    is => 'ro',
    weak_ref => 1,
  );

has 'path' => ( documentation => <<'',
absolute path to the data source's config file

    is  => 'ro',
    isa => 'Path::Class::File',
    required => 1,
    coerce => 1,
   );

has 'config' => ( documentation => <<'',
the parsed config of this data source, a Bio::Graphics::FeatureFile

    is  => 'ro',
    isa => 'Bio::Graphics::FeatureFile',
    lazy_build => 1,
   ); sub _build_config {
       Bio::Graphics::FeatureFile->new(
           -file => shift->path->stringify,
           -safe => 1,
          );
   }

has '_databases' => (
    is => 'ro',
    isa => 'HashRef',
    traits => ['Hash'],
    lazy_build => 1,
    handles => {
        databases => 'values',
        database  => 'get',
    },
   ); sub _build__databases {
       die 'database parsing not implemented for gbrowse 1.x';
   }


sub view_url {
    shift->_url( 'gbrowse', @_ );
}

sub image_url {
    my ( $self, $q ) = @_;
    $q ||= {};
    $q->{width}    ||= 600;
    $q->{keystyle} ||= 'between',
    $q->{grid}     ||= 'on',
    return $self->_url( 'gbrowse_img', $q );
}

sub _url {
    my ( $self, $script, $query ) = @_;
    if( my $gbrowse = $self->gbrowse ) {
        my $url = $gbrowse->cgi_url->clone;
        $url->path( join '', map "$_/", $url->path, $script, $self->name );
        $url->query_form_hash( $query ) if $query;
        return $url;
    }
    return;
}


sub TO_JSON {
    my $self = shift;
    no strict 'refs';
    return {
        map {
            $_ => ''.$self->$_()
        } qw (
            name
            description
            extended_description
            organism
            path
            image_url
            view_url
        )
    };
};

__PACKAGE__->meta->make_immutable;
1;
