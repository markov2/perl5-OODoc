#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package OODoc::Export;
use parent 'OODoc::Object';

use strict;
use warnings;

use Log::Report    'oodoc';

use HTML::Entities qw/encode_entities/;
use POSIX          qw/strftime/;

our %exporters = (
	json   => 'OODoc::Export::JSON',
);

#--------------------
=chapter NAME

OODoc::Export - base-class for exporters

=chapter SYNOPSIS

  my $doc = OODoc->new(...);
  $doc->export('json');

=chapter DESCRIPTION
This base-class organizes export transformations which can be shared between
serialization formats.

Current serialization formats:

=over 4

=item OODoc::Export::JSON

=back

=chapter METHODS

=section Constructors

=c_method new %options

=requires serializer $name
At the moment, only serializer 'json' is supported.

=requires markup $markup
Specifies the markup style for the output.  At the moment, only markup
in 'html' is supported.  See accessor M<markupStyle()>.

=error exporter serializer '$name' is unknown.
=error exporter $name has compilation errors: $err
=error only HTML markup is currently supported.
=cut

sub new(%)
{	my ($class, %args) = @_;

	$class eq __PACKAGE__
		or return $class->SUPER::new(%args);

	my $serial = $args{serializer} or panic;

	my $pkg    = $exporters{$serial}
		or error __x"exporter serializer '{name}' is unknown.";

	eval "require $pkg";
	$@ and error __x"exporter {name} has compilation errors: {err}", name => $serial, err => $@;

	$pkg->new(%args);
}

sub init($)
{	my ($self, $args) = @_;
	$self->SUPER::init($args);
	$self->{OE_serial} = delete $args->{serializer} or panic;
	$self->{OE_markup} = delete $args->{markup}     or panic;

	$self->markupStyle eq 'html'   # avoid producing errors in every method
		or error __x"only HTML markup is currently supported.";

	$self;
}

#--------------------
=section Atributes

=method serializer
The label for this serializer.

=method markupStyle
=method parser
=method format
=cut

sub serializer()  { $_[0]->{OE_serial} }
sub markupStyle() { $_[0]->{OE_markup} }
sub parser()      { $_[0]->{OE_parser} }
sub format()      { $_[0]->{OE_format} }

#--------------------
=section Output

=method tree $doc, %options
Convert the documentation data in a beautiful tree.

=requires exporter OODoc::Export-object
Manages the conversion from source markup for text into the requested
markup (f.i. "markov" into "html").

=option  podtail POD
=default podtail undef
The last chapters of any produced manual page, in POD syntax.

=option  manuals ARRAY
=default manuals undef
Include only information for the manuals (specified as names).

=option  meta HASH
=default meta +{}
Key/string pairs with interesting additional data.

=option  distributions HASH
=default distributions +{}
Name to F<MYMETA.json> content mappings of project and used distributions.

=cut

sub tree($%)
{	my ($self, $doc, %args)   = @_;
	$args{exporter}      = $self;

	my $selected_manuals = $args{manuals};
	my %need_manual      = map +($_ => 1), @{$selected_manuals || []};
	my @podtail_chapters = $self->podChapters($args{podtail});

	my %man;
	foreach my $package (sort $doc->packageNames)
	{
		foreach my $manual ($doc->manualsForPackage($package))
		{	!$selected_manuals || $need_manual{$manual} or next;
			my $man = $manual->publish(\%args) or next;

			push @{$man->{chapters}}, @podtail_chapters;
			$man{$manual->name} = $man->{id};
		}
	}

	my $meta = $args{meta} || {};
	my %meta = map +($_ => $self->markup($meta->{$_}) ), keys %$meta;

	 +{
		project        => $self->markup($doc->project),
		distribution   => $doc->distribution,
		version        => $doc->version,
		manuals        => \%man,
		meta           => \%meta,
		distributions  => $args{distributions} || {},
		index          => $self->publicationIndex,

		generated_by   => {
			program         => $0,
			program_version => $main::VERSION // undef,
			oodoc_version   => $OODoc::VERSION // 'devel',
			created         => (strftime "%F %T", localtime),
		},
	 };
}

sub publish { panic }

=method processingManual $manual|undef
Manual pages may be written in different syntaxes.  In the document tree,
the main structure is parsed, but the text blocks are not: they are only
processed at output time.  Calling this method sets the interpretation
mode for text blocks.
=cut

