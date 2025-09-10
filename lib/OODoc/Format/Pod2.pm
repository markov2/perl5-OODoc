#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package OODoc::Format::Pod2;
use parent 'OODoc::Format::Pod', 'OODoc::Format::TemplateMagic';

use strict;
use warnings;

use Log::Report    'oodoc';

use Template::Magic ();
use File::Spec      ();
use Encode          qw/decode/;

#--------------------
=chapter NAME

OODoc::Format::Pod2 - Produce POD pages from the doc tree with a template

=chapter SYNOPSIS

  my $doc = OODoc->new(...);
  $doc->formatter('pod2')->createPages(
     manual_options => [ show_examples => 'NO' ],
  );

=chapter DESCRIPTION

Create manual pages in the POD syntax, using the Template::Magic
template system.  It may be a bit simpler to configure the outcome
using the template, than using OODoc::Format::Pod, however you
first need to install L<Bundle::Template::Magic>.

=chapter METHODS

=section Constructors
=c_method new %options

=default format 'pod2'
=cut

sub init($)
{	my ($self, $args) = @_;
	$args->{format} //= 'pod2';
	$self->SUPER::init($args);
}

#--------------------
=section Page generation

=method createManual %options

=option  template FILENAME
=default template <in code>
The default template is included in the DATA segment of
OODoc::Format::Pod2.  You may start your own template
by copying it to a file.
=cut

my $default_template;
{	local $/;
	$default_template = <DATA>;
	close DATA;
}

sub createManual(@)
{	my ($self, %args) = @_;
	$self->{OFP_template} = delete $args{template} || \$default_template;
	$self->SUPER::createManual(%args) or return;
}

sub _formatManual(@)
{	my ($self, %args) = @_;
	my $output    = delete $args{output};

	my %permitted =
	( chapter     => sub {$self->templateChapter(shift, \%args) },
		diagnostics => sub {$self->templateDiagnostics(shift, \%args) },
		append      => sub {$self->templateAppend(shift, \%args) },
		comment     => sub { '' }
	);

	my $template = Template::Magic->new({ -lookups => \%permitted });
	my $layout   = ${$self->{OFP_template}};        # Copy needed by template!
	my $created  = $template->output(\$layout);
	$output->print($$created);
}

=method templateChapter

=error chapter without name in template
In your template file, a C<{chapter}> statement is used, which is
erroneous, because it requires a chapter name.

=warning no meaning for container $tags in chapter block
=cut

sub templateChapter($$)
{	my ($self, $zone, $args) = @_;
	my $contained = $zone->content;
	defined $contained && length $contained
		or warning __x"no meaning for container {tags} in chapter block", tags => $contained;

	my $attrs = $zone->attributes;
	my $name  = $attrs =~ s/^\s*(\w+)\s*\,?// ? $1 : undef;

	defined $name
		or (error __x"chapter without name in template"), return '';

	my @attrs = $self->zoneGetParameters($attrs);

	open my $output, '>:encoding(UTF-8)', \(my $out);
	$self->showOptionalChapter($name, %$args, output => $output, @attrs);
	decode 'UTF-8', $out;
}

sub templateDiagnostics($$)
{	my ($self, $zone, $args) = @_;
	open my $output, '>:encoding(UTF-8)', \(my $out);
	$self->chapterDiagnostics(%$args, output => $output);
	decode 'UTF-8', $out;
}

sub templateAppend($$)
{	my ($self, $zone, $args) = @_;
	open my $output, '>:encoding(UTF-8)', \(my $out);
	$self->showAppend(%$args, output => $output);
	decode 'UTF-8', $out;
}

1;

__DATA__
=encoding utf8

{chapter NAME}
{chapter INHERITANCE}
{chapter SYNOPSIS}
{chapter DESCRIPTION}
{chapter OVERLOADED}
{chapter METHODS}
{chapter FUNCTIONS}
{chapter CONSTANTS}
{chapter EXPORTS}
{chapter DETAILS}
{diagnostics}
{chapter REFERENCES}
{chapter COPYRIGHTS}
{comment In stead of append you can also add texts directly}
{append}
