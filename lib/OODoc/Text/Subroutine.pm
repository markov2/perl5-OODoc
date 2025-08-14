package OODoc::Text::Subroutine;
use parent 'OODoc::Text';

use strict;
use warnings;

use Log::Report    'oodoc';
use Scalar::Util   qw/blessed/;

=chapter NAME

OODoc::Text::Subroutine - collects information about one documented sub

=chapter SYNOPSIS

=chapter DESCRIPTION

Perl has various things we can call "sub" (for "subroutine") one
way or the other.  This object tries to store all types of them:
methods, functions, ties, and overloads.  Actually, these are the
most important parts of the documentation.  The share more than
they differ.

=chapter METHODS

=c_method new %options

=option  parameters STRING
=default parameters undef
The STRING which is found as description of the parameters which can be
passed to the subroutine.  Although free format, there is a convertion
which you can find in the manual page of the selected parser.
=cut

sub init($)
{   my ($self, $args) = @_;

    exists $args->{name}
        or error __x"no name for subroutine";

    $self->SUPER::init($args)
        or return;

    $self->{OTS_param}    = delete $args->{parameters};
    $self->{OTS_options}  = {};
    $self->{OTS_defaults} = {};
    $self->{OTS_diags}    = [];
    $self;
}

sub _call($)
{	my ($self, $exporter) = @_;
    my $type       = $self->type;
    my $unique     = $self->unique;
    my $style      = $exporter->markupStyle;

    my $name       = $exporter->markupString($self->name);
    my $paramlist  = $exporter->markupString($self->parameters);

	if($style eq 'html')
    {   my $call       = qq[<b><a name="$unique">$name</a></b>];
        $call         .= "(&nbsp;$paramlist&nbsp;)" if length $paramlist;

        return
            $type eq 'i_method' ? qq[\$obj-&gt;$call]
          : $type eq 'c_method' ? qq[\$class-&gt;$call]
          : $type eq 'ci_method'? qq[\$any-&gt;$call]
          : $type eq 'overload' ? qq[overload: $call]
          : $type eq 'function' ? qq[$call]
          : $type eq 'tie'      ? $call
          : panic "Type $type? for $call";
    }

    if($style eq 'pod')
    {   my $params
          = !length $paramlist ? '()'
          : $paramlist =~ m/^[\[<]|[\]>]$/ ? "( $paramlist )"
          :                      "($paramlist)";

        return
            $type eq 'i_method' ? qq[\$obj-E<gt>B<$name>$params]
          : $type eq 'c_method' ? qq[\$class-E<gt>B<$name>$params]
          : $type eq 'ci_method'? qq[\$any-E<gt>B<$name>$params]
          : $type eq 'function' ? qq[B<$name>$params]
          : $type eq 'overload' ? qq[overload: B<$name>]
          : $type eq 'tie'      ? qq[B<$name>$params]
          :    panic $type;
	}

    panic $style;
}

sub publish($)
{   my ($self, $args) = @_;
    my $exporter = $args->{exporter} or panic;

    my $p      = $self->SUPER::publish($args);
    $p->{call} = $self->_call($exporter);

    my $opts   = $self->collectedOptions; # = [ [ $option, $default ], ... ]
    if(keys %$opts)
    {   my @options = map +[ map $_->publish($args)->{id}, @$_ ],
            sort { $a->[0]->name cmp $b->[0]->name }
                values %$opts;

        $p->{options}= \@options;
    }

    my @d = map $_->publish($args)->{id}, $self->diagnostics;
    $p->{diagnostics} = \@d if @d;
    $p;
}

