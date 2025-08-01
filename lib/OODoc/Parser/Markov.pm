package OODoc::Parser::Markov;
use parent 'OODoc::Parser';

use strict;
use warnings;

use Log::Report    'oodoc';

use OODoc::Text::Chapter       ();
use OODoc::Text::Section       ();
use OODoc::Text::SubSection    ();
use OODoc::Text::SubSubSection ();
use OODoc::Text::Subroutine    ();
use OODoc::Text::Option        ();
use OODoc::Text::Default       ();
use OODoc::Text::Diagnostic    ();
use OODoc::Text::Example       ();
use OODoc::Manual              ();

use File::Spec;

my $url_modsearch = "http://search.cpan.org/perldoc?";
my $url_coderoot  = 'CODE';
my @default_rules;

=chapter NAME

OODoc::Parser::Markov - Parser for the MARKOV syntax

=chapter SYNOPSIS

=chapter DESCRIPTION

The "Markov parser" is named after the author, because the author likes
to invite other people to write their own parser as well: every one has
not only their own coding style, but also their own documentation wishes.

The task for the parser is to strip Perl package files into a code part
and a documentation tree.  The code is written to a directory where the
module distribution is built, the documenation tree is later formatted
into manual pages.

=chapter METHODS

#--------------------------
=section Constructors

=c_method new %options

=option  additional_rules ARRAY
=default additional_rules []

Reference to an array which contains references to match-action pairs,
as accepted by M<rule()>.  These rules get preference over the existing
rules.

=cut

sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args) or return;

    my @rules = @default_rules;
    unshift @rules, @{delete $args->{additional_rules}}
        if exists $args->{additional_rules};

    $self->{OPM_rules} = [];
    $self->rule(@$_) for @rules;
    $self;
}

#------------------
=section Attributes

=method setBlock REF-SCALAR
Set the scalar where the next documentation lines should be collected
in.
=cut

sub setBlock($)
{   my ($self, $ref) = @_;
    $self->{OPM_block} = $ref;
    $self->inDoc(1);
    $self;
}

=method inDoc [BOOLEAN]
When a BOOLEAN is specified, the status changes.  It returns the current
status of the document reader.
=cut

sub inDoc(;$) { my $s = shift; @_ ? $s->{OPM_in_pod} = shift : $s->{OPM_in_pod} }

=method currentManual [$manual]
Returns the manual object which is currently being filled with data.
With a new $manual, a new one is set.
=cut

sub currentManual(;$) { my $s = shift; @_ ? ($s->{OPM_manual} = shift) : $s->{OPM_manual} }

=method rules
Returns the ARRAY of active rules.  You may modify it.
=cut

sub rules() { $_[0]->{OPM_rules} }

#-------------------------------------------
=section Parsing a file
=cut

