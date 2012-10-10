#!/usr/bin/env perl
# vim: set ft=perl :

use strict;
use warnings;
use utf8;

our $VERSION = '0.0.1';

use FindBin;
use lib ("$FindBin::Bin/lib", "$FindBin::Bin/sitelib");
use File::Spec::Functions qw/catfile/;

our %options;

BEGIN {
    my $config_file  = catfile($FindBin::Bin, ".config.pl");
    eval {
        -f $config_file and require $config_file;
    };
    if ($@) {
        print STDERR "fatal error at initialization: $@";
        exit 1;
    }
};


use IWiki;

my $iwiki = IWiki->new(%options);
eval {
    $iwiki->start;
};
if ($@) {
    $options{debug} and print $iwiki->error(500, $@);
    print STDERR "fatal error: $@";
    exit 1;
}

1;

__END__

=head1 SCRIPT NAME

index.cgi -- a lightweight wiki script

=head1 DESCRIPTION

This is a lightweight wiki script to publish web pages in a simple way like blosxom.

=over2

=item

One text file corresponds to one page. You can manage your pages with your favorite interface e.g. a command-line console, a file manager, and so on.

=item

Each text file is written in Wiki notation. Plain text is easy to edit.

=item

XSLT is adopted as a template engine. Stable and secure for generating XHTML or other XML-based documents like RSS.

=back

=head1 REQUIREMENTS

=over 2

=item Perl (5.8.0 or later) L<http://www.perl.org/>

=item libxml2 L<http://xmlsoft.org/>

=item XML::LibXML

=item XML::LibXSLT

=item DBD::SQLite

=item Regexp::Common

=item HTTP::Date

=item DateTime

=item DateTime::Format::W3CDTF

=back

=head1 INSTALL

1. Put all files and directories into your web root directory.

2. Rename F<sample.config.pl> to F<.config.pl>.

3. Change permissions properly.

 -+- index.cgi  (r-x)
  |- .config.pl (r--)
  |- cache/     (rwx)
  |- lib/       (r-x)
  |- sitelib/   (r-x)
  |- template/  (r-x)
  |- text/      (r-x)

4. Install the required modules from CPAN. These modules can be installed into F<sitelib> directory.

=head1 USAGE

1. Edit F<.config.pl>. There are some modifiable variables.

2. Write templates in XSLT and put them into F<template> directory.

3. Make text files in Wiki notation and put them into F<text> directory.

=head1 CONFIGURATION

variables in F<.config.pl>.

=over 2

=item C<$main::options{debug}> (default: 0)

Show detailed error messages on 500 error page when an exception is caught.

=item C<$main::options{text_dir}> (default: $FindBin::Bin/text)

The path of the directory where text files are placed.

=item C<$main::options{template_dir}> (default: $FindBin::Bin/template)

The path of the directory where template files are placed.

=item C<$main::options{cache_dir}> (default: $FindBin::Bin/cache)

The path of the directory where cache files are created.

=item C<$main::options{use_cache}> (default: 0)

Whether XSLT results are cached or not.

=item C<$main::options{rules}>

This variable determines which template should be applied to which URL.
$main::options{rules} is a reference to an array which consists of hash references which have the following keys and values.

=over 2

=item C<template>

The location of a template file. This key is mandatory.

=item C<match_path_info>, C<match_dirname>, C<match_basename>, C<match_extension>, C<match_text_path>

The specified template is used if the path matches the specified regexp.

=item C<env_ENVVAR>

The specified template is used if the environmental variable ENVVAR matches the specified regexp.

=item C<expiry>

The cache will expire when the specified seconds have passed.

=item C<ignore_last_modified>

Ignore If_Modified_Since field and do not send Last-Modified field in HTTP header.

=item C<http_field_name>

Add or overrite Field-Name field in HTTP header with the value.

=back

For example:

 $main::options{rules} = [
     {
         match_path_info       => qr{\A/update\.rdf\z},
         template              => "update_rdf.xsl",
         expiry                => 60 * 60 * 24,
         ignore_last_modified  => 1,
     }, # update_rdf.xsl is used when PATH_INFO is /update.rdf.
        # The cache is expired in 24 hours.
     {
         match_path_info       => qr{(?:/.+\.html|/)\z},
         template              => 'default.xsl',
         http_content_language => 'ja',
     }, # default.xsl is used when PATH_INFO matches the regular expression.
        # 'Content-Language: ja' is included in HTTP header.
 ];

=item C<$main::options{xslt_params}>

Parameters to be passed to XSLT template.

=item C<$main::options{user_ns}>

Pairs of namespace prefix and namespace URI.

=item C<$main::options{valid_extensions}> (default: ['.html'])

Lists of valid extensions.

