
package OODoc::Manual;
use base 'OODoc::Object';

use strict;
use warnings;

use Carp;
use List::Util 'first';
use OODoc::Text::Chapter;

=chapter NAME

OODoc::Manual - one manual about a package

=chapter SYNOPSIS

 my $doc    = OODoc->new(...);
 my $manual = OODoc::Manual->new(name => ..., source => ...);

 $doc->manual($manual);
 my @manual = $doc->manualsForPackage('Mail::Box');

 print $manual->name;
 print $manual->package;

=chapter DESCRIPTION

The C<OODoc::Manual> object contains information of a singel manual page.
More than one manual can be related to a single package.

=chapter OVERLOADED

=overload stringification

Used in string context, a manual produces its name.

=cut

use overload '""' => sub { shift->name };
use overload bool => sub {1};

=overload cmp
String comparison takes place between a manual name and another
manual name which may be a manual object or any other string or
stringifyable object.

=examples

 if($manual eq 'OODoc') ...
 if($man1 eq $man2) ...
 my @sorted = sort @manuals;    # implicit calls to cmp

=cut

use overload cmp  => sub {$_[0]->name cmp "$_[1]"};

#-------------------------------------------

=chapter METHODS

=c_method new OPTIONS

=requires parser OBJECT
The parser which produces this manual page.  This parameter is needed
to be able to low-level format the text blocks.

=requires package STRING
The name of the package which is described by this manual.

=requires source STRING
The file where the manual was found in, or in some cases some other
string which explains where the data came from.

=requires version STRING

=option  stripped STRING
=default stripped undef
The file where the stripped code is written to.

=option  pure_pod BOOLEAN
=default pure_pod <false>
Some documentation is stored in files which look like a module,
but do not contain any code.  Their filenames usually end with C<.pod>.

=requires distribution STRING

=error   package name is not specified
You try to instantiate a manual, but have not specified the name
of the package which is described in this manual, which is required.

=error   no source filename is specified for manual $name
You have to specify where you found the information for the manual.  This
does not need to be the name of an existing file, but usually it will be.

=error  no version is specified for manual $name
=error  no distribution is specified for manual $name
=cut

sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args) or return;

    my $name = $self->{OP_package} = delete $args->{package}
       or croak "ERROR: package name is not specified";

    $self->{OP_source}   = delete $args->{source}
        or croak "ERROR: no source filename is specified for manual $name";

    $self->{OP_version}  = delete $args->{version}
        or croak "ERROR: no version is specified for manual $name";

    $self->{OP_distr}    = delete $args->{distribution}
        or croak "ERROR: no distribution is specified for manual $name";

    $self->{OP_parser}   = delete $args->{parser}    or confess;
    $self->{OP_stripped} = delete $args->{stripped};

    $self->{OP_pure_pod} = delete $args->{pure_pod} || 0;
    $self->{OP_chapter_hash} = {};
    $self->{OP_chapters}     = [];
    $self->{OP_subclasses}   = [];
    $self->{OP_realizers}    = [];
    $self->{OP_extra_code}   = [];

    $self;
}

#-------------------------------------------

=section Attributes

=method package
Returns the package of the manual.
=cut

sub package() {shift->{OP_package}}

=method parser
Returns the parser which has produced this manual object.
=cut

sub parser() {shift->{OP_parser}}

=method source
Returns the source of this manual information.
=cut

sub source() {shift->{OP_source}}

=method version
Returns the version of this manual information.
=cut

sub version() {shift->{OP_version}}

=method distribution
Returns the distribution which includes this manual.
=cut

sub distribution() {shift->{OP_distr}}

=method stripped
The name of the produced stripped package file.
=cut

sub stripped() {shift->{OP_stripped}}

=method isPurePod
Returns whether this package has real code related to it.
=cut

sub isPurePod() {shift->{OP_pure_pod}}

#-------------------------------------------

=section Collected

=method chapter NAME|OBJECT
When a NAME (a string) given, the chapter with that name is returned, or
C<undef> when it is not known.  With an OBJECT, that object is added to
the list of chapters.

