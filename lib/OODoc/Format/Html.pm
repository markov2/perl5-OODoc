
package OODoc::Format::Html;
use base 'OODoc::Format';

use strict;
use warnings;

use Carp;
use IO::Scalar;
use IO::File;

use File::Spec;
use File::Find     'find';
use File::Basename qw/basename dirname/;
use File::Copy     'copy';
use POSIX          'strftime';

use Template::Magic;

=chapter NAME

OODoc::Format::Html - Produce HTML pages from the doc tree

=chapter SYNOPSIS

 my $doc = OODoc->new(...);
 $doc->createManual
   ( 'html'   # or 'OODoc::Format::Html'
   , format_options => [show_examples => 'NO']
   );

=chapter DESCRIPTION

Create manual pages in the HTML syntax, using the M<Template::Magic>
template system.  Producing HTML is more complicated than producing
POD, because one manual page may be spread over multiple output files.

=cut

#-------------------------------------------

=chapter METHODS

=cut

#-------------------------------------------

=c_method new OPTIONS

=option  html_root   URI
=default html_root   '/'

=option  jump_script URI
=default jump_script <html_root>/jump.cgi

=option  html_meta_data STRING
=default html_meta_data ''

Will be (usually) be added to the header, and may contain links to
Cascading Style Sheets, and such.

=cut

sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args) or return;

    my $html = delete $args->{html_root} || '/';
    $html    =~ s!/$!!;

    $self->{OFH_html} = $html;
    $self->{OFH_jump} = delete $args->{jump_script} || "$html/jump.cgi";
    $self->{OFH_meta} = delete $args->{html_meta_data};
    $self;
}

#-------------------------------------------

=section Page generation

=method cleanupString MANUAL, OBJECT

The general M<cleanup()> is too over eager: it turns all pieces of text
into paragraphs.  So things, like names of chapters, are not paragraphs
at all: these simple strings are to be cleaned from paragraph information.

=cut

sub cleanupString($$)
{   my $self = shift;
    my $text = $self->cleanup(@_);
    $text =~ s!</p>\s*<p>!<br />!gs;
    $text =~ s!\</?p\>!!g;
    $text;
}

#-------------------------------------------

=method link MANUAL, OBJECT, [TEXT]

Create the html for a link which refers to the OBJECT.  The link will be
shown somewhere in the MANUAL.  The TEXT is displayed as link, and defaults
to the name of the OBJECT.

=cut

sub link($$;$)
{   my ($self, $manual, $object, $text) = @_;
    $text = $object->name unless defined $text;

    my $jump
      = $object->isa('OODoc::Manual') ? "$self->{OFH_html}/$object/index.html"
      :   $self->{OFH_jump}.'?'.$manual->name.'&'.$object->unique;

    qq[<a href="$jump" target="_top">$text</a>];
}

#-------------------------------------------

=method mark MANUAL, ID

Write a marker to items file.  This locates an item to a frameset.

=cut

sub mark($$)
{   my ($self, $manual, $id) = @_;
    $self->{OFH_markers}->print("$id $manual $self->{OFH_filename}\n");
}

#-------------------------------------------

=method createManual OPTIONS

=option  template DIRECTORY|HASH
=default template "html/manual/"

A DIRECTORY containing all template files which have to be filled-in
and copied per manual page created.  You may also specify an HASH
of file- and directory names and format options for each of those files.
These options overrule the general M<createManual(format_options)> values
and the defaults.  These options can be overruled by values specified
in the template file.

=example template specification

Default:

 template => "html/manual/"

Complex:

 template => { "man_index/"    => [ show_examples => 'NO' ]
             , "man_main.html" => [ show_examples => 'EXPAND' ]
             }

=error no package name for html production

=error cannot write html manual at $filename: $!

=cut

