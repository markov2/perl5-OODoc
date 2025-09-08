
#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package OODoc::Format::Pod;
use parent 'OODoc::Format';

use strict;
use warnings;

use Log::Report    'oodoc';

use File::Spec::Functions qw/catfile/;
use List::Util            qw/max/;
use Pod::Escapes          qw/e2char/;

#--------------------
=chapter NAME

OODoc::Format::Pod - Produce POD pages from the doc tree

=chapter SYNOPSIS

  my $doc = OODoc->new(...);
  $doc->formatter('pod3')->createPages(
     append         => "extra text\n",
     manual_options => [
        show_examples => 'NO'
     ],
  );

=chapter DESCRIPTION

Create manual pages in the POD syntax.  POD is the standard document
description syntax for Perl.  POD can be translated to many different
operating system specific manual systems, like the Unix C<man> system.

=chapter METHODS

=section Constructors
=c_method new %options

=default format 'pod'
=cut

sub init($)
{	my ($self, $args) = @_;
	$args->{format} //= 'pod';
	$self->SUPER::init($args);
}

#--------------------
=section Page generation
=cut

sub cleanup($$%)
{	my ($self, $manual, $string, %args) = @_;
	$manual->parser->cleanupPod($manual, $string, %args,
		create_link => sub { $self->link(@_) },
	);
}

=ci_method link $manual, $object, [$text, \%settings]

Create the text for a link which refers to the $object.  The link will be
shown somewhere in the $manual.  The $text will be displayed is stead
of the link path, when specified.

=error cannot link to a $package
=cut

sub link($$;$$)
{	my ($any, $manual, $object, $text) = @_;

	$object = $object->subroutine if $object->isa('OODoc::Text::Option');
	$object = $object->subroutine if $object->isa('OODoc::Text::Default');
	$object = $object->container  if $object->isa('OODoc::Text::Example');
	$object = $object->container  if $object->isa('OODoc::Text::Subroutine');
	$text   = defined $text ? "$text|" : '';

	return "L<$text$object>"
		if $object->isa('OODoc::Manual');

	$object->isa('OODoc::Text::Structure')
		or error __x"cannot link to a {package}", package => ref $object;

	my $manlink = defined $manual ? $object->manual.'/' : '';
	qq(L<$text$manlink"$object">);
}

=method createManual %options
The %options are a collection of all options available to C<show*()> methods.

=option  append STRING|CODE
=default append C<"">
Used after each manual page has been formatting according to the
standard rules.  When a STRING is specified, it will be appended to
the manual page.  When a CODE reference is given, that function is
called with all the options that M<showChapter()> usually gets.

Using P<append> is one of the alternatives to create the correct
Reference, Copyrights, etc chapters at the end of each manual
page.  See L</Configuring>.

=fault cannot write prelimary pod manual to $file: $!
=cut

sub createManual($@)
{	my ($self, %args) = @_;
	my $manual   = $args{manual} or panic;
	my $podname  = $manual->source =~ s/\.pm$/.pod/r;
	my $tmpname  = $podname . 't';

	my $tmpfile  = catfile $self->workdir, $tmpname;
	my $podfile  = catfile $self->workdir, $podname;

	open my $output, '>:encoding(utf8)', $tmpfile
		or fault __x"cannot write prelimary pod manual to {file}", file => $tmpfile;

	$self->_formatManual(
		manual => $manual,
		output => $output,
		append => $args{append},
		%args
	);

	$output->close;

	$self->simplifyPod($tmpfile, $podfile);
	unlink $tmpfile;

	$self->manifest->add($podfile);

	$self;
}

sub _formatManual(@)
{	my $self = shift;
	$self->chapterName(@_);
	$self->chapterInheritance(@_);
	$self->chapterSynopsis(@_);
	$self->chapterDescription(@_);
	$self->chapterOverloaded(@_);
	$self->chapterMethods(@_);
	$self->chapterExports(@_);
	$self->chapterDetails(@_);
	$self->chapterDiagnostics(@_);
	$self->chapterReferences(@_);
	$self->chapterCopyrights(@_);
	$self->showAppend(@_);
	$self;
}

sub showAppend(@)
{	my ($self, %args) = @_;
	my $append = $args{append};

	   if(!defined $append)      { ; }
	elsif(ref $append eq 'CODE') { $append->(formatter => $self, %args) }
	else
	{	my $output = $args{output} or panic;
		$output->print($append);
	}

	$self;
}