=item C<$main::options{default_extension}> (default: .html)

The default extension.

=back

=head1 XSLT TEMPLATES

A source tree passed to XSLT is RDF/XML like this.

 <rdf:RDF>
   <rdf:Description rdf:about="/foo/bar/baz">
     <dcterms:title>page title</dcterms:title>
     <dcterms:modified>2011-03-02T17:20:00+09:00</dcterms:modified>
     <h:body rdf:parseType="Literal">
       <p>contents...</p>
       ...
     </h:body>
     <ex:prop1>literal value</ex:prop1>
     <ex:prop2 rdf:resource="http://URLref/value"/>
     ...
 </rdf:RDF>

These variables are available in XSLT templates.

=over 2

=item $path_info (e.g. /foo/bar/baz)

=item $dirname (e.g. /foo/bar)

=item $basename (e.g. baz)

=item $extension (e.g. .html)

=item $text_path (e.g. /path/to/text_dir/foo/bar/baz.txt)

=item $mtime (e.g. 1299054000)

=item $media_type (e.g. text/html)

=item $encoding (e.g. UTF-8)

=back

=head1 TEXT FILE FORMAT

Every text file takes a format described below.

 page title                    # <-- The first line is a title.
 prop1: "literal value"        # <-- The second and follorwing lines before
 prop2: <http://URLref/value>  #     a blank line are meta data section.

 contents...                   # <-- The page body in wiki notation.

Text files must be encoded in UTF-8 with line breaker LF (0x0A).

=head2 wiki notation

=head3 paragraph

 a normal line makes a paragraph

 ~a line starting with a tilde is also a paragraph

=head3 headings

 * heading lv.1
 ** heading lv.2
 *** heading lv.3
 **** heading lv.4
 ***** heading lv.5
 ****** heading lv.6

=head3 quotation

 > block-level quotation
 > block-level quotation
 >> block-level quotation quoted

=head3 horizontal rule

 ====

=head3 numbered list

 + item1
 + item2
 ++ item2-1

=head3 non-numbered list

 - item1
 - item2
 -- item2-1

=head3 definition list

 : term
 := description

=head3 formatted plain text (inline formatter can be used inside)

 >|
 formatted text
 |<

=head3 formatted plain text (verbatim)

 >||
 formatted text
 ||<

=head3 mathematical expression

 >|MATH|
 e = mc^{2}
 |MATH|<

=head3 table

 | |  A  |  B  |
 |1| A-1 | B-1 |
 |2| A-2 | B-2 |

 | caption     |c
 | |  A  |  B  |h
 |1| A-1 | B-1 |
 |2| A-2 | B-2 |
 | |  A  |  B  |f

=head3 inline

 **emphasized**
 ***strongly emphasized***
 $$code$$
 ``quoted text''
 ^{superscript}
 _{subscript}
 --<inserted text>--
 >--deleted text--<
 [[link_url]]
 [[link_url | title]]
 [IMG[image_url | alternative text]]
 [OBJ[data_url | alternative text]]
 {VERB}verbatim text{/VERB}

=head1 TIPS

=head2 install a CPAN module into a non-standard directory.

If you are not a root user and not granted a write permission to system directories, you can install CPAN modules into any directories with the following commands.

 $ libdir=/path/to/lib
 $ archdir=/path/to/arch
 $ man1dir=/path/to/man3
 $ man3dir=/path/to/man3
 $ bindir=/path/to/bin
 $ cd Foo-1.00
 $ perl Makefile.PL INSTALLSITELIB=$libdir INSTALLSITEARCH=$archdir \
            INSTALLSITEMAN1DIR=$man1dir INSTALLSITEMAN3DIR=$man3dir \
            INSTALLSITEBIN=$bindir
 $ make
 $ make install

=head2 static URL with mod_rewrite

The Apache's mod_rewrite module enables a CGI script to behave as if its pages were static HTML files, e.g. C<http://example.org/foo.html> instead of C<http://example.org/index.cgi/foo.html>.  Write this code snippet in F<.htaccess> to turn on redirection.

 <IfModule mod_rewrite.c>
   RewriteEngine On
   RewriteCond %{REQUEST_FILENAME} !-f
   RewriteCond %{REQUEST_FILENAME} !-d
   RewriteRule ^(.*) index.cgi/$1 [L,QSA,PT]
 </IfModule>


=head1 AUTHOR

Ikuo Ishikawa C<< <i.ishikawa.b06@gmail.com> >>

=head1 LICENSE

The MIT License

Copyright (c) 2010 Ikuo Ishikawa

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

See L<http://www.opensource.org/licenses/mit-license.php>.

=head1 REFERENCES

=over 1

=item blosxom L<http://www.blosxom.com/>

=back

=cut

