package OODoc::Text::Default;
use parent 'OODoc::Text';

use strict;
use warnings;

use Log::Report    'oodoc';

=chapter NAME

OODoc::Text::Default - one default for an option in one subroutine

=chapter SYNOPSIS

=chapter DESCRIPTION

Each M<OODoc::Text::Subroutine> can have a list of options, which have
default values which are each captured in a separate object as described
in this manual page.

=chapter METHODS

=c_method new %options

=requires subroutine OBJECT
The subroutine in which this option lives.

=requires value STRING
The value which is related to this default.

=default container M<new(subroutine)>
=default type      'Default'
=cut

sub init($)
{   my ($self, $args) = @_;
    $args->{type}    ||= 'Default';
    $args->{container} = delete $args->{subroutine} or panic;

    $self->SUPER::init($args)
        or return;

    $self->{OTD_value} = delete $args->{value};
    defined $self->{OTD_value} or panic;

    $self;
}

sub publish($)
{   my ($self, $args) = @_;
    my $exporter = $args->{exporter};

    my $p = $self->SUPER::publish($args);
    $p->{value} = $exporter->markupString($self->value);
    $p;
}

#-------------------------------------------
=section Attributes

=method subroutine 
Returns the subroutine object for this option.
=cut

sub subroutine() { $_[0]->container }

=method value 
The value of this default.
=cut

sub value() { $_[0]->{OTD_value} }

sub _setValue() { $_[0]->{OTD_value} = $_[1] }

1;
