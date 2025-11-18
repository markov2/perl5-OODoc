#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package OODoc::Object;

use strict;
use warnings;

use Log::Report    'oodoc';

use List::Util     qw/first/;

#--------------------
=chapter NAME

OODoc::Object - base class for all OODoc classes.

=chapter SYNOPSIS

  # Never instantiated directly.

=chapter DESCRIPTION

Any object used in the OODoc module is derived from this OODoc::Object
class.  This means that all functionality in this class is provided
for all of the other classes.

=chapter OVERLOADED

=overload  '==' (numeric equivalent)
Numeric comparison is used to compare to objects whether they are
identical.  On many extensions, string comparison is overloaded to
compare the names of the objects.

=overload  '!=' (numeric different)
Results in true when the objects are different

=overload 'bool'
Always returns true: "exists".
=cut

use overload
	'=='   => sub {$_[0]->unique == $_[1]->unique},
	'!='   => sub {$_[0]->unique != $_[1]->unique},
	'bool' => sub {1};

#--------------------
=chapter METHODS

=section Constructors

=c_method new %options

Create a new object (instantiation).  All objects in OODoc are created
the same way: they carry a list of key-value pairs as option.  For
examples, see the description of this method in the manual page of
the specific object.

The validity of the options for C<new> is checked, in contrary to the
options when used with many other method defined by OODoc.

=error unknown object attribute '$name' for $pkg
You have used the option with $name, which is not defined with the
instantiation (the C<new> method) of this object.

=error unknown object attributes for $pkg: '$names'
You have used more than one option which is not defined to instantiate
the object.

=cut

sub new(@)
{	my ($class, %args) = @_;
	my $self = (bless {}, $class)->init(\%args);

	if(my @missing = keys %args)
	{	error __xn"unknown object attribute '{names}' for {pkg}", "unknown object attributes for {pkg}: {names}",
			scalar @missing, names => \@missing, pkg => $class;
	}

	$self;
}

my $unique = 42;

sub init($)
{	my ($self, $args) = @_;

	# prefix with 'id', otherwise confusion between string and number
	$self->{OO_unique} = 'id' . $unique++;
	$self;
}

#--------------------
=section Attributes

=method unique
Returns a unique id for this text item.  This is the easiest way to
see whether two references to the same (overloaded) objects point to
the same thing. The ids are numeric.

=example
  if($obj1->unique == $obj2->unique) {...}
  if($obj1 == $obj2) {...}   # same via overload

=cut

sub unique() { $_[0]->{OO_unique} }

=method manual
The manual of the text object is returned.
=cut

sub manual() { panic }

#--------------------
=section Collected

=method publish \%options
Extract the data of an object for export, and register it in the index.
A HASH is returned which should get filled with useful data.
=cut

my $index;  # still a global :-(  Set by ::Export
sub _publicationIndex($) { $index = $_[1] }

sub publish($)
{	my ($self, $args) = @_;
	my $id     = $self->unique;

	my $manual = $args->{manual};
	$id .= '-' . $manual->unique if $manual->inherited($self);

	$index->{$id} = +{ id => $id };
}

1;
