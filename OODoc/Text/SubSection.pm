
package OODoc::Text::SubSection;
use base 'OODoc::Text::Structure';

use strict;
use warnings;

use Carp;

=chapter NAME

OODoc::Text::SubSection - collects the text of one subsection within a section

=chapter SYNOPSIS

 my $section = $subsection->section;
 my $chapter = $subsection->chapter;

=chapter DESCRIPTION

A subsection (or head3) is the third level of refining document
hierarchies.  A subsection must be a part of a section, which is
part of a chapter.

=cut

#-------------------------------------------

=chapter METHODS

=cut

#-------------------------------------------

=c_method new OPTIONS

=requires section OBJECT
The section in which this sub-section lives.

=default container <section>
=default level     3

=cut

sub init($)
{   my ($self, $args) = @_;
    $args->{type}      ||= 'Subsection';
    $args->{container} ||= delete $args->{section} or confess;
    $args->{level}     ||= 3;

    $self->SUPER::init($args) or return;

    $self;
}

#-------------------------------------------

sub path()
{   my $self = shift;
    $self->section->path . '/' . $self->name;
}

#-------------------------------------------

=section Container

=cut

#-------------------------------------------

=method section

Returns the section object for this subsection.

=cut

sub section() { shift->container }

#-------------------------------------------

=method chapter

Returns the chapter object for this subsection.

=cut

sub chapter() { shift->section->chapter }

#-------------------------------------------

1;