@default_rules =
  ( [ '=cut'        => 'docCut'        ]
  , [ '=chapter'    => 'docChapter'    ]
  , [ '=section'    => 'docSection'    ]
  , [ '=subsection' => 'docSubSection' ]
  , [ '=subsubsection' => 'docSubSubSection' ]
  , [ '=method'     => 'docSubroutine' ]
  , [ '=i_method'   => 'docSubroutine' ]
  , [ '=c_method'   => 'docSubroutine' ]
  , [ '=ci_method'  => 'docSubroutine' ]
  , [ '=function'   => 'docSubroutine' ]
  , [ '=tie'        => 'docSubroutine' ]
  , [ '=overload'   => 'docSubroutine' ]
  , [ '=option'     => 'docOption'     ]
  , [ '=default'    => 'docDefault'    ]
  , [ '=requires'   => 'docRequires'   ]
  , [ '=example'    => 'docExample'    ]
  , [ '=examples'   => 'docExample'    ]
  , [ '=error'      => 'docDiagnostic' ]
  , [ '=warning'    => 'docDiagnostic' ]
  , [ '=notice'     => 'docDiagnostic' ]
  , [ '=debug'      => 'docDiagnostic' ]
 
  # deprecated
  , [ '=head1'      => 'docChapter'    ]
  , [ '=head2'      => 'docSection'    ]
  , [ '=head3'      => 'docSubSection' ]
 
  # problem spotter
  , [ qr/^(warn|die|carp|confess|croak)\s/ => 'debugRemains' ]
  , [ qr/^( sub \s+ \w
          | (?:my|our) \s+ [\($@%]
          | (?:package|use) \s+ \w+\:
          )
        /x => 'forgotCut' ]
  );

=method rule <STRING|Regexp>, <$method|CODE>

Register a rule which will be applied to a line in the input file.  When
a STRING is specified, it must start at the beginning of the line to be
selected.  You may also specify a regular expression which will match
on the line.

The second argument is the action which will be taken when the line
is selected.  Either the named $method or the CODE reference will be called.
Their arguments are:

 $parser->METHOD($match, $line, $file, $linenumber);
 CODE->($parser, $match, $line, $file, $linenumber);

=cut

sub rule($$)
{   my ($self, $match, $action) = @_;
    push @{$self->rules}, [$match, $action];
    $self;
}

=method findMatchingRule $line
Check the list of rules whether this $line matches one of them.  This
is an ordered evaluation.  Returned is the matched string and the required
action.  If the line fails to match anything, an empty list is returned.

=example
  if(my($match, $action) = $parser->findMatchingRule($line))
  {  # do something with it
     $action->($parser, $match, $line);
  }

=cut

sub findMatchingRule($)
{   my ($self, $line) = @_;

    foreach ( @{$self->rules} )
    {   my ($match, $action) = @$_;
        if(ref $match)
        {   return ($&, $action) if $line =~ $match;
        }
        elsif(substr($line, 0, length($match)) eq $match)
        {   return ($match, $action);
        }
    }

    ();
}

=method parse %options

=requires input FILENAME

=option   output FILENAME
=default  output devnull

=requires distribution STRING
=requires version STRING

=option   notice STRING
=default  notice ''
Block of text added in from of the output file.

=error no input file to parse specified
The parser needs the name of a file to be read, otherwise it can not
work.

=error cannot read document from $input: $!
The document file can not be processed because it can not be read.  Reading
is required to be able to build a documentation tree.

=warning doc did not end in $input
When the whole $input was parsed, the documentation part was still open.
Probably you forgot to terminate it with a C<=cut>.

=warning unknown markup in $file line $number: $line
The standard pod and the extensions made by this parser define a long
list of markup keys, but yours is not one of these predefined names.

=cut

sub parse(@)
{   my ($self, %args) = @_;

    my $input   = $args{input}
       or error __x"no input file to parse specified";

    my $output  = $args{output} || File::Spec->devnull;
    my $version = $args{version}      or panic;
    my $distr   = $args{distribution} or panic;

    open my $in, '<:encoding(utf8)', $input
        or fault __x"cannot read document from {file}", file => $input;

    open my $out, '>:encoding(utf8)', $output
        or fault __x"cannot write stripped code to {file}", file => $output;

    # pure doc files have no package statement included, so it shall
    # be created beforehand.

    my ($manual, @manuals);

    my $pure_pod = $input =~ m/\.pod$/;
    if($pure_pod)
    {   $manual = OODoc::Manual->new
          ( package  => $self->filenameToPackage($input)
          , pure_pod => 1
          , source   => $input
          , parser   => $self

          , distribution => $distr
          , version      => $version
          );

        push @manuals, $manual;
        $self->currentManual($manual);
        $self->inDoc(1);
    }
    else
    {   $out->print($args{notice}) if $args{notice};
        $self->inDoc(0);
    }

    # Read through the file.

    while(my $line = $in->getline)
    {   my $ln = $in->input_line_number;

        if(    !$self->inDoc
            && $line !~ m/^\s*package\s*DB\s*;/
            && $line =~ s/^(\s*package\s*([\w\-\:]+)\s*\;)//
          )
        {   $out->print($1);
            my $package = $2;

            # Wrap VERSION declaration in a block to avoid any problems with
            # double declaration
            $out->print("{\nour \$VERSION = '$version';\n}\n");
            $out->print($line);

            $manual = OODoc::Manual->new
              ( package  => $package
              , source   => $input
              , stripped => $output
              , parser   => $self

              , distribution => $distr
              , version      => $version
              );
            push @manuals, $manual;
            $self->currentManual($manual);
        }
        elsif(!$self->inDoc && $line =~ m/^=package\s*([\w\-\:]+)\s*$/)
        {   my $package = $1;
            $manual = OODoc::Manual->new
              ( package  => $package
              , source   => $input
              , stripped => $output
              , parser   => $self
              , distribution => $distr
              , version      => $version
              );
            push @manuals, $manual;
            $self->currentManual($manual);
        }
        elsif(my($match, $action) = $self->findMatchingRule($line))
        {   $self->$action($match, $line, $input, $ln)
                or $out->print($line);
        }
        elsif($line =~ m/^=(over|back|item|for|pod|begin|end|head4|encoding)\b/)
        {   ${$self->{OPM_block}} .= "\n". $line;
            $self->inDoc(1);
        }
        elsif(substr($line, 0, 1) eq '=')
        {   warning __x"unknown markup in {file} line {linenr}:\n {line}", file => $input, linenr => $ln, line => $line;
            ${$self->{OPM_block}} .= $line;
            $self->inDoc(1);
        }
        elsif($pure_pod || $self->inDoc)
        {   # add the line to the currently open text block
            my $block = $self->{OPM_block};
            unless($block)
            {   warning __x"no block for line {linenr} in file {file}\n {line}", file => $input, linenr => $ln, line => $line;
                my $dummy = '';
                $block = $self->setBlock(\$dummy);
            }
            $$block  .= $line;
        }
        elsif($line eq "__DATA__\n")  # flush rest file
        {   $out->print($line, $in->getlines);
        }
        else
        {   $out->print($line);
        }
    }

    ! $self->inDoc || $pure_pod
        or warning __x"doc did not end in {file}", file => $input;

    $self->closeChapter;
    $in->close && $out->close;

    @manuals;
}

=warning Pod tag $tag does not terminate any doc in $file line $number
There is no document to end here.
=cut

sub docCut($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;

    if($self->currentManual->isPurePod)
    {   warn "The whole file $fn is pod, so =cut in line $ln is useless.\n";
        return;
    }

    $self->inDoc
        or warning __x"Pod tag {tag} does not terminate any doc in {file} line {line}", tag => $match, file => $fn, line => $ln;

    $self->inDoc(0);
    1;
}

#-------------------------------------------
# CHAPTER

=error chapter `$name' before package statement in $file line $number
A package file can contain more than one package: more than one
name space.  The docs are sorted after the name space.  Therefore,
each chapter must be preceeded by a package statement in the file
to be sure that the correct name space is used.
=cut

sub docChapter($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;
    $line =~ s/^\=(chapter|head1)\s+//;
    $line =~ s/\s+$//;

    $self->closeChapter;

    my $manual = $self->currentManual
        or error __x"chapter {name} before package statement in {file} line {line}", name => $line, file => $fn, line => $ln;

    my $chapter = $self->{OPM_chapter} =
        OODoc::Text::Chapter->new(name => $line, manual => $manual, linenr => $ln);

    $self->setBlock($chapter->openDescription);
    $manual->chapter($chapter);
    $chapter;
}

sub closeChapter()
{   my $self = shift;
    my $chapter = delete $self->{OPM_chapter} or return;
    $self->closeSection()->closeSubroutine();
}

#-------------------------------------------
# SECTION

=error section '$name' outside chapter in $file line $number
Sections must be contained in chapters.
=cut

sub docSection($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;
    $line =~ s/^\=(section|head2)\s+//;
    $line =~ s/\s+$//;

    $self->closeSection;

    my $chapter = $self->{OPM_chapter}
        or error __x"section '{name}' outside chapter in {file} line {line}", name => $line, file => $fn, line => $ln;

    my $section = $self->{OPM_section} =
        OODoc::Text::Section->new(name => $line, chapter => $chapter, linenr => $ln);

    $chapter->section($section);
    $self->setBlock($section->openDescription);
    $section;
}

sub closeSection()
{   my $self    = shift;
    my $section = delete $self->{OPM_section} or return $self;
    $self->closeSubSection();
}

#-------------------------------------------
# SUBSECTION

=error subsection '$name' outside section in $file line $number
Subsections are only allowed in a chapter when it is nested within
a section.
=cut

sub docSubSection($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;
    $line =~ s/^\=(subsection|head3)\s+//;
    $line =~ s/\s+$//;

    $self->closeSubSection;

    my $section = $self->{OPM_section}
        or error __x"subsection '{name}' outside section in {file} line {line}", name => $line, file => $fn, line => $ln;

    my $subsection = $self->{OPM_subsection} =
        OODoc::Text::SubSection->new(name => $line, section => $section, linenr => $ln);

    $section->subsection($subsection);
    $self->setBlock($subsection->openDescription);
    $subsection;
}

sub closeSubSection()
{   my $self       = shift;
    my $subsection = delete $self->{OPM_subsection};
    $self->closeSubSubSection;
}

#-------------------------------------------
# SUBSECTION

=error subsubsection '$name' outside subsection in $file line $number
Subsubsections are only allowed in a chapter when it is nested within
a subsection.
=cut

sub docSubSubSection($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;
    $line =~ s/^\=(subsubsection|head4)\s+//;
    $line =~ s/\s+$//;

    $self->closeSubSubSection;

    my $subsection = $self->{OPM_subsection}
        or error __x"subsubsection '{name}' outside section in {file} line {line}", name => $line, file => $fn, line => $ln;

    my $subsubsection = $self->{OPM_subsubsection} =
        OODoc::Text::SubSubSection->new(name => $line, subsection => $subsection, linenr => $ln);

    $subsection->subsubsection($subsubsection);
    $self->setBlock($subsubsection->openDescription);
    $subsubsection;
}

sub closeSubSubSection()
{   my $self = shift;
    delete $self->{OPM_subsubsection};
    $self->closeSubroutine;
}

#-------------------------------------------
# SUBROUTINES

=error subroutine $name outside chapter in $file line $number
Subroutine descriptions (method, function, tie, ...) can only be used
within a restricted set of chapters.  You have not started any
chapter yet.
=cut

sub docSubroutine($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;

    chomp $line;
    $line    =~ s/^\=(\w+)\s+//;
    my $type = $1;

    my ($name, $params)
     = $type eq 'overload' ? ($line, '')
     :                       $line =~ m/^(\w*)\s*(.*?)\s*$/;

    my $container = $self->{OPM_subsection} || $self->{OPM_section} || $self->{OPM_chapter}
        or error __x"subroutine {name} outside chapter in {file} line {line}", name => $name, file => $fn, line => $ln;

    $type    = 'i_method' if $type eq 'method';
    my $sub  = $self->{OPM_subroutine} =
       OODoc::Text::Subroutine->new(type => $type, name => $name, parameters => $params, linenr => $ln, container => $container);

    $self->setBlock($sub->openDescription);
    $container->addSubroutine($sub);
    $sub;
}

sub closeSubroutine()
{   my $self = shift;
    delete $self->{OPM_subroutine};
    $self;
}

#-------------------------------------------
# SUBROUTINE ADDITIONALS

=error option $name outside subroutine in $file line $number
An option is set, however there is not subroutine in scope (yet).

=warning option line incorrect in $file line $number: $line
The shown $line is not in the right format: it should contain at least
two words being the option name and an abstract description of possible
values.

=cut

sub docOption($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;

    unless($line =~ m/^\=option\s+(\S+)\s+(.+?)\s*$/ )
    {   warning __x"option line incorrect in {file} line {linenr}:\n {line}", file => $fn, linenr => $ln, line => $line;
        return;
    }
    my ($name, $parameters) = ($1, $2);

    my $sub  = $self->{OPM_subroutine}
        or error __x"option {name} outside subroutine in {file} line {line}", name => $name, file => $fn, line => $ln;

    my $option  = OODoc::Text::Option->new
      ( name       => $name
      , parameters => $parameters
      , linenr     => $ln
      , subroutine => $sub
      );

    $self->setBlock($option->openDescription);
    $sub->option($option);
    $sub;
}

#-------------------------------------------
# DEFAULT

=error default for option $name outside subroutine in $file line $number
A default is set, however there is not subroutine in scope (yet).  It
is plausible that the option does not exist either, but that will
be checked later.

=warning default line incorrect in $file line $number: $line
The shown $line is not in the right format: it should contain at least
two words being the option name and the default value.

=cut

sub docDefault($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;

    unless($line =~ m/^\=default\s+(\S+)\s+(.+?)\s*$/ )
    {   warning __x"default line incorrect in {file} line {linenr}:\n {line}", file => $fn, linenr => $ln, line => $line;
        return;
    }

    my ($name, $value) = ($1, $2);

    my $sub = $self->{OPM_subroutine}
       or error __x"default for option {name} outside subroutine in {file} line {line}", name => $name, file => $fn, line => $ln;

    my $default = OODoc::Text::Default->new(name => $name, value => $value, linenr => $ln, subroutine => $sub);

    $sub->default($default);
    $sub;
}

sub docRequires($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;

    unless($line =~ m/^\=requires\s+(\w+)\s+(.+?)\s*$/ )
    {   warning __x"requires line incorrect in {file} line {linenr}:\n {line}", file => $fn, linenr => $ln, line => $line;
        return;
    }

    my ($name, $param) = ($1, $2);
    $self->docOption ($match, "=option  $name $param", $fn, $ln);
    $self->docDefault($match, "=default $name <required>", $fn, $ln);
}

#-------------------------------------------
# DIAGNOSTICS

=warning no diagnostic message supplied in $file line $number
The start of a diagnostics message was indicated, however not provided
on the same line.

=error diagnostic $type outside subroutine in $file line $number
It is unclear to which subroutine this diagnostic message belongs.

=cut

sub docDiagnostic($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;

    $line =~ s/^\=(\w+)\s*//;
    my $type = $1;

    $line =~ s/\s*$//;
    unless(length $line)
    {   warning __x"no diagnostic message supplied in {file} line {line}", file => $fn, line => $ln;
        return;
    }

    my $sub  = $self->{OPM_subroutine}
        or error __x"diagnostic {type} outside subroutine in {file} line {line}", type => $type, file => $fn, line => $ln;

    my $diag  = OODoc::Text::Diagnostic->new(type => ucfirst($type), name => $line, linenr => $ln, subroutine => $sub);

    $self->setBlock($diag->openDescription);
    $sub->diagnostic($diag);
    $sub;
}

#-------------------------------------------
# EXAMPLE

=error example outside chapter in $file line $number
An example can belong to a subroutine, chapter, section, and subsection.
Apparently, this example was found before the first chapter started in
the file.

=cut

sub docExample($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;

    $line =~ s/^=examples?\s*//;
    $line =~ s/^\#.*//;

    my $container = $self->{OPM_subroutine}
                 || $self->{OPM_subsubsection}
                 || $self->{OPM_subsection}
                 || $self->{OPM_section}
                 || $self->{OPM_chapter};

    defined $container
        or error __x"example outside chapter in {file} line {line}", file => $fn, line => $ln;

    my $example  = OODoc::Text::Example->new(name => ($line || ''), linenr => $ln, container => $container);

    $self->setBlock($example->openDescription);
    $container->example($example);
    $example;
}

=warning Debugging remains in $filename line $number
The author's way of debugging is by putting warn/die/carp etc on the
first position of a line.  Other lines in a method are always indented,
which means that these debugging lines are clearly visible.  You may
simply ingnore this warning.
=cut

sub debugRemains($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;

    $self->inDoc || $self->currentManual->isPurePod
        or warning __x"Debugging remains in {file} line {line}", file => $fn, line => $ln;

    undef;
}

=warning You may have accidentally captured code in doc file $fn line $number
Some keywords on the first position of a line are very common for code.
However, code within doc should start with a blank to indicate pre-formatted
lines.  This warning may be false.
=cut

sub forgotCut($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;

    $self->inDoc && ! $self->currentManual->isPurePod
        and warning __x"You may have accidentally captured code in doc {file} line {line}", file => $fn, line => $ln;

    undef;
}

#-------------------------------------------
=section Producing manuals

=method decomposeM $manual, $link

=warning module $name is not on your system, but linked to in $manual
The module can not be found.  This may be an error at your part (usually
a typo) or you didn't install the module on purpose.  This message will
also be produced if some defined package is stored in one file together
with an other module or when compilation errors are encountered.

=warning subroutine $name is not defined by $package, found in $manual
=warning option "$name" unknow for $name() in $package, found in $manual

=warning no manual for $package (correct casing?)
The manual for $package cannot be found.  If you have a module named this
way, this may indicate that the NAME chapter of the manual page in that
module differs from the package name.  Often, this is a typo in the
NAME... probably a difference in used cases.

=warning use problem for module $link in $module; $@
In an attempt to check the correctness of your naming of a module,
OODoc will try to compile ("require") the named module.  Apparently,
the module was found, but something else went wrong.  The exact cause
is not always easy to find.

=cut

sub decomposeM($$)
{   my ($self, $manual, $link) = @_;

    my ($subroutine, $option) = $link =~ s/(?:^|\:\:) (\w+) \( (.*?) \)$//x ? ($1, $2) : ('', '');

    my $man;
       if(not length($link)) { $man = $manual }
    elsif(defined($man = $self->findManual($link))) { ; }
    else
    {   eval "no warnings; require $link";
        if(  ! $@
          || $@ =~ m/attempt to reload/i
          || $self->skipManualLink($link)
          ) { ; }
        elsif($@ =~ m/Can't locate/ )
        {   warning __x"module {name} is not on your system, found in {manual}", name => $link, manual => $manual;
        }
        else
        {  $@ =~ s/ at \(eval.*//;
           warning __x"use problem for module {name} in {manual};\n{err}", name => $link, manual => $manual, err => $@;
        }
        $man = $link;
    }

    unless(ref $man)
    {   return ( $manual
               , $man
                 . (length($subroutine) ? " subroutine $subroutine" : '')
                 . (length($option)     ? " option $option" : '')
               );
    }

    defined $subroutine && length $subroutine
        or return (undef, $man);

    my $package = $self->findManual($man->package);
    unless(defined $package)
    {   my $want = $man->package;
        warning __x"no manual for {package} (correct casing?)", package => $want;
        return (undef, "$want subroutine $subroutine");
    }

    my $sub     = $package->subroutine($subroutine);
    unless(defined $sub)
    {   warning __x"subroutine {call}() is not defined by {pkg}, but linked to in {manual}",
            call => $subroutine, pkg => $package, manual => $manual;
        return ($package, "$package subroutine $subroutine");
    }

    my $location = $sub->manual;
    defined $option && length $option
        or return ($location, $sub);

    my $opt = $sub->findOption($option);
    unless(defined $opt)
    {   warning __x"option '{name}' unknown for {call}() in {where}, found in {manual}",
            name => $option, call => $subroutine, where => $location, manual => $manual;
        return ($location, "$package subroutine $subroutine option $option");
    }

    ($location, $opt);
}

=method decomposeL $manual, $link
Decompose the L-tags.  These tags are described in L<perlpod>, but
they will not refer to items: only headers.

=warning empty L link in $manual
=warning manual $manual links to unknown entry "$item" in $manual
=cut

sub decomposeL($$)
{   my ($self, $manual, $link) = @_;
    my $text  = $link =~ s/^([^|]*)\|// ? $1 : undef;

    length $link
        or (warning __x"empty L link in {manual}", manual => $manual), return ();

    return (undef, undef, $link, $text // $link)
        if $link  =~ m/^[a-z]+\:[^:]/;

    my ($name, $item) = $link =~ m[(.*?)(?:/(.*))?$];

    ($name, $item)    = (undef, $name) if $name =~ m/^".*"$/;
    $item     =~ s/^"(.*)"$/$1/        if defined $item;

    my $man   = length $name ? ($self->findManual($name) || $name) : $manual;

    my $dest;
    if(!ref $man)
    {   unless(defined $text && length $text)
        {   $text  = "manual $man";
            $text .= " entry $item" if defined $item && length $item;
        }

        if($man !~ m/\(\d.*\)\s*$/)
        {   (my $escaped = $man) =~ s/\W+/_/g;
            $dest = "$url_modsearch$escaped";
        }
    }
    elsif(!defined $item)
    {   $dest   = $man;
        $text //= $man->name;
    }
    elsif(my @obj = $man->all(findEntry => $item))
    {   $dest   = shift @obj;
        $text //= $item;
    }
    else
    {   warning __x"manual {manual} links to unknown entry '{item}' in {other_manual}",
            manual => $manual, entry => $item, other_manual => $man;
        $dest   = $man;
        $text //= "$man";
    }

    ($man, $dest, undef, $text);
}

sub cleanupPod($$$)
{   my ($self, $manual, $string, %args) = @_;
    defined $string && length $string or return '';

    my @lines   = split /^/, $string;
    my $protect;

    for(my $i=0; $i < @lines; $i++)
    {   $protect = $1  if $lines[$i] =~ m/^=(for|begin)\s+\w/;

        undef $protect if $lines[$i] =~ m/^=end/;
        undef $protect if $lines[$i] =~ m/^\s*$/ && $protect && $protect eq 'for';
        next if $protect;

        $lines[$i] =~ s/\bM\<([^>]*)\>/$self->cleanupPodM($manual, $1, \%args)/ge;

        $lines[$i] =~ s/\bL\<([^>]*)\>/$self->cleanupPodL($manual, $1, \%args)/ge
            if substr($lines[$i], 0, 1) eq ' ';

        # permit losing blank lines around pod statements.
        if(substr($lines[$i], 0, 1) eq '=')
        {   if($i > 0 && $lines[$i-1] ne "\n")
            {   splice @lines, $i-1, 0, "\n";
                $i++;
            }
            elsif($i < $#lines && $lines[$i+1] ne "\n" && substr($lines[$i], 0, 5) ne "=for ")
            {   splice @lines, $i+1, 0, "\n";
            }
        }
        else
        {   $lines[$i] =~ s/^\\\=/\=/;
        }

        # Remove superfluous blanks
        if($i < $#lines && $lines[$i] eq "\n" && $lines[$i+1] eq "\n")
        {   splice @lines, $i+1, 1;
        }
    }

    # remove leading and trailing blank lines
    shift @lines while @lines && $lines[0]  eq "\n";
    pop   @lines while @lines && $lines[-1] eq "\n";

    @lines ? join('', @lines) : '';
}

=method cleanupPodM $manual, $link, $args
=cut

sub cleanupPodM($$$)
{   my ($self, $manual, $link, $args) = @_;
    my ($toman, $to) = $self->decomposeM($manual, $link);
    ref $to ? $args->{create_link}->($toman, $to, $link, $args) : $to;
}

=method cleanupPodL $manual, $link, $args
The C<L> markups for C<OODoc::Parser::Markov> have the same syntax
as standard POD has, however most standard pod-laters do no accept
links in verbatim blocks.  Therefore, the links have to be
translated in their text in such a case.  The translation itself
is done in by this method.
=cut

sub cleanupPodL($$$)
{   my ($self, $manual, $link, $args) = @_;
    my ($toman, $to, $href, $text) = $self->decomposeL($manual, $link);
    $text;
}

sub cleanupHtml($$$)
{   my ($self, $manual, $string, %args) = @_;
    defined $string && length $string or return '';

	my $is_html = $args{is_html};

    if($string =~ m/(?:\A|\n)                   # start of line
                    \=begin\s+(:?\w+)\s*        # begin statement
                    (.*?)                       # encapsulated
                    \n\=end\s+\1\s*             # related end statement
                    /xs
     || $string =~ m/(?:\A|\n)                  # start of line
                     \=for\s+(:?\w+)\b          # for statement
                     (.*?)\n                    # encapsulated
                     (\n|\Z)                    # end of paragraph
                    /xs
      )
    {   my ($before, $type, $capture, $after) = ($`, lc($1), $2, $');
        if($type =~ m/^\:?html\b/ )
        {   $type    = 'html';
            $capture = $self->cleanupHtml($manual, $capture, is_html => 1);
        }

        return $self->cleanupHtml($manual, $before)
             . $capture
             . $self->cleanupHtml($manual, $after);
    }

    for($string)
    {   unless($is_html)
        {   s#\&#\&amp;#g;
            s#(\s|^)\<([^>]+)\>#$1&lt;$2&gt;#g;
            s#(?<!\b[LFCIBEMX])\<#&lt;#g;
            s#([=-])\>#$1\&gt;#g;
        }
        s/\bM\<([^>]*)\>/$self->cleanupHtmlM($manual, $1, \%args)/ge;
        s/\bL\<([^>]*)\>/$self->cleanupHtmlL($manual, $1, \%args)/ge;
        s#\bI\<([^>]*)\>#<em>$1</em>#g;
        s#\bB\<([^>]*)\>#<b>$1</b>#g;
        s#\bE\<([^>]*)\>#\&$1;#g;
        s#^\=over\s+\d+\s*#\n<ul>\n#gms;
        s#(?:\A|\n)\=item\s*(?:\*\s*)?([^\n]*)#\n<li>$1<br />#gms;
        s#(?:\A|\s*)\=back\b#\n</ul>#gms;
        s#\bC\<([^>]*)\>#<code>$1</code>#g;  # introduces a '<', hence last
        s#^=pod\b##gm;

        # when F<> contains a URL, it will be used. However, when it
        # contains a file, we cannot do anything with it yet.
        s#\bF\<(\w+\://[^>]*)\>#<a href="$1">$1</a>#g;
        s#\bF\<([^>]*)\>#<tt>$1</tt>#g;

        my ($label, $level, $title);
        s#^\=head([1-6])\s*([^\n]*)#
          ($title, $level) = ($1, $2);
          $label = $title;
          $label =~ s/\W+/_/g;
          qq[<h$level class="$title"><a name="$label">$title</a></h$level>];
         #ge;

        next if $is_html;

        s!(?:(?:^|\n)
              [^\ \t\n]+[^\n]*      # line starting with blank: para
          )+
         !<p>$&</p>!gsx;

        s!(?:(?:^|\n)               # start of line
              [\ \t]+[^\n]+         # line starting with blank: pre
          )+
         !<pre>$&\n</pre>!gsx;

        s#</pre>\n<pre>##gs;
        s#<p>\n#\n<p>#gs;
    }

    $string;
}

