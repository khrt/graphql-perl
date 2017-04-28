package GraphQL::Type::Introspection;

use strict;
use warnings;

use GraphQL::Language::Printer qw/print_doc/;
use GraphQL::Type qw/
    GraphQLScalarType
    GraphQLObjectType
    GraphQLInterfaceType
    GraphQLUnionType
    GraphQLEnumType
    GraphQLInputObjectType
    GraphQLList
    GraphQLNonNull

    GraphQLString
    GraphQLBoolean

/;
    # GraphQLField

    # DirectiveLocation

use Exporter qw/import/;

our @EXPORT_OK = (qw/
    __Schema
    __Directive
    __DirectiveLocation
    __Type
    __Field
    __InputValue
    __EnumValue
    __TypeKind

    TypeKind
/);

sub __TypeKind {
    GraphQLEnumType(
        name => '__TypeKind',
        is_introspection => 1,
        description => 'An enum describing what kind of type a given `__Type` is.',
        values => {
            SCALAR => {
                value => TypeKind->SCALAR,
                description => 'Indicates this type is a scalar.'
            },
            OBJECT => {
                value => TypeKind->OBJECT,
                description => 'Indicates this type is an object. ' +
                '`fields` and `interfaces` are valid fields.'
            },
            INTERFACE => {
                value => TypeKind->INTERFACE,
                description => 'Indicates this type is an interface. ' +
                '`fields` and `possibleTypes` are valid fields.'
            },
            UNION => {
                value => TypeKind->UNION,
                description => 'Indicates this type is a union. ' +
                '`possibleTypes` is a valid field.'
            },
            ENUM => {
                value => TypeKind->ENUM,
                description => 'Indicates this type is an enum. ' +
                '`enumValues` is a valid field.'
            },
            INPUT_OBJECT => {
                value => TypeKind->INPUT_OBJECT,
                description => 'Indicates this type is an input object. ' +
                '`inputFields` is a valid field.'
            },
            LIST => {
                value => TypeKind->LIST,
                description => 'Indicates this type is a list. ' +
                '`ofType` is a valid field.'
            },
            NON_NULL => {
                value => TypeKind->NON_NULL,
                description => 'Indicates this type is a non-null. ' +
                '`ofType` is a valid field.'
            },
        },
    );
}

sub TypeKind {
  # SCALAR: 'SCALAR',
  # OBJECT: 'OBJECT',
  # INTERFACE: 'INTERFACE',
  # UNION: 'UNION',
  # ENUM: 'ENUM',
  # INPUT_OBJECT: 'INPUT_OBJECT',
  # LIST: 'LIST',
  # NON_NULL: 'NON_NULL',
}

sub __EnumValue {
    GraphQLObjectType(
        name => '__EnumValue',
        is_introspection => 1,
        description =>
              'One possible value for a given Enum. Enum values are unique values, not '
            . 'a placeholder for a string or numeric value. However an Enum value is '
            . 'returned in a JSON response as a string.',
        fields => sub {

        },
    );
}

sub __InputValue {
    GraphQLObjectType(
        name => '__InputValue',
        is_introspection => 1,
        description =>
              'Arguments provided to Fields or Directives and the input fields of an '
            . 'InputObject are represented as Input Values which describe their type '
            . 'and optionally a default value.',
        fields => sub {

        },
    );
}

sub __Field {
    GraphQLObjectType(
        name => '__Field',
        is_introspection => 1,
        description =>
              'Object and Interface types are described by a list of Fields, each of '
            . 'which has a name, potentially a list of arguments, and a return type.',
        fields => sub {
            name => { type => GraphQLNonNull(GraphQLString) },
            description => { type => GraphQLString },
            args => {
                type => GraphQLNonNull(GraphQLList(GraphQLNonNull(__InputValue))),
                resolve => sub {
                    my (undef, $field) = @_;
                    $field->args || [];
                },
            },
            # TODO: type => { type => GraphQLNonNull(__Type) },
            isDeprecated => { type => GraphQLNonNull(GraphQLBoolean) },
            deprecationReason => {
                type => GraphQLString,
            }
        },
    );
}