=error two chapters named $name in $filename line $ln1 and $ln2
The indicated file contains two chapters with the same name, which
is not permitted.  Join the contents of both parts.

=cut

sub chapter($)
{   my ($self, $it) = @_;
    ref $it
        or return $self->{OP_chapter_hash}{$it};

    $it->isa("OODoc::Text::Chapter")
        or confess "ERROR: $it is not a chapter";

    my $name = $it->name;
    if(my $old = $self->{OP_chapter_hash}{$name})
    {   my ($fn,   $ln2) = $it->where;
        my (undef, $ln1) = $old->where;
        die "ERROR: two chapters named $name in $fn line $ln2 and $ln1\n";
    }

    $self->{OP_chapter_hash}{$name} = $it;
    push @{$self->{OP_chapters}}, $it;
    $it;
}

=method chapters [CHAPTERS]
Returns the ordered list of chapter object for this manual.
=cut

sub chapters(@)
{   my $self = shift;
    if(@_)
    {   $self->{OP_chapters}     = [ @_ ];
        $self->{OP_chapter_hash} = { map { ($_->name => $_) } @_ };
    }
    @{$self->{OP_chapters}};
}

=method name
Returns the name of the manual, which is found in the NAME chapter.

=error No chapter NAME in scope of package $pkg in file $source
Each documentation part requires a chapter "NAME" which starts with
the manual name followed by a dash.  Apparently, this was not found
in the indicated file.  This chapter description must be anywhere
after the package statement leading the name-space.

=error The NAME chapter does not have the right format in $source
The NAME chapter is used to figure-out what name the manual page must
have.  The standard format contains only one line, containing the
manual's name, one dash ('-'), and then a brief explanation. For instance:
  =chapter NAME
  OODoc::Manual - one manual about a package

=cut

sub name()
{   my $self    = shift;
    return $self->{OP_name} if defined $self->{OP_name};

    my $chapter = $self->chapter('NAME')
        or die 'ERROR: No chapter NAME in scope of package ',$self->package
             , ' in file '.$self->source."\n";

    my $text   = $chapter->description || '';
    $text =~ m/^\s*(\S+)\s*\-\s/
        or die "ERROR: The NAME chapter does not have the right format in "
             , $self->source, "\n";

    $self->{OP_name} = $1;
}


=method subroutines
All subroutines of all chapters within this manual together, especially
useful for counting.

=example
 print scalar $manual->subroutines;

=cut

sub subroutines() { shift->all('subroutines') }

=method subroutine NAME
Returns the subroutine with the specified NAME as object reference.  When
the manual is part of a package description which is spread over multiple
manuals, then these other manuals will be searched as well.
=cut

sub subroutine($)
{   my ($self, $name) = @_;
    my $sub;

    my $package = $self->package;
    my @parts   = defined $package ? $self->manualsForPackage($package) : $self;

    foreach my $part (@parts)
    {   foreach my $chapter ($part->chapters)
        {   $sub = first {defined $_} $chapter->all(subroutine => $name);
            return $sub if defined $sub;
        }
    }

    ();
}

=method examples
All examples of all chapters within this manual together, especially
useful for counting.

=example
 print scalar $manual->examples;

=cut

sub examples()
{   my $self = shift;
    ( $self->all('examples')
    , map {$_->examples} $self->subroutines
    );
}

=method diagnostics OPTIONS
All diagnostic messages of all chapters for this manual together.

=option  select ARRAY
=default select []
Select only the diagnostic message of the specified types (case
insensitive).  Without any type, all are selected.

=cut

sub diagnostics(@)
{   my ($self, %args) = @_;
    my @select = $args{select} ? @{$args{select}} : ();

    my @diag = map {$_->diagnostics} $self->subroutines;
    return @diag unless @select;

    my $select;
    {   local $" = '|';
        $select = qr/^(@select)$/i;
    }

    grep {$_->type =~ $select} @diag;
}


#-------------------------------------------

=section Inheritance knowledge

=method superClasses [PACKAGES]
Returns the super classes for this package.  PACKAGES (names or objects)
will be added to the list of superclasses first.
=cut