sub showStructureExpanded(@)
{	my ($self, %args) = @_;

	my $examples = $args{show_examples} || 'EXPAND';
	my $text     = $args{structure} or panic;

	my $name     = $text->name;
	my $level    = $text->level;
	my $output   = $args{output}  or panic;
	my $manual   = $args{manual}  or panic;

	my $descr   = $self->cleanup($manual, $text->description);
	$output->print("\n=head$level $name\n\n$descr");

	$self->showSubroutines(%args, subroutines => [ $text->subroutines ]);
	$self->showExamples(%args, examples => [ $text->examples ])
		if $examples eq 'EXPAND';

	$self;
}

sub showStructureRefer(@)
{	my ($self, %args) = @_;
	my $text     = $args{structure} or panic;

	my $name     = $text->name;
	my $level    = $text->level;
	my $output   = $args{output}  or panic;
	my $manual   = $args{manual}  or panic;

	my $link     = $self->link($manual, $text);
	$output->print("\n=head$level $name\n\nSee $link.\n");
	$self;
}

sub chapterDescription(@)
{	my ($self, %args) = @_;

	$self->showRequiredChapter(DESCRIPTION => %args);

	my $manual  = $args{manual} or panic;
	my $details = $manual->chapter('DETAILS') // return $self;

	my $output  = $args{output} or panic;
	$output->print("\nSee L</DETAILS> chapter below\n");
	$self->showChapterIndex($output, $details, "   ");
	$self;
}

sub chapterDiagnostics(@)
{	my ($self, %args) = @_;
	my $manual  = $args{manual} or panic;

	my $diags   = $manual->chapter('DIAGNOSTICS');
	$self->showChapter(chapter => $diags, %args)
		if defined $diags;

	my @diags   = map $_->diagnostics, $manual->subroutines;
	return unless @diags;

	my $output  = $args{output} or panic;
	$diags
		or $output->print("\n=head1 DIAGNOSTICS\n");

	$output->print("\n=over 4\n\n");
	$self->showDiagnostics(%args, diagnostics => \@diags);
	$output->print("\n=back\n\n");
	$self;
}

=method showChapterIndex $file, $chapter, $indent
=cut

sub showChapterIndex($$;$)
{	my ($self, $output, $chapter, $indent) = @_;
	$indent //= '';

	foreach my $section ($chapter->sections)
	{	$output->print($indent, $section->name, "\n");
		foreach my $subsection ($section->subsections)
		{	$output->print($indent, $indent, $subsection->name, "\n");
		}
	}
	$self;
}

sub showExamples(@)
{	my ($self, %args) = @_;
	my $examples = $args{examples} or panic;
	@$examples or return;

	my $manual    = $args{manual}  or panic;
	my $output    = $args{output}  or panic;

	foreach my $example (@$examples)
	{	my $name    = $self->cleanup($manual, $example->name);
		$output->print("\nexample: $name\n\n");
		$output->print($self->cleanup($manual, $example->description));
		$output->print("\n");
	}
	$self;
}

sub showDiagnostics(@)
{	my ($self, %args) = @_;
	my $diagnostics = $args{diagnostics} or panic;
	@$diagnostics or return;

	my $manual    = $args{manual}  or panic;
	my $output    = $args{output}  or panic;

	foreach my $diag (sort @$diagnostics)
	{	my $name    = $self->cleanup($manual, $diag->name);
		my $type    = $diag->type;
		$output->print("\n=item $type: $name\n\n");
		$output->print($self->cleanup($manual, $diag->description));
		$output->print("Cast by ", $diag->subroutine->name, "()\n");
		$output->print("\n");
	}
	$self;
}

sub showSubroutines(@)
{	my ($self, %args) = @_;
	my $subs = $args{subroutines} || [];
	@$subs or return;

	my $output = $args{output} or panic;

	$output->print("\n=over 4\n\n");
	$self->SUPER::showSubroutines(%args);
	$output->print("\n=back\n\n");
}

sub showSubroutine(@)
{	my $self = shift;
	$self->SUPER::showSubroutine(@_);

	my %args   = @_;
	my $output = $args{output} or panic;
	$output->print("\n");
	$self;
}

