use strict;
use warnings;
use utf8;

use Test::More;

use XML::LibXML;
use IWiki;
use IWiki::Parser;
use IWiki::Parser::BasicTagSet;

# dependency check
BEGIN {
    use_ok('XML::LibXML');
}


my %ns = (
    h       => "http://www.w3.org/1999/xhtml",
);

# debug functions
sub wikitext_to_xml {
    my $wikitext = shift;
    my $wikip    = IWiki::Parser->new(IWiki::Parser::BasicTagSet->new);
    my $doc      = XML::LibXML::Document->new("1.0", "utf-8");
    my $root     = $doc->createElementNS($ns{h}, 'div');
    $doc->setDocumentElement($root);
    my $fragment = $wikip->parse(\$wikitext)->fragment;
    $root->appendChild($fragment);
    return $doc->toString(1);
}

sub canonicalize_xml {
    my $xml_string = shift;
    my $parser     = XML::LibXML->new();
    $parser->keep_blanks(0);
    my $doc        = $parser->parse_string($xml_string);
    return $doc->toString(1);
}

sub diff_wiki_xml {
    my $wikitext = shift;
    my $expected = shift;
    my $title    = shift || undef;
    is(wikitext_to_xml($wikitext), canonicalize_xml($expected), $title);
}

### document

diff_wiki_xml("", <<EOD, "absolutely empty document");
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}"/>
EOD


diff_wiki_xml("\n\n", <<EOD, "empty document containing blank lines");
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}"/>
EOD


### block-level elements

diff_wiki_xml(<<EOD,<<EOD,'paragraph of coutinuous lines');
p
~ p
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <p>p
~ p</p>
</div>
EOD


diff_wiki_xml(<<EOD,<<EOD,'horizontal lines');
====
====

====
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <hr/>
  <hr/>
  <hr/>
</div>
EOD


diff_wiki_xml(<<EOD,<<EOD,'heading of multiple lines');
* h1
heading lv.1

** h2
heading lv.2
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <h1>h1
heading lv.1</h1>
  <h2>h2
heading lv.2</h2>
</div>
EOD


diff_wiki_xml(<<EOD,<<EOD,'preformatted text');
>|
pre
pre
|<
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <pre>pre
pre</pre>
</div>
EOD


diff_wiki_xml(<<EOD,<<EOD,'block-level quotes followed by a new block');
> blockquote p
> blockquote p
* h1
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <blockquote>
    <p>blockquote p
blockquote p</p>
  </blockquote>
  <h1>h1</h1>
</div>
EOD


diff_wiki_xml(<<EOD,<<EOD,'block-level quotes separated by a blank line');
> blockquote[1] p
> blockquote[1] p

> blockquote[2] p
> blockquote[2] p
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <blockquote>
    <p>blockquote[1] p
blockquote[1] p</p>
  </blockquote>
  <blockquote>
    <p>blockquote[2] p
blockquote[2] p</p>
  </blockquote>
</div>
EOD



diff_wiki_xml(<<EOD,<<EOD,'nested block-level quotes');
> blockquote[1] p
> blockquote[1] p
>
>> blockquote blockquote p
>> blockquote blockquote p
>
> blockquote[2] p
> blockquote[2] p
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <blockquote>
    <p>blockquote[1] p
blockquote[1] p</p>
    <blockquote>
      <p>blockquote blockquote p
blockquote blockquote p</p>
    </blockquote>
    <p>blockquote[2] p
blockquote[2] p</p>
  </blockquote>
</div>
EOD


diff_wiki_xml(<<EOD,<<EOD,'pre in block-level quoted');
>>|
>blockquote pre
>blockquote pre
>|<
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <blockquote>
    <pre>blockquote pre
blockquote pre</pre>
  </blockquote>
</div>
EOD


diff_wiki_xml(<<EOD,<<EOD,'pre terminated by a blank line');
>>|
>blockquote pre
>blockquote pre

~ p
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <blockquote>
    <pre>blockquote pre
blockquote pre</pre>
  </blockquote>
  <p>p</p>
</div>
EOD


### list element

diff_wiki_xml(<<EOD,<<EOD,'nested list');
+item1
+item2
++item2-1
++item2-2
+++item2-2-1
+item3
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <ol>
    <li>item1</li>
    <li>item2<ol>
      <li>item2-1</li>
      <li>item2-2<ol>
      <li>item2-2-1</li></ol></li></ol></li>
    <li>item3</li>
  </ol>
