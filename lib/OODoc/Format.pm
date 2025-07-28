package OODoc::Format;
use parent 'OODoc::Object';

use strict;
use warnings;

use Log::Report    'oodoc';

use OODoc::Manifest ();

our %formatters =
  ( pod   => 'OODoc::Format::Pod'
  , pod2  => 'OODoc::Format::Pod2'
  , pod3  => 'OODoc::Format::Pod3'
  , html  => 'OODoc::Format::Html'
  , html2 => 'OODoc::Format::Html2'   # not (yet) included in the OODoc release
  );

=chapter NAME

OODoc::Format - base class for all OODoc formatters

=chapter SYNOPSIS

 # Never instantiated directly.

=chapter DESCRIPTION

A formater produces manual pages in some way or an other which contain
(parts of) the module documentation.  Each formatter class is based on
this OODoc::Format class, which should not be instantiated directly.
By far most users will never explicitly create a formatter by themselves:
it is created implicitly when M<OODoc::formatter()> is called on a M<OODoc>
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

=item * M<OODoc::Format::Pod3>

The whole formatter, implemented as template in M<OODoc::Template>, a
very light weighted template system.

You have to install L<OODoc::Template> to use this feature.

=item * M<OODoc::Format::Html>

Produce HTML by filling in templates. This module requires
L<Bundle::Template::Magic> and the ability to run cgi scripts.

=back

=chapter METHODS

=section Constructors

=c_method new %options

=requires format 'pod*'|'html*'|PACKAGE
Select the formatter to be used.

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

=error formatter $name has compilation errors: $@
The formatter which is specified does not compile, so can not be used.

=cut

sub new($%)
{	my ($class, %args) = @_;

	$class eq __PACKAGE__
        or return $class->SUPER::new(%args);

	my $format = $args{format}
        or error __x"No formatter specified.";

    my $pkg = $formatters{$format} || $format;

    eval "require $pkg";
    $@ and error __x"formatter {name} has compilation errors: {err}", name => $format, err => $@;

    $pkg->new(%args);
}

sub init($)
{   my ($self, $args) = @_;

    $self->SUPER::init($args) or return;
	$self->{OF_format}   = delete $args->{format};

    my $name = $self->{OF_project} = delete $args->{project}
        or error __x"formatter knows no project name";

    $self->{OF_version}  = delete $args->{version}
        or error __x"formatter for {name} does not know the version", name => $name;

    $self->{OF_workdir}  = delete $args->{workdir}
        or error __x"no working directory specified for {name}", name => $name;

    $self->{OF_manifest} = delete $args->{manifest} || OODoc::Manifest->new;
    $self;
}

#-------------------------------------------
=section Attributes

=method project 
Returns the name of this project.
=cut

sub project() { $_[0]->{OF_project} }

=method version 
Returns the version string of this project.  This version may
contains any character, so should be handled with care.

=method workdir 
Returns the name of the work directory: the top location for all
the output files.

=method manifest 
Returns the M<OODoc::Manifest> object which maintains the names
of created files.

=method format
Code for the format.
=cut

sub version()  { $_[0]->{OF_version} }
sub workdir()  { $_[0]->{OF_workdir} }
sub manifest() { $_[0]->{OF_manifest} }
sub format()   { $_[0]->{OF_format} }

#-------------------------------------------
=section Page generation

=method createPages %options

=option  append STRING|CODE
=default append C<undef>
The value is passed on to M<createManual(append)>,
but the behavior is formatter dependent.

=option  manual_templates DIRECTORY
=default manual_templates C<undef>
Passed to M<createManual(template)>, and defines the
location of the set of pages which has to be created for each manual
page.  Some formatters do not support templates and the valid values
are formatter dependent.

=option  other_templates DIRECTORY
=default other_templates C<undef>
Other files which have to be copied
passed to M<createOtherPages(source)>.

=option  process_files REGEXP
=default process_files <formatter dependent>
Selects the files which are to be processed for special markup information.
Other files, like image files, will be simply copied.  The value will be
passed to M<createOtherPages(process)>.

=option  manual_format ARRAY
=default manual_format []
Options passed to M<createManual()> when a manual page has to be produced.
See the applicable formatter manual page for the possible flags and
values.

