# This code is part of perl distribution OODoc.  It is licensed under the
# same terms as Perl itself: https://spdx.org/licenses/Artistic-2.0.html

package OODoc;
use parent 'OODoc::Object';

use strict;
use warnings;

our $VERSION = '3.00';  # needed here for own release process

use Log::Report    'oodoc';

use OODoc::Manifest ();
use OODoc::Format   ();

use File::Spec      qw/catfile/;   sub catfile(@);
use IO::File        ();
use File::Copy      qw/copy move/;
use File::Basename  qw/dirname/;
use List::Util      qw/first/;
use Scalar::Util    qw/blessed/;

=chapter NAME

OODoc - object oriented production of software documentation

=chapter SYNOPSIS

 use OODoc;
 my $doc = OODoc->new(distribution => 'My Name', version => '0.02');
 $doc->processFiles(workdir => $dest);
 $doc->prepare;
 $doc->formatter('pod', workdir => $dest)->createPages;
 $doc->formatter('html', workdir => '/tmp/html')->createPages;

or use the oodist script

=chapter DESCRIPTION

OODoc stands for "Object Oriented Documentation": to produce better
manual-pages in HTML or perl POD format than the standard offerings
of the Perl tool-chain.

The OO part of the name refers to two things: this module simplifies
writing documentation for Object Oriented programs, and, at the same time,
it is Object Oriented itself: easily extensible.

Before you read any further, decide:

=over 4
=item 1
Write your own wrapper around the OODoc module; or

=item 2
use script C<oodist>, which manages your whole distribution process
configured by your Makefile.PL.
=back

OODoc has been used for small and for very large sets of modules, like
the MailBox suite.  It can also be used to integrate manual-pages from
many modules into one homogeneous set.

The documentation syntax can be changed, by configuring the
provided parser or adding a new one.  The M<OODoc::Parser::Markov>
parser understands POD and has many additional logical markup tags.
See M<OODoc::Parser> about what each parser needs to support.

The output is produced by formatters and exporteds.  The current
implementation contains three POD formatters and one HTML formatter,
and a JSON exporter.  See M<OODoc::Format> and M<OODoc::Export>.

Do not forget to B<read> the L<DETAILS> section later on this manual-page to
get started.  Please contribute ideas.  Have a look at the main website
of this project at L<http://perl.overmeer.net/oodoc/>.  That is also an
example of the produced html output.

=chapter METHODS

=c_method new %options

=option  project STRING
=default project <distribution>
A short description of the distribution, as will be shown on many places
in the produced manual pages and code.  You can use the main package name,
or something which is nicer to read.

=requires distribution STRING
The name of the package, as released on CPAN.

=option  version STRING
=default version <from version or VERSION file>
The version number as automatically included in all packages after
each package statement and on many places in the documentation. By
default the current directory is searched for a file named C<version>
or C<VERSION> which contains a number.

=error the destribution must be specified

=error no version specified for distribution "$name"
Version information will be added to all packages and all manual
pages.  You need to specify a version and be sure that it changes
with each release, or create a file named C<version> or C<VERSION>
which contains that data.

=error Cannot read version from file $fn: $!

=cut

sub init($)
{   my ($self, $args) = @_;

    $self->SUPER::init($args) or return;

    $self->{O_pkg}     = {};

    my $distribution   = $self->{O_distribution} = delete $args->{distribution};
    defined $distribution
        or error __x"the produced distribution needs a project description";

    $self->{O_project} = delete $args->{project} || $distribution;

    my $version        = delete $args->{version};
    unless(defined $version)
    {   my $fn         = -f 'version' ? 'version'
                       : -f 'VERSION' ? 'VERSION'
                       : undef;
        if(defined $fn)
        {   my $v = IO::File->new($fn, 'r')
                or fault __x"cannot read version from file {file}", file=> $fn;
            $version = $v->getline;
            $version = $1 if $version =~ m/(\d+\.[\d\.]+)/;
            chomp $version;
        }
    }

    $self->{O_version} = $version
        or error __x"no version specified for distribution '{dist}'", dist  => $distribution;

    $self;
}

#-------------------------------------------
=section Attributes

=method distribution 
Returns the nice name for the distribution.
=cut

sub distribution() {shift->{O_distribution}}

=method version 
Returns the version string for the distribution.
=cut

sub version() {shift->{O_version}}

=method project 
Returns the general project description, by default the distribution name.
=cut

sub project() {shift->{O_project}}

#-------------------------------------------
=section Parser

=method selectFiles $which, LIST

Returns two array references: the first with files to process, and the second
with files which do not need to be processed.  $which comes from
M<processFiles(select)> and the LIST are files from a manifest.

