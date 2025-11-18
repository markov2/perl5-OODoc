#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package OODoc::Parser;
use parent 'OODoc::Object';

use strict;
use warnings;

use Log::Report    'oodoc';

use List::Util     qw/first/;
use Scalar::Util   qw/reftype/;

our %syntax_implementation = (
	markov => 'OODoc::Parser::Markov',
);

#--------------------
=chapter NAME

OODoc::Parser - base class for all OODoc parsers.

=chapter SYNOPSIS

  # Never instantiated directly.

=chapter DESCRIPTION

A parser is used to process files which contain POD or contain code:
their filename extension is C<pod>, C<pm>, or C<pl> (actually, this
can be configured).

Currently distributed parsers:

=over 4
=item * OODoc::Parser::Markov (markov)
The Markov parser understands standard POD, but adds logical markup tags
and C<M> and C<P> links.
=back

=cut

#--------------------
=chapter METHODS

=section Constructors

=c_method new %options

=option  syntax PACKAGE|$name
=default syntax 'markov'

=option  skip_links ARRAY|REGEXP|STRING
=default skip_links undef
The parser should not attempt to load modules which match the REGEXP
or are equal or sub-namespace of STRING.  More than one of these
can be passed in an ARRAY.
=cut

sub new(%)
{	my ($class, %args) = @_;

	$class eq __PACKAGE__
		or return $class->SUPER::new(%args);

	my $syntax = delete $args{syntax} || 'markov';
	my $pkg    = $syntax_implementation{$syntax} || $syntax;
	eval "require $pkg" or die $@;
	$pkg->new(%args);
}

sub init($)
{	my ($self, $args) = @_;
	$self->SUPER::init($args) or return;

	my $skip = delete $args->{skip_links} || [];
	my @skip = map { ref $_ eq 'REGEXP' ? $_ : qr/^\Q$_\E(?:\:\:|$)/ }
		ref $skip eq 'ARRAY' ? @$skip : $skip;

	$self->{skip_links} = \@skip;
	$self;
}

#--------------------
=section Parsing a file

=method parse %options
Parse the specified input file into a code file and an object tree which
describes the pod.  Returned is a list of package objects which contain
the docs found in this file.

=requires input $file
The name of the input $file.

=option  output $file
=default output <black hole>
Where to write the produced code to.  If no $file is specified, the
platform dependend black hole is used (F</dev/null> on UNIX).

=cut

sub parse(@) {panic}

#--------------------
=section Producing manuals

After the manuals have been parsed into objects, the information can
be formatted in various ways, for instance into POD and HTML.  However,
the parsing is not yet complete: the structure has been decomposed
with M<parse()>, but the text blocks not yet.  This is because the
transformations which are needed are context dependent.

For each text section M<cleanupPod()> or M<cleanupHtml()> is called
for the final touch for the requested output markup.

=method skipManualLink $package
Returns true if the $package name matches one of the links to be
skipped, set by M<new(skip_links)>.
=cut

sub skipManualLink($)
{	my ($self, $package) = @_;
	(first { $package =~ $_ } @{$self->{skip_links}}) ? 1 : 0;
}

=method cleanupPod $manual, $text, %options
Translate the $text block, which is written in the parser specific
syntax (which may resemble native Perl POD) into real Perl POD.

=requires create_link CODE
See M<OODoc::Format::cleanup(create_link)>.
=cut

sub cleanupPod($$%) { ... }

=method cleanupHtml $manual, $text, %options
Translate the $text block, which is written in the parser specific
syntax into HTML.  This is a better quality HTML than the HTML
produced from POD, as f.i. metacpan displays.

=requires create_link CODE
See M<OODoc::Format::cleanup(create_link)>.

=option  is_html BOOLEAN
=default is_html false
Some changes will not be made when P<is_html> is true, for instance,
a "E<lt>" will stay that way, not being translated in a "E<amp>lt;".
=cut

sub cleanupHtml($$%) { ... }

=mthod formatReferTo $manual, $object
[3.05] Transform a text $object into a link in the parser specific syntax,
as it can be used in the $manual to get to refer to the $object.  This
output can be enclosed in an C<< M< > >> tag.
=cut

sub formatReferTo($$) { ... }

=method finalizeManual $manual, %options
[3.01] The parser gets a last chance to work on $manual documentation,
after all documents have been collected and intergrated.
=cut

sub finalizeManual($)
{	my ($self, $manual, %args) = @_;
	$self;
}

1;
