
package OODoc::Parser::Markov;
use base 'OODoc::Parser';

use strict;
use warnings;

use OODoc::Text::Chapter;
use OODoc::Text::Section;
use OODoc::Text::SubSection;
use OODoc::Text::Subroutine;
use OODoc::Text::Option;
use OODoc::Text::Default;
use OODoc::Text::Diagnostic;
use OODoc::Text::Example;
use OODoc::Manual;

use Carp;
use File::Spec;
use IO::File;

my $url_modsearch = "http://search.cpan.org/perldoc?";
my $url_coderoot  = 'CODE';

=chapter NAME

OODoc::Parser::Markov - Parser for the MARKOV syntax

=chapter SYNOPSIS

=chapter DESCRIPTION

The Markov parser is named after the author, because the author likes to
invite other people to write their own parser as well: every one has
not only their own coding style, but also their own documentation
wishes.

The task for the parser is to strip Perl package files into a code
part and a documentation tree.  The code is written to a directory
where the module distribution is built, the documenation tree is
later formatted into manual pages.

=cut

#-------------------------------------------

=chapter METHODS

=cut

#-------------------------------------------

my @default_rules =
 ( [ '=cut'        => 'docCut'        ]
 , [ '=chapter'    => 'docChapter'    ]
 , [ '=section'    => 'docSection'    ]
 , [ '=subsection' => 'docSubSection' ]
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

 # deprecated
 , [ '=head1'      => 'docChapter'    ]
 , [ '=head2'      => 'docSection'    ]
 , [ '=head3'      => 'docSubSection' ]

 # problem spotter
 , [ qr/^(warn|die|carp|confess|croak)/ => 'debugRemains' ]
 , [ qr/^(sub|my|our|package|use)\s/    => 'forgotCut' ]
 );

#-------------------------------------------

=c_method new OPTIONS

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

    $self->{OP_rules} = [];
    $self->rule(@$_) foreach @rules;
    $self;
}

#-------------------------------------------

=section Parsing a file

=cut

#-------------------------------------------

=method rule (STRING|REGEX), (METHOD|CODE)

Register a rule which will be applied to a line in the input file.  When
a STRING is specified, it must start at the beginning of the line to be
selected.  You may also specify a regular expression which will match
on the line.

The second argument is the action which will be taken when the line
is selected.  Either the named METHOD or the CODE reference will be called.
Their arguments are:

 $parser->METHOD($match, $line, $file, $linenumber);
 CODE->($parser, $match, $line, $file, $linenumber);

=cut

sub rule($$)
{   my ($self, $match, $action) = @_;
    push @{$self->{OP_rules}}, [$match, $action];
    $self;
}

#-------------------------------------------

=method findMatchingRule LINE

Check the list of rules whether this LINE matches one of them.  This
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

    foreach ( @{$self->{OP_rules}} )
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

#-------------------------------------------

=method parse OPTIONS

=requires input FILENAME

=option  output FILENAME
=default output devnull