=method cleanupHtmlM $manual, $link, \%options
=cut

sub cleanupHtmlM($$$)
{   my ($self, $manual, $link, $args) = @_;
    my ($toman, $to) = $self->decomposeM($manual, $link);
    ref $to ? $args->{create_link}->($toman, $to, $link, $args) : $to;
}

=method cleanupHtmlL $manual, $link, \%options
=cut

sub cleanupHtmlL($$$)
{   my ($self, $manual, $link, $args) = @_;
    my ($toman, $to, $href, $text) = $self->decomposeL($manual, $link);

     defined $href ? qq[<a href="$href" target="_blank">$text</a>]
   : !defined $to  ? $text
   : ref $to       ? $args->{create_link}->($toman, $to, $text, $args)
   :                 qq[<a href="$to">$text</a>]
}

#-------------------------------------------
=chapter DETAILS

=section General Description

The Markov parser has some commonalities with the common POD syntax.
You can use the same tags as are defined by POD, however these tags are
"visual style", which means that OODoc can not treat it smart.  The Markov
parser adds many logical markups which will produce nicer pages.

Furthermore, the parser will remove the documentation from the
source code, because otherwise the package installation would fail:
Perl's default installation behavior will extract POD from packages,
but the markup is not really POD, which will cause many complaints.

