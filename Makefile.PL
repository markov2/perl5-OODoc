use ExtUtils::MakeMaker;

WriteMakefile
  ( NAME	 => 'OODoc'
  , VERSION_FROM => 'lib/OODoc.pm'
  , PREREQ_PM    =>
    { Test::More                  => 0.47
    }
  , AUTHOR       => 'Mark Overmeer'
  , ABSTRACT     => 'Object Oriented Documentation'
  );
