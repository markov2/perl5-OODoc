
package OODoc::Parser;
use base 'OODoc::Object';

use strict;
use warnings;

use Carp;

=chapter NAME

OODoc::Parser - base class for all OODoc parsers.

=chapter SYNOPSIS

 # Never instantiated directly.

=chapter DESCRIPTION

=cut

#-------------------------------------------

=chapter METHODS

=cut

#-------------------------------------------

=section Parsing a file

=method parse OPTIONS

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

sub parse(@) { confess }

#-------------------------------------------

=section Formatting text pieces

After the manuals have been parsed into objects, the information can
be formatted in various ways, for instance into POD and HTML.  However,
the parsing is not yet complete: the structure has been decomposed 
with M<parse()>, but the text blocks not yet.  This is because the
transformations which are needed are context dependent.  For each
text section M<cleanup()> is called for the final touch.

=cut

#-------------------------------------------

=method cleanup FORMATTER, MANUAL, STRING

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
       if $formatter->isa('OODoc::Format::Html');

    croak "ERROR: The formatter type ".ref($formatter)
        . " is not known for cleanup\n";

    $string;
}

1;

