use ExtUtils::MakeMaker;

WriteMakefile
  ( NAME	 => 'OODoc'
  , VERSION_FROM => 'version'
  , PREREQ_PM    =>
    { Test::More              => 0.47
    , Template::Magic::HTML   => 1.02
    , Bundle::Template::Magic => 0
    }
  , AUTHOR       => 'Mark Overmeer'
  , ABSTRACT     => 'Object Oriented Documentation'
  );
