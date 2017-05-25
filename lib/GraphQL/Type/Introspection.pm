package GraphQL::Type::Introspection;

use strict;
use warnings;

use DDP;

use constant {
    SCALAR => 'SCALAR',
    OBJECT => 'OBJECT',
    INTERFACE => 'INTERFACE',
    UNION => 'UNION',
    ENUM => 'ENUM',
    INPUT_OBJECT => 'INPUT_OBJECT',
    LIST => 'LIST',
    NON_NULL => 'NON_NULL',
};

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

    SchemaMetaFieldDef
    TypeMetaFieldDef
    TypeNameMetaFieldDef
/);

use GraphQL::Error qw/GraphQLError/;
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
use GraphQL::Type::Directive;
use GraphQL::Util qw/
    ast_from_value
/;
use GraphQL::Util::Type qw/is_abstract_type/;

sub DirectiveLocation { 'GraphQL::Type::Directive' }

sub __TypeKind {
    GraphQLEnumType(
        name => '__TypeKind',
        is_introspection => 1,
        description => 'An enum describing what kind of type a given `__Type` is.',
        values => {
            SCALAR => {
                value => SCALAR,
                description => 'Indicates this type is a scalar.'
            },
            OBJECT => {
                value => OBJECT,
                description => 'Indicates this type is an object. '
                             . '`fields` and `interfaces` are valid fields.'
            },
            INTERFACE => {
                value => INTERFACE,
                description => 'Indicates this type is an interface. '
                             . '`fields` and `possible_types` are valid fields.'
            },
            UNION => {
                value => UNION,
                description => 'Indicates this type is a union. '
                             . '`possible_types` is a valid field.'
            },
            ENUM => {
                value => ENUM,
                description => 'Indicates this type is an enum. '
                             . '`enum_values` is a valid field.'
            },
            INPUT_OBJECT => {
                value => INPUT_OBJECT,
                description => 'Indicates this type is an input object. '
                             . '`input_fields` is a valid field.'
            },
            LIST => {
                value => LIST,
                description => 'Indicates this type is a list. '
                             . '`of_type` is a valid field.'
            },
            NON_NULL => {
                value => NON_NULL,
                description => 'Indicates this type is a non-null. '
                             . '`of_type` is a valid field.'
            },
        },
    );
}

sub __EnumValue {
    GraphQLObjectType(
        name => '__EnumValue',
        is_introspection => 1,
        description =>
              'One possible value for a given Enum. Enum values are unique values, not '
            . 'a placeholder for a string or numeric value. However an Enum value is '
            . 'returned in a JSON response as a string.',
        fields => sub { {
            name => { type => GraphQLNonNull(GraphQLString) },
            description => { type => GraphQLString },
            is_deprecated => { type => GraphQLNonNull(GraphQLBoolean) },
            deprecation_reason => { type => GraphQLString }
        } },
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
        fields => sub { {
            name => { type => GraphQLNonNull(GraphQLString) },
            description => { type => GraphQLString },
            type => { type => GraphQLNonNull(&__Type) },
            default_value => {
                type => GraphQLString,
                description => 'A GraphQL-formatted string representing the default value for this input value.',
                resolve => sub {
                    my ($input_val) = @_;
                    return defined($input_val->{default_value})
                        ? print_doc(ast_from_value($input_val->{default_value}, $input_val->{type}))
                        : undef;
                },
            }
        } },
    );
}