=requires version STRING

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
       or croak "ERROR: no input file to parse specified";

    my $output  = $args{output} || File::Spec->devnull;
    my $version = $args{version} or confess;

    my $in     = IO::File->new($input, 'r')
       or die "ERROR: cannot read document from $input: $!\n";

    my $out    = IO::File->new($output, 'w')
       or die "ERROR: cannot write stripped code to $output: $!\n";

    # pure doc files have no package statement included, so it shall
    # be created beforehand.

    my $pure_pod = $input =~ m/\.pod$/;

    my ($manual, @manuals);

    if($pure_pod)
    {   $manual = OODoc::Manual->new
         ( package  => $self->filenameToPackage($input)
         , pure_pod => 1
         , source   => $input
         , parser   => $self
         , version  => $version
         );

        push @manuals, $manual;
        $self->currentManual($manual);
        $self->inDoc(1);
    }
    else
    {   $self->inDoc(0);
    }

    # Read through the file.

    while(my $line = $in->getline)
    {   my $ln = $in->input_line_number;

        if($line =~ m/^\s*package\s*([\w\-\:]+)\;/ && ! $self->inDoc)
        {   my $package = $1;
            $manual = OODoc::Manual->new
             ( package  => $package
             , source   => $input
             , stripped => $output
             , parser   => $self
             , version  => $version
             );
            push @manuals, $manual;
            $self->currentManual($manual);
            $out->print($line);
            $out->print("use vars '\$VERSION';\n\$VERSION = '$version';\n");
        }
        elsif(my($match, $action) = $self->findMatchingRule($line))
        {
            if(ref $action)
            {   $action->($self, $match, $line, $input, $ln)
                  or $out->print($line);
            }
            else
            {   no strict 'refs';
                $self->$action($match, $line, $input, $ln)
                  or $out->print($line);
            }
        }
        elsif($line =~ m/^=(over|back|item|for|pod|begin|end|head4)\b/ )
        {   ${$self->{OPM_block}} .= $line;
            $self->inDoc(1);
        }
        elsif(substr($line, 0, 1) eq '=')
        {   warn "WARNING: unknown markup in $input line $ln:\n $line";
            ${$self->{OPM_block}} .= $line;
            $self->inDoc(1);
        }
        elsif($pure_pod || $self->inDoc)
        {   # add the line to the currently open text block
            my $block = $self->{OPM_block};
            unless($block)
            {   warn "WARNING: no block for line $ln in file $input\n $line";
                my $dummy = '';
                $block = $self->setBlock(\$dummy);
            }
            $$block  .= $line;
        }
        else
        {   $out->print($line);
        }
    }

    warn "WARNING: doc did not end in $input.\n"
        if $self->inDoc && ! $pure_pod;

    $self->closeChapter;
    $in->close && $out->close;

    @manuals;
}

#-------------------------------------------

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

#-------------------------------------------

=method inDoc [BOOLEAN]

When a BOOLEAN is specified, the status changes.  It returns the current
status of the document reader.

=cut

sub inDoc(;$)
{   my $self = shift;
    $self->{OPM_in_pod} = shift if @_;
    $self->{OPM_in_pod};
}

#-------------------------------------------

=method currentManual [MANUAL]

Returns the manual object which is currently being filled with data.
With a new MANUAL, a new one is set.

=cut

sub currentManual(;$)
{   my $self = shift;
    @_ ? $self->{OPM_manual} = shift : $self->{OPM_manual};
}
    
#-------------------------------------------

=warning =cut does not terminate any doc in $file line $number

There is no document to end here.

=cut

sub docCut($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;

    if($self->currentManual->isPurePod)
    {   warn "The whole file $fn is pod, so =cut in line $ln is useless.\n";
        return;
    }

    warn "WARNING: $match does not terminate any doc in $fn line $ln.\n"
        unless $self->inDoc;

    $self->inDoc(0);
    1;
}

#-------------------------------------------
# CHAPTER

=error chapter $name before package statement in $file line $number

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

    my $manual = $self->currentManual;
    die "ERROR: chapter $line before package statement in $fn line $ln\n"
       unless defined $manual;

    my $chapter = $self->{OPM_chapter} = OODoc::Text::Chapter->new
     ( name    => $line
     , manual  => $manual
     , linenr  => $ln
     );

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

=error section $name outside chapter in $file line $number

Sections must be contained in chapters.

=cut

