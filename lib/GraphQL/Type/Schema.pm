package GraphQL::Type::Schema;

use strict;
use warnings;

use feature 'say';

use DDP {
    indent => 2,
    # max_depth => 3,
    index => 0,
    class => {
        internals => 0,
        show_methods => 'none',
    },
    filters => {
        'GraphQL::Type::Enum'        => sub { shift->to_string },
        'GraphQL::Type::InputObject' => sub { shift->to_string },
        'GraphQL::Type::Interface'   => sub { shift->to_string },
        'GraphQL::Type::List'        => sub { shift->to_string },
        'GraphQL::Type::NonNull'     => sub { shift->to_string },
        'GraphQL::Type::Object'      => sub { shift->to_string },
        'GraphQL::Type::Scalar'      => sub { shift->to_string },
        'GraphQL::Type::Union'       => sub { shift->to_string },
        },
    caller_info => 0,
};

use GraphQL::Type::Introspection qw/__Schema/;
use GraphQL::Util qw/find/;
use GraphQL::Util::Type qw/is_type_subtype_of/;
use GraphQL::Util::TypeComparators qw/is_equal_type/;

sub specified_directives { 'specified_directives' }

sub new {
    my ($class, %config) = @_;

    die "Must provide configuration object.\n" if ref(\%config) ne 'HASH';

    die "Schema query must be Object Type but got: ${ \$config{query}->to_string }.\n"
        unless $config{query}->isa('GraphQL::Type::Object');

    die "Schema mutation must be Object Type if provided but got: ${ \$config{mutation}->to_string }.\n"
        if $config{mutation} && !$config{mutation}->isa('GraphQL::Type::Object');

    die "Schema subscription must be Object Type if provided but got: ${ \$config{mutation}->to_string }.\n"
        if $config{subscription} && !$config{subscription}->isa('GraphQL::Type::Object');

    die "Schema types must be Array if provided but got: ${ \$config{types}->to_string  }.\n"
        if $config{types} && ref($config{types}) ne 'ARRAY';

    die "Schema directives must be Array<GraphQLDirective> if provided but got: ${ \$config{directives}->to_string }.\n"
        if    $config{directives}
           && (   ref($config{directives}) ne 'ARRAY'
               || grep { !$_->isa('GraphQL::Type::Directive') } @{ $config{directives} });

    my $self = bless {
        _query_type => $config{query},
        _mutation_type => $config{mutation},
        _subscription_type => $config{subscription},
        # Provide specified directives (e.g. @include and @skip) by default.
        _directives => $config{directives} || specified_directives,

        _type_map => undef,
        _implementations => undef,
        _possible_type_map => undef,
    }, $class;

    my @initial_types = (
        $self->get_query_type,
        $self->get_mutation_type,
        $self->get_subscription_type,
        __Schema,
    );

    my $types = $config{types};
    if ($types) {
        push @initial_types, @$types;
    }

    for (@initial_types) {
        $self->{_type_map} = {
            %{ $self->{_type_map} || {} },
            %{ type_map_reducer({}, $_) },
        };
    }

    # Keep track of all implementations by interface name.
    $self->{_implementations} = {};
    for my $type_name (keys %{ $self->{_type_map} }) {
        my $type = $self->{_type_map}{ $type_name };

        if ($type->isa('GraphQL::Type::Object')) {
            for my $iface (@{ $type->get_interfaces }) {
                my $impls = $self->{_implementations}{ $iface->name };

                if ($impls) {
                    push @$impls, $type;
                }
                else {
                    $self->{_implementations}{ $iface->name } = [$type];
                }
            }
        }
    }

    # Enforce correct interface implementations.
    for my $type_name (keys %{ $self->{_type_map} }) {
        my $type = $self->{_type_map}{ $type_name };

        if ($type->isa('GraphQL::Type::Object')) {
            for my $iface (@{ $type->get_interfaces }) {
                assert_object_implements_interface($self, $type, $iface);
            }
        }
    }

    return $self;
}

sub get_query_type { shift->{_query_type} }
sub get_mutation_type { shift->{_mutation_type} }
sub get_subscription_type { shift->{_subscription_type} }
sub get_type_map { shift->{_type_map} }

sub get_type {
    my ($self, $name) = @_;
    return $self->get_type_map->{$name};
}

sub get_possible_types {
    my ($self, $abstract_type) = @_;

    if ($abstract_type->isa('GraphQL::Type::Union')) {
        return $abstract_type->get_types;
    }

    die 'Interface expected' unless $abstract_type->isa('GraphQL::Type::Interface');
    return $self->{_implementations}{ $abstract_type->name };
}

sub is_possible_type {
    my ($self, $abstract_type, $possible_type) = @_;

    my $possible_type_map = $self->{_possible_type_map};
    if (!$possible_type_map) {
        $self->{_possible_type_map} = $possible_type_map = {};
    }

    if (!$possible_type_map->{ $abstract_type->name }) {
        my $possible_types = $self->get_possible_types($abstract_type);

        die   "Could not find possible implementing types for ${ \$abstract_type->name } "
            . "in schema. Check that schema.types is defined and is an array of "
            . "all possible types in the schema.\n" if ref($possible_types) ne 'ARRAY';

die 'TODO';
        $possible_type_map->{ $abstract_type->name } = \grep {
            1
            # TODO: (map, type) => ((map[type.name] = true), map),
        } @$possible_types;
    }

    return !!$possible_type_map->{ $abstract_type->name }{ $possible_type->name };
}

