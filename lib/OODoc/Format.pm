
package OODoc::Format;
use base 'OODoc::Object';

use strict;
use warnings;

use Carp;
use OODoc::Manifest;

=chapter NAME

OODoc::Format - base class for all OODoc formatters

=chapter SYNOPSIS

 # Never instantiated directly.

=chapter DESCRIPTION

A formater produces manual pages in some way or an other which contain
(parts of) the module documentation.  Each formatter class is based on
this OODoc::Format class, which should not be instantiated directly.
By far most users will never explicitly create a formatter by themselves:
it is created implicitly when M<OODoc::create()> is called on a M<OODoc>
object.

Currently available formatters:

=over 4

=item * M<OODoc::Format::Pod>

Simple formatter, which has the layout of the produced POD manual pages
hard-coded in it's body.  The only way to adapt the structure of the
pages is by extending the class, and thereby overrule some of the
methods which produce the text.  Not much of a problem for experienced
Object Oriented programmers.

=item * M<OODoc::Format::Pod2>

This formatter uses the same methods to generate the manual page as
defined by M<OODoc::Format::Pod>, but the general layout of the page
can be configured using templates.
You have to install L<Bundle::Template::Magic> to use this feature.

=item * M<OODoc::Format::Html>

Produce HTML by filling in templates. This module requires
L<Bundle::Template::Magic> and the ability to run cgi scripts.

=back

=cut

#-------------------------------------------

=chapter METHODS

=cut

#-------------------------------------------

=c_method new OPTIONS

=requires project STRING

The short name of this project (module), set by M<OODoc::new(project)>.

=requires version STRING

Many manual pages will contain the version of the project.  This can
be any STRING, although blanks are not advised.

=requires workdir DIRECTORY

The DIRECTORY where the output will be placed.  If it does not exist,
it will be created for you.

=option  manifest OBJECT
=default manifest undef

=error formatter has no project name.

A formatter was created without a name specified for the project at
hand.  This should be passed with M<new(project)>.

=error no working directory specified.

The formatter has to know where the output can be written.  This
directory must be provided via M<new(workdir)>, but was not specified.

=error formatter does not know the version.

=cut

sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args) or return;

    $self->{OF_project} = delete $args->{project}
        or croak "ERROR: formatter knows no project name.\n";

    $self->{OF_version} = delete $args->{version}
        or croak "ERROR: formatter does not know the version.\n";

    $self->{OF_workdir} = delete $args->{workdir}
        or croak "ERROR: no working directory specified.\n";

    $self->{OF_manifest} = delete $args->{manifest} || OODoc::Manifest->new;

    $self;
}

#-------------------------------------------

=section Attributes

=method project
Returns the name of this project.
=cut

sub project() {shift->{OF_project}}

#-------------------------------------------

=method version
Returns the version string of this project.  This version may
contains any character, so should be handled with care.
=cut

sub version() {shift->{OF_version}}

#-------------------------------------------

=method workdir
Returns the name of the work directory: the top location for all
the output files.
=cut

sub workdir() {shift->{OF_workdir}}

#-------------------------------------------

=method manifest
Returns the M<OODoc::Manifest> object which maintains the names
of created files.
=cut

sub manifest() {shift->{OF_manifest}}

#-------------------------------------------

=section Page generation

=method createManual OPTIONS

=option  format_options ARRAY
=default format_options []

An ARRAY which contains a list of options which are the defaults
for formatting a chapter.

=requires manual MANUAL

The manual to be formatted.

=option  append STRING|CODE
=default append undef

=option  template LOCATION
=default template undef

Some formatters support templates to descibe the output of the pages.
The valid values for this option differs per formatter.

=requires project STRING

The name of this project, which will appear on many pages.

=cut

sub createManual(@) { confess }

#-------------------------------------------

=method cleanup MANUAL, STRING

Takes the STRING and cleans it up to be in the right format for the
current formatter.  The cleaning up is parser dependent, and therefore
the parser of the manual is addressed to do the work.

=cut

sub cleanup($$)
{   my ($self, $manual, $string) = @_;
    $manual->parser->cleanup($self, $manual, $string);
}

#-------------------------------------------

=method showChapter OPTIONS

You can pass all OPTIONS about formatting to this method.  They will passed
to the related methods.  So: the list of options you can pass here is much
longer: the combination of everything possible for all show* methods.

