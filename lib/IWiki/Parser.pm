# vim: set ft=perl :

package IWiki::Parser;
use strict;
use warnings;
use utf8;

use Carp           qw/croak/;
use Regexp::Common qw/pattern clean no_defaults URIRef/;
use XML::LibXML;
use IWiki;

our $VERSION = '0.0.1';

my $para = {
    name         => 'para',
    qname        => 'p',
    type         => 'multi',
    construct_cb => '_construct_lines',
    create_cb    => '_create_xhtml_element_from_name',
    trim_sp      => 3,
};

my $attr_chars = {'.' => 'class',
                  '#' => 'id',
                  '@' => 'xml:lang'};
{
    my $ncname = '[A-Z_a-z][-.A-Z_a-z0-9]*';
    my $name   = '[:A-Z_a-z][-.:A-Z_a-z0-9]*';
    my $acs = join '|', map { quotemeta $_ } keys %$attr_chars;

    pattern name   => [qw/XML PrefixedName/],
            create => sub { "(?k:(?k:$ncname):(?k:$ncname))" };

    pattern name   => [qw/XML UnPrefixedName/],
            create => sub { "(?k:$ncname)" };

    pattern name   => [qw/XML CharRef/],
             create => sub { "&\\#(?k:[0-9]+|x[0-9a-fA-F]+);" };

    pattern name   => [qw/XML EntityRef/],
            create => sub { "&(?k:$name);" };

    pattern name   => [qw/IWiki attr/],
            create => sub {
                "<(?:(?k:$acs)|(?k:$name)=)(?:\"(?k:[^\"]*)\"|'(?k:[^']*)'|(?k:[^>]*))>";
            };
}

my %ns = (
    xml     => "http://www.w3.org/XML/1998/namespace",
    h       => "http://www.w3.org/1999/xhtml",
);

