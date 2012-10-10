package Regexp::Common::URIRef;

use Regexp::Common                  qw/pattern clean no_defaults/;
use Regexp::Common::URIRef::RFC3986 qw/$scheme $userinfo $host $port $path $query $fragment $URI $relative_part $relative_ref $absolute_URI $URI_reference/;

use strict;
use warnings;

use Exporter;
use vars qw/@ISA/;
@ISA       = qw/Exporter/;

use vars qw/$VERSION/;
$VERSION = '2010070601';

pattern name    => [qw (URIRef)],
        create  => sub {my $uri_ref = $URI_reference;
                           $uri_ref =~ s/\(\?k:/(?:/g;
                      "(?k:$uri_ref)";
        },
        ;

pattern name    => [qw (URIRef URI), '-scheme'],
        create  => sub {my $uri_ref = $URI;
                        my $scheme  = $_[1]->{-scheme} || undef;
                           defined $scheme
                               and $uri_ref =~ s,\Q(?#scheme)\E.*?\Q(?#/scheme)\E,$scheme,g;
                           $uri_ref =~ s/\(\?k:/(?:/g;
                      "(?k:$uri_ref)";
        },
        ;

pattern name    => [qw (URIRef relative_ref)],
        create  => sub {my $uri_ref = $relative_ref;
                           $uri_ref =~ s/\(\?k:/(?:/g;
                      "(?k:$uri_ref)";
        },
        ;

1;

__END__

=pod

=head1 NAME

Regexp::Common::URIRef -- provide patterns for URI references.

=head1 SYNOPSIS

    use Regexp::Common qw/URIRef/;

    $str =~ /$RE{URIRef}/       # check $str is a URI reference
    $str =~ /$RE{URIRef}{URI}/  # check $str is a URI
    $str =~ /$RE{URIRef}{URI}{-scheme => 'http'}/
                                # check $str is a URI with http scheme
    $str =~ /$RE{URIRef}{relative_ref}/
                                # check $str is a relative URI

=head1 DESCRIPTION

The package provides regular expressions which match URI references defined in RFC 3986.

=head1 REFERENCES

=over 4

=item B<[RFC 3986]>

T. Berners-Lee, R. Fielding, and L. Masinter, I<Uniform Resource Identifier (URI): Generic Syntax>. January 2005.

=item B<[RFC 2234]>

D. Crocker, Ed., P. Overell, I<Augmented BNF for Syntax Specifications: ABNF>

=back

=head1 SEE ALSO

L<Regexp::Common::URI>, L<Regexp::Common>

=head1 AUTHOR

Ikuo Ishikawa (i.ishikawa.b06@gmail.com)

=head1 ORIGINAL AUTHOR

Damian Conway (damian@conway.org)

=head1 LICENSE and COPYRIGHT

The MIT License

Copyright (c) 2010 Ikuo Ishikawa

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

See L<http://www.opensource.org/licenses/mit-license.php>

=cut