=requires chapter CHAPTER
=requires output FILE
=requires manual MANUAL

=option   show_inherited_chapters 'NO'|'REFER'|'EXPAND'
=default  show_inherited_chapters 'REFER'

=option   show_inherited_sections 'NO'|'REFER'|'EXPAND'
=default  show_inherited_sections 'REFER'

REFER means that inherited sections are simply listed as reference
to the manual page which describes it.

=option   show_inherited_subsections 'NO'|'REFER'|'EXPAND'
=default  show_inherited_subsections 'REFER'

=cut

sub showChapter(@)
{   my ($self, %args) = @_;
    my $chapter  = $args{chapter} or confess;
    my $manual   = $args{manual}  or confess;
    my $show_ch  = $args{show_inherited_chapter}    || 'REFER';
    my $show_sec = $args{show_inherited_section}    || 'REFER';
    my $show_ssec= $args{show_inherited_subsection} || 'REFER';

    if($manual->inherited($chapter))
    {    return $self if $show_ch eq 'NO';
         $self->showStructureRefer(%args, structure => $chapter);
         return $self;
    }

    $self->showStructureExpand(%args, structure => $chapter);

    foreach my $section ($chapter->sections)
    {   if($manual->inherited($section))
        {   next if $show_sec eq 'NO';
            $self->showStructureRefer(%args, structure => $section), next
                unless $show_sec eq 'REFER';
        }

        $self->showStructureExpand(%args, structure => $section);

        foreach my $subsection ($section->subsections)
        {   if($manual->inherited($subsection))
            {   next if $show_ssec eq 'NO';
                $self->showStructureRefer(%args, structure=>$subsection), next
                    unless $show_ssec eq 'REFER';
            }

            $self->showStructureExpand(%args, structure => $subsection);
        }
    }
}

#-------------------------------------------

=method showStructureExpanded OPTIONS

=option   show_chapter_examples 'NO'|'EXPAND'
=default  show_chapter_examples 'EXPAND'

The I<chapter examples> are all examples which are not subroutine
related: examples which come at the end of a chapter, section, or
subsection.

=cut

sub showStructureExpanded(@) {confess}

#-------------------------------------------

=method showStructureRefer OPTIONS

=cut

sub showStructureRefer(@) {confess}

#-------------------------------------------

sub chapterName(@)        {shift->showRequiredChapter(NAME        => @_)}
sub chapterSynopsis(@)    {shift->showOptionalChapter(SYNOPSIS    => @_)}
sub chapterDescription(@) {shift->showRequiredChapter(DESCRIPTION => @_)}
sub chapterOverloaded(@)  {shift->showOptionalChapter(OVERLOADED  => @_)}
sub chapterMethods(@)     {shift->showOptionalChapter(METHODS     => @_)}
sub chapterExports(@)     {shift->showOptionalChapter(EXPORTS     => @_)}
sub chapterDiagnostics(@) {shift->showOptionalChapter(DIAGNOSTICS => @_)}
sub chapterDetails(@)     {shift->showOptionalChapter(DETAILS     => @_)}
sub chapterReferences(@)  {shift->showOptionalChapter(REFERENCES  => @_)}
sub chapterCopyrights(@)  {shift->showOptionalChapter(COPYRIGHTS  => @_)}

#-------------------------------------------

=method showRequiredChapter NAME, OPTIONS

=warning missing required chapter $name in $manual

=cut

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

=method showOptionalChapter NAME, OPTIONS

=cut

sub showOptionalChapter($@)
{   my ($self, $name, %args) = @_;
    my $manual  = $args{manual} or confess;

    my $chapter = $manual->chapter($name);
    return unless defined $chapter;

    $self->showChapter(chapter => $chapter, %args);
}

#-------------------------------------------

=method createOtherPages OPTIONS

Create other pages which come with the set of formatted manuals.  What
the contents of these pages is depends on the formatter.  Some formatters
simply ignore the functionality of this method as a whole: they do not
support data-files which are not manuals.

=option  verbose  INTEGER
=default verbose  0

=option  source   DIRECTORY
=default source   undef

The location of the DIRECTORY which contains files which are part of
the produced set of documentation, but not copied per manual page
but only once.