sub createManual($@)
{   my ($self, %args) = @_;
    my $verbose  = $args{verbose} || 0;
    my $manual   = $args{manual} or confess;
    my $options  = $args{format_options} || [];

    # Location for the manual page files.

    my $template = $args{template} || File::Spec->catdir('html', 'manual');
    my %template = $self->expandTemplate($template, $options);

    my $dest = File::Spec->catdir($self->workdir, "$manual");
    $self->mkdirhier($dest);

    # File to trace markers must be open.

    unless(defined $self->{OFH_markers})
    {   my $markers = File::Spec->catdir($self->workdir, 'markers');
        my $mark = IO::File->new($markers, 'w')
            or die "Cannot write markers to $markers: $!\n";
        $self->{OFH_markers} = $mark;
        $mark->print($self->{OFH_html}, "\n");
    }

    #
    # Process template
    #

    my $manifest = $self->manifest;
    while(my($raw, $options) = each %template)
    {   my $cooked = File::Spec->catfile($dest, basename $raw);

        print "$manual: $cooked\n" if $verbose > 2;
        $manifest->add($cooked);

        my $output  = IO::File->new($cooked, "w")
          or die "ERROR: cannot write html manual at $cooked: $!";

        $self->{OFH_filename} = basename $raw;

        $self->format
         ( manual   => $manual
         , output   => $output
         , template => $raw
         , @$options
         );
    }

    delete $self->{OFH_filename};
    $self;
}

#-------------------------------------------

=method createOtherPages OPTIONS

=default source "html/other/"
=default process  qr/\.(s?html|cgi)$/

=error no directory to put other html pages in.
=error html source directory $source does not exist.

=cut

sub createOtherPages(@)
{   my ($self, %args) = @_;
    
    my $verbose  = $args{verbose} || 0;

    #
    # Collect files to be processed
    #

    my $source   = $args{source};
    if(defined $source)
    {   croak "ERROR: html source directory $source does not exist.\n"
             unless -d $source;
    }
    else
    {   $source = File::Spec->catdir("html", "other");
        return $self unless -d $source;
    }

    my $process  = $args{process}  || qr/\.(s?html|cgi)$/;

    my $dest = $self->workdir;
    $self->mkdirhier($dest);

    my @sources;
    find( { no_chdir => 1
          , wanted   => sub { my $fn = $File::Find::name;
                              push @sources, $fn if -f $fn;
                            }
           }, $source
        );

    #
    # Process files, one after the other
    #

    my $manifest = $self->manifest;
    foreach my $raw (@sources)
    {   (my $cooked = $raw) =~ s/$source/$dest/;

        print "create $cooked\n" if $verbose > 2;
        $manifest->add($cooked);

        if($raw =~ $process)
        {   $self->mkdirhier(dirname $cooked);
            my $output  = IO::File->new($cooked, "w")
                or die "ERROR: cannot write html other file at $cooked: $!";

            my $options = [];
            $self->format
             ( manual   => undef
             , output   => $output
             , template => $raw
             , @$options
             );
         }
         else
         {   copy($raw, $cooked)
                or die "ERROR: Copy from $raw to $cooked failed: $!\n";
         }

         my $rawmode = (stat $raw)[2] & 07777;
         chmod $rawmode, $cooked or confess;
    }

    $self;
}

#-------------------------------------------

=method expandTemplate LOCATION, [FORMAT]

Translate a filename, directory name or hash with file/directory names
which are specified as LOCATION for templates into hash of filenames
names and related formatting options.  The FORMAT is an array of options
which can be overruled by values which the LOCATION is specified as hash.

=examples expanding template specification into files

 my $exp = $self->expandTemplate("html/manual", [show => 'NO']);
 while(my ($fn,$opts) = each %$exp) {print "$fn @$opts\n"}
 # may print something like
 #   index.html show NO
 #   main.html show NO

 my $exp = $self->expandTemplate(
   { "html/manual/index.html" => [show => 'YES']
     "html/manual/main.html"  => []
   } , [show => 'NO']);
 # will print something like
 #   index.html show YES
 #   main.html show NO

=error cannot find template source $name

Somewhere was specified to use $name (a file or directory) as source
for a template.  However, it does not seem to exist.  Unfortunately,
the location where the source is specified is not known when the
error is produced.

=cut
 
