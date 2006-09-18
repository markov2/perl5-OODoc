use ExtUtils::MakeMaker;

WriteMakefile
  ( NAME	 => 'OODoc'
  , VERSION_FROM => 'version'
  , PREREQ_PM    =>
    { Test::More              => 0.47
    , Template::Magic::HTML   => 1.02
    , Bundle::Template::Magic => 0
    , Pod::Man                => 2.12
    }
  , AUTHOR       => 'Mark Overmeer'
  , ABSTRACT     => 'Object Oriented Documentation'
  );
