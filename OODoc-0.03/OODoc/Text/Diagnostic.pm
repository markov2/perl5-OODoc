
package OODoc::Text::Diagnostic;
use vars 'VERSION';
$VERSION = '0.03';
use base 'OODoc::Text';

use strict;
use warnings;

use Carp;


#-------------------------------------------


#-------------------------------------------


sub init($)
{   my ($self, $args) = @_;
    $args->{type}    ||= 'Diagnostic';
    $args->{container} = delete $args->{subroutine} or confess;

    $self->SUPER::init($args) or return;

    $self;
}

#-------------------------------------------


sub subroutine() { shift->container }

#-------------------------------------------

1;
