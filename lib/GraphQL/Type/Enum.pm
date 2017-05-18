package GraphQL::Type::Enum;

use strict;
use warnings;

use GraphQL::Util qw/assert_valid_name/;
use GraphQL::Util::Type qw/define_enum_values/;

sub name { shift->{name} }

sub new {
    my ($class, %config) = @_;

    assert_valid_name($config{name}, $config{is_introspection});

    my $self = bless {
        name => $config{name},
        description => $config{description},

        _enum_config => \%config,
        _values => undef,
        _value_lookup => undef,
        _name_lookup => undef,
    }, $class;

    # NOTE: RANDOM ORDER OF VALUES
    # NOTE: random order; makes an array from a hash
    $self->{_values} = define_enum_values($self, $config{values});

    return $self;
}

sub get_values { shift->{_values} }

sub get_value {
    my ($self, $name) = @_;
    return $self->_get_name_lookup->{$name};
}

sub serialize {
    my ($self, $value) = @_;
    my $enum_value = $self->_get_value_lookup->{$value};
    return $enum_value ? $enum_value->{name} : undef; # null
}

sub parse_value {
    my ($self, $value) = @_;
    if (!ref($value)) { # === 'string'
        my $enum_value = $self->_get_name_lookup->{$value};
        if ($enum_value) {
            return $enum_value->{value};
        }
    }
    return;
}

sub parse_literal {
    my ($self, $value_node) = @_;
    if ($value_node->{kind} eq GraphQL::Language::Parser->ENUM) {
        my $enum_value = $self->_get_name_lookup->{ $value_node->{value} };
        if ($enum_value) {
            return $enum_value->{value};
        }
    }
    return;
}

sub _get_value_lookup {
    my $self = shift;
    if (!$self->{_value_lookup}) {
        my %lookup = map { $_->{value} => $_ } @{ $self->get_values };
        $self->{_value_lookup} = \%lookup;
    }
    return $self->{_value_lookup};
}

sub _get_name_lookup {
    my $self = shift;
    if (!$self->{_name_lookup}) {
        my %lookup = map { $_->{name} => $_ } @{ $self->get_values };
        $self->{_name_lookup} = \%lookup;
    }
    return $self->{_name_lookup};
}

sub to_string { shift->name }

sub to_json { shift->to_string }
sub inspect { shift->to_string }

1;

__END__

Enum Type Definition

Some leaf values of requests and input values are Enums. GraphQL serializes
Enum values as strings, however internally Enums can be represented by any
kind of type, often integers.

Example:

    const RGBType = new GraphQLEnumType({
      name: 'RGB',
      values: {
        RED: { value: 0 },
        GREEN: { value: 1 },
        BLUE: { value: 2 }
      }
    });

Note: If a value is not provided in a definition, the name of the enum value
will be used as its internal value.
