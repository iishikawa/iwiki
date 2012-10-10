# vim: set ft=perl :

package IWiki::Parser::BasicTagSet;
use strict;
use warnings;
use utf8;

our $VERSION = '0.0.1';

use Carp         qw/croak/;

use base qw/IWiki::Parser::TagSet/;

our %default = (
    block_element_types => [
        {
            name         => 'p',
            type         => 'multi',
            construct_cb => '_construct_lines',
            create_cb    => '_create_xhtml_element_from_name',
            mark         => '~',
            trim_sp      => 3,
        },
        {
            name         => 'h1',
            type         => 'multi',
            construct_cb => '_construct_lines',
            create_cb    => '_create_xhtml_element_from_name',
            mark         => '*',
            trim_sp      => 3,
        },
        {
            name         => 'h2',
            type         => 'multi',
            construct_cb => '_construct_lines',
            create_cb    => '_create_xhtml_element_from_name',
            mark         => '**',
            trim_sp      => 3,
        },
        {
            name         => 'h3',
            type         => 'multi',
            construct_cb => '_construct_lines',
            create_cb    => '_create_xhtml_element_from_name',
            mark         => '***',
            trim_sp      => 3,
        },
        {
            name         => 'h4',
            type         => 'multi',
            construct_cb => '_construct_lines',
            create_cb    => '_create_xhtml_element_from_name',
            mark         => '****',
            trim_sp      => 3,
        },
        {
            name         => 'h5',
            type         => 'multi',
            construct_cb => '_construct_lines',
            create_cb    => '_create_xhtml_element_from_name',
            mark         => '*****',
            trim_sp      => 3,
        },
        {
            name         => 'h6',
            type         => 'multi',
            construct_cb => '_construct_lines',
            create_cb    => '_create_xhtml_element_from_name',
            mark         => '******',
            trim_sp      => 3,
        },
        {
            name         => 'blockquote',
            type         => 'list',
            construct_cb => '_construct_blocks',
            create_cb    => '_create_xhtml_element_from_name',
            mark         => '>',
            trim_sp      => 3,
        },
        {
            name      => 'hr',
            type      => 'single',
            create_cb => '_create_xhtml_element_from_name',
            mark      => '====',
            trim_sp      => 3,
        },
        {
            name         => 'ol',
            type         => 'list',
            construct_cb => '_construct_text_or_list',
            create_cb    => '_create_xhtml_element_from_name',
            mark         => '+',
            trim_sp      => 3,
        },
        {
            name         => 'ul',
            type         => 'list',
            construct_cb => '_construct_text_or_list',
            create_cb    => '_create_xhtml_element_from_name',
            mark         => '-',
            trim_sp      => 3,
        },
        {
            name         => 'dl',
            type         => 'list',
            construct_cb => '_construct_definition_list',
            create_cb    => '_create_xhtml_element_from_name',
            mark         => ':',
            trim_sp      => 3,
        },
        {
            name         => 'pre',
            type         => 'env',
            construct_cb => '_construct_lines',
            create_cb    => '_create_xhtml_element_from_name',
            mark         => '>|',
            end_mark     => '|<',
            trim_sp      => 0,
        },
        {
            name         => 'blockcode',
            type         => 'env',
            construct_cb => '_construct_lines',
            create_cb    => '_create_xhtml_blockcode',
            mark         => '>||',
            end_mark     => '||<',
            verbatim     => 1,
            trim_sp      => 0,
        },
        {
            name         => 'math',
            qname        => 'div',
            type         => 'env',
            construct_cb => '_construct_lines',
            create_cb    => '_create_xhtml_element_from_name',
            mark         => '>|MATH|',
            end_mark     => '|MATH|<',
            trans_nl     => 1,
            trim_sp      => 0,
        },
        {
            name         => 'table',
            type         => 'list',
            construct_cb => '_construct_table',
            create_cb    => '_create_xhtml_element_from_name',
            mark         => '|',
        },
    ],
    inline_element_types => [
        {
            name      => 'em',
            parse_cb  => '_parse_line',
            create_cb => '_create_xhtml_element_from_name',
            mark      => '**',
            end_mark  => '**',
        },
        {
            name      => 'strong',
            parse_cb  => '_parse_line',
            create_cb => '_create_xhtml_element_from_name',
            mark      => '***',
            end_mark  => '***',
        },
        {
            name      => 'code',
            parse_cb  => '_parse_line',
            create_cb => '_create_xhtml_element_from_name',
            mark      => '$$',
            end_mark  => '$$',
        },
        {
            name      => 'q',
            parse_cb  => '_parse_line',
            create_cb => '_create_xhtml_element_from_name',
            mark      => '``',
            end_mark  => "''",
        },
        {
            name      => 'sup',
            parse_cb  => '_parse_line',
            create_cb => '_create_xhtml_element_from_name',
            mark      => '^{',
            end_mark  => '}',
        },
        {
            name      => 'sub',
            parse_cb  => '_parse_line',
            create_cb => '_create_xhtml_element_from_name',
            mark      => '_{',
            end_mark  => '}',
        },
        {
            name      => 'ins',
            parse_cb  => '_parse_line',
            create_cb => '_create_xhtml_element_from_name',
            mark      => '--<',
            end_mark  => '>--',
        },
        {
            name      => 'del',
            parse_cb  => '_parse_line',
            create_cb => '_create_xhtml_element_from_name',
            mark      => '>--',
            end_mark  => '--<',
        },
        {
            name      => 'a',
            parse_cb  => '_parse_link',
            create_cb => '_create_xhtml_element_from_name',
            mark      => '[[',
            end_mark  => ']]',
        },
        {
            name      => 'img',
            parse_cb  => '_parse_link',
            create_cb => '_create_xhtml_element_from_name',
            mark      => '[IMG[',
            end_mark  => ']]',
        },
        {
            name      => 'object',
            parse_cb  => '_parse_link',
            create_cb => '_create_xhtml_element_from_name',
            mark      => '[OBJ[',
            end_mark  => ']]',
        },
        {
            name      => 'verb',
            qname     => 'span',
            parse_cb  => '_parse_line_verbatim',
            create_cb => '_create_xhtml_element_from_name',
            mark      => '{VERB}',
            end_mark  => '{/VERB}',
            verbatim  => 1,
        },
    ],
);

# $self->_init(): initialization
sub _init {
    my $self = shift;
    not defined $self->{$_} and $self->{$_} = $default{$_}
        for keys %default;
    $self->SUPER::_init() if $self->SUPER::can('init');
    return $self;
}

1;

