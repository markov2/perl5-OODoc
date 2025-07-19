# This code is part of perl distribution OODoc.  It is licensed under the
# same terms as Perl itself: https://spdx.org/licenses/Artistic-2.0.html

package OODoc::Text::Option;
use parent 'OODoc::Text';

use strict;
use warnings;

use Log::Report    'oodoc';

=chapter NAME

OODoc::Text::Option - one option for one subroutine

=chapter SYNOPSIS

=chapter DESCRIPTION

Each M<OODoc::Text::Subroutine> can have a list of options, which are each
captured in a separate object as described in this manual page.

=chapter METHODS

=c_method new %options

=requires subroutine OBJECT
The subroutine in which this option lives.

=requires parameters STRING
An informal short description of the valid values for this option.

=default  container M<new(subroutine)>
=default  type      'Option'

=cut

sub init($)
{   my ($self, $args) = @_;
    $args->{type}    ||= 'Option';
    $args->{container} = delete $args->{subroutine} or panic;

    $self->SUPER::init($args)
        or return;

    $self->{OTO_parameters} = delete $args->{parameters} or panic;

    $self;
}

#-------------------------------------------
=section Attributes

=method subroutine 
Returns the subroutine object for this option.
=cut

sub subroutine() { shift->container }

=method parameters 
Returns the short, informal description of the valid parameters for
this option.
=cut

sub parameters() { shift->{OTO_parameters} }

1;
