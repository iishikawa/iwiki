# vim: set ft=perl :

use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec::Functions qw/catfile/;
use IWiki;
use IWiki::Page;
use Data::Dumper;

my $debug = 1;
my $template_dir = "./t/template";
my $cache_dir = "/tmp";
my $use_cache = 0;
my $text_dir = "./t/text";

BEGIN {
    use_ok('IWiki');
}


my $iwiki = IWiki->new(debug => $debug,
    text_dir => $text_dir,
    template_dir => $template_dir,
    cache_dir => $cache_dir,
    use_cache => $use_cache);

done_testing;
