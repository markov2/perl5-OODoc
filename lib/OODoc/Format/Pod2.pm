
package OODoc::Format::Pod2;
use base 'OODoc::Format::Pod';

use strict;
use warnings;

use Carp;
use File::Spec;
use IO::Scalar;

use Template::Magic;

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

=cut

#-------------------------------------------

=chapter METHODS

=cut

=method createManual OPTIONS

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

#-------------------------------------------

sub formatManual(@)
{   my ($self, %args) = @_;
    my $output    = delete $args{output};

    my %permitted =
     ( chapter     => sub {$self->templateChapter(shift, \%args) }
     , inheritance => sub {$self->templateInheritance(shift, \%args) }
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

#-------------------------------------------

=section Template processing

=method templateChapter

=error chapter without name in template.
In your template file, a {chapter} statement is used, which is
erroneous, because it requires a chapter name.

=warning no meaning for container $container in chapter block

=cut

sub templateChapter($$)
{   my ($self, $zone, $args) = @_;
    my $contained = $zone->content;
    warn "WARNING: no meaning for container $contained in chapter block\n"
        if defined $contained && length $contained;

    my $attrs = $zone->attributes;
    my $name  = $attrs =~ s/^\s*(\w+)\s*\,?// ? $1 : undef;

    croak "ERROR: chapter without name in template.", return ''
       unless defined $name;

    my @attrs = $self->zoneGetParameters($attrs);
    my $out   = '';

    $self->showOptionalChapter($name, %$args,
       output => IO::Scalar->new(\$out), @attrs);

    $out;
}

#-------------------------------------------

sub templateInheritance($$)
{   my ($self, $zone, $args) = @_;
    my $out   = '';
    $self->chapterInheritance(%$args, output => IO::Scalar->new(\$out));
    $out;
}

#-------------------------------------------

sub templateDiagnostics($$)
{   my ($self, $zone, $args) = @_;
    my $out   = '';
    $self->chapterDiagnostics(%$args, output => IO::Scalar->new(\$out));
    $out;
}

#-------------------------------------------

sub templateAppend($$)
{   my ($self, $zone, $args) = @_;
    my $out   = '';
    $self->showAppend(%$args, output => IO::Scalar->new(\$out));
    $out;
}

#-------------------------------------------

=section Commonly used functions

=cut

1;

__DATA__
{chapter NAME}
{inheritance}
{chapter SYNOPSIS}
{chapter DESCRIPTION}
{chapter OVERLOADED}
{chapter METHODS}
{chapter EXPORTS}
{diagnostics}
{chapter DETAILS}
{chapter REFERENCES}
{chapter COPYRIGHTS}
{comment In stead of append you can also add texts directly}
{append}