sub superClasses(;@)
{   my $self = shift;
    push @{$self->{OP_isa}}, @_;
    @{$self->{OP_isa}};
}

=method realizes [PACKAGE]
Returns the class into which this class can be realized.  This is
a trick of the Object::Realize::Later module.  The PACKAGE (name or
object) will be set first, if specified.
=cut

sub realizes(;$)
{   my $self = shift;
    @_ ? ($self->{OP_realizes} = shift) : $self->{OP_realizes};
}

=method subClasses [PACKAGES]
Returns the names of all sub-classes (extensions) of this package.
When PACKAGES (names or objects) are specified, they are first added
to the list.
=cut

sub subClasses(;@)
{   my $self = shift;
    push @{$self->{OP_subclasses}}, @_;
    @{$self->{OP_subclasses}};
}

=method realizers [PACKAGES]
Returns a list of packages which can realize into this object
using Object::Realize::Later magic.  When PACKAGES (names or objects)
are specified, they are added first.
=cut

sub realizers(;@)
{   my $self = shift;
    push @{$self->{OP_realizers}}, @_;
    @{$self->{OP_realizers}};
}

=method extraCode
Returns a list of manuals which contain extra code for this package.
=cut

sub extraCode()
{   my $self = shift;
    my $name = $self->name;

    $self->package eq $name
    ? grep {$_->name ne $name} $self->manualsForPackage($name)
    : ();
}

=method all METHOD, PARAMETERS
Call M<OODoc::Text::Structure::all()> on all chapters, passing the METHOD
and PARAMETERS.  In practice, this means that you can simply collect
kinds of information from various parts within the manual page.

=example
 my @diags = $manual->all('diagnostics');

=cut

sub all($@)
{   my $self = shift;
    map { $_->all(@_) } $self->chapters;
}

=method inherited SUBROUTINE|OPTION
Returns whether the SUBROUTINE or OPTION was defined by this manual page,
or inherited from it.
=cut

sub inherited($) {$_[0]->name ne $_[1]->manual->name}

=method ownSubroutines
Returns only the subroutines which are described in this manual page
itself.  M<subroutines()> returns them all.
=cut

sub ownSubroutines
{   my $self = shift;
    my $me   = $self->name || return 0;
    grep {not $self->inherited($_)} $self->subroutines;
}

#-------------------------------------------

=section Processing

=method collectPackageRelations
=cut

sub collectPackageRelations()
{   my $self = shift;
    return () if $self->isPurePod;

    my $name = $self->package;
    my %return;

    # The @ISA / use base
    {  no strict 'refs';
       $return{isa} = [ @{"${name}::ISA"} ];
    }

    # Support for Object::Realize::Later
    $return{realizes} = $name->willRealize if $name->can('willRealize');

    %return;
}

=method expand
Add the information of lower level manuals into this one.
=cut

