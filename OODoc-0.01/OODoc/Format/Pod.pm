
package OODoc::Format::Pod;
use vars 'VERSION';
$VERSION = '0.01';
use base 'OODoc::Format';

use strict;
use warnings;

use Carp;
use File::Spec;
use List::Util 'max';


#-------------------------------------------


#-------------------------------------------


sub link($$;$)
{   my ($self, $manual, $object, $text) = @_;
    $object = $object->subroutine if $object->isa('OODoc::Text::Option');
    $object = $object->subroutine if $object->isa('OODoc::Text::Default');
    $object = $object->container  if $object->isa('OODoc::Text::Example');
    $object = $object->container  if $object->isa('OODoc::Text::Subroutine');
    $text   = defined $text ? "$text|" : '';

    return "L<$text$object>" if $object->isa('OODoc::Manual');

    my $manlink = $manual eq $object->manual ? '' : $object->manual.'/';

      $object->isa('OODoc::Text::Structure') ? qq(L<$text$manlink"$object">)
    : confess "cannot link to a ".ref $object;
}

#-------------------------------------------


sub createManual($@)
{   my ($self, %args) = @_;
    my $verbose  = $args{verbose} || 0;
    my $manual   = $args{manual} or confess;
    my $manifest = $args{manifest} || OODoc::Manifest->new;

    my $workdir  = $args{workdir}
       or die "ERROR: no directory to put pod for $manual in";

    my $options  = $args{format_options} || [];

    print $manual->orderedChapters." chapters in $manual\n" if $verbose==3;
    (my $podname = $manual->source) =~ s/\.pm$/.pod/;
    $manifest->add($podname);

    my $podfile  = File::Spec->catfile($workdir, $podname);
    my $output  = IO::File->new($podfile, "w")
    or die "ERROR: cannot write pod manual at $podfile: $!";

    $self->showChapters
      ( manual => $manual
      , output => $output
      , append => $args{append}
      , @$options
      );

    $self;
}

#-------------------------------------------


sub showChapters($@)
{   my $self = shift;
    $self->chapterName(@_);
    $self->chapterInheritance(@_);
    $self->chapterSynopsis(@_);
    $self->chapterDescription(@_);
    $self->chapterOverloading(@_);
    $self->chapterMethods(@_);
    $self->chapterExports(@_);
    $self->chapterDiagnostics(@_);
    $self->chapterDetails(@_);
    $self->chapterReferences(@_);
    $self->chapterCopyrights(@_);

    my %args   = @_;
    my $append = $args{append};

       if(!defined $append)      { ; }
    elsif(ref $append eq 'CODE') { $append->(formatter => $self, %args) }
    else
    {   my $output = $args{output} or confess;
        $output->print($append);
    }

    $self;
}

#-------------------------------------------

sub showChapter(@)
{   my ($self, %args) = @_;
    my $chapter = $args{chapter} or confess;
    my $name    = $chapter->name;
    my $output  = $args{output}  or confess;
    my $manual  = $args{manual}  or confess;

    my $show_examples
      = defined $args{show_chapter_examples} ? $args{show_chapter_examples} : 1;
    my $descr   = $self->cleanup($manual, $chapter->description);

    $output->print("\n=head1 $name\n\n");
    $output->print($descr);

    $self->showSubroutines(subroutines => [$chapter->subroutines], %args);

    foreach my $section ($chapter->sections)
    {   $output->print("\n=head2 ", $section->name, "\n\n");
        $output->print($self->cleanup($manual, $section->description));

        $self->showSubroutines(subroutines => [$section->subroutines], %args);
        $self->showExamples(examples => [$section->examples], %args)
           if $show_examples;

        foreach my $subsection ($section->subsections)
        {   $output->print("\n=head3 ",  $subsection->name, "\n\n");
            $output->print($self->cleanup($manual,$subsection->description));
            $self->showSubroutines(subroutines => [$subsection->subroutines]
                                  , %args);
            $self->showExamples(examples => [$subsection->examples], %args)
               if $show_examples;
        }
    }

    $self->showExamples(examples => [$chapter->examples], %args)
        if $show_examples;
}

#-------------------------------------------

sub chapterDescription(@)
{   my ($self, %args) = @_;

    $self->showRequiredChapter(DESCRIPTION => %args);

    my $manual  = $args{manual} or confess;
    my $details = $manual->chapter('DETAILS');
   
    return $self unless defined $details;

    my $output  = $args{output} or confess;
    $output->print("\nSee L</DETAILS> chapter below\n");
    $self->showChapterIndex($output, $details, "   ");
}