sub docSection($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;
    $line =~ s/^\=(section|head2)\s+//;
    $line =~ s/\s+$//;

    $self->closeSection;

    my $chapter = $self->{OPM_chapter};
    die "ERROR: section $line outside chapter in $fn line $ln\n"
       unless defined $chapter;

    my $section = $self->{OPM_section} = OODoc::Text::Section->new
     ( name     => $line
     , chapter  => $chapter
     , linenr   => $ln
     );

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

=error subsection $name outside section in $file line $number

Subsections are only allowed in a chapter when it is nested within
a section.

=cut

sub docSubSection($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;
    $line =~ s/^\=(subsection|head3)\s+//;
    $line =~ s/\s+$//;

    $self->closeSubSection;

    my $section = $self->{OPM_section};
    die "ERROR: subsection $line outside section in $fn line $ln\n"
       unless defined $section;

    my $subsection = $self->{OPM_subsection} = OODoc::Text::SubSection->new
     ( name     => $line
     , section  => $section
     , linenr   => $ln
     );

    $section->subsection($subsection);
    $self->setBlock($subsection->openDescription);
    $subsection;
}

sub closeSubSection()
{   my $self       = shift;
    my $subsection = delete $self->{OPM_subsection};
    $self;
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

    my $container = $self->{OPM_subsection}
                 || $self->{OPM_section}
	         || $self->{OPM_chapter};

    die "ERROR: subroutine $name outside chapter in $fn line $ln\n"
       unless defined $container;

    $type    = 'i_method' if $type eq 'method';
    my $sub  = $self->{OPM_subroutine} = OODoc::Text::Subroutine->new
     ( type       => $type
     , name       => $name
     , parameters => $params
     , linenr     => $ln
     , container  => $container
     );

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

    unless($line =~ m/^\=option\s+(\S+)\s*(.+?)\s*$/ )
    {   warn "WARNING: option line incorrect in $fn line $ln:\n$line";
        return;
    }
    my ($name, $parameters) = ($1, $2);

    my $sub  = $self->{OPM_subroutine};
    die "ERROR: option $name outside subroutine in $fn line $ln\n"
       unless defined $sub;

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

    unless($line =~ m/^\=default\s+(\S+)\s*(.+?)\s*$/ )
    {   warn "WARNING: default line incorrect in $fn line $ln:\n$line";
        return;
    }

    my ($name, $value) = ($1, $2);

    my $sub  = $self->{OPM_subroutine};
    die "ERROR: default for option $name outside subroutine in $fn line $ln\n"
       unless defined $sub;

    my $default  = OODoc::Text::Default->new
     ( name       => $name
     , value      => $value
     , linenr     => $ln
     , subroutine => $sub
     );

    $sub->default($default);
    $sub;
}

#-------------------------------------------

sub docRequires($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;

    unless($line =~ m/^\=requires\s+(\w+)\s*(.+?)\s*$/ )
    {   warn "WARNING: requires line incorrect in $fn line $ln:\n$line";
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
    {   warn "WARNING: no diagnostic message supplied in $fn line $ln";
        return;
    }

    my $sub  = $self->{OPM_subroutine};
    die "ERROR: diagnostic $type outside subroutine in $fn line $ln\n"
       unless defined $sub;

    my $diag  = OODoc::Text::Diagnostic->new
     ( type       => ucfirst($type)
     , name       => $line
     , linenr     => $ln
     , subroutine => $sub
     );

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
                 || $self->{OPM_subsection}
                 || $self->{OPM_section}
                 || $self->{OPM_chapter};
 
    die "ERROR: example outside chapter in $fn line $ln\n"
       unless defined $container;

    my $example  = OODoc::Text::Example->new
     ( name      => ($line || '')
     , linenr    => $ln
     , container => $container
     );

    $self->setBlock($example->openDescription);
    $container->example($example);
    $example;
}

#-------------------------------------------

=warning Debugging remains in $filename line $number

The author's way of debugging is by putting warn/die/carp etc on the
first position of a line.  Other lines in a method are always indented,
which means that these debugging lines are clearly visible.  You may
simply ingnore this warning.

=cut

sub debugRemains($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;

    warn "WARNING: Debugging remains in $fn line $ln\n"
       unless $self->inDoc || $self->currentManual->isPurePod;

    undef;
}

#-------------------------------------------

=warning You may have accidentally captured code in doc file $fn line $number

Some keywords on the first position of a line are very common for code.
However, code within doc should start with a blank to indicate pre-formatted
lines.  This warning may be false.

=cut

sub forgotCut($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;

    warn "WARNING: You may have accidentally captured code in doc $fn line $ln\n"
       if $self->inDoc && ! $self->currentManual->isPurePod;

    undef;
}

#-------------------------------------------

=section Producing manuals

=cut

#-------------------------------------------

=method decomposeM MANUAL, LINK

=warning package $link is not on your system, but linked to in $manual

=warning subroutine $name is not defined by $package, but linked to in $manual

=warning option "$name" is not defined for subroutine $name in $package, but is linked to in $manual

=cut

sub decomposeM($$)
{   my ($self, $manual, $link) = @_;

    my ($subroutine, $option)
      = $link =~ s/(?:^|\:\:) (\w+) \( (.*?) \)$//x ? ($1, $2)
      :                                               ('', '');

    my $man;
       if(not length($link)) { $man = $manual }
    elsif($man = $self->manual($link)) { ; }
    else
    {   eval "require $link";
        warn "WARNING: package $link is not on your system, but linked to in $manual\n"
           if $@;
        $man = $link;
    }

    unless(ref $man)
    {   return ( $manual
               , $man
                 . (length($subroutine) ? " subroutine $subroutine" : '')
                 . (length($option)     ? " option $option" : '')
               );
    }

    return (undef, $man)
        unless defined $subroutine && length $subroutine;

    my $package = $self->manual($man->package);
    my $sub     = $package->subroutine($subroutine);
    unless(defined $sub)
    {   warn "WARNING: subroutine $subroutine() is not defined by $package, but linked to in $manual\n";
        return ($package, "$package subroutine $subroutine");
    }

    my $location = $sub->manual;
    return ($location, $sub)
        unless defined $option && length $option;

    my $opt = $sub->findOption($option);
    unless(defined $opt)
    {   warn "WARNING: option \"$option\" is not defined for subroutine $subroutine in $location, but linked to in $manual\n";
        return ($location, "$package subroutine $subroutine option $option");
    }

    ($location, $opt);
}

#-------------------------------------------

=method decomposeL MANUAL, LINK

Decompose the L-tags.  These tags are described in L<perlpod>, but
they will not refer to items: only headers.

=warning empty L link in $manual

=warning Manual $manual links to unknown entry "$item" in $manual

=cut

sub decomposeL($$)
{   my ($self, $manual, $link) = @_;
    my $text = $link =~ s/^([^|]*)\|// ? $1 : undef;

    unless(length $link)
    {   warn "WARNING: empty L link in $manual";
        return ();
    }

    if($link  =~ m/^[a-z]+\:[^:]/ )
    {   $text         = $link unless defined $text;
        return (undef, undef, $link, $text);
    }

    my ($name, $item) = $link =~ m[(.*?)(?:/(.*))?$];

    ($name, $item)    = (undef, $name) if $name =~ m/^".*"$/;
    $item     =~ s/^"(.*)"$/$1/        if defined $item;

    my $man   = length $name ? ($self->manual($name) || $name) : $manual;

    my $dest;
    if(!ref $man)
    {   unless(defined $text && length $text)
        {  $text = "manual $man";
           $text .= " entry $item" if defined $item && length $item;
        }

        $dest = "$url_modsearch$man"
           unless $man =~ m/\(\d.*\)\s*$/;
    }
    elsif(!defined $item)
    {   $dest  = $man;
        $text  = $man->name unless defined $text;
    }
    elsif(my @obj = $man->all(findEntry => $item))
    {   $dest  = shift @obj;
        $text  = $item unless defined $text;
    }
    else
    {   warn "WARNING: Manual $manual links to unknown entry \"$item\" in $man\n";
        $dest = $man;
        $text = "$man" unless defined $text;
    }

    ($man, $dest, undef, $text);
}

#-------------------------------------------

=method cleanupPod FORMATTER, MANUAL, STRING

=cut

sub cleanupPod($$$)
{   my ($self, $formatter, $manual, $string) = @_;
    return '' unless defined $string && length $string;

    my @lines   = split /^/, $string;
    my $protect;

    for(my $i=0; $i < @lines; $i++)
    {   $protect = $1  if $lines[$i] =~ m/^=(for|begin)\s+\w/;

        undef $protect if $lines[$i] =~ m/^=end/;

        undef $protect if $lines[$i] =~ m/^\s*$/
                       && $protect && $protect eq 'for';

        next if $protect;

        $lines[$i] =~
             s/\bM\<([^>]*)\>/$self->cleanupPodLink($formatter,$manual,$1)/ge;

        # permit losing blank lines around pod statements.
        if(substr($lines[$i], 0, 1) eq '=')
        {   if($i > 0 && $lines[$i-1] ne "\n")
            {   splice @lines, $i-1, 0, "\n";
                $i++;
            }
            elsif($i < $#lines && $lines[$i+1] ne "\n"
                  && substr($lines[$i], 0, 5) ne "=for ")
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

#-------------------------------------------

=method cleanupPodLink FORMATTER, MANUAL, LINK

=cut

sub cleanupPodLink($$$)
{   my ($self, $formatter, $manual, $link) = @_;
    my ($toman, $to) = $self->decomposeM($manual, $link);
    ref $to ? $formatter->link($toman, $to, $link) : $to;
}

#-------------------------------------------

=method cleanupHtml FORMATTER, MANUAL, STRING

=cut

sub cleanupHtml($$$)
{   my ($self, $formatter, $manual, $string) = @_;
    return '' unless defined $string && length $string;

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
        if($type =~ s/^\:(text|html)\b// )
        {   $type    = $1;
            $capture = $self->cleanupHtml($formatter, $manual, $capture);
        }

        my $take = $type eq 'text' ? "<pre>\n". $capture . "</pre>\n"
                 : $type eq 'html' ? $capture
                 :                   '';   # ignore

        return $self->cleanupHtml($formatter, $manual, $before)
             . $take
             . $self->cleanupHtml($formatter, $manual, $after);
    }

    for($string)
    {   s#\&#\&amp;#g;
        s#(?<!\b[LFCIBEM])\<#&lt;#g;
        s/\bM\<([^>]*)\>/$self->cleanupHtmlM($formatter, $manual, $1)/ge;
        s/\bL\<([^>]*)\>/$self->cleanupHtmlL($formatter, $manual, $1)/ge;
        s#\bF\<([^>]*)\>#<a href="$url_coderoot"/$1>$1</a>#g;
        s#\bC\<([^>]*)\>#<code>$1</code>#g;
        s#\bI\<([^>]*)\>#<em>$1</em>#g;
        s#\bB\<([^>]*)\>#<b>$1</b>#g;
        s#\bE\<([^>]*)\>#\&$1;#g;
        s#\-\>#-\&gt;#g;
        s#^\=over\s+\d+\s*#\n<ul>\n#gms;
        s#(?:\A|\n)\=item\s*(?:\*\s*)?([^\n]*)#\n<li><b>$1</b><br />#gms;
        s#(?:\A|\s*)\=back\b#\n</ul>#gms;
        s#^=pod\b##gm;
 
        my ($label, $level, $title);
        s#^\=head([1-6])\s*([^\n]*)#
          ($title, $level) = ($1, $2);
          $label = $title;
          $label =~ s/\W+/_/g;
          qq[<h$level class="$title"><a name="$label">$title</a></h$level>];
         #ge;

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

#-------------------------------------------

=method cleanupHtmlM FORMATTER, MANUAL, LINK

=cut

sub cleanupHtmlM($$$)
{   my ($self, $formatter, $manual, $link) = @_;
    my ($toman, $to) = $self->decomposeM($manual, $link);
    ref $to ? $formatter->link($toman, $to, $link) : $to;
}

#-------------------------------------------

=method cleanupHtmlL FORMATTER, MANUAL, LINK

=cut

sub cleanupHtmlL($$$)
{   my ($self, $formatter, $manual, $link) = @_;
    my ($toman, $to, $href, $text) = $self->decomposeL($manual, $link);

     defined $href ? qq[<a href="$href">$text</a>]
   : !defined $to  ? $text
   : ref $to       ? $formatter->link($toman, $to, $text)
   :                 qq[<a href="$to">$text</a>]
}

#-------------------------------------------

=section Commonly used functions

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
backup anymore.

=section Structural tags

=subsection Heading

 =chapter    STRING
 =section    STRING
 =subsection STRING

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

=subsection Include examples

Examples can be added to chapters, sections, subsections and subroutines.
They run until the next markup line, so can only come at the end of the
documentation pieces.

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

 =head1 Heading Text          (same as =chapter)
 =head2 Heading Text          (same as =section)
 =head3 Heading Text          (same as =subsection)
 =head4 Heading Text
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
CE<lt>some codeE<gt> can be used to create visual markup as a code
fragment.

One kind is added to the standard list: the C<M>.

=subsection The M-link

The C<M>-link can not be nested inside other text markup items.  It is used
to refer to manuals, subroutines, and options.  You can use an C<L>-link
to manuals as well, however then the POD output filter will modify the
manual page while converting it to other manual formats.

Syntax of the C<M>-link:
 M E<lt> OODoc::Object E<gt>
 M E<lt> OODoc::Object::new() E<gt>
 M E<lt> OODoc::Object::new(verbose) E<gt>
 M E<lt> new() E<gt>
 M E<lt> new(verbose) E<gt>

These links refer to a manual page, a subroutine within a manual page, and
an option of a subroutine respectively.  And then two abbreviations are
shown: they refer to subroutines of the same manual page, in which case
you may refer to inherited documentation as well.

=subsection The L-link

The standard POD defines a C<L> markup tag.  This can also be used with
this Markov parser.

The following syntaxes are supported:
 L E<lt> manual E<gt>
 L E<lt> manual/section E<gt>
 L E<lt> manual/"section" E<gt>
 L E<lt> manual/subsection E<gt>
 L E<lt> manual/"subsection" E<gt>
 L E<lt> /section E<gt>
 L E<lt> /"section" E<gt>
 L E<lt> /subsection E<gt>
 L E<lt> /"subsection" E<gt>
 L E<lt> "section" E<gt>
 L E<lt> "subsection" E<gt>
 L E<lt> unix-manual E<gt>
 L E<lt> url E<gt>
 
In the above, I<manual> is the name of a manual, I<section> the name of
any section (in that manual, by default the current manual), and
I<subsection> a subsection (in that manual, by default the current manual).

The I<unix-manual> MUST be formatted with its chapter number, for instance
C<cat(1)>, otherwise a link will be created.  See the following examples
in the html version of these manual pages:

 M E<lt> perldoc E<gt>              illegal: not in distribution
 L E<lt> perldoc E<gt>              L<perldoc>
 L E<lt> perldoc(1perl) E<gt>       L<perldoc(1perl)>

 M E<lt> OODoc::Object E<gt>        M<OODoc::Object>
 L E<lt> OODoc::Object E<gt>        L<OODoc::Object>
 L E<lt> OODoc::Object(3pm) E<gt>   L<OODoc::Object(3pm)>

=section Grouping subroutines

Subroutine descriptions can be grouped in a chapter, section, or subsection.
It is very common to have a large number of subroutines, so some structure
has to be imposed here.

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
 use base 'OODoc::Object';
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