sub showSubroutineUse(@)
{	my ($self, %args) = @_;
	my $subroutine = $args{subroutine} or panic;
	my $manual     = $args{manual}     or panic;
	my $output     = $args{output}     or panic;

	my $use = $self->subroutineUse($manual, $subroutine);
	$use    =~ s/(.+)/=item $1\n\n/gm;

	$output->print($use);
	$output->print("Inherited, see ". $self->link($manual, $subroutine)."\n\n")
		if $manual->inherited($subroutine);

	$self;
}

sub subroutineUse($$)
{	my ($self, $manual, $subroutine) = @_;
	my $type       = $subroutine->type;
	my $name       = $self->cleanup($manual, $subroutine->name);
	my $paramlist  = $self->cleanup($manual, $subroutine->parameters);

	$type eq 'tie'
		and return qq[tie B<$name>, $paramlist];

	my $params     = !length $paramlist ? '()' :
		$paramlist =~ m/^[\[<]|[\]>]$/ ? "( $paramlist )" : "($paramlist)";

	my $class      = $manual->package;
	my $use
	  = $type eq 'i_method' ? qq[\$obj-E<gt>B<$name>$params]
	  : $type eq 'c_method' ? qq[\$class-E<gt>B<$name>$params]
	  : $type eq 'ci_method'? qq[\$any-E<gt>B<$name>$params]
	  : $type eq 'function' ? qq[B<$name>$params]
	  : $type eq 'overload' ? qq[overload: B<$name> $paramlist]
	  :    panic $type;

	$use;
}

sub showSubroutineName(@)
{	my ($self, %args) = @_;
	my $subroutine = $args{subroutine} or panic;
	my $manual     = $args{manual}     or panic;
	my $output     = $args{output}     or panic;
	my $name       = $subroutine->name;

	my $url = $manual->inherited($subroutine) ? "M<".$subroutine->manual."::$name>" : "M<$name>";
	$output->print( $self->cleanup($manual, $url), ($args{last} ? ".\n" : ",\n") );
}

sub showOptions(@)
{	my ($self, %args) = @_;
	my $output = $args{output} or panic;
	$output->print("\n=over 2\n\n");
	$self->SUPER::showOptions(%args);
	$output->print("\n=back\n\n");
}

sub showOptionUse(@)
{	my ($self, %args) = @_;
	my $output = $args{output} or panic;
	my $option = $args{option} or panic;
	my $manual = $args{manual}  or panic;

	my $params = $option->parameters =~ s/\s+$//r =~ s/^\s+//r;
	$params    = " => ".$self->cleanup($manual, $params) if length $params;

	$output->print("=item $option$params\n\n");
	$self;
}

sub showOptionExpand(@)
{	my ($self, %args) = @_;
	my $output = $args{output} or panic;
	my $option = $args{option} or panic;
	my $manual = $args{manual}  or panic;

	$self->showOptionUse(%args);

	my $where = $option->findDescriptionObject or return $self;
	my $descr = $self->cleanup($manual, $where->description);
	$output->print("\n$descr\n\n") if length $descr;
	$self;
}

=method writeTable %options

=requires output FILE
=requires header ARRAY

=requires rows ARRAY-OF-ARRAYS
An array of arrays, each describing a row for the output.  The first row
is the header.

=option  widths ARRAY
=default widths undef

=cut

sub writeTable($@)
{	my ($self, %args) = @_;

	my $head   = $args{header} or panic;
	my $output = $args{output} or panic;
	my $rows   = $args{rows}   or panic;
	@$rows or return;

	# Convert all elements to plain text, because markup is not
	# allowed in verbatim pod blocks.
	my @rows;
	foreach my $row (@$rows)
	{	push @rows, [ map {$self->removeMarkup($_)} @$row ];
	}

	# Compute column widths
	my @w      = (0) x @$head;

	foreach my $row ($head, @rows)
	{	$w[$_] = max $w[$_], length($row->[$_])
			foreach 0..$#$row;
	}

	if(my $widths = $args{widths})
	{	defined $widths->[$_] && $widths->[$_] > $w[$_] && ($w[$_] = $widths->[$_])
			for 0..$#$rows;
	}

	pop @w;   # ignore width of last column

	# Table head
	my $headf  = " -".join("--", map "\%-${_}s", @w)."--%s\n";
	$output->printf($headf, @$head);

	# Table body
	my $format = "  ".join("  ", map "\%-${_}s", @w)."  %s\n";
	$output->printf($format, @$_) for @rows;
}

