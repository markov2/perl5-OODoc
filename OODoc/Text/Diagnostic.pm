
package OODoc::Text::Diagnostic;
use base 'OODoc::Text';

use strict;
use warnings;

use Carp;

=chapter NAME

OODoc::Text::Diagnostic - one explanation of a problem report

=chapter SYNOPSIS

=chapter DESCRIPTION

Each M<OODoc::Text::Subroutine> can have a list of warning and 
error messages, which are each captured in a separate object as described
in this manual page.

=cut

#-------------------------------------------

=chapter METHODS

=cut

#-------------------------------------------

=c_method new OPTIONS

=requires subroutine OBJECT

The subroutine in which this option lives.

=default container <subroutine>

=cut

sub init($)
{   my ($self, $args) = @_;
    $args->{type}    ||= 'Diagnostic';
    $args->{container} = delete $args->{subroutine} or confess;

    $self->SUPER::init($args) or return;

    $self;
}

#-------------------------------------------

=section Attributes

=method subroutine

Returns the subroutine object for this option.

=cut

sub subroutine() { shift->container }

#-------------------------------------------

1;
