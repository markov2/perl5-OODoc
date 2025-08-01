#!/usr/bin/perl

use strict;
use warnings;

print "Content-Type: text/html\r\n\r\n";

# Get the question

my $to = $ENV{QUERY_STRING} || '';
my ($manual, $unique) = $to =~ m#([\w:%]+)\&(id\d+)#;
$manual =~ s/\%[a-fA-F0-9]{2}/chr hex $1/ge;

# Contact the database

my $DB = $0;
$DB    =~ s/[\w\.]+$/markers/;

open my $db, '<', $DB or die "Cannot read markers from $DB: $!\n";
my $root = $db->getline;
chomp $root;

# Lookup location of item in the manual page

my ($nr, $in, $page);
while(my $line = $db->getline)
{   ($nr, $in, $page) = split " ", $line, 3;
    last if $nr eq $unique && $in eq $manual;
}

$nr eq $unique
    or die "cannot find id $to for $manual in $DB\n";

chomp $page;

# Keep same index on the right, if possible

my $show = "relations.html";
if(my $refer = $ENV{HTTP_REFERER})
{   $show = "$1.html"
        if $refer =~ m/(doclist|sorted|grouped|relations)\.html/;
}

# Produce page, which is compible to the normal html/manual/index.html
# This cgi script is processed by the template system too.

print <<PAGE;
<html>
<head>
  <title>$manual</title>
  <!--{meta}-->
</head>

<frameset rows="130,*" frameborder="NO">
   <frame src="$root/$manual/head.html" name="head">
   <frameset cols="*,350" frameborder="NO">
      <frame src="$root/$manual/$page#$unique" name="main">
      <frame src="$root/$manual/$show" name="grouped">
   </frameset>
</frameset>
   
<noframes>
  <body>
  Sorry, you need frames for this documentation.
  </body>
</noframes>

</html>
PAGE