=option  process  REGEXP
=default process  undef

Selects files to be processed from the source directory.  Other files
are copied without modification.  What happens with the selected
files is formatter dependent.

=cut

sub createOtherPages(@) {shift}

#-------------------------------------------

=method showSubroutines OPTIONS

=option  subroutines ARRAY
=default subroutines []

=option  output  FILE
=default output  <selected filehandle>

=requires manual  MANUAL

=option  show_subs_index 'NO'|'NAMES'|'USE'
=default show_subs_index 'NO'

=option  show_inherited_subs 'NO'|'NAMES'|'USE'|'EXPAND'
=default show_inherited_subs 'USE'

=option  show_described_subs 'NO'|'NAMES'|'USE'|'EXPAND'
=default show_described_subs 'EXPAND'

=option  show_option_table 'NO'|'DESCRIBED'|'INHERITED'|'ALL'
=default show_option_table 'ALL'

=option  show_inherited_options 'NO'|'LIST'|'USE'|'EXPAND'
=default show_inherited_options 'USE'

=option  show_described_options 'NO'|'LIST'|'USE'|'EXPAND'
=default show_described_options 'EXPAND'

=cut

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

=method showSubroutine(@)

=requires subroutine OBJECT
=requires manual  MANUAL

=option  output  FILE
=default output  <selected filehandle>

=option  show_subroutine 'NO'|'NAMES'|'USE'|'EXPAND'
=default show_subroutine 'EXPAND'

=option  show_option_table 'NO'|'INHERITED'|'DESCRIBED'|'ALL'
=default show_option_table 'ALL'

=option  show_inherited_options 'NO'|'LIST'|'USE'|'EXPAND'
=default show_inherited_options 'USE'

=option  show_described_options 'NO'|'LIST'|'USE'|'EXPAND'
=default show_described_options 'EXPAND'

=option  show_sub_description 'NO'|'DESCRIBED'|'REFER'|'ALL'
=default show_sub_description 'DESCRIBED'

Included the description of the use of the subroutines, which
comes before the options are being explained.  C<NO> will cause
the description to be ignored, C<DESCRIBED> means that only
text which was written in the manual-page at hand is included,
C<REFER> means that a reference to inherited documentation is
made, and with C<ALL> the inherited texts are expanded into this
file as well.

=option  show_examples 'NO'|'EXPAND'
=default show_examples 'EXPAND'

=option  show_diagnostics 'NO'|'EXPAND'
=default show_diagnostics 'NO'

Diagnostics (error and warning messages) are defined per subroutine,
but are usually not listed with the subroutine.  The POD formatter's
default behavior, for instance, puts them all in a separate DIAGNOSTICS
chapter per manual page.

=option  last BOOLEAN
=default last 0

=cut

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

=method showExamples OPTIONS

=requires examples ARRAY
=requires manual MANUAL
=requires output FILE

=cut

sub showExamples(@) {shift}

#-------------------------------------------

=method showSubroutineUse OPTIONS

=requires subroutine OBJECT
=requires manual OBJECT
=requires output FILE

=warning unknown subroutine type $type for $name in $manual

=cut

sub showSubroutineUse(@) {shift}


#-------------------------------------------

=method showSubroutineName OPTIONS

=requires subroutine OBJECT
=requires manual OBJECT
=requires output FILE

=option  last BOOLEAN
=default last 0

=cut

sub showSubroutineName(@) {shift}

#-------------------------------------------

=method showSubroutineDescription OPTIONS

=requires subroutine OBJECT
=requires manual OBJECT
=requires output FILE
=cut

sub showSubroutineDescription(@) {shift}

#-------------------------------------------

=method showOptionTable OPTIONS

=requires options ARRAY
=requires manual OBJECT
=requires output FILE

=cut

sub showOptionTable(@)
{   my ($self, %args) = @_;
    my $options = $args{options} or confess;
    my $manual  = $args{manual}  or confess;
    my $output  = $args{output}  or confess;

    my @rows;
    foreach (@$options)
    {   my ($option, $default) = @$_;
        my $optman = $option->manual;
        my $link   = $manual->inherited($option)
                   ? $self->link(undef, $optman)
                   : '';
        push @rows, [ $self->cleanup($manual, $option->name)
                    , $link
                    , $self->cleanup($manual, $default->value)
                    ];
    }

    my @header = ('Option', 'Defined in', 'Default');
    unless(grep {length $_->[1]} @rows)
    {   # removed empty "defined in" column
        splice @$_, 1, 1 for @rows, \@header;
    }

    $output->print("\n");
    $self->writeTable
     ( output => $output
     , header => \@header
     , rows   => \@rows
     , widths => [undef, 15, undef]
     );

    $self
}

