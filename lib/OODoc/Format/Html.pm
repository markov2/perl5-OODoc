# This code is part of perl distribution OODoc.  It is licensed under the
# same terms as Perl itself: https://spdx.org/licenses/Artistic-2.0.html

package OODoc::Format::Html;
use parent 'OODoc::Format';

use strict;
use warnings;

use Log::Report     'oodoc';
use OODoc::Template ();

use File::Spec::Functions qw/catfile catdir/;
use File::Find      qw/find/;
use File::Basename  qw/basename dirname/;
use File::Copy      qw/copy/;
use POSIX           qw/strftime/;
use List::Util      qw/first/;

=chapter NAME

OODoc::Format::Html - Produce HTML pages using OODoc::Template

=chapter SYNOPSIS

 my $doc = OODoc->new(...);
 $doc->createManual
   ( 'html'   # or 'OODoc::Format::Html'
   , show_examples => 'NO',
   );

=chapter DESCRIPTION

Create manual pages in the HTML syntax, using the M<OODoc::Template>
template system.  Producing HTML is more complicated than producing
POD, because one manual page may be spread over multiple output files.

=chapter METHODS

=section Constructors

=c_method new %options

=default format      'html'

=option  html_root   URI
=default html_root   '/'

=option  jump_script URI
=default jump_script <html_root>/jump.cgi

=option  html_meta_data STRING
=default html_meta_data ''
Will be (usually) be added to the header, and may contain links to
Cascading Style Sheets, and such.

=option  html_stylesheet STRING
=default html_stylesheet undef
Adds a link to the stylesheet to the meta-data.

=cut

sub init($)
{   my ($self, $args) = @_;
	$args->{format} //= 'html';

    $self->SUPER::init($args) or return;

    my $html = delete $args->{html_root} || '/';
    $html    =~ s! /$ !!x;

    $self->{OFH_html} = $html;
    $self->{OFH_jump} = delete $args->{jump_script} || "$html/jump.cgi";

    my $meta  = delete $args->{html_meta_data} || '';
    if(my $ss = delete $args->{html_stylesheet})
    {   my $base = basename $ss;
        $meta   .= qq[<link rel="STYLESHEET" href="/$base">];
    }
    $self->{OFH_meta} = $meta;
    $self;
}

#-------------------------------------------
=section Attributes

=method manual [$manual]
Returns (optionally after setting) the $manual which is being processed.

=method jumpScript

=method htmlRoot
Without trailing slash.

=method markers [$filehandle]
The filehandle where M<createManual()> writes the 'mark's to: the jump
points.

=method filename [$filename]
The name of the documentation file which M<createManual()> is currently
processing.

=method meta
Returns a string with html for the page header block.
=cut

sub jumpScript() { $_[0]->{OFH_jump} }
sub htmlRoot()   { $_[0]->{OFH_html} }
sub meta()       { $_[0]->{OFH_meta} }

sub manual(;$)   { @_==2 ? $_[0]->{OFH_manual} = $_[1] : $_[0]->{OFH_manual} }
sub markers(;$)  { @_==2 ? $_[0]->{OFH_mark} = $_[1] : $_[0]->{OFH_mark} }
sub filename(;$) { @_==2 ? $_[0]->{OFH_fn}   = $_[1] : $_[0]->{OFH_fn}   }

#-------------------------------------------
=section Page generation

=method cleanupString $manual, $object
The general M<cleanup()> is over-eager: it turns all pieces of text
into paragraphs.  So things, like names of chapters, are not paragraphs
at all: these simple strings are to be cleaned from paragraph information.
=cut

sub cleanupString($$)
{   my $self = shift;
    $self->cleanup(@_) =~ s!</p>\s*<p>!<br>!grs =~ s!\</?p\>!!gr;
}

=method link $manual, $object, [$text]
Create the html for a link which refers to the $object.  The link will be
shown somewhere in the $manual.  The $text is displayed as link, and defaults
to the name of the $object.
=cut

sub link($$;$)
{   my ($self, $manual, $object, $text) = @_;
    $text //= $object->name;

    my $jump;
    if($object->isa('OODoc::Manual'))
    {   (my $manname = $object->name) =~ s!\:\:!_!g;
        $jump = $self->htmlRoot . "/$manname/index.html";
    }
    else
    {   (my $manname = $manual->name) =~ s!\:\:!_!g;
        $jump = $self->jumpScript . "?$manname&". $object->unique;
    }

    qq[<a href="$jump" target="_top">$text</a>];
}

