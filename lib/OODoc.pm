
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
use List::Util 'first';

=chapter NAME

OODoc - object oriented production of code documentation

=chapter SYNOPSIS

 use OODoc;
 my $doc = OODoc->new(distribution => 'My Name', version => '0.02');
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

=option  project STRING
=default project <distribution>

A short description of the distribution, as will be shown on many places
in the produced manual pages and code.  You can use the main package name,
or something which is nicer to read.

=requires distribution STRING

The name of the package, as released on CPAN.

=option  verbose INTEGER
=default verbose 0

Verbosity during the process.  The higher the number, the more information
will be presented (current useful maximum is 4).

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

    $self->{O_pkg}    = {};

    my $distribution  = $self->{O_distribution} = delete $args->{distribution};
    croak "ERROR: the produced distribution needs a project description"
        unless defined $distribution;

    $self->{O_project} = delete $args->{project} || $distribution;

    my $version        = delete $args->{version};
    unless(defined $version)
    {   my $fn         = -f 'version' ? 'version'
                       : -f 'VERSION' ? 'VERSION'
                       : undef;
        if(defined $fn)
        {   my $v = IO::File->new($fn, 'r')
               or die "ERROR: Cannot read version from file $fn: $!\n";
            $version = $v->getline;
            chomp $version;
        }
    }

    croak "ERROR: no version specified for distribution \"$distribution\""
        unless defined $version;

    $self->{O_version} = $version;
    $self->{O_verbose} = delete $args->{verbose} || 0;
    $self;
}

#-------------------------------------------

=section Attributes

=method distribution

Returns the nice name for the distribution.

=cut

sub distribution() {shift->{O_distribution}}

#-------------------------------------------

=method version

Returns the version string for the distribution.

=cut

sub version() {shift->{O_version}}

#-------------------------------------------

=method project

Returns the general project description, by default the distribution name.

=cut

sub project() {shift->{O_project}}

#-------------------------------------------

=section Parser

=method selectFiles WHICH, LIST

Returns two array references: the first with files to process, and the second
with files which do not need to be processed.  WHICH comes from
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
      : croak "ERROR: use regex, code reference or array for file selection";

    return ($select, []) if ref $select eq 'ARRAY';

    my (@process, @copy);
    foreach my $fn (@_)
    {   if($select->($fn)) {push @process, $fn}
        else               {push @copy,    $fn}
    }

    ( \@process, \@copy );
}

#-------------------------------------------

=method processFiles OPTIONS

=requires workdir DIRECTORY

Specify the directory where the stripped pm-files and the pod files
will be written to.  Probably the whole distribution is collected on
that spot.

If you do not want to create a distribution, you may
specify C<undef> (still: you have to specify the option).  In this
case, only the documentation in the files is consumed, and no files
created.

=option  verbose INTEGER
=default verbose <from object>

Tell more about each stage of the processing.  The higher the number,
the more information you will get.

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

