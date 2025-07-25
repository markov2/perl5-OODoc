# This code is part of perl distribution OODoc.  It is licensed under the
# same terms as Perl itself: https://spdx.org/licenses/Artistic-2.0.html

package OODoc::Format::Pod2;
use parent 'OODoc::Format::Pod', 'OODoc::Format::TemplateMagic';

use strict;
use warnings;

use Log::Report    'oodoc';
use Template::Magic ();

use File::Spec      ();
use IO::Scalar      ();

=chapter NAME

OODoc::Format::Pod2 - Produce POD pages from the doc tree with a template

=chapter SYNOPSIS

 my $doc = OODoc->new(...);
 $doc->create
   ( 'pod2'   # or 'OODoc::Format::Pod2'
   , format_options => [show_examples => 'NO']
   );

=chapter DESCRIPTION

Create manual pages in the POD syntax, using the M<Template::Magic>
template system.  It may be a bit simpler to configure the outcome
using the template, than using M<OODoc::Format::Pod>, however you
first need to install L<Bundle::Template::Magic>.

=chapter METHODS

=section Constructors
=c_method new %options

=default format 'pod2'
=cut

sub init($)
{   my ($self, $args) = @_;
    $args->{format} //= 'pod2';
    $self->SUPER::init($args);
}

#------------
=section Page generation

=method createManual %options

=option  template FILENAME
=default template <in code>
The default template is included in the DATA segment of
M<OODoc::Format::Pod2>.  You may start your own template
by copying it to a file.
=cut

my $default_template;
{   local $/;
    $default_template = <DATA>;
    close DATA;
}

sub createManual(@)
{   my ($self, %args) = @_;
    $self->{O_template} = delete $args{template} || \$default_template;
    $self->SUPER::createManual(%args) or return;
}

sub formatManual(@)
{   my ($self, %args) = @_;
    my $output    = delete $args{output};

    my %permitted =
     ( chapter     => sub {$self->templateChapter(shift, \%args) }
     , diagnostics => sub {$self->templateDiagnostics(shift, \%args) }
     , append      => sub {$self->templateAppend(shift, \%args) }
     , comment     => sub { '' }
     );

    my $template  = Template::Magic->new
     ( { -lookups => \%permitted }
     );

    my $layout  = ${$self->{O_template}};        # Copy needed by template!
    my $created = $template->output(\$layout);
    $output->print($$created);
}

=method templateChapter 

=error chapter without name in template.
In your template file, a {chapter} statement is used, which is
erroneous, because it requires a chapter name.

=warning no meaning for container $container in chapter block
=cut

sub templateChapter($$)
{   my ($self, $zone, $args) = @_;
    my $contained = $zone->content;
    defined $contained && length $contained
        or warning __x"no meaning for container {c} in chapter block", c => $contained;

    my $attrs = $zone->attributes;
    my $name  = $attrs =~ s/^\s*(\w+)\s*\,?// ? $1 : undef;

    unless(defined $name)
    {   error __x"chapter without name in template.";
        return '';
    }

    my @attrs = $self->zoneGetParameters($attrs);
    my $out   = '';

    $self->showOptionalChapter($name, %$args, output => IO::Scalar->new(\$out), @attrs);

    $out;
}

sub templateDiagnostics($$)
{   my ($self, $zone, $args) = @_;
    my $out = '';
    $self->chapterDiagnostics(%$args, output => IO::Scalar->new(\$out));
    $out;
}

sub templateAppend($$)
{   my ($self, $zone, $args) = @_;
    my $out   = '';
    $self->showAppend(%$args, output => IO::Scalar->new(\$out));
    $out;
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
