
package OODoc::Manifest;
use base 'OODoc::Object';

use strict;
use warnings;

use Carp;
use IO::File;

=chapter NAME

OODoc::Manifest - maintain the information inside a manifest file.

=chapter SYNOPSIS

 my $manifest = OODoc::Manifest->new(filename => ...);

=chapter DESCRIPTION

=cut

#-------------------------------------------

=chapter METHODS

=cut

#-------------------------------------------

=c_method new OPTIONS

=option  filename FILENAME
=default filename C<undef>

The filename where the manifest is in.  When the name is not defined,
the data will not be written.

=cut

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

=overload @{}

Referencing this object as array will produce all filenames from the
manifest.

=cut

use overload '@{}' => sub { [ shift->files ] };
use overload bool  => sub {1};

#-------------------------------------------

=method filename

The name of the file which is read or will be written.

=cut

sub filename() {shift->{OM_filename}}

#-------------------------------------------

=method read

Read the manifest file.

=error Cannot read manifest file $filename: $!

The manifest file could not be opened for reading.

=cut

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

=method modified [BOOLEAN]

Whether filenames have been added to the list after initiation.

=cut

sub modified(;$)
{   my $self = shift;
    @_ ? $self->{OM_modified} = @_ : $self->{OM_modified};
}

#-------------------------------------------

=method files

Returns an unsorted list with all filenames in this manifest.

=cut

sub files() { keys %{shift->{O_files}} }

#-------------------------------------------

=method add FILENAMES

Adds the FILENAMES to the manifest, doubles are ignored.

=cut

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

=method write

Write the MANIFEST file if it has changed.  The file will automatically
be written when the object leaves scope.

=cut

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
