use strict;
use warnings;

package OODoc::Format::Pod3;
use base 'OODoc::Format::Pod';

use OODoc::Template;

=chapter NAME

OODoc::Format::Pod3 - Produce POD pages using OODoc::Template

=chapter SYNOPSIS

 my $doc = OODoc->new(...);
 $doc->create
   ( 'pod3'   # or 'OODoc::Format::Pod3'
   , format_options => [show_examples => 'NO']
   );

=chapter DESCRIPTION

Create manual pages in the POD syntax, using the M<OODoc::Template>
template system.

=chapter METHODS

=method createManual OPTIONS

=option  template FILENAME
=default template <in code>
The default template is included in the DATA segment of
M<OODoc::Format::Pod3>.  You may start your own template
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
    $self->SUPER::createManual(%args);
}

sub formatManual(@)
{   my ($self, %args) = @_;
    my $output    = delete $args{output};

    my $template  = OODoc::Template->new
     ( markers    => [ '<{', '}>' ]
     , manual_obj => delete $args{manual}
     , chapter_order =>
         [ qw/NAME INHERITANCE SYNOPSIS DESCRIPTION OVERLOADED METHODS
              FUNCTIONS EXPORTS DIAGNOSTICS DETAILS REFERENCES COPYRIGHTS/
         ]
     , %args
     );

    $output->print
      (  scalar $template->process
         ( $self->{O_template}
         , manual         => sub { shift; ( {}, @_ ) }
         , chapters       => sub { $self->chapters($template, @_) }
         , sections       => sub { $self->sections($template, @_) }
         , subsections    => sub { $self->subsections($template, @_) }
         , subsubsections => sub { $self->subsubsections($template, @_) }
         , subroutines    => sub { $self->subroutines($template, @_) }
         , diagnostics    => sub { $self->diagnostics($template, @_) }
         )
      );
}

=section Template processing

=cut

sub structure($$$)
{   my ($self, $template, $type, $object) = @_;

    my $manual_obj = $template->valueFor('manual_obj');
    my $descr = $self->cleanup($manual_obj, $object->description);

    $descr =~ s/\n*$/\n\n/
        if defined $descr && length $descr;

    +{ $type        => $object->name
     , $type.'_obj' => $object
     , description  => $descr
     , examples     => [ $object->examples ]
     };
}

sub chapters($$$$$)
{   my ($self, $template, $tag, $attrs, $then, $else) = @_;
    my $manual_obj = $template->valueFor('manual_obj');

    my @chapters
       = map { $self->structure($template, chapter => $_) }
             grep {! $_->isEmpty}
                 $manual_obj->chapters;

    if(my $order = $attrs->{order})
    {   my @order = ref $order eq 'ARRAY' ? @$order : split( /\,\s*/, $order);
        my %order;

        # first the pre-defined names, then the other
        my $count = 1;
        $order{$_} = $count++ for @order;
        $order{$_->{chapter}} ||= $count++ for @chapters;

        @chapters = sort { $order{$a->{chapter}} <=> $order{$b->{chapter}} }
           @chapters;
    }

    ( \@chapters, $attrs, $then, $else );
}

sub sections($$$$$)
{   my ($self, $template, $tag, $attrs, $then, $else) = @_;
    my $chapter_obj = $template->valueFor('chapter_obj');
    my @sections
       = map { $self->structure($template, section => $_) }
             $chapter_obj->sections;

    ( \@sections, $attrs, $then, $else );
}

sub subsections($$$$$)
{   my ($self, $template, $tag, $attrs, $then, $else) = @_;
    my $section_obj = $template->valueFor('section_obj');
    my @subsections
       = map { $self->structure($template, subsection => $_) }
             $section_obj->subsections;

    ( \@subsections, $attrs, $then, $else );
}

sub subsubsections($$$$$)
{   my ($self, $template, $tag, $attrs, $then, $else) = @_;
    my $subsection_obj = $template->valueFor('subsection_obj');
    my @subsubsections
       = map { $self->structure($template, subsubsection => $_) }
             $subsection_obj->subsubsections;

    ( \@subsubsections, $attrs, $then, $else );
}

sub subroutines($$$$$$)
{   my ($self, $template, $tag, $attrs, $then, $else) = @_;

    my $parent
      = $template->valueFor('subsubsection_obj')
     || $template->valueFor('subsection_obj')
     || $template->valueFor('section_obj')
     || $template->valueFor('chapter_obj');

    defined $parent
        or return ();

    my $out  = '';
    open OUT, '>',\$out;

    my @show = map { ($_ => scalar $template->valueFor($_)) }
       qw/show_described_options show_described_subs show_diagnostics
          show_examples show_inherited_options show_inherited_subs
          show_option_table show_subs_index/;

    # This is quite weak: the whole POD section for a sub description
    # is produced outside the template.  In the future, this may get
    # changed: if there is a need for it: of course, we can do everything
    # in the template system.

    $self->showSubroutines
      ( subroutines => [ $parent->subroutines ]
      , manual      => $parent->manual
      , output      => \*OUT
      , @show
      );

    close OUT;
    length $out or return;

    $out =~ s/\n*$/\n\n/;
    ($out);
}

sub diagnostics($$$$$$)
{   my ($self, $template, $tag, $attrs, $then, $else) = @_;
    my $manual = $template->valueFor('manual_obj');
    
    my $out  = '';
    open OUT, '>',\$out;
    $self->chapterDiagnostics(%$attrs, manual => $manual, output => \*OUT);
    close OUT;

    $out =~ s/\n*$/\n\n/;
    ($out);
}

1;

__DATA__
<{macro name=structure}>\
   <{description}>\
   <{subroutines}>\
   <{template macro=examples}>\
<{/macro}>\


<{macro name=examples}>\
<{examples}>\
   <{template macro=example}>

<{/examples}>\
<{/macro}>\


<{macro name=example}>\
<{/macro}>\


<{manual}>\
  <{chapters order=$chapter_order}>\

=head1 <{chapter}>

\
    <{sections}>\

=head2 <{section}>

\
      <{subsections}>\

=head3 <{subsection}>

\
        <{subsubsections}>\

=head4 <{subsubsection}>

\
          <{template macro=structure}>\
        <{/subsubsections}>\

        <{template macro=structure}>\
      <{/subsections}>\

      <{template macro=structure}>\
    <{/sections}>\

    <{template macro=structure}>\
  <{/chapters}>\

  <{diagnostics}>\
  <{append}>\

<{/manual}>
