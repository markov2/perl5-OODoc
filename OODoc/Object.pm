
package OODoc::Object;

use strict;
use warnings;

use Carp;

=chapter NAME

OODoc::Object - base class for all OODoc classes.

=chapter SYNOPSIS

 # Never instantiated directly.

=chapter DESCRIPTION

Any object used in the OODoc module is derived from this OODoc::Object
class.  This means that all functionality in this class is provided
for all of the other classes.

=cut

#-------------------------------------------

=chapter METHODS

=section Initiation

=cut

#-------------------------------------------

=c_method new OPTIONS

Create a new object (instantiation).  All objects in OODoc are created
the same way: they carry a list of key-value pairs as option.  For
examples, see the description of this method in the manual page of
the specific object.

The validity of the options for C<new> is checked, in contrary to the
options when used with many other method defined by OODoc.

=warning Unknown option $name

You have used the option with $name, which is not defined with the
instantiation (the C<new> method) of this object.

=warning Unknown options @names

You have used more than one option which is not defined to instantiate
the object.

=cut

sub new(@)
{   my $class = shift;

    my %args = @_;
    my $self = (bless {}, $class)->init(\%args);

    if(my @missing = keys %args)
    {   local $" = ', ';
        carp "WARNING: Unknown ".(@missing==1?'option':'options')." @missing";
    }

    $self;
}

sub init($)
{   my ($self, $args) = @_;
    $self;
}

#-------------------------------------------

=section Collected

=method extends [OBJECT]

Close to all elements used within OODoc can have an inheritance relation.
The returned object is extended by the current object.  Multiple inheritance
is not supported here.

=cut

sub extends(;$)
{   my $self = shift;
    @_ ? ($self->{OO_extends} = shift) : $self->{OO_extends};
}

#-------------------------------------------

=section Commonly used functions

=ci_method mkdirhier DIRECTORY

Creates this DIRECTORY and all its non-existing parents.

=cut

sub mkdirhier($)
{   my $thing = shift;
    my @dirs  = File::Spec->splitdir(shift);
    my $path  = $dirs[0] eq '' ? shift @dirs : '.';

    while(@dirs)
    {   $path = File::Spec->catdir($path, shift @dirs);
        die "Cannot create $path $!"
            unless -d $path || mkdir $path;
    }

    $thing;
}

#-------------------------------------------

=ci_method filenameToPackage FILENAME

=example

 print $self->filenameToPackage('Mail/Box.pm'); # prints Mail::Box

=cut

sub filenameToPackage($)
{   my ($thing, $package) = @_;
    $package =~ s#/#::#g;
    $package =~ s/\.(pm|pod)$//g;
    $package;
}

#-------------------------------------------

=section Manual Repository

All manuals can be reached everywhere in the program: it is a global
collection.

=cut

#-------------------------------------------

=method addManual MANUAL

The MANUAL will be added to the list of known manuals.  The same package
name can appear in more than one manual.  This OBJECT shall be of type
M<OODoc::Manual>.

=error manual definition requires manual object

A call to M<addManual()> expects a new manual object (a M<OODoc::Manual>),
however an incompatible thing was passed.  Usually, intended was a call
to M<manualsForPackage()> or M<mainManual()>.

=cut

my %packages;

sub addManual($)
{   my ($self, $manual) = @_;

    confess "ERROR: manual definition requires manual object"
        unless ref $manual && $manual->isa('OODoc::Manual');

    push @{$packages{$manual->package}}, $manual;
    $self;
}

#-------------------------------------------

=method mainManual NAME

Returns the manual of the named package which contains the primar
documentation for the code of the package NAME.

=cut

sub mainManual($)
{  my ($self, $name) = @_;
   (grep {$_ eq $_->package} $self->manualsForPackage($name))[0];
}

#-------------------------------------------

=method manualsForPackage NAME

Returns a list package objects which are related to the specified NAME.
One NAME can appear in more than one file, and therefore a list is
returned.

=cut

sub manualsForPackage($)
{   my ($self,$name) = @_;
    defined $packages{$name} ? @{$packages{$name}} : ();
}

#-------------------------------------------

=method manuals 

All manuals are returned.

=cut

sub manuals() { map { @$_ } values %packages }

#-------------------------------------------

=method packageNames

Returns the names of all defined packages.

=cut

sub packageNames() { keys %packages }

1;
