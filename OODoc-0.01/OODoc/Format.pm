
package OODoc::Format;
use vars 'VERSION';
$VERSION = '0.01';
use base 'OODoc::Object';

use strict;
use warnings;

use Carp;


#-------------------------------------------


#-------------------------------------------


sub createManual(@) { confess }

#-------------------------------------------


sub cleanup($$)
{   my ($self, $manual, $string) = @_;
    $manual->parser->cleanup($self, $manual, $string);
}

#-------------------------------------------


sub showChapter(@) {confess}

sub chapterName(@)        {shift->showRequiredChapter(NAME        => @_)}
sub chapterSynopsis(@)    {shift->showOptionalChapter(SYNOPSIS    => @_)}
sub chapterDescription(@) {shift->showRequiredChapter(DESCRIPTION => @_)}
sub chapterOverloading(@) {shift->showOptionalChapter(OVERLOADING => @_)}
sub chapterMethods(@)     {shift->showOptionalChapter(METHODS     => @_)}
sub chapterExports(@)     {shift->showOptionalChapter(EXPORTS     => @_)}
sub chapterDiagnostics(@) {shift->showOptionalChapter(DIAGNOSTICS => @_)}
sub chapterDetails(@)     {shift->showOptionalChapter(DETAILS     => @_)}
sub chapterReferences(@)  {shift->showOptionalChapter(REFERENCES  => @_)}
sub chapterCopyrights(@)  {shift->showOptionalChapter(COPYRIGHTS  => @_)}

#-------------------------------------------


sub showRequiredChapter($@)
{   my ($self, $name, %args) = @_;
    my $manual  = $args{manual} or confess;
    my $chapter = $manual->chapter($name);

    unless(defined $chapter)
    {   warn "WARNING: missing required chapter $name in $manual\n";
        return;
    }

    $self->showChapter(chapter => $chapter, %args);
}

#-------------------------------------------


sub showOptionalChapter($@)
{   my ($self, $name, %args) = @_;
    my $manual  = $args{manual} or confess;

    my $chapter = $manual->chapter($name);
    return unless defined $chapter;

    $self->showChapter(chapter => $chapter, %args);
}

#-------------------------------------------


sub createIndexPages(@) {shift}

#-------------------------------------------


sub showSubroutines(@)
{   my ($self, %args) = @_;

    my @subs   = $args{subroutines} ? sort @{$args{subroutines}} : [];
    return unless @subs;

    my $manual = $args{manual} or confess;
    my $output = $args{output}    || select;

    $args{show_subs_index}        ||= 'NO';
    $args{show_inherited_subs}    ||= 'USE';
    $args{show_described_subs}    ||= 'EXPAND';
    $args{show_option_table}      ||= 'ALL';
    $args{show_inherited_options} ||= 'USE';
    $args{show_described_options} ||= 'EXPAND';

    $self->showSubsIndex(%args, subroutines => \@subs);

    for(my $index=0; $index<@subs; $index++)
    {   my $subroutine = $subs[$index];
        my $show = $manual->inherited($subroutine)
                 ? $args{show_inherited_subs}
                 : $args{show_described_subs};

        $self->showSubroutine 
        ( %args
        , subroutine             => $subroutine
        , show_subroutine        => $show
        , last                   => ($index==$#subs)
        );
    }
}

#-------------------------------------------


sub showSubroutine(@)
{   my ($self, %args) = @_;

    my $subroutine = $args{subroutine} or confess;
    my $manual = $args{manual}         or confess;
    my $output = $args{output}    || select;

    #
    # Method use
    #

    my $use    = $args{show_subroutine} || 'EXPAND';
    my ($show_use, $expand)
     = $use eq 'EXPAND' ? ('showSubroutineUse',  1)
     : $use eq 'USE'    ? ('showSubroutineUse',  0)
     : $use eq 'NAMES'  ? ('showSubroutineName', 0)
     : $use eq 'NO'     ? (undef,                0)
     : croak "ERROR: illegal value for show_subroutine: $use";

    $self->$show_use(%args, subroutine => $subroutine)
       if defined $show_use;
 
    return unless $expand;

    $args{show_inherited_options} ||= 'USE';
    $args{show_described_options} ||= 'EXPAND';

    #
    # Subroutine descriptions
    #

    my $descr       = $args{show_sub_description} || 'DESCRIBED';
    my $description = $subroutine->findDescriptionObject;
    my $show_descr  = 'showSubroutineDescription';

       if(not $description || $descr eq 'NO') { $show_descr = undef }
    elsif($descr eq 'REFER')
    {   $show_descr = 'showSubroutineDescriptionRefer'
           if $manual->inherited($description);
    }
    elsif($descr eq 'DESCRIBED')
         { $show_descr = undef if $manual->inherited($description) }
    elsif($descr eq 'ALL') {;}
    else { croak "ERROR: illegal value for show_sub_description: $descr" }
    
    $self->$show_descr(%args, subroutine => $description)
          if defined $show_descr;

    #
    # Options
    #

    my $options = $subroutine->collectedOptions;

    my $opttab  = $args{show_option_table} || 'NAMES';
    my @options = @{$options}{ sort keys %$options };

    # Option table

    my @opttab
     = $opttab eq 'NO'       ? ()
     : $opttab eq 'DESCRIBED'? (grep {not $manual->inherits($_->[0])} @options)
     : $opttab eq 'INHERITED'? (grep {$manual->inherits($_->[0])} @options)
     : $opttab eq 'ALL'      ? @options
     : croak "ERROR: illegal value for show_option_table: $opttab";
    
    $self->showOptionTable(%args, options => \@opttab)
       if @opttab;

    # Option expanded

    my @optlist;
    foreach (@options)
    {   my ($option, $default) = @$_;
        my $check
          = $manual->inherited($option) ? $args{show_inherited_options}
          :                               $args{show_described_options};
        push @optlist, $_ if $check eq 'USE' || $check eq 'EXPAND';
    }

    $self->showOptions(%args, options => \@optlist)
        if @optlist;

    # Examples

    my @examples = $subroutine->examples;
    my $show_ex  = $args{show_examples} || 'EXPAND';
    $self->showExamples(%args, examples => \@examples)
        if $show_ex eq 'EXPAND';
    
    # Diagnostics

    my @diags    = $subroutine->diagnostics;
    my $show_diag= $args{show_diagnostics} || 'NO';
    $self->showDiagnostics(%args, diagnostics => \@diags)
        if $show_diag eq 'EXPAND';
}

#-------------------------------------------


sub showExamples(@) {shift}

#-------------------------------------------


sub showSubroutineUse(@) {shift}


#-------------------------------------------


sub showSubroutineName(@) {shift}

#-------------------------------------------


sub showSubroutineDescription(@) {shift}

#-------------------------------------------


sub showOptionTable(@) {shift}

#-------------------------------------------


sub showOptions(@)
{   my ($self, %args) = @_;

    my $options = $args{options} or confess;
    my $manual  = $args{manual}  or confess;

    foreach (@$options)
    {   my ($option, $default) = @$_;
        my $show
         = $manual->inherited($option) ? $args{show_inherited_options}
         :                               $args{show_described_options};

        my $action
         = $show eq 'USE'   ? 'showOptionUse'
         : $show eq 'EXPAND'? 'showOptionExpand'
         : croak "ERROR: illegal show option choice $show";

        $self->$action(%args, option => $option, default => $default);
    }
    $self;
}

#-------------------------------------------


sub showOptionUse(@) {shift}

#-------------------------------------------


sub showOptionExpand(@) {shift}

#-------------------------------------------

1;

