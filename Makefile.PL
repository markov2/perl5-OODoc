use ExtUtils::MakeMaker;

WriteMakefile
  ( NAME	 => 'OODoc'
  , VERSION      => 0.99
  , PREREQ_PM    =>
    { Test::More              => 0.47
    , Template::Magic::HTML   => 1.02
    , Bundle::Template::Magic =>    0
    , Pod::Man                => 2.12
    , File::Slurp             => 9999.12
    }
  , EXE_FILES    => [ 'bin/oodist' ]

  , AUTHOR       => 'Mark Overmeer'
  , ABSTRACT     => 'Object Oriented Documentation'
  );

### used by oodist during production of distribution
sub MY::postamble { <<'__POSTAMBLE' }

# for DIST
RAWDIR		= ../public_html/oodoc/raw
DISTDIR		= ../public_html/oodoc/source
LICENSE		= artistic

# for POD
FIRST_YEAR      = 2003
EMAIL           = oodoc@overmeer.net
WEBSITE         = http://perl.overmeer.net/oodoc/

# for HTML
HTML_OUTPUT	= ../public_html/oodoc/html
HTML_DOCROOT	= /oodoc/html

__POSTAMBLE

