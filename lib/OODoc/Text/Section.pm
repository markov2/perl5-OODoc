
package OODoc::Text::Section;
use base 'OODoc::Text::Structure';

use strict;
use warnings;

use Carp;
use List::Util 'first';

=chapter NAME

OODoc::Text::Section - collects the text of one section within a chapter

=chapter SYNOPSIS

 my $chapter = $section->chapter;
 my @subsect = $section->subsections;

 my $index   = $section->subsection('INDEX');

 my $index   = OODoc::Text::SubSection->new(...);
 $section->subsection($index);           # add subsection

=chapter DESCRIPTION

=chapter METHODS

=c_method new OPTIONS

=requires chapter   OBJECT
=default  container M<new(chapter)>
=default  level     2
=default  type      'Section'

=cut

sub init($)
{   my ($self, $args) = @_;
    $args->{type}      ||= 'Section';
    $args->{level}     ||= 2;
    $args->{container} ||= delete $args->{chapter} or confess;

    $self->SUPER::init($args) or return;

    $self->{OTS_subsections} = [];
    $self;
}

#-------------------------------------------

=section Location

=method chapter

Returns the chapter object for this section.

=cut

sub chapter() { shift->container }

#-------------------------------------------

sub path()
{   my $self = shift;
    $self->chapter->path . '/' . $self->name;
}

#-------------------------------------------

sub findSubroutine($)
{   my ($self, $name) = @_;
    my $sub = $self->SUPER::findSubroutine($name);
    return $sub if defined $sub;

    foreach my $subsection ($self->subsections)
    {   my $sub = $subsection->findSubroutine($name);
        return $sub if defined $sub;
    }

    undef;
}

#-------------------------------------------

sub findEntry($)
{   my ($self, $name) = @_;
    return $self if $self->name eq $name;
    my $subsect = $self->subsection($name);
    defined $subsect ? $subsect : ();
}

#-------------------------------------------

sub all($@)
{   my $self = shift;
    ($self->SUPER::all(@_), map {$_->all(@_)} $self->subsections);
}

#-------------------------------------------

=section Subsections

=method subsection NAME|OBJECT

With a NAME, the subsection within this section with that name is
returned.  With an OBJECT (which must be a OODoc::Text::SubSection),
a new subsection is added to the end of the list.

=cut

sub subsection($)
{   my ($self, $thing) = @_;

    if(ref $thing)
    {   push @{$self->{OTS_subsections}}, $thing;
        return $thing;
    }

    first {$_->name eq $thing} $self->subsections;
}

#-------------------------------------------

=method subsections [SUBSECTIONS]

Returns a list of all sections in this chapter.

=cut

sub subsections(;@)
{   my $self = shift;
    if(@_)
    {   $self->{OTS_subsections} = [ @_ ];
        $_->container($self) for @_;
    }

    @{$self->{OTS_subsections}};
}

#-------------------------------------------

=section Commonly used functions

=cut

1;
