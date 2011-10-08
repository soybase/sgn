package SGN::SiteFeatures::CrossReference::WithPreviewImage;
use Moose::Role;
use MooseX::Types::URI qw/ Uri /;

has 'preview_image_url' => ( is => 'ro', isa => Uri, coerce => 1 );

around 'TO_JSON' => sub {
    my ( $orig, $self ) = @_;
    my $j = $self->$orig();
    $j->{preview_image_url} = ''.$self->preview_image_url;
    $j
};

1;
