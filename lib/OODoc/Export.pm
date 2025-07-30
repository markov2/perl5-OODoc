package OODoc::Export;
use parent 'OODoc::Object';

use strict;
use warnings;

use Log::Report    'oodoc';

use HTML::Entities qw/encode_entities/;

our %exporters =
  ( json   => 'OODoc::Export::JSON'
  );

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

=item M<OODoc::Export::JSON>

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
=cut

sub new(%)
{   my $class = shift;
    $class eq __PACKAGE__
        or return $class->SUPER::new(@_);

    my %args   = @_;
    my $serial = $args{serializer} or panic;

    my $pkg    = $exporters{$serial}
        or error __x"exporter serializer '{name}' is unknown.";

    eval "require $pkg";
    $@ and error __x"exporter {name} has compilation errors: {err}", name => $serial, err => $@;

    $pkg->new(%args);
}

sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->{OE_serial} = delete $args->{serializer} or panic;
    $self->{OE_markup} = delete $args->{markup}     or panic;

	$self->markupStyle eq 'html'   # avoid producing errors in every method
        or error __x"only HTML markup is currently supported.";

    $self;
}

#------------------
=section Atributes

=method serializer
The label for this serializer.

=method markupStyle
=method parser
=cut

sub serializer()  { $_[0]->{OE_serial} }
sub markupStyle() { $_[0]->{OE_markup} }
sub parser()      { $_[0]->{OE_parser} }

#------------------
=section Output

=method processingManual $manual|undef
Manual pages may be written in different syntaxes.  In the document tree,
the main structure is parsed, but the text blocks are not: they are only
processed at output time.  Calling this method sets the interpretation
mode for text blocks.
=cut

sub processingManual($)
{   my ($self, $manual) = @_;
    $self->{OE_parser} = defined $manual ? $manual->parser : undef;
}

=method markup STRING
The source string is to be considered as foreign to the input markup format,
so no (pseudo-)POD.
=cut

sub markup($)
{	my ($self, $string) = @_;
	defined $string or return;

    $self->markupStyle eq 'html' ? encode_entities $string : $string;
}

=method boolean BOOL
=cut

sub boolean($) { !! $_[1] }

=method markupBlock $text
Convert a block of text, which still contains markup.
=cut

sub markupBlock($)
{	my ($self, $text) = @_;
    my $parser = $self->parser
        or panic "Markup block outside a manual:\n   ", (length $text > 83 ? substr($text, 0, 80, '...') : $text);

	my $style = $self->markupStyle;

return "<pre>".(encode_entities $text)."</pre>";
        $style eq 'html' ? $parser->cleanupHtml($text)
      : $style eq 'pod'  ? $parser->cleanupPod($text)
      : panic;
}

=method podChapters $pod
=cut

sub podChapters($)
{	my ($self, $pod) = @_;
	defined $pod && length $pod or return [];

    my $parser = OODoc::Parser::Markov->new;  # supports plain POD
    ...
}

1;

__END__
=chapter DETAILS

The exporters will each create the same data tree, but implement different serializations.

In the following examples, magnifactured JSON dumps are shown.  Be aware the JSON
does not sort fields, so your output looks less organized.

=section the Tree

The data-structure refers to a few capitalized comments:

=over 4
=item MARKUP
The output markup used for text.  Currently only "html" is supported.
=item REFERENCE
Refers to a different element in the tree.  See L</Reference>.
=back

=subsection root

The root:

  { "project": "MailBox",                      # MARKUP
    "distribution": "Mail-Box",
    "version": "4.01_12",

    "generated_by" : {
       "program": "oodist",
       "program_version": "3.14",
       "oodoc_version": "3.00",
       "created": "2025-07-27 16:30"
    },
    "distributions": {
       "Mail-Box": { ... },
       "Mail-Message": { ... }
    },
    "manuals": {
       "Mail::Message": { ... },
       "Mail::Message::Field": { ... }
    },
  }

