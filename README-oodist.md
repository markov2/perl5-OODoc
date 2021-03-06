# helper command oodist

From release 0.96, the OODoc module contains a script named 'oodist',
which simplifies the creation of pod and HTML enormously.  You do not
need to create mkdoc and mkdist scripts anymore: simply add a few lines
to your Makefile.PL is sufficient.

## about the examples

The OODoc module will be used to produce the manuals for many packages
by the same author.  Some of these modules are small, some are larger.
The setup for these packages are included in this distribution as
examples.

WARNING: Since OODoc v0.96, you can use the oodist script to produce
         the manual pages.  You do not need the mkdoc and mkdist
         scripts anymore, but still need the html/* files from these
         examples.

WARNING: You can not use the examples without modifying them to
         contain your local directory paths.  Be careful!


+ Examples:

examples/orl.tar.gz
   Extremely simple distribution (only one module!) which even doesn't
   produce any HTML output, just plain pod.

examples/mimetypes.tar.gz
   About the simplest full output you can get: two modules in this
   distribution, with both pod and html output.
   See http://perl.overmeer.net/mimetypes/html for its output.

examples/oodoc.tar.gz
   The setup for the OODoc distribution itselves.  This is a quite
   large set of modules, which causes a large amount of template files.
   See http://perl.overmeer.net/oodoc/html for its output.

examples/mailbox.tar.gz
   The most complicated module which is controlled by OODoc: the
   Mail::Box module.  This is by far most complex test case for OODoc,
   grouping the docs of multiple distributions.
