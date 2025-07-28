package OODoc::Export::JSON;
use parent 'OODoc::Export';

use strict;
use warnings;

use Log::Report  'oodoc';

use JSON   ();

=chapter NAME

OODoc::Export::JSON - Dump the parsed docs into JSON

=chapter SYNOPSIS

  my $doc = OODoc->new(...);
  $doc->export('json');

  my $exporter = OODoc::Export::JSON->new;

=chapter DESCRIPTION
Create a JSON dump or the parsed documentation, useful to work with dynamically
generated web-pages.

=chapter METHODS

=section Constructors

=c_method new %options
=default serializer 'json'
=cut

sub new(%) { my $class = shift; $class->SUPER::new(serializer => 'json', @_) }

#------------------
=section Output

=cut

# Bleh: JSON has real true and false booleans :-(
sub boolean($) { $_[1] ? $JSON::true : $JSON::false }

=method write $filename|$filehandle, $publish, %options
Serialize the collected publishable data to the file.

=option  pretty_print BOOLEAN
=default pretty_print C<false>
Produce readible output.

=error Cannot write output to '$file': $!
=error Write errors to {file}: $!
=cut

sub write($$%)
{   my ($self, $output, $data, %args) = @_;

    my $fh;
    if($output eq '-')
    {   $fh = \*STDOUT;
    }
    else
    {   open $fh, '>:raw', $output
            or fault __x"Cannot write output to '{file}'", file => $output;
    }

    my $json = JSON->new->pretty($args{pretty_print});
    $fh->print($json->encode($data));

    $output eq '-' || $fh->close
        or fault __x"Write errors to {file}", file => $output;

}

1;
