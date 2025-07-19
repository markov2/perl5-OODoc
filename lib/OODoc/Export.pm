# This code is part of perl distribution OODoc.  It is licensed under the
# same terms as Perl itself: https://spdx.org/licenses/Artistic-2.0.html

package OODoc::Export;
use base 'OODoc::Object';

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

=requires serializer 'json'
=requires markup 'html'

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

	$self->markup eq 'html'   # avoid producing errors in every method
        or error __x"only HTML markup is currently supported.";

    $self;
}

#------------------
=section Atributes

=method serializer
The label for this serializer.

=method markup
=method parser
=cut

sub serializer() { $_[0]->{OE_serial} }
sub markup()     { $_[0]->{OE_markup} }
sub parser()     { $_[0]->{OE_parser} }

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

=method plainText STRING
The source string is to be considered as foreign to the input markup format,
so no (pseudo-)POD.
=cut

sub plainText($)
{	my ($self, $string) = @_;
	defined $string or return;

    $self->markup eq 'html' ? encode_entities $string : $string;
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
        or panic "Markup block outside a manual:\n   ",
              length $text > 83 ? substr($text, 0, 80, '...') : $text;

        $self->markup eq 'html' ? $parser->cleanupHtml($text)
      : $self->markup eq 'pod'  ? $parser->cleanupPod($text)
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
