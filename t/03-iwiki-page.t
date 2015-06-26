# vim: set ft=perl :

use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec::Functions qw/catfile canonpath/;
use IWiki::Page;


BEGIN {
    use_ok('IWiki');
    use_ok('IWiki::Parser');
    $ENV{TZ} or $ENV{TZ} = 'Asia/Tokyo';
}

my $text_dir = "./t/text";
my $user_ns = {
    rdf     => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
    dcterms => "http://purl.org/dc/terms/",
    ex      => "http://example.org/ns#",
};

sub canonicalize_xml {
    my $xml_string = shift;
    my $parser     = XML::LibXML->new();
    $parser->keep_blanks(0);
    my $doc        = $parser->parse_string($xml_string);
    return $doc->documentElement->toString(1);
}

# IWiki::Page->new
{
    my $title = "new() given no parameters";
    my $page     = IWiki::Page->new(text_dir => $text_dir);
    is($page->text_path, catfile($text_dir, "index.txt"), $title);
    is($page->path_info, "/", $title);
    is($page->dirname, "/", $title);
    is($page->basename, "", $title);
    is($page->extension, "", $title);
}

{
    my $title = "new() given path_info";
    my $page     = IWiki::Page->new(text_dir => $text_dir, path_info => '/index');
    is($page->text_path, catfile($text_dir, "index.txt"), $title);
    is($page->path_info, "/index", $title);
    is($page->dirname, "/", $title);
    is($page->basename, "index", $title);
    is($page->extension, "", $title);
}

{
    my $title = "new() given path_info and extension (which is ignored)";
    my $page     = IWiki::Page->new(text_dir => $text_dir, path_info => '/index', extension => '.xml');
    is($page->text_path, catfile($text_dir, "index.txt"), $title);
    is($page->path_info, "/index", $title);
    is($page->dirname, "/", $title);
    is($page->basename, "index", $title);
    is($page->extension, "", $title);
}

{
    my $title = "new() given text_path";
    my $text_path = catfile($text_dir, "index.txt");
    my $page     = IWiki::Page->new(text_dir => $text_dir, text_path => $text_path);
    is($page->text_path, $text_path, $title);
    is($page->path_info, "/index.html", $title);
    is($page->dirname, "/", $title);
    is($page->basename, "index", $title);
    is($page->extension, ".html", $title);
}

{
    my $title = "new() given text_path and extension";
    my $text_path = catfile($text_dir, "index.txt");
    my $page     = IWiki::Page->new(text_dir => $text_dir, text_path => $text_path, extension => '.xml');
    is($page->text_path, $text_path, $title);
    is($page->path_info, "/index.xml", $title);
    is($page->dirname, "/", $title);
    is($page->basename, "index", $title);
    is($page->extension, ".xml", $title);
}

# $page->text_path()
{
    my $title = "set text_path with text_path()";
    my $page     = IWiki::Page->new(text_dir => $text_dir);
    $page->text_path("$text_dir/a.txt");
    is($page->text_path, canonpath("$text_dir/a.txt"), $title);
    is($page->path_info, "/a.html", $title);
    is($page->dirname, "/", $title);
    is($page->basename, "a", $title);
    is($page->extension, ".html", $title);

    $title = "set new text_path with text_path()";
    $page->text_path("$text_dir/a/b.txt", $title);
    is($page->text_path, canonpath("$text_dir/a/b.txt", $title));
    is($page->path_info, "/a/b.html", $title);
    is($page->dirname, "/a/", $title);
    is($page->basename, "b", $title);
    is($page->extension, ".html", $title);

    {
        $title = "set text_path outside text_dir";
        local($SIG{__WARN__}) = sub {};
        $page->text_path("/tmp/a.txt");
        is($page->text_path, canonpath("/tmp/a.txt"), $title);
        is($page->path_info, undef, $title);
        is($page->dirname, undef, $title);
        is($page->basename, undef, $title);
        is($page->extension, undef, $title);
    }
}

