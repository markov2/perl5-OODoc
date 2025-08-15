#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package OODoc::Text::Diagnostic;
use parent 'OODoc::Text';

use strict;
use warnings;

use Log::Report    'oodoc';

#--------------------
=chapter NAME

OODoc::Text::Diagnostic - one explanation of a problem report

=chapter SYNOPSIS

=chapter DESCRIPTION

Each OODoc::Text::Subroutine can have a list of warning and
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
{	my ($self, $args) = @_;
	$args->{type}    ||= 'Diagnostic';
	$args->{container} = delete $args->{subroutine} or panic;
	$self->SUPER::init($args);
}

sub publish($)
{	my ($self, $args) = @_;
	my $exporter = $args->{exporter};

	my $p = $self->SUPER::publish($args);
	$p->{subroutine} = $self->subroutine->unique;
	$p;
}

#--------------------
=section Attributes

=method subroutine
Returns the subroutine object for this option.
=cut

sub subroutine() { $_[0]->container }

1;
