package OODoc::Object;

use strict;
use warnings;

use Log::Report    'oodoc';

use List::Util     qw/first/;

=chapter NAME

OODoc::Object - base class for all OODoc classes.

=chapter SYNOPSIS

 # Never instantiated directly.

=chapter DESCRIPTION

Any object used in the OODoc module is derived from this OODoc::Object
class.  This means that all functionality in this class is provided
for all of the other classes.

=chapter OVERLOADED

=chapter METHODS

=section Constructors

=c_method new %options

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
{   my ($class, %args) = @_;
    my $self = (bless {}, $class)->init(\%args);

    if(my @missing = keys %args)
    {   error __xn"Unknown object attribute '{options}'", "Unknown object attributes: {options}",
            scalar @missing, options => \@missing;
    }

    $self;
}

sub init($)
{   my ($self, $args) = @_;
    $self;
}

#-------------------------------------------
=section Accessors
=cut

#-------------------------------------------
=section Manual Repository

All manuals can be reached everywhere in the program: it is a global
collection.

=method addManual $manual
The $manual will be added to the list of known manuals.  The same package
name can appear in more than one manual.  This OBJECT shall be of type
M<OODoc::Manual>.

=error manual definition requires manual object
A call to M<addManual()> expects a new manual object (a M<OODoc::Manual>),
however an incompatible thing was passed.  Usually, intended was a call
to M<manualsForPackage()> or M<mainManual()>.

=cut

my %packages;
my %manuals;

sub addManual($)
{   my ($self, $manual) = @_;

    ref $manual && $manual->isa('OODoc::Manual')
        or panic "manual definition requires manual object";

    push @{$packages{$manual->package}}, $manual;
    $manuals{$manual->name} = $manual;
    $self;
}

=method mainManual $name
Returns the manual of the named package which contains the primar
documentation for the code of the package $name.
=cut

sub mainManual($)
{  my ($self, $name) = @_;
   first { $_ eq $_->package } $self->manualsForPackage($name);
}

=method manualsForPackage $name
Returns a list package objects which are related to the specified $name.
One $name can appear in more than one file, and therefore a list is
returned.
=cut

sub manualsForPackage($)
{   my ($self, $name) = @_;
    @{$packages{$name || 'doc'} || []};
}

=method manuals 
All manuals are returned.
=cut

sub manuals() { values %manuals }

=method findManual $name
[3.00] Returns the manual with the specified name, or else C<undef>.
=cut

sub findManual($) { $manuals{ $_[1] } }

=method packageNames 
Returns the names of all defined packages.
=cut

sub packageNames() { keys %packages }

#-------------------------------------------
=section Commonly used functions

=ci_method mkdirhier $directory
Creates this $directory and all its non-existing parents.
=cut

sub mkdirhier($)
{   my $thing = shift;
    my @dirs  = File::Spec->splitdir(shift);
    my $path  = $dirs[0] eq '' ? shift @dirs : '.';

    while(@dirs)
    {   $path = File::Spec->catdir($path, shift @dirs);
        -d $path || mkdir $path
            or fault __x"cannot create {dir}", dir => $path;
    }

    $thing;
}

=ci_method filenameToPackage $filename
=example
 print $self->filenameToPackage('Mail/Box.pm'); # prints Mail::Box
=cut

sub filenameToPackage($)
{   my ($thing, $package) = @_;
    $package =~ s!^lib/!!r =~ s#/#::#gr =~ s/\.(?:pm|pod)$//gr;
}

1;
