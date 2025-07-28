package OODoc::Parser;
use parent 'OODoc::Object';

use strict;
use warnings;

use Log::Report    'oodoc';

use List::Util     'first';

our %syntax_implementation = (
    markov => 'OODoc::Parser::Markov',
);

#------------------
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
=item * M<OODoc::Parser::Markov> (markov)
The Markov parser understands standard POD, but adds logical markup tags
and the C<M&lt;&gt;> links.
=back

=cut

#-------------------------------------------
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
{   my ($class, %args) = @_;
    return $class->SUPER::new(%args) unless $class eq __PACKAGE__;

    my $syntax = delete $args{syntax} || 'markov';
    my $pkg    = $syntax_implementation{$syntax} || $syntax;
    eval "require $pkg" or die $@;
    $pkg->new(%args);
}

sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args) or return;

    my $skip = delete $args->{skip_links} || [];
    my @skip = map { ref $_ eq 'Regexp' ? $_ : qr/^\Q$_\E(?:\:\:|$)/ }
        ref $skip eq 'ARRAY' ? @$skip : $skip;
    $self->{skip_links} = \@skip;

    $self;
}

#-------------------------------------------
=section Parsing a file

=method parse %options
Parse the specified input file into a code file and an object tree which
describes the pod.  Returned is a list of package objects which contain
the docs found in this file.

=requires input FILENAME
The name of the input file.

=option  output FILENAME
=default output <black hole>
Where to write the produced code to.  If no filename is specified, the
platform dependend black hole is used (/dev/null on UNIX).

=cut

sub parse(@) {panic}

#-------------------------------------------
=section Formatting text pieces

After the manuals have been parsed into objects, the information can
be formatted in various ways, for instance into POD and HTML.  However,
the parsing is not yet complete: the structure has been decomposed 
with M<parse()>, but the text blocks not yet.  This is because the
transformations which are needed are context dependent.  For each
text section M<cleanup()> is called for the final touch.

=method skipManualLink $package
Returns true is the $package name matches one of the links to be
skipped, set by M<new(skip_links)>.
=cut

sub skipManualLink($)
{   my ($self, $package) = @_;
    (first { $package =~ $_ } @{$self->{skip_links}}) ? 1 : 0;
}

=method cleanup $formatter, $manual, STRING

=error The formatter type $class is not known for cleanup
Text blocks have to get the finishing touch in the final formatting
phase.  The parser has to fix the text block segments to create a
formatter dependent output.  Only a few formatters are predefined.

=cut

sub cleanup($$$)
{   my ($self, $formatter, $manual, $string) = @_;

    return $self->cleanupPod($formatter, $manual, $string)
        if $formatter->isa('OODoc::Format::Pod');

    return $self->cleanupHtml($formatter, $manual, $string)
        if $formatter->isa('OODoc::Format::Html')
        || $formatter->isa('OODoc::Format::Html2');

    error __x"the formatter type {type} is not known for cleanup", type => ref $formatter;
}

=section Commonly used functions
=cut

1;