=error use regex, code reference or array for file selection
The M<processFiles(select)> option is not understood.  You may specify
an ARRAY, regular expression, or a code reference.

=cut

sub selectFiles($@)
{   my ($self, $files) = (shift, shift);

    my $select
      = ref $files eq 'Regexp' ? sub { $_[0] =~ $files }
      : ref $files eq 'CODE'   ? $files
      : ref $files eq 'ARRAY'  ? $files
      :     error __x"use regex, code reference or array for file selection";

    return ($select, [])
        if ref $select eq 'ARRAY';

    my (@process, @copy);
    foreach my $fn (@_)
    {   if($select->($fn)) { push @process, $fn }
        else               { push @copy,    $fn }
    }

    ( \@process, \@copy );
}

=method processFiles %options

=requires workdir DIRECTORY
Specify the directory where the stripped pm-files and the pod files
will be written to.  Probably the whole distribution is collected on
that spot.

If you do not want to create a distribution, you may
specify C<undef> (still: you have to specify the option).  In this
case, only the documentation in the files is consumed, and no files
created.

=option  manifest FILENAME
=default manifest <source/>'MANIFEST'
The manifest file lists all files which belong to this distribution: packages,
pods, tests, etc. before the new pod files are created.

=option  select ARRAY|REGEX|CODE
=default select qr/\.(pod|pm)$/
The files which contain documentation to be processed.  You can provide
a list of filenames as array reference, a REGEX which is used to select
names from the manifest file, or a CODE reference which is used to
select elements from the manifest (filename passed as first argument).
Is your pod real pod or should it also be passed through the parser?

=option  source DIRECTORY
=default source C<'.'>
The location where the files are located.  This is useful when you collect
the documentation of other distributions into the main one.  Usually in
combination with an undefined value for C<workdir>.

=option  parser CLASS|$name|OBJECT
=default parser M<OODoc::Parser::Markov>
The parser CLASS or OBJECT to be used to process the pages.

=option  distribution NAME
=default distribution <from main OODoc object>
Useful when more than one distribution is merged into one set of
documentation.

=option  version STRING
=default version <from source directory or OODoc object>
The version of the distribution.  If not specified, the C<source>
directory is scanned for a file named C<version> or C<VERSION>. The
content is used as version value.  If these do not exist, then the
main OODoc object needs to provide the version.

To make C<Makefile.PL> option C<VERSION_FROM> to work with this
seperate version file, that line should contain C<$VERSION = >.

=option  notice STRING
=default notice ''
Include the string (which may consist of multiple lines) to each of the
pm files.  This notice usually contains the copyright message.

=option  skip_links ARRAY|STRING|REGEXP
=default skip_links []
Passed to M<OODoc::Parser::new(skip_links)>.

=error Cannot compile $parser class
The $parser class does not exist or produces compiler errors.

=error Parser $parser could not be instantiated
Something went wrong while starting the parser object.  Probably there is
an other error message which will tell you the exact cause.

=error requires a directory to write the distribution to
You have to give a value to C<workdir>, which may be C<undef>.  This
option is enforced to avoid the accidental omission of the parameter.

When processing the manifest file, some files must be copied directly
to a temporary directory.  The packages are first stripped from
their pseudo doc, and then written to the same directory.  That
directory will be the place where C<make dist> is run later.

=error cannot copy distribution file $fn to $dest: $!
For some reason, a plain file from can not be copied from your source
tree to the location where the distribution is made.

=warning no file $fn to include in the distribution
Probably your MANIFEST file lists this file which does not exist.  The file
will be skipped for now, but may cause problems later on.

=error there is no version defined for the source files
Each manual will need a version number.  There are various ways to
specify one.  For instance, create a file named C<version> or C<VERSION>
in the top source directory of your distribution, or specify a version
as argument to M<OODoc::new()> or M<OODoc::processFiles()>.

=cut

