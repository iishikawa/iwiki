# vim: set ft=perl :

use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec::Functions qw/catfile/;
use IWiki::Util;


BEGIN {
    use_ok('IWiki::Util');
}

my $http_accept = "text/html, text/plain;q=0.9, */*;q=0.8";
my @candidates = qw|text/html text/plain|;
is(pref_accept($http_accept, @candidates), "text/html");

{
    my $http_accept = "text/html;q=0.9, text/plain;q=0.8 ,*/*;q=0.7";
    my @candidates = qw|text/html text/plain|;
    is(pref_accept($http_accept, @candidates), "text/html");
}

{
    my $http_accept = "text/*;q=0.9, application/xml;q=0.8 ,*/*;q=0.7";
    my @candidates = qw|text/html application/xml|;
    is(pref_accept($http_accept, @candidates), "text/html");
}

{
    my $http_accept = "text/*;q=0.9, application/xml;q=0.8 ,*/*;q=0.7";
    my @candidates = qw|text/html application/xml|;
    is(pref_accept($http_accept, @candidates), "text/html");
}

{
    my $http_accept = "hoge, fuga, piyo";
    my @candidates = qw|text/html application/xml|;
    is(pref_accept($http_accept, @candidates), "");
}

{
    my $http_accept = "hoge, fuga, piyo, text/html;q=0, application/xml;q=0";
    my @candidates = qw|text/html application/xml|;
    is(pref_accept($http_accept, @candidates), "");
}

is(html_escape(""), "");
is(html_escape(q/<a/), q/&lt;a/);
is(html_escape(q/&a/), q/&amp;a/);
is(html_escape(q/a>/), q/a&gt;/);
is(html_escape(q/"a"/), q/&quot;a&quot;/);
is(html_escape(q/'a'/),q/&#39;a&#39;/);
is(html_escape(q/<a href="b" id='c'>/),q/&lt;a href=&quot;b&quot; id=&#39;c&#39;&gt;/);

is(htmlout(qw|abc|),qq|<p>abc</p>\n|);
is(htmlout(qw|abc def|),qq|<p>abc<br>\ndef</p>\n|);

done_testing;