=option  select CODE|REGEXP
=default select <all>
Produce only the indicated manuals, which is useful in case of merging
manuals from different distributions.  When a REGEXP is provided, it
will be checked against the manual name.  The CODE reference will be
called with a manual as only argument.

=cut

sub createPages(%)
{   my ($self, %args) = @_;

    my $sel = $args{select} || sub { 1 };
    my $select = ref $sel eq 'CODE' ? $sel : sub { $_[0]->name =~ $sel };

	# Manual knowledge is global

    my $options = $args{manual_format} || [];
    foreach my $package (sort $self->packageNames)
    {
        foreach my $manual ($self->manualsForPackage($package))
        {   $select->($manual) or next;

            unless($manual->chapters)
            {   trace "  skipping $manual: no chapters";
                next;
            }

            trace "  creating manual $manual with ".(ref $self);

            $self->createManual
              ( manual   => $manual
              , template => $args{manual_templates}
              , append   => $args{append}
              , @$options
              );
        }
    }

    #
    # Create other pages
    #

    trace "creating other pages";
    $self->createOtherPages
      ( source   => $args{other_templates}
      , process  => $args{process_files}
      );

    1;
}

=method createManual %options
Format a manual into the selected format.

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

sub createManual(@) {panic}

=method cleanup $manual, STRING
Takes the STRING and cleans it up to be in the right format for the
current formatter.  The cleaning up is parser dependent, and therefore
the parser of the manual is addressed to do the work.
=cut

sub cleanup($$)
{   my ($self, $manual, $string) = @_;
    $manual->parser->cleanup($self, $manual, $string);
}

=method showChapter %options
You can pass all %options about formatting to this method.  They will passed
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
    my $chapter  = $args{chapter} or panic;
    my $manual   = $args{manual}  or panic;
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

=method showStructureExpanded %options

=option   show_chapter_examples 'NO'|'EXPAND'
=default  show_chapter_examples 'EXPAND'
The I<chapter examples> are all examples which are not subroutine
related: examples which come at the end of a chapter, section, or
subsection.
=cut

sub showStructureExpanded(@) {panic}

=method showStructureRefer %options
=cut

sub showStructureRefer(@) {panic}

sub chapterName(@)        {shift->showRequiredChapter(NAME        => @_)}
sub chapterSynopsis(@)    {shift->showOptionalChapter(SYNOPSIS    => @_)}
sub chapterInheritance(@) {shift->showOptionalChapter(INHERITANCE => @_)}
sub chapterDescription(@) {shift->showRequiredChapter(DESCRIPTION => @_)}
sub chapterOverloaded(@)  {shift->showOptionalChapter(OVERLOADED  => @_)}
sub chapterMethods(@)     {shift->showOptionalChapter(METHODS     => @_)}
sub chapterExports(@)     {shift->showOptionalChapter(EXPORTS     => @_)}
sub chapterDiagnostics(@) {shift->showOptionalChapter(DIAGNOSTICS => @_)}
sub chapterDetails(@)     {shift->showOptionalChapter(DETAILS     => @_)}
sub chapterReferences(@)  {shift->showOptionalChapter(REFERENCES  => @_)}
sub chapterCopyrights(@)  {shift->showOptionalChapter(COPYRIGHTS  => @_)}

=method showRequiredChapter $name, %options
=warning missing required chapter $name in $manual
=cut

sub showRequiredChapter($%)
{   my ($self, $name, %args) = @_;
    my $manual  = $args{manual} or panic;

    my $chapter = $manual->chapter($name)
        or (alert "missing required chapter $name in $manual"), return;

    $self->showChapter(chapter => $chapter, %args);
}

=method showOptionalChapter $name, %options
=cut

sub showOptionalChapter($@)
{   my ($self, $name, %args) = @_;
    my $manual  = $args{manual} or panic;
    my $chapter = $manual->chapter($name) or return;
    $self->showChapter(chapter => $chapter, %args);
}

=method createOtherPages %options
Create other pages which come with the set of formatted manuals.  What
the contents of these pages is depends on the formatter.  Some formatters
simply ignore the functionality of this method as a whole: they do not
support data-files which are not manuals.

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

=method showSubroutines %options

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

=option  show_examples 'NO'|'EXPAND'
=default show_examples 'EXPAND'

