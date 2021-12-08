# This code is part of perl distribution OODoc.  It is licensed under the
# same terms as Perl itself: https://spdx.org/licenses/Artistic-2.0.html

package OODoc::Text::Structure;
use base 'OODoc::Text';

use strict;
use warnings;

use Log::Report    'oodoc';
use List::Util     'first';

=chapter NAME
OODoc::Text::Structure - set of paragraphs with examples and subroutines

=chapter SYNOPSIS
 # Cannot be instantiated itself

=chapter DESCRIPTION

The OODoc::Text::Structure class is used as base class for
the M<OODoc::Text::Chapter>, M<OODoc::Text::Section>, and
M<OODoc::Text::SubSection> classes.  Each of these classes group some
paragraphs of text, probably some examples and some subroutines: they
provide a structure to the document.

=chapter METHODS

=section Constructors

=c_method new %options

=requires level INTEGER
Header level of the text structure.  A chapter will be 1, section 2, and
subsection 3.

=error no level defined for structural component
=cut

sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args) or return;
    $self->{OTS_subs}  = [];
    $self->{OTS_level} = delete $args->{level}
        or panic "no level defined for structural component";
    $self;
}

=method emptyExtension $container
Create an I<empty> copy of a structured text element, which is used
at a higher level of inheritance to collect related subroutines and
such.
=cut

sub emptyExtension($)
{   my ($self, $container) = @_;

    my $new = ref($self)->new
     ( name      => $self->name
     , linenr    => -1
     , level     => $self->level
     , container => $container
     );
    $new->extends($self);
    $new;
}

#-------------------------------------------

=section Attributes

=method level 
Returns the level of the text structure.  Like in pod and html, a chapter
will be 1, section 2, and subsection 3.
=cut

sub level()   {shift->{OTS_level}}

=method niceName 
Returns the name of this chapter, section or sub-section beautified to
normal caps.  If the name does not contain lower-case characters, then
the whole string is lower-cased, and then the first upper-cased.

=cut

sub niceName()
{   my $name = shift->name;
    $name =~ m/[a-z]/ ? $name : ucfirst(lc $name);
}

#-------------------------------------------

=section Location

=method path 
Represent the location of this chapter, section, or subsection as
one string, separated by slashes.

=example
 print $subsect->path; 
    # may print:  METHODS/Container/Search
=cut

sub path() { panic "Not implemented" }

=method findEntry $name
Find the chapter, section or subsection with this $name.  The object found
is returned.
=cut

sub findEntry($) { panic "Not implemented" }

#-------------------------------------------

=section Collected

=method all $method, $parameters
Call the $method recursively on this object and all its sub-structures.
For instance, when C<all> is called on a chapter, it first will call
the $method on that chapter, than on all its sections and subsections.
The $parameters are passed with each call.  The results of all calls is
returned as list.
=cut

sub all($@)
{   my ($self, $method) = (shift, shift);
    $self->$method(@_);
}

=method isEmpty 
Return true if this text structure is only a place holder for something
found in a super class.  Structured elements are created with
M<emptyExtension()> on each sub-class pass the idea of order and to
collect subroutines to be listed.  However, in some cases, nothing
is to be listed after all, and in that case, this method returns C<true>.

=example
 unless($chapter->isEmpty) ...
=cut

sub isEmpty()
{   my $self = shift;

    my $manual = $self->manual;
    return 0 if $self->description !~ m/^\s*$/;
    return 0 if first {!$manual->inherited($_)}
        $self->examples, $self->subroutines;

    my @nested
      = $self->isa('OODoc::Text::Chapter')    ? $self->sections
      : $self->isa('OODoc::Text::Section')    ? $self->subsections
      : $self->isa('OODoc::Text::SubSection') ? $self->subsubsections
      : return 1;

    not first {!$_->isEmpty} @nested;
}

#-------------------
=section Subroutines

Each manual page structure element (chapter, section, and subsection)
can contain a list of subroutine descriptions.

=method addSubroutine $objects
A subroutine (M<OODoc::Text::Subroutine> object) is added to the
chapter, section, or subsection.

=cut

sub addSubroutine(@)
{  my $self = shift;
   push @{$self->{OTS_subs}}, @_;
   $_->container($self) for @_;
   $self;
}

=method subroutines 
Returns the list of subroutines which are related to this text object.
=cut

sub subroutines() { @{shift->{OTS_subs}} }

=method subroutine $name
Returns the subroutine with the specific name.
=cut

sub subroutine($)
{   my ($self, $name) = @_;
    first {$_->name eq $name} $self->subroutines;
}

=method setSubroutines ARRAY
Sets the subroutines which are related to this text structure, replacing
the preivous set.  This is used when the manual pages are expanded into
each-other to simplify working with the inheritance relations.
=cut

sub setSubroutines($)
{   my $self = shift;
    $self->{OTS_subs} = shift || [];
}

#-------------------------------------------

=section Commonly used functions

=cut


1;
