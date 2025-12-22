#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package OODoc;
use parent 'OODoc::Object';

use strict;
use warnings;

our $VERSION = '3.05';  # needed here for own release process

use Log::Report    'oodoc';

use OODoc::Manifest ();
use OODoc::Format   ();
use OODoc::Index    ();

use File::Basename        qw/dirname/;
use File::Copy            qw/copy move/;
use File::Spec::Functions qw/catfile/;
use List::Util            qw/first/;
use Scalar::Util          qw/blessed reftype/;

#--------------------
=chapter NAME

OODoc - object oriented production of software documentation

=chapter SYNOPSIS

  use OODoc;
  my $doc = OODoc->new(distribution => 'My Name', version => '0.02');
  $doc->processFiles(workdir => $dest);
  $doc->finalize;
  $doc->formatter('pod', workdir => $dest)->createPages;
  $doc->formatter('html', workdir => '/tmp/html')->createPages;

or use the C<oodist> script, included in this distribution (advised).

=chapter DESCRIPTION

"OODoc" stands for "Object Oriented Documentation": to create better
manual-pages in HTML and Perl's POD format than produced by the standard
offerings of the Perl tool-chain.

Do not forget to B<read> the L</DETAILS> section (further down on this
manual-page) to get started.  Please contribute ideas.  Have a look at
the main website of this project at L<https://perl.overmeer.net/oodoc/>.
That is also an example of the produced html output (we are working on
nicer visuals)

=chapter METHODS

=c_method new %options
Create this general manager object.  When you use the C<oodist> script,
these parameters are read from the configuration in F<Makefile.PL>
(actually F<MYMETA.json>).

=option  project STRING
=default project $distribution
A short description of the $distribution, as will be shown on many places
in the produced manual pages and code.  You can use the main package name,
or something which is nicer to read.

=requires distribution STRING
The name of the package, as released on CPAN.

=option  version STRING
=default version <from version or VERSION file>
The version number as automatically included in all packages after
each package statement and on many places in the documentation. By
default the current directory is searched for a file named F<version>
or F<VERSION> which contains a number.

=error the produced distribution needs a project description

=error no version specified for distribution $dist
Version information will be added to all packages and all manual
pages.  You need to specify a version and be sure that it changes
with each release, or create a file named F<version> or F<VERSION>
which contains that data.

=fault cannot read distribution version from file $file: $!
=cut

sub init($)
{	my ($self, $args) = @_;

	$self->SUPER::init($args) or return;

	my $distribution   = $self->{O_distribution} = delete $args->{distribution}
		or error __x"the produced distribution needs a project description";

	$self->{O_project} = delete $args->{project} || $distribution;

	my $version        = delete $args->{version};
	unless(defined $version)
	{	my $fn         = -f 'version' ? 'version' : -f 'VERSION' ? 'VERSION' : undef;
		if(defined $fn)
		{	open my $v, '<:encoding(UTF-8)', $fn
				or fault __x"cannot read distribution version from file {file}", file=> $fn;
			$version = $v->getline;
			$version = $1 if $version =~ m/(\d+\.[\d\.]+)/;
			chomp $version;
		}
	}

	$self->{O_version} = $version
		or error __x"no version specified for distribution {dist}", dist  => $distribution;

	$self->{O_index}   = OODoc::Index->new;
	$self;
}

sub publish { panic }

#--------------------
=section Attributes

=method distribution
Returns the nice name for the distribution.
=cut

sub distribution() { $_[0]->{O_distribution} }

=method version
Returns the version string for the distribution.
=cut

sub version() { $_[0]->{O_version} }

=method project
Returns the general project description, by default the distribution name.
=cut

sub project() { $_[0]->{O_project} }

=method index
Returns the OODoc::Index which maintains the collected information.
=cut

sub index() { $_[0]->{O_index} }

#--------------------
=section Parser

=method selectFiles $filter, @files

Split the @files into two sets: the first with @files to process, and the second
with @files which do not need to be processed.  The selecting $filter comes from
M<processFiles(select)> and the @files are originally read from a F<MANIFEST>.
Returned are two ARRAY (references).

=error use regex, code reference or array for file selection, not $type
The M<processFiles(select)> option is not understood.  You may specify
an ARRAY, regular expression, or a CODE reference.

