# vim: set ft=perl :

package IWiki::Page;
use strict;
use warnings;
use utf8;

our $VERSION = '0.0.1';

use FindBin;
use Carp                  qw/croak carp/;
use File::stat            qw/stat/;
use File::Spec::Functions qw/catfile canonpath splitpath splitdir/;
use File::Basename        qw/fileparse/;
use DateTime;
use DateTime::Format::W3CDTF;
use DBI;
use XML::LibXML;
use IWiki;
use IWiki::Parser;
use IWiki::Parser::BasicTagSet;


my $text_dir          = catfile($FindBin::Bin, 'text');
my @valid_extensions  = qw/.html/;
my $fileenc           = 'utf8';
my $default_index     = 'index';
my $default_extension = '.html';
my $cache_dir         = catfile($FindBin::Bin, 'cache');
my $use_cache         = 0;
my $db_filename       = 'cache.sqlite';

my %ns = (
    h       => "http://www.w3.org/1999/xhtml",
    rdf     => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
    dcterms => "http://purl.org/dc/terms/",
);

# IWiki::Page->new([key1 => value1, key2 => value2, ...]): constructor
sub new {
    my $class  = shift || croak "new(): no class name";
    my $self   = bless {
        path_info => undef,
        dirname   => undef,
        basename  => undef,
        extension => undef,
        text_path => undef,
        text_dir  => canonpath($text_dir),
        fileenc   => $fileenc,
        mtime     => undef,
        xmldoc    => undef,
        user_ns   => {},
        valid_extensions  => \@valid_extensions,
        default_extension => $default_extension,
        cache_dir         => $cache_dir,
        use_cache         => $use_cache,
        @_} => $class;
    if (not defined $self->{path_info} and not defined $self->{text_path}) {
        $self->path_info(defined $ENV{PATH_INFO} && $ENV{PATH_INFO} ne ''
            ? $ENV{PATH_INFO} : '/');
    }
    elsif (not defined $self->{path_info} and defined $self->{text_path}) {
        $self->text_path($self->{text_path});

    }
    else {
        $self->path_info($self->{path_info});
    }

    if ($self->{use_cache}) {
        my $db_file = catfile($self->{cache_dir}, $db_filename);
        $self->{dbh} = DBI->connect("dbi:SQLite:dbname=$db_file",
            undef, undef, {
                RaiseError => 1,
                PrintError => 1,
                AutoCommit => 1,
            });

        my $count = $self->{dbh}->selectrow_array(qq{
SELECT count(*) FROM sqlite_master
  WHERE type='table' AND name='pagexml';
});
        if ($count == 0) {
            $self->{dbh}->do(qq{
CREATE TABLE pagexml (
  text_path,
  mtime,
  xmldoc_text,
  last_cached,
  PRIMARY KEY(text_path)
);
        });
        }
    }

    return $self;
}

sub DESTORY {
    my $self = shift;
    $self->{dbh}->disconnect;
}

# $self->_get_pagexml_from_db($text_path)
sub _get_pagexml_from_db {
    my $self = shift;
    croak "_get_pagexml_from_db(): cache is disabled"
        unless $self->{use_cache};
    my $pagexml;
    my $sth = $self->{dbh}->prepare(qq{
SELECT mtime, xmldoc_text, last_cached
FROM pagexml
WHERE text_path = ?;
        });
    $sth->execute($_[0] || $self->{text_path});
    if (my @pd = $sth->fetchrow_array) {
        $pagexml = {
            mtime       => $pd[0],
            xmldoc_text => $pd[1],
            last_cached => $pd[2],
        };
    }
    $sth->finish;
    $pagexml;
}

