
package OODoc;
use base 'OODoc::Object';

use strict;
use warnings;

use OODoc::Manifest;

use Carp;
use File::Copy;
use File::Spec;
use File::Basename;
use IO::File;

=chapter NAME

OODoc - object oriented production of code documentation

=chapter SYNOPSIS

 use OODoc;
 my $doc = OODoc->new(module => 'My Name', version => '0.02');
 $doc->processFiles(workdir => $dest);
 $doc->prepare;
 $doc->create('pod', workdir => $dest);
 $doc->create('html', workdir => '/tmp/html');

=chapter DESCRIPTION

OODoc stands for "Object Oriented Documentation".  The OO part refers
to two things: this module simplifies writing documentation for Object
Oriented programs, and at the same time, it is Object Oriented itself:
easily extensible.

OODoc is a rather new module, but is developed far enough to be
useful for most applications.  You have the possibility to modify
the output of the formatters to your taste using templates, although
it is not donfigurable in full extend.

Please contribute ideas.  Have a look at the main website of this
project at L<http://perl.overmeer.net/oodoc/>.

=cut

#-------------------------------------------

=chapter METHODS

=c_method new OPTIONS

=requires module STRING

The name of the module, as will be shown on many places in the produced
manual pages and code.  You can use the main package name, or something
which is nicer to read.

=option  verbose INTEGER
=default verbose 0

Verbosity during the process.  The higher the number, the more information
will be presented (current useful maximum is 4).

=requires version STRING

The version number as automatically included in all packages after
each package statement and on many places in the documentation.

=error the produced module needs a descriptive name

Every module needs a name, which will be used on many places in the
documentation.

=error no version specified for module "$name"

Version information will be added to all packages and all manual
pages.  You need to specify a version and be sure that it changes
with each release.

=cut

sub init($)
{   my ($self, $args) = @_;

    $self->SUPER::init($args) or return;

    $self->{O_pkg} = {};

    my $module = $self->{O_module} = delete $args->{module};
    croak "ERROR: the produced module needs a descriptive name"
        unless defined $module;

    my $version = $self->{O_version} = delete $args->{version};
    croak "ERROR: no version specified for module \"$module\""
        unless defined $version;

    $self->{O_verbose} = delete $args->{verbose} || 0;
    $self;
}

#-------------------------------------------

=section Attributes

=cut

#-------------------------------------------

=method module

Returns the nice name for the module.

=cut

sub module() {shift->{O_module}}

#-------------------------------------------

=method version

Returns the version string for the module.

=cut

sub version() {shift->{O_version}}

#-------------------------------------------

=section Parser

=cut

#-------------------------------------------

=method selectFiles WHICH, LIST

Returns two array references: the first with files to process, and the second
with files which do not need to be processed.  WHICH comes from
M<processFiles(select)> and the LIST are files from a manifest.

=error use regex, code reference or array for file selection

The M<processFiles(select)> option is not understood.  You may specify
an ARRAY, regular expression, or a code reference.

=warning no file $fn to include in the distribution

Probably your MANIFEST file lists this file which does not exist.  The file
will be skipped for now, but may cause problems later on.

=cut

sub selectFiles($@)
{   my ($self, $files) = (shift, shift);

    my $select
      = ref $files eq 'Regexp' ? sub { $_[0] =~ $files }
      : ref $files eq 'CODE'   ? $files
      : ref $files eq 'ARRAY'  ? $files
      : croak "ERROR: use regex, code reference or array for file selection";

    return ($select, []) if ref $select eq 'ARRAY';

    my (@process, @copy);
    foreach my $fn (@_)
    {   if(not $fn)
        {  carp "WARNING: no file $fn to include in the distribution" }
        elsif($select->($fn)) {push @process, $fn}
        else                  {push @copy,    $fn}
    }

    ( \@process, \@copy );
}

#-------------------------------------------

=method processFiles OPTIONS

=requires workdir DIRECTORY

=option  verbose INTEGER
=default verbose <from object>

Tell more about each stage of the processing.  The higher the number,
the more information you will get.

=option  manifest FILENAME
=default manifest 'MANIFEST'

The manifest file lists all files which belong to this module: packages,
pods, tests, etc.

=option  select ARRAY|REGEX|CODE
=default select qr/\.(pod|pm)$/

The files which contain documentation to be processed.  You can provide
a list of filenames as array reference, a REGEX which is used to select
names from the manifest file, or a CODE reference which is used to
select elements from the manifest (filename passed as first argument).
Is your pod real pod or should it also be passed through the parser?

=option  parser CLASS|OBJECT
=default parser 'OODoc::Parser::ExtendedPOD'

The parser CLASS or OBJECT to be used to process the pages.

=error Cannot compile $parser class

The $parser class does not exist or produces compiler errors.

=error Parser $parser could not be instantiated

Something went wrong while starting the parser object.  Probably there is
an other error message which will tell you the exact cause.

=error requires a directory to write the distribution to

You have to give a value to C<workdir>.
When processing the manifest file, some files must be copied directly
to a temporary directory.  The packages are first stripped from
their pseudo doc, and then written to the same directory.  That
directory will be the place where C<make dist> is run later.