sub expand()
{   my $self = shift;
    return $self if $self->{OP_is_expanded};

    #
    # All super classes much be expanded first.  Manuals for
    # extra code are considered super classes as well.  Super
    # classes which are external are ignored.
    #

    my @supers  = reverse     # multiple inheritance, first isa wins
                      grep { ref $_ }
                          $self->superClasses;

    $_->expand for @supers;

    #
    # Expand chapters, sections and subsections.
    #

    my @chapters = $self->chapters;

    my $merge_subsections =
        sub {  my ($section, $inherit) = @_;
               $section->extends($inherit);
               $section->subsection($self->mergeStructure
                ( this      => [ $section->subsections ]
                , super     => [ $inherit->subsections ]
                , merge     => sub { $_[0]->extends($_[1]) }
                , container => $section
                ));
               $section;
            };

    my $merge_sections =
        sub {  my ($chapter, $inherit) = @_;
               $chapter->extends($inherit);
               $chapter->sections($self->mergeStructure
                ( this      => [ $chapter->sections ]
                , super     => [ $inherit->sections ]
                , merge     => $merge_subsections
                , container => $chapter
                ));
               $chapter;
            };

    foreach my $super (@supers)
    {
        $self->chapters($self->mergeStructure
         ( this      => \@chapters
         , super     => [ $super->chapters ]
         , merge     => $merge_sections
         , container => $self
         ));
    }

    #
    # Give all the inherited subroutines a new location in this manual.
    #

    my %extended  = map { ($_->name => $_) }
                       map { $_->subroutines }
                          ($self, $self->extraCode);
    my %used;  # items can be used more than once, collecting mulitple inherit

    my @inherited = map { $_->subroutines  } @supers;
    my %location;

    foreach my $inherited (@inherited)
    {   my $name        = $inherited->name;
        if(my $extended = $extended{$name})
        {   $extended->extends($inherited);
            unless($used{$name}++)    # add only at first appearance
            {   my $path = $self->mostDetailedLocation($extended);
                push @{$location{$path}}, $extended;
            }
        }
        else
        {   my $path = $self->mostDetailedLocation($inherited);
            push @{$location{$path}}, $inherited;
        }
    }

    while(my($name, $item) = each %extended)
    {   next if $used{$name};
        push @{$location{$item->path}}, $item;
    }

    foreach my $chapter ($self->chapters)
    {   $chapter->setSubroutines(delete $location{$chapter->path});
        foreach my $section ($chapter->sections)
        {   $section->setSubroutines(delete $location{$section->path});
            foreach ($section->subsections)
            {   $_->setSubroutines(delete $location{$_->path});
            }
        }
    }

    warn "ERROR: Section without location in $self: $_\n"
        for keys %location;

    $self->{OP_is_expanded} = 1;
    $self;
}

=method mergeStructure OPTIONS
Merge two lists of structured text objects: "this" list and "super" list.
The "this" objects are defined on this level of inheritance, where the
"super" objects are from an inheritence level higher (super class).
The combined list is returned, where the inherited objects are
preferably included before the new ones.

Merging is a complicated task, because the order of both lists should be
kept as well as possible.

=option  this ARRAY
=default this []

=option  super ARRAY
=default super []

=requires container OBJECT

=option  equal CODE
=default equal sub {"$_[0]" eq "$_[1]"}
Define how can be determined that two objects are the same.  By default,
the stringification of both objects are compared.

=option  merge CODE
=default merge sub {$_[0]}
What to call if both lists contain the same object.  These two objects
will be passed as argument to the code reference.

=warning order conflict "$take" before "$insert" in $file line $number
The order of the objects in a sub-class shall be the same as that of
the super class, otherwise the result of merging of the information
received from both classes is undertermined.

=cut

sub mergeStructure(@)
{   my ($self, %args) = @_;
    my @this      = defined $args{this}  ? @{$args{this}}  : ();
    my @super     = defined $args{super} ? @{$args{super}} : ();
    my $container = $args{container} or confess;

    my $equal     = $args{equal} || sub {"$_[0]" eq "$_[1]"};
    my $merge     = $args{merge} || sub {$_[0]};

    my @joined;

    while(@super)
    {   my $take = shift @super;
        unless(first {$equal->($take, $_)} @this)
        {   push @joined, $take->emptyExtension($container);
            next;
        }

        # A low-level merge is needed.

        my $insert;
        while(@this)      # insert everything until equivalents
        {   $insert = shift @this;
            last if $equal->($take, $insert);

            if(first {$equal->($insert, $_)} @super)
            {   my ($fn, $ln) = $insert->where;
                warn "WARNING: order conflict \"$take\" before \"$insert\" in $fn line $ln\n";
            }

            push @joined, $insert;
        }

        push @joined, $merge->($insert, $take);
    }

    (@joined, @this);
}

=method mostDetailedLocation OBJECT
The OBJECT (a text element) is lccated in some subsection, section or
chapter.  But the OBJECT may also be an extension to a piece of
documentation which is described in a super class with a location in
more detail.  The most detailed location for the description is returned.

=warning subroutine $name location conflict: $here and $there
Finding the optimal location to list a subroutine description is
a harsh job: information from various manual pages is being used.