=method mark $manual, $id
Write a marker to items file.  This locates an item to a frameset.
=cut

sub mark($$)
{   my ($self, $manual, $id) = @_;
	my @fields = ($id, $manual =~ s/\:\:/_/gr, $self->filename);
    $self->markers->print(join(' ', @fields), "\n");
}

=method createManual %options

=option  template DIRECTORY|HASH
=default template "html/manual/"

A DIRECTORY containing all template files which have to be filled-in
and copied per manual page created.  You may also specify an HASH
of file- and directory names and format options for each of those files.
These options can be overruled by values specified in the template file.

=example template specification

Default:

 template => "html/manual/"

Complex:

 template => { "man_index/"    => [ show_examples => 'NO' ]
             , "man_main.html" => [ show_examples => 'EXPAND' ]
             }

=error cannot write markers to $filename: $!
=error cannot write html manual to $filename: $!
=cut

sub createManual($@)
{   my ($self, %args) = @_;
    my $verbose  = $args{verbose} || 0;
    my $manual   = $args{manual} or panic;

    # Location for the manual page files.

    my $template = $args{template} || (catdir 'html', 'manual');
    my %template = $self->expandTemplate($template, [ %args ]);

    my $manfile  = "$manual" =~ s!\:\:!_!gr;
    my $dest = catdir $self->workdir, $manfile;
    $self->mkdirhier($dest);

    # File to trace markers must be open.

    unless(defined $self->markers)
    {   my $markers = catfile $self->workdir, 'markers';
        open my $mark, ">:encoding(utf8)", $markers
            or fault __x"cannot write markers to {fn}", fn => $markers;
        $self->markers($mark);
        $mark->print($self->htmlRoot, "\n");
    }

    #
    # Process template
    #

    my $manifest = $self->manifest;
    while(my($raw, $options) = each %template)
    {   my $cooked = catfile $dest, basename $raw;

        print "$manual: $cooked\n" if $verbose > 2;
        $manifest->add($cooked);

        open my $output, ">:encoding(utf8)", $cooked
            or fault __x"cannot write html manual to {fn}", fn => $cooked;

        $self->filename(basename $raw);

        $self->manual($manual);
        $self->interpolate(output => $output, template_fn => $raw, @$options);
        $self->manual(undef);
        $output->close;
    }

    $self->filename(undef);
    $self;
}

=method createOtherPages %options

=default source   "html/other/"
=default process  qr/\.(s?html|cgi)$/

=error html source directory $source: $!
=error cannot write html to $filename: $!
=error chmod of $filename to $mode failed: $!
=cut

sub createOtherPages(@)
{   my ($self, %args) = @_;

    my $verbose = $args{verbose} || 0;

    #
    # Collect files to be processed
    #

    my $source  = $args{source};
    if(defined $source)
    {   -d $source
             or fault __x"html source directory {dir}", dir => $source;
    }
    else
    {   $source = catdir "html", "other";
        -d $source or return $self;
    }

    my $process = $args{process} || qr/\.(?:s?html|cgi)$/;

    my $dest    = $self->workdir;
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
    {   (my $cooked = $raw) =~ s/\Q$source\E/$dest/;

        print "create $cooked\n" if $verbose > 2;
        $manifest->add($cooked);

        if($raw =~ $process)
        {   $self->mkdirhier(dirname $cooked);
            open my $output, ">:encoding(utf8)", $cooked
                or fault __x"cannot write html to {fn}", fn => $cooked;

            my $options = [];
            $self->interpolate
             ( manual      => undef
             , output      => $output
             , template_fn => $raw
             , @$options
             );
            $output->close;
         }
         else
         {   copy $raw, $cooked
                or fault __x"copy from {from} to {to} failed", from => $raw, to => $cooked;
         }

         my $rawmode = (stat $raw)[2] & 07777;
         chmod $rawmode, $cooked
             or fault __x"chmod of {fn} to {mode%o} failed", fn => $cooked, mode => $rawmode;
    }

    $self;
}

=method expandTemplate $location, [$format]
Translate a filename, directory name or hash with file/directory names
which are specified as $location for templates into hash of filenames
names and related formatting options.  The $format is an array of options
which can be overruled by values which the $location is specified as hash.

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
    my $loc      = shift || panic;
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
                                  push @result, $fn, $defaults if -f $fn;
                                }
              }, $loc
            );
    }
    elsif(-f $loc) { push @result, $loc => $defaults }
    else { error __x"cannot find template source '{name}'", name => $loc }

    @result;
}

