
package OODoc::Text::Subroutine;
use base 'OODoc::Text';

use strict;
use warnings;

use Carp;

=chapter NAME

OODoc::Text::Subroutine - collects information about one documented sub

=chapter SYNOPSIS

=chapter DESCRIPTION

Perl has various things we can call "sub" (for "subroutine") one
way or the other.  This object tries to store all types of them:
methods, funtion, ties, and overloads. Actually, these are the
most important parts of the documentation.  The share more than
they differ.

=chapter METHODS

=c_method new OPTIONS

=option  parameters STRING
=default parameters undef

=cut

sub init($)
{   my ($self, $args) = @_;

    confess "no name for subroutine"
       unless exists $args->{name};

    $self->SUPER::init($args) or return;

    $self->{OTS_param}    = delete $args->{parameters};
    $self->{OTS_options}  = {};
    $self->{OTS_defaults} = {};
    $self->{OTS_diags}    = [];
    $self;
}

#-------------------------------------------

=method extends [OBJECT]

=warning subroutine $name extended by different type:

Any description of a subroutine classifies it as method, tie, overload or
whatever.  Apparently, this indicated subroutine is defined being of a
different type on these both places, and there is an inheritance relation
between these places.

In very rare cases, this warning can be ignored, but usually these
situation is errorneous of confusing for the users of the library.

=cut

sub extends($)
{   my $self  = shift;
    return $self->SUPER::extends unless @_;

    my $super = shift;
    if($self->type ne $super->type)
    {   my ($fn1, $ln1) = $self->where;
        my ($fn2, $ln2) = $super->where;
        my ($t1,  $t2 ) = ($self->type, $super->type);

        warn <<WARN;
WARNING: subroutine $self() extended by different type:
   $t1 in $fn1 line $ln1
   $t2 in $fn2 line $ln2
WARN
    }

    $self->SUPER::extends($super);
}

#-------------------------------------------

=section Attributes

=method parameters

The parameter list for the subroutine is returned as string.  The
result may be C<undef> or empty.

=cut

sub parameters() {shift->{OTS_param}}

#-------------------------------------------

=section Location

=method location MANUAL

Try to figure-out what the location for the subroutine is within the
MANUAL page.  Have a look at all levels of extension for this
sub-routine's documentation and decides the best enclosing
chapter, section and subsection.  Then return that object for the
current manual.

=warning subroutine $self location conflict: $here $super

The location of subroutine descriptions must be consistent over the
manual pages.  You may change the level of clearness about the
exact location (place in the chapter in one page, and in a subsection
in the next), as long as it is not conflicting (the subsection must
be a part of the chapter).

=cut

sub location($)
{   my ($self, $manual) = @_;
    my $container = $self->container;
    my $super     = $self->extends or return $container;

    my $superloc  = $super->location;
    my $superpath = $superloc->path;
    my $mypath    = $container->path;

    return $container if $superpath eq $mypath;
    
    if(length $superpath < length $mypath)
    {   return $container
           if substr($mypath, 0, length($superpath)+1) eq "$superpath/";
    }
    elsif(substr($superpath, 0, length($mypath)+1) eq "$mypath/")
    {   if($superloc->isa("OODoc::Text::Chapter"))
        {   return $self->manual
                        ->chapter($superloc->name);
        }
        elsif($superloc->isa("OODoc::Text::Section"))
        {   return $self->manual
                        ->chapter($superloc->chapter->name)
                        ->section($superloc->name);
        }
        else
        {   return $self->manual
                        ->chapter($superloc->chapter->name)
                        ->section($superloc->section->name)
                        ->subsection($superloc->name);
        }
   }

   unless($manual->inherited($self))
   {   my ($myfn, $myln)       = $self->where;
       my ($superfn, $superln) = $super->where;

       warn <<WARN
WARNING: Subroutine $self() location conflict:
   $mypath in $myfn line $myln
   $superpath in $superfn line $superln
WARN
   }

   $container;
}

=method path
Returns the path of the text structure which contains this subroutine.
=cut

sub path() { shift->container->path }

#-------------------------------------------

=section Collected

=method default NAME|OBJECT

In case of a NAME, a default object for this method is looked up.  This
does not search through super classes, but solely which is defined with
this subroutine.  When passed an OBJECT of type OODoc::Text::Default
that will be stored.

=cut

sub default($)
{   my ($self, $it) = @_;
    return $self->{OTS_defaults}{$it} unless ref $it;

    my $name = $it->name;
    $self->{OTS_defaults}{$name} = $it;
    $it;
}

#-------------------------------------------

=method defaults
Returns a list of all defaults as defined by this documentation item in
one manual.
=cut

sub defaults() { values %{shift->{OTS_defaults}} }

=method option NAME|OBJECT
In case of a NAME, the option object for this method is looked up.  This
does not search through super classes, but solely which is defined with
this subroutine.  When passed an OBJECT of type OODoc::Text::Option
that will be stored.
=cut

sub option($)
{   my ($self, $it) = @_;
    return $self->{OTS_options}{$it} unless ref $it;

    my $name = $it->name;
    $self->{OTS_options}{$name} = $it;
    $it;
}


=method findOption NAME
Does a little more thorough job than M<option()> bu searching the inherited
options for this subroutine as well.
=cut

sub findOption($)
{   my ($self, $name) = @_;
    my $option = $self->option($name);
    return $option if $option;

    my $extends = $self->extends or return;
    $extends->findOption($name);
}

=method options
Returns a list of all options as defined by this documentation item in
one manual.
=cut

sub options() { values %{shift->{OTS_options}} }

=method diagnostic OBJECT
Add a new diagnostic message (a OODoc::Text::Diagnostic object) to the
list already in this object.  You can not look for a message because
these names are without use.
=cut

sub diagnostic($)
{   my ($self, $diag) = @_;
    push @{$self->{OTS_diags}}, $diag;
    $diag;
}

=method diagnostics
Returns a list of all diagnostics.
=cut

sub diagnostics() { @{shift->{OTS_diags}} }

=method collectedOptions
Returns a list of option-default combinations on this subroutine.
=cut

sub collectedOptions(@)
{   my ($self, %args) = @_;
    my @extends   = $self->extends;
    my %options;
    foreach ($self->extends)
    {   my $options = $_->collectedOptions;
        @options{ keys %$options } = values %$options;
    }

    $options{$_->name}[0] = $_ for $self->options;

    foreach my $default ($self->defaults)
    {   my $name = $default->name;

        unless(exists $options{$name})
        {   my ($fn, $ln) = $default->where;
            warn "WARNING: no option $name for default in $fn line $ln\n";
            next;
        }
        $options{$name}[1] = $default;
    }

    foreach my $option ($self->options)
    {   my $name = $option->name;
        next if defined $options{$name}[1];

        my ($fn, $ln) = $option->where;
        warn "WARNING: no default for option $name defined in $fn line $ln\n";

        my $default = $options{$name}[1] =
        OODoc::Text::Default->new
         ( name => $name, value => 'undef'
         , subroutine => $self, linenr => $ln
         );

        $self->default($default);
    }

    \%options;
}

1;
