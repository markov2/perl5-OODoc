
package OODoc::Text::Example;
use vars 'VERSION';
$VERSION = '0.01';
use base 'OODoc::Text';

use strict;
use warnings;

use Carp;


#-------------------------------------------


#-------------------------------------------


sub init($)
{   my ($self, $args) = @_;
    $args->{type}    ||= 'Example';
    $args->{container} = delete $args->{container} or confess;

    $self->SUPER::init($args) or return;

    $self;
}

#-------------------------------------------

1;
