# This code is part of perl distribution OODoc.  It is licensed under the
# same terms as Perl itself: https://spdx.org/licenses/Artistic-2.0.html

package OODoc::Text;
use parent 'OODoc::Object';

use strict;
use warnings;

use Log::Report    'oodoc';

=chapter NAME

OODoc::Text - text component as found in a manual

=chapter SYNOPSIS

 # Cannot be instantiated itself

=chapter DESCRIPTION

The parsers (implemented in the M<OODoc::Parser> classes) scan
the documentation as written down by the author of the module, and
build a tree of these OODoc::Text objects from it. Then, any formatter
(implemented by the M<OODoc::Format> classes) can take this tree of text
objects and convert it into manual pages.

=chapter OVERLOADED

=overload  '==' $and '!='
Numeric comparison is used to compare to objects whether they are
identical.  String comparison is overloaded to compare the names
of the objects.

=overload  '""' <$stringification>
Returned is the name of the text object.

=overload  'cmp' <$string $comparison>
Names are compared.

=cut

use overload '=='   => sub {$_[0]->unique == $_[1]->unique}
           , '!='   => sub {$_[0]->unique != $_[1]->unique}
           , '""'   => sub {$_[0]->name}
           , 'cmp'  => sub {$_[0]->name cmp "$_[1]"}
           , 'bool' => sub {1};

#-------------------------------------------

=chapter METHODS

=c_method new %options

=option  name STRING
=default name undef
The name contains the main data about the text piece.

=requires container OBJECT
All text objects except chapters are contained in some other object.

=requires type STRING
The type of this text element.  This is used for debugging only.

=option  description STRING
=default description ''
The text which is contained in the body of this text item.  Often, this
is filled in later by M<openDescription()>.

=requires linenr INTEGER

=error no text container specified for the $type object
Each text element is encapsulated by an other text element, except
chapters.  A value must be known for this C<container> option to
define the elements relative location.

=cut

my $unique = 1;

sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args) or return;

    $self->{OT_name}     = delete $args->{name};

    my $nr = $self->{OT_linenr} = delete $args->{linenr} or panic;
    $self->{OT_type}     = delete $args->{type} or panic;

    exists $args->{container}   # may be explicit undef
        or panic "no text container specified for the {pkg} object"
             , pkg => ref $self;

    # may be undef
    $self->{OT_container}= delete $args->{container};

    $self->{OT_descr}    = delete $args->{description} || '';
    $self->{OT_examples} = [];
    $self->{OT_unique}   = $unique++;

    $self;
}

#-------------------------------------------
=section Attributes

=method name 
The name of this text element.  Stringification is overloaded to call
this name method.

=examples
 print $text->name;
 print $text;   # via overload
=cut

sub name() {shift->{OT_name}}

=method type 
Returns the type name of this data object.
=cut

sub type() {shift->{OT_type}}

=method description 
Returns the description text for this object.  Nearly all objects
contains some kind of introductory description.
=cut

sub description()
{   my $text  = shift->{OT_descr};
    my @lines = split /^/m, $text;
    shift @lines while @lines && $lines[ 0] =~ m/^\s*$/;
    pop   @lines while @lines && $lines[-1] =~ m/^\s*$/;
    join '', @lines;
}

=method container [$object]
The text element which encapsulates the text element at hand.  This
defines the structure of the documentation.
Only for chapters, this value will be undefined.
=cut

sub container(;$)
{   my $self = shift;
    @_ ? ($self->{OT_container} = shift) : $self->{OT_container};
}

=method linenr
=cut

sub linenr() { $_[0]->{OT_linenr} }

=section Location

=method manual [$name]
Without a $name, the manual of the text object is returned. With a $name,
the manual with that name is returned, even when that does not have a
relation to the object: it calls M<OODoc::Object::manual()>.
=cut

sub manual(;$)
{   my $self = shift;
    @_ ? $self->SUPER::manual(@_) : $self->container->manual;
}

=method unique 
Returns a unique id for this text item.  This is the easiest way to
see whether two references to the same (overloaded) objects point to
the same thing. The ids are numeric.

=example
 if($obj1->unique == $obj2->unique) {...}
 if($obj1 == $obj2) {...}   # same via overload

=cut

sub unique() {shift->{OT_unique}}

=method where 
Returns the source of the text item: the filename name and the line
number of the start of it.
=cut

sub where()
{   my $self = shift;
    ( $self->manual->source, $self->{OT_linenr} );
}

#-------------------------------------------
=section Collected

=method openDescription 
Returns a reference to the scalar which will contain the description for
this object.

=example
 my $descr = $text->openDescription;
 $$descr  .= "add a line\n";

=cut

sub openDescription() { \shift->{OT_descr} }

=method findDescriptionObject 
From the current object, search in the extends until an object is found
which has a content for the description field.
=cut

sub findDescriptionObject()
{   my $self   = shift;
    return $self if length $self->description;

    my @descr = map $_->findDescriptionObject, $self->extends;
    wantarray ? @descr : $descr[0];
}

=method example $object
Add a new example (a OODoc::Text::Example object) to the list already in
this object.  You can not look for a specific because they have no real
name (only a sequence number).
=cut

sub example($)
{   my ($self, $example) = @_;
    push @{$self->{OT_examples}}, $example;
    $example;
}

=method examples 
Returns a list of all examples contained in this text element.
=cut

sub examples() { @{shift->{OT_examples}} }

=method publish %options
=requires exporter M<OODoc::Export>-object
=cut

sub publish(%)
{   my ($self, %args) = @_;
    my $exporter = $args{exporter} or panic;

    my %p =
      ( type => $exporter->plainText($self->type)
      );

	if(my $name = $self->name)
	{   $p{name} = $exporter->plainText($name);
    }

    my $descr = $self->description // '';
    if(length $descr)
    {   $p{description} = $exporter->markupBlock($descr);
    }

	my @e = map $_->publish(%args), $self->examples;
	$p{examples} = \@e if @e;

	\%p;
}

#-------------------------------------------
=section Commonly used functions
=cut

1;