sub __Type {
    my $__Type;
    $__Type = GraphQLObjectType(
        name => '__Type',
        is_introspection => 1,
        description =>
              "The fundamental unit of any GraphQL Schema is the type. There are "
            . "many kinds of types in GraphQL as represented by the `__TypeKind` enum."
            . "\n\nDepending on the kind of a type, certain fields describe "
            . "information about that type. Scalar types provide no information "
            . "beyond a name and description, while Enum types provide their values. "
            . "Object and Interface types provide the fields they describe. Abstract "
            . "types, Union and Interface, provide the Object types possible "
            . "at runtime. List and NonNull types compose other types.",
        fields => sub {
            kind => {
                type => GraphQLNonNull(__TypeKind),
                resolve => sub {
                    my (undef, $type) = @_;

                    if ($type->isa(GraphQLScalarType)) {
                        return TypeKind->SCALAR;
                    }
                    elsif ($type->isa(GraphQLObjectType)) {
                        return TypeKind->OBJECT;
                    }
                    elsif ($type->isa(GraphQLInterfaceType)) {
                        return TypeKind->INTERFACE;
                    }
                    elsif ($type->isa(GraphQLUnionType)) {
                        return TypeKind->UNION;
                    }
                    elsif ($type->isa(GraphQLEnumType)) {
                        return TypeKind->ENUM;
                    }
                    elsif ($type->isa(GraphQLInputObjectType)) {
                        return TypeKind->INPUT_OBJECT;
                    }
                    elsif ($type->isa(GraphQLList)) {
                        return TypeKind->LIST;
                    }
                    elsif ($type->isa(GraphQLNonNull)) {
                        return TypeKind->NON_NULL;
                    }

                    die "Unknown kind of type => $type";
                }
            },
            name => { type => GraphQLString },
            description => { type => GraphQLString },
            fields => {
                type => GraphQLList(GraphQLNonNull(__Field)),
                args => {
                    include_deprecated => { type => GraphQLBoolean, default_value => 0 }
                },
                resolve => sub {
                    my (undef, $type, $args) = @_;
                    my $include_deprecated = $args->{include_deprecated};

                    if (   $type->isa(GraphQLObjectType)
                        || $type->isa(GraphQLInterfaceType))
                    {
                        my $field_map = $type->get_fields;
                        my %fields = map { $_ => $field_map->{$_} } keys %$field_map;

                        if (!$include_deprecated) {
                            die;
                            #$fields = $fields->filter(field => !$field->deprecationReason);
                        }

                        return \%fields;
                    }

                    return;
                },
            },
            interfaces => {
                type => GraphQLList(GraphQLNonNull($__Type)),
                resolve => sub {
                    my (undef, $type) = @_;
                    if ($type->isa(GraphQLObjectType)) {
                        return $type->get_interfaces;
                    }
                    return;
                }
            },
            possible_types => {
                type => GraphQLList(GraphQLNonNull($__Type)),
                resolve => sub {
                    # TODO parameter name xxx
                    my (undef, $type, $args, $context, $xxx) = @_;
                    my $schema = $xxx->{schema};

                    if (   $type->isa(GraphQLInterfaceType)
                        || $type->isa(GraphQLUnionType))
                    {
                        return $schema->get_possible_types($type);
                    }

                    return;
                }
            },
            enum_values => {
                type => GraphQLList(GraphQLNonNull(__EnumValue)),
                args => {
                    include_deprecated => { type => GraphQLBoolean, default_value => 0 }
                },
                resolve => sub {
                    my (undef, $type, $args) = @_;
                    my $include_deprecated = $args->{include_deprecated};

                    if ($type->isa(GraphQLEnumType)) {
                        my $values = $type->get_values;

                        if (!$include_deprecated) {
                            die;
                            # values = values->filter(value => !value->deprecationReason);
                        }

                        return $values;
                    }

                    return;
                }
            },
            input_fields => {
                type => GraphQLList(GraphQLNonNull(__InputValue)),
                resolve => sub {
                    my (undef, $type) = @_;

                    if ($type->isa(GraphQLInputObjectType)) {
                        my $field_map = $type->get_fields;
                        return [map { $_ => $field_map->{$_} } keys %$field_map];
                    }

                    return;
                }
            },
            of_type => { type => $__Type }
        },
    );
}

