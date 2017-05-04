package GraphQL::Type::Object;

use strict;
use warnings;

use GraphQL::Util qw/assert_valid_name/;
use GraphQL::Util::Type qw/define_field_map define_interfaces/;

# TODO: Move to BASE type
sub name { shift->{name} }

sub new {
    my ($class, %config) = @_;

    assert_valid_name($config{name}, $config{is_introspection});

    if ($config{is_type_of}) {
        die qq`$config{name} must provide "is_type_of" as a function.`
            if ref($config{is_type_of}) ne 'CODE';
    }

    my $self = bless {
        name => $config{name},
        description => $config{description} || '',
        is_type_of => $config{is_type_of},

        _type_config => \%config,
        _fields => undef,
        _interfaces => undef,
    }, $class;

    return $self;
}

sub get_fields {
    my $self = shift;
    return $self->{_fields}
        || ($self->{_fields} = define_field_map($self, $self->{_type_config}{fields}));
}

sub get_interfaces {
    my $self = shift;
    return $self->{_interfaces}
        || ($self->{_interfaces} = define_interfaces($self, $self->{_type_config}{interfaces}));
}

sub to_string { shift->name }

sub to_json { shift->to_string }
sub inspect { shift->to_string }

1;

__END__

Object Type Definition

Almost all of the GraphQL types you define will be object types. Object types
have a name, but most importantly describe their fields.

Example:

    const AddressType = new GraphQLObjectType({
      name: 'Address',
      fields: {
        street: { type: GraphQLString },
        number: { type: GraphQLInt },
        formatted: {
          type: GraphQLString,
          resolve(obj) {
            return obj.number + ' ' + obj.street
          }
        }
      }
    });

When two types need to refer to each other, or a type needs to refer to
itself in a field, you can use a function expression (aka a closure or a
thunk) to supply the fields lazily.

Example:

    const PersonType = new GraphQLObjectType({
      name: 'Person',
      fields: () => ({
        name: { type: GraphQLString },
        bestFriend: { type: PersonType },
      })
    });
