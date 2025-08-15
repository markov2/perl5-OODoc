#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package OODoc::Text::Example;
use parent 'OODoc::Text';

use strict;
use warnings;

use Log::Report    'oodoc';

#--------------------
=chapter NAME

OODoc::Text::Example - one example for the use of a subroutine

=chapter SYNOPSIS

=chapter DESCRIPTION

Each OODoc::Text element can have a list of examples,
which are each captured in a separate object as described
in this manual page.

=chapter METHODS

=c_method new %options
=default type  'Example'
=cut

sub init($)
{	my ($self, $args) = @_;
	$args->{type}    ||= 'Example';
	$args->{container} = delete $args->{container} or panic;
	$self->SUPER::init($args);
}

1;
