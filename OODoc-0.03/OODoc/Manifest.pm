
package OODoc::Manifest;
use vars 'VERSION';
$VERSION = '0.03';
use base 'OODoc::Object';

use strict;
use warnings;

use Carp;
use IO::File;


#-------------------------------------------


#-------------------------------------------


sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args) or return;

    my $filename = $self->{OM_filename} = delete $args->{filename};

    $self->{O_files} = {};
    $self->read if defined $filename && -e $filename;
    $self->modified(0);
    $self;
}

#-------------------------------------------


use overload '@{}' => sub { [ shift->files ] };
use overload bool  => sub {1};

#-------------------------------------------


sub filename() {shift->{OM_filename}}

#-------------------------------------------


sub read()
{   my $self = shift;
    my $filename = $self->filename;
    my $file = IO::File->new($filename, "r")
       or die "ERROR: Cannot read manifest file $filename: $!\n";

    my @dist = $file->getlines;
    $file->close;

    chomp foreach @dist;
    $self->{O_files}{$_}++ foreach @dist;
    $self;
}

#-------------------------------------------


sub modified(;$)
{   my $self = shift;
    @_ ? $self->{OM_modified} = @_ : $self->{OM_modified};
}

#-------------------------------------------


sub files() { keys %{shift->{O_files}} }

#-------------------------------------------


sub add($)
{   my $self = shift;
    while(@_)
    {   my $filename = shift;
        $self->modified(1) unless exists $self->{O_file}{$filename};
        $self->{O_files}{$filename}++;
    }
    $self;
}

#-------------------------------------------


sub write()
{   my $self = shift;
    return unless $self->modified;
    my $filename = $self->filename;

    my $file = IO::File->new($filename, "w")
      or die "ERROR: Cannot write manifest $filename: $!\n";

    $file->print($_, "\n") foreach sort $self->files;
    $file->close;

    $self->modified(0);
    $self;
}

sub DESTROY() { shift->write }

#-------------------------------------------

1;
