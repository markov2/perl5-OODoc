use ExtUtils::MakeMaker;

WriteMakefile
  ( NAME	 => 'OODoc'
  , VERSION      => '1.06'
  , PREREQ_PM    =>
    { Test::More              => 0.47
    , Pod::Man                => 2.12
    , File::Slurp             => 9999.12
    , Test::Pod               => 1.26
    , IO::Scalar              => 2.110
    , OODoc::Template         => 0.12

# modules not supported anymore by the author
# still needs to be removed from ::Format::HTML
    , Template::Magic::HTML   => 1.02
    , Bundle::Template::Magic =>    0
    }
  , EXE_FILES    => [ 'bin/oodist' ]

  , AUTHOR       => 'Mark Overmeer'
  , ABSTRACT     => 'Object Oriented Documentation'
  , LICENSE      => 'perl'
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
EXTENDS         = ../OODocTemplate

# for HTML
HTML_OUTPUT	= ../public_html/oodoc/html
HTML_DOCROOT	= /oodoc/html
HTML_PACKAGE	= ../public_html/oodoc/htmlpkg

__POSTAMBLE