=error cannot copy distribution file $fn to $dest: $!

For some reason, a plain file from can not be copied from your source
tree to the location where the distribution is made.

=cut

sub processFiles(@)
{   my ($self, %args) = @_;
    my $verbose = defined $args{verbose} ? $args{verbose} : $self->{O_verbose};

    my $dest    = $args{workdir}
       or croak "ERROR: requires a directory to write the distribution to";

    #
    # Split the set of files into those who do need special processing
    # and those who do not.
    #

    my $manfile  = exists $args{manifest} ? $args{manifest} : 'MANIFEST';
    my $manifest = OODoc::Manifest->new(filename => $manfile);

    my $select   = $args{select} || qr/\.(pm|pod)$/;
    my ($process, $copy) = $self->selectFiles($select, @$manifest);

    print @$process. " files to process and ".@$copy." files to copy\n"
       if $verbose > 1;

    #
    # Copy all the files which do not contain pseudo doc
    #

    foreach my $fn (@$copy)
    {   my $dn = File::Spec->catfile($dest, $fn);
        next if -e $dn && ( -M $dn < -M $fn ) && ( -s $dn == -s $fn );

        $self->mkdirhier(dirname $dn);

        copy($fn, $dn)
           or die "ERROR: cannot copy distribution file $fn to $dest: $!\n";

        print "Copied $fn to $dest\n" if $verbose > 2;
    }

    #
    # Create the parser
    #

    my $parser = $args{parser} || 'OODoc::Parser::Markov';
    unless(ref $parser)
    {   eval "require $parser";
        croak "ERROR: Cannot compile $parser class:\n$@"
           if $@;

        $parser = $parser->new
           or croak "ERROR: Parser $parser could not be instantiated";
    }

    #
    # Now process the rest
    #

    foreach my $fn (@$process)
    {   my $dn = File::Spec->catfile($dest, $fn);
        $self->mkdirhier(dirname $dn);

        # do the stripping
        my @manuals = $parser->parse
            ( input    => $fn
            , output   => $dn
            , version  => $self->version
            , manifest => $manfile
            );

        if($verbose > 2)
        {   print "Stripped $fn into $dn\n";
            print $_->stats foreach @manuals;
        }

        $self->addManual($_) foreach @manuals;
    }

    #
    # Some general subtotals
    #

    print $self->stats if $verbose > 1;
    $self;
}

#-------------------------------------------

=section Preparation

=cut

#-------------------------------------------

=method prepare OPTIONS

Add information to the documentation tree about inheritance relationships
of the packages.  C<prepare> must be called between M<processFiles()>
and M<create()>.

=option  verbose INTEGER
=default verbose <from object>

=cut

sub prepare(@)
{   my ($self, %args) = @_;
    my $verbose = defined $args{verbose} ? $args{verbose} : $self->{O_verbose};

    print "Collect package relations.\n" if $verbose >1;
    $self->getPackageRelations;

    print "Expand manual contents.\n" if $verbose >1;
    $self->expandManuals;

    $self;
}

#-------------------------------------------

=method getPackageRelations

Compile all files which contain packages, and then try to find-out
how they are related.

=error problems compiling $code for package $name: $@

Syntax error in your code, or a problem caused by stripping the file.
You can run your test-scripts before the files get stripped as long
as you do not use C<make test>, because that will try to produce
manual-pages as well...

=cut

sub getPackageRelations()
{   my $self     = shift;
    my @manuals  = $self->manuals;  # all

    my @sources  = map {$_->source} @manuals;

    foreach my $fn (@sources)
    {    next unless $fn =~ m/\.pm$/;
         eval { require $fn };
         die "ERROR: problems compiling $fn:\n$@"
           if $@;
    }

    foreach my $manual (@manuals)
    {
        if($manual->name ne $manual->package)  # autoloaded code
        {   my $main = $self->mainManual("$manual");
            $main->extraCode($manual) if defined $main;
            next;
        }
        my %uses = $manual->collectPackageRelations;

        foreach (defined $uses{isa} ? @{$uses{isa}} : ())
        {   my $isa = $self->mainManual($_) || $_;

            $manual->superClasses($isa);
            $isa->subClasses($manual) if ref $isa;
        }

        if(my $realizes = $uses{realizes})
        {   my $to  = $self->mainManual($realizes) || $realizes;

            $manual->realizes($to);
            $to->realizers($manual) if ref $to;
        }
    }

    $self;
}

#-------------------------------------------

=method expandManuals

Take all manuals, and fill them with the info all the super classes.  Some
of this data may actually be used when formatting the manual into pages.

=cut

sub expandManuals() { $_->expand foreach shift->manuals }

#-------------------------------------------

=section Formatter

=cut

#-------------------------------------------

=method create NAME|CLASS|OBJECT, OPTIONS

Create a manual for the set of manuals read so far.  The manuals are
produced by different formatters which produce one page at a time.
Returned is the formatter which is used: it may contain useful information
for you.