my %ent_table = (
    nbsp     => 160,
    iexcl    => 161,
    cent     => 162,
    pound    => 163,
    curren   => 164,
    yen      => 165,
    brvbar   => 166,
    sect     => 167,
    uml      => 168,
    copy     => 169,
    ordf     => 170,
    laquo    => 171,
    not      => 172,
    shy      => 173,
    reg      => 174,
    macr     => 175,
    deg      => 176,
    plusmn   => 177,
    sup2     => 178,
    sup3     => 179,
    acute    => 180,
    micro    => 181,
    para     => 182,
    middot   => 183,
    cedil    => 184,
    sup1     => 185,
    ordm     => 186,
    raquo    => 187,
    frac14   => 188,
    frac12   => 189,
    frac34   => 190,
    iquest   => 191,
    Agrave   => 192,
    Aacute   => 193,
    Acirc    => 194,
    Atilde   => 195,
    Auml     => 196,
    Aring    => 197,
    AElig    => 198,
    Ccedil   => 199,
    Egrave   => 200,
    Eacute   => 201,
    Ecirc    => 202,
    Euml     => 203,
    Igrave   => 204,
    Iacute   => 205,
    Icirc    => 206,
    Iuml     => 207,
    ETH      => 208,
    Ntilde   => 209,
    Ograve   => 210,
    Oacute   => 211,
    Ocirc    => 212,
    Otilde   => 213,
    Ouml     => 214,
    times    => 215,
    Oslash   => 216,
    Ugrave   => 217,
    Uacute   => 218,
    Ucirc    => 219,
    Uuml     => 220,
    Yacute   => 221,
    THORN    => 222,
    szlig    => 223,
    agrave   => 224,
    aacute   => 225,
    acirc    => 226,
    atilde   => 227,
    auml     => 228,
    aring    => 229,
    aelig    => 230,
    ccedil   => 231,
    egrave   => 232,
    eacute   => 233,
    ecirc    => 234,
    euml     => 235,
    igrave   => 236,
    iacute   => 237,
    icirc    => 238,
    iuml     => 239,
    eth      => 240,
    ntilde   => 241,
    ograve   => 242,
    oacute   => 243,
    ocirc    => 244,
    otilde   => 245,
    ouml     => 246,
    divide   => 247,
    oslash   => 248,
    ugrave   => 249,
    uacute   => 250,
    ucirc    => 251,
    uuml     => 252,
    yacute   => 253,
    thorn    => 254,
    yuml     => 255,
    fnof     => 402,
    Alpha    => 913,
    Beta     => 914,
    Gamma    => 915,
    Delta    => 916,
    Epsilon  => 917,
    Zeta     => 918,
    Eta      => 919,
    Theta    => 920,
    Iota     => 921,
    Kappa    => 922,
    Lambda   => 923,
    Mu       => 924,
    Nu       => 925,
    Xi       => 926,
    Omicron  => 927,
    Pi       => 928,
    Rho      => 929,
    Sigma    => 931,
    Tau      => 932,
    Upsilon  => 933,
    Phi      => 934,
    Chi      => 935,
    Psi      => 936,
    Omega    => 937,
    alpha    => 945,
    beta     => 946,
    gamma    => 947,
    delta    => 948,
    epsilon  => 949,
    zeta     => 950,
    eta      => 951,
    theta    => 952,
    iota     => 953,
    kappa    => 954,
    lambda   => 955,
    mu       => 956,
    nu       => 957,
    xi       => 958,
    omicron  => 959,
    pi       => 960,
    rho      => 961,
    sigmaf   => 962,
    sigma    => 963,
    tau      => 964,
    upsilon  => 965,
    phi      => 966,
    chi      => 967,
    psi      => 968,
    omega    => 969,
    thetasym => 977,
    upsih    => 978,
    piv      => 982,
    bull     => 8226,
    hellip   => 8230,
    prime    => 8242,
    Prime    => 8243,
    oline    => 8254,
    frasl    => 8260,
    weierp   => 8472,
    image    => 8465,
    real     => 8476,
    trade    => 8482,
    alefsym  => 8501,
    larr     => 8592,
    uarr     => 8593,
    rarr     => 8594,
    darr     => 8595,
    harr     => 8596,
    crarr    => 8629,
    lArr     => 8656,
    uArr     => 8657,
    rArr     => 8658,
    dArr     => 8659,
    hArr     => 8660,
    forall   => 8704,
    part     => 8706,
    exist    => 8707,
    empty    => 8709,
    nabla    => 8711,
    isin     => 8712,
    notin    => 8713,
    ni       => 8715,
    prod     => 8719,
    sum      => 8721,
    minus    => 8722,
    lowast   => 8727,
    radic    => 8730,
    prop     => 8733,
    infin    => 8734,
    ang      => 8736,
    and      => 8743,
    or       => 8744,
    cap      => 8745,
    cup      => 8746,
    int      => 8747,
    there4   => 8756,
    sim      => 8764,
    cong     => 8773,
    asymp    => 8776,
    ne       => 8800,
    equiv    => 8801,
    le       => 8804,
    ge       => 8805,
    sub      => 8834,
    sup      => 8835,
    nsub     => 8836,
    sube     => 8838,
    supe     => 8839,
    oplus    => 8853,
    otimes   => 8855,
    perp     => 8869,
    sdot     => 8901,
    lceil    => 8968,
    rceil    => 8969,
    lfloor   => 8970,
    rfloor   => 8971,
    lang     => 9001,
    rang     => 9002,
    loz      => 9674,
    spades   => 9824,
    clubs    => 9827,
    hearts   => 9829,
    diams    => 9830,
    quot     => 34,
    amp      => 38,
    apos     => 39,
    lt       => 60,
    gt       => 62,
    OElig    => 338,
    oelig    => 339,
    Scaron   => 352,
    scaron   => 353,
    Yuml     => 376,
    circ     => 710,
    tilde    => 732,
    ensp     => 8194,
    emsp     => 8195,
    thinsp   => 8201,
    zwnj     => 8204,
    zwj      => 8205,
    lrm      => 8206,
    rlm      => 8207,
    ndash    => 8211,
    mdash    => 8212,
    lsquo    => 8216,
    rsquo    => 8217,
    sbquo    => 8218,
    ldquo    => 8220,
    rdquo    => 8221,
    bdquo    => 8222,
    dagger   => 8224,
    Dagger   => 8225,
    permil   => 8240,
    lsaquo   => 8249,
    rsaquo   => 8250,
    euro     => 8364,
    # Added entity references
    bang       => 0x21,
    hash       => 0x23,
    dollar     => 0x24,
    percent    => 0x25,
    lparen     => 0x28,
    rparen     => 0x29,
    asterisk   => 0x2A,
    plus       => 0x2B,
    comma      => 0x2C,
    hyphen     => 0x2D,
    dot        => 0x2E,
    slash      => 0x2F,
    colon      => 0x3A,
    semicolon  => 0x3B,
    equal      => 0x3D,
    question   => 0x3F,
    at         => 0x40,
    lsbracket  => 0x5B,
    backslash  => 0x5C,
    rsbracket  => 0x5D,
    circumflex => 0x5E,
    underscore => 0x5F,
    grave      => 0x60,
    lcbracket  => 0x7B,
    bar        => 0x7C,
    rcbracket  => 0x7D,
    tilde      => 0x7E,
);