sub __DirectiveLocation {
    GraphQLEnumType(
        name => '__DirectiveLocation',
        is_introspection => 1,
        description =>
              'A Directive can be adjacent to many parts of the GraphQL language, a '
            . '__DirectiveLocation describes one such possible adjacencies.',
            values => {
                QUERY => {
                    value => DirectiveLocation->QUERY,
                    description => 'Location adjacent to a query operation.'
                },
                MUTATION => {
                    value => DirectiveLocation->MUTATION,
                    description => 'Location adjacent to a mutation operation.'
                },
                SUBSCRIPTION => {
                    value => DirectiveLocation->SUBSCRIPTION,
                    description => 'Location adjacent to a subscription operation.'
                },
                FIELD => {
                    value => DirectiveLocation->FIELD,
                    description => 'Location adjacent to a field.'
                },
                FRAGMENT_DEFINITION => {
                    value => DirectiveLocation->FRAGMENT_DEFINITION,
                    description => 'Location adjacent to a fragment definition.'
                },
                FRAGMENT_SPREAD => {
                    value => DirectiveLocation->FRAGMENT_SPREAD,
                    description => 'Location adjacent to a fragment spread.'
                },
                INLINE_FRAGMENT => {
                    value => DirectiveLocation->INLINE_FRAGMENT,
                    description => 'Location adjacent to an inline fragment.'
                },
                SCHEMA => {
                    value => DirectiveLocation->SCHEMA,
                    description => 'Location adjacent to a schema definition.'
                },
                SCALAR => {
                    value => DirectiveLocation->SCALAR,
                    description => 'Location adjacent to a scalar definition.'
                },
                OBJECT => {
                    value => DirectiveLocation->OBJECT,
                    description => 'Location adjacent to an object type definition.'
                },
                FIELD_DEFINITION => {
                    value => DirectiveLocation->FIELD_DEFINITION,
                    description => 'Location adjacent to a field definition.'
                },
                ARGUMENT_DEFINITION => {
                    value => DirectiveLocation->ARGUMENT_DEFINITION,
                    description => 'Location adjacent to an argument definition.'
                },
                INTERFACE => {
                    value => DirectiveLocation->INTERFACE,
                    description => 'Location adjacent to an interface definition.'
                },
                UNION => {
                    value => DirectiveLocation->UNION,
                    description => 'Location adjacent to a union definition.'
                },
                ENUM => {
                    value => DirectiveLocation->ENUM,
                    description => 'Location adjacent to an enum definition.'
                },
                ENUM_VALUE => {
                    value => DirectiveLocation->ENUM_VALUE,
                    description => 'Location adjacent to an enum value definition.'
                },
                INPUT_OBJECT => {
                    value => DirectiveLocation->INPUT_OBJECT,
                    description => 'Location adjacent to an input object type definition.'
                },
                INPUT_FIELD_DEFINITION => {
                    value => DirectiveLocation->INPUT_FIELD_DEFINITION,
                    description => 'Location adjacent to an input object field definition.'
                },
            }
    );
}