The first, optional argument specifies the type of pages to be produced.
This can be either a predefined NAME (currently available are C<pod>
and C<html> representing M<OODoc::Format::Pod> and M<OODoc::Format::Html>
respectively), the name of a CLASS which needs to be instantiated,
or an instantiated formatter.

=option  verbose INTEGER
=default verbose 0

Debug level, the higher the number, the more details about the process
you will have.

=requires workdir DIRECTORY

The directory where the output is going to.

=option  format_options ARRAY
=default format_options []

Formatter dependent initialization options.  See the documentation of
the formatter which will be used for the possible values.

=option  manual_format ARRAY
=default manual_format []

Options passed to M<OODoc::Format::createManual(format_options)> when
a manual page has to be produced.  See the applicable formatter
manual page for the possible flags and values.

=option  manifest FILENAME|undef
=default manifest <workdir>/MANIFEST

The names of the produced files are appended to this file.  When undef
is given, no file will be written for this.

=option  append STRING|CODE
=default append C<undef>

The value is passed on to M<OODoc::Format::createManual(append)>,
but the behavior is formatter dependent.

=option  manual_template LOCATION
=default manual_template C<undef>

Passed to M<OODoc::Format::createManual(template)>, and defines the
location of the set of pages which has to be created for each manual
page.  Some formatters do not support templates and the valid values
are formatter dependent.

=option  other_files DIRECTORY
=default other_files C<undef>

Other files which have to be copied
passed to M<OODoc::Format::createOtherPages(source)>.

=option  process_files REGEXP
=default process_files <formatter dependent>

Selects the files which are to be processed for special markup information.
Other files, like image files, will be simply copied.  The value will be
passed to M<OODoc::Format::createOtherPages(process)>.

=error formatter $name has compilation errors: $@

The formatter which is specified does not compile, so can not be used.

=error requires a directory to write the manuals to

You have to give a value to C<workdir>, which will be used as top directory
for the produced output.  It does not matter whether there is already some
stuff in that directory.

=cut

our %formatters =
 ( pod  => 'OODoc::Format::Pod'
 , pod2 => 'OODoc::Format::Pod2'
 , html => 'OODoc::Format::Html'
 );

sub create($@)
{   my ($self, $format, %args) = @_;
    my $verbose = defined $args{verbose} ? $args{verbose} : $self->{O_verbose};

    my $dest    = $args{workdir}
       or croak "ERROR: requires a directory to write the manuals to";

    #
    # Start manifest
    #

    my $manfile  = exists $args{manifest} ? $args{manifest}
                 : File::Spec->catfile($dest, 'MANIFEST');
    my $manifest = OODoc::Manifest->new(filename => $manfile);

    # Create the formatter

    unless(ref $format)
    {   $format = $formatters{$format} if exists $formatters{$format};
        eval "require $format";
        die "ERROR: formatter $format has compilation errors: $@" if $@;
        my $options    = delete $args{format_options} || [];

        $format = $format->new
          ( manifest    => $manifest
          , workdir     => $dest
          , project     => $self->module
          , version     => $self->version
          , @$options
          );
    }

    #
    # Create the manual pages
    #

    foreach my $package (sort $self->packageNames)
    {   foreach my $manual ($self->manualsForPackage($package))
        {   print "Creating manual $manual for $package\n" if $verbose > 1;
            $format->createManual
             ( manual   => $manual
             , template => $args{manual_template}
             , append         => $args{append}
             , format_options => ($args{manual_format} || [])
             );
        }
    }

    #
    # Create other pages
    #

    print "Creating other pages\n" if $verbose > 1;
    $format->createOtherPages
     ( source   => $args{other_files}
     , process  => $args{process_files}
     );

    $format;
}

#-------------------------------------------

=method stats

Returns a string which contains some statistics about the whole parsed
document set.

=cut

sub stats()
{   my $self = shift;
    my @manuals  = $self->manuals;
    my $manuals  = @manuals;
    my $realpkg  = $self->packageNames;

    my $subs     = map {$_->subroutines} @manuals;
    my $examples = map {$_->examples}    @manuals;

    my $diags    = map {$_->diagnostics} @manuals;
    my $module   = $self->module;
    my $version  = $self->version;

    <<STATS;
$module version $version
  Number of package manuals: $manuals
  Real number of packages:   $realpkg
  documented subroutines:    $subs
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
larger programs, you start seeing the weaker sites of POD.

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
modules, but is much more needed when programs grow larger.

=section How does OODoc work

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
Within one module, different files can be parsed by different parsers.

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

=section Getting Started

To use OODoc, you need to create a scripts which helps you producing
the distribution of your module.  The simpest script look like this:

 use OODoc;
 my $dist = '/tmp/abc';
 my $doc  = OODoc->new
  ( module     => 'E-mail handling'
  , version    => '0.01'
  );

 $doc->processFiles(workdir => $dist);  # parsing
 $doc->prepare;                         # collecting
 $doc->create('pod', workdir => $dist); # formatting to POD

The default parser will be used to process the files, see
M<OODoc::Parser::Markov> for its syntax.  The formatter is
described in M<OODoc::Format::Pod>.

Once you have this working, you may decide to add options to the
calls to adapt the result more to your own taste.

=cut

1;