# IWiki::Parser->new($tagset1, $tagset2...)
sub new {
    my $class   = shift || croak "new(): no class name";
    my @tagsets = @_;
    $_->validate for @tagsets;
    my $block_element_types
      = [$para, map { @{$_->block_element_types} } @tagsets];
    my $block_by_name
      = {map { $_->{name} => $_ } @$block_element_types};
    my $block_by_mark
      = {map { $_->{mark} => $_ }
          grep { defined $_->{mark} and $_->{mark} ne "" }
            @$block_element_types};
    my $inline_element_types
      = [map { @{$_->inline_element_types} } @tagsets];
    my $inline_by_name
      = {map { $_->{name} => $_ } @$inline_element_types};
    my $inline_by_mark
      = {map { $_->{mark} => $_ }
          grep { defined  $_->{mark} and $_->{mark} ne "" }
            @$inline_element_types};

    return bless {
        lines                => [],
        row                  => 0,
        doc                  => undef,
        fragment             => undef,
        regexp               => {},
        block_element_types  => $block_element_types,
        block_by_name        => $block_by_name,
        block_by_mark        => $block_by_mark,
        inline_element_types => $inline_element_types,
        inline_by_name       => $inline_by_name,
        inline_by_mark       => $inline_by_mark,
        user_ns              => {},
    } => $class;
}

# $self->user_ns([$prefix => $namespace[, ...]])
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

# $self->parse($glob)
# $self->parse($scalar_ref)
# $self->parse($array_ref)
sub parse {
    my $self = shift;
    my $arg1 = shift;
    if (ref $arg1 eq 'GLOB' or ref $arg1 eq 'IO::File') {
        $self->_start([map { chomp; $_ } <$arg1>]);
    }
    elsif (ref $arg1 eq 'SCALAR') {
        $self->_start([split(m|$/|, $$arg1)]);
    }
    elsif (ref $arg1 eq 'ARRAY') {
        $self->_start($arg1);
    }
    else {
        croak "parse(): not a reference passed";
    }
    return $self;
}

# $self->fragment()
sub fragment {
    my $self = shift;
    return $self->{fragment};
}

# $self->doc()
sub doc {
    my $self = shift;
    return $self->{doc};
}

# $self->_start($array_ref)
sub _start {
    my $self          = shift;
    $self->{lines}    = shift;
    $self->{row}      = 0;
    $self->{doc}      = XML::LibXML::Document->new("1.0", "utf-8");
    $self->{fragment} = $self->{doc}->createDocumentFragment();
    $self->{regexp}   = {};
    $self->_construct_blocks($self->{fragment});
    my $root          = $self->{doc}->createElementNS($ns{h}, 'div');
    $self->{doc}->setDocumentElement($root);
    $self->{doc}->getDocumentElement
      ->appendChild($self->{fragment}->cloneNode(1));
    return $self;
}

# $self->_construct_args_init ($parent, $parent_type, $marks, $end_mark)
sub _construct_args_init {
    my ($self, $parent, $parent_type, $marks, $end_mark) = @_[0..4];
    $marks = "" if not defined $marks;
    $parent_type = {} if not defined $parent_type;
    ($parent, $parent_type, $marks, length($marks), $end_mark);
}