# $page->path_info(), $page->_pathinfo_to_textpath()
{
    my $title = "set path_info with path_info()";
    my $page = IWiki::Page->new(text_dir => $text_dir);
    $page->path_info("/");
    is($page->text_path, catfile($text_dir, "index.txt"), $title);
    is($page->path_info, "/", $title);
    is($page->dirname, "/", $title);
    is($page->basename, "", $title);
    is($page->extension, "", $title);

    $title = "set path_info to '/a' (filename)";
    $page->path_info("/a");
    is($page->text_path, catfile($text_dir, "a.txt"), $title);
    is($page->path_info, "/a", $title);
    is($page->dirname, "/", $title);
    is($page->basename, "a", $title);
    is($page->extension, "", $title);

    $title = "set path_info to '/a.html' (filename with extension)";
    $page->path_info("/a.html");
    is($page->text_path, catfile($text_dir, "a.txt"), $title);
    is($page->path_info, "/a.html", $title);
    is($page->dirname, "/", $title);
    is($page->basename, "a", $title);
    is($page->extension, ".html", $title);

    $title = "set path_info to '/a/' (directory)";
    $page->path_info("/a/");
    is($page->text_path, catfile($text_dir, "a", "index.txt"), $title);
    is($page->path_info, "/a/", $title);
    is($page->dirname, "/a/", $title);
    is($page->basename, "", $title);
    is($page->extension, "", $title);

    $title = "set path_info to '/a/b' (directory and filename)";
    $page->path_info("/a/b");
    is($page->text_path, catfile($text_dir, "a", "b.txt"), $title);
    is($page->path_info, "/a/b", $title);
    is($page->dirname, "/a/", $title);
    is($page->basename, "b", $title);
    is($page->extension, "", $title);

    $title = "set path_info to '/a/b' (directory and filename with extension)";
    $page->path_info("/a/b.html");
    is($page->text_path, catfile($text_dir, "a", "b.txt"), $title);
    is($page->path_info, "/a/b.html", $title);
    is($page->dirname, "/a/", $title);
    is($page->basename, "b", $title);
    is($page->extension, ".html", $title);


    $title = "set path_info to ''";
    $page->path_info("");
    is($page->text_path, catfile($text_dir, "index.txt"), $title);
    is($page->path_info, "/", $title);
    is($page->dirname, "/", $title);
    is($page->basename, "", $title);
    is($page->extension, "", $title);
}

