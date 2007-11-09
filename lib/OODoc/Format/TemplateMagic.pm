
use strict;
use warnings;

package OODoc::Format::TemplateMagic;

=chapter NAME

OODoc::Format::TemplateMagic - helpers to simplify use of Template::Magic

=chapter SYNOPSIS

 # Never instantiated directly.

=chapter DESCRIPTION

=chapter METHODS

=method zoneGetParameters ZONE|STRING
Takes a Template::Magic::Zone object to process the text after the
tag.  You may also specify a string, for instance a modified
attribute list.  The return is a list of key-value pairs with data.

=examples of valid arguments

 <!--{examples expand NO list ALL}-->   # old style
 <!--{examples expand => NO, list => ALL}-->
 <!--{examples expand => NO,
         list => ALL}-->

=cut

sub zoneGetParameters($)
{   my ($self, $zone) = @_;
    my $param = ref $zone ? $zone->attributes : $zone;
    $param =~ s/^\s+//;
    $param =~ s/\s+$//;

    return () unless length $param;

    return split / /, $param       # old style
       unless $param =~ m/[^\s\w]/;

    # new style
    my @params = split /\s*\,\s*/, $param;
    map { (split /\s*\=\>\s*/, $_, 2) } @params;
}

1;