# $self->_construct_blocks ($parent, $parent_type, $marks, $end_mark)
sub _construct_blocks {
    my $self         = shift;
    my ($parent, $parent_type, $marks, $marks_len, $end_mark)
                     = $self->_construct_args_init(@_[0..3]);
    my $re_block     = $self->_make_regexp('block' => $self->{block_element_types});

    while ($self->{row} <= $#{$self->{lines}}) {
        next if $self->{lines}[$self->{row}] =~ /\A\Q$marks\E\s*\z/;

        my ($child_mark, $child_type) =
            $self->{lines}[$self->{row}] =~ /\A\Q$marks\E($re_block)/ ?
                ($1, $self->{block_by_mark}{$1})
              : ("", $self->{block_by_name}{para});

        # $child1 is either the child itself or $child2's ancestor.
        my ($child1, $child2) = $self->_call_create_cb($child_type);

        while ($self->{lines}[$self->{row}] =~ s/\A(\Q$marks$child_mark\E)$RE{IWiki}{attr}{-keep}/$1/ms) {
            my $attr_name = defined $2 ?  $attr_chars->{$2} : $3;
            my $attr_value = defined $4 ? $4 : defined $5 ? $5 : $6;
            if ($attr_name =~ /\A$RE{XML}{PrefixedName}{-keep}\z/) {
                if (defined $2 and $2 eq 'xml') {
                    $child1->setAttribute($attr_name, $attr_value);
                    #$child1->setAttributeNS($ns{xml}, $attr_name, $attr_value);
                }
                else {
                    $child1->setAttributeNS(defined $self->{user_ns}{$2} ? $self->{user_ns}{$2} : '', $attr_name, $attr_value);
                }
            }
            else {
                $child1->setAttribute($attr_name, $attr_value);
            }
        }

        if (defined $child_type->{construct_cb}) {
            $self->_call_construct_cb(
                $child2,
                $child_type,
                $child_type->{type} eq 'list' ?
                    $marks.$child_mark : $marks,
                defined $child_type->{end_mark} ? $child_type->{end_mark} : $end_mark);
        }

        $parent->appendChild($child1);
    }
    continue {
        last if $self->_block_ends($parent_type, $marks, $end_mark);
        $self->{row}++;
    }

    return $parent;
}

# $self->_construct_lines($parent, $parent_type, $marks, $end_mark, $verbatim)
sub _construct_lines {
    my $self     = shift;
    my ($parent, $parent_type, $marks, $marks_len, $end_mark)
                 = $self->_construct_args_init(@_[0..3]);
    my $verbatim = $parent_type->{verbatim} || 0;
    my $trans_nl = $parent_type->{trans_nl} || 0;
    my $joint    = {0=>$/, 1=>$/, 2=>' ', 3=>''}->{$trans_nl};
    my $trim_sp  = $parent_type->{trim_sp}  || 0;
    my $re_trim  = $trim_sp == 1 ? qr/^\s+/
                 : $trim_sp == 2 ? qr/\s+$/
                 : $trim_sp == 3 ? qr/^\s+|\s+$/
                 : undef;

    if ($parent_type->{type} eq 'env') {
        $self->{row}++;
    }

    if ($parent_type->{type} eq 'single'
            or $parent_type->{type} eq 'multi') {
        $self->{lines}[$self->{row}] =
          substr($self->{lines}[$self->{row}], 0, $marks_len)
        . substr($self->{lines}[$self->{row}],
            $marks_len + length(defined $parent_type->{mark} ? $parent_type->{mark} : ""));
    }

    my $i      = $self->{row};
    my $reason = 0;
    $self->{row}++ until $reason = $self->_block_ends($parent_type, $marks, $end_mark);

    my $child_text = join $joint,
      map {
        my $line = substr $_, $marks_len;
        $line =~ s/$re_trim//g if defined $re_trim;
        $line
      } @{$self->{lines}}[$i..$self->{row}];

    if ($verbatim) {
        $parent->appendTextNode($child_text);
    }
    else {
        my $pos = 0;
        $self->_parse_line($parent, {}, \$child_text, \$pos, "", $trans_nl);
    }

    $self->{row}++ if $reason == 4;
    $self->{row}++ if $parent_type->{type} eq 'env';
    return $parent;
}