</div>
EOD


diff_wiki_xml(<<EOD,<<EOD,'nested list (combination of ul and ol)');
+item1
+item2
++item2-1
+item3
+-item3-1
++item3-1
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <ol>
    <li>item1</li>
    <li>item2<ol>
      <li>item2-1</li></ol></li>
    <li>item3<ul>
      <li>item3-1</li></ul><ol>
      <li>item3-1</li></ol></li>
  </ol>
</div>
EOD


diff_wiki_xml(<<EOD,<<EOD,'nested list without a top-level item');
+++item1-1-1
++item1-2
+item2
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <ol>
    <li>
      <ol>
        <li>
          <ol>
            <li>item1-1-1</li>
          </ol>
        </li>
        <li>item1-2</li>
      </ol>
    </li>
    <li>item2</li>
  </ol>
</div>
EOD


diff_wiki_xml(<<EOD,<<EOD,'definition list');
:dl dt
:=dl dd
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <dl>
    <dt>dl dt</dt>
    <dd>dl dd</dd>
  </dl>
</div>
EOD


diff_wiki_xml(<<EOD,<<EOD,'nested definition list');
:dl dt
:=dl dd[1]
:=:dl dd[2] dl dt
:=:=dl dd[2] dl dd
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <dl>
    <dt>dl dt</dt>
    <dd>dl dd[1]</dd>
    <dd>
      <dl>
        <dt>dl dd[2] dl dt</dt>
        <dd>dl dd[2] dl dd</dd>
      </dl>
    </dd>
  </dl>
</div>
EOD


### table element

diff_wiki_xml(<<EOD,<<EOD,'table with caption, header, footer and body');
|caption|c
||~A|~B|hf
|1|A-1|B-1|b
|2|A-2|B-2|
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <table>
    <caption>caption</caption>
    <thead>
      <tr>
        <td/><th>A</th><th>B</th>
      </tr>
    </thead>
    <tfoot>
      <tr>
        <td/><th>A</th><th>B</th>
      </tr>
    </tfoot>
    <tbody>
      <tr>
        <td>1</td><td>A-1</td><td>B-1</td>
      </tr>
      <tr>
        <td>2</td><td>A-2</td><td>B-2</td>
      </tr>
    </tbody>
  </table>
</div>
EOD


diff_wiki_xml(<<EOD,<<EOD,'table containing malformed lines');
|A     ignored
|**|** ignored
|1|2|
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <table>
    <tbody>
      <tr>
        <td>1</td><td>2</td>
      </tr>
    </tbody>
  </table>
</div>
EOD


diff_wiki_xml(<<EOD,<<EOD,'empty table with all lines malformed');
|A     ignored
|**|** ignored
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <table>
    <tbody>
      <tr>
        <td/>
      </tr>
    </tbody>
  </table>
</div>
EOD


### inline elements

diff_wiki_xml(<<EOD,<<EOD,'code: opened and closed with the same string');
~ \$\$code1\$\$ text \$\$code2\$\$
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <p><code>code1</code> text <code>code2</code></p>
</div>
EOD


diff_wiki_xml(<<EOD,<<EOD,'code');
~ \$\$code1\$\$ text \$\$code2\$\$ text
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <p><code>code1</code> text <code>code2</code> text</p>
</div>
EOD


diff_wiki_xml(<<EOD,<<EOD,'quote: closing string is omitted');
~ text ````quote
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <p>text <q><q>quote</q></q></p>
</div>
EOD


diff_wiki_xml(<<EOD,<<EOD,'nested quote');
~ ``quote1 ``quote1-1'' quote1''
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <p>
    <q>quote1 <q>quote1-1</q> quote1</q>
  </p>
</div>
EOD


diff_wiki_xml(<<EOD,<<EOD,'em: closed with ***, not starting strong');
~ **em***text
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <p><em>em</em>*text</p>
</div>
EOD


diff_wiki_xml(<<EOD,<<EOD,'em in strong');
~ ***strong **em***text
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <p>
    <strong>strong <em>em</em>*text</strong>
  </p>
</div>
EOD


diff_wiki_xml(<<EOD,<<EOD,'em in a cell');
|text**em|em**text|
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <table>
    <tbody>
      <tr>
        <td>text<em>em|em</em>text</td>
      </tr>
    </tbody>
  </table>
