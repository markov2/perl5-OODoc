
package OODoc::Manifest;
use base 'OODoc::Object';

use strict;
use warnings;

use Carp;
use IO::File;
use File::Basename 'dirname';

=chapter NAME

OODoc::Manifest - maintain the information inside a manifest file.

=chapter SYNOPSIS

 my $manifest = OODoc::Manifest->new(filename => ...);

=chapter DESCRIPTION

=chapter OVERLOADED

=overload @{}

Referencing this object as array will produce all filenames from the
manifest.

=cut

use overload '@{}' => sub { [ shift->files ] };
use overload bool  => sub {1};

#-------------------------------------------

=chapter METHODS

=c_method new OPTIONS

=option  filename FILENAME
=default filename undef

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

=section Attributes

=method filename

The name of the file which is read or will be written.

=cut

sub filename() {shift->{OM_filename}}

#-------------------------------------------

=section The manifest list

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
    {   my $add = $self->relative(shift);
        $self->modified(1) unless exists $self->{O_file}{$add};
        $self->{O_files}{$add}++;
    }
    $self;
}

#-------------------------------------------

=section Internals

=method read

Read the MANIFEST file.  The comments are stripped from the lines.

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

    s/\s+.*\n?$// for @dist;
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

=method write

Write the MANIFEST file if it has changed.  The file will automatically
be written when the object leaves scope.

=cut

sub write()
{   my $self = shift;
    return unless $self->modified;
    my $filename = $self->filename || return $self;

    my $file = IO::File->new($filename, "w")
      or die "ERROR: Cannot write manifest $filename: $!\n";

    $file->print($_, "\n") foreach sort $self->files;
    $file->close;

    $self->modified(0);
    $self;
}

sub DESTROY() { shift->write }

#-------------------------------------------

=method relative FILENAME

Returns the name of the file relative to the location of the MANIFEST
file.  The MANIFEST file should always be in top of the directory tree,
so the FILENAME should be in the same directory and below.

=warning MANIFEST file $name lists filename outside (sub)directory: $file

The MANIFEST file of a distributed package should be located in the top
directory of that packages.  All files of the distribution are in that
same directory, or one of its sub-directories, otherwise they will not
be packaged.

=cut

sub relative($)
{   my ($self, $filename) = @_;
    my $dir = dirname $self->filename;
    return $filename if $dir eq '.';

    if(substr($filename, 0, length($dir)+1) eq "$dir/")
    {   substr $filename, 0, length($dir)+1, '';
        return $filename;
    }

    warn "WARNING: MANIFEST file ".$self->filename
            . " lists filename outside (sub)directory: $filename\n";

    $filename;
}

#-------------------------------------------

=section Commonly used functions

=cut

1;
