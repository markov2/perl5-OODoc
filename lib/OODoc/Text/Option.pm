#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package OODoc::Text::Option;
use parent 'OODoc::Text';

use strict;
use warnings;

use Log::Report    'oodoc';

#--------------------
=chapter NAME

OODoc::Text::Option - one option for one subroutine

=chapter SYNOPSIS

=chapter DESCRIPTION

Each OODoc::Text::Subroutine can have a list of options, which are each
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
{	my ($self, $args) = @_;
	$args->{type}    ||= 'Option';
	$args->{container} = delete $args->{subroutine} or panic;

	$self->SUPER::init($args) or return;

	$self->{OTO_parameters} = delete $args->{parameters} or panic;
	$self;
}

sub publish($)
{	my ($self, $args) = @_;
	my $exporter = $args->{exporter};

	my $p = $self->SUPER::publish($args);
	$p->{params} = $exporter->markupString($self->parameters);
	$p;
}

#--------------------
=section Attributes

=method subroutine
Returns the subroutine object for this option.
=cut

sub subroutine() { $_[0]->container }

=method parameters
Returns the short, informal description of the valid parameters for
this option.
=cut

sub parameters() { $_[0]->{OTO_parameters} }

1;