sub _formatterHtml($$)
{	my ($self, $manual, $parser) = @_;

	sub {
		# called with $html, %settings
		$parser->cleanupHtml($manual, @_, create_link => sub {
			# called with ($manual, ...);
			my (undef, $object, $html, $settings) = @_;
			$html //= encode_entities $object->name;
			my $unique = $object->unique;
			qq{<a class="jump" href="$unique">$html</a>};
		});
	};
}

sub _formatterPod($$)
{	my ($self, $manual, $parser) = @_;

	sub {
		# called with $text, %settings
		$parser->cleanupPod($manual, @_, create_link => sub {
			# called with ($manual, ...);
			my (undef, $object, $text, $settings) = @_;
			OODoc::Format::Pod->link($manual, $object, $text, $settings);
		});
	};
}

sub processingManual($)
{	my ($self, $manual) = @_;
	my $parser = $self->{OE_parser} = defined $manual ? $manual->parser : undef;

	if(!defined $manual)
	{	delete $self->{OE_parser};
		$self->{OE_format} = sub { panic };
		return;
	}

	my $style  = $self->markupStyle;
	$self->{OE_format}
	  = $style eq 'html' ? $self->_formatterHtml($manual, $parser)
	  : $style eq 'pod'  ? $self->_formatterPod($manual, $parser)
	  :   panic $style;

	$self;
}

=method markup STRING
The source string is to be considered as foreign to the input markup format,
so no (pseudo-)POD.
=cut

sub markup($)
{	my ($self, $string) = @_;
	defined $string && $self->markupStyle eq 'html' ? encode_entities $string : $string;
}

=method boolean BOOL
=cut

sub boolean($) { !! $_[1] }

=method markupBlock $text, %args
Convert a block of text, which still contains markup.
=cut

sub markupBlock($%)
{	my ($self, $text, %args) = @_;
	$self->format->($text, %args);
}

=method markupString $string, %args
Convert a line of text, which still contains markup.  This sometimes as some
differences with a M<markupBlock()>.
=cut

sub markupString($%)
{	my ($self, $string, %args) = @_;
	my $up = $self->format->($string, %args);
	$self->markupStyle eq 'html' or return $up;

	$up =~ s!</p>\s*<p>!<br>!grs  # keep line-breaks
		=~ s!<p\b.*?>!!gr         # remove paragraphing
		=~ s!\</p\>!!gr;
}

=method podChapters $pod
=cut

sub podChapters($)
{	my ($self, $pod) = @_;
	defined $pod && length $pod or return ();

	my $parser = OODoc::Parser::Markov->new;  # supports plain POD
	...
}

1;

__END__
#--------------------
=chapter DETAILS

The exporters will each create the same data tree, but implement different serializations.

In the following examples, magnifactured JSON dumps are shown.  Be aware the JSON
does not sort fields, so your output looks less organized.

=section the Tree

The data-structure refers to a few capitalized comments:

=over 4
=item MARKUP
The output markup used for text.  Currently only "html" is supported.

=item META
Distribution meta-data, as provided by its F<MYMETA.json>.

=item SAFE
No HTML, but does never contain any HTML conflicting data.  Is
does not contain links.
=back

=subsection root

The root:

  { "project": "MailBox",                      # MARKUP
    "distribution": "Mail-Box",                # SAFE
    "version": "4.01_12",                      # SAFE

    "generated_by" : {
       "program": "oodist",                    # SAFE
       "program_version": "3.14",              # SAFE
       "oodoc_version": "3.00",                # SAFE
       "created": "2025-07-27 16:30"           # SAFE
    },
    "distributions": {
       "Mail-Box": { ... },                    # META
       "Mail-Message": { ... }                 # META
    },
    "manuals": {
       "Mail::Message": "id42",                # REF
       "Mail::Message::Field": "id1023"        # REF
    },
    "index": {
       "id42": { ... },
       "id1023": { ... }
    }
  }

=subsection Distributions

Each HASH in the C<distributions>, is a full copy of the C<MYMETA.json> for a
distribution which belongs to the C<project> or is C<use>d by any distribution
which is part of the project.

Some of the important fields:

  { "name": "Mail-Box",                        # SAFE
    "abstract": "Manage a mailbox",            # MARKUP
    "version": "3.14"                          # SAFE
  }

