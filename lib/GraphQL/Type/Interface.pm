package GraphQL::Type::Interface;

use strict;
use warnings;

use GraphQL::Util qw/assert_valid_name/;
use GraphQL::Util::Type qw/resolve_thunk define_field_map/;

sub name { shift->{name} }
sub resolve_type { shift->{resolve_type} }

sub new {
    my ($class, %config) = @_;

    assert_valid_name($config{name});

    if ($config{resolve_type}) {
        die qq`$config{name} must provide "resolve_type" as a function.`
            if ref($config{resolve_type}) ne 'CODE';
    }

    my $self = bless {
        name => $config{name},
        description => $config{description} || '',
        resolve_type => $config{resolve_type},

        _type_config => \%config,
        _fields => undef,
    }, $class;

    return $self;
}

sub get_fields {
    my $self = shift;
    return $self->{_fields}
        || ($self->{_fields} = define_field_map($self, $self->{_type_config}{fields}));
}

sub to_string { shift->name }

sub to_json { shift->to_string }
sub inspect { shift->to_string }

1;

__END__

Interface Type Definition

When a field can return one of a heterogeneous set of types, a Interface type
is used to describe what types are possible, what fields are in common across
all types, as well as a function to determine which type is actually used
when the field is resolved.

Example:

    const EntityType = new GraphQLInterfaceType({
      name: 'Entity',
      fields: {
        name: { type: GraphQLString }
      }
    });
