# vim: set ft=perl :

package IWiki::PageNobody;
use strict;
use warnings;
use utf8;

our $VERSION = '0.0.1';

use Carp                  qw/croak carp/;
use DateTime;
use DateTime::Format::W3CDTF;

use base qw/IWiki::Page/;

my $default_index     = 'index';
my %ns = (
    h       => "http://www.w3.org/1999/xhtml",
    rdf     => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
    dcterms => "http://purl.org/dc/terms/",
);

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

    open my $fh, "<:encoding($self->{fileenc})", $self->{text_path}
        or croak "to_xmldoc(): cannot open " . $self->{text_path} . ": $!";

    # <rdf:RDF>
    #   <rdf:Description rdf:about="{path_info}">
    #     <dcterms:title>...</dcterms:title>
    #     <dcterms:modified>...</dcterms:modified>
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

            eval {
                if ($self->{user_ns}{$prefix} eq $ns{dcterms} and $localpart eq "modified") {
                    $self->{mtime} = DateTime::Format::HTTP->parse_datetime($literal)->epoch;
                }
                elsif($self->{user_ns}{$prefix} eq $ns{dcterms} and $localpart eq "created") {
                    $self->{ctime} = DateTime::Format::HTTP->parse_datetime($literal)->epoch;
                }
            };
        }
    }

    if (not $res->getElementsByTagNameNS($ns{dcterms}, 'modified')) {
        my $modified = $doc->createElementNS($ns{dcterms}, 'dcterms:modified');
        $res->appendChild($modified);
        # my $dt = DateTime->from_epoch(epoch => $self->{mtime}, time_zone => 'local');
        my $dt = DateTime->from_epoch(epoch => $self->{mtime}, time_zone => 'floating');
        my $modified_text = DateTime::Format::W3CDTF->new->format_datetime($dt);
        $modified->appendTextNode($modified_text);
    }
    if (not $res->getElementsByTagNameNS($ns{dcterms}, 'created')) {
        my $created = $doc->createElementNS($ns{dcterms}, 'dcterms:created');
        $res->appendChild($created);
        # my $dt = DateTime->from_epoch(epoch => $self->{mtime}, time_zone => 'local');
        my $dt = DateTime->from_epoch(epoch => $self->{ctime}, time_zone => 'floating');
        my $created_text = DateTime::Format::W3CDTF->new->format_datetime($dt);
        $created->appendTextNode($created_text);
    }

    close $fh;


    return $self->{xmldoc} = $doc;

}


1;

