
package OODoc::Manual;
use vars 'VERSION';
$VERSION = '0.01';
use base 'OODoc::Object';

use strict;
use warnings;

use Carp;
use List::Util 'first';


#-------------------------------------------


#-------------------------------------------


use overload '""' => sub { shift->name };
use overload bool => sub {1};

#-------------------------------------------


use overload cmp  => sub {$_[0]->name cmp "$_[1]"};

#-------------------------------------------


sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args) or return;

    my $name = $self->{OP_package} = delete $args->{package}
       or croak "ERROR: package name is not specified";

    $self->{OP_source}   = delete $args->{source}
       or croak "ERROR: no source filename is specified for manual $name";

    $self->{OP_parser}   = delete $args->{parser}    or confess;
    $self->{OP_stripped} = delete $args->{stripped};

    $self->{OP_pure_pod} = delete $args->{pure_pod} || 0;
    $self->{OP_chapter_hash} = {};
    $self->{OP_chapters}     = [];
    $self->{OP_subclasses}   = [];
    $self->{OP_realizers}    = [];
    $self->{OP_extra_code}   = [];

    $self;
}

#-------------------------------------------


sub package() {shift->{OP_package}}

#-------------------------------------------


sub parser() {shift->{OP_parser}}

#-------------------------------------------


sub source() {shift->{OP_source}}

#-------------------------------------------


sub stripped() {shift->{OP_stripped}}

#-------------------------------------------


sub isPurePod() {shift->{OP_pure_pod}}

#-------------------------------------------


sub chapter($)
{   my ($self, $it) = @_;
    return $self->{OP_chapter_hash}{$it} unless ref $it;

    confess "$it is not a chapter"
       unless $it->isa("OODoc::Text::Chapter");

    my $name = $it->name;
    if(my $old = $self->{OP_chapter_hash}{$name})
    {   my ($fn,   $ln2) = $it->where;
        my (undef, $ln1) = $old->where;
        die "ERROR: two chapters name $name in $fn line $ln1 and $ln2\n";
    }

    $self->{OP_chapter_hash}{$name} = $it;
    push @{$self->{OP_chapters}}, $it;
    $it;
}

#-------------------------------------------


sub chapters(@)
{   my $self = shift;
    if(@_)
    {   $self->{OP_chapters}     = [ @_ ];
        $self->{OP_chapter_hash} = { map { ($_->name => $_) } @_ };
    }
    @{$self->{OP_chapters}};
}

#-------------------------------------------


sub name()
{   my $self    = shift;
    return $self->{OP_name} if defined $self->{OP_name};

    my $chapter = $self->chapter('NAME') or return ();
    my $text    = $chapter->description;

    die "ERROR: No name in manual ".$self->source."\n"
       unless $text =~ m/^\s*(\S*)\s*\-\s*/;

    $self->{OP_name} = $1
   
}

#-------------------------------------------


sub all($@)
{   my $self = shift;
    map { $_->all(@_) } $self->chapters;
}

#-------------------------------------------


sub subroutines() { shift->all('subroutines') }

#-------------------------------------------


sub subroutine($)
{   my ($self, $name) = @_;
    my $sub;
    foreach my $chapter ($self->chapters)
    {   $sub = first {defined $_} $chapter->all(subroutine => $name);
        last if defined $sub;
    }
    $sub;
}

#-------------------------------------------


sub inherited($) {$_[0]->name ne $_[1]->manual->name}

#-------------------------------------------


sub ownSubroutines
{   my $self = shift;
    my $me   = $self->name;
    grep {not $self->inherited($_)} $self->subroutines;
}

#-------------------------------------------


sub examples()
{   my $self = shift;
    ( $self->all('examples')
    , map {$_->examples} $self->subroutines
    );
}

#-------------------------------------------


sub diagnostics(@)
{   my ($self, %args) = @_;
    my @select = $args{select} ? @{$args{select}} : ();

    my @diag = map {$_->diagnostics} $self->subroutines;
    return @diag unless @select;

    my $select;
    {   local $" = '|';
        $select = qr/^(@select)$/i;
    }

    grep {$_->type =~ $select} @diag;
}

#-------------------------------------------


