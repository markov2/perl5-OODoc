#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package OODoc::Examples;

#--------------------
=chapter NAME

OODoc::Examples - check the generated output

=chapter SYNOPSIS

 # Not code

=chapter DESCRIPTION
This manual page does not produce any code, and does not document OODoc:
it lists various existing constructs supported by the Markov parser
(M<OODoc::Parser::Markov>), to check whether the produced output
(POD, HTML or generated via Export) from OODoc is correct.

It is really useful to look at the source of this page on github, metacpan,
or in the distribution.
L<https://github.com/markov2/perl5-OODoc/blob/master/lib/OODoc/Examples.pm>

=chapter METHODS

=section Subroutine calls

=c_method classMethod %options
=i_method instanceMethod %options
=method   instanceMethod2 %options
=ci_method classInstanceMethod %options
=function function_name %options
=tie %hash $class, %options
=overload "" (stringify)

=section Subroutine description

=method subr %options
Some descriptive text.

=option   is_optional STRING
=default  is_optional "my default"
This is an optional argument.

=requires is_required STRING
This is a required argument.

=example first example
This is an example for subroutine 'subr'.

=example another example
This is another example for subroutine 'subr'.

=fault ouch, that hurts; system fault: $!
Faults are system errors which make it into errors.

=error oops, something went wrong
Errors reflect problems in the running code.

=info transfer completed
Info statements usually show at verbose runs, to elaborate on
steps made.

=section Subroutine references

The C<M> tag can be used to make references to Methods (functions, ...)
and even parameters and options of them.  Much more fine-grained than
standard PerlPod.  This does understand inheritance.

=over 4
=item * M<subr()>; refers to method subr
=item * M<subr(is_optional)>; refers to option C<is_optional> of method subr
=back

These may also be in other manual-pages:

=over 4
=item * M<OODoc::finalize()>; refers to a method in a different manual
=item * M<OODoc::processFiles(version)>; refers to an option of a method in another manual
=back

=section Blocks
This is a section.

=subsection SubSection
This is a subsection.

=subsubsection SubSubSection
This is a subsubsection.

=section Block references

In-page links:
=over 4
=item * L</"METHODS">, links to chapter METHODS
=item * L</"Blocks">, links to section Blocks
=item * L</"SubSection">, links to SubSection
=item * L</"SubSubSection">, links to SubSubSection
=item * L<https://ibm.com>, links to external webpage
=back

In-page links, but now with alternative text:
=over 4
=item * L<TEXT|/"METHODS">, links to chapter METHODS
=item * L<TEXT|/"Blocks">, links to section Blocks
=item * L<TEXT|/"SubSection">, links to SubSection
=item * L<TEXT|/"SubSubSection">, links to SubSubSection
=item * L<TEXT|https://ibm.com>, links to external webpage
=back

=cut

1;
