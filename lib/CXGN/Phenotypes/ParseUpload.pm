package CXGN::Phenotypes::ParseUpload;

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Module::Pluggable require => 1;

sub validate {
    my $self = shift;
    my $type = shift;
    my $filename = shift;
    my $validate_result;

    foreach my $p ($self->plugins()) {
        if ($type eq $p->name()) {
	     $validate_result = $p->validate($filename);
	}
    }
    return $validate_result;
}

sub parse {
    my $self = shift;
    my $type = shift;
    my $filename = shift;
    my $parse_result;

    foreach my $p ($self->plugins()) {
        if ($type eq $p->name()) {
	     $parse_result = $p->parse($filename);
	}
    }
    return $parse_result;
}

1;