Take a look at the C<MYMETA.json> or C<META.json> for any module which is produced
with OODoc, for instance OODoc itself at L<https://metacpan.org/XXX>

=subsection Manual

  { "id": REF,
    "name": "Mail::Box",                       # MARKUP
    "version": "3.14",                         # or undef
    "title": "Manage a mailbox",               # MARKUP
    "package": "lib/Mail/Box.pm",              # SAFE
    "distribution": "Mail-Box",                # SAFE
    "is_pure_pod": false,                      # BOOLEAN
    "inheritance": \%interitance,              # see below
    "chapters": [ REF, ... ]
  }

The chapters are sorted logically, as they appear in traditional unix manual pages,
with a few extensions.

=subsection Inheritance
The manual contains a details inheritance relationship structure, which MAY
use the following fields:

  { "extends": [ CLASS, ... ],                 # parent class(es)
    "extended_by": [ CLASS, ... ],             # extension class(es)
    "extra_code_for": PACKAGE,                 # package != filename
    "extra_code_in": [ PACKAGE, ... ],         # dynamically loaded code
    "realizes": CLASS,                         # see Object::Realize::Later
    "realized_by": [ CLASS, ... ],             #   "
  }

Objects which extend Object::Realize::Later are placeholders, which can become
real objects when they are used.  It's a beautiful trick, hence supported here.

One of the most extensive uses of this structure is Mail::Message::Body.

=subsection Nested blocks of text

Manuals are a collection of chapters, which can contain sections, which may have
subsections, which on their turn can carry subsubsections.  So: the manuals are
a list of nested blocks.

Each (text) block has same features:

  { "id": REF,                                 # SAFE
    "name": "Constructors",                    # MARKUP
    "level": 2,                                # SAFE
    "type": "section",                         # SAFE
    "extends": REFERENCE,                      #XXX TODO
    "intro": "Intro to this section.",         # MARKUP
    "examples": [ REF, ... ],
    "subroutines": [ REF, ... ],
    "nest": [ REF, ... ],                      # sub-blocks
  }

The examples, subroutines and nested blocks are to be kept in their order.

The description and examples are about the content of the whole block.
Subroutines will also have specific descriptions and examples.

=subsection Subroutines

There are a few types of subroutines:

=over 4
=item * C<function>, the classical 'sub'
=item * C<i_method>, instance method (in the docs also as C<=method>)
=item * C<c_method>, class method
=item * C<ci_method>, both usable as class or instance method
=item * C<overload>, describes overloading
=item * C<tie>, tied interface
=back

Each subroutine looks like this:

  { "id": REF,                               # SAFE
    "name": "producePages",                  # MARKUP
    "call": "$obj->producePages()" ],        # MARKUP
    "type": "i_method",                      # MARKUP
    "intro": "Create the manual ...",        # MARKUP
    "examples": [ REF, ... ],
    "options: [ REF, ... ],
    "diagnostics": [ REF, ... ],
  }

=subsection Options

Most subroutine forms can have options.  They are passed as
list sorted by name.

  { "id": REF,                               # SAFE
    "name": "beautify",                      # MARKUP
    "type": "option",                        # SAFE
    "params": "true|false",                  # MARKUP
    "intro": "Make the output better"        # MARKUP
  }

The defaults look like this:

  { "id": REF,                               # SAFE
    "name": "beautify",                      # MARKUP
    "type": "default",                       # SAFE
    "value": "<true>",                       # MARKUP
  }

The option is required when the default value is C<< <required> >>.

=subsection Examples

Every block of text, and every subroutine can have a number of
examples.  Examples do not always have a name.

  { "id": REF,                               # SAFE
    "name": "how to produce pages",          # MARKUP
    "type": "example",                       # SAFE
    "intro": "Like this"                     # MARKUP
  }

=subsection Diagnostics

Most subroutine forms can have a list of diagnostics, which are
sorted errors first, then by description text.  Other types of
diagnostics will be added soon, to match the levels offered by
Log::Report.

  { "id": REF,                               # SAFE
    "type": "error"/"warning"/"info"...,     # SAFE
    "name": "Missing ...",                   # MARKUP
    "intro: "This error is shown when...",   # MARKUP
    "subroutine": REF,
  }

=cut
