
package OODoc::Text::Chapter;
use base 'OODoc::Text::Structure';

use strict;
use warnings;

use List::Util 'first';
use Carp;

=chapter NAME

OODoc::Text::Chapter - collects the information of one chapter

=chapter SYNOPSIS

=chapter DESCRIPTION

=chapter METHODS

=c_method new OPTIONS

=default container M<new(manual)>
=default level     C<1>
=default type      C<'Chapter'>

=option  manual    OBJECT
=default manual    undef

The manual in which this chapter is described.

=cut

sub init($)
{   my ($self, $args) = @_;
    $args->{type}       ||= 'Chapter';
    $args->{container}  ||= delete $args->{manual} or confess;
    $args->{level}      ||= 1;

    $self->SUPER::init($args) or return;

    $self->{OTC_sections} = [];

    $self;
}

#-------------------------------------------

sub manual() {shift->container}

#-------------------------------------------

sub path() {shift->name}

#-------------------------------------------

sub findSubroutine($)
{   my ($self, $name) = @_;
    my $sub = $self->SUPER::findSubroutine($name);
    return $sub if defined $sub;

    foreach my $section ($self->sections)
    {   my $sub = $section->findSubroutine($name);
        return $sub if defined $sub;
    }

    undef;
}

#-------------------------------------------

sub findEntry($)
{   my ($self, $name) = @_;
    return $self if $self->name eq $name;

    foreach my $section ($self->sections)
    {   my $entry = $section->findEntry($name);
        return $entry if defined $entry;
    }

    ();
}

#-------------------------------------------

sub all($@)
{   my $self = shift;
    ($self->SUPER::all(@_), map {$_->all(@_)} $self->sections);
}

#-------------------------------------------

=section Sections

A chapters consists of a list of sections, which may contain subsections.

=cut

#-------------------------------------------

=method section NAME|OBJECT

With a NAME, the section within this chapter with that name is
returned.  With an OBJECT (which must be a M<OODoc::Text::Section>),
a new section is added to the end of the list.

=cut

sub section($)
{   my ($self, $thing) = @_;

    if(ref $thing)
    {   push @{$self->{OTC_sections}}, $thing;
        return $thing;
    }

    first {$_->name eq $thing} $self->sections;
}

#-------------------------------------------

=method sections [SECTIONS]

Returns a list of all sections in this chapter.

=cut

sub sections()
{  my $self = shift;
   if(@_)
   {   $self->{OTC_sections} = [ @_ ];
       $_->container($self) for @_;
   }
   @{$self->{OTC_sections}};
}

#-------------------------------------------

1;
