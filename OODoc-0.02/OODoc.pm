
package OODoc;
use vars 'VERSION';
$VERSION = '0.02';
use base 'OODoc::Object';

use strict;
use warnings;

use OODoc::Manifest;

use Carp;
use File::Copy;
use File::Spec;
use File::Basename;
use IO::File;


#-------------------------------------------


#-------------------------------------------


sub init($)
{   my ($self, $args) = @_;

    $self->SUPER::init($args) or return;

    $self->{O_pkg} = {};

    my $module = $self->{O_module} = delete $args->{module};
    croak "ERROR: the produced module needs a descriptive name"
        unless defined $module;

    my $version = $self->{O_version} = delete $args->{version};
    croak "ERROR: no version specified for module \"$module\""
        unless defined $version;

    $self->{O_workdir} = delete $args->{workdir};
    $self->{O_verbose} = delete $args->{verbose} || 0;
    $self;
}

#-------------------------------------------


#-------------------------------------------


sub module() {shift->{O_module}}

#-------------------------------------------


sub version() {shift->{O_version}}

#-------------------------------------------


#-------------------------------------------


sub selectFiles($@)
{   my ($self, $files) = (shift, shift);

    my $select
      = ref $files eq 'Regexp' ? sub { $_[0] =~ $files }
      : ref $files eq 'CODE'   ? $files
      : ref $files eq 'ARRAY'  ? $files
      : croak "ERROR: do not understand your file selection";

    return ($select, []) if ref $select eq 'ARRAY';

    my (@process, @copy);
    foreach my $fn (@_)
    {   if(not $fn)
        {  carp "WARNING: no file $fn to include in the distribution" }
        elsif($select->($fn)) {push @process, $fn}
        else                  {push @copy,    $fn}
    }

    ( \@process, \@copy );
}

#-------------------------------------------


sub processFiles(@)
{   my ($self, %args) = @_;
    my $verbose = defined $args{verbose} ? $args{verbose} : $self->{O_verbose};

    my $dest    = $args{workdir} || $self->{O_workdir}
       or croak "ERROR: requires a directory to write the distribution to";

    #
    # Split the set of files into those who do need special processing
    # and those who do not.
    #

    my $manfile  = exists $args{manifest} ? $args{manifest} : 'MANIFEST';
    my $manifest = OODoc::Manifest->new(filename => $manfile);

    my $select   = $args{select} || qr/\.(pm|pod)$/;
    my ($process, $copy) = $self->selectFiles($select, @$manifest);

    print @$process. " files to process and ".@$copy." files to copy\n"
       if $verbose > 1;

    #
    # Copy all the files which do not contain pseudo doc
    #

    foreach my $fn (@$copy)
    {   my $dn = File::Spec->catfile($dest, $fn);
        next if -e $dn && ( -M $dn < -M $fn ) && ( -s $dn == -s $fn );

        $self->mkdirhier(dirname $dn);

        copy($fn, $dn)
           or die "ERROR: cannot copy distribution file $fn to $dest: $!\n";

        print "Copied $fn to $dest\n" if $verbose > 2;
    }

    #
    # Create the parser
    #

    my $parser = $args{parser} || 'OODoc::Parser::Markov';
    unless(ref $parser)
    {   eval "require $parser";
        croak "ERROR: Cannot compile $parser class:\n$@"
           if $@;

        $parser = $parser->new
           or croak "ERROR: Parser $parser could not be instantiated";
    }

    #
    # Now process the rest
    #

    foreach my $fn (@$process)
    {   my $dn = File::Spec->catfile($dest, $fn);
        $self->mkdirhier(dirname $dn);

        # do the stripping
        my @manuals = $parser->parse
            ( input    => $fn
            , output   => $dn
            , version  => $self->version
            , manifest => $manfile
            );

        if($verbose > 2)
        {   print "Stripped $fn into $dn\n";
            print $_->stats foreach @manuals;
        }

        $self->addManual($_) foreach @manuals;
    }

    #
    # Some general subtotals
    #

    print $self->stats if $verbose > 1;
    $self;
}

