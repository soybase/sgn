package SGN::SiteFeatures::CrossReference::WithSeqFeatures;
use Moose::Role;

has 'seqfeatures' => (
    is        => 'ro',
    isa       => 'ArrayRef',
    predicate => 'has_seqfeatures',
   );

around 'TO_JSON' => sub {
    my ( $orig, $self ) = @_;
    my $j = $self->$orig();
    $j->{seqfeatures} = [
        map +{
            display_name => $_->name,
            primary_id   => $_->primary_id,
            start        => $_->start,
            end          => $_->end,
            seq_id       => $_->seq_id,
        },
        @{$self->seqfeatures}
    ];
    $j
};


1;
