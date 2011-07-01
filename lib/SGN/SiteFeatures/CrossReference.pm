package SGN::SiteFeatures::CrossReference;
use Moose;

use MooseX::Aliases;

extends 'Ambikon::Xref';

around BUILDARGS => sub {
      my $orig  = shift;
      my $class = shift;
      my $args = $class->$orig(@_);
      if( $args->{feature} && !$args->{subsite} ) {
          $args->{subsite} = delete $args->{feature};
      }
      return $args;
  };

alias 'feature' => 'subsite';

# alias xref_cmp to cr_cmp for backcompat
alias 'cr_cmp' => 'xref_cmp';

# alias xref_eq to cr_eq for backcompat
alias 'cr_eq' => 'xref_eq';



1;

