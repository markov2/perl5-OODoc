
package OODoc::Format::PodTemplate;
use vars 'VERSION';
$VERSION = '0.03';
use base 'OODoc::Format::Pod';

use strict;
use warnings;

use Carp;
use File::Spec;
use List::Util 'max';
use IO::Scalar;

use Text::MagicTemplate;


#-------------------------------------------



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
     ( chapter     => sub {$self->templateChapter(\@_, \%args) }
     , inheritance => sub {$self->templateInheritance(\@_, \%args) }
     , diagnostics => sub {$self->templateDiagnostics(\@_, \%args) }
     , append      => sub {$self->templateAppend(\@_, \%args) }
     , comment     => sub {}
     );

    my $template  = Text::MagicTemplate->new
     ( { -lookups => \%permitted }
     );

    my $created = $template->output($self->{O_template});
    $output->print($$created);
}

#-------------------------------------------


sub templateChapter($$)
{   my ($self, $attr, $args) = @_;
    my ($contained, $attributes) = @$attr;
    my $name = $attributes =~ s/^\s*(\w+)\b// ? $1 : undef;

    croak "ERROR: chapter without name in template.", return ''
       unless defined $name;

    warn "WARNING: no meaning for container $contained in chapter block\n"
        if defined $contained && length $contained;

    my @attrs = split " ", $attributes;

    my $out   = '';
    $self->showOptionalChapter($name, %$args,
       output => IO::Scalar->new(\$out), @attrs);

    $out;
}

#-------------------------------------------

sub templateInheritance($$)
{   my ($self, $attr, $args) = @_;
    my $out   = '';
    $self->chapterInheritance(%$args, output => IO::Scalar->new(\$out));
    $out;
}

#-------------------------------------------

sub templateDiagnostics($$)
{   my ($self, $attr, $args) = @_;
    my $out   = '';
    $self->chapterDiagnostics(%$args, output => IO::Scalar->new(\$out));
    $out;
}

#-------------------------------------------

sub templateAppend($$)
{   my ($self, $attr, $args) = @_;
    my $out   = '';
    $self->showAppend(%$args, output => IO::Scalar->new(\$out));
    $out;
}

#-------------------------------------------

1;

__DATA__
{chapter NAME}
{inheritance}
{chapter SYNOPSIS}
{chapter DESCRIPTION}
{chapter OVERLOADING}
{chapter METHODS}
{chapter EXPORTS}
{diagnostics}
{chapter DETAILS}
{chapter REFERENCES}
{chapter COPYRIGHTS}
{comment In stead of append you can also add texts directly}
{append}
