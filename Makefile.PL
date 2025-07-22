use ExtUtils::MakeMaker;

use warnings;
use strict;

my $git      = "https://github.com/markov2/perl5-OODoc";
my $webpages = '../public_html';
my $publish  = "$webpages/oodoc";
my $homepage = 'https://perl.overmeer.net/oodoc/';

# Use command 'oodist' to produce the documentation before the software release.
# Lines marked with '#O' are optional: ignored components or have a good default
my %oodoc = (
	first_year       => 2003,                  #   Year of first release, for copyright statement
	email            => 'perl@overmeer.net',   #O  Contact email address for this project

	include          => [                      #O  List of repository roots for modules which belong
		'../OODoc-Template',                   #O     to the documentation tree of this module.
	],

	release => {                               #   The CPAN release
		publish      => "$publish/source",     #   where a $dist-$version.tar.gz is produced
	},

	raw  => {                                  #O Keep development sources as package
		publish      => "$publish/raw",        #  where a $dist-$version-raw.tar.gz is produced
	},

	parser => {                                #O  Describes the input files
		syntax       => 'markov',              #O  name or class.  'markov' supports plain pod as well
		skip_links   => [                      #O  list of classes linked to, but not parser for the docs
		],
		pmhead       => 'PMHEAD.txt'           #O  lines to add to each stripped pm file
		podtail      => 'PODTAIL.txt',         #O  chapters to be added to the end of each manual in this dist
    },

	generate => [
	  {	format       => 'pod3',                #O  Pod files are merged into the distribution
	  },
	  {	format       => 'html',                #O  Produce static HTML output
		webpages     => "$publish/html",       #   where the pages are created
		templates    => './html',              #   templates to be used
		docroot      => '/oodoc/html',         #   the root for each generated website link
		publish      => "$publish/htmlpkg",    #   where a $dist-$version-html.tar.gz is produced
		stylesheet   => '/oodoc.css',          #   use the generic style sheet (under docroot)
	  },
	  {	export       => 'new-website'          #   Name of export
		serializer   => 'json',                #O  Serializer to produce export
		markup       => 'html',                #O  markup to be used for the output texts
		publish      => "$publish/doctree",    #   where the $dist-$version-doc.json will be produced
		output       => '-',                   #O  where to send the output, default STDOUT
	  },
	],
);

WriteMakefile
	NAME         => 'OODoc',
	VERSION_FROM => 'lib/OODoc.pm',
	PREREQ_PM    => {
		'File::Basename'  => 0,
		'File::Copy'      => 0,
		'File::Find'      => 0,
		'File::Glob'      => 0,
		'File::Slurper'   => 0.014,
		'File::Spec'      => 0,
		'HTML::Entities'  => 0,
		'IO::File'        => 0,
		'JSON'            => 0,
		'List::Util'      => 0,
		'Log::Report'     => 0,
		'OODoc::Template' => 0.16,
		'Pod::Escapes'    => 0,
		'Scalar::Util'    => 0,
	},
	EXE_FILES    => [ 'bin/oodist' ],

	AUTHOR       => 'Mark Overmeer <perl@overmeer.net>',
	ABSTRACT     => 'Object Oriented Documentation',
	LICENSE      => 'perl_5',

	META_MERGE => {
		'meta-spec' => { version => 2 },
		resources   => {
			repository => {
				type => 'git',
				url  => "$git.git",
				web  => $git,
			},
			homepage => $homepage,
			license  => [ 'https://dev.perl.org/licenses/' ],
		},
		prereqs => {
			develop => {
				requires => {
					'OODoc' => '3.00',
				}
			},
			test => {
				requires => {
					'Test::More' => 0.47,
				}
			},
		},
		x_oodoc => \%oodoc,
	};