# $self->_construct_text_or_list($parent, $parent_type, $marks, $end_mark)
sub _construct_text_or_list {
    my $self    = shift;
    my ($parent, $parent_type, $marks, $marks_len, $end_mark)
                = $self->_construct_args_init(@_);
    my $re_list = $self->_make_regexp('list'
        => [$self->{block_by_name}{ol}, $self->{block_by_name}{ul}]);

    while ($self->{row} <= $#{$self->{lines}}) {

        # nested list
        if ($self->{lines}[$self->{row}] =~ /\A\Q$marks\E($re_list)/) {
            my ($mark, $child_type) = ($1, $self->{block_by_mark}{$1});
            $parent->appendChild(
                $self->{doc}->createElementNS($ns{h}, 'li')
            ) unless $parent->hasChildNodes();
            my $item = $parent->lastChild;
            my $list = $self->{doc}
                ->createElementNS($ns{h}, $child_type->{name});
            $self->_construct_text_or_list($list, $child_type, "$marks$mark", $end_mark);
            $item->appendChild($list);
        }

        # list item
        else {
            my $item = $self->{doc}->createElementNS($ns{h}, 'li');
            $self->_construct_lines($item, {type=>'single'}, $marks, $end_mark);
            $parent->appendChild($item);
        }
    }
    continue {
        last if $self->_block_ends($parent_type, $marks, $end_mark);
        $self->{row}++;
    }

    return $parent;
}

# $self->_construct_definition_list($parent, $parent_type, $marks, $end_mark)
sub _construct_definition_list {
    my $self     = shift;
    my ($parent, $parent_type, $marks, $marks_len, $end_mark)
                 = $self->_construct_args_init(@_);
    my $re_dl    = $self->_make_regexp('dl'
        => [$self->{block_by_name}{dl}]);
    my $dd_mark  = '=';
    my $re_dd    = quotemeta $dd_mark;

    while ($self->{row} <= $#{$self->{lines}}) {

        # DD element
        if ($self->{lines}[$self->{row}] =~ /\A\Q$marks\E($re_dd)/g) {
            my $dd = $self->{doc}->createElementNS($ns{h}, 'dd');
            if ($self->{lines}[$self->{row}] =~ /\G($re_dl)/) {
                my ($mark, $child_type) = ($1, $self->{block_by_mark}{$1});
                my $dl = $self->{doc}
                    ->createElementNS($ns{h}, $child_type->{name});

                $self->_construct_definition_list($dl, $child_type, "$marks$dd_mark$mark", $end_mark);
                $dd->appendChild($dl);
            }
            else {
                $self->_construct_lines($dd, {type=>'single'}, "$marks$dd_mark", $end_mark);
            }
            $parent->appendChild($dd);
        }

        # DT element
        else {
            my $dt = $self->{doc}->createElementNS($ns{h}, 'dt');
            $self->_construct_lines($dt, {type=>'single'}, $marks, $end_mark);
            $parent->appendChild($dt);
        }
    }
    continue {
        last if $self->_block_ends($parent_type, $marks, $end_mark);
        $self->{row}++;
    }

    return $parent;
}

