
package OODoc::Object;
use vars 'VERSION';
$VERSION = '0.02';

use strict;
use warnings;

use Carp;


#-------------------------------------------


#-------------------------------------------


sub new(@)
{   my $class = shift;

    my %args = @_;
    my $self = (bless {}, $class)->init(\%args);

    if(my @missing = keys %args)
    {   local $" = ', ';
        carp "WARNING: Unknown ".(@missing==1?'option':'options')." @missing";
confess;
    }

    $self;
}

sub init($)
{   my ($self, $args) = @_;
    $self;
}

#-------------------------------------------


sub extends(;$)
{   my $self = shift;
    @_ ? ($self->{OO_extends} = shift) : $self->{OO_extends};
}

#-------------------------------------------


sub mkdirhier($)
{   my $thing = shift;
    my @dirs  = File::Spec->splitdir(shift);
    my $path  = shift @dirs;   #  '/'

    while(@dirs)
    {   $path = File::Spec->catdir($path, shift @dirs);
        die "Cannot create $path $!"
            unless -d $path || mkdir $path;
    }

    $thing;
}

#-------------------------------------------


sub filenameToPackage($)
{   my ($thing, $package) = @_;
    $package =~ s#/#::#g;
    $package =~ s/\.(pm|pod)$//g;
    $package;
}

#-------------------------------------------


sub unique(@)
{   my $self  = shift;
    my %count;
    $count{$_}++ foreach @_;
    keys %count;
} 

#-------------------------------------------


sub mergeObjects(@)
{   my ($self, %args) = @_;
    my @list   = defined $args{this}  ? @{$args{this}}  : [];
    my @insert = defined $args{super} ? @{$args{super}} : [];
    my $equal  = $args{equal} || sub {"$_[0]" eq "$_[1]"};
    my $merge  = $args{merge} || sub {$_[0]};

    my @joined;

    while(@list && @insert)
    {   my $take = shift @list;
        unless(grep {$equal->($take, $_)} @insert)
        {   push @joined, $take;
            next;
        }

        my $insert;
        while(1)      # insert everything until equivalents
        {   $insert = shift @insert;
            last if $equal->($take, $insert);

            if(grep {$equal->($insert, $_)} @list)
            {   my ($fn, $ln) = $take->where;
                warn "WARNING: order conflict \"$take\" before \"$insert\" in $fn line $ln\n";
            }

            push @joined, $insert;
        }

        push @joined, $merge->($take, $insert);
    }

    (@joined, @list, @insert);
}

#-------------------------------------------


#-------------------------------------------


my %packages;

sub addManual($)
{   my ($self, $manual) = @_;

    confess "ERROR: manual definition requires manual object"
        unless ref $manual && $manual->isa('OODoc::Manual');

    push @{$packages{$manual->package}}, $manual;
    $self;
}

#-------------------------------------------


sub mainManual($)
{  my ($self, $name) = @_;
   (grep {$_ eq $_->package} $self->manualsForPackage($name))[0];
}

#-------------------------------------------


sub manualsForPackage($)
{   my ($self,$name) = @_;
    defined $packages{$name} ? @{$packages{$name}} : ();
}

#-------------------------------------------


sub manuals() { map { @$_ } values %packages }

#-------------------------------------------


sub packageNames() { keys %packages }

1;