=subsection Distributions

Each HASH in the C<distributions>, is a full copy of the C<MYMETA.json> for a
distribution which belongs to the C<project> or is C<use>d by any distribution
which is part of the project.

Some of the important fields:

  { "name": "Mail-Box",
    "abstract": "Manage a mailbox",            # MARKUP
    "version": "3.14"
  }

Take a look at the C<MYMETA.json> or C<META.json> for any module which is produced
with OODoc, for instance OODoc itself at F<https://metacpan.org/XXX>

=subsection Manual

  { "name": "Mail::Box",                       # MARKUP
  , "version": "3.14",                         # or undef
  , "title": "Manage a mailbox",               # MARKUP
  , "package": "lib/Mail/Box.pm",
  , "distribution": "Mail-Box",
  , "is_pure_pod": false,                      # BOOLEAN
  , "chapters": [ { ... }, ... ]
  }

The chapters are sorted logically, as they appear in traditional unix manual pages,
with a few extensions.

=subsection Nested blocks of text

Manuals are a collection of chapters, which can contain sections, which may have
subsections, which on their turn can carry subsubsections.  So: the manuals are
a list of nested blocks.

Each (text) block has same features:

  { "name": "Constructors",                    # MARKUP
    "level": 2,
    "type": "section",
    "extends": REFERENCE,
    "description": "Intro to this section.",   # MARKUP
    "examples": [ { ... }, ... ],
    "subroutines": [ { ... }, ... ],
    "nest": [ { ... }, ... ],  # sub-blocks
  }

The examples, subroutines and nested blocks are to be kept in their order.

The description and examples are about the content of the whole block.
Subroutines will also have specific descriptions and examples.

=subsection Subroutines

There are a few types of subroutines:

=over 4
=item C<function>, the classical 'sub'
=item C<i_method>, instance method (in the docs also as C<=method>)
=item C<c_method>, class method
=item C<ci_method>, both usable as class or instance method
=item C<overload>, describes overloading
=item C<tie>, tied interface
=back

Each subroutine looks like this:

  { "name": "producePages",                  # MARKUP
    "call": [ "$obj->producePages()", ... ], # MARKUP
    "options: [ { ... }, ... ],
    "extends": REFERENCE,
    "type": "i_method",
    "description": "Create the manual ...",  # MARKUP
    "examples": [ { ... }, ... ],
    "diagnostics": [ { ... }, ... ],
    "block": REFERENCE
  }

=subsection Options

Most subroutine forms can have options.  They are passed as
list sorted by name.

  { "name": "beautify",                      # MARKUP
    "type": "option",
    "extends": REFERENCE,
    "default": "true|false",                 # MARKUP
    "is_required": true,
    "description": "Make the output better"  # MARKUP
  }

=subsection Examples

Every block of text, and every subroutine can have a number of
examples.  Examples do not always have a name.

  { "name": "how to produce pages",          # MARKUP
    "type": "example",
    "description": "Like this"               # MARKUP
  }

=subsection Diagnostics

Most subroutine forms can have a list of diagnostics, which are
sorted errors first, then by description text.  Other types of
diagnostics will be added soon, to match the levels offered by
M<Log::Report>.

  { "type": "error" or "warning",
    "description": "Missing ...",            # MARKUP
    "subroutine": REFERENCE
  }

=subsection Reference

Only field C<manual> will always be present.  Most fields require a C<chapter>.
The C<sub*section> require a C<*section>.
Field C<option> requires C<subroutine>.

  { "manual": "Mail::Box",
    "chapter": "METHODS",                    # MARKUP
    "section": "Constructors",               # MARKUP
    "subsection": undef,                     # MARKUP
    "subsubsection": undef,                  # MARKUP
    "subroutine": "new",                     # MARKUP
    "option": "beautify",                    # MARKUP
    "example": undef,                        # MARKUP
  }

=cut