sub processFiles(@)
{   my ($self, %args) = @_;

    exists $args{workdir}
        or error __x"requires a directory to write the distribution to";

    my $dest    = $args{workdir};
    my $source  = $args{source};
    my $distr   = $args{distribution} || $self->distribution;

    my $version = $args{version};
    unless(defined $version)
    {   my $fn  = defined $source ? catfile($source, 'version') : 'version';
        $fn     = -f $fn          ? $fn
                : defined $source ? catfile($source, 'VERSION')
                :                   'VERSION';
        if(defined $fn)
        {   my $v = IO::File->new($fn, "r")
                or fault __x"cannot read version from {file}", file => $fn;
            $version = $v->getline;
            $version = $1 if $version =~ m/(\d+\.[\d\.]+)/;
            chomp $version;
        }
        elsif($version = $self->version) { ; }
        else
        {   error __x"there is no version defined for the source files";
        }
    }

    my $notice = '';
    if($notice = $args{notice})
    {   $notice =~ s/^(\#\s)?/# /mg;       # put comments if none
    }

    #
    # Split the set of files into those who do need special processing
    # and those who do not.
    #

    my $manfile
      = exists $args{manifest} ? $args{manifest}
      : defined $source        ? catfile($source, 'MANIFEST')
      :                          'MANIFEST';

    my $manifest = OODoc::Manifest->new(filename => $manfile);

    my $manout;
    if(defined $dest)
    {   my $manif = catfile($dest, 'MANIFEST');
        $manout   = OODoc::Manifest->new(filename => $manif);
        $manout->add($manif);
    }
    else
    {   $manout   = OODoc::Manifest->new(filename => undef);
    }

    my $select    = $args{select} || qr/\.(pm|pod)$/;
    my ($process, $copy) = $self->selectFiles($select, @$manifest);

    trace @$process." files to process and ".@$copy." files to copy";

    #
    # Copy all the files which do not contain pseudo doc
    #

    if(defined $dest)
    {   foreach my $filename (@$copy)
        {   my $fn = defined $source ? catfile($source, $filename) : $filename;

            my $dn = catfile($dest, $fn);
            unless(-f $fn)
            {   warning __x"no file {file} to include in the distribution", file => $fn;
                next;
            }

            unless(-e $dn && ( -M $dn < -M $fn ) && ( -s $dn == -s $fn ))
            {   $self->mkdirhier(dirname $dn);

                copy $fn, $dn
                    or fault __x"cannot copy distribution file {from} to {to}", from => $fn, to => $dest;

                trace "  copied $fn to $dest";
            }

            $manout->add($dn);
        }
    }

    #
    # Create the parser
    #

    my $parser = $args{parser} || 'OODoc::Parser::Markov';
	$parser    = 'OODoc::Parser::Markov' if $parser eq 'markov';

    unless(blessed $parser)
    {   eval "require $parser";
        $@ and error __x"cannot compile {pkg} class: {err}", pkg => $parser, err => $@;

        $parser = $parser->new(skip_links => delete $args{skip_links})
            or error __x"parser {name} could not be instantiated", name=> $parser;
    }

    #
    # Now process the rest
    #

    foreach my $filename (@$process)
    {   my $fn = $source ? catfile($source, $filename) : $filename; 

        unless(-f $fn)
        {   warning __x"no file {file} to include in the distribution", file => $fn;
            next;
        }

        my $dn;
        if($dest)
        {   $dn = catfile($dest, $fn);
            $self->mkdirhier(dirname $dn);
            $manout->add($dn);
        }

        # do the stripping
        my @manuals = $parser->parse
          ( input        => $fn
          , output       => $dn
          , distribution => $distr
          , version      => $version
          , notice       => $notice
          );

        trace "stripped $fn into $dn" if defined $dn;
        trace $_->stats for @manuals;

        foreach my $man (@manuals)
        {   $self->addManual($man) if $man->chapters;
        }
    }

    # Some general subtotals
    trace $self->stats;

    $self;
}

#-------------------------------------------
=section Preparation

=method prepare %options
Add information to the documentation tree about inheritance relationships
of the packages.  C<prepare> must be called between M<processFiles()>
and M<create()>.
=cut

sub prepare(@)
{   my ($self, %args) = @_;

    info "collect package relations";
    $self->getPackageRelations;

    info "expand manual contents";
    foreach my $manual ($self->manuals)
    {   trace "  expand manual $manual";
        $manual->expand;
    }

    info "Create inheritance chapters";
    foreach my $manual ($self->manuals)
    {    next if $manual->chapter('INHERITANCE');

         trace "  create inheritance for $manual";
         $manual->createInheritance;
    }

    $self;
}

=method getPackageRelations 
Compile all files which contain packages, and then try to find-out
how they are related.

=error problems compiling $code for package $name: $@
Syntax error in your code, or a problem caused by stripping the file.
You can run your test-scripts before the files get stripped as long
as you do not use C<make test>, because that will try to produce
manual-pages as well...

=cut

sub getPackageRelations($)
{   my $self    = shift;
    my @manuals = $self->manuals;  # all

    #
    # load all distributions (which are not loaded yet)
    #

    info "compile all packages";

    foreach my $manual (@manuals)
    {    next if $manual->isPurePod;
         trace "  require package $manual";

         eval "require $manual";
         warning __x"errors from {manual}: {err}", manual => $manual, err =>$@
             if $@ && $@ !~ /can't locate/i && $@ !~ /attempt to reload/i;
    }

    info "detect inheritance relationships";

    foreach my $manual (@manuals)
    {
        trace "  relations for $manual";

        if($manual->name ne $manual->package)  # autoloaded code
        {   my $main = $self->mainManual("$manual");
            $main->extraCode($manual) if defined $main;
            next;
        }
        my %uses = $manual->collectPackageRelations;

        foreach (defined $uses{isa} ? @{$uses{isa}} : ())
        {   my $isa = $self->mainManual($_) || $_;

            $manual->superClasses($isa);
            $isa->subClasses($manual) if blessed $isa;
        }

        if(my $realizes = $uses{realizes})
        {   my $to  = $self->mainManual($realizes) || $realizes;

            $manual->realizes($to);
            $to->realizers($manual) if blessed $to;
        }
    }

    $self;
}

#-------------------------------------------
=section Main entries

=method formatter $name|$class|$object, %options
[2.03] Create a manual for the set of manuals read so far.  The manuals are
produced by different formatters which produce one page at a time.
Returned is the formatter which is used: it may contain useful information
for you.

The first, optional argument specifies the type of pages to be produced.
This can be either a predefined $name (currently available are C<pod>
and C<html> representing M<OODoc::Format::Pod> and M<OODoc::Format::Html>
respectively), the name of a $class which needs to be instantiated,
or an instantiated formatter.

You can also pass many options which are passed to M<OODoc::Format::createPages()>

=requires workdir DIRECTORY
The directory where the output is going to.

=option  manifest FILENAME|undef
=default manifest <workdir>/MANIFEST
The names of the produced files are appended to this file.  When undef
is given, no file will be written for this.

=error formatter requires a directory to write the manuals to
You have to give a value to C<workdir>, which will be used as top directory
for the produced output.  It does not matter whether there is already some
stuff in that directory.

=cut

sub formatter($@)
{   my ($self, $format, %args) = @_;

    my $dest     = delete $args{workdir}
       or error __x"formatter() requires a directory to write the manuals to";

    # Start manifest

    my $manfile  = delete $args{manifest} // catfile($dest, 'MANIFEST');
    my $manifest = OODoc::Manifest->new(filename => $manfile);

    # Create the formatter

    return $format
        if blessed $format && $format->isa('OODoc::Format');

    OODoc::Format->new(
        %args,
        format      => $format,
        manifest    => $manifest,
        workdir     => $dest,
        project     => $self->distribution,
        version     => $self->version,
    );
}

sub create() { panic 'Interface change in 2.03: use $oodoc->formatter->createPages' }

=method export %options
Convert the documentation data in a beautiful tree.

=requires exporter M<OODoc::Export>-object
Manages the conversion from source markup for text into the requested
markup (f.i. "markov" into "html").

=option  podtail POD
=default podtail C<undef>
The last chapters of any produced manual page, in POD syntax.

=option  manuals ARRAY
=default manuals C<undef>
Include only information for the manuals (specified as names).

=option  meta HASH
=default meta C<+{ }>
Key/string pairs with interesting additional data.
=cut

sub export($$%)
{    my ($self, %args) = @_;
    my $exporter    = $args{exporter} or panic;

    my $selected_manuals = $args{manuals};
    my %need_manual = map +($_ => 1), @{$selected_manuals || []};
    my @podtail_chapters = $exporter->podChapters($args{podtail});

    my %man;
    foreach my $package (sort $self->packageNames)
    {
        foreach my $manual ($self->manualsForPackage($package))
        {   !$selected_manuals || $need_manual{$manual} or next;
            my $man = $manual->publish(%args) or next;

            push @{$man->{chapters}}, @podtail_chapters;
            $man{$manual->name} = $man;
        }
    }

    my $meta = $args{meta} || {};
    my %meta = map +($_ => $exporter->plainText($meta->{$_}) ), keys %$meta;

     +{
        distribution => $exporter->plainText($self->distribution),
        version      => $exporter->plainText($self->version),
        project      => $exporter->plainText($self->project),
        manuals      => \%man,
        meta         => \%meta,
      };
}


=method stats 
Returns a string which contains some statistics about the whole parsed
document set.
=cut

sub stats()
{   my $self = shift;
    my @manuals  = $self->manuals;
    my $manuals  = @manuals;
    my $realpkg  = $self->packageNames;

    my $subs     = map $_->subroutines, @manuals;
    my @options  = map { map $_->options, $_->subroutines } @manuals;
    my $options  = scalar @options;
    my $examples = map $_->examples,    @manuals;

    my $diags    = map $_->diagnostics, @manuals;
    my $distribution   = $self->distribution;
    my $version  = $self->version;

    <<STATS;
$distribution version $version
  Number of package manuals: $manuals
  Real number of packages:   $realpkg
  documented subroutines:    $subs
  documented options:        $options
  documented diagnostics:    $diags
  shown examples:            $examples
STATS
}

#-------------------------------------------
=section Commonly used functions

=chapter DETAILS

=section Why use OODoc in stead of POD

POD (Perl's standard Plain Old Document format) has a very simple
syntax.  POD is very simple to learn, and the produced manual pages
look like normal Unix manual pages.  However, when you start writing
larger programs, you start seeing the weaker sides of POD.

One of the main problems with POD is that is using a visual markup
style: you specify information by how it must be presented to the
viewer.  This in contrast with logical markup where you specify the
information more abstract, and a visual representation is created by
translation.  For instance in HTML defines a C<I > tag (visual markup
italic) and C<EM> (logical markup emphasis, which will usually show
as italic).

The main disadvantage of visual markup is lost information: the
formatter of the manual page can not help the author of the documentation
to produce more consistent manual pages.  This is not a problem for small
distributions, but is much more needed when programs grow larger.

=section How OODoc works

Like with POD, you simply mix your documentation with your code.  When
the module is distributed, this information is stripped from the files
by a I<parser>, and translated into an object tree.  This tree is then
optimized: items combined, reorganized, etc, to collect all information
required to produce useable manual pages.  Then, a I<formatter> is called
to generate the manual pages.

=subsection The parser

The parser reads the package files, and (by default) strip them from all
documentation.  The stripped files are written to a temporary directory
which is used to create the module distribution.

It is possible to use more than one parser for your documentation.  On
this moment, there is only one parser implemented: the Markov parser,
named after the author.  But you can add your own parser, if you want to. 
Within one distribution, different files can be parsed by different parsers.

The parser produces an object tree, which is a structured representation of
the documentation.  The tree is parser independent, and organized by
manual page.

=subsection Collecting relations

The second phase of the manual page generation process figures out the
relations between the manual pages.  It collects inheritance relations
and other organizational information which is to be used by the
manual page generators.

=subsection The formatter

The final phase can be called more than once: based on the same object
tree, documents can be produced in various formats.  The initial
implementation produces POD and HTML.

=section Getting Started from scratch

To use OODoc, you need to create a scripts which helps you producing
the distribution of your module.  The simpest script look like this:

 use OODoc;
 my $dist = '/tmp/abc';
 my $doc  = OODoc->new
  ( distribution => 'E-mail handling'
  , version      => '0.01'
  );

 $doc->processFiles(workdir => $dist);  # parsing
 $doc->prepare;                         # collecting
 $doc->create('pod', workdir => $dist); # formatting to POD

The default parser will be used to process the files, see
M<OODoc::Parser::Markov> for its syntax.  The formatter is described
in M<OODoc::Format::Pod>.  Once you have this working, you may decide
to add options to the calls to adapt the result more to your own taste.

=section Getting Started by Cloning

A much easier way to start, is to simply pick one of the examples
which are distributed with OODoc.  They come in three sizes: for a
small module (mimetypes and orl), an average sized set-up (for OODoc
itself), and a huge one (mailbox, over 140 packages).

All examples are written by the same person, and therefore follow the
same set-up.  Copy the files C<mkdoc>, C<mkdist> and C<MANIFEST.extra>
plus the directory C<html> to the top directory of your distribution.
Edit all the files, to contain the name of your module.

It expects a C<MANIFEST> file to be present, like standard for Perl
modules.  That file lists your own code, pod and additional files
which need to be included in the release.  OODoc will extend this
file with produced POD files.

The demo-scripts use a C<version> file, which contains something like
C<< $VERSION = 0.1 >>.  This is not required: you can specify to
take a version from any file, in the traditional Perl way.  However,
when you glue multiple modules together into one big HTML documentation
website (see the mailbox example), then this separate file simplifies
the production script.

To test the document production,
try (on UNIX/Linux)  C<<pod2man xyz.pod | man -l - >>

To get a prepared distribution, use C<./mkdist 1>.  This will first
produce all documentation, and then run C<make test> and C<make dist>.
It generates two distributions: the C<module-version.tar.gz> which
can be uploaded to CPAN, and the C<module-version-raw.tar.gz> which
is for yourself.  The latter contains the whole setup which is used
to generate the distribution, so the unprocessed files!

=cut

1;
