
package OODoc::Text::Subroutine;
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

    confess "no name for subroutine"
       unless exists $args->{name};

    $self->SUPER::init($args) or return;

    $self->{OTS_param}    = delete $args->{parameters};
    $self->{OTS_options}  = {};
    $self->{OTS_defaults} = {};
    $self->{OTS_diags}    = [];
    $self;
}

#-------------------------------------------


#-------------------------------------------


sub parameters() {shift->{OTS_param}}

#-------------------------------------------


#-------------------------------------------


sub default($)
{   my ($self, $it) = @_;
    return $self->{OTS_defaults}{$it} unless ref $it;

    my $name = $it->name;
    $self->{OTS_defaults}{$name} = $it;
    $it;
}

#-------------------------------------------


sub defaults() { values %{shift->{OTS_defaults}} }

#-------------------------------------------


sub option($)
{   my ($self, $it) = @_;
    return $self->{OTS_options}{$it} unless ref $it;

    my $name = $it->name;
    $self->{OTS_options}{$name} = $it;
    $it;
}

#-------------------------------------------


sub findOption($)
{   my ($self, $name) = @_;
    my $option = $self->option($name);
    return $option if $option;

    my $extends = $self->extends or return;
    $extends->option($name);
}

#-------------------------------------------



sub options() { values %{shift->{OTS_options}} }

#-------------------------------------------


sub diagnostic($)
{   my ($self, $diag) = @_;
    push @{$self->{OTS_diags}}, $diag;
    $diag;
}

#-------------------------------------------


sub diagnostics() { @{shift->{OTS_diags}} }

#-------------------------------------------


#-------------------------------------------


sub location($)
{   my ($self, $manual) = @_;
    my $container = $self->container;
    my $super     = $self->extends or return $container;

    my $superloc  = $super->location;
    my $superpath = $superloc->path;
    my $mypath    = $container->path;

    return $container if $superpath eq $mypath;
    
    if(length $superpath < length $mypath)
    {   return $container
           if substr($mypath, 0, length($superpath)+1) eq "$superpath/";
    }
    elsif(substr($superpath, 0, length($mypath)+1) eq "$mypath/")
    {   if($superloc->isa("OODoc::Text::Chapter"))
        {   return $self->manual
                        ->chapter($superloc->name);
        }
        elsif($superloc->isa("OODoc::Text::Section"))
        {   return $self->manual
                        ->chapter($superloc->chapter->name)
                        ->section($superloc->name);
        }
        else
        {   return $self->manual
                        ->chapter($superloc->chapter->name)
                        ->section($superloc->section->name)
                        ->subsection($superloc->name);
        }
   }

   unless($manual->inherited($self))
   {   my ($myfn, $myln)       = $self->where;
       my ($superfn, $superln) = $super->where;

       warn <<WARN
WARNING: Subroutine $self() location conflict:
   $mypath ($myfn line $myln)
   $superpath ($superfn line $superln)
WARN
   }

   $container;
}

#-------------------------------------------


sub collectedOptions(@)
{   my ($self, %args) = @_;
    my $extends   = $self->extends;
    my $options   = $extends ? $extends->collectedOptions : {};
    
    $options->{$_->name}[0] = $_ for $self->options;

    foreach my $default ($self->defaults)
    {   my $name = $default->name;

        unless(exists $options->{$name})
        {   my ($fn, $ln) = $default->where;
            warn "WARNING: no option $name for default in $fn line $ln\n";
            next;
        }
        $options->{$name}[1] = $default;
    }

    foreach my $option ($self->options)
    {   my $name = $option->name;
        next if defined $options->{$name}[1];

        my ($fn, $ln) = $option->where;
        warn "WARNING: no default for option $name defined in $fn line $ln\n";

        my $default = $options->{$name}[0] =
        OODoc::Text::Default->new
         ( name => $name, value => 'C<undef>'
         , soubroutine => $self, linenr => $ln
         );
        $self->default($default);
    }

    $options;
}

1;