#-------------------------------------------

sub chapterDiagnostics(@)
{   my ($self, %args) = @_;

    my $manual  = $args{manual} or confess;
    my $diags   = $manual->chapter('DIAGNOSTICS');

    $self->showChapter(chapter => $diags, %args)
        if defined $diags;

    my @diags   = map {$_->diagnostics} $manual->subroutines;
    return unless @diags;

    unless($diags)
    {   my $output = $args{output} or confess;
        $output->print("\n=head1 DIAGNOSTICS\n");
    }

    $self->showDiagnostics(%args, diagnostics => \@diags);
    $self;
}

#-------------------------------------------


sub showChapterIndex($$;$)
{   my ($self, $output, $chapter, $indent) = @_;
    $indent = '' unless defined $indent;

    foreach my $section ($chapter->sections)
    {   $output->print($indent, $section->name, "\n");
        foreach my $subsection ($section->subsections)
        {   $output->print($indent, $indent, $subsection->name, "\n");
        }
    }
    $self;
}

#-------------------------------------------

sub showExamples(@)
{   my ($self, %args) = @_;
    my $examples = $args{examples} or confess;
    return unless @$examples;

    my $manual    = $args{manual}  or confess;
    my $output    = $args{output}  or confess;

    foreach my $example (@$examples)
    {   my $name    = $self->cleanup($manual, $example->name);
        $output->print("\nI<Example:> $name\n\n");
        $output->print($self->cleanup($manual, $example->description));
    }
    $self;
}

#-------------------------------------------

sub showDiagnostics(@)
{   my ($self, %args) = @_;
    my $diagnostics = $args{diagnostics} or confess;
    return unless @$diagnostics;

    my $manual    = $args{manual}  or confess;
    my $output    = $args{output}  or confess;

    foreach my $diag (sort @$diagnostics)
    {   my $name    = $self->cleanup($manual, $diag->name);
        my $type    = $diag->type;
        $output->print("\nI<$type:> $name\n\n");
        $output->print($self->cleanup($manual, $diag->description));
    }
    $self;
}

#-------------------------------------------


sub chapterInheritance(@)
{   my ($self, %args) = @_;

    my $package = $args{manual} or confess;
    my $output  = $args{output} or confess;

    $output->print("\n=head1 INHERITANCE\n");

    my @supers = $package->superClasses;

    if(my $realized = $package->realizes)
    {   $output->print("\n $package realizes a $realized\n");
        @supers = $realized->superClasses if ref $realized;
    }

    if(my @extras = $package->extraCode)
    {   $output->print("\n $package has extra code in\n");
        $output->print("   $_\n") foreach @extras;
    }

    foreach (@supers)
    {   $output->print("\n $package\n");
        $self->showSuperSupers($output, $_);
    }

    if(my @subclasses = $package->subClasses)
    {   $output->print("\n $package is extended by\n");
        $output->print("   $_\n") foreach sort @subclasses;
    }

    if(my @realized = $package->realizers)
    {   $output->print("\n $package is realized by\n");
        $output->print("   $_\n") foreach sort @realized;
    }
}

sub showSuperSupers($$)
{   my ($self, $output, $package) = @_;
    $output->print("   is a $package\n");
    return unless ref $package;  # only the name of the package is known

    if(my $realizes = $package->realizes)
    {   $self->showSuperSupers($output, $realizes);
        return $self;
    }

    my @supers = $package->superClasses or return;
    $self->showSuperSupers($output, shift @supers);

    foreach(@supers)
    {   $output->print("\n\n   $package also extends $_\n");
        $self->showSuperSupers($output, $_);
    }

    $self;
}

#-------------------------------------------

sub showSubroutine(@)
{   my $self = shift;
    $self->SUPER::showSubroutine(@_);

    my %args   = @_;
    my $output = $args{output} or confess;
    $output->print("\n=back\n");
    $self;
}

#-------------------------------------------