=cut

sub selectFiles($@)
{	my ($self, $filter, @files) = @_;

	my $ftype = reftype $filter;
	my $select
	  = $ftype eq 'REGEXP' ? sub { $_[0] =~ $filter }
	  : $ftype eq 'CODE'   ? $filter
	  : $ftype eq 'ARRAY'  ? $filter
	  :     error __x"use regex, code reference or array for file selection, not {type}", type => $ftype;

	return ($select, [])
		if reftype $select eq 'ARRAY';

	my (@process, @copy);
	foreach my $fn (@files)
	{	if($select->($fn)) { push @process, $fn }
		else               { push @copy,    $fn }
	}

	( \@process, \@copy );
}

=method processFiles %options
Extract the documentation from the selected files.

=option  workdir $directory
=default workdir undef
Specify the $directory where the stripped pm-files and the pod files
will be written to.  Probably the whole distribution is collected on
that spot.

When the processed files are not part of this distribution, then
then do not specify this option: knowledge is built, but not
included in the release.

=option  manifest $file
=default manifest "$source/MANIFEST"
The MANIFEST $file lists all files which belong to this distribution: packages,
pods, tests, etc. before the new pod files are created.

=option  select ARRAY|REGEX|CODE
=default select C<< qr/\.(pod|pm)$/ >>
The files which contain documentation to be processed.  You can provide
a list of filenames as array reference, a P<REGEX> which is used to select
names from the MANIFEST file, or a P<CODE> reference which is used to
select elements from the MANIFEST (filename passed as first argument).
Is your pod real pod or should it also be passed through the parser?

=option  source $directory
=default source C<'.'>
The location where the files are located.  This is useful when you collect
the documentation of other distributions into the main one.  Usually in
combination with an undefined value for P<workdir>.

=option  parser CLASS|$name|$parser
=default parser OODoc::Parser::Markov
The parser P<CLASS> or $parser object to be used to process the pages.

=option  distribution NAME
=default distribution <from main OODoc object>
Useful when more than one distribution is merged into one set of
documentation.

=option  version STRING
=default version <from source directory or OODoc object>
The version of the distribution.  If not specified, the P<source>
directory is scanned for a file named F<version> or F<VERSION>. The
content is used as version value.  If these do not exist, then the
main OODoc object needs to provide the version.

To make F<Makefile.PL> option C<VERSION_FROM> to work with this
seperate version file, that line should contain something like

  our $VERSION = 3.14;

=option  notice $text
=default notice C<''>
Include the $text (which may consist of multiple lines) to each of the
pm files.  This notice usually contains the copyright message.

=option  skip_links ARRAY|STRING|REGEXP
=default skip_links []
Passed to M<OODoc::Parser::new(skip_links)>.

=error cannot compile $pkg class: $err
The $pkg parser class does not exist or produces compiler errors.

=error parser $name could not be instantiated
Something went wrong while starting the parser object.  Probably there is
an other error message which will tell you the exact cause.

=error requires a directory to write the distribution to
You have to give a value to P<workdir>, which may be undef.  This
option is enforced to avoid the accidental omission of the parameter.

When processing the manifest file, some files must be copied directly
to a temporary directory.  The packages are first stripped from
their pseudo doc, and then written to the same directory.  That
directory will be the place where C<< make dist >> is run later.

=fault cannot read version from $file: $!
A $file named F<version> or F<VERSION> was found to contain the
distribution version, but not accessible.

=fault cannot copy distribution file $from to $to: $!
For some reason, a plain file can not be copied $from your source
tree $to the location where the distribution is made.

=warning no file $file to include in the distribution
Probably your MANIFEST file lists this $file which does not exist.
The $file will be skipped for now, but may cause problems later on.

=error there is no version defined for the source files
Each manual will need a version number.  There are various ways to
specify one.  For instance, create a file named F<version> or F<VERSION>
in the top source directory of your distribution, or specify a version
as argument to M<OODoc::new()> or M<OODoc::processFiles()>.
=cut

