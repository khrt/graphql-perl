package GraphQL::Type::Scalar;

use strict;
use warnings;

sub name { shift->{name} }
sub description { shift->{description} }

sub new {
    my ($class, %config) = @_;

    die   qq`$config{name} must provide "serialize" function. If this custom Scalar `
        . qq`is also used as an input type, ensure "parse_value" and "parse_literal" `
        . qq`funcitions are also provided.\n`
        if ref($config{serialize}) ne 'CODE';

    if ($config{parse_value} || $config{parse_literal}) {
        die qq`$config{name} must provide both "parse_value" and "parse_literal" functions`
            if ref($config{parse_value}) ne 'CODE' || ref($config{parse_literal}) ne 'CODE';
    }

    my $self = bless {
        name => $config{name},
        description => $config{description} || '',
        _scalar_config => \%config,
    }, $class;

    return $self;
}

# Serializes an internal value to include a response.
sub serialize {
    my ($self, $value) = @_;
    my $serializer = $self->{_scalar_config}{serialize};
    return $serializer->($value);
}

# Parses an externally provided value to use as an input.
sub parse_value {
    my ($self, $value) = @_;
    my $parser = $self->{_scalar_config}{parse_value};
    return $parser ? $parser->($value) : undef;
}

# Parses an externally provided literal value to use as an input.
sub parse_literal {
    my ($self, $value_node) = @_;
    my $parser = $self->{_scalar_config}{parse_literal};
    return $parser ? $parser->($value_node) : undef;
}

sub to_string { shift->name }

sub to_json { shift->to_string }
sub inspect { shift->to_string }

1;

__END__

Scalar Type Definition

The leaf values of any request and input values to arguments are
Scalars (or Enums) and are defined with a name and a series of functions
used to parse input from ast or variables and to ensure validity.

Example:

    const OddType = new GraphQLScalarType({
      name: 'Odd',
      serialize(value) {
        return value % 2 === 1 ? value : null;
      }
    });
