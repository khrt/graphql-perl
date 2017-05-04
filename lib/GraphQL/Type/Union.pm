package GraphQL::Type::Union;

use strict;
use warnings;

use GraphQL::Util qw/assert_valid_name/;
use GraphQL::Util::Type qw/define_types/;

sub name { shift->{name} }

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
        _types => undef,
        _possible_type_names => undef,
    }, $class;

    return $self;
}

sub get_types {
    my $self = shift;
    return $self->{_types}
        || ($self->{_types} = define_types($self, $self->{_type_config}{types}));
}

sub to_string { shift->name }

sub to_json { shift->to_string }
sub inspect { shift->to_string }

1;

__END__

Union Type Definition

When a field can return one of a heterogeneous set of types, a Union type
is used to describe what types are possible as well as providing a function
to determine which type is actually used when the field is resolved.

Example:

    const PetType = new GraphQLUnionType({
      name: 'Pet',
      types: [ DogType, CatType ],
      resolveType(value) {
        if (value instanceof Dog) {
          return DogType;
        }
        if (value instanceof Cat) {
          return CatType;
        }
      }
    });