=method extends [$object]
Subroutine documentation can overrule the documentation on a lower
level, but only when that overruled subroutine is of the same type.

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
    @_ or return $self->SUPER::extends;

    my $super = shift;
    if($self->type ne $super->type)
    {   my ($fn1, $ln1) = $self->where;
        my ($fn2, $ln2) = $super->where;
        my ($t1,  $t2 ) = ($self->type, $super->type);

        warning __x"subroutine {name}() extended by different type:\n  {type1} in {file1} line {line1}\n  {type2} in {file2} line {line2}"
          , name => "$self"
          , type1 => $t1, file1 => $fn1, line1 => $ln1
          , type2 => $t2, file2 => $fn2, line2 => $ln2;
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

=method location $manual
Try to figure-out what the location for the subroutine is within the
$manual page.  Have a look at all levels of extension for this
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
    my $super     = $self->extends
        or return $container;

    my $superloc  = $super->location;
    my $superpath = $superloc->path;
    my $mypath    = $container->path;

    return $container if $superpath eq $mypath;

    if(length $superpath < length $mypath)
    {   return $container
            if substr($mypath, 0, length($superpath)+1) eq "$superpath/";
    }
    elsif(substr($superpath, 0, length($mypath)+1) eq "$mypath/")
    {   return $self->manual->chapter($superloc->name)
            if $superloc->isa("OODoc::Text::Chapter");

        my $chapter = $self->manual->chapter($superloc->chapter->name);

        return $chapter->section($superloc->name)
            if $superloc->isa("OODoc::Text::Section");

        my $section = $chapter->section($superloc->section->name);

        return $section->subsection($superloc->name)
            if $superloc->isa("OODoc::Text::SubSection");

        my $subsection = $section->subsection($superloc->subsection->name);

        return $subsection->subsubsection($superloc->name)
            if $superloc->isa("OODoc::Text::SubSubSection");

        panic $superloc;
   }

   unless($manual->inherited($self))
   {   my ($myfn, $myln)       = $self->where;
       my ($superfn, $superln) = $super->where;

       warning __x"subroutine {name}() location conflict:\n  {path1} in {file1} line {line1}\n  {path2} in {file2} line {line2}"
         , name => "$self"
         , path1 => $mypath, file1 => $myfn, line1 => $myln
         , path2 => $superpath, file2 => $superfn, line2 => $superln;
   }

   $container;
}

=method path 
Returns the path of the text structure which contains this subroutine.
=cut

sub path() { shift->container->path }

#-------------------------------------------
=section Collected

=method default $name|$object
In case of a $name, a default object for this method is looked up.  This
does not search through super classes, but solely which is defined with
this subroutine.  When passed an $object of type OODoc::Text::Default
that will be stored.
=cut

sub default($)
{   my ($self, $it) = @_;
    blessed $it
        or return $self->{OTS_defaults}{$it};

    my $name = $it->name;
    $self->{OTS_defaults}{$name} = $it;
    $it;
}

=method defaults 
Returns a list of all defaults as defined by this documentation item in
one manual.
=cut

sub defaults() { values %{shift->{OTS_defaults}} }

=method option $name|$object
In case of a $name, the option object for this method is looked up.  This
does not search through super classes, but solely which is defined with
this subroutine.  When passed an $object of type OODoc::Text::Option
that will be stored.
=cut

sub option($)
{   my ($self, $it) = @_;
    ref $it
        or return $self->{OTS_options}{$it};

    my $name = $it->name;
    $self->{OTS_options}{$name} = $it;
    $it;
}

=method findOption $name
Does a little more thorough job than M<option()> by searching the inherited
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

=method diagnostic $object
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
    foreach my $base ($self->extends)
    {   my $options = $base->collectedOptions;
        @options{keys %$options} = values %$options;
    }

    $options{$_->name}[0] = $_ for $self->options;

    foreach my $default ($self->defaults)
    {   my $name = $default->name;

        unless(exists $options{$name})
        {   my ($fn, $ln) = $default->where;
            warning __x"no option {name} for default in {file} line {line}", name => $name, file => $fn, line => $ln;
            next;
        }
        $options{$name}[1] = $default;
    }

    foreach my $option ($self->options)
    {   my $name = $option->name;
        next if defined $options{$name}[1];

        my ($fn, $ln) = $option->where;
        warning __x"no default for option {name} defined in {file} line {line}", name => $name, file => $fn, line => $ln;

        my $default = $options{$name}[1] =
            OODoc::Text::Default->new(name => $name, value => 'undef', subroutine => $self, linenr => $ln);

        $self->default($default);
    }

    \%options;
}

1;