The version of the module is defined by the OODoc object which creates
the manual page.  Therefore, C<$VERSION> will be added to each package
automatically.

=subsection Disadvantages

The Markov parser removes all raw documentation from the package files,
which means that people sending you patches will base them on the
processed source: the line numbers will be wrong.  Usually, it is not
much of a problem to manually process the patch: you have to check the
correctness anyway.

A second disadvantage is that you have to backup your sources separately:
the sources differ from what is published on CPAN, so CPAN is not your
backup anymore.  The example scripts, contained in the distribution, show
how to produce these "raw" packages.

Finally, a difference with the standard POD process: the manual-page must
be preceeded with a C<package> keyword.

=section Structural tags

=subsection Heading

 =chapter       STRING
 =section       STRING
 =subsection    STRING
 =subsubsection STRING

These text structures are used to group descriptive text and subroutines.
You can use any name for a chapter, but the formatter expects certain
names to be used: if you use a name which is not expected by the formatter,
that documentation will be ignored.

=subsection Subroutines

Perl has many kinds of subroutines, which are distinguished in the logical
markup.  The output may be different per kind.

 =i_method  NAME PARAMETERS   (instance method)
 =c_method  NAME PARAMETERS   (class method)
 =ci_method NAME PARAMETERS   (class and instance method)
 =method    NAME PARAMETERS   (short for i_method)
 =function  NAME PARAMETERS
 =tie       NAME PARAMETERS
 =overload  STRING