# $self->_set_pagexml_into_db($pagexml, $text_path)
sub _set_pagexml_into_db {
    my $self = shift;
    croak "_set_pagexml_from_db(): cache is disabled"
        unless $self->{use_cache};
    my ($pagexml, $text_path) = @_;
    $text_path = $self->{text_path} unless defined $text_path;

    my $count = $self->{dbh}->selectrow_array(qq{
SELECT count(*)
FROM pagexml
WHERE text_path = ?;
}, undef, $text_path);
    if ($count == 0) {
        my $sth = $self->{dbh}->prepare(qq{
INSERT INTO pagexml VALUES(
  ?, ?, ?, ?
);
        });
        $sth->execute(
            $text_path,
            $pagexml->{mtime}, $pagexml->{xmldoc_text},
            time
        );
        $sth->finish;
    }
    else {
        my $sth = $self->{dbh}->prepare(qq{
UPDATE pagexml
SET mtime = ?,
    xmldoc_text = ?,
    last_cached = ?
WHERE text_path = ?;
        });
        $sth->execute(
            $pagexml->{mtime}, $pagexml->{xmldoc_text}, time, $text_path
        );
        $sth->finish;
    }
}
# $self->user_ns([$prefix => $namespace])
sub user_ns {
    my $self = shift;
    if (@_ >= 1) {
        if (@_ % 2 != 0) {
            croak "user_ns(): arguments is not a hash";
        }
        else {
            $self->{user_ns} = {$self->{user_ns}, @_};
        }
    }
    $self->{user_ns};
}

# $self->path_info([$path_info]): accessor
# if $path_info is specified, path_info is set to the value and
# basename, dirname, extension and text_path are set to the
# corresponding value as well.
sub path_info {
    my $self = shift;
    if ($#_ != -1) {
        $self->{path_info} = $_[0];
        if (index($self->{path_info}, '/') != 0) {
            $self->{path_info} = '/' . $self->{path_info};
        }
        ($self->{basename}, $self->{dirname}, $self->{extension})
            = fileparse($self->{path_info}, qr/\.[^.]+$/);
        $self->{text_path} = $self->_pathinfo_to_textpath();
        $self->_set_mtime;
        $self->{xmldoc} = undef;
    }
    return $self->{path_info};
}

# $self->_pathinfo_to_textpath([$path_info]) : convert path_jnfo into text_path
# e.g. /             => $text_dir/index.txt
#      /foo          => $text_dir/foo.txt
#      /foo/         => $text_dir/foo/index.txt
#      /foo/bar      => $text_dir/foo/bar.txt
#      /foo/bar.html => $text_dir/foo/bar.txt
sub _pathinfo_to_textpath {
    my $self     = shift;
    my $path_info = shift || $self->{path_info};
    my ($base, $dir, $ext) = fileparse( $path_info.(substr($path_info, -1) eq '/' ? $default_index : ''), qr/\.[^\.]+$/);
    return catfile($self->{text_dir}, $dir, "$base.txt");
}