#-------------------------------------------

=method showOptions OPTIONS

The options shown are B<not> the OPTIONS passed as argument, but the
options which belong to the subroutine being displayed.

=requires options ARRAY
=requires manual OBJECT

=option  show_inherited_options 'NO'|'LIST'|'USE'|'EXPAND'
=default show_inherited_options 'USE'

=option  show_described_options 'NO'|'LIST'|'USE'|'EXPAND'
=default show_described_options 'EXPAND'

=cut

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

=method showOptionUse OPTIONS

=requires option OBJECT
=requires default OBJECT
=requires output FILE
=requires manual OBJECT

=cut

sub showOptionUse(@) {shift}

#-------------------------------------------

=method showOptionExpand OPTIONS

=requires option OBJECT
=requires default OBJECT
=requires output FILE
=requires manual OBJECT

=cut

sub showOptionExpand(@) {shift}

#-------------------------------------------

=method createInheritance MANUAL

Create the text which represents the inheritance relationships of
a certain package.  More than one MANUAL can be defined for one
package, and will each produce the same text.  The returned string
still has to be cleaned-up before inclusion.

=cut

sub createInheritance($)
{   my ($self, $package) = @_;

    if($package->name ne $package->package)
    {   # This is extra code....
        my $from = $package->package;
        return "\n $package\n    contains extra code for\n    M<$from>\n";
    }

    my $output;
    my @supers  = $package->superClasses;

    if(my $realized = $package->realizes)
    {   $output .= "\n $package realizes a M<$realized>\n";
        @supers = $realized->superClasses if ref $realized;
    }

    if(my @extras = $package->extraCode)
    {   $output .= "\n $package has extra code in\n";
        $output .= "   M<$_>\n" foreach sort @extras;
    }

    foreach (@supers)
    {   $output .= "\n $package\n";
        $output .= $self->showSuperSupers($_);
    }

    if(my @subclasses = $package->subClasses)
    {   $output .= "\n $package is extended by\n";
        $output .= "   M<$_>\n" foreach sort @subclasses;
    }

    if(my @realized = $package->realizers)
    {   $output .= "\n $package is realized by\n";
        $output .= "   M<$_>\n" foreach sort @realized;
    }

    $output;
}

sub showSuperSupers($)
{   my ($self, $package) = @_;
    my $output = "   is a M<$package>\n";
    return $output
        unless ref $package;  # only the name of the package is known

    if(my $realizes = $package->realizes)
    {   $output .= $self->showSuperSupers($realizes);
        return $output;
    }

    my @supers = $package->superClasses or return $output;
    $output .= $self->showSuperSupers(shift @supers);

    foreach(@supers)
    {   $output .= "\n\n   $package also extends M<$_>\n";
        $output .= $self->showSuperSupers($_);
    }

    $output;
}

#-------------------------------------------

=section Template::Magic

Support methods for implementations which are based on L<Template::Magic>.

=method zoneGetParameters ZONE|STRING

Takes a Template::Magic::Zone object to process the text after the
tag.  You may also specify a string, for instance a modified
attribute list.  The return is a list of key-value pairs with data.

=examples of valid arguments

 <!--{examples expand NO list ALL}-->   # old style
 <!--{examples expand => NO, list => ALL}-->
 <!--{examples expand => NO,
         list => ALL}-->

=cut

sub zoneGetParameters($)
{   my ($self, $zone) = @_;
    my $param = ref $zone ? $zone->attributes : $zone;
    $param =~ s/^\s+//;
    $param =~ s/\s+$//;

    return () unless length $param;

    return split / /, $param       # old style
       unless $param =~ m/[^\s\w]/;

    # new style
    my @params = split /\s*\,\s*/, $param;
    map { (split /\s*\=\>\s*/, $_, 2) } @params;
}

#-------------------------------------------

=section Commonly used functions

=cut

1;