The NAME is the name of the subroutine, and the PARAMETERS an argument
indicator.

Then the subroutine description follows.  These tags have to follow the
general description of the subroutines.  You can use

 =option    NAME PARAMETERS
 =default   NAME VALUE
 =requires  NAME PARAMETERS

If you have defined an =option, you have to provide a =default for this
option anywhere.  Use of =default for an option on a higher level will
overrule the one in a subclass.

=subsection Subroutine parameters

The parser will turn this line

  =c_method new %options

into an M<OODoc::Text::Subroutine>, with C<name> set to C<new>, and
C<%options> as parameter string.  The formatters and exporters will
translate this subroutine call into

  $class->new(%options)

A more complex list of parameters, by convension, is a LIST of

=over 4
=item C<undef>: undef is accepted on this spot;
=item C<$scalar>: a single value;
=item C<%options>: a list of key-value pairs;
=item C<\@array>: a reference to an ARRAY of values;
=item C<\%hash>: a reference to a HASH;
=item C<LIST>: a comma-separated sequence of values;
=item C< [something] >: the parameter is optional; and
=item C< ($scalar|\@array|undef) >: alternative parameters on that position.
=back

For instance:

  =method scan $filename|$fh, $max_size, %options
  =c_method new [$count], %options|\%options

Shown as:

  $obj->scan($filename|$fh, $max_size, %options);
  $class->new([$count], %options|\%options);

