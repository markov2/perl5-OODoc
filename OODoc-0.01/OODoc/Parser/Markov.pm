
package OODoc::Parser::Markov;
use vars 'VERSION';
$VERSION = '0.01';
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


#-------------------------------------------


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


#-------------------------------------------


sub rule($$)
{   my ($self, $match, $action) = @_;
    push @{$self->{OP_rules}}, [$match, $action];
    $self;
}

#-------------------------------------------


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
             );
            push @manuals, $manual;
            $self->currentManual($manual);
            $out->print($line);
            $out->print("use vars 'VERSION';\n\$VERSION = '$version';\n");
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


sub setBlock($)
{   my ($self, $ref) = @_;
    $self->{OPM_block} = $ref;
    $self->inDoc(1);
    $self;
}

#-------------------------------------------


sub inDoc(;$)
{   my $self = shift;
    $self->{OPM_in_pod} = shift if @_;
    $self->{OPM_in_pod};
}

#-------------------------------------------


sub currentManual(;$)
{   my $self = shift;
    @_ ? $self->{OPM_manual} = shift : $self->{OPM_manual};
}
    
#-------------------------------------------


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


sub docChapter($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;
    $line =~ s/^\=chapter\s+//;
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


sub docSection($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;
    $line =~ s/^\=section\s+//;
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


sub docSubSection($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;
    $line =~ s/^\=subsection\s+//;
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


sub docOption($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;

    unless($line =~ m/^\=option\s+(\w+)\s*(.+?)\s*$/ )
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


sub docDefault($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;

    unless($line =~ m/^\=default\s+(\w+)\s*(.+?)\s*$/ )
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


sub debugRemains($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;

    warn "WARNING: Debugging remains in $fn line $ln\n"
       unless $self->inDoc || $self->currentManual->isPurePod;

    undef;
}

#-------------------------------------------


sub forgotCut($$$$)
{   my ($self, $match, $line, $fn, $ln) = @_;

    warn "WARNING: You may have accidentally captured code in doc $fn line $ln\n"
       if $self->inDoc && ! $self->currentManual->isPurePod;

    undef;
}

#-------------------------------------------


#-------------------------------------------


sub decomposeLink($$)
{   my ($self, $manual, $link) = @_;

    my ($subroutine, $option)
      = $link =~ s/(?:^|\:\:) (\w+) \( (.*?) \)$//x ? ($1, $2)
      :                                               ('', '');

    my $package;

       if(not length($link)) { $package = $manual }
    elsif($package = $self->mainManual($link)) {;}
    else
    {   eval "require $link";
        warn "WARNING: package $link is not on your system, but linked to in $manual\n"
           if $@;
        $package = $link;
    }

    unless(ref $package)
    {   return $package
              . (defined $subroutine ? " subroutine $subroutine" : '')
              . (length($option)     ? " option $option" : '');
    }

    return $package
        unless defined $subroutine && length $subroutine;

    my $sub = $package->subroutine($subroutine);
    for( my $extends = $package->extends
       ; !defined $sub && defined $extends
       ; $extends = $extends->extends)
    {   $sub = $extends->subroutine;
    }

    unless(defined $sub)
    {   warn "WARNING: subroutine $subroutine() is not defined by $package, but linked to in $manual\n";
        return "$package subroutine $subroutine";
    }

    return $sub
        unless defined $option && length $option;

    my $opt = $sub->option($option);
    unless(defined $opt)
    {   warn "WARNING: option \"$option\" is not defined for subroutine $subroutine in $package, but linked to in $manual\n";
        return "$package subroutine $subroutine option $option";
    }

    $opt;
}

#-------------------------------------------


#-------------------------------------------


sub cleanupPod($$$)
{   my ($self, $formatter, $manual, $string) = @_;
    $string =~ s/M\<([^>]*)\>/$self->cleanupPodLink($formatter, $manual, $1)/ge;
    $string;
}

#-------------------------------------------


sub cleanupPodLink($$$)
{   my ($self, $formatter, $manual, $link) = @_;
    my $to = $self->decomposeLink($manual, $link);
    ref $to ? $formatter->link($manual, $to, $link) : $to;
}

#-------------------------------------------


1;
