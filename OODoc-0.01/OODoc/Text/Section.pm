
package OODoc::Text::Section;
use vars 'VERSION';
$VERSION = '0.01';
use base 'OODoc::Text::Structure';

use strict;
use warnings;

use Carp;
use List::Util 'first';


#-------------------------------------------


#-------------------------------------------


sub init($)
{   my ($self, $args) = @_;
    $args->{type}    ||= 'Section';

    my $chapter        = delete $args->{chapter} or confess;
    $args->{container} = $chapter;

    $self->SUPER::init($args) or return;

    $self->{OTS_subsections} = [];
    $self;
}

#-------------------------------------------

sub path()
{   my $self = shift;
    $self->chapter->path . '/' . $self->name;
}

#-------------------------------------------

sub findSubroutine($)
{   my ($self, $name) = @_;
    my $sub = $self->SUPER::findSubroutine($name);
    return $sub if defined $sub;

    foreach my $subsection ($self->subsections)
    {   my $sub = $subsection->findSubroutine($name);
        return $sub if defined $sub;
    }

    undef;
}

#-------------------------------------------

sub all($@)
{   my $self = shift;
    ($self->SUPER::all(@_), map {$_->all(@_)} $self->subsections);
}

#-------------------------------------------


#-------------------------------------------


sub subsection($)
{   my ($self, $thing) = @_;

    if(ref $thing)
    {   push @{$self->{OTS_subsections}}, $thing;
        return $thing;
    }

    first {$_->name eq $thing} $self->subsections;
}

#-------------------------------------------


sub subsections(;@)
{   my $self = shift;
    $self->{OTS_subsections} = [ @_ ] if @_;
    @{$self->{OTS_subsections}};
}

#-------------------------------------------


#-------------------------------------------


sub chapter() { shift->container }

#-------------------------------------------


#-------------------------------------------


sub allExamples()
{   my $self = shift;

    ( $self->examples
    , map {$_->examples} $self->subsections
    );
}

1;