sub showStructureExpand(@)
{   my ($self, %args) = @_;

    my $examples = $args{show_chapter_examples} || 'EXPAND';
    my $text     = $args{structure} or panic;

    my $name     = $text->name;
    my $level    = $text->level +1;  # header level, chapter = H2
    my $output   = $args{output} or panic;
    my $manual   = $args{manual} or panic;

    # Produce own chapter description

    my $descr   = $self->cleanup($manual, $text->description);
    my $unique  = $text->unique;
    my $id      = $name =~ s/\W+/_/gr;

    $output->print( qq[\n<h$level id="$id"><a name="$unique">$name</a></h$level>\n$descr] );

    $self->mark($manual, $unique);

    # Link to inherited documentation.

    my $super = $text;
    while($super = $super->extends)
    {   last if $super->description !~ m/^\s*$/;
    }

    if(defined $super)
    {   my $superman = $super->manual;   #  :-)
        $output->print( "<p>See ", $self->link($superman, $super),
            " in " , $self->link(undef, $superman), "</p>\n");
    }

    # Show the subroutines and examples.

    $self->showSubroutines(%args, subroutines => [$text->subroutines]);
    $self->showExamples(%args, examples => [$text->examples])
         if $examples eq 'EXPAND';

    $self;
}

sub showStructureRefer(@)
{   my ($self, %args) = @_;

    my $text     = $args{structure} or panic;
    my $name     = $text->name;
    my $level    = $text->level;

    my $output   = $args{output}  or panic;
    my $manual   = $args{manual}  or panic;

    my $link     = $self->link($manual, $text);
    $output->print( qq[\n<h$level id="$name"><a href="$link">$name</a><h$level>\n] );
    $self;
}