=option  parser CLASS|OBJECT
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
    my $verbose = defined $args{verbose} ? $args{verbose} : $self->{O_verbose};

    croak "ERROR: requires a directory to write the distribution to"
       unless exists $args{workdir};

    my $dest    = $args{workdir};
    my $source  = $args{source};
    my $distr   = $args{distribution} || $self->distribution;

    my $version = $args{version};
    unless(defined $version)
    {   my $fn  = defined $source ? File::Spec->catfile($source, 'version')
                :                   'version';
        $fn     = -f $fn          ? $fn
                : defined $source ? File::Spec->catfile($source, 'VERSION')
                :                   'VERSION';
        if(defined $fn)
        {   my $v = IO::File->new($fn, "r")
                or die "ERROR: Cannot read version from $fn: $!";
            $version = $v->getline;
            chomp $version;
        }
        elsif($version = $self->version) { ; }
        else
        {   die "ERROR: there is no version defined for the source files.\n";
        }
    }

    #
    # Split the set of files into those who do need special processing
    # and those who do not.
    #

    my $manfile
      = exists $args{manifest} ? $args{manifest}
      : defined $source        ? File::Spec->catfile($source, 'MANIFEST')
      :                          'MANIFEST';

    my $manifest = OODoc::Manifest->new(filename => $manfile);

    my $manout;
    if(defined $dest)
    {   my $manif = File::Spec->catfile($dest, 'MANIFEST');
        $manout   = OODoc::Manifest->new(filename => $manif);
        $manout->add($manif);
    }
    else
    {   $manout   = OODoc::Manifest->new(filename => undef);
    }

    my $select    = $args{select} || qr/\.(pm|pod)$/;
    my ($process, $copy) = $self->selectFiles($select, @$manifest);

    print @$process. " files to process and ".@$copy." files to copy\n"
       if $verbose > 1;

    #
    # Copy all the files which do not contain pseudo doc
    #

    if(defined $dest)
    {   foreach my $filename (@$copy)
        {   my $fn = defined $source ? File::Spec->catfile($source, $filename)
                   :                   $filename;

            my $dn = File::Spec->catfile($dest, $fn);
            next if -e $dn && ( -M $dn < -M $fn ) && ( -s $dn == -s $fn );

            $self->mkdirhier(dirname $dn);

            carp "WARNING: no file $fn to include in the distribution", next
               unless -f $fn;

            copy($fn, $dn)
               or die "ERROR: cannot copy distribution file $fn to $dest: $!\n";

            $manout->add($dn);
            print "Copied $fn to $dest\n" if $verbose > 2;
        }
    }

    #
    # Create the parser
    #

    my $parser = $args{parser} || 'OODoc::Parser::Markov';
    unless(ref $parser)
    {   eval "{require $parser}";
        croak "ERROR: Cannot compile $parser class:\n$@"
           if $@;

        $parser = $parser->new
           or croak "ERROR: Parser $parser could not be instantiated";
    }

    #
    # Now process the rest
    #

    foreach my $filename (@$process)
    {   my $fn = $source ? File::Spec->catfile($source, $filename) : $filename; 

        carp "WARNING: no file $fn to include in the distribution", next
            unless -f $fn;

        my $dn;
        if($dest)
        {   $dn = File::Spec->catfile($dest, $fn);
            $self->mkdirhier(dirname $dn);
            $manout->add($dn);
        }

        # do the stripping
        my @manuals = $parser->parse
            ( input        => $fn
            , output       => $dn
            , distribution => $distr
            , version      => $version
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

    #
    # load all distributions (which are not loaded yet)
    # simply ignore all errors.

    foreach my $manual (@manuals)
    {    next if $manual->isPurePod;
         eval "require $manual";
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

=option  select CODE|REGEXP
=default select C<undef>

Produce only the indicated manuals, which is useful in case of merging
manuals from different distributions.  When a REGEXP is provided, it
will be checked against the manual name.  The CODE reference will be
called with a manual as only argument.

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
          , project     => $self->distribution
          , version     => $self->version
          , @$options
          );
    }

    #
    # Create the manual pages
    #

    my $select = ! defined $args{select}     ? sub {1}
               : ref $args{select} eq 'CODE' ? $args{select}
               :                        sub { $_[0]->name =~ $args{select}};

    foreach my $package (sort $self->packageNames)
    {   foreach my $manual ($self->manualsForPackage($package))
        {   next unless $select->($manual);

            print "Creating manual $manual\n" if $verbose > 1;
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
    my $distribution   = $self->distribution;
    my $version  = $self->version;

    <<STATS;
$distribution version $version
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
distributions, but is much more needed when programs grow larger.

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

=section Getting Started

To use OODoc, you need to create a scripts which helps you producing
the distribution of your module.  The simpest script look like this:

 use OODoc;
 my $dist = '/tmp/abc';
 my $doc  = OODoc->new
  ( distribution => 'E-mail handling'
  , version       => '0.01'
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