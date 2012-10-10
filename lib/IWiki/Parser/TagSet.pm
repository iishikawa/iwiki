# vim: set ft=perl :

package IWiki::Parser::TagSet;
use strict;
use warnings;
use utf8;

our $VERSION = '0.0.1';

use Carp         qw/croak/;

our %default = (
    block_element_types  => [],
    inline_element_types => [],
);

# IWiki::Parser::TagSet->new(key1 => value1, key2 => value2, ...): constructor
sub new {
    my $class  = shift || croak "new(): no class name";
    my $self   = bless {@_} => $class;
    $self->_init() if $self->can('_init');
    return $self;
}

# $self->_init(): initialization
sub _init {
    my $self = shift;
    not exists $self->{$_} and $self->{$_} = $default{$_}
        for keys %default;
    return $self;
}

# $self->block_element_types(): accesser
sub block_element_types {
    my $self = shift;
    $self->{block_element_types};
}

# $self->inline_element_types(): accesser
sub inline_element_types {
    my $self = shift;
    $self->{inline_element_types};
}

# $self->validate()
sub validate {
    my $self = shift;
    my $pkgname = ref $self;
    my %required_keys = (
        block_element_types  => [qw/type create_cb/],
        inline_element_types => [qw/create_cb parse_cb/],
    );
    for my $k (keys %required_keys) {
        for my $element_type (@{$self->{$k}}) {
            croak "check(): $pkgname: not a reference to hash"
                unless ref $element_type eq 'HASH';
            croak "check(): $pkgname: no name"
                unless defined $element_type->{name};
            for my $key (@{$required_keys{$k}}) {
                croak "check(): $pkgname: '$key' is missing on $element_type->{name}"
                    unless defined $element_type->{$key};
            }
        }
    }
}

1;