# $self->_construct_table($parent, $parent_type, $marks, $end_mark)
sub _construct_table {
    my $self         = shift;
    my ($parent, $parent_type, $marks, $marks_len, $end_mark) =  $self->_construct_args_init(@_);

    my $table_delim  = '|';
    my $th_mark      = '~';
    my $caption      = undef;
    my $tgroups      = {};

    # tr for each line
    while ($self->{row} <= $#{$self->{lines}}) {
        my $line = substr $self->{lines}[$self->{row}], $marks_len;
        next if $line =~ /\A[^|]*\z/;
        $line =~ s/\s+\z//;

        my $pos    = 0;

        # caption
        if (not defined $caption and $line =~ /\A.{$pos}(.*)\|(?=.*c)[^|]+\z/) {
            $caption = $self->{doc}->createElementNS($ns{h}, 'caption');
            my $line = $1;
            $self->_parse_line($caption, {}, \$line, \$pos, undef, 0);
            $caption->firstChild->replaceDataRegEx(qr/\A\s+/, '')
                if $caption->firstChild->nodeType == 3;
            $caption->lastChild->replaceDataRegEx(qr/\s+\z/, '')
                if $caption->lastChild->nodeType == 3;
            next;
        }

        # th/td delimited with '|'
        else {
            my $tr     = undef;
            my $option = '';
            while ($pos < length $line) {
                if ($line =~ /\A.{$pos}([^|]*)\z/) {
                    $option = $1;
                    last;
                }

                my $qname = "";
                if (index($line, $th_mark, $pos) == $pos) {
                    $qname = 'th';
                    $pos += length $th_mark;
                }
                else {
                    $qname = 'td';
                }
                my $cell = $self->{doc}->createElementNS($ns{h}, $qname);
                my $i = $pos;
                $self->_parse_line($cell, {}, \$line, \$pos, $table_delim, 0);
                $cell->firstChild->replaceDataRegEx(qr/\A\s+/, '')
                    if $cell->hasChildNodes
                      and $cell->firstChild->nodeType == 3;
                $cell->lastChild->replaceDataRegEx(qr/\s+\z/, '')
                    if $cell->hasChildNodes
                      and $cell->lastChild->nodeType == 3;

                if (index($line, $table_delim, $pos - length $table_delim) == $pos - length $table_delim) {
                    $tr = $self->{doc}->createElementNS($ns{h}, 'tr')
                      unless defined $tr;
                    $tr->appendChild($cell);
                    next;
                }
                else {
                    $option = substr $line, $i;
                    last;
                }
            }

            next unless defined $tr;

            my %hfb = (
                thead => ($option =~ tr/h/h/),
                tfoot => ($option =~ tr/f/f/),
                tbody => ($option =~ tr/b/b/),
            );
            $hfb{"tbody$_"} = ($option =~ m/$_/) for 0..9;
            $hfb{tbody}++ if ($option =~ tr/hfb0-9/hfb0-9/) == 0;
            for my $key (keys %hfb) {
                if ($hfb{$key} >= 1) {
                    $tgroups->{$key} =
                    $self->{doc}->createElementNS($ns{h}, substr($key, 0, 5))
                    unless defined $tgroups->{$key};
                    $tgroups->{$key}->appendChild($tr->cloneNode(1));
                }
            }
        }
    }
    continue {
        last if $self->_block_ends($parent_type, $marks, $end_mark);
        $self->{row}++;
    }

    $parent->appendChild($caption) if defined $caption;
    if (scalar %$tgroups) {
        for my $key (('thead', 'tfoot', 'tbody', 'tbody0'..'tbody9')) {
            $parent->appendChild($tgroups->{$key})
                if defined $tgroups->{$key};
        }
    }
    else {
        my $tbody = $self->{doc}->createElementNS($ns{h}, 'tbody');
        my $tr    = $self->{doc}->createElementNS($ns{h}, 'tr');
        my $td    = $self->{doc}->createElementNS($ns{h}, 'td');
        $tr->appendChild($td);
        $tbody->appendChild($tr);
        $parent->appendChild($tbody);
    }

    return $parent;
}

# $self->_parse_args_init($parent, $parent_type, $ref_line, $ref_pos, $end_mark, $trans_nl)
sub _parse_args_init {
    my $self = shift;
    my ($parent, $parent_type, $ref_line, $ref_pos,
        $end_mark, $trans_nl) = @_;
    $parent_type  ||= {};
    my $pos         = 0;
    $ref_pos      ||= \$pos;
    $end_mark     ||= "";
    my $re_end_mark = quotemeta $end_mark || qr/(?!)/;
    $trans_nl     ||= 0;
    ($parent, $parent_type, $ref_line, $ref_pos, $end_mark, $re_end_mark, $trans_nl);
}