sub expandTemplate($$)
{   my $self     = shift;
    my $loc      = shift || confess;
    my $defaults = shift || [];

    my @result;
    if(ref $loc eq 'HASH')
    {   foreach my $n (keys %$loc)
        {   my %options = (@$defaults, @{$loc->{$n}});
            push @result, $self->expandTemplate($n, [ %options ])
        }
    }
    elsif(-d $loc)
    {   find( { no_chdir => 1,
                wanted   => sub { my $fn = $File::Find::name;
                                  push @result, $fn, $defaults
                                     if -f $fn;
                                }
              }, $loc
            );
    }
    elsif(-f $loc) { push @result, $loc => $defaults }
    else { croak "ERROR: cannot find template source $loc." }

    @result;
}

#-------------------------------------------

sub showStructureExpand(@)
{   my ($self, %args) = @_;

    my $examples = $args{show_chapter_examples} || 'EXPAND';
    my $text     = $args{structure} or confess;

    my $name     = $text->name;
    my $level    = $text->level;
    my $output   = $args{output}  or confess;
    my $manual   = $args{manual}  or confess;

    # Produce own chapter description

    my $descr   = $self->cleanup($manual, $text->description);
    my $unique  = $text->unique;
    (my $id     = $name) =~ s/\W+/_/g;

    $output->print(
        qq[\n<h$level id="$id"><a name="$unique">$name</a></h$level>\n$descr]
                  );

    $self->mark($manual, $unique);

    # Link to inherited documentation.

    my $super = $text;
    while($super = $super->extends)
    {   last if $super->description !~ m/^\s*$/;
    }

    if(defined $super)
    {   my $superman = $super->manual;   #  :-)
        $output->print( "<p>See ", $self->link($superman, $super), " in "
                      , $self->link(undef, $superman), "</p>\n");
    }

    # Show the subroutines and examples.

    $self->showSubroutines(%args, subroutines => [$text->subroutines]);
    $self->showExamples(%args, examples => [$text->examples])
         if $examples eq 'EXPAND';

    $self;
}

#-------------------------------------------

sub showStructureRefer(@)
{   my ($self, %args) = @_;

    my $text     = $args{structure} or confess;

    my $name     = $text->name;
    my $level    = $text->level;
    my $output   = $args{output}  or confess;
    my $manual   = $args{manual}  or confess;

    my $link     = $self->link($manual, $text);
    $output->print(
       qq[\n<h$level id="$name"><a href="$link">$name</a><h$level>\n]);
    $self;
}

#-------------------------------------------

sub chapterDiagnostics(@)
{   my ($self, %args) = @_;

    my $manual  = $args{manual} or confess;
    my $diags   = $manual->chapter('DIAGNOSTICS');

    my @diags   = map {$_->diagnostics} $manual->subroutines;
    $diags      = OODoc::Text::Chapter->new(name => 'DIAGNOSTICS')
        if !$diags && @diags;

    return unless $diags;

    $self->showChapter(chapter => $diags, %args)
        if defined $diags;

    $self->showDiagnostics(%args, diagnostics => \@diags);
    $self;
}

#-------------------------------------------

sub showExamples(@)
{   my ($self, %args) = @_;
    my $examples = $args{examples} or confess;
    return unless @$examples;

    my $manual    = $args{manual}  or confess;
    my $output    = $args{output}  or confess;

    $output->print( qq[<dl class="example">\n] );

    foreach my $example (@$examples)
    {   my $name   = $example->name;
        my $descr  = $self->cleanup($manual, $example->description);
        my $unique = $example->unique;
        $output->print( <<EXAMPLE );
<dt>&raquo;&nbsp;<a name="$unique">Example</a>: $name</dt>
<dd>$descr</dd>
EXAMPLE

         $self->mark($manual, $unique);
    }
    $output->print( qq[</dl>\n] );

    $self;
}

#-------------------------------------------

sub showDiagnostics(@)
{   my ($self, %args) = @_;
    my $diagnostics = $args{diagnostics} or confess;
    return unless @$diagnostics;

    my $manual    = $args{manual}  or confess;
    my $output    = $args{output}  or confess;

    $output->print( qq[<dl class="diagnostics">\n] );

    foreach my $diag (sort @$diagnostics)
    {   my $name    = $diag->name;
        my $type    = $diag->type;
        my $text    = $self->cleanup($manual, $diag->description);
        my $unique  = $diag->unique;

        $output->print( <<DIAG );
<dt class="type">&raquo;&nbsp;$type: <a name="$unique">$name</a></dt>
<dd>$text</dd>
DIAG

         $self->mark($manual, $unique);
    }

    $output->print( qq[</dl>\n] );
    $self;
}