sub __Field {
    GraphQLObjectType(
        name => '__Field',
        is_introspection => 1,
        description =>
              'Object and Interface types are described by a list of Fields, each of '
            . 'which has a name, potentially a list of arguments, and a return type.',
        fields => sub { {
            name => { type => GraphQLNonNull(GraphQLString) },
            description => { type => GraphQLString },
            args => {
                type => GraphQLNonNull(GraphQLList(GraphQLNonNull(__InputValue))),
                resolve => sub {
                    my ($field) = @_;
                    return $field->args || [];
                },
            },
            type => { type => GraphQLNonNull(&__Type) },
            is_deprecated => { type => GraphQLNonNull(GraphQLBoolean) },
            deprecation_reason => {
                type => GraphQLString,
            }
        } },
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
        fields => sub { {
            kind => {
                type => GraphQLNonNull(__TypeKind),
                resolve => sub {
                    my ($type) = @_;

                    if ($type->isa('GraphQL::Type::Scalar')) {
                        return SCALAR;
                    }
                    elsif ($type->isa('GraphQL::Type::Object')) {
                        return OBJECT;
                    }
                    elsif ($type->isa('GraphQL::Type::Interface')) {
                        return INTERFACE;
                    }
                    elsif ($type->isa('GraphQL::Type::Union')) {
                        return UNION;
                    }
                    elsif ($type->isa('GraphQL::Type::Enum')) {
                        return ENUM;
                    }
                    elsif ($type->isa('GraphQL::Type::InputObject')) {
                        return INPUT_OBJECT;
                    }
                    elsif ($type->isa('GraphQL::Type::List')) {
                        return LIST;
                    }
                    elsif ($type->isa('GraphQL::Type::NonNull')) {
                        return NON_NULL;
                    }

                    die GraphQLError("Unknown kind of type: $type");
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
                    my ($type, $args) = @_;
                    my $include_deprecated = $args->{include_deprecated};

                    if (   $type->isa('GraphQL::Type::Object')
                        || $type->isa('GraphQL::Type::Interface'))
                    {
                        my $field_map = $type->get_fields;
                        my @fields = map { $field_map->{$_} } keys %$field_map;

                        if (!$include_deprecated) {
                            @fields = grep { !$_->{deprecation_reason} } @fields;
                        }

                        return \@fields;
                    }

                    return;
                },
            },
            interfaces => {
                type => GraphQLList(GraphQLNonNull($__Type)),
                resolve => sub {
                    my ($type) = @_;
                    if ($type->isa('GraphQL::Type::Object')) {
                        return $type->get_interfaces;
                    }
                    return;
                }
            },
            possible_types => {
                type => GraphQLList(GraphQLNonNull($__Type)),
                resolve => sub {
                    my ($type, $args, $context, $info) = @_;
                    my $schema = $info->{schema};

                    if (is_abstract_type($type)) {
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
                    my ($type, $args) = @_;
                    my $include_deprecated = $args->{include_deprecated};

                    if ($type->isa('GraphQL::Type::Enum')) {
                        my $values = $type->get_values;

                        if (!$include_deprecated) {
                            $values = [grep { !$_->{deprecation_reason} } @$values];
                        }

                        return $values;
                    }

                    return;
                }
            },
            input_fields => {
                type => GraphQLList(GraphQLNonNull(__InputValue)),
                resolve => sub {
                    my ($type) = @_;

                    if ($type->isa('GraphQL::Type::InputObject')) {
                        my $field_map = $type->get_fields;
                        return [map { $field_map->{$_} } keys %$field_map];
                    }

                    return;
                }
            },
            of_type => { type => $__Type }
        } },
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
        fields => sub { {
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
                    die;
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
        } },
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
        fields => sub { {
            types => {
                description => 'A list of all types supported by this server.',
                type => GraphQLNonNull(GraphQLList(GraphQLNonNull(__Type))),
                resolve => sub {
                    my ($schema) = @_;
                    my $type_map = $schema->get_type_map;
                    return [map { $type_map->{$_} } keys %$type_map];
                }
            },
            query_type => {
                description => 'The type that query operations will be rooted at.',
                type => GraphQLNonNull(__Type),
                resolve => sub {
                    my ($schema) = @_;
                    $schema->get_query_type;
                },
            },
            mutation_type => {
                description => 'If this server supports mutation, the type that '
                             . 'mutation operations will be rooted at.',
                type => __Type,
                resolve => sub {
                    my ($schema) = @_;
                    $schema->get_mutation_type;
                },
            },
            subscription_type => {
                description => 'If this server support subscription, the type that '
                             . 'subscription operations will be rooted at.',
                type => __Type,
                resolve => sub {
                    my ($schema) = @_;
                    $schema->get_subscription_type;
                },
            },
            directives => {
                description => 'A list of all directives supported by this server.',
                type => GraphQLNonNull(GraphQLList(GraphQLNonNull(__Directive))),
                resolve => sub {
                    my ($schema) = @_;
                    $schema->get_directives;
                },
            }
        } },
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
            my ($source, $args, $context, $info) = @_;
            return $info->{schema};
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
            my ($source, $args, $context, $info) = @_;
            return $info->{schema}->get_type($args->{name});
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
            my ($source, $args, $context, $info) = @_;
            return $info->{parent_type}->name;
        },
    }
}

1;

__END__