# $self->_parse_line($parent, $parent_type, $ref_line, $ref_pos, $end_mark, $trans_nl)
sub _parse_line {
    my $self      = shift;
    my ($parent, $parent_type, $ref_line, $ref_pos,
        $end_mark, $re_end_mark, $trans_nl)
                  = $self->_parse_args_init(@_);
    my $re_inline = $self->_make_regexp('inline'
        => $self->{inline_element_types});
    my $re_nl     = $trans_nl == 1 ? qr,$/, : qr,(?!), ;

    $$ref_pos += length(defined $parent_type->{mark} ? $parent_type->{mark} : "");

    # content ::= (text? (reference | element))* text
    while ($$ref_line =~ /\A.{$$ref_pos}
        (.*?)(?=$re_end_mark|$RE{XML}{CharRef}|$RE{XML}{EntityRef}|$re_inline|$re_nl|\z)
        (?:($re_end_mark)|$RE{XML}{CharRef}{-keep}|$RE{XML}{EntityRef}{-keep}|($re_inline)|($re_nl)|\z)/msx) {

        my ($cdata, $parent_end_mark, $charref, $entref, $child_mark, $nl)
            = ($1, $2, $3, $4, $5, $6);

        if ($cdata ne "") {
            my $text = $self->{doc}->createTextNode($cdata);
            $parent->appendChild($text);
            $$ref_pos += length $cdata;
        }

        if (defined $charref) {
            my $codepoint = index($charref, 'x') == 0 ? hex(substr($charref, 1))
                : $charref;
            my $char = ($codepoint == 0x9 or $codepoint == 0xA
                    or $codepoint == 0xD
                    or 0x20 <= $codepoint and $codepoint <= 0xD7FF
                    or 0xE000 <= $codepoint and $codepoint <= 0xFFFD
                    or 0x10000 <= $codepoint and $codepoint <= 0x10FFFF
            ) ? chr($codepoint) : "&#$charref;";
            my $text = $self->{doc}->createTextNode($char);
            $parent->appendChild($text);
            $$ref_pos += 3 + length($charref);
        }
        elsif (defined $entref) {
            my $char = exists $ent_table{$entref} ? chr($ent_table{$entref})
                : "&$entref;";
            my $text = $self->{doc}->createTextNode($char);
            $parent->appendChild($text);
            $$ref_pos += 2 + length($entref);
        }
        elsif (defined $child_mark) {
            my $child_type = $self->{inline_by_mark}{$child_mark};

            # $child1 is either itself or $child2's ancestor.
            my ($child1, $child2) = $self->_call_create_cb($child_type);
            $self->_call_parse_cb($child2, $child_type, $ref_line, $ref_pos, $child_type->{end_mark});
            $parent->appendChild($child1);
            next;
        }
        elsif (defined $nl) {
            my $br = $self->{doc}->createElementNS($ns{h}, 'br');
            $parent->appendChild($br);
            $$ref_pos += length $nl;
            next;
        }
        else {
            last;
        }
    }

    $$ref_pos += length $end_mark;
    return $parent;
}

# $self->_parse_line_verbatim($parent, $parent_type, $ref_line, $ref_pos, $end_mark)
sub _parse_line_verbatim {
    my $self        = shift;
    my ($parent, $parent_type, $ref_line, $ref_pos,
        $end_mark, $re_end_mark, $trans_nl)
                    = $self->_parse_args_init(@_);

    $$ref_pos += length(defined $parent_type->{mark} ? $parent_type->{mark} : "");

    if ($$ref_line =~ /\A.{$$ref_pos}(.*?)(?:$re_end_mark|\z)/msx) {
        my $cdata = $1;
        if ($cdata ne "") {
            $parent->appendTextNode($cdata);
            $$ref_pos += length $cdata;
        }
    }

    $$ref_pos += length $end_mark;
    return $parent;
}