sub showSubroutine(@)
{   my $self = shift;
    my %args   = @_;
    my $output = $args{output}     or confess;
    my $sub    = $args{subroutine} or confess;
    my $type   = $sub->type;
    my $name   = $sub->name;

    $self->SUPER::showSubroutine(@_);

    $output->print( qq[</dd>\n</dl>\n</div>\n] );
    $self;
}

#-------------------------------------------

sub showSubroutineUse(@)
{   my ($self, %args) = @_;
    my $subroutine = $args{subroutine} or confess;
    my $manual     = $args{manual}     or confess;
    my $output     = $args{output}     or confess;

    my $type       = $subroutine->type;
    my $name       = $self->cleanupString($manual, $subroutine->name);
    my $paramlist  = $self->cleanupString($manual, $subroutine->parameters);
    my $unique     = $subroutine->unique;

    my $class      = $manual->package;

    my $call       = qq[<b><a name="$unique">$name</a></b>];
    $call         .= "(&nbsp;$paramlist&nbsp;)" if length $paramlist;
    $self->mark($manual, $unique);

    my $use
      = $type eq 'i_method' ? qq[\$obj-&gt;$call]
      : $type eq 'c_method' ? qq[\$class-&gt;$call]
      : $type eq 'ci_method'? qq[\$obj-&gt;$call<br />\$class-&gt;$call]
      : $type eq 'overload' ? qq[overload: $call]
      : $type eq 'function' ? qq[$call]
      : $type eq 'tie'      ? $call
      :                       '';

    warn "WARNING: unknown subroutine type $type for $name in $manual"
        unless length $use;

    $output->print( <<SUBROUTINE );
<div class="$type" id="$name">
<dl>
<dt class="sub_use">$use</dt>
<dd class="sub_body">
SUBROUTINE

    if($manual->inherited($subroutine))
    {   my $defd    = $subroutine->manual;
        my $sublink = $self->link($defd, $subroutine, $name);
        my $manlink = $self->link($manual, $defd);
        $output->print( qq[See $sublink in $manlink.<br />\n] );
    }

    $self;
}

#-------------------------------------------

sub showSubsIndex(@)
{   my ($self, %args) = @_;
    my $output     = $args{output}     or confess;
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
     ( $self->cleanupString($manual, $url)
     , ($args{last} ? ".\n" : ",\n")
     );
}

#-------------------------------------------

sub showOptions(@)
{   my $self   = shift;
    my %args   = @_;
    my $output = $args{output} or confess;
    $output->print( qq[<dl class="options">\n] );

    $self->SUPER::showOptions(@_);

    $output->print( qq[</dl>\n] );
    $self;
}

#-------------------------------------------

sub showOptionUse(@)
{   my ($self, %args) = @_;
    my $output = $args{output} or confess;
    my $option = $args{option} or confess;
    my $manual = $args{manual} or confess;

    my $params = $self->cleanupString($manual, $option->parameters);
    $params    =~ s/\s+$//;
    $params    =~ s/^\s+//;
    $params    = qq[ =&gt; <span class="params">$params</span>]
        if length $params;
 
    my $use    = qq[<span class="option">$option</span>];
    $output->print( qq[<dt class="option_use">$use$params</dt>\n] );
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
    my $descr = $self->cleanupString($manual, $where->description);

    $output->print( qq[<dd>$descr</dd>\n] )
        if length $descr;

    $self;
}

#-------------------------------------------

=method writeTable

=requires output FILE
=requires header ARRAY
=requires ARRAY-OF-ARRAYS

An array of arrays, each describing a row for the output.  The first row
is the header.

=cut

sub writeTable($@)
{   my ($self, %args) = @_;

    my $rows   = $args{rows}   or confess;
    return unless @$rows;

    my $head   = $args{header} or confess;
    my $output = $args{output} or confess;

    $output->print( qq[<table cellspacing="3" cellpadding="0">\n] );

    local $"   = qq[</th>    <th align="left">];
    $output->print( qq[<tr><th align="left">@$head</th></tr>\n] );

    local $"   = qq[</td>    <td valign="top">];
    $output->print( qq[<tr><td align="left">@$_</td></tr>\n] )
        foreach @$rows;

    $output->print( qq[</table>\n] );
    $self;
}