sub processFiles(@)
{	my ($self, %args) = @_;

	my $dest    = $args{workdir};
	my $source  = $args{source};
	my $distr   = $args{distribution} || $self->distribution;

	my $version = $args{version};
	unless(defined $version)
	{	my $fn  = defined $source ? catfile($source, 'version') : 'version';
		$fn     = -f $fn          ? $fn
				: defined $source ? catfile($source, 'VERSION')
				:                   'VERSION';
		if(defined $fn)
		{	open my $v, '<:encoding(UTF-8)', $fn
				or fault __x"cannot read version from {file}", file => $fn;
			$version = $v->getline;
			$version = $1 if $version =~ m/(\d+\.[\d\.]+)/;
			chomp $version;
		}
		elsif($version = $self->version) { ; }
		else
		{	error __x"there is no version defined for the source files";
		}
	}

	my $notice = '';
	if($notice = $args{notice})
	{	$notice =~ s/^([^#\n])/# $1/mg;       # put comments if none
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
	{	my $manif = catfile $dest, 'MANIFEST';
		$manout   = OODoc::Manifest->new(filename => $manif);
		$manout->add($manif);
	}
	else
	{	$manout   = OODoc::Manifest->new(filename => undef);
	}

	my $select    = $args{select} || qr/\.(pm|pod)$/;
	my ($process, $copy) = $self->selectFiles($select, @$manifest);

	trace @$process." files to process and ".@$copy." files to copy";

	#
	# Copy all the files which do not contain pseudo doc
	#

	if(defined $dest)
	{	foreach my $filename (@$copy)
		{	my $fn = defined $source ? catfile($source, $filename) : $filename;

			my $dn = catfile $dest, $fn;
			unless(-f $fn)
			{	warning __x"no file {file} to include in the distribution", file => $fn;
				next;
			}

			unless(-e $dn && ( -M $dn < -M $fn ) && ( -s $dn == -s $fn ))
			{	$self->mkdirhier(dirname $dn);

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

	unless(blessed $parser)
	{	$parser = 'OODoc::Parser::Markov' if $parser eq 'markov';

		eval "require $parser";
		$@ and error __x"cannot compile {pkg} class: {err}", pkg => $parser, err => $@;

		$parser = $parser->new(skip_links => delete $args{skip_links}, index => $self->index)
			or error __x"parser {name} could not be instantiated", name => $parser;
	}

	#
	# Now process the rest
	#

	foreach my $filename (@$process)
	{	my $fn = $source ? catfile($source, $filename) : $filename;

		-f $fn
			or warning(__x"no file {file} to include in the distribution", file => $fn), next;

		my $dn;
		if($dest)
		{	$dn = catfile $dest, $fn;
			$self->mkdirhier(dirname $dn);
			$manout->add($dn);
		}

		# do the stripping
		my @manuals = $parser->parse(
			input        => $fn,
			output       => $dn,
			distribution => $distr,
			version      => $version,
			notice       => $notice,
		);

		trace "stripped $fn into $dn" if defined $dn;
		trace $_->stats for @manuals;

		foreach my $man (@manuals)
		{	$self->index->addManual($man) if $man->chapters;
		}
	}

	$self;
}

#--------------------
=section Actions

=method finalize %options
[3.01] After all documentation fragments have been read via M<processFiles()>,
the pages need to be composed together.  For instance, inheritance and final
cleanups are due here.

=info * collect package relations
=info * expand manual contents
=info * create inheritance chapters
=info * finalize each manual
=cut

sub finalize(%)
{	my ($self, %args) = @_;

	info "* collect package relations";
	$self->getPackageRelations;

	my @manuals = $self->index->manuals;

	info "* expand manual contents";
	$_->expand for @manuals;

	info "* create inheritance chapters";
	$_->createInheritance for @manuals;

	info "* finalize each manual";
	$_->finalize(%args) for @manuals;

	$self;
}

sub prepare() { panic "OODoc 3.01 renamed prepare() into finalize." }

=method getPackageRelations
Compile all files which contain packages, and then try to find-out
how they are related.

=warning errors from $manual: $err
Syntax error in your code, or a problem caused by stripping the file.
You can run your test-scripts before the files get stripped as long
as you do not use C<make test>, because that will try to produce
manual-pages as well...

=info compiling all packages
=info detect inheritance relationships
=cut

sub getPackageRelations($)
{	my $self    = shift;
	my @manuals = $self->index->manuals;  # all

	info "compiling all packages";

	foreach my $manual (@manuals)
	{	next if $manual->isPurePod;
		trace "  require package $manual";

		eval "require $manual";
		warning __x"errors from {manual}: {err}", manual => $manual, err =>$@
			if $@ && $@ !~ /can't locate/i && $@ !~ /attempt to reload/i;
	}

	info "detect inheritance relationships";
	my $index = $self->index;

	foreach my $manual (@manuals)
	{
		trace "  relations for $manual";

		if($manual->name ne $manual->package)  # autoloaded code
		{	my $main = $index->mainManual("$manual");
			$main->extraCode($manual) if defined $main;
			next;
		}
		my %uses = $manual->collectPackageRelations;

		foreach (defined $uses{isa} ? @{$uses{isa}} : ())
		{	my $isa = $index->mainManual($_) || $_;

			$manual->superClasses($isa);
			$isa->subClasses($manual) if blessed $isa;
		}

		if(my $realizes = $uses{realizes})
		{	my $to  = $index->mainManual($realizes) || $realizes;

			$manual->realizes($to);
			$to->realizers($manual) if blessed $to;
		}
	}

	$self;
}

=method formatter $name|$class|$object, %options
[2.03] Create a manual for the set of manuals read so far.  The manuals are
produced by different formatters which produce one page at a time.
Returned is the formatter which is used: it may contain useful information
for you.

The first, optional argument specifies the type of pages to be produced.
This can be either a predefined $name (currently available are C<pod>
and C<html>, representing OODoc::Format::Pod and OODoc::Format::Html
respectively), the name of a $class which needs to be instantiated,
or an instantiated formatter $object.

You can also pass many options which are passed to (the effective extension
of) M<OODoc::Format::createPages()>.

=requires workdir $directory
The $directory where the output is going to.

=option  manifest FILENAME|undef
=default manifest P<workdir>/MANIFEST
The names of the produced files are appended to this file content.  When undef
is given, no file will be written for this.

=error formatter() requires a directory to write the manuals to
You have to provide a value to P<workdir>, which will be used as top directory
for the produced output.  It does not matter whether there is already some
stuff in that directory.

=cut

sub formatter($@)
{	my ($self, $format, %args) = @_;

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
		index       => $self->index,
	);
}

sub create() { panic 'Interface change in 2.03: use $oodoc->formatter->createPages' }

=method stats
Returns a string which contains some statistics about the whole parsed
document set.
=cut

sub stats()
{	my $self = shift;
	my @manuals  = $self->index->manuals;
	my $realpkg  = $self->index->packageNames;

	my $subs     = map $_->subroutines, @manuals;
	my @options  = map { map $_->options, $_->subroutines } @manuals;
	my $options  = scalar @options;
	my $examples = map $_->examples,    @manuals;
	my $diags    = map $_->diagnostics, @manuals;
	my $version  = $self->version;
	my $project  = $self->project;
	my $nr_mans  = @manuals;

	<<__STATS;
Project $project contains:
  Number of package manuals: $nr_mans
  Real number of packages:   $realpkg
  documented subroutines:    $subs
  documented options:        $options
  documented diagnostics:    $diags
  shown examples:            $examples
__STATS
}

=ci_method mkdirhier $directory
Creates this $directory and all its non-existing parents.

=fault cannot create $dir: $!
=cut

sub mkdirhier($)
{	my $thing = shift;
	my @dirs  = File::Spec->splitdir(shift);
	my $path  = $dirs[0] eq '' ? shift @dirs : '.';

	while(@dirs)
	{	$path = File::Spec->catdir($path, shift @dirs);
		-d $path || mkdir $path
			or fault __x"cannot create {dir}", dir => $path;
	}

	$thing;
}

#--------------------
=chapter DETAILS

=section OODoc

The "OO" part of the name refers to two things: this module simplifies
writing documentation for Object Oriented programs.  At the same time,
it is Object Oriented itself: easily extensible.  It can be used to
integrate manual-pages from many distributions into one homogeneous set.
OODoc has been used for small single package upto very large sets of
modules, like the MailBox suite.

=subsection Adding logical markup

POD (Perl's standard Plain Old Document format) has a very simple
syntax.  POD is very simple to learn, and the produced manual pages
look like standard Unix manual pages.  However, when you start writing
larger programs, you start seeing the weaker aspects of POD.

One of the main problems with POD is that is using a visual markup style:
you specify information by how it must be presented to the viewer.
This in contrast with logical markup where you specify the information
more abstract, and a visual representation is created by an application.
For instance, HTML defines an C<< <I> >> tag as visual markup Italic,
and C<< <EM> >> as logical markup for EMphasis, which will usually show
in italic.

The main disadvantage of visual markup is limited expression: the
formatter of the manual page can not help the author of the documentation
to produce more consistent and complete manual pages.  This is not a
problem for small distributions, but is much more needed when code
grows larger.

=subsection Application

This module can be used directly, but you may also use the C<oodist>
script which comes with this distribution.  That command will also help
you with your whole distribution release process.

The documentation syntax can be changed by configuring the provided
parser or adding a new one.  The OODoc::Parser::Markov parser
extends standard POD, which uses visual markup, with logical markup tags.

The output is produced by formatters and exporters.  The current
implementation contains three POD formatters, one HTML formatter,
and a JSON exporter.

=section How OODoc works

Like with POD, you simply mix your documentation with your code.  When
the module is distributed, this information is stripped from the files
by a I<parser>, and translated into an object tree.  This tree is then
optimized: items combined, reorganized, etc, to collect all information
required to produce useable manual pages.

Then, a I<formatter> is called to generate the manual pages in real
POD or HTML.  You may also use an I<exporter> to serialize that tree
(into JSON).

  My-Dist -------+                      +--formatter--> POD
  My-Other-Dist -|--parser--> DocTree --|--formatter--> HTML
  Even-More -----+                      +--exporter---> JSON/HTML

=subsection The parser

The parser reads the package files, and (by default) strips them from
all documentation fragments.  The stripped C<pm> files are written to
a temporary directory which is used to create the distribution release.
Existing C<pod> files will also be consumed, but published untouched.

The parser produces an object tree, which is a structured representation
of the documentation.  That tree is parser independent, and organized
by manual page.

It is possible to use more than one parser for your documentation.  On
this moment, there is only one parser implemented: the "Markov parser",
named after the author.  You can add your own parser, if you prefer to.
Within one distribution, different files may be parsed by different parsers.

=subsection collecting relations

The second phase of the manual page generation process figures out the
relations between the manual pages.  It collects inheritance relations
and other organizational information, which is to be used by the
manual page generators.

Links are being checked.  The Markov parser let you refer to subroutines
and even documented options within a sub.

Information of super-classes is merged: sections, methods, method options
and their defaults.  Methods are sorted by name per ((sub)sub)section.

=subsection formatter

The final phase can be called more than once: based on the same object
tree, documents can be produced in various formats.  The current
implementations produce POD and HTML.

More details in the OODoc::Format base-class.

=subsection exporters

You may also export the documentation tree to be used with your own
separate application.  At this moment, that dump will be made in JSON
with HTML-formatted text fragments only.

More details in the OODoc::Export base-class.

=section Release process

OODoc, as document generator, will need to be integrated into your
software release process.

=subsection do it yourself

To use OODoc, you need a script which helps you producing
the distribution of your module.  The simpest script looks like this:

  use OODoc;
  my $dist = '/tmp/abc';
  my $doc  = OODoc->new(
    distribution => 'E-mail handling',
    version      => '0.01',
  );

  $doc->processFiles(...);  # parsing
  $doc->finalize(...);      # collecting
  $doc->formatter('pod', ...)->createPages(...);
                            # formatting to POD

The default parser will be used to process the files, see
OODoc::Parser::Markov for its syntax.  The formatter is described
in OODoc::Format::Pod.  Once you have this working, you may decide
to add options to the calls to adapt the result more to your own taste.

=subsection use oodist

This distribution comes with a script named C<oodist>, which automates
most steps of your release process (to CPAN).  To start using OODoc with
your existing distribution, simply run this:

=over 4
=item 1. go to the root directory of your module
=item 2. run 'oodist'
=item 3. follow the instructions to configure oodist
=item 4. run 'oodist -v'
=back

This should take you more than a few minutes.  When the output looks fine,
then start playing with the advantages of the Markov extended POD syntax.

=subsection Checking the produced manual pages

To test the document production for C<My::Module>, try (on UNIX/Linux)

  pod2man $dist/lib/My/Module.pod | man -l -

=cut

1;