#-------------------------------------------


#-------------------------------------------


sub prepare(@)
{   my ($self, %args) = @_;
    my $verbose = defined $args{verbose} ? $args{verbose} : $self->{O_verbose};

    print "Collect package relations.\n" if $verbose >1;
    $self->getPackageRelations;

    print "Expand manual contents.\n" if $verbose >1;
    $self->expandManuals;

    $self;
}

#-------------------------------------------


sub getPackageRelations()
{   my $self     = shift;
    my @manuals  = $self->manuals;  # all

    my @sources  = $self->unique( map {$_->source} @manuals );

    foreach my $fn (@sources)
    {    eval { require $fn };
         die "ERROR: problems compiling $fn:\n$@"
           if $@;
    }

    foreach my $manual (@manuals)
    {   if($manual->name ne $manual->package)     # autoloaded code
        {   $self->mainManual("$manual")->extraCode($manual);
            next;
        }
        my %uses = $manual->collectPackageRelations;

        foreach (defined $uses{isa} ? @{$uses{isa}} : ())
        {   my $isa = $self->mainManual($_) || $_;

            $manual->superClasses($isa);
            $isa->subClasses($manual) if ref $isa;
        }

        if(my $realizes = $uses{realizes})
        {   my $to  = $self->mainManual($realizes) || $realizes;

            $manual->realizes($to);
            $to->realizers($manual) if ref $to;
        }
    }

    $self;
}

#-------------------------------------------


sub expandManuals() { $_->expand foreach shift->manuals }

#-------------------------------------------


#-------------------------------------------


our %formatters =
 ( pod  => 'OODoc::Format::Pod'
 , html => 'OODoc::Format::Html'
 );

sub createManual($@)
{   my ($self, $format, %args) = @_;
    my $verbose = defined $args{verbose} ? $args{verbose} : $self->{O_verbose};

    my $dest    = $args{workdir} || $self->{O_workdir}
       or croak "ERROR: requires a directory to write the manuals to";

    # Create the formatter

    unless(ref $format)
    {   $format = $formatters{$format} if exists $formatters{$format};
        eval "require $format";
        die "ERROR: formatter $format has compilation errors: $@" if $@;

        $format = $format->new();
    }

    #
    # Start manifest
    #

    my $manfile  = exists $args{manifest} ? $args{manifest}
                 : File::Spec->catfile($dest, 'MANIFEST');
    my $manifest = OODoc::Manifest->new(filename => $manfile);

    #
    # Create the manual pages
    #

    foreach my $package (sort $self->packageNames)
    {   foreach my $manual ($self->manualsForPackage($package))
        {   print "Creating manual $manual for $package\n" if $verbose > 1;
            $format->createManual
             ( manual   => $manual
             , workdir  => $dest
             , manifest => $manifest

             , append         => $args{append}
             , format_options => ($args{format_options} || [])
             );
        }
    }

    #
    # Create other pages
    #

    print "Creating index pages\n" if $verbose > 1;
    $format->createIndexPages
     (
       manifest => $manifest
     );

    $format;
}

#-------------------------------------------


sub stats()
{   my $self = shift;
    my @manuals  = $self->manuals;
    my $manuals  = @manuals;
    my $realpkg  = $self->packageNames;

    my $subs     = map {$_->subroutines} @manuals;
    my $examples = map {$_->examples}    @manuals;

    my $diags    = map {$_->diagnostics} @manuals;
    my $module   = $self->module;
    my $version  = $self->version;

    <<STATS;
$module version $version
  Number of package manuals: $manuals
  Real number of packages:   $realpkg
  documented subroutines:    $subs
  documented diagnostics:    $diags
  shown examples:            $examples
STATS
}

#-------------------------------------------



1;