# $page->exists(), ->is_readable(), ->is_safe(), ->in_safe_directory(),
# ->has_directory(), ->is_ok(), ->is_forbidden()
{
    my $page = IWiki::Page->new(text_dir => $text_dir);
    $page->path_info("/");
    ok($page->exists, "index.txt exists");
    ok($page->is_readable, "index.txt is readable");
    ok($page->is_safe, "index.txt is safe");
    ok($page->in_safe_directory, "index.txt is in a safe directory");
    ok($page->is_ok, "/ is 200 OK");
    ok(! $page->is_forbidden, "/ is not 403 Forbidden");

    $page->path_info("/a.html");
    ok($page->exists, "a.txt exists");
    ok($page->is_readable, "a.txt is readable");
    ok($page->is_safe, "a.txt is safe");
    ok($page->in_safe_directory, "a.txt is in a safe directory");
    ok($page->is_ok, "/a.html is 200 OK");
    ok(! $page->is_forbidden, "/a.html is not 403 Forbidden");

    $page->path_info("/a.xml");
    ok($page->exists, "a.txt exists");
    ok($page->is_readable, "a.txt is readable");
    ok($page->is_safe, "a.txt is safe");
    ok($page->in_safe_directory, "a.txt is in a safe directory");
    ok(! $page->is_ok, "/a.xml is not 200 OK (not a valid extension)");
    ok(! $page->is_forbidden, "/a.xml is not 403 Forbidden (not a valid extension)");

    $page->path_info("/.a.html");
    ok($page->exists, ".a.txt exists");
    ok($page->is_readable, ".a.txt is readable");
    ok(! $page->is_safe, ".a.txt is not safe (dot file)");
    ok($page->in_safe_directory, ".a.txt is in a safe directory");
    ok(! $page->is_ok, "/a.html is not 200 OK");
    ok($page->is_forbidden, "/a.html is 403 Forbidden");

    $page->path_info("/z.html");
    ok(! $page->exists, "z.txt does not exist");
    ok(! $page->is_readable, "z.txt is not readable");
    ok($page->is_safe, "z.txt is safe");
    ok($page->in_safe_directory, "z.txt is in a safe directory");
    ok(! $page->is_ok, "/z.html is not 200 OK");
    ok(! $page->is_forbidden, "/z.html is not 403 Forbidden");

    $page->path_info("/.z.html");
    ok(! $page->exists, ".z.txt does not exist");
    ok(! $page->is_readable, ".z.txt is not readable");
    ok(! $page->is_safe, ".z.txt is not safe");
    ok($page->in_safe_directory, ".z.txt is not in a safe directory");
    ok(! $page->is_ok, "/.z.html is not 200 OK");
    ok(! $page->is_forbidden, "/.z.html is not 403 Forbidden");

    $page->path_info("/a/b.html");
    ok($page->exists, "a/b.txt exists");
    ok($page->is_readable ,"a/b.txt is readable");
    ok($page->is_safe ,"a/b.txt is safe");
    ok($page->in_safe_directory ,"a/b.txt is in a safe directory");
    ok($page->is_ok ,"/a/b.html is 200 OK");
    ok(! $page->is_forbidden ,"/a/b.html is not 403 Forbidden");

    $page->path_info("/a/.b.html");
    ok($page->exists, "a/.b.txt exists");
    ok($page->is_readable, "a/.b.txt is readable");
    ok(! $page->is_safe, "a/.b.txt is not safe (dot file)");
    ok($page->in_safe_directory, "a/.b.txt is in a safe directory");
    ok(! $page->is_ok, "/a/.b.html is not 200 OK");
    ok($page->is_forbidden, "/a/.b.html is 403 Forbidden");

    $page->path_info("/a/z.html");
    ok(! $page->exists, "a/z.txt does not exist");
    ok(! $page->is_readable, "a/z.txt is not readable");
    ok($page->is_safe, "a/z.txt is safe");
    ok($page->in_safe_directory, "a/z.txt is in a safe directory");
    ok(! $page->is_ok, "/a/z.html is not 200 OK");
    ok(! $page->is_forbidden, "/a/z.html is not 403 Forbidden");

    $page->path_info("/a/.z.html");
    ok(! $page->exists, "a/.z.txt does not exist");
    ok(! $page->is_readable, "a/.z.txt is not readable");
    ok(! $page->is_safe, "a/.z.txt is not safe (dot file)");
    ok($page->in_safe_directory, "a/.z.txt is in a safe directory");
    ok(! $page->is_ok, "/a/.z.html is not 200 OK");
    ok(! $page->is_forbidden, "/a/.z.html is not 403 Forbidden");

    $page->path_info("/.a/b.html");
    ok($page->exists, ".a/b.txt exists");
    ok($page->is_readable, ".a/b.txt is readable");
    ok(! $page->is_safe, ".a/b.txt is not safe (dot directory)");
    ok($page->in_safe_directory, ".a/b.txt is in a safe directory");
    ok(! $page->is_ok, "/.a/b.html is not 200 OK");
    ok($page->is_forbidden, "/.a/b.html is 403 Forbidden");

    $page->path_info("/.a/.b.html");
    ok($page->exists, ".a/.b.txt exists");
    ok($page->is_readable, ".a/.b.txt is readable");
    ok(! $page->is_safe, ".a/.b.txt is not safe (dot file and directory)");
    ok($page->in_safe_directory, ".a/.b.txt is in a safe directory");
    ok(! $page->is_ok, "/.a/.b.html is not 200 OK");
    ok($page->is_forbidden, "/.a/.b.html is 403 Forbidden");

    $page->path_info("/.a/z.html");
    ok(! $page->exists, ".a/z.txt does not exist");
    ok(! $page->is_readable, ".a/z.txt is not readable");
    ok(! $page->is_safe, ".a/z.txt is not safe (dot directory)");
    ok($page->in_safe_directory, ".a/z.txt is in a safe directory");
    ok(! $page->is_ok, "/.a/z.html is not 200 OK");
    ok(! $page->is_forbidden, "/.a/z.html is not 403 Forbidden");

    $page->path_info("/.a/.z.html");
    ok(! $page->exists, ".a/.z.txt does not exist");
    ok(! $page->is_readable, ".a/.z.txt is not readable");
    ok(! $page->is_safe, ".a/.z.txt is not safe (dot file and dot directory)");
    ok($page->in_safe_directory, ".a/.z.txt is in a safe directory");
    ok(! $page->is_ok, "/.a/.z.html is not 200 OK");
    ok(! $page->is_forbidden, "/.a/.z.html not 403 Forbidden");
}


