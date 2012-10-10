package Regexp::Common::URIRef::RFC3986;

use Regexp::Common qw/pattern clean no_defaults/;

use strict;
use warnings;

use vars qw/$VERSION/;
$VERSION = '2010070601';

use vars qw/@EXPORT @EXPORT_OK %EXPORT_TAGS @ISA/;
use Exporter;
@ISA = qw/Exporter/;


my %vars;

BEGIN {
    $vars{low}     = [qw /
$ALPHA
$DIGIT
$HEXDIG
$pct_encoded
$unreserved
$gen_delims
$sub_delims
$reserved
$pchar
$userinfo
    /];
    $vars{parts}   = [qw /
$query
$fragment
$segment
$segment_nz
$segment_nz_nc
$path_abempty
$path_absolute
$path_noscheme
$path_rootless
$path_empty
$path
    /];
    $vars{connect} = [qw /
$dec_octet
$IPv4address
$h16
$ls32
$IPv6address
$IPvFuture
$IP_literal
$reg_name
$host
$port
$authority
    /];
    $vars{URI}     = [qw /
$scheme
$hier_part
$URI
$relative_part
$relative_ref
$absolute_URI
$URI_reference
    /];
}

use vars map {@$_} values %vars;

@EXPORT      = ();
@EXPORT_OK   = map {@$_} values %vars;
%EXPORT_TAGS = (%vars, ALL => [@EXPORT_OK]);

# RFC 3986, base definitions.
$ALPHA         = qr,[a-zA-Z],;
$DIGIT         = qr,[0-9],;
$HEXDIG        = qr,[0-9A-F],;
$pct_encoded   = qr,%$HEXDIG{2},;
$unreserved    = qr,[a-zA-Z0-9\-._~],;
$gen_delims    = qr,[:/?#[\]@],;
$sub_delims    = qr,[!\$&'()*+\,;=],;
$reserved      = qr,$gen_delims|$sub_delims,;
$pchar         = qr,$unreserved|$pct_encoded|$sub_delims|[:@],;
$userinfo      = qr,(?:$unreserved|$pct_encoded|$sub_delims|:)*,;


$query         = qr,(?:$pchar|[/?])*,;
$fragment      = qr,(?:$pchar|[/?])*,;
$segment       = qr,$pchar*,;
$segment_nz    = qr,$pchar+,;
$segment_nz_nc = qr,(?:$unreserved|$pct_encoded|$sub_delims|@)+,;
$path_abempty  = qr,(?:/$segment)*,;
$path_absolute = qr,/(?:$segment_nz(?:/$segment)*)?,;
$path_noscheme = qr,$segment_nz_nc(?:/$segment)*,;
$path_rootless = qr,$segment_nz(?:/$segment)*,;
$path_empty    = "";
$path          = qr,$path_abempty|$path_absolute|$path_noscheme|$path_rootless|$path_empty,;


$dec_octet     = qr,\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5],;
$IPv4address   = qr,$dec_octet\.$dec_octet\.$dec_octet\.$dec_octet,;
$h16           = qr,(?:$HEXDIG){1\,4},;
$ls32          = qr,$h16:$h16|$IPv4address,;
$IPv6address   = qr,       (?:$h16:){6}$ls32
|                        ::(?:$h16:){5}$ls32
|                   $h16?::(?:$h16:){4}$ls32
| (?:(?:$h16:){\,1}$h16)?::(?:$h16:){3}$ls32
| (?:(?:$h16:){\,2}$h16)?::(?:$h16:){2}$ls32
| (?:(?:$h16:){\,3}$h16)?::   $h16:    $ls32
| (?:(?:$h16:){\,4}$h16)::             $ls32
| (?:(?:$h16:){\,5}$h16)::             $h16
| (?:(?:$h16:){\,6}$h16)::,x;
$IPvFuture     = qr,v$HEXDIG+\.(?:$unreserved|$sub_delims|:)+,;
$IP_literal    = qr,\[(?:$IPv6address|$IPvFuture)\],;
$reg_name      = qr,(?:$unreserved|$pct_encoded|$sub_delims)*,;
$host          = qr,$IP_literal|$IPv4address|$reg_name,;
$port          = qr,\d*,;
$authority     = qr,(?:$userinfo@)?$host(?::$port)?,;


$scheme        = qr,(?#scheme)[a-zA-Z][a-zA-Z0-9+\-.]*(?#/scheme),;
$hier_part     = qr,//$authority$path_abempty|$path_absolute|$path_rootless|$path_empty,;
$URI           = qr,$scheme:$hier_part(?:\?$query)?(?:\#$fragment)?,;
$relative_part = qr,//$authority$path_abempty|$path_absolute|$path_noscheme|$path_empty,;
$relative_ref  = qr,$relative_part(?:\?$query)?(?:\#$fragment)?,;
$absolute_URI  = qr,$scheme:$hier_part(?:\?$query)?,;
$URI_reference = qr,$URI|$relative_ref,;


1;

__END__

=pod

=head1 NAME

Regexp::Common::URIRef::RFC3986 -- Definitions from RFC3986;

=head1 SYNOPSIS

    use Regexp::Common::URIRef::RFC3986 qw/:ALL/;

=head1 DESCRIPTION

This package exports definitions from RFC3986, which obsolets RFC2396.  (I hope) it replaces Damian Conway's Regexp::Common::URI and Regexp::Common::URI::RFC2396.

The major difference RFC3986 and RFC2396 is that URI (not URI reference) in RFC3986 can have '#fragment' and so does relative-ref (relative URI). See the RFC documentation for more detail.

=head1 REFERENCES

=over 4

=item B<[RFC 3986]>

T. Berners-Lee, R. Fielding, and L. Masinter, I<Uniform Resource Identifier (URI): Generic Syntax>. January 2005.

=item B<[RFC 2234]>

D. Crocker, Ed., P. Overell, I<Augmented BNF for Syntax Specifications: ABNF>

=back

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

=head1 SEE ALSO

L<Regexp::Common::URI::RFC2396>

=cut