sub showSubroutineUse(@)
{   my ($self, %args) = @_;
    my $subroutine = $args{subroutine} or confess;
    my $manual     = $args{manual}     or confess;
    my $output     = $args{output}     or confess;

    my $type       = $subroutine->type;
    my $name       = $self->cleanup($manual, $subroutine->name);
    my $paramlist  = $self->cleanup($manual, $subroutine->parameters);
    my $params     = length $paramlist ? "($paramlist)" : '';

    my $class      = $manual->package;

    if($type eq 'i_method')
    {   $output->print("\n\$obj-E<gt>B<$name>$params\n") }
    elsif($type eq 'c_method')
    {   $output->print("\n$class-E<gt>B<$name>$params\n") }
    elsif($type eq 'ci_method')
    {   $output->print("\n\$obj-E<gt>B<$name>$params\n");
        $output->print("\n$class-E<gt>B<$name>$params\n");
    }
    elsif($type eq 'overload')
    {   $output->print("\noverload: B<$name>$params\n") }
    elsif($type eq 'tie')
    {   $output->print("\nB<$name> $paramlist\n") }
    else
    {   warn "WARNING: unknown subroutine type $type for $name in $manual";
    }

    $output->print("\n=over 4\n");

    if($manual->inherited($subroutine))
    {   $output->print("\nSee ". $self->link($manual, $subroutine)."\n");
    }

    $self;
}

#-------------------------------------------

sub showSubroutineName(@)
{   my ($self, %args) = @_;
    my $subroutine = $args{subroutine} or confess;
    my $manual     = $args{manual}     or confess;
    my $output     = $args{output}     or confess;
    my $name       = $subroutine->name;

    my $url
     = $manual->inherited($subroutine)
     ? "M<".$subroutine->manual."::$name>"
     : "M<$name>";

    $output->print
     ( $self->cleanup($manual, $url)
     , ($args{last} ? ".\n" : ",\n")
     );
}

#-------------------------------------------

sub showOptionTable(@)
{   my ($self, %args) = @_;
    my $options = $args{options} or confess;
    my $manual  = $args{manual}  or confess;
    my $output  = $args{output}  or confess;

    my @rows;
    foreach (@$options)
    {   my ($option, $default) = @$_;
        push @rows, [ $self->cleanup($manual, $option->name)
                    , ($manual->inherited($option) ? $option->manual : '')
                    , $self->cleanup($manual, $default->value)
                    ];
    }

    $output->print("\n");
    $self->writeTable
     ( output => $output
     , header => ['Option', 'Defined in', 'Default']
     , rows   => \@rows
     , widths => [undef, 15, undef]
     );
}

#-------------------------------------------

sub showOptionUse(@)
{   my ($self, %args) = @_;
    my $output = $args{output} or confess;
    my $option = $args{option} or confess;

    my $params = $option->parameters;
    $params    =~ s/\s+$//;
    $params    =~ s/^\s+//;
    $params    = " $params" if length $params;
 
    $output->print("\n. $option$params\n");
    $self;
}

#-------------------------------------------

sub showOptionExpand(@)
{   my ($self, %args) = @_;
    my $output = $args{output} or confess;
    my $option = $args{option} or confess;
    my $manual = $args{manual}  or confess;

    $self->showOptionUse(%args);

    my $where = $option->findDescriptionObject or return $self;
    $output->print
     ( "\n=over 4\n\n"
     , $self->cleanup($manual, $where->description)
     , "\n=back\n"
     );
    $self;
}

#-------------------------------------------


sub writeTable($@)
{   my ($self, %args) = @_;

    my $head   = $args{header} or confess;
    my @w      = (0) x @$head;

    my $rows   = $args{rows}   or confess;
    return unless @$rows;

    foreach my $row ($head, @$rows)
    {   $w[$_] = max $w[$_], length($row->[$_])
           foreach 0..$#$row;
    }

    if(my $widths = $args{widths})
    {   defined $widths->[$_] && ($w[$_] = $widths->[$_])
           foreach 0..$#$rows;
    }

    my $format = " ".join("  ", map { "\%-${_}s" } @w)."\n";

    my $output = $args{output}   or confess;
    $output->printf($format, @$_)
       foreach $head, @$rows;
}

#-------------------------------------------

sub showSubroutineDescription(@)
{   my ($self, %args) = @_;
    my $manual  = $args{manual}                   or confess;
    my $subroutine = $args{subroutine}            or confess;

    my $text    = $self->cleanup($manual, $subroutine->description);
    return $self unless length $text;

    my $output  = $args{output}                   or confess;
    $output->print("\n", $text);

    my $extends = $self->extends                  or return $self;
    my $refer   = $extends->findDescriptionObject or return $self;
    $self->showSubroutineDescriptionRefer(%args, subroutine => $refer);
}

#-------------------------------------------

sub showSubroutineDescriptionRefer(@)
{   my ($self, %args) = @_;
    my $manual  = $args{manual}                   or confess;
    my $subroutine = $args{subroutine}            or confess;
    my $output  = $args{output}                   or confess;
    $output->print("\nSee ", $self->link($manual, $subroutine), "\n");
}

#-------------------------------------------

sub showSubsIndex() {;}

#-------------------------------------------


1;
