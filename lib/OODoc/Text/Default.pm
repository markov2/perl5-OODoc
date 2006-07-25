
package OODoc::Text::Default;
use base 'OODoc::Text';

use strict;
use warnings;

use Carp;

=chapter NAME

OODoc::Text::Default - one default for an option in one subroutine

=chapter SYNOPSIS

=chapter DESCRIPTION

Each M<OODoc::Text::Subroutine> can have a list of options, which have
default values which are each captured in a separate object as described
in this manual page.

=chapter METHODS

=c_method new OPTIONS

=requires subroutine OBJECT

The subroutine in which this option lives.

=requires value STRING

The value which is related to this default.

=default container M<new(subroutine)>
=default type      'Default'

=cut

sub init($)
{   my ($self, $args) = @_;
    $args->{type}    ||= 'Default';
    $args->{container} = delete $args->{subroutine} or confess;

    $self->SUPER::init($args) or return;

    $self->{OTD_value} = delete $args->{value};
    confess unless defined $self->{OTD_value};

    $self;
}

#-------------------------------------------

=section Attributes

=method subroutine

Returns the subroutine object for this option.

=cut

sub subroutine() { shift->container }

#-------------------------------------------

=method value

The value of this default.

=cut

sub value() { shift->{OTD_value} }

#-------------------------------------------

1;
