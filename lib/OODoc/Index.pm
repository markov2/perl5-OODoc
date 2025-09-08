#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package OODoc::Index;
use parent 'OODoc::Object';

use strict;
use warnings;

use Log::Report    'oodoc';

use List::Util     qw/first/;

#--------------------
=chapter NAME

OODoc::Index - administer the collected information

=chapter SYNOPSIS

  my $index = $oodoc->index;

=chapter DESCRIPTION

=chapter OVERLOADED

#--------------------
=chapter METHODS

=c_method new %options
=cut

sub init($)
{	my ($self, $args) = @_;
	$self->SUPER::init($args);
	$self->{OI_pkgs} = {};
	$self->{OI_mans} = {};
	$self;
}

#--------------------
=section Attributes
=cut

sub _packages() { $_[0]->{OI_pkgs} }
sub _manuals()  { $_[0]->{OI_mans} }

#--------------------
=section The Manual Repository

=method addManual $manual
The $manual will be added to the list of known manuals.  The same package
name can appear in more than one manual.  This OBJECT shall be of type
OODoc::Manual.

=error manual definition requires manual object
A call to M<addManual()> expects a new manual object (a OODoc::Manual),
however an incompatible thing was passed.  Usually, intended was a call
to M<manualsForPackage()> or M<mainManual()>.

=cut

sub addManual($)
{	my ($self, $manual) = @_;

	ref $manual && $manual->isa('OODoc::Manual')
		or panic "manual definition requires manual object";

	push @{$self->_packages->{$manual->package}}, $manual;
	$self->_manuals->{$manual->name} = $manual;
	$self;
}

=method mainManual $name
Returns the manual of the named package which contains the primar
documentation for the code of the package $name.
=cut

sub mainManual($)
{	my ($self, $name) = @_;
	first { $_ eq $_->package } $self->manualsForPackage($name);
}

=method manualsForPackage $name
Returns a list package objects which are related to the specified $name.
One $name can appear in more than one file, and therefore a list is
returned.
=cut

sub manualsForPackage($)
{	my ($self, $name) = @_;
	@{$self->_packages->{$name || 'doc'} || []};
}

=method manuals
All manuals are returned.
=cut

sub manuals() { values %{$_[0]->_manuals} }

=method findManual $name
[3.00] Returns the manual with the specified name, or else undef.
=cut

sub findManual($) { $_[0]->_manuals->{ $_[1] } }

=method packageNames
Returns the names of all defined packages.
=cut

sub packageNames() { keys %{$_[0]->_packages} }


1;