It is not a problem to list the documentation of a certain method M
in module A in chapter "METHODS", section "General", subsection "X"
(which is abbreviated in the report as METHODS/General/X), and the
same method M in module A::B, which extends A, in chapter "METHODS"
without providing details about the section and subsection.  The in most
detail descripted location is used everywhere.

This warning means that the location of the method in this manual page
is not related to that of the same method in an other page.  For instance,
in the first page it is listed in chapter "METHODS", and in the second
in chapter "FUNCTIONS".

=cut

sub mostDetailedLocation($)
{   my ($self, $thing) = @_;

    my $inherit = $thing->extends
       or return $thing->path;

   my $path1    = $thing->path;
   my $path2    = $self->mostDetailedLocation($inherit);
   my ($lpath1, $lpath2) = (length($path1), length($path2));

   return $path1 if $path1 eq $path2;

   return $path2
      if $lpath1 < $lpath2 && substr($path2, 0, $lpath1+1) eq "$path1/";

   return $path1
      if $lpath2 < $lpath1 && substr($path1, 0, $lpath2+1) eq "$path2/";

   warn "WARNING: subroutine $thing location conflict:\n"
      , "   $path1 in ",$thing->manual, "\n"
      , "   $path2 in ",$inherit->manual, "\n"
         if $self eq $thing->manual;

   $path1;
}

=method createInheritance
Create the text which represents the inheritance relationships of
a certain package.  More than one MANUAL can be defined for one
package, and will each produce the same text.  The returned string
still has to be cleaned-up before inclusion.
=cut

sub createInheritance()
{   my $self = shift;

    if($self->name ne $self->package)
    {   # This is extra code....
        my $from = $self->package;
        return "\n $self\n    contains extra code for\n    M<$from>\n";
    }

    my $output;
    my @supers  = $self->superClasses;

    if(my $realized = $self->realizes)
    {   $output .= "\n $self realizes a M<$realized>\n";
        @supers = $realized->superClasses if ref $realized;
    }

    if(my @extras = $self->extraCode)
    {   $output .= "\n $self has extra code in\n";
        $output .= "   M<$_>\n" foreach sort @extras;
    }

    foreach my $super (@supers)
    {   $output .= "\n $self\n";
        $output .= $self->createSuperSupers($super);
    }

    if(my @subclasses = $self->subClasses)
    {   $output .= "\n $self is extended by\n";
        $output .= "   M<$_>\n" foreach sort @subclasses;
    }

    if(my @realized = $self->realizers)
    {   $output .= "\n $self is realized by\n";
        $output .= "   M<$_>\n" foreach sort @realized;
    }

    my $chapter = OODoc::Text::Chapter->new
      ( name        => 'INHERITANCE'
      , manual      => $self
      , linenr      => -1
      , description => $output
      );

    $self->chapter($chapter);
}

sub createSuperSupers($)
{   my ($self, $package) = @_;
    my $output = "   is a M<$package>\n";
    return $output
        unless ref $package;  # only the name of the package is known

    if(my $realizes = $package->realizes)
    {   $output .= $self->createSuperSupers($realizes);
        return $output;
    }

    my @supers = $package->superClasses or return $output;
    $output   .= $self->createSuperSupers(shift @supers);

    foreach(@supers)
    {   $output .= "\n\n   $package also extends M<$_>\n";
        $output .= $self->createSuperSupers($_);
    }

    $output;
}

#-------------------------------------------

=section Tracing

=method stats
Returns a string which displays some stats about the manual.
=cut

sub stats()
{   my $self     = shift;
    my $chapters = $self->chapters || return;
    my $subs     = $self->ownSubroutines;
    my $options  = map { $_->options } $self->ownSubroutines;
    my $diags    = $self->diagnostics;
    my $examples = $self->examples;

    my $manual   = $self->name;
    my $package  = $self->package;
    my $head
      = $manual eq $package
      ? "manual $manual"
      : "manual $manual for $package";

    <<STATS;
$head
   chapters:               $chapters
   documented subroutines: $subs
   documented options:     $options
   documented diagnostics: $diags
   shown examples:         $examples
STATS
}

#-------------------------------------------

=section Commonly used functions
=cut

1;