sub chapterDiagnostics(@)
{   my ($self, %args) = @_;

    my $manual  = $args{manual} or panic;
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

sub showExamples(@)
{   my ($self, %args) = @_;
    my $examples = $args{examples} or panic;
    return unless @$examples;

    my $manual    = $args{manual}  or panic;
    my $output    = $args{output}  or panic;

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

sub showDiagnostics(@)
{   my ($self, %args) = @_;
    my $diagnostics = $args{diagnostics} or panic;
    return unless @$diagnostics;

    my $manual    = $args{manual}  or panic;
    my $output    = $args{output}  or panic;

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
    my $output = $args{output}     or panic;
    my $sub    = $args{subroutine} or panic;
    my $type   = $sub->type;
    my $name   = $sub->name;

    $self->SUPER::showSubroutine(@_);

    $output->print( qq[</dd>\n</dl>\n</div>\n] );
    $self;
}

sub showSubroutineUse(@)
{   my ($self, %args) = @_;
    my $subroutine = $args{subroutine} or panic;
    my $manual     = $args{manual}     or panic;
    my $output     = $args{output}     or panic;

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
      : $type eq 'ci_method'? qq[\$obj-&gt;$call<br>\$class-&gt;$call]
      : $type eq 'overload' ? qq[overload: $call]
      : $type eq 'function' ? qq[$call]
      : $type eq 'tie'      ? $call
      : warning("unknown subroutine type {type} for {name} in {manual}"
             , type => $type, name => $name, manual => $manual);

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
        $output->print( qq[See $sublink in $manlink.<br>\n] );
    }
    $self;
}

sub showSubsIndex(@)
{   my ($self, %args) = @_;
    my $output     = $args{output}     or panic;
}

sub showSubroutineName(@)
{   my ($self, %args) = @_;
    my $subroutine = $args{subroutine} or panic;
    my $manual     = $args{manual}     or panic;
    my $output     = $args{output}     or panic;
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

sub showOptions(@)
{   my $self   = shift;
    my %args   = @_;
    my $output = $args{output} or panic;
    $output->print( qq[<dl class="options">\n] );

    $self->SUPER::showOptions(@_);

    $output->print( qq[</dl>\n] );
    $self;
}

sub showOptionUse(@)
{   my ($self, %args) = @_;
    my $output = $args{output} or panic;
    my $option = $args{option} or panic;
    my $manual = $args{manual} or panic;

    my $params = $self->cleanupString($manual, $option->parameters);
    $params    =~ s/\s+$//;
    $params    =~ s/^\s+//;
    $params    = qq[ =&gt; <span class="params">$params</span>]
        if length $params;

    my $use    = qq[<span class="option">$option</span>];
    $output->print( qq[<dt class="option_use">$use$params</dt>\n] );
    $self;
}

sub showOptionExpand(@)
{   my ($self, %args) = @_;
    my $output = $args{output} or panic;
    my $option = $args{option} or panic;
    my $manual = $args{manual}  or panic;

    $self->showOptionUse(%args);

    my $where = $option->findDescriptionObject or return $self;
    my $descr = $self->cleanupString($manual, $where->description);

    $output->print( qq[<dd>$descr</dd>\n] )
        if length $descr;

    $self;
}

=method writeTable 

=requires output FILE
=requires header ARRAY

=requires rows ARRAY-OF-ARRAYS
An array of arrays, each describing a row for the output.  The first row
is the header.

=cut

sub writeTable($@)
{   my ($self, %args) = @_;

    my $rows   = $args{rows}   or panic;
    return unless @$rows;

    my $head   = $args{header} or panic;
    my $output = $args{output} or panic;

    $output->print( qq[<table cellspacing="0" cellpadding="2" border="1">\n] );

    local $"   = qq[</th>    <th align="left">];
    $output->print( qq[<tr><th align="left">@$head</th></tr>\n] );

    local $"   = qq[</td>    <td valign="top">];
    $output->print( qq[<tr><td align="left">@$_</td></tr>\n] )
        foreach @$rows;

    $output->print( qq[</table>\n] );
    $self;
}

sub showSubroutineDescription(@)
{   my ($self, %args) = @_;
    my $manual     = $args{manual}     or panic;
    my $subroutine = $args{subroutine} or panic;

    my $text       = $self->cleanup($manual, $subroutine->description);
    return $self unless length $text;

    my $output     = $args{output}     or panic;
    $output->print($text);

    my $extends    = $subroutine->extends    or return $self;
    my $refer      = $extends->findDescriptionObject or return $self;

    $output->print("<br>\n");
    $self->showSubroutineDescriptionRefer(%args, subroutine => $refer);
}

sub showSubroutineDescriptionRefer(@)
{   my ($self, %args) = @_;
    my $manual     = $args{manual}     or panic;
    my $subroutine = $args{subroutine} or panic;
    my $output     = $args{output}     or panic;
    $output->print("\nSee ", $self->link($manual, $subroutine), "\n");
}

#----------------------

=section Template processing

=method interpolate %options

=option  manual MANUAL
=default manual undef
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

sub interpolate(@)
{   my ($self, %args) = @_;
    my $output    = delete $args{output};

    my %permitted = %args;
    my $template  = OODoc::Template->new;
    while(my ($tag, $method) = each %producers)
    {   $permitted{$tag} = sub
          { # my ($istag, $attrs, $ifblock, $elseblock) = @_;
            shift;
            $self->$method($template, @_)
          };
    }

    $output->print(scalar $template->processFile($args{template_fn}, \%permitted));
}

=method templateProject $templ, $attrs, $if, $else
=cut

sub templateProject($$)
{   my ($self, $templ, $attrs, $if, $else) = @_;
    $self->project;
}

=method templateTitle $templ, $attrs, $if, $else
=error not a manual, so no automatic title in $template
=cut

sub templateTitle($$)
{   my ($self, $templ, $attrs, $if, $else) = @_;

    my $manual = $self->manual
        or error __x"not a manual, so no automatic title in {fn}", fn => scalar $templ->valueFor('template_fn');

    my $name   = $self->cleanupString($manual, $manual->name);
    $name      =~ s/\<[^>]*\>//g;
    $name;
}

=method templateManual $templ, $attrs, $if, $else
=error not a manual, so no manual name for $template
=cut

sub templateManual($$)
{   my ($self, $templ, $attrs, $if, $else) = @_;

    my $manual = $self->manual
        or error __x"not a manual, so no manual name for {fn}", fn => scalar $templ->valueFor('template_fn');

    $self->cleanupString($manual, $manual->name);
}

=method templateDistribution $templ, $attrs, $if, $else
The name of the distribution which contains the manual page at hand.
=cut

sub templateDistribution($$)
{   my ($self, $templ, $attrs, $if, $else) = @_;
    my $manual  = $self->manual;
    defined $manual ? $manual->distribution : '';
}

=method templateVersion $templ, $attrs, $if, $else
The version is taken from the manual (which means that you may have
a different version number per manual) when a manual is being formatted,
and otherwise the project total version.
=cut

sub templateVersion($$)
{   my ($self, $templ, $attrs, $if, $else) = @_;
    my $manual  = $self->manual;
    defined $manual ? $manual->version : $self->version;
}

=method templateDate $templ, $attrs, $if, $else
=cut

sub templateDate($$)
{   my ($self, $templ, $attrs, $if, $else) = @_;
    strftime "%Y/%m/%d", localtime;
}

=method templateName $templ, $attrs, $if, $else
=error not a manual, so no name for $template
=error cannot find chapter NAME in manual $name
=error chapter NAME in manual $name has illegal shape
=cut

sub templateName($$)
{   my ($self, $templ, $attrs, $if, $else) = @_;

    my $manual = $self->manual
        or error __x"not a manual, so no name for {fn}"
            , fn => scalar $templ->valueFor('template_fn');

    my $chapter = $manual->chapter('NAME')
        or error __x"cannot find chapter NAME in manual {fn}", $manual->source;

    my $descr   = $chapter->description;

    return $1 if $descr =~ m/^ \s*\S+\s*\-\s*(.*?)\s* $ /x;

    error __x"chapter NAME in manual {manual} has illegal shape"
      , manual => $manual;
}

=method templateHref $templ, $attrs, $if, $else
=cut

our %path_lookup =
  ( front       => "/index.html"
  , manuals     => "/manuals/index.html"
  , methods     => "/methods/index.html"
  , diagnostics => "/diagnostics/index.html"
  , details     => "/details/index.html"
  );

sub templateHref($$)
{   my ($self, $templ, $attrs, $if, $else) = @_;
    my $window = delete $attrs->{window} || '_top';
    keys %$attrs==1
        or error __x"expect one name with 'a'";
    (my $to)   = keys %$attrs;

    my $path   = $path_lookup{$to}
        or error __x"missing path for {dest}", dest => $to;

	my $root   = $self->htmlRoot;
    qq[<a href="$root$path" target="$window">];
}

=method templateMeta $templ, $attrs, $if, $else
ARGS is a reference to a hash with options.  ZONE contains the attributes
in the template.  Use M<new(html_meta_data)> to set the result of this
method, or extend its implementation.
=cut

sub templateMeta($$)
{   my ($self, $templ, $attrs, $if, $else) = @_;
    $self->meta;
}

=method templateInheritance $templ, $attrs, $if, $else
=cut

sub templateInheritance(@)
{   my ($self, $templ, $attrs, $if, $else) = @_;

    my $manual  = $self->manual;
    my $chapter = $manual->chapter('INHERITANCE')
        or return '';

    my $buffer  = '';
    open my $out, '>', \$buffer;
    $self->showChapter
      ( %$attrs
      , manual  => $self->manual
      , chapter => $chapter
      , output  => $out
      );
    close $out;

    for($buffer)
    {   s#\<pre\>\s*(.*?)\</pre\>\n*#\n$1#gs;   # over-eager cleanup
        s#^( +)#'&nbsp;' x length($1)#gme;
        s# $ #<br>#gmx;
        s#(\</h\d\>)(\<br\>\n?)+#$1\n#;
    }

    $buffer;
}

=method templateChapter 
=error chapter without name in template $fn
In your template file, a {chapter} statement is used, which is
erroneous, because it requires a chapter name.

=warning no meaning for container $contained in chapter block
=cut

sub templateChapter($$)
{   my ($self, $templ, $attrs, $if, $else) = @_;
    warning __x"no meaning for container {c} in chapter block", c => $if
        if defined $if && length $if;

    my $name  = first { !/[a-z]/ } keys %$attrs;
    defined $name
        or error __x"chapter without name in template {fn}", fn => scalar $templ->valueFor('template_fn');

    my $manual  = $self->manual;
    defined $manual or panic;
    my $chapter = $manual->chapter($name) or return '';

    my $buffer  = '';
    open my $out, '>', \$buffer;
    $self->showChapter
      ( %$attrs
      , manual  => $self->manual
      , chapter => $chapter
      , output  => $out
      );
    close $out;

    $buffer;
}

=method templateIndex $templ, $attrs, $if, $else

The I<index> template is called with one keyword, which tells the
kind of index to be built.  Valid values are C<MANUALS>,
C<SUBROUTINES>, C<DIAGNOSTICS>, and C<DETAILS>.  In the future, more
names may get defined.

The tag produces a list of columns which should be put in a table
container to produce valid html.

=example use of the template tag "index"

 <table cellspacing="10">
 <!--{index DIAGNOSTICS type => error, starting_with => A}-->
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
{   my ($self, $templ, $attrs, $if, $else) = @_;

    ! defined $if || ! length $if
        or warning __x"no meaning for container {c} in list block", c => $if;

    my $group  = first { !/[a-z]/ } keys %$attrs
        or error __x"no group named as attribute for list";

    my $start  = $attrs->{starting_with} || 'ALL';
    my $types  = $attrs->{type}          || 'ALL';

    my $select = sub { @_ };
    if($start ne 'ALL')
    {   $start =~ s/_/[\\W_]/g;
        my $regexp = qr/^$start/i;
        $select    = sub { grep $_->name =~ $regexp, @_ };
    }

    if($types ne 'ALL')
    {   my @take   = map { $_ eq 'method' ? '.*method' : $_ } split /[_|]/, $types;
        local $"   = ')|(';
        my $regexp = qr/^(@take)$/i;
        my $before = $select;
        $select    = sub { grep $_->type =~ $regexp, $before->(@_) };
    }

    my $columns = $attrs->{table_columns} || 2;
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
$type: $diag<br>
&middot;&nbsp;$linksub in $linkman<br>
DIAG
                }
            }
        }

        @rows = sort @rows;
    }
    elsif($group eq 'DETAILS')
    {   foreach my $manual (sort $select->($self->manuals))
        {   my $details  = $manual->chapter("DETAILS") or next;
            my @sections;
            foreach my $section ($details->sections)
            {   my @subsect = grep !$manual->inherited($_) && $_->description, $section->subsections;
                push @sections, $section
                    if @subsect || $section->description;
            }

            @sections || length $details->description
                or next;

            my $sections = join "\n", map "<li>".$self->link($manual, $_)."</li>", @sections;

            push @rows, $self->link($manual, $details, "Details in $manual")
              . qq[\n<ul>\n$sections</ul>\n]
        }
    }
    elsif($group eq 'MANUALS')
    {   @rows = map $self->link(undef, $_, $_->name), sort $select->($self->manuals);
    }
    else
    {   error __x"unknown group {name} as list attribute", name => $group;
    }

    push @rows, ('') x ($columns-1);
    my $rows   = int(@rows/$columns);

    my $output = qq[<tr>];
    while(@rows >= $columns)
    {   $output .= qq[<td valign="top">]
                . join( "<br>\n", splice(@rows, 0, $rows))
                .  qq[</td>\n];
    }
    $output   .= qq[</tr>\n];
    $output;
}