use Time::Local qw/timelocal/;

# $self->to_xmldoc
{
    my $text_path = catfile($text_dir, "sample.txt");
    my $time = timelocal(0, 0, 0, 1, 1 - 1, 2010);
    utime $time, $time, $text_path;
    my $dt = DateTime->from_epoch(epoch => $time, time_zone => 'local');
    my $modified_text = DateTime::Format::W3CDTF->new->format_datetime($dt);
    my $page     = IWiki::Page->new(text_dir => $text_dir, text_path => $text_path);
    my $created_text = $modified_text;

    is($page->to_xmldoc->documentElement->toString(1),
        canonicalize_xml(<<EOD));
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about="/sample.html">
    <dcterms:title xmlns:dcterms="http://purl.org/dc/terms/">title</dcterms:title>
    <dcterms:modified xmlns:dcterms="http://purl.org/dc/terms/">${modified_text}</dcterms:modified>
    <dcterms:created xmlns:dcterms="http://purl.org/dc/terms/">${created_text}</dcterms:created>
    <h:body xmlns:h="http://www.w3.org/1999/xhtml" rdf:parseType="Literal">
      <p xmlns="http://www.w3.org/1999/xhtml">body</p>
    </h:body>
  </rdf:Description>
</rdf:RDF>
EOD

}

{
    my $text_path = catfile($text_dir, "sample2.txt");
    my $time = timelocal(0, 0, 0, 1, 1 - 1, 2010);
    utime $time, $time, $text_path;
    my $dt = DateTime->from_epoch(epoch => $time, time_zone => 'local');
    my $modified_text = DateTime::Format::W3CDTF->new->format_datetime($dt);
    my $page     = IWiki::Page->new(text_dir => $text_dir, text_path => $text_path, user_ns => $user_ns);
    my $created_text = $modified_text;

    is($page->to_xmldoc->documentElement->toString(1),
        canonicalize_xml(<<EOD));
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about="/sample2.html">
    <dcterms:title xmlns:dcterms="http://purl.org/dc/terms/">title</dcterms:title>
    <ex:prop1 xmlns:ex="http://example.org/ns#">string</ex:prop1>
    <ex:prop2 xmlns:ex="http://example.org/ns#" rdf:resource="http://example.org/"/>
    <dcterms:modified xmlns:dcterms="http://purl.org/dc/terms/">${modified_text}</dcterms:modified>
    <dcterms:created xmlns:dcterms="http://purl.org/dc/terms/">${created_text}</dcterms:created>
    <h:body xmlns:h="http://www.w3.org/1999/xhtml" rdf:parseType="Literal">
      <p xmlns="http://www.w3.org/1999/xhtml">body</p>
    </h:body>
  </rdf:Description>
</rdf:RDF>
EOD

}

