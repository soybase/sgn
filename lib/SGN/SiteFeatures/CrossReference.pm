package SGN::SiteFeatures::CrossReference;
use Moose;

use MooseX::Aliases;
use List::MoreUtils ();

extends 'Ambikon::Xref';

around BUILDARGS => sub {
      my $orig  = shift;
      my $class = shift;
      my $args = $class->$orig(@_);
      if( $args->{feature} && !$args->{subsite} ) {
          $args->{subsite} = delete $args->{feature};
      }
      if( $args->{subsite} && !$args->{tags} ) {
          $args->{tags} = [
              List::MoreUtils::uniq
              grep defined,
              $args->{subsite}->description,
              $args->{subsite}->name,
              $args->{subsite}->shortname,
          ];
      }
      return $args;
  };

alias 'feature' => 'subsite';

# alias xref_cmp to cr_cmp for backcompat
alias 'cr_cmp' => 'xref_cmp';

# alias xref_eq to cr_eq for backcompat
alias 'cr_eq' => 'xref_eq';


__PACKAGE__->meta->make_immutable;
1;

