# This code is part of perl distribution OODoc.  It is licensed under the
# same terms as Perl itself: https://spdx.org/licenses/Artistic-2.0.html

package OODoc::Text::Example;
use base 'OODoc::Text';

use strict;
use warnings;

use Log::Report    'oodoc';

=chapter NAME

OODoc::Text::Example - one example for the use of a subroutine

=chapter SYNOPSIS

=chapter DESCRIPTION

Each M<OODoc::Text> element can have a list of examples,
which are each captured in a separate object as described
in this manual page.

=chapter METHODS

=c_method new %options

=default type  'Example'

=cut

sub init($)
{   my ($self, $args) = @_;
    $args->{type}    ||= 'Example';
    $args->{container} = delete $args->{container} or panic;

    $self->SUPER::init($args)
        or return;

    $self;
}

1;