=subsection Include examples

Examples can be added to chapters, sections, subsections, subsubsections,
and subroutines.  They run until the next markup line, so can only come
at the end of the documentation pieces.

 =example
 =examples

=subsection Include diagnostics

A subroutine description can also contain error or warning descriptions.
These diagnostics are usually collected into a special chapter of the
manual page.

 =error this is very wrong
 Of course this is not really wrong, but only as an example
 how it works.

 =warning wrong, but not sincerely
 Warning message, which means that the program can create correct output
 even though it found sometning wrong.

=subsection Compatibility

For comfort, all POD markups are supported as well

 =head1 Heading Text   (same as =chapter)
 =head2 Heading Text   (same as =section)
 =head3 Heading Text   (same as =subsection)
 =head4 Heading Text   (same as =subsubsection)
 =over indentlevel
 =item stuff
 =back
 =cut
 =pod
 =begin format
 =end format
 =for format text...

=section Text markup

Next to the structural markup, there is textual markup.  This markup
is the same as POD defines in the perlpod manual page. For instance,
E<lt>some codeE<gt> can be used to create visual markup as a code
fragment.

One kind is added to the standard list: the C<M>.

=subsection The M-link

The C<M>-link can not be nested inside other text markup items.  It is used
to refer to manuals, subroutines, and options.  You can use an C<L>-link
to manuals as well, however then the POD output filter will modify the
manual page while converting it to other manual formats.