# $self->text_path([$text_path]): accessor
# if $text_path is specified, text_path is set to the value and
# basename, dirname, extension and path_info are set to the
# corresponding value as well.
# if $text_path is outside of $text_dir, path_info is set to undef.
sub text_path {
    my $self = shift;
    if ($#_ != -1) {
        $self->{text_path} = canonpath($_[0]);
        my ($base, $dir, $ext) = fileparse($self->{text_path}, qr/\.[^\.]+$/);
        my @dirs_1 = splitdir canonpath $dir;
        my @dirs_2 = splitdir canonpath $self->{text_dir};
        if ($self->in_safe_directory) {
            $self->{path_info} = '/' . (join '/', @dirs_1[@dirs_2..$#dirs_1], $base) . ($self->{extension} || $self->{default_extension});
            ($self->{basename}, $self->{dirname}, $self->{extension})
                = fileparse($self->{path_info} , qr/\.[^.]+$/);
        }
        else {
            carp "text_path(): $self->{text_path} is not under $self->{text_dir}";
            $self->{path_info} = $self->{dirname} = $self->{basename} = $self->{extension} = undef;
        }
        $self->_set_mtime;
        $self->{xmldoc} = undef;
    }
    return $self->{text_path};
}

# $self->_set_mtime()
sub _set_mtime {
    my $self = shift;
    $self->{mtime} = $self->is_readable ? (stat $self->text_path)->mtime : undef;
}

# $self->dirname(): accessor, read-only
sub dirname {
    my $self = shift;
    $self->{dirname};
}

# $self->basename(): accessor, read-only
sub basename {
    my $self = shift;
    $self->{basename};
}

# $self->extension(): accessor, read-only
sub extension {
    my $self = shift;
    $self->{extension};
}

# $self->mtime(): accessor, read-only
sub mtime {
    my $self = shift;
    $self->{mtime};
}

# $self->exists(): true if the text file exists.
sub exists {
    my $self = shift;
    scalar -f $self->{text_path};
}

# $self->is_readable(): true if the text file exists and is readable.
sub is_readable {
    my $self = shift;
    scalar (-f $self->{text_path} and -r _);
}

# $self->is_safe(): true if the text file is not a dot(.) file and
# text_path does not contain dot(.) directories.
sub is_safe {
    my $self           = shift;
    my ($dirs, $file) = (splitpath($self->{text_path}))[1..2];
    scalar not grep { /\A\.(?!\.?\z)/ } (splitdir($dirs), $file);
}

# $self->in_safe_directory(): true if the text file is under $text_path.
sub in_safe_directory {
    my $self   = shift;
    my $dir    = (fileparse($self->{text_path}, qr/\.[^.]+$/))[1];
    my @dirs_1 = splitdir canonpath $dir;
    my @dirs_2 = splitdir canonpath $self->{text_dir};
    scalar(
        $#dirs_1 >= $#dirs_2
        and not grep {$dirs_1[$_] ne $dirs_2[$_]} (0..$#dirs_2)
        and ($#dirs_1 == $#dirs_2 or
             not grep {$_ eq ".."} @dirs_1[($#dirs_2+1)..$#dirs_1])

    );
}

# $self->has_valid_extension()
sub has_valid_extension {
    my $self           = shift;
    scalar($self->{extension} eq ""
            and ($self->{default_extension} eq ""
                or scalar grep {$_ eq $self->{default_extension}}
                               @{$self->{valid_extensions}})
            or scalar grep {$_ eq $self->{extension}}
                           @{$self->{valid_extensions}});
}

# $self->is_ok()
sub is_ok {
    my $self           = shift;
    scalar($self->is_readable
            and $self->is_safe
            and $self->in_safe_directory
            and $self->has_valid_extension);
}

# $self->is_forbidden(): true if file exists but is not readable
# or file exists but is unsafe
# or 'index' file does not exist but parent directory exists
sub is_forbidden {
    my $self           = shift;
    scalar($self->exists
            and $self->in_safe_directory
            and $self->has_valid_extension
            and not ($self->is_readable and $self->is_safe)
            or not $self->exists
            and $self->{basename}.$self->{extension} eq ""
            and -d File::Basename::dirname($self->{text_path}));
}

# $self->to_xml(): return XML::LibXML::Element (root element)
sub to_xml {
    my $self = shift;
    return $self->to_xmldoc->documentElement;
}

# $self->to_xmldoc(): return XML::LibXML::Document
sub to_xmldoc {
    my $self = shift;
    unless ($self->is_readable) {
        carp(($self->{text_path} || "undef") . " is not readable.");
        return undef;
    }
    defined $self->{xmldoc} and return $self->{xmldoc};

    my $pagexml;
    my $doc;
    my $save_cache = 0;
    my $expiry = '2 weeks';
    if ($self->{use_cache}) {
        $pagexml = $self->_get_pagexml_from_db();
        if ($pagexml) {
            if ($pagexml->{mtime} != $self->{mtime}) {
                $pagexml = undef;
                $save_cache = 1;
            }
            else {
                my $parser = XML::LibXML->new;
                $parser->keep_blanks(0);
                $doc = $parser->parse_string($pagexml->{xmldoc_text})
                    or croak "to_xmldoc(): cannot load XML from cache of $self->{text_path}";
            }
        }
        else {
            $save_cache = 1;
        }
    }
    unless ($doc) {
        open my $fh, "<:encoding($self->{fileenc})", $self->{text_path}
            or croak "to_xmldoc(): cannot open " . $self->{text_path} . ": $!";

        # <rdf:RDF>
        #   <rdf:Description rdf:about="{path_info}">
        #     <dcterms:title>...</dcterms:title>
        #     <dcterms:modified>...</dcterms:modified>
        #     <h:body rdf:parseType="Literal">...</h:body>
        #     <ex:attribute>...</ex:attribute>
        #     <ex:attribute rdf:resource="..."/>
        #     ...

        $doc = XML::LibXML::Document->new('1.0', 'utf-8');
        $doc->setStandalone(1);

        my $rdf = $doc->createElementNS($ns{rdf}, 'rdf:RDF');
        $doc->setDocumentElement($rdf);

        my $res = $doc->createElementNS($ns{rdf}, 'rdf:Description');
        $rdf->appendChild($res);
        $res->setAttributeNS($ns{rdf}, "rdf:about", $self->dirname
            .($self->basename eq $default_index ? "" : $self->basename.$self->{default_extension}));

        my $title = $doc->createElementNS($ns{dcterms}, 'dcterms:title');
        $res->appendChild($title);
        my $title_text = <$fh>;
        chomp $title_text;
        $title->appendTextNode($title_text);

        my $modified = $doc->createElementNS($ns{dcterms}, 'dcterms:modified');
        $res->appendChild($modified);
        my $dt = DateTime->from_epoch(epoch => $self->{mtime}, time_zone => 'local');
        my $modified_text = DateTime::Format::W3CDTF->new->format_datetime($dt);
        $modified->appendTextNode($modified_text);

        while (my $line = <$fh>) {
            last if $line =~ /^\s*$/;
            chomp $line;
            if ($line =~ /^(?:([_A-Za-z][-_.A-Za-z0-9]*):)?
                ([_A-Za-z][-_.A-Za-z0-9]*)
                \s+(?:<([^>]*)>|"([^"]*)"|'([^']*)'|(.*))$/msx) {
                my $prefix    = $1;
                my $localpart = $2;
                my $prop      = defined $prefix ? "$prefix:$localpart" : $localpart;
                my $uri       = $3;
                my $literal   = $4 || $5 || $6;
                if (defined $prefix and not defined $self->{user_ns}{$prefix}) {
                    carp("Unknown prefix: $prefix");
                    next;
                }
                my $elm = defined $prefix ?  $doc->createElementNS($self->{user_ns}{$prefix}, $prop) : $doc->createElement($prop);
                if (defined $uri) {
                    $elm->setAttributeNS($ns{rdf}, 'rdf:resource', $uri);
                }
                else {
                    $elm->appendTextNode($literal);
                }
                $res->appendChild($elm);
            }
        }

        my $content = $doc->createElementNS($ns{h}, 'h:body');
        $res->appendChild($content);
        $content->setAttributeNS($ns{rdf}, 'rdf:parseType', 'Literal');
        unless (eof $fh) {
            my $wikip = IWiki::Parser->new(IWiki::Parser::BasicTagSet->new);
            my $fragment = $wikip->parse($fh)->fragment;
            $doc->importNode($fragment);
            $content->appendChild($fragment);
        }
        close $fh;

    }

    if ($self->{use_cache} and $save_cache) {
        $pagexml = {
            xmldoc_text => $doc->toString(),
            mtime  => $self->{mtime},
        };
        $self->_set_pagexml_into_db($pagexml);
    }
    return $self->{xmldoc} = $doc;

}

1;

