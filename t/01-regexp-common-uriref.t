use strict;
use warnings;

use Test::More;

use Regexp::Common qw/URIRef/;
use Data::Dumper;

# dependency check
BEGIN {
    use_ok('Regexp::Common::URIRef');
    use_ok('Regexp::Common::URIRef::RFC3986');
}


# $RE{URIRef}, $RE{URIRef}{URI}, $RE{URIRef}{relative_ref}
my @tests = (
    #['test_string', URIRef, URI, relative_ref]
    ['scheme://host', 1, 1, 0],
    ['scheme://127.0.0.1', 1, 1, 0],
    ['scheme://user:pass@host', 1, 1, 0],
    ['scheme://host:8080', 1, 1, 0],
    ['scheme://user:pass@host:8080', 1, 1, 0],
    ['scheme:/path_absolute', 1, 1, 0],
    ['scheme:path_rootless', 1, 1, 0],
    ['scheme:', 1, 1, 0],
    ['scheme://host/foo', 1, 1, 0],
    ['scheme://host/foo/bar', 1, 1, 0],
    ['scheme://host/foo/bar?', 1, 1, 0],
    ['scheme://host/foo/bar?query-._~!$&\'()*+,;=:@/?', 1, 1, 0],
    ['scheme://host/foo/bar#fragment-._~!$&\'()*+,;=:@/?', 1, 1, 0],
    ['//host', 1, 0, 1],
    ['/path_absolute', 1, 0, 1],
    ['path_rootless', 1, 0, 1],
    ['', 1, 0, 1],
    ['あ', 0, 0, 0],
);

for my $test (@tests) {
    if ($test->[1]) {
        like($test->[0] => qr/\A$RE{URIRef}\z/,
            "$test->[0] is a URI reference.");
    }
    else {
        unlike($test->[0] => qr/\A$RE{URIRef}\z/,
            "$test->[0] is not a URI reference.");
    }

    if ($test->[2]) {
        like($test->[0] => qr/\A$RE{URIRef}{URI}\z/,
            "$test->[0] is a URI.");
    }
    else {
        unlike($test->[0] => qr/\A$RE{URIRef}{URI}\z/,
            "$test->[0] is not a URI.");
    }

    if ($test->[3]) {
        like($test->[0] => qr/\A$RE{URIRef}{relative_ref}\z/,
            "$test->[0] is a relative URI.");
    }
    else {
        unlike($test->[0] => qr/\A$RE{URIRef}{relative_ref}\z/,
            "$test->[0] is not a relative URI.");
    }
}

# $RE{URIRef}{URI}{-scheme => ...}
like('http://example.org'
    => qr/\A$RE{URIRef}{URI}{-scheme => 'http'}\z/);
like('http://example.org'
    => qr/\A$RE{URIRef}{URI}{-scheme => '(?:http|https)'}\z/);
unlike('ftp://example.org'
    => qr/\A$RE{URIRef}{URI}{-scheme => 'http'}\z/);
like('http:/example.org'
    => qr/\A$RE{URIRef}{URI}{-scheme => 'http'}\z/);
like('http:example.org'
    => qr/\A$RE{URIRef}{URI}{-scheme => 'http'}\z/);

done_testing;

