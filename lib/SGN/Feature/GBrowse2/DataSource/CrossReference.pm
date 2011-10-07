package SGN::Feature::GBrowse2::DataSource::CrossReference;
use Moose;
use MooseX::Types::URI qw/ Uri /;
extends 'SGN::SiteFeatures::CrossReference';

with 'SGN::SiteFeatures::CrossReference::WithPreviewImage',
     'SGN::SiteFeatures::CrossReference::WithSeqFeatures';

has 'data_source' => ( is => 'ro', required => 1 );

has 'is_whole_sequence' => (
    is => 'ro',
    isa => 'Bool',
    documentation => 'true if this cross-reference points to the entire reference sequence',
    );

has 'seq_id' => (
    is  => 'ro',
    isa => 'Str',
    );

has $_ => ( is => 'ro', isa => 'Int' )
  for 'start', 'end';

__PACKAGE__->meta->make_immutable;
1;