=method templateList $templ, $attrs, $if, $else

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

=warning no meaning for container $contained in index block
=error   illegal value to show_sections: $show_sec

=cut

sub templateList($$)
{   my ($self, $templ, $attrs, $if, $else) = @_;
    warning __x"no meaning for container {c} in index block", c => $if
        if defined $if && length $if;

    my $group  = first { !/[a-z]/ } keys %$attrs;
    defined $group
        or error __x"no group named as attribute for list";

    my $show_sub = $attrs->{show_subroutines} || 'LIST';
    my $types    = $attrs->{subroutine_types} || 'ALL';
    my $manual   = $self->manual or panic;
    my $output   = '';

    my $selected = sub { @_ };
    unless($types eq 'ALL')
    {   my @take   = map { $_ eq 'method' ? '.*method' : $_ } split /[_|]/, $types;
        local $"   = ')|(?:';
        my $regexp = qr/^(?:@take)$/;
        $selected  = sub { grep $_->type =~ $regexp, @_ };
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
        my $show_sec = $attrs->{show_sections} || 'LINK';
        my @sections = $show_sec eq 'NO' ? () : $chapter->sections;

        my @subs = $sorted->(
            $selected->( @sections ? $chapter->subroutines : $chapter->all('subroutines'))
        );

        $output  .= $self->link($manual, $chapter, $chapter->niceName); 
        my $count = @subs && $show_sub eq 'COUNT' ? ' ('.@subs.')' : '';

        if($show_sec eq 'NO') { $output .= qq[$count<br>\n] }
        elsif($show_sec eq 'LINK' || $show_sec eq 'NAME')
        {   $output .= qq[<br>\n<ul>\n];
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
        {   error __x"illegal value to show_sections: {v}", v => $show_sec;
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

sub indexListSubroutines(@)
{   my $self   = shift;
    my $manual = shift;

    join ",\n", map $self->link($manual, $_, $_), @_;
}

1;