=method removeMarkup STRING
There is (AFAIK) no way to get the standard podlators code to remove
all markup from a string: to simplify a string.  On the other hand,
you are not allowed to put markup in a verbatim block, but we do have
that.  So: we have to clean the strings ourselves.
=cut

sub removeMarkup($)
{	my ($self, $string) = @_;
	my $out = $self->_removeMarkup($string);
	for($out)
	{	s/^\s+//gm;
		s/\s+$//gm;
		s/\s{2,}/ /g;
		s/\[NB\]/ /g;
	}
	$out;
}

sub _removeMarkup($)
{	my ($self, $string) = @_;

	my $out = '';
	while($string =~ s/
			(.*?)         # before
			([BCEFILSXZ]) # known formatting codes
			([<]+)        # capture ALL starters
		//x)
	{	$out .= $1;
		my ($tag, $bracks, $brack_count) = ($2, $3, length($3));

		if($string !~ s/^(|.*?[^>])  # contained
						[>]{$brack_count}
						(?![>])
						//xs)
		{	$out .= "$tag$bracks";
			next;
		}

		my $container = $1;
		if($tag =~ m/[XZ]/) { ; }  # ignore container content
		elsif($tag =~ m/[BCI]/)    # cannot display, but can be nested
		{	$out .= $self->_removeMarkup($container);
		}
		elsif($tag eq 'E') { $out .= e2char($container) }
		elsif($tag eq 'F') { $out .= $container }
		elsif($tag eq 'L')
		{	if($container =~ m!^\s*([^/|]*)\|!)
			{	$out .= $self->_removeMarkup($1);
				next;
			}

			my ($man, $chapter) = ($container, '');
			if($container =~ m!^\s*([^/]*)/\"([^"]*)\"\s*$!)
			{	($man, $chapter) = ($1, $2);
			}
			elsif($container =~ m!^\s*([^/]*)/(.*?)\s*$!)
			{	($man, $chapter) = ($1, $2);
			}

			$out .=
			  ( !length $man     ? "section $chapter"
			  : !length $chapter ? $man
			  :                    "$man section $chapter"
			  );
		}
		elsif($tag eq 'S')
		{	my $clean = $self->_removeMarkup($container);
			$clean =~ s/ /[NB]/g;
			$out  .= $clean;
		}
	}

	$out . $string;
}

sub showSubroutineDescription(@)
{	my ($self, %args) = @_;
	my $manual  = $args{manual}         or panic;
	my $output  = $args{output}         or panic;
	my $subroutine = $args{subroutine}  or panic;

	# Z<> will cause an empty body when the description is missing, so there
	# will be a blank line to the next sub description.
	my $text    = $self->cleanup($manual, $subroutine->description);
	my $extends = $subroutine->extends;
	my $refer   = $extends ? $extends->findDescriptionObject : undef;
	$text     ||= $self->cleanup($manual, "Z<>\n") unless $refer;

	$output->print("\n", $text) if length $text;
	$output->print("Improves base, see ",$self->link($manual, $refer),"\n") if $refer;
}

sub showSubroutineDescriptionRefer(@)
{	my ($self, %args) = @_;
	my $manual  = $args{manual}         or panic;
	my $output  = $args{output}         or panic;
	my $subroutine = $args{subroutine}  or panic;
	$output->print("\nInherited, see ",$self->link($manual, $subroutine),"\n");
}

sub showSubsIndex() {;}

=method simplifyPod $in, $out
The POD is produced in the specified $in filename, but may contain some
garbage, especially a lot of superfluous blanks lines.  Because it is
quite complex to track double blank lines in the production process,
we make an extra pass over the POD to remove it afterwards.  Other
clean-up activities may be implemented later.

=fault cannot read prelimary pod from $file: $!
=fault cannot write final pod to $file: $!
=fault write to $file failed: $!
=cut

sub simplifyPod($$)
{	my ($self, $infn, $outfn) = @_;

	open my $in, "<:encoding(utf8)", $infn
		or fault __x"cannot read prelimary pod from {file}", file => $infn;

	open my $out, ">:encoding(utf8)", $outfn
		or fault __x"cannot write final pod to {file}", file => $outfn;

	my $last_is_blank = 1;
  LINE:
	while(my $l = $in->getline)
	{	if($l =~ m/^\s*$/s)
		{	next LINE if $last_is_blank;
			$last_is_blank = 1;
		}
		else
		{	$last_is_blank = 0;
		}

		$out->print($l);
	}

	$in->close;
	$out->close
		or fault __x"write to {file} failed", file => $outfn;

	$self;
}

#--------------------
=chapter DETAILS

=section Configuring

Probably, the output which is produced by the POD formatter is only a
bit in the direction of your own ideas, but not quite what you like.
Therefore, there are a few ways to adapt the output.

=subsection Configuring with format options

M<createManual()> or M<OODoc::formatter()>
can be used with a list of formatting options which are passed to
M<showChapter()>.  This will help you to produce pages which have
pre-planned changes in layout.

=example format options

  use OODoc;
  my $doc = OODoc->new(...);
  $doc->processFiles(...);
  $doc->prepare;
  $doc->formatter(pod =>
     show_subs_index     => 'NAMES',
     show_inherited_subs => 'NO',
     show_described_subs => 'USE',
     show_option_table   => 'NO',
  );

=subsection Configuring by appending

By default, the last chapters are not filled in: the C<REFERENCES> and
C<COPYRIGHTS> chapters are very personal.  You can fill these in by
extending the POD generator, as described in the next section, or take
a very simple approach simply using M<createManual(append)>.

=example appending text to a page

  use OODoc;
  my $doc = OODoc->new(...);
  $doc->processFiles(...);
  $doc->prepare;
  $doc->formatter('pod', append => <<'TEXT');

  =head2 COPYRIGHTS
  ...
  TEXT

=subsection Configuring via extension

OODoc is an object oriented module, which means that you can extend the
functionality of a class by creating a new class.  This provides an
easy way to add, change or remove chapters from the produced manual
pages.

=example remove chapter inheritance

  $doc->formatter('MyPod', %format_options);

  package MyPod;
  use parent 'OODoc::Format::Pod';
  sub chapterInheritance(@) {shift}

The C<MyPod> package is extending the standard POD generator, by overruling
the default behavior of C<chapterInheritance()> by producing nothing.

=example changing the chapter's output

  $doc->formatter('MyPod', %format_options);

  package MyPod;
  use parent 'OODoc::Format::Pod';

  sub chapterCopyrights(@)
  {   my ($self, %args) = @_;
      my $manual = $args{manual} or panic;
      my $output = $args{output} or panic;

      $output->print("\n=head2 COPYRIGHTS\n");
      $output->print($manual->name =~ m/abc/ ? <<'FREE' : <<'COMMERICIAL');
This package can be used free of charge, as Perl itself.
FREE
This package will cost you money.  Register if you want to use it.
COMMERCIAL

  $self;
 }

=example adding to a chapter's output

  $doc->formatter('MyPod', %format_options);

  package MyPod;
  use parent 'OODoc::Format::Pod';
  use Log::Report 'panic';

  sub chapterDiagnostics(@)
  {   my ($self, %args) = @_;
      $self->SUPER::Diagnostics(%args);

      my $output  = $args{output} or panic;
      my $manual  = $args{manual} or panic;
      my @extends = $manual->superClasses;

      $output->print(\nSee also the diagnostics is @extends.\n");
      $self;
  }

=subsection Configuring with OODoc::Template

When using 'pod2' in stead of 'pod' when M<OODoc::formatter()> is called,
the OODoc::Format::Pod2 will be used.   It's nearly a drop-in
replacement by its default behavior.  When you specify
your own template file, every thing can be made.

=example formatting with template

  use OODoc;
  my $doc = OODoc->new(...);
  $doc->processFiles(...);
  $doc->prepare;
  $doc->formatter(pod2 =>
     template          => '/some/file',
     manual_options    => [
        show_subs_index   => 'NAMES',
        show_option_table => 'NO',
     ],
  );

=example format options within template

The template van look like this:

  {chapter NAME}
  some extra text
  {chapter OVERLOADED}
  {chapter METHODS show_option_table NO}

The formatting options can be added, however the syntax is quite sensitive:
not quotes, comma's and exactly one blank between the strings.

=cut

1;