{
    my $text_path = catfile($text_dir, "sample3.txt");
    my $modified_text = "2015-06-22T12:00:00+09:00";
    my $created_text = "2010-01-01T00:00:00+09:00";
    my $page     = IWiki::Page->new(text_dir => $text_dir, text_path => $text_path, user_ns => $user_ns);

    is($page->to_xmldoc->documentElement->toString(1),
        canonicalize_xml(<<EOD));
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about="/sample3.html">
    <dcterms:title xmlns:dcterms="http://purl.org/dc/terms/">title</dcterms:title>
    <dcterms:modified xmlns:dcterms="http://purl.org/dc/terms/">${modified_text}</dcterms:modified>
    <dcterms:created xmlns:dcterms="http://purl.org/dc/terms/">${created_text}</dcterms:created>
    <ex:prop1 xmlns:ex="http://example.org/ns#">string</ex:prop1>
    <ex:prop2 xmlns:ex="http://example.org/ns#" rdf:resource="http://example.org/"/>
    <h:body xmlns:h="http://www.w3.org/1999/xhtml" rdf:parseType="Literal">
      <p xmlns="http://www.w3.org/1999/xhtml">body</p>
    </h:body>
  </rdf:Description>
</rdf:RDF>
EOD

}

{
    my $text_path = catfile($text_dir, "sample4.txt");
    my $modified_text = "2015-06-22T12:00:00+09:00";
    my $time = timelocal(0, 0, 0, 1, 1 - 1, 2015);
    utime $time, $time, $text_path;
    my $dt = DateTime->from_epoch(epoch => $time, time_zone => 'local');
    my $created_text = DateTime::Format::W3CDTF->new->format_datetime($dt);
    my $page     = IWiki::Page->new(text_dir => $text_dir, text_path => $text_path, user_ns => $user_ns);

    is($page->to_xmldoc->documentElement->toString(1),
        canonicalize_xml(<<EOD));
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about="/sample4.html">
    <dcterms:title xmlns:dcterms="http://purl.org/dc/terms/">title</dcterms:title>
    <dcterms:modified xmlns:dcterms="http://purl.org/dc/terms/">${modified_text}</dcterms:modified>
    <ex:prop1 xmlns:ex="http://example.org/ns#">string</ex:prop1>
    <ex:prop2 xmlns:ex="http://example.org/ns#" rdf:resource="http://example.org/"/>
    <dcterms:created xmlns:dcterms="http://purl.org/dc/terms/">${created_text}</dcterms:created>
    <h:body xmlns:h="http://www.w3.org/1999/xhtml" rdf:parseType="Literal">
      <p xmlns="http://www.w3.org/1999/xhtml">body</p>
    </h:body>
  </rdf:Description>
</rdf:RDF>
EOD

}

{
    my $text_path = catfile($text_dir, "sample5.txt");
    my $time = timelocal(0, 0, 0, 1, 1 - 1, 2015);
    utime $time, $time, $text_path;
    my $dt = DateTime->from_epoch(epoch => $time, time_zone => 'local');
    my $modified_text = DateTime::Format::W3CDTF->new->format_datetime($dt);
    my $created_text = "2010-01-01T00:00:00+09:00";
    my $page     = IWiki::Page->new(text_dir => $text_dir, text_path => $text_path, user_ns => $user_ns);

    is($page->to_xmldoc->documentElement->toString(1),
        canonicalize_xml(<<EOD));
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about="/sample5.html">
    <dcterms:title xmlns:dcterms="http://purl.org/dc/terms/">title</dcterms:title>
    <dcterms:created xmlns:dcterms="http://purl.org/dc/terms/">${created_text}</dcterms:created>
    <ex:prop1 xmlns:ex="http://example.org/ns#">string</ex:prop1>
    <ex:prop2 xmlns:ex="http://example.org/ns#" rdf:resource="http://example.org/"/>
    <dcterms:modified xmlns:dcterms="http://purl.org/dc/terms/">${modified_text}</dcterms:modified>
    <h:body xmlns:h="http://www.w3.org/1999/xhtml" rdf:parseType="Literal">
      <p xmlns="http://www.w3.org/1999/xhtml">body</p>
    </h:body>
  </rdf:Description>
</rdf:RDF>
EOD

}
done_testing;
