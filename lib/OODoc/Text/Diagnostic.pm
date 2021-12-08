# This code is part of perl distribution OODoc.  It is licensed under the
# same terms as Perl itself: https://spdx.org/licenses/Artistic-2.0.html

package OODoc::Text::Diagnostic;
use base 'OODoc::Text';

use strict;
use warnings;

use Log::Report    'oodoc';

=chapter NAME

OODoc::Text::Diagnostic - one explanation of a problem report

=chapter SYNOPSIS

=chapter DESCRIPTION

Each M<OODoc::Text::Subroutine> can have a list of warning and 
error messages, which are each captured in a separate object as described
in this manual page.

=chapter METHODS

=c_method new %options

=requires subroutine OBJECT

The subroutine in which this option lives.

=default container M<new(subroutine)>
=default type      'Diagnostic'

=cut

sub init($)
{   my ($self, $args) = @_;
    $args->{type}    ||= 'Diagnostic';
    $args->{container} = delete $args->{subroutine} or panic;

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