#-------------------------------------------

sub showSubroutineDescription(@)
{   my ($self, %args) = @_;
    my $manual  = $args{manual}                   or confess;
    my $subroutine = $args{subroutine}            or confess;

    my $text    = $self->cleanup($manual, $subroutine->description);
    return $self unless length $text;

    my $output  = $args{output}                   or confess;
    $output->print($text);

    my $extends = $self->extends                  or return $self;
    my $refer   = $extends->findDescriptionObject or return $self;

    $output->print("<br />\n");
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

=section Template processing

=cut

#-------------------------------------------

=method format OPTIONS

=option  manual MANUAL
=default manual C<undef>

=cut

our %producers =
 ( a           => 'templateHref'
 , chapter     => 'templateChapter'
 , date        => 'templateDate'
 , index       => 'templateIndex'
 , inheritance => 'templateInheritance'
 , list        => 'templateList'
 , manual      => 'templateManual'
 , meta        => 'templateMeta'
 , distribution=> 'templateDistribution'
 , name        => 'templateName'
 , project     => 'templateProject'
 , title       => 'templateTitle'
 , version     => 'templateVersion'
 );
   
sub format(@)
{   my ($self, %args) = @_;
    my $output    = delete $args{output};

    my %permitted = ();
    while(my ($tag, $method) = each %producers)
    {   $permitted{$tag}
          = sub { my $zone = shift;
                  $self->$method($zone, \%args);
                };
    }

    my $template  = Template::Magic->new
     ( markers   => 'HTML'
     , behaviors => 'HTML'
     , lookups   => [ \%permitted ]
     );

    my $created = $template->output($args{template});
    $output->print($$created);
}

#-------------------------------------------

=method templateTitle ZONE, ARGS

=cut

sub templateProject($$)
{   my ($self, $zone, $args) = @_;
    $self->project;
}

#-------------------------------------------

=method templateTitle ZONE, ARGS

=error not a manual, so no automatic title in $template

=cut

sub templateTitle($$)
{   my ($self, $zone, $args) = @_;

    my $manual = $args->{manual}
       or die "ERROR: not a manual, so no automatic title in $args->{template}\n";

    my $name   = $self->cleanupString($manual, $manual->name);
    $name =~ s/\<[^>]*\>//g;
    $name;
}

#-------------------------------------------

=method templateManual ZONE, ARGS

=error not a manual, so no manual name for $template

=cut

sub templateManual($$)
{   my ($self, $zone, $args) = @_;

    my $manual = $args->{manual}
       or confess "ERROR: not a manual, so no manual name for $args->{template}\n";

    $self->cleanupString($manual, $manual->name);
}

#-------------------------------------------

=method templateDistribution ZONE, ARGS

The name of the distribution which contains the manual page at hand.

=cut

sub templateDistribution($$)
{   my ($self, $zone, $args) = @_;
    my $manual  = $args->{manual};
    defined $manual ? $manual->distribution : '';
}

#-------------------------------------------

=method templateVersion ZONE, ARGS

The version is taken from the manual (which means that you may have
a different version number per manual) when a manual is being formatted,
and otherwise the project total version.

=cut

sub templateVersion($$)
{   my ($self, $zone, $args) = @_;
    my $manual  = $args->{manual};
    defined $manual ? $manual->version : $self->version;
}

#-------------------------------------------

=method templateDate ZONE, ARGS

=cut

sub templateDate($$)
{   my ($self, $zone, $args) = @_;
    strftime "%Y/%m/%d", localtime;
}

#-------------------------------------------

=method templateName ZONE, ARGS

=error not a manual, so no name for $template

=error cannot find chapter NAME in manual $name

=error chapter NAME in manual $name has illegal shape

=cut

sub templateName($$)
{   my ($self, $zone, $args) = @_;

    my $manual = $args->{manual}
       or die "ERROR: not a manual, so no name for $args->{template}\n";

    my $chapter = $manual->chapter('NAME')
       or die "ERROR: cannot find chapter NAME in manual ",$manual->source,"\n";

    my $descr   = $chapter->description;

    return $1 if $descr =~ m/^\s*\S+\s*\-\s*(.*?)\s*$/;
   
    die "ERROR: chapter NAME in manual $manual has illegal shape\n";
}

#-------------------------------------------

=method templateHref ZONE, ARGS

=cut

our %path_lookup =
 ( front       => "index.html"
 , manuals     => "manuals/index.html"
 , methods     => "methods/index.html"
 , diagnostics => "diagnostics/index.html"
 , details     => "details/index.html"
 );

sub templateHref($$)
{   my ($self, $zone, $args) = @_;
    my ($to, $window) = split " ", $zone->attributes;
    my $path   = $path_lookup{$to} || warn "missing path for $to";

    qq[<a href="$self->{OFH_html}/$path" target="_top">];
}

#-------------------------------------------

=method templateMeta ZONE, ARGS

ARGS is a reference to a hash with options.  ZONE contains the attributes
in the template.  Use M<new(html_meta_data)> to set the result of this
method, or extend its implementation.

=cut

sub templateMeta($$)
{   my ($self, $zone, $args) = @_;
    $self->{OFH_meta};
}

#-------------------------------------------

=method templateInheritance ZONE, ARGS

=cut

sub templateInheritance(@)
{   my ($self, $zone, $args) = @_;

    my $manual  = $args->{manual} or confess;
    my $output  = $self->cleanup($manual, $self->createInheritance($manual));
    return '' unless length $output;

    for($output)
    {   s#<pre>\n*(.*)</pre>\n*#$1#s;            # over-eager cleanup
        s#^( +)#'&nbsp;' x length($1)#gme;
        s#$#<br />#gm;
    }
    $output;
}

#-------------------------------------------

=method templateChapter

=error chapter without name in template.

In your template file, a {chapter} statement is used, which is
erroneous, because it requires a chapter name.

=warning no meaning for container $container in chapter block

=cut

sub templateChapter($$)
{   my ($self, $zone, $args) = @_;
    my $contained = $zone->content;
    warn "WARNING: no meaning for container $contained in chapter block\n"
        if defined $contained && length $contained;

    my $attr    = $zone->attributes;
    my $name    = $attr =~ s/^\s*(\w+)\s*\,?\s*// ? $1 : undef;
    my @attrs   = $self->zoneGetParameters($attr);

    croak "ERROR: chapter without name in template"
       unless defined $name;

    my $manual  = $args->{manual};
    defined $manual or confess;
    my $chapter = $manual->chapter($name) or return '';

    my $out     = '';
    $self->showChapter(%$args, chapter => $chapter,
       output => IO::Scalar->new(\$out), @attrs);

    $out;
}

#-------------------------------------------

=method templateIndex ZONE, ARGS

The I<index> template is called with one keyword, which tells the
kind of index to be built.  Valid values are C<MANUALS>,
C<SUBROUTINES>, C<DIAGNOSTICS>, and C<DETAILS>.  In the future, more
names may get defined.

The tag produces a list of columns which should be put in a table
container to produce valid html.

=example use of the template tag "index"

 <table cellspacing="10">
 <!--{index DIAGNOSTICS type error starting_with A}-->
 </table>

=option  starting_with 'ALL'|STRING
=default starting_with 'ALL'

Only selects the objects which have names which start with the STRING
(case-insensitive match).  Underscores in the string are interpreted
as any non-word character or underscore.

=option  type 'ALL'|STRING
=default type 'ALL'

The types of objects which are to be selected, which is not applicable to
all kinds of indexes.  The STRING may contain an I<underscore> or I<pipe>
separated list of types, for instance C<method|tie> when subroutines
are listed or C<error> for diagnostics.

=option  table_columns INTEGER
=default table_columns 2

Produce a table with that number of columns.

=error   no group named as attribute for list
=warning no meaning for container $contained in list block
=error   unknown group $name as list attribute

=cut

sub templateIndex($$)
{   my ($self, $zone, $args) = @_;

    my $contained = $zone->content;
    warn "WARNING: no meaning for container $contained in list block\n"
        if defined $contained && length $contained;

    my $attrs  = $zone->attributes;
    my $group  = $attrs =~ s/^\s*(\w+)\s*\,?\s*// ? $1 : undef;
    die "ERROR: no group named as attribute for list\n"
       unless defined $group;

    my %opts   = $self->zoneGetParameters($attrs);

    my $start  = $opts{starting_with} || $args->{starting_with} ||'ALL';
    my $types  = $opts{type}          || $args->{type}          ||'ALL';

    my $select = sub { @_ };
    unless($start eq 'ALL')
    {   $start =~ s/_/[\\W_]/g;
        my $regexp = qr/^$start/i;
        $select    = sub { grep { $_->name =~ $regexp } @_ };
    }
    unless($types eq 'ALL')
    {   my @take   = map { $_ eq 'method' ? '.*method' : $_ }
                         split /[_|]/, $types;
        local $"   = ')|(';
        my $regexp = qr/^(@take)$/i;
        my $before = $select;
        $select    = sub { grep { $_->type =~ $regexp } $before->(@_) };
    }

    my $columns = $opts{table_columns} || $args->{table_columns} || 2;
    my @rows;

    if($group eq 'SUBROUTINES')
    {   my @subs;

        foreach my $manual ($self->manuals)
        {   foreach my $sub ($select->($manual->ownSubroutines))
            {   my $linksub = $self->link($manual, $sub, $sub->name);
                my $linkman = $self->link(undef, $manual, $manual->name);
                my $link    = "$linksub -- $linkman";
                push @subs, [ lc("$sub-$manual"), $link ];
            }
        }

        @rows = map { $_->[1] }
            sort { $a->[0] cmp $b->[0] } @subs;
    }
    elsif($group eq 'DIAGNOSTICS')
    {   foreach my $manual ($self->manuals)
        {   foreach my $sub ($manual->ownSubroutines)
            {   my @diags    = $select->($sub->diagnostics) or next;

                my $linksub  = $self->link($manual, $sub, $sub->name);
                my $linkman  = $self->link(undef, $manual, $manual->name);

                foreach my $diag (@diags)
                {   my $type = uc($diag->type);
                    push @rows, <<"DIAG";
$type: $diag<br />
&middot;&nbsp;$linksub in $linkman<br />
DIAG
                }
            }
        }

       @rows = sort @rows;
    }
    elsif($group eq 'DETAILS')
    {  foreach my $manual (sort $select->($self->manuals))
       {   my $details  = $manual->chapter("DETAILS") or next;
           my @sections = grep {not $manual->inherited($_)}
                              $details->sections;
           next unless @sections || length $details->description;

           my $sections = join "\n"
                             , map { "<li>".$self->link($manual, $_)."</li>" }
                                @sections;

           push @rows, $self->link($manual, $details, "Details in $manual")
                       . qq[\n<ul>\n$sections</ul>\n]
       }
    }
    elsif($group eq 'MANUALS')
    {  @rows = map { $self->link(undef, $_, $_->name) }
                 sort $select->($self->manuals);
    }
    else
    {  die "ERROR: unknown group $group as list attribute.\n";
    }

    push @rows, ('') x ($columns-1);
    my $rows   = int(@rows/$columns);

    my $output = qq[<tr>];
    while(@rows >= $columns)
    {   $output .= qq[<td valign="top">]
                . join( "<br />\n", splice(@rows, 0, $rows))
                .  qq[</td>\n];
    }
    $output   .= qq[</tr>\n];
    $output;
}

#-------------------------------------------

=method templateList ZONE, ARGS

The ZONE (which originate from the template file) start with the
name of a chapter or C<'ALL'>.  The rest of the ZONE
are interpreted as argument list which overrule the OPTIONS.

=requires manual MANUAL

=option  show_sections 'NO'|'NAME'|'LINK'
=default show_sections 'LINK'

This option is only used when a chapter name is specified.  It tells how
to treat sections within the chapter: must they be shown expanded or
should the subroutines be listed within the chapter.

=option  show_subroutines 'NO'|'COUNT'|'LIST'
=default show_subroutines 'LIST'

=option  subroutine_types 'ALL'|LIST
=default subroutine_types 'ALL'

The LIST contains a I<underscore> separated set of subroutine types which are
selected to be displayed, for instance C<method_tie_function>. The separator
underscore is used because M<Template::Magic> does not accept commas
in the tag parameter list, which is a pity.

=error no group named as attribute for index

In your template file, an {index} statement is used without a chapter name
or 'ALL'.  Therefore, it is unclear which kind of index has to
be built.

=warning no meaning for container $container in index block
=error   illegal value to show_sections: $show_sec

=cut

sub templateList($$)
{   my ($self, $zone, $args) = @_;
    my $contained = $zone->content;
    warn "WARNING: no meaning for container $contained in index block\n"
        if defined $contained && length $contained;

    my $attrs    = $zone->attributes;
    my $group    = $attrs =~ s/^\s*(\w+)\s*\,?// ? $1 : undef;
    my %opts     = $self->zoneGetParameters($attrs);

    die "ERROR: no group named as attribute for index\n"
       unless defined $group;

    my $show_sub = $opts{show_subroutines}||$args->{show_subroutines}||'LIST';
    my $types    = $opts{subroutine_types}||$args->{subroutine_types}||'ALL';
    my $manual   = $args->{manual} or confess;

    my $output   = '';

    my $selected = sub { @_ };
    unless($types eq 'ALL')
    {   my @take   = map { $_ eq 'method' ? '.*method' : $_ }
                         split /[_|]/, $types;
        local $"   = ')|(';
        my $regexp = qr/^(@take)$/;
        $selected  = sub { grep { $_->type =~ $regexp } @_ };
    }

    my $sorted     = sub { sort {$a->name cmp $b->name} @_ };

    if($group eq 'ALL')
    {   my @subs   = $sorted->($selected->($manual->subroutines));
        if(!@subs || $show_sub eq 'NO') { ; }
        elsif($show_sub eq 'COUNT')     { $output .= @subs }
        else
        {   $output .= $self->indexListSubroutines($manual,@subs);
        }
    }
    else  # any chapter
    {   my $chapter  = $manual->chapter($group) or return '';
        my $show_sec = $opts{show_sections} ||$args->{show_sections} ||'LINK';
        my @sections = $show_sec eq 'NO' ? () : $chapter->sections;

        my @subs = $sorted->($selected->( @sections
                                        ? $chapter->subroutines
                                        : $chapter->all('subroutines')
                                        )
                             );

        $output  .= $self->link($manual, $chapter, $chapter->niceName); 
        my $count = @subs && $show_sub eq 'COUNT' ? ' ('.@subs.')' : '';

        if($show_sec eq 'NO') { $output .= qq[$count<br />\n] }
        elsif($show_sec eq 'LINK' || $show_sec eq 'NAME')
        {   $output .= qq[<br />\n<ul>\n];
            if(!@subs) {;}
            elsif($show_sec eq 'LINK')
            {   my $link = $self->link($manual, $chapter, 'unsorted');
                $output .= qq[<li>$link$count\n];
            }
            elsif($show_sec eq 'NAME')
            {   $output .= qq[<li>];
            }

            $output .= $self->indexListSubroutines($manual,@subs)
                if @subs && $show_sub eq 'LIST';
        }
        else
        {   confess "ERROR: illegal value to show_sections: $show_sec\n";
        }
     
        # All sections within the chapter (if show_sec is enabled)

        foreach my $section (@sections)
        {   my @subs  = $sorted->($selected->($section->all('subroutines')));

            my $count = ! @subs              ? ''
                      : $show_sub eq 'COUNT' ? ' ('.@subs.')'
                      :                        ': ';

            if($show_sec eq 'LINK')
            {   my $link = $self->link($manual, $section, $section->niceName);
                $output .= qq[<li>$link$count\n];
            }
            else
            {   $output .= qq[<li>$section$count\n];
            }

            $output .= $self->indexListSubroutines($manual,@subs)
                if $show_sub eq 'LIST' && @subs;

            $output .= qq[</li>\n];
        }

        $output .= qq[</ul>\n]
             if $show_sec eq 'LINK' || $show_sec eq 'NAME';
    }

    $output;
}

#-------------------------------------------

sub indexListSubroutines(@)
{   my $self   = shift;
    my $manual = shift;
    
    join ",\n"
       , map { $self->link($manual, $_, $_) }
            @_;
}

#-------------------------------------------

=section Commonly used functions

=chapter DETAILS

=section Configuring

=cut

1;
