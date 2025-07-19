# This code is part of perl distribution OODoc.  It is licensed under the
# same terms as Perl itself: https://spdx.org/licenses/Artistic-2.0.html

package OODoc::Text::Chapter;
use base 'OODoc::Text::Structure';

use strict;
use warnings;

use Log::Report    'oodoc';
use List::Util     'first';

=chapter NAME

OODoc::Text::Chapter - collects the information of one chapter

=chapter SYNOPSIS

=chapter DESCRIPTION

=chapter METHODS

=section Constructors

=c_method new %options

=default container M<new(manual)>
=default level     1
=default type      'Chapter'

=option  manual    OBJECT
=default manual    undef
The manual in which this chapter is described.

=cut

sub init($)
{   my ($self, $args) = @_;
    $args->{type}       ||= 'Chapter';
    $args->{container}  ||= delete $args->{manual} or panic;
    $args->{level}      ||= 1;
    $self->SUPER::init($args) or return;
    $self->{OTC_sections} = [];
    $self;
}

sub emptyExtension($)
{   my ($self, $container) = @_;
    my $empty = $self->SUPER::emptyExtension($container);
    my @sections = map $_->emptyExtension($empty), $self->sections;
    $empty->sections(@sections);
    $empty;
}

sub manual() { $_[0]->container }
sub path()   { $_[0]->name }

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

sub findEntry($)
{   my ($self, $name) = @_;
    return $self if $self->name eq $name;

    foreach my $section ($self->sections)
    {   my $entry = $section->findEntry($name);
        return $entry if defined $entry;
    }

    ();
}

sub all($@)
{   my $self = shift;
      ( $self->SUPER::all(@_)
      , map $_->all(@_), $self->sections
      );
}

sub publish(%)
{   my ($self, %args) = @_;
	$args{chapter} = $self;
    my $p = $self->SUPER::publish(%args);
    my @s = map $_->publish(%args), $self->sections;
	$p->{nest} = \@s if @s;
    $p;
}

#-------------------
=section Sections

A chapters consists of a list of sections, which may contain subsections.

=method section $name|$object
With a $name, the section within this chapter with that name is
returned.  With an $object (which must be a M<OODoc::Text::Section>),
a new section is added to the end of the list.
=cut

sub section($)
{   my ($self, $thing) = @_;

    if(ref $thing)
    {   push @{$self->{OTC_sections}}, $thing;
        return $thing;
    }

    first { $_->name eq $thing } $self->sections;
}

=method sections [$sections]
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

1;
