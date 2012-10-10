# vim: set ft=perl :

package IWiki::Util;
use strict;
use warnings;
use utf8;

our $VERSION = '0.0.1';

use Carp qw/croak/;

use base qw/Exporter/;
our @EXPORT      = qw/accept_qvalue pref_accept htmlout html_escape canonicalize_header/;
our @EXPORT_OK   = qw//;
our %EXPORT_TAGS = (
    all => [@EXPORT, @EXPORT_OK],
);



# IWiki::Util::accept_qvalue($accept_ref, $media_type): returns qvalue in HTTP_ACCEPT
sub accept_qvalue {
    my $accept_ref = shift || croak "accept_qvalue(): an argument missing";
    my $ts      = shift || croak "accept_qvalue(): an argument missing";
    my ($t, $s) = split /\//, $ts;
    $t and $s or croak "accept_qvalue(): $ts is not like a media type";
    my @ts = grep {
      ($_->[0] eq $t or $_->[0] eq '*') and ($_->[1] eq $s or $_->[1] eq '*')
    } @{$accept_ref};
    @ts ? $ts[0][2] : 0;
}

# IWiki::Util::pref_accept($http_accept, $media_type1, $media_type2, ...): return the most preferable media type
sub pref_accept {
    my @accept =
    sort { $b->[2] <=> $a->[2] }
    map {
        my @ps               = split /\s*;\s*/, $_;
        my ($type, $subtype) = split /\//, $ps[0];
        my $qvalue           = (split /\s*=\s*/, ((grep /\Aq\s*=/, @ps[1..$#ps])[0] || 'q=1'))[1];
       [ $type || "", $subtype || "", $qvalue ];
        } split /\s*,\s*/, shift;
    (sort { accept_qvalue(\@accept, $b) <=> accept_qvalue(\@accept, $a) }
     grep { accept_qvalue(\@accept, $_) > 0 } @_)[0] || "";
}

# IWiki::Util::html_escape($string): return the escaped HTML string.
sub html_escape {
    local $_ = shift;
    s/&/&amp;/gms; s/</&lt;/gms; s/>/&gt;/gms;
    s/"/&quot;/gsm; s/'/&#39;/gsm;
    return $_;
}

# IWiki::Util::htmlout($line1, $line2, ...): return the escaped HTML string surrounded with <p>.
sub htmlout {
    return "<p>".join("<br>\n", map {html_escape $_} @_)."</p>\n";
}

# IWiki::Util::canonicalize_header($field)
sub canonicalize_header {
    join('-', map { ucfirst($_) } split(/[-_]/, $_[0]));
}

1;

