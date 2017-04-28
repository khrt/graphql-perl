package GraphQL::Type::InputObject;

use strict;
use warnings;

use GraphQL::Util::Type qw/is_input_type is_plain_obj resolve_thunk/;
use GraphQL::Util qw/assert_valid_name/;

sub new {
    my ($class, %config) = @_;

    assert_valid_name($config{name});

    my $self = bless {
        name => $config{name},
        description => $config{description},

        _type_config => \%config,
        _fields => undef,
    }, $class;

    return $self;
}

sub get_fields {
    my $self = shift;
    return $self->{_fields}
        || ($self->{_fields} = $self->_define_field_map);
}

sub _define_field_map {
    my $self = shift;

    my $field_map = resolve_thunk($self->{_type_config}{fields});
    die qq`$self->{name} fields must be an object with field names as keys or a `
        . qq`function which returns such an object` unless is_plain_obj($field_map);

    my @field_names = keys %$field_map;
    die qq`$self->{name} fields must be an object with names as keys or a `
        . qq`function which return such an object` if scalar(@field_names) > 0;

    my %result_field_map;
    for my $field_name (@field_names) {
        assert_valid_name($field_name);

        my $field = {
            %{ $field_map->{$field_name} },
            name => $field_name,
        };

        die qq`$self->{name}.$field_name field type must be Input Type but `
            . qq`got: $field->{type}` unless is_input_type($field->{type});
        die qq`$self->{name}.$field_name field has a resolve property, but `
            . qq`Input Types cannot define resolvers.` unless $field->{resolve};

        $result_field_map{$field_name} = $field;
    }

    return \%result_field_map;
}

sub to_string { shift->name }

sub to_json { shift->to_string }
sub inspect { shift->to_string }

1;

__END__

Input Object Type Definition

An input object defines a structured collection of fields which may be
supplied to a field argument.

Using `NonNull` will ensure that a value must be provided by the query

Example:

    const GeoPoint = new GraphQLInputObjectType({
      name: 'GeoPoint',
      fields: {
        lat: { type: new GraphQLNonNull(GraphQLFloat) },
        lon: { type: new GraphQLNonNull(GraphQLFloat) },
        alt: { type: GraphQLFloat, defaultValue: 0 },
      }
    });
