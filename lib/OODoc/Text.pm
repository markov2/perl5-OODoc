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

=overload  '""' (stringification)
Returned is the name of the text object.

=overload 'cmp' (string comparison)
True when both object have same name.  Numeric comparison operators
check whether it is the same object: subtilly different.
=cut

use overload
    '""'   => sub {$_[0]->name},
    'cmp'  => sub {$_[0]->name cmp "$_[1]"};

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
=default description <empty string>
The text which is contained in the body of this text item.  Often, this
is filled in later by M<openDescription()>.

=requires linenr INTEGER

=error no text container specified for the $type object
Each text element is encapsulated by an other text element, except
chapters.  A value must be known for this C<container> option to
define the elements relative location.

=cut

sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args) or return;

    $self->{OT_name}     = delete $args->{name};

    my $nr = $self->{OT_linenr} = delete $args->{linenr} or panic;
    $self->{OT_type}     = delete $args->{type} or panic;

    exists $args->{container}   # may be explicit undef
        or panic "no text container specified for the {pkg} object", pkg => ref $self;

    $self->{OT_container}= delete $args->{container};    # may be undef initially
    $self->{OT_descr}    = delete $args->{description} || '';
    $self->{OT_examples} = [];
    $self->{OT_extends}  = [];
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

sub name() { $_[0]->{OT_name} }

=method type
Returns the type name of this data object.
=cut

sub type() { $_[0]->{OT_type} }

=method description
Returns the description text for this object.  Nearly all objects
contains some kind of introductory description.
=cut

sub description()
{   my @lines = split /^/m, shift->{OT_descr};
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

=method where
Returns the source of the text item: the filename name and the line
number of the start of it.
=cut

sub where()
{   my $self = shift;
    ( $self->manual->source, $self->linenr );
}

=method manual
The manual of the text object is returned.
=cut

sub manual(;$)
{   my $self = shift;
    $self->container->manual;
}

=method extends [$object]
Close to all elements used within OODoc can have an inheritance relation.
The returned object is extended by the current object.  Multiple inheritance
is not supported here.
=cut

sub extends(;$)
{   my $self = shift;
    my $ext  = $self->{OT_extends};
    push @$ext, @_;

    wantarray ? @$ext : $ext->[0];
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

=method addExample $object
Add a new example (an M<OODoc::Text::Example> object) to the list already
in this object.  You can not search for a specific example, because they
have no real name (only a sequence number).
=cut

sub addExample($)
{   my ($self, $example) = @_;
    push @{$self->{OT_examples}}, $example;
    $example;
}

=method examples
Returns a LIST of all examples contained in this text element.
=cut

sub examples() { @{shift->{OT_examples}} }

sub publish($%)
{   my ($self, $args) = @_;
    my $exporter = $args->{exporter} or panic;
	my $manual   = $args->{manual}   or panic;

	my $p = $self->SUPER::publish($args);
    $p->{type}      = $exporter->markup(lc $self->type);
	$p->{inherited} = $exporter->boolean($manual->inherited($self));

    if(my $name  = $self->name)
    {   $p->{name} = $exporter->markupString($name);
    }

    my $descr    = $self->description // '';
    $p->{intro}  = $exporter->markupBlock($descr)
        if length $descr;

    my @e        = map $_->publish($args)->{id}, $self->examples;
    $p->{examples} = \@e if @e;
	$p;
}

#-------------------------------------------
=section Commonly used functions
=cut

1;