</div>
EOD


diff_wiki_xml(<<EOD,<<EOD,'links');
~ [[http://example.org]]

~ [[http://example.org]]

~ [[http://example.org|example.org]]

~ [[ http://example.org | example.org ]]

~ [IMG[ http://example.org/image.png | image ]]

~ [OBJ[ http://example.org/image.png | image ]]
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <p><a href="http://example.org">http://example.org</a></p>
  <p><a href="http://example.org">http://example.org</a></p>
  <p><a href="http://example.org">example.org</a></p>
  <p><a href="http://example.org">example.org</a></p>
  <p><img src="http://example.org/image.png" alt="image"/></p>
  <p><object data="http://example.org/image.png">image</object></p>
</div>
EOD


diff_wiki_xml(<<EOD,<<EOD,'verbatim');
~ {VERB}**hoge**{/VERB}
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <p><span>**hoge**</span></p>
</div>
EOD


### blockcode

diff_wiki_xml(<<EOD,<<EOD,'blockcode');
>||
pre code
pre code
||<
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <pre>
    <code>pre code
pre code</code>
  </pre>
</div>
EOD


### option : trans_nl

diff_wiki_xml(<<EOD,<<EOD,'math expression');
>|MATH|
div
div
|MATH|<
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <div>div<br/>div</div>
</div>
EOD


### attributes

diff_wiki_xml(<<EOD,<<EOD,'@id and @xml:lang');
*<#myid> h1[id=myid]

**<\@en> h2[xml:lang=en]
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <h1 id="myid">h1[id=myid]</h1>
  <h2 xml:lang="en">h2[xml:lang=en]</h2>
</div>
EOD


diff_wiki_xml(<<EOD,<<EOD,'@class');
><.class1> blockquote[class=class1] p
> blockquote p
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <blockquote class="class1">
    <p>blockquote[class=class1] p
blockquote p</p>
  </blockquote>
</div>
EOD


diff_wiki_xml(<<EOD,<<EOD,'general attributes');
>|<class="code">
pre[class=code]
pre
|<
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <pre class="code">pre[class=code]
pre</pre>
</div>
EOD

diff_wiki_xml(<<EOD,<<EOD,'general attributes');
*<xml:lang="en"> h1[xml:lang="en"]
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <h1 xml:lang="en">h1[xml:lang="en"]</h1>
</div>
EOD


### open file

{
    my $textpath   = "t/text/index.txt";
    my $expected = <<"EOD";
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <p>This is /index.txt.</p>
</div>
EOD
    open my $fh, '<:encoding(utf8)', $textpath
        or die $!;
    <$fh>; <$fh>;
    my $wikip    = IWiki::Parser->new(IWiki::Parser::BasicTagSet->new);
    my $doc      = XML::LibXML::Document->new("1.0", "utf-8");
    my $root     = $doc->createElementNS($ns{h}, 'div');
    $doc->setDocumentElement($root);
    my $fragment = $wikip->parse($fh)->fragment;
    $root->appendChild($fragment);
    is($doc->toString(1), canonicalize_xml($expected), 'parse a text file');
    close $fh;
}

{
    my $lines = <<"EOD";
para
EOD
    my $expected = <<"EOD";
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <p>para</p>
</div>
EOD
    my $wikip    = IWiki::Parser->new();
    my $doc      = XML::LibXML::Document->new("1.0", "utf-8");
    my $root     = $doc->createElementNS($ns{h}, 'div');
    $doc->setDocumentElement($root);
    my $fragment = $wikip->parse(\$lines)->fragment;
    $root->appendChild($fragment);
    is($doc->toString(1), canonicalize_xml($expected), 'parse a scalar text');
}

## character/entity reference

diff_wiki_xml(<<EOD,<<EOD,'character/entity reference');
alpha &#945; &#x03B1; &alpha;

bang &bang;

undefined &hoge;

surrogate block &#xFFFE; &#xFFFF;

non unicode character &#x110000;
EOD
<?xml version="1.0" encoding="utf-8"?>
<div xmlns="$ns{h}">
  <p>alpha \x{03B1} \x{03B1} \x{03B1}</p>
  <p>bang !</p>
  <p>undefined &amp;hoge;</p>
  <p>surrogate block &amp;#xFFFE; &amp;#xFFFF;</p>
  <p>non unicode character &amp;#x110000;</p>
</div>
EOD

done_testing;