sub __Directive {
    GraphQLObjectType(
        name => '__Directive',
        is_introspection => 1,
        description =>
              "A Directive provides a way to describe alternate runtime execution and "
            . "type validation behavior in a GraphQL document."
            . "\n\nIn some cases, you need to provide options to alter GraphQL\"s "
            . "execution behavior in ways field arguments will not suffice, such as "
            . "conditionally including or skipping a field. Directives provide this by "
            . "describing additional information to the executor.",
        fields => sub {
            name => { type => GraphQLNonNull(GraphQLString) },
            description => { type => GraphQLString },
            locations => {
                type => GraphQLNonNull(GraphQLList(GraphQLNonNull(__DirectiveLocation)))
            },
            args => {
                type => GraphQLNonNull(GraphQLList(GraphQLNonNull(__InputValue))),
                resolve => sub {
                    my (undef, $d) = @_;
                    $d->args || [];
                },
            },
            # NOTE: the following three fields are deprecated and are no longer part
            # of the GraphQL specification.
            on_operation => {
                deprecation_reason => 'Use `locations`.',
                type => GraphQLNonNull(GraphQLBoolean),
                resolve => sub {
                    my (undef, $d) = @_;
                    $d->locations->indexOf(DirectiveLocation->QUERY) != -1 ||
                    $d->locations->indexOf(DirectiveLocation->MUTATION) != -1 ||
                    $d->locations->indexOf(DirectiveLocation->SUBSCRIPTION) != -1;
                },
            },
            on_fragment => {
                deprecation_reason => 'Use `locations`.',
                type => GraphQLNonNull(GraphQLBoolean),
                resolve => sub {
                    my (undef, $d) = @_;
                    $d->locations->indexOf(DirectiveLocation->FRAGMENT_SPREAD) != -1 ||
                    $d->locations->indexOf(DirectiveLocation->INLINE_FRAGMENT) != -1 ||
                    $d->locations->indexOf(DirectiveLocation->FRAGMENT_DEFINITION) != -1;
                },
            },
            on_field => {
                deprecation_reason => 'Use `locations`.',
                type => GraphQLNonNull(GraphQLBoolean),
                resolve => sub {
                    my (undef, $d) = @_;
                    $d->locations->indexOf(DirectiveLocation->FIELD) != -1;
                }
            },
        }
    );
}

sub __Schema {
    GraphQLObjectType(
        name => '__Schema',
        is_introspection => 1,
        description =>
              'A GraphQL Schema defines the capabilities of a GraphQL server. It '
            . 'exposes all available types and directives on the server, as well as '
            . 'the entry points for query, mutation, and subscription operations.',
        fields => sub {
            types => {
                description => 'A list of all types supported by this server.',
                type => GraphQLNonNull(GraphQLList(GraphQLNonNull(__Type))),
                resolve => sub {
                    my ($self, $schema) = @_;
                    my $type_map = $schema->get_type_map;
                    return { map { $_ => $type_map->{$_} } keys %$type_map };
                }
            },
            queryType => {
                description => 'The type that query operations will be rooted at.',
                type => GraphQLNonNull(__Type),
                resolve => sub {
                    my ($self, $schema) = @_;
                    $schema->get_query_type;
                },
            },
            mutationType => {
                description => 'If this server supports mutation, the type that '
                             . 'mutation operations will be rooted at.',
                type => __Type,
                resolve => sub {
                    my ($self, $schema) = @_;
                    $schema->get_mutation_type;
                },
            },
            subscriptionType => {
                description => 'If this server support subscription, the type that '
                             . 'subscription operations will be rooted at.',
                type => __Type,
                resolve => sub {
                    my ($self, $schema) = @_;
                    $schema->get_subscription_type;
                },
            },
            directives => {
                description => 'A list of all directives supported by this server.',
                type => GraphQLNonNull(GraphQLList(GraphQLNonNull(__Directive))),
                resolve => sub {
                    my ($self, $schema) = @_;
                    $schema->get_directives;
                },
            }
        },
    )
}

#
# Note that there are GraphQLField and not GraphQLFieldConfig,
# so the format for args is different
#

sub SchemaMetaFieldDef {
    {
        name => '__schema',
        type => GraphQLNonNull(__Schema),
        description => 'Access the current type schema of this server.',
        args => [],
        resolve => sub {
            my (undef, $source, $args, $context, $xxx) = @_;
            # TODO: rename xxx
            $xxx->{schema};
        },
    }
}

sub TypeMetaFieldDef {
    {
        name => '__type',
        type => __Type,
        description => 'Request the type information of a single type.',
        args => [
            { name => 'name', type => GraphQLNonNull(GraphQLString) }
        ],
        resolve => sub {
            my (undef, $source, $args, $context, $xxx) = @_;
            # TODO: rename xxx
            $xxx->{schema}->get_type($args->{name});
        },
    }
}
sub TypeNameMetaFieldDef {
    {
        name => '__typename',
        type => GraphQLNonNull(GraphQLString),
        description => 'The name of the current Object type at runtime.',
        args => [],
        resolve => sub {
            my (undef, $source, $args, $context, $xxx) = @_;
            # TODO: rename xxx
            $xxx->{parent_type}->name;
        },
    }
}

1;

__END__
