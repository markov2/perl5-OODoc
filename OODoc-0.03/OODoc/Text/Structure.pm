
package OODoc::Text::Structure;
use vars 'VERSION';
$VERSION = '0.03';
use base 'OODoc::Text';

use strict;
use warnings;

use Carp;
use List::Util 'first';


#-------------------------------------------


#-------------------------------------------


sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args) or return;
    $self->{OTS_subs} = [];
}

#-------------------------------------------


#-------------------------------------------


sub path() { confess "Not implemented" }

#-------------------------------------------


sub all($@)
{   my ($self, $method) = (shift, shift);
    $self->$method(@_);
}

#-------------------------------------------


#-------------------------------------------


sub addSubroutine(@)
{  my $self = shift;
   push @{$self->{OTS_subs}}, @_;
   $self;
}

#-------------------------------------------


sub subroutines() { @{shift->{OTS_subs}} }

#-------------------------------------------


sub setSubroutines()
{   my $self = shift;
    $self->{OTS_subs} = [ @_ ];
}

#-------------------------------------------


sub subroutine($)
{   my ($self, $name) = @_;
    first {$_->name eq $name} $self->subroutines;
}

#-------------------------------------------

1;