=option  show_diagnostics 'NO'|'EXPAND'
=default show_diagnostics 'NO'

=cut

sub showSubroutines(@)
{   my ($self, %args) = @_;

    my @subs   = $args{subroutines} ? sort @{$args{subroutines}} : [];
    return unless @subs;

    my $manual = $args{manual} or panic;
    my $output = $args{output}    || select;

    # list is also in ::Pod3
    $args{show_described_options} ||= 'EXPAND';
    $args{show_described_subs}    ||= 'EXPAND';
    $args{show_diagnostics}       ||= 'NO';
    $args{show_examples}          ||= 'EXPAND';
    $args{show_inherited_options} ||= 'USE';
    $args{show_inherited_subs}    ||= 'USE';
    $args{show_option_table}      ||= 'ALL';
    $args{show_subs_index}        ||= 'NO';

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

=method showSubroutine <@>

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

    my $subroutine = $args{subroutine} or panic;
    my $manual = $args{manual} or panic;
    my $output = $args{output} || select;

    #
    # Method use
    #

    my $use    = $args{show_subroutine} || 'EXPAND';
    my ($show_use, $expand)
      = $use eq 'EXPAND' ? ('showSubroutineUse',  1)
      : $use eq 'USE'    ? ('showSubroutineUse',  0)
      : $use eq 'NAMES'  ? ('showSubroutineName', 0)
      : $use eq 'NO'     ? (undef,                0)
      : error __x"illegal value for show_subroutine: {value}", value => $use;

    $self->$show_use(%args, subroutine => $subroutine)
        if defined $show_use;

    $expand or return;

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
    else { error __x"illegal value for show_sub_description: {v}", v => $descr}

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
     : error __x"illegal value for show_option_table: {v}", v => $opttab;

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

=method showExamples %options
=requires examples ARRAY
=requires manual MANUAL
=requires output FILE
=cut

sub showExamples(@) {shift}

=method showSubroutineUse %options
=requires subroutine OBJECT
=requires manual OBJECT
=requires output FILE

=warning unknown subroutine type $type for $name in $manual
=cut

sub showSubroutineUse(@) {shift}

=method showSubroutineName %options
=requires subroutine OBJECT
=requires manual OBJECT
=requires output FILE

=option  last BOOLEAN
=default last 0
=cut

sub showSubroutineName(@) {shift}

=method showSubroutineDescription %options
=requires subroutine OBJECT
=requires manual OBJECT
=requires output FILE
=cut

sub showSubroutineDescription(@) {shift}

=method showOptionTable %options
=requires options ARRAY
=requires manual OBJECT
=requires output FILE
=cut

sub showOptionTable(@)
{   my ($self, %args) = @_;
    my $options = $args{options} or panic;
    my $manual  = $args{manual}  or panic;
    my $output  = $args{output}  or panic;

    my @rows;
    foreach (@$options)
    {   my ($option, $default) = @$_;
        my $optman = $option->manual;
        push @rows, [ $self->cleanup($manual, $option->name)
                    , ($manual->inherited($option) ? $self->link(undef, $optman) : '') 
                    , $self->cleanup($manual, $default->value)
                    ];
    }

    my @header = ('Option', 'Defined in', 'Default');
    unless(grep length $_->[1], @rows)
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

    $self;
}

=method showOptions %options
The options shown are B<not> the %options passed as argument, but the
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

    my $options = $args{options} or panic;
    my $manual  = $args{manual}  or panic;

    foreach (@$options)
    {   my ($option, $default) = @$_;
        my $show = $manual->inherited($option)
          ? $args{show_inherited_options}
          : $args{show_described_options};

        my $action
          = $show eq 'USE'   ? 'showOptionUse'
          : $show eq 'EXPAND'? 'showOptionExpand'
          : error __x"illegal show option choice: {v}", v => $show;

        $self->$action(%args, option => $option, default => $default);
    }
    $self;
}

=method showOptionUse %options
=requires option OBJECT
=requires default OBJECT
=requires output FILE
=requires manual OBJECT
=cut

sub showOptionUse(@) {shift}

=method showOptionExpand %options
=requires option OBJECT
=requires default OBJECT
=requires output FILE
=requires manual OBJECT
=cut

sub showOptionExpand(@) {shift}

#----------------------
=section Commonly used functions
=cut

1;