Syntax of the C<M>-link:

 M < OODoc::Object >
 M < OODoc::Object::new() >
 M < OODoc::Object::new(verbose) >
 M < new() >
 M < new(verbose) >

These links refer to a manual page, a subroutine within a manual page, and
an option of a subroutine respectively.  And then two abbreviations are
shown: they refer to subroutines of the same manual page, in which case
you may refer to inherited documentation as well.

=subsection The L-link

The standard POD defines a C<L> markup tag.  This can also be used with
this Markov parser.

The following syntaxes are supported:

 L < manual >
 L < manual/section >
 L < manual/"section" >
 L < manual/subsection >
 L < manual/"subsection" >
 L < /section >
 L < /"section" >
 L < /subsection >
 L < /"subsection" >
 L < "section" >
 L < "subsection" >
 L < "subsubsection" >
 L < unix-manual >
 L < url >

In the above, I<manual> is the name of a manual, I<section> the name of
any section (in that manual, by default the current manual), and
I<subsection> a subsection (in that manual, by default the current manual).

The I<unix-manual> MUST be formatted with its chapter number, for instance
C<cat(1)>, otherwise a link will be created.  See the following examples
in the html version of these manual pages:

 M < perldoc >              illegal: not in distribution
 L < perldoc >              L<perldoc>
 L < perldoc(1perl) >       L<perldoc(1perl)>
 M < OODoc::Object >        M<OODoc::Object>
 L < OODoc::Object >        L<OODoc::Object>
 L < OODoc::Object(3pm) >   L<OODoc::Object(3pm)>