sub collectPackageRelations()
{   my $self = shift;
    return $self if $self->isPurePod;

    my $name = $self->package;
    my %return;

    # The @ISA / use base
    {  no strict 'refs';
       $return{isa} = [ @{"${name}::ISA"} ];
    }

    # Support for Object::Realize::Later
    $return{realizes} = $name->willRealize if $name->can('willRealize');

    %return;
}

#-------------------------------------------


sub superClasses(;@)
{   my $self = shift;
    push @{$self->{OP_isa}}, @_;
    @{$self->{OP_isa}};
}

#-------------------------------------------


sub realizes(;$)
{   my $self = shift;
    @_ ? ($self->{OP_realizes} = shift) : $self->{OP_realizes};
}

#-------------------------------------------


sub subClasses(;@)
{   my $self = shift;
    push @{$self->{OP_subclasses}}, @_;
    @{$self->{OP_subclasses}};
}

#-------------------------------------------


sub realizers(;@)
{   my $self = shift;
    push @{$self->{OP_realizers}}, @_;
    @{$self->{OP_realizers}};
}

#-------------------------------------------


sub extraCode(;@)
{   my $self = shift;
    push @{$self->{OP_extra_code}}, @_;
    @{$self->{OP_extra_code}};
}

#-------------------------------------------


sub expand()
{   my $self = shift;
    return $self if $self->{OP_is_expanded};

    #
    # All super classes much be expanded first.  Manuals for
    # extra code are considered super classes as well.  Super
    # classes which are external are ignored.
    #

    my @supers  = map { ($_, $_->extraCode) }
                     reverse     # multiple inheritance, first isa wins
                         grep { ref $_ }
                            $self->superClasses;

    $_->expand for @supers;

    #
    # Expand chapters, sections and subsections.
    #

    my @chapters = $self->chapters;

    my $merge_subsections =
        sub {  $_[0]->extends($_[1]);
               $_[0]->subsection($self->mergeObjects
                ( this  => [ $_[0]->subsections ]
                , super => [ $_[1]->subsections ]
                , merge => sub { $_[0]->extends($_[1]) }
                ));
               $_[0];
            };

    my $merge_sections =
        sub {  $_[0]->extends($_[1]);
               $_[0]->sections($self->mergeObjects
                ( this  => [ $_[0]->sections ]
                , super => [ $_[1]->sections ]
                , merge => $merge_subsections
                ));
               $_[0];
            };

    foreach my $super (@supers)
    { 
        $self->chapters($self->mergeObjects
         ( this    => \@chapters
         , super   => [ $super->chapters ]
         , merge   => $merge_sections
         ));
    }

    #
    # Expand subroutines
    #

    my %subroutine = map { ($_->name => $_) }
                        map { $_->subroutines }
                           @supers;

    foreach my $subroutine ($self->ownSubroutines)
    {   my $name = $subroutine->name;
        $subroutine->extends($subroutine{$name}) if exists $subroutine{$name};
        $subroutine{$name} = $subroutine;
    }

    my %groups;
    foreach my $subroutine (values %subroutine)
    {   my $hash = $subroutine->location($self)->unique;
        push @{$groups{$hash}}, $subroutine;
    }

    foreach my $chapter ($self->chapters)
    {   $chapter->setSubroutines(@{$groups{$chapter->unique}});

        foreach my $section ($chapter->sections)
        {   $section->setSubroutines(@{$groups{$section->unique}});

            $_->setSubroutines(@{$groups{$_->unique}})
               foreach $section->subsections;
        }
    }

    $self->{OP_is_expanded} = 1;
    $self;
}

#-------------------------------------------


sub stats()
{   my $self     = shift;
    my $subs     = $self->ownSubroutines;
    my $diags    = $self->diagnostics;
    my $chapters = $self->chapters;
    my $examples = $self->examples;

    my $manual   = $self->name;
    my $package  = $self->package;
    my $head
      = $manual eq $package
      ? "manual $manual"
      : "manual $manual for $package";

    <<STATS;
$head
   chapters:               $chapters
   documented subroutines: $subs
   documented diagnistics: $diags
   shown examples:         $examples
STATS
}

#-------------------------------------------

1;
