#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package OODoc::Text::SubSubSection;
use parent 'OODoc::Text::Structure';

use strict;
use warnings;

use Log::Report    'oodoc';

#--------------------
=chapter NAME

OODoc::Text::SubSubSection - collects the text of one subsubsection within a subsection

=chapter SYNOPSIS

=chapter DESCRIPTION

A subsubsection (or head4) is the fourth level of refining document
hierarchies.  A subsubsection must be a part of a subsection, which is
part of a section.

=chapter METHODS

=c_method new %options

=requires subsection OBJECT
The section in which this sub-section lives.

=default container M<new(subsection)>
=default level     3
=default type      'Subsubsection'

=cut

sub init($)
{	my ($self, $args) = @_;
	$args->{type}      ||= 'Subsubsection';
	$args->{container} ||= delete $args->{subsection} or panic;
	$args->{level}     ||= 3;
	$self->SUPER::init($args);
}

sub findEntry($)
{	my ($self, $name) = @_;
	$self->name eq $name ? $self : ();
}

sub nest() { }

#--------------------
=section Location

=method subsection
Returns the subsection object for this subsubsection.
=cut

sub subsection() { $_[0]->container }

=method chapter
Returns the chapter object for this subsection.
=cut

sub chapter() { $_[0]->subsection->chapter }

sub path()
{	my $self = shift;
	$self->subsection->path . '/' . $self->name;
}

1;