sub get_directives { shift->{_directives} }

sub get_directive {
    my ($self, $name) = @_;
    return find($self->get_directives, sub { shift->{name} eq $name });
}


##

sub type_map_reducer {
    my ($map, $type) = @_;

    return $map unless $type;

    if ($type->isa('GraphQL::Type::List') || $type->isa('GraphQL::Type::NonNull')) {
        return type_map_reducer($map, $type->of_type);
    }

    if ($map->{ $type->name }) {
        die   "Schema must contain unique types but contains multiple"
            . "types named ${ \$type->name }.\n" if $map->{ $type->name }->to_string ne $type->to_string;
        return $map;
    }

    $map->{ $type->name } = $type;

    if ($type->isa('GraphQL::Type::Union')) {
        for (@{ $type->get_types }) {
            $map = {
                %$map,
                %{ type_map_reducer($map, $_) },
            };
        }
    }

    if ($type->isa('GraphQL::Type::Object')) {
        for (@{ $type->get_interfaces }) {
            $map = {
                %$map,
                %{ type_map_reducer($map, $_) },
            };
        }
    }

    if (   $type->isa('GraphQL::Type::Object')
        || $type->isa('GraphQL::Type::Interface'))
    {
        my $field_map = $type->get_fields;

        for my $field_name (keys %$field_map) {
            my $field = $field_map->{ $field_name };

            if ($field->{args}) {
                my @field_arg_types = map { $_->{type} } @{ $field->{args} };

                for (@field_arg_types) {
                    $map = {
                        %$map,
                        %{ type_map_reducer($map, $_) },
                    };
                }
            }

            $map = {
                %$map,
                %{ type_map_reducer($map, $field->{type}) },
            };
        }
    }

    if ($type->isa('GraphQL::Type::InputObject')) {
        my $field_map = $type->get_fields;

        for my $field_name (keys %$field_map) {
            my $field = $field_map->{ $field_name };
            $map = {
                %$map,
                %{ type_map_reducer($map, $field->{type}) },
            };
        }
    }

    return $map;
}

sub assert_object_implements_interface {
    my ($schema, $object, $iface) = @_;

    my $object_field_map = $object->get_fields;
    my $iface_field_map = $iface->get_fields;

    # Assert each interface field is implemented.
    for my $field_name (keys %$iface_field_map) {
        my $object_field = $object_field_map->{ $field_name };
        my $iface_field = $iface_field_map->{ $field_name };

        # Assert interface field exists on object.
        die qq`"${ \$iface->name }" expects field "$field_name" but "${ \$object->name }" `
            . 'does not provide it.' unless $object_field;

        # Assert interface field type is satisfied by object field type, by being
        # a valid subtype. (covariant)
        die   qq`${ \$iface->{name} }.$field_name expects type "${ \$iface_field->{type}->to_string }" `
            . qq`but `
            . qq`${ \$object->{name} }.$field_name provides type "${ \$object_field->{type}->to_string }".`
            unless is_type_subtype_of($schema, $object_field->{type}, $iface_field->{type});

        # Assert interface field arg type matches object field arg type.
        # (invariant)
        for my $iface_arg (@{ $iface_field->{args} }) {
            my $arg_name = $iface_arg->{name};
            my $object_arg =
                find($object_field->{args}, sub { shift->{name} eq $arg_name });

            # Assert interface field arg exists on object field.
            die   qq`${ \$iface->name }.$field_name expects argument "$arg_name" but `
                . qq`${ \$object->name }.$field_name does not provide it.` unless $object_arg;

            # Assert interface field arf type matches object field arg type.
            # (invariant)
            die   qq`${ \$iface->name }.$field_name($arg_name:) expects type `
                . qq`"${ \$iface_arg->{type}->to_string }" but `
                . qq`${ \$object->name }.$field_name($arg_name:) provides type `
                . qq`"${ \$object_arg->{type}->to_string }".`
                unless is_equal_type($iface_arg->{type}, $object_arg->{type});
        }

        # Assert additional arguments must not be required.
        for my $object_arg (@{ $object_field->{args} }) {
            my $arg_name = $object_arg->{name};
            my $iface_arg =
                find($iface_field->{args}, sub { shift->{name} eq $arg_name });

            if (!$iface_arg) {
                die   qq`${ \$object->name }.$field_name($arg_name:) is of required type `
                    . qq`"${ \$object_arg->{type}->to_string }" but is not also provided by the `
                    . qq`interface ${ \$iface->name }.$field_name.`
                    if $object_arg->{type}->isa('GraphQL::Type::NonNull');
            }
        }
    }
}

1;

__END__

Schema Definition

A Schema is created by supplying the root types of each type of operation,
query and mutation (optional). A schema definition is then supplied to the
validator and executor.

Example:

    const MyAppSchema = new GraphQLSchema({
      query: MyAppQueryRootType,
      mutation: MyAppMutationRootType,
    })

Note: If an array of `directives` are provided to GraphQLSchema, that will be
the exact list of directives represented and allowed. If `directives` is not
provided then a default set of the specified directives (e.g. @include and
@skip) will be used. If you wish to provide *additional* directives to these
specified directives, you must explicitly declare them. Example:

    const MyAppSchema = new GraphQLSchema({
      ...
      directives: specifiedDirectives.concat([ myCustomDirective ]),
    })