=section Grouping subroutines

Subroutine descriptions can be grouped in a chapter, section,
subsection, or subsubsection.  It is very common to have a large number
of subroutines, so some structure has to be imposed here.

If you document the same routine in more than one manual page with an
inheritance relationship, the documentation location shall not conflict.
You do not need to give the same level of detail about the exact
location of a subroutine, as long as it is not conflicting.  This
relative freedom is created to be able to regroup existing documentation
without too much effort.

For instance, in the code of OODoc itself (which is of course documented
with OODoc), the following happens:

 package OODoc::Object;
 ...
 =chapter METHODS
 =section Initiation
 =c_method new OPTIONS

 package OODoc;
 use parent 'OODoc::Object';
 =chapter METHODS
 =c_method new OPTIONS

As you can see in the example, in the higher level of inheritance, the
C<new> method is not put in the C<Initiation> section explicitly.  However,
it is located in the METHODS chapter, which is required to correspond to
the base class.  The generated documentation will show C<new> in the
C<Initiation> section in both manual pages.

=section Caveats

The markov parser does not require blank lines before or after tags, like
POD does.  This means that the change to get into parsing problems have
increased: lines within here documents which start with a C<=> will
cause confusion.  However, I these case, you can usually simply add a backslash
in front of the printed C<=>, which will disappear once printed.

=section Examples

You may also take a look at the raw code archive for OODoc (the text
as is before it was processed for distribution).

=example how subroutines are documented

 =chapter FUNCTIONS

 =function countCharacters FILE|STRING, OPTIONS
 Returns the number of bytes in the FILE or STRING,
 or undef if the string is undef or the character
 set unknown.

 =option  charset CHARSET
 =default charset 'us-ascii'
 Characters in, for instance, utf-8 or unicode encoding
 require variable number of bytes per character.  The
 correct CHARSET is needed for the correct result.

 =examples

   my $count = countCharacters("monkey");
   my $count = countCharacters("monkey",
       charset => 'utf-8');

 =error unknown character set $charset

 The character set you can use is limited by the sets
 defined by L<Encode>.  The characters of the input can
 not be seperated from each other without this definition.

 =cut

 # now the coding starts
 sub countCharacters($@) {
    my ($self, $input, %options) = @_;
    ...
 }

=cut

1;