# $self->_parse_link($parent, $parent_type, $ref_line, $ref_pos, $end_mark, $re_end_mark, $trans_nl)
sub _parse_link {
    my $self      = shift;
    my ($parent, $parent_type, $ref_line, $ref_pos,
        $end_mark, $re_end_mark, $trans_nl)
                  = $self->_parse_args_init(@_);
    my $re_inline = $self->_make_regexp('inline'
        => $self->{inline_element_types});
    my $re_nl     = $trans_nl == 1 ? qr,$/, : qr,(?!), ;
    my $sep       = '|';
    my $re_sep    = quotemeta $sep;
    my $uri       = undef;
    my $label     = undef;

    $$ref_pos += length(defined $parent_type->{mark} ? $parent_type->{mark} : "");

    my $relative_ref  = qr,(?:[A-Za-z0-9\-._~/]+)?
                           (?:\?[A-Za-z0-9\-._~&;%]*)?
                           (?:\#[-._A-Za-z0-9]*)?,x;
    my $re_uriref     = qr,$RE{URIRef}{URI}{-scheme => '(?:https?|ftp|urn|mailto)'}|$relative_ref,;

    # link has a label
    if ($$ref_line =~ /\A.{$$ref_pos}
        (\s*($re_uriref)\s*$re_sep\s*(.*?)\s*)
        (?:$re_end_mark|\z)/msx) {
        $$ref_pos += length $1;
        $uri      = $2;
        $label    = $3;
    }
    # link has no label
    elsif ($$ref_line =~ /\A.{$$ref_pos}
        (\s*($re_uriref)\s*)(?:$re_end_mark|\z)/msx) {
        $$ref_pos += length $1;
        $uri      = $2;
        $label    = $uri;
    }
    # link is not a URI
    elsif ($$ref_line =~ /\A.{$$ref_pos}
        (\s*(.*)\s*)(?:$re_end_mark|\z)/msx) {
        $$ref_pos += length $1;
        $label    = $2;
    }
    else {
        croak "_parse_link(): failed to parse link\n";
    }

    if ($parent_type->{name} eq 'a') {
        $parent->setAttribute('href', $uri) if defined $uri;
        $parent->appendTextNode($label)     if defined $label;
    }
    elsif ($parent_type->{name} eq 'img') {
        $parent->setAttribute('src', defined $uri ? $uri : "");
        $parent->setAttribute('alt', defined $label ? $label : "");
    }
    elsif ($parent_type->{name} eq 'object') {
        $parent->setAttribute('data', $uri) if defined $uri;
        $parent->appendTextNode($label)     if defined $label;
    }

    $$ref_pos += length $end_mark;
    return $parent;
}

# $self->_create_xhtml_element_from_name ($element_type)
sub _create_xhtml_element_from_name {
    my $self         = shift;
    my $element_type = shift;
    my $child        = $self->{doc}->createElementNS($ns{h},
        defined $element_type->{qname} ? $element_type->{qname} : $element_type->{name});
    return ($child, $child);
}

# $self->_create_xhtml_blockcode ($element_type)
sub _create_xhtml_blockcode {
    my $self         = shift;
    my $element_type = shift;
    my $code = $self->{doc}
        ->createElementNS($ns{h}, 'code');
    my $pre = $self->{doc}
        ->createElementNS($ns{h}, 'pre');
    $pre->appendChild($code);
    return ($pre, $code);
}

# $self->_block_ends($parent_type, $marks, $end_mark)
sub _block_ends {
    my $self        = shift;
    my $parent_type = shift;
    my $marks       = shift; $marks = "" unless defined $marks;
    my $end_mark    = shift;
    return
        $self->{row} >= $#{$self->{lines}} ? 1
        : index($self->{lines}[$self->{row}+1], $marks) != 0 ? 2
        : defined $end_mark && index($self->{lines}[$self->{row}+1], "$marks$end_mark") == 0 ? 3
        : defined $parent_type->{type}
            && $parent_type->{type} eq 'multi'
            && $self->{lines}[$self->{row}+1] =~ /\A\Q$marks\E\s*\z/ ? 4
        : defined $parent_type->{type}
            && $parent_type->{type} eq 'single' ? 5
        : 0;
}

# $self->_make_regexp($name => [$element_type, $element_type...])
sub _make_regexp {
    my $self              = shift;
    my $name              = shift;
    my $element_types_ref = shift;
    return $self->{regexp}{$name} ||
        ($self->{regexp}{$name}
            = scalar(grep { defined $_->{mark} and $_->{mark} ne "" } @$element_types_ref) ?
              (join '|', map { quotemeta $_->{mark} }
                sort { length $b->{mark} <=> length $a->{mark} }
                grep { defined $_->{mark} and $_->{mark} ne "" }
                  @$element_types_ref)
            : qr/(?!)/
        );
}

# $self->_call_create_cb($element_type)
sub _call_create_cb {
    my $self         = shift;
    my $element_type = shift;
    my $create_cb    = $element_type->{create_cb};

    if (ref $create_cb eq 'CODE') {
        return $create_cb->($self, $element_type);
    }
    elsif ($self->can($create_cb)) {
        return $self->$create_cb($element_type);
    }
    else {
        croak "_call_create_cb(): cannot call $create_cb";
    }
}

# $self->_call_construct_cb($parent, $element_type, @_)
sub _call_construct_cb {
    my $self         = shift;
    my $parent       = shift;
    my $element_type = shift;
    my $cb           = $element_type->{construct_cb};
    if (ref $cb eq 'CODE') {
        return $cb->($self, $parent, $element_type, @_);
    }
    elsif ($self->can($cb)) {
        return $self->$cb($parent, $element_type, @_);
    }
    else {
        croak "_call_construct_cb(): cannot call $cb";
    }
}

# $self->_call_parse_cb($parent, $element_type, @_)
sub _call_parse_cb {
    my $self         = shift;
    my $parent       = shift;
    my $element_type = shift;
    my $cb           = $element_type->{parse_cb};
    if (ref $cb eq 'CODE') {
        return $cb->($parent, $element_type, @_);
    }
    elsif ($self->can($cb)) {
        return $self->$cb($parent, $element_type, @_);
    }
    else {
        croak "_call_parse_cb(): cannot call $cb";
    }
}
1;

