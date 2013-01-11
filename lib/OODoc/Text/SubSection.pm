
package OODoc::Text::SubSection;
use base 'OODoc::Text::Structure';

use strict;
use warnings;

use Log::Report    'oodoc';

=chapter NAME

OODoc::Text::SubSection - collects the text of one subsection within a section

=chapter SYNOPSIS

 my $section = $subsection->section;
 my $chapter = $subsection->chapter;

=chapter DESCRIPTION

A subsection (or head3) is the third level of refining document
hierarchies.  A subsection must be a part of a section, which is
part of a chapter.

=chapter METHODS

=c_method new OPTIONS

=requires section OBJECT
The section in which this sub-section lives.

=default container M<new(section)>
=default level     3
=default type      'Subsection'

=cut

sub init($)
{   my ($self, $args) = @_;
    $args->{type}      ||= 'Subsection';
    $args->{container} ||= delete $args->{section} or panic;
    $args->{level}     ||= 3;

    $self->SUPER::init($args) or return;
    $self->{OTS_subsubsections} = [];
    $self;
}

sub emptyExtension($)
{   my ($self, $container) = @_;
    my $empty = $self->SUPER::emptyExtension($container);
    my @subsub = map {$_->emptyExtension($empty)} $self->subsubsections;
    $empty->subsubsections(@subsub);
    $empty;
}

sub findEntry($)
{  my ($self, $name) = @_;
   $self->name eq $name ? $self : ();
}

#-------------------------------------------

=section Location

=method section
Returns the section object for this subsection.
=cut

sub section() { shift->container }

=method chapter
Returns the chapter object for this subsection.
=cut

sub chapter() { shift->section->chapter }

sub path()
{   my $self = shift;
    $self->section->path . '/' . $self->name;
}

#-------------------------------------------

=section Subsubsections

=method subsubsection NAME|OBJECT
With a NAME, the subsubsection within this subsection with that name is
returned.  With an OBJECT (which must be a OODoc::Text::SubSubSection),
a new subsubsection is added to the end of the list.

=cut

sub subsubsection($)
{   my ($self, $thing) = @_;

    if(ref $thing)
    {   push @{$self->{OTS_subsubsections}}, $thing;
        return $thing;
    }

    first {$_->name eq $thing} $self->subsubsections;
}

=method subsubsections [SUBSUBSECTIONS]
Returns a list of all subsubsections in this chapter.
=cut

sub subsubsections(;@)
{   my $self = shift;
    if(@_)
    {   $self->{OTS_subsubsections} = [ @_ ];
        $_->container($self) for @_;
    }

    @{$self->{OTS_subsubsections}};
}

=section Commonly used functions
=cut

1;

1;
