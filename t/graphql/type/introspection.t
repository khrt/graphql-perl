
use strict;
use warnings;

use DDP;
use Test::More;
use Test::Deep;
use JSON qw/encode_json/;

use GraphQL qw/graphql :types/;

subtest 'executes an introspection query'=> sub {
    plan skip_all => 'TODO';

    my $introspection_query = <<'EOQ';
query IntrospectionQuery {
  __schema {
    query_type { name }
    mutation_type { name }
    subscription_type { name }
    types {
      ...FullType
    }
    directives {
      name
      description
      locations
      args {
        ...InputValue
      }
    }
  }
}

fragment FullType on __Type {
  kind
  name
  description
  fields(include_deprecated: true) {
    name
    description
    args {
      ...InputValue
    }
    type {
      ...TypeRef
    }
    is_deprecated
    deprecation_reason
  }
  input_fields {
    ...InputValue
  }
  interfaces {
    ...TypeRef
  }
  enum_values(include_deprecated: true) {
    name
    description
    is_deprecated
    deprecation_reason
  }
  possible_types {
    ...TypeRef
  }
}

fragment InputValue on __InputValue {
  name
  description
  type { ...TypeRef }
  default_value
}

fragment TypeRef on __Type {
  kind
  name
  of_type {
    kind
    name
    of_type {
      kind
      name
      of_type {
        kind
        name
        of_type {
          kind
          name
          of_type {
            kind
            name
            of_type {
              kind
              name
              of_type {
                kind
                name
              }
            }
          }
        }
      }
    }
  }
}
EOQ

    my $EmptySchema = GraphQLSchema(
        query =>  GraphQLObjectType(
            name => 'QueryRoot',
            fields => {
                onlyField => { type => GraphQLString }
            }
        )
    );

    my $res = graphql($EmptySchema, $introspection_query);
    p $res;
    cmp_deeply $res, {
        data => {
            __schema => {
                mutation_type => undef,
                subscription_type => undef,
                query_type => {
                    name => 'QueryRoot',
                },
                types => [
                    {
                        kind => 'OBJECT',
                        name => 'QueryRoot',
                        input_fields => undef,
                        interfaces => [],
                        enum_values => undef,
                        possible_types => undef,
                    },
                    {
                        kind => 'OBJECT',
                        name => '__Schema',
                        fields => [
                            {
                                name => 'types',
                                args => [],
                                type => {
                                    kind => 'NON_NULL',
                                    name => undef,
                                    of_type => {
                                        kind => 'LIST',
                                        name => undef,
                                        of_type => {
                                            kind => 'NON_NULL',
                                            name => undef,
                                            of_type => {
                                                kind => 'OBJECT',
                                                name => '__Type'
                                            }
                                        }
                                    }
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'queryType',
                                args => [],
                                type => {
                                    kind => 'NON_NULL',
                                    name => undef,
                                    of_type => {
                                        kind => 'OBJECT',
                                        name => '__Type',
                                        of_type => undef
                                    }
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'mutation_type',
                                args => [],
                                type => {
                                    kind => 'OBJECT',
                                    name => '__Type',
                                    of_type => undef
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'subscriptionType',
                                args => [],
                                type => {
                                    kind => 'OBJECT',
                                    name => '__Type',
                                    of_type => undef
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'directives',
                                args => [],
                                type => {
                                    kind => 'NON_NULL',
                                    name => undef,
                                    of_type => {
                                        kind => 'LIST',
                                        name => undef,
                                        of_type => {
                                            kind => 'NON_NULL',
                                            name => undef,
                                            of_type => {
                                                kind => 'OBJECT',
                                                name => '__Directive'
                                            }
                                        }
                                    }
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            }
                        ],
                        input_fields => undef,
                        interfaces => [],
                        enum_values => undef,
                        possible_types => undef,
                    },
                    {
                        kind => 'OBJECT',
                        name => '__Type',
                        fields => [
                            {
                                name => 'kind',
                                args => [],
                                type => {
                                    kind => 'NON_NULL',
                                    name => undef,
                                    of_type => {
                                        kind => 'ENUM',
                                        name => '__TypeKind',
                                        of_type => undef
                                    }
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'name',
                                args => [],
                                type => {
                                    kind => 'SCALAR',
                                    name => 'String',
                                    of_type => undef
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'description',
                                args => [],
                                type => {
                                    kind => 'SCALAR',
                                    name => 'String',
                                    of_type => undef
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'fields',
                                args => [
                                    {
                                        name => 'include_deprecated',
                                        type => {
                                            kind => 'SCALAR',
                                            name => 'Boolean',
                                            of_type => undef
                                        },
                                        default_value => 'false'
                                    }
                                ],
                                type => {
                                    kind => 'LIST',
                                    name => undef,
                                    of_type => {
                                        kind => 'NON_NULL',
                                        name => undef,
                                        of_type => {
                                            kind => 'OBJECT',
                                            name => '__Field',
                                            of_type => undef
                                        }
                                    }
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'interfaces',
                                args => [],
                                type => {
                                    kind => 'LIST',
                                    name => undef,
                                    of_type => {
                                        kind => 'NON_NULL',
                                        name => undef,
                                        of_type => {
                                            kind => 'OBJECT',
                                            name => '__Type',
                                            of_type => undef
                                        }
                                    }
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'possible_types',
                                args => [],
                                type => {
                                    kind => 'LIST',
                                    name => undef,
                                    of_type => {
                                        kind => 'NON_NULL',
                                        name => undef,
                                        of_type => {
                                            kind => 'OBJECT',
                                            name => '__Type',
                                            of_type => undef
                                        }
                                    }
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'enum_values',
                                args => [
                                    {
                                        name => 'include_deprecated',
                                        type => {
                                            kind => 'SCALAR',
                                            name => 'Boolean',
                                            of_type => undef
                                        },
                                        default_value => 'false'
                                    }
                                ],
                                type => {
                                    kind => 'LIST',
                                    name => undef,
                                    of_type => {
                                        kind => 'NON_NULL',
                                        name => undef,
                                        of_type => {
                                            kind => 'OBJECT',
                                            name => '__EnumValue',
                                            of_type => undef
                                        }
                                    }
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'input_fields',
                                args => [],
                                type => {
                                    kind => 'LIST',
                                    name => undef,
                                    of_type => {
                                        kind => 'NON_NULL',
                                        name => undef,
                                        of_type => {
                                            kind => 'OBJECT',
                                            name => '__InputValue',
                                            of_type => undef
                                        }
                                    }
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'of_type',
                                args => [],
                                type => {
                                    kind => 'OBJECT',
                                    name => '__Type',
                                    of_type => undef
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            }
                        ],
                        input_fields => undef,
                        interfaces => [],
                        enum_values => undef,
                        possible_types => undef,
                    },
                    {
                        kind => 'ENUM',
                        name => '__TypeKind',
                        fields => undef,
                        input_fields => undef,
                        interfaces => undef,
                        enum_values => [
                            {
                                name => 'SCALAR',
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'OBJECT',
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'INTERFACE',
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'UNION',
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'ENUM',
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'INPUT_OBJECT',
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'LIST',
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'NON_NULL',
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            }
                        ],
                        possible_types => undef,
                    },
                    {
                        kind => 'SCALAR',
                        name => 'String',
                        fields => undef,
                        input_fields => undef,
                        interfaces => undef,
                        enum_values => undef,
                        possible_types => undef,
                    },
                    {
                        kind => 'SCALAR',
                        name => 'Boolean',
                        fields => undef,
                        input_fields => undef,
                        interfaces => undef,
                        enum_values => undef,
                        possible_types => undef,
                    },
                    {
                        kind => 'OBJECT',
                        name => '__Field',
                        fields => [
                            {
                                name => 'name',
                                args => [],
                                type => {
                                    kind => 'NON_NULL',
                                    name => undef,
                                    of_type => {
                                        kind => 'SCALAR',
                                        name => 'String',
                                        of_type => undef
                                    }
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'description',
                                args => [],
                                type => {
                                    kind => 'SCALAR',
                                    name => 'String',
                                    of_type => undef
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'args',
                                args => [],
                                type => {
                                    kind => 'NON_NULL',
                                    name => undef,
                                    of_type => {
                                        kind => 'LIST',
                                        name => undef,
                                        of_type => {
                                            kind => 'NON_NULL',
                                            name => undef,
                                            of_type => {
                                                kind => 'OBJECT',
                                                name => '__InputValue'
                                            }
                                        }
                                    }
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'type',
                                args => [],
                                type => {
                                    kind => 'NON_NULL',
                                    name => undef,
                                    of_type => {
                                        kind => 'OBJECT',
                                        name => '__Type',
                                        of_type => undef
                                    }
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'is_deprecated',
                                args => [],
                                type => {
                                    kind => 'NON_NULL',
                                    name => undef,
                                    of_type => {
                                        kind => 'SCALAR',
                                        name => 'Boolean',
                                        of_type => undef
                                    }
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'deprecation_reason',
                                args => [],
                                type => {
                                    kind => 'SCALAR',
                                    name => 'String',
                                    of_type => undef
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            }
                        ],
                        input_fields => undef,
                        interfaces => [],
                        enum_values => undef,
                        possible_types => undef,
                    },
                    {
                        kind => 'OBJECT',
                        name => '__InputValue',
                        fields => [
                            {
                                name => 'name',
                                args => [],
                                type => {
                                    kind => 'NON_NULL',
                                    name => undef,
                                    of_type => {
                                        kind => 'SCALAR',
                                        name => 'String',
                                        of_type => undef
                                    }
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'description',
                                args => [],
                                type => {
                                    kind => 'SCALAR',
                                    name => 'String',
                                    of_type => undef
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'type',
                                args => [],
                                type => {
                                    kind => 'NON_NULL',
                                    name => undef,
                                    of_type => {
                                        kind => 'OBJECT',
                                        name => '__Type',
                                        of_type => undef
                                    }
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'default_value',
                                args => [],
                                type => {
                                    kind => 'SCALAR',
                                    name => 'String',
                                    of_type => undef
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            }
                        ],
                        input_fields => undef,
                        interfaces => [],
                        enum_values => undef,
                        possible_types => undef,
                    },
                    {
                        kind => 'OBJECT',
                        name => '__Enum_value',
                        fields => [
                            {
                                name => 'name',
                                args => [],
                                type => {
                                    kind => 'NON_NULL',
                                    name => undef,
                                    of_type => {
                                        kind => 'SCALAR',
                                        name => 'String',
                                        of_type => undef
                                    }
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'description',
                                args => [],
                                type => {
                                    kind => 'SCALAR',
                                    name => 'String',
                                    of_type => undef
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'is_deprecated',
                                args => [],
                                type => {
                                    kind => 'NON_NULL',
                                    name => undef,
                                    of_type => {
                                        kind => 'SCALAR',
                                        name => 'Boolean',
                                        of_type => undef
                                    }
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'deprecation_reason',
                                args => [],
                                type => {
                                    kind => 'SCALAR',
                                    name => 'String',
                                    of_type => undef
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            }
                        ],
                        input_fields => undef,
                        interfaces => [],
                        enum_values => undef,
                        possible_types => undef,
                    },
                    {
                        kind => 'OBJECT',
                        name => '__Directive',
                        fields => [
                            {
                                name => 'name',
                                args => [],
                                type => {
                                    kind => 'NON_NULL',
                                    name => undef,
                                    of_type => {
                                        kind => 'SCALAR',
                                        name => 'String',
                                        of_type => undef
                                    }
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'description',
                                args => [],
                                type => {
                                    kind => 'SCALAR',
                                    name => 'String',
                                    of_type => undef
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'locations',
                                args => [],
                                type => {
                                    kind => 'NON_NULL',
                                    name => undef,
                                    of_type => {
                                        kind => 'LIST',
                                        name => undef,
                                        of_type => {
                                            kind => 'NON_NULL',
                                            name => undef,
                                            of_type => {
                                                kind => 'ENUM',
                                                name => '__DirectiveLocation'
                                            }
                                        }
                                    }
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'args',
                                args => [],
                                type => {
                                    kind => 'NON_NULL',
                                    name => undef,
                                    of_type => {
                                        kind => 'LIST',
                                        name => undef,
                                        of_type => {
                                            kind => 'NON_NULL',
                                            name => undef,
                                            of_type => {
                                                kind => 'OBJECT',
                                                name => '__InputValue'
                                            }
                                        }
                                    }
                                },
                                is_deprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'on_operation',
                                args => [],
                                type => {
                                    kind => 'NON_NULL',
                                    name => undef,
                                    of_type => {
                                        kind => 'SCALAR',
                                        name => 'Boolean',
                                        of_type => undef,
                                    },
                                },
                                is_deprecated => JSON::true,
                                deprecation_reason => 'Use `locations`.'
                            },
                            {
                                name => 'on_fragment',
                                args => [],
                                type => {
                                    kind => 'NON_NULL',
                                    name => undef,
                                    of_type => {
                                        kind => 'SCALAR',
                                        name => 'Boolean',
                                        of_type => undef,
                                    },
                                },
                                is_deprecated => JSON::true,
                                deprecation_reason => 'Use `locations`.'
                            },
                            {
                                name => 'on_field',
                                args => [],
                                type => {
                                    kind => 'NON_NULL',
                                    name => undef,
                                    of_type => {
                                        kind => 'SCALAR',
                                        name => 'Boolean',
                                        of_type => undef,
                                    },
                                },
                                is_deprecated => JSON::true,
                                deprecation_reason => 'Use `locations`.'
                            }
                        ],
                        input_fields => undef,
                        interfaces => [],
                        enum_values => undef,
                        possible_types => undef,
                    },
                    {
                        kind => 'ENUM',
                        name => '__DirectiveLocation',
                        fields => undef,
                        input_fields => undef,
                        interfaces => undef,
                        enum_values => [
                            {
                                name => 'QUERY',
                                is_deprecated => JSON::false
                            },
                            {
                                name => 'MUTATION',
                                is_deprecated => JSON::false
                            },
                            {
                                name => 'SUBSCRIPTION',
                                is_deprecated => JSON::false
                            },
                            {
                                name => 'FIELD',
                                is_deprecated => JSON::false
                            },
                            {
                                name => 'FRAGMENT_DEFINITION',
                                is_deprecated => JSON::false
                            },
                            {
                                name => 'FRAGMENT_SPREAD',
                                is_deprecated => JSON::false
                            },
                            {
                                name => 'INLINE_FRAGMENT',
                                is_deprecated => JSON::false
                            },
                        ],
                        possible_types => undef,
                    }
                ],
                directives => [
                    {
                        name => 'include',
                        locations =>
                            ['FIELD', 'FRAGMENT_SPREAD', 'INLINE_FRAGMENT'],
                        args => [
                            {
                                default_value => undef,
                                name => 'if',
                                type => {
                                    kind => 'NON_NULL',
                                    name => undef,
                                    of_type => {
                                        kind => 'SCALAR',
                                        name => 'Boolean',
                                        of_type => undef
                                    }
                                }
                            }
                        ],
                    },
                    {
                        name => 'skip',
                        locations =>
                            ['FIELD', 'FRAGMENT_SPREAD', 'INLINE_FRAGMENT'],
                        args => [
                            {
                                default_value => undef,
                                name => 'if',
                                type => {
                                    kind => 'NON_NULL',
                                    name => undef,
                                    of_type => {
                                        kind => 'SCALAR',
                                        name => 'Boolean',
                                        of_type => undef
                                    }
                                }
                            }
                        ],
                    }
                ]
            }
        }
    };
};

subtest 'introspects on input object'=> sub {
    my $TestInputObject = GraphQLInputObjectType(
        name => 'TestInputObject',
        fields => {
            a => { type => GraphQLString, default_value => 'foo' },
            b => { type => GraphQLList(GraphQLString) },
            c => { type => GraphQLString, default_value => JSON::null }
        }
    );

    my $TestType = GraphQLObjectType(
        name => 'TestType',
        fields => {
            field => {
                type => GraphQLString,
                args => { complex => { type => $TestInputObject } },
                resolve => sub {
                    my (undef, $args) = @_;
                    return encode_json($args->{complex});
                },
            }
        }
    );

    my $schema = GraphQLSchema(query => $TestType);
    my $request = <<'EOQ';
      {
        __schema {
          types {
            kind
            name
            input_fields {
              name
              type { ...TypeRef }
              default_value
            }
          }
        }
      }

      fragment TypeRef on __Type {
        kind
        name
        of_type {
          kind
          name
          of_type {
            kind
            name
            of_type {
              kind
              name
            }
          }
        }
      }
EOQ

    cmp_deeply graphql($schema, $request), {
        data => {
            __schema => {
                types => supersetof(
                    {
                        kind => 'INPUT_OBJECT',
                        name => 'TestInputObject',
                        input_fields => bag(
                            {
                                name => 'a',
                                type => {
                                    kind => 'SCALAR',
                                    name => 'String',
                                    of_type => undef,
                                },
                                default_value => '"foo"',
                            },
                            {
                                name => 'b',
                                type => {
                                    kind => 'LIST',
                                    name => undef,
                                    of_type => {
                                        kind => 'SCALAR',
                                        name => 'String',
                                        of_type => undef,
                                    }
                                },
                                default_value => undef,
                            },
                            {
                                name => 'c',
                                type => {
                                    kind => 'SCALAR',
                                    name => 'String',
                                    of_type => undef,
                                },
                                default_value => undef,
                            }
                        )
                    }
                )
            }
        }
    };
};

subtest 'supports the __type root field'=> sub {
    my $TestType = GraphQLObjectType(
      name => 'TestType',
      fields => {
        testField => {
          type => GraphQLString,
        }
      }
    );

    my $schema = GraphQLSchema(query => $TestType);
    my $request = <<'EOQ';
      {
        __type(name: "TestType") {
          name
        }
      }
EOQ

    is_deeply graphql($schema, $request), {
        data => {
            __type => {
                name => 'TestType'
            }
        }
    };
};

subtest 'identifies deprecated fields'=> sub {
    my $TestType = GraphQLObjectType(
        name => 'TestType',
        fields => {
            nonDeprecated => {
                type => GraphQLString,
            },
            deprecated => {
                type => GraphQLString,
                deprecation_reason => 'Removed in 1.0'
            }
        }
    );

    my $schema = GraphQLSchema(query => $TestType);
    my $request = <<'EOQ';
      {
        __type(name: "TestType") {
          name
          fields(include_deprecated: true) {
            name
            is_deprecated,
            deprecation_reason
          }
        }
      }
EOQ

    is_deeply sort_keys( graphql( $schema, $request ), [qw/fields/] ), {
        data => {
            __type => {
                name => 'TestType',
                fields => [
                    {
                        name => 'nonDeprecated',
                        is_deprecated => undef,
                        deprecation_reason => undef,
                    },
                    {
                        name => 'deprecated',
                        is_deprecated => 1,
                        deprecation_reason => 'Removed in 1.0'
                    }
                ]
            }
        }
    };
};

subtest 'respects the includeDeprecated parameter for fields'=> sub {
    my $TestType = GraphQLObjectType(
      name => 'TestType',
      fields => {
        nonDeprecated => {
          type => GraphQLString,
        },
        deprecated => {
          type => GraphQLString,
          deprecation_reason => 'Removed in 1.0'
        }
      }
    );

    my $schema = GraphQLSchema(query => $TestType);
    my $request = <<'EOQ';
      {
        __type(name: "TestType") {
          name
          trueFields: fields(include_deprecated: true) {
            name
          }
          falseFields: fields(include_deprecated: false) {
            name
          }
          omittedFields: fields {
            name
          }
        }
      }
EOQ

    is_deeply sort_keys( graphql( $schema, $request ), [qw/trueFields falseFields omittedFields/] ), {
        data => {
            __type => {
                name => 'TestType',
                trueFields => [
                    { name => 'nonDeprecated' },
                    { name => 'deprecated' },
                ],
                falseFields => [
                    { name => 'nonDeprecated' },
                ],
                omittedFields => [
                    { name => 'nonDeprecated' },
                ],
            }
        }
    };
};

subtest 'identifies deprecated enum values'=> sub {
    my $TestEnum = GraphQLEnumType(
        name => 'TestEnum',
        values => {
            NONDEPRECATED => { value => 0 },
            DEPRECATED => { value => 1, deprecation_reason => 'Removed in 1.0' },
            ALSONONDEPRECATED => { value => 2 }
        }
    );

    my $TestType = GraphQLObjectType(
        name => 'TestType',
        fields => {
            testEnum => {
                type => $TestEnum,
            },
        }
    );

    my $schema = GraphQLSchema(query => $TestType);
    my $request = <<'EOQ';
      {
        __type(name: "TestEnum") {
          name
          enum_values(include_deprecated: true) {
            name
            is_deprecated,
            deprecation_reason
          }
        }
      }
EOQ

    is_deeply sort_keys( graphql( $schema, $request ), [qw/enum_values/] ), {
        data => {
            __type => {
                name => 'TestEnum',
                enum_values => [
                    {
                        name => 'NONDEPRECATED',
                        is_deprecated => undef,
                        deprecation_reason => undef,
                    },
                    {
                        name => 'DEPRECATED',
                        is_deprecated => 1,
                        deprecation_reason => 'Removed in 1.0',
                    },
                    {
                        name => 'ALSONONDEPRECATED',
                        is_deprecated => undef,
                        deprecation_reason => undef,
                    }
                ]
            }
        }
    };
};

subtest 'respects the includeDeprecated parameter for enum values'=> sub {
    my $TestEnum = GraphQLEnumType(
        name => 'TestEnum',
        values => {
            NONDEPRECATED => { value => 0 },
            DEPRECATED => { value => 1, deprecation_reason => 'Removed in 1.0' },
            ALSONONDEPRECATED => { value => 2 }
        }
    );

    my $TestType = GraphQLObjectType(
        name => 'TestType',
        fields => {
            testEnum => {
                type => $TestEnum,
            },
        }
    );

    my $schema = GraphQLSchema(query => $TestType);
    my $request = <<'EOQ';
      {
        __type(name: "TestEnum") {
          name
          trueValues: enum_values(include_deprecated: true) {
            name
          }
          falseValues: enum_values(include_deprecated: false) {
            name
          }
          omittedValues: enum_values {
            name
          }
        }
      }
EOQ

    is_deeply sort_keys( graphql( $schema, $request ), [qw/trueValues falseValues omittedValues/] ), {
        data => {
            __type => {
                name => 'TestEnum',
                trueValues => [
                    { name => 'NONDEPRECATED', },
                    { name => 'DEPRECATED' },
                    { name => 'ALSONONDEPRECATED' },
                ],
                falseValues => [
                    { name => 'NONDEPRECATED' },
                    { name => 'ALSONONDEPRECATED' },
                ],
                omittedValues => [
                    { name => 'NONDEPRECATED' },
                    { name => 'ALSONONDEPRECATED' },
                ],
            }
        }
    };
};

subtest 'fails as expected on the __type root field without an arg'=> sub {
    my $TestType = GraphQLObjectType(
        name => 'TestType',
        fields => {
            testField => {
                type => GraphQLString,
            }
        }
    );

    my $schema = GraphQLSchema(query => $TestType);
    my $request = <<'EOQ';

      {
        __type {
          name
        }
      }
EOQ

    cmp_deeply graphql($schema, $request), {
        errors => [noclass(superhashof({
            message => GraphQL::Validator::Rule::ProvidedNonNullArguments::missing_field_arg_message('__type', 'name', 'String!'),
            locations => [{ line => 3, column => 9 }],
        }))]
    };
};

subtest 'exposes descriptions on types and fields'=> sub {
    my $QueryRoot = GraphQLObjectType(
        name => 'QueryRoot',
        fields => {
            onlyField => { type => GraphQLString }
        }
    );

    my $schema = GraphQLSchema(query => $QueryRoot);
    my $request = <<'EOQ';
      {
        schemaType: __type(name: "__Schema") {
          name,
          description,
          fields {
            name,
            description
          }
        }
      }
EOQ

    cmp_deeply graphql($schema, $request), {
        data => {
            schemaType => {
                name => '__Schema',
                description => 'A GraphQL Schema defines the capabilities of a GraphQL server. It exposes all available types and directives on the server, as well as the entry points for query, mutation, and subscription operations.',
                fields => bag(
                    {
                        name => 'types',
                        description => 'A list of all types supported by this server.'
                    },
                    {
                        name => 'query_type',
                        description => 'The type that query operations will be rooted at.'
                    },
                    {
                        name => 'mutation_type',
                        description => 'If this server supports mutation, the type that mutation operations will be rooted at.'
                    },
                    {
                        name => 'subscription_type',
                        description => 'If this server support subscription, the type that subscription operations will be rooted at.',
                    },
                    {
                        name => 'directives',
                        description => 'A list of all directives supported by this server.'
                    }
                )
            }
        }
    };
};

subtest 'exposes descriptions on enums'=> sub {
    my $QueryRoot = GraphQLObjectType(
        name => 'QueryRoot',
        fields => {
            onlyField => { type => GraphQLString }
        }
    );

    my $schema = GraphQLSchema(query => $QueryRoot);
    my $request = <<'EOQ';
      {
        typeKindType: __type(name: "__TypeKind") {
          name,
          description,
          enum_values {
            name,
            description
          }
        }
      }
EOQ

    cmp_deeply graphql($schema, $request), {
        data => {
            typeKindType => {
                name => '__TypeKind',
                description => 'An enum describing what kind of type a given `__Type` is.',
                enum_values => bag(
                    {
                        description => 'Indicates this type is a scalar.',
                        name => 'SCALAR'
                    },
                    {
                        description => 'Indicates this type is an object. `fields` and `interfaces` are valid fields.',
                        name => 'OBJECT'
                    },
                    {
                        description => 'Indicates this type is an interface. `fields` and `possible_types` are valid fields.',
                        name => 'INTERFACE'
                    },
                    {
                        description => 'Indicates this type is a union. `possible_types` is a valid field.',
                        name => 'UNION'
                    },
                    {
                        description => 'Indicates this type is an enum. `enum_values` is a valid field.',
                        name => 'ENUM'
                    },
                    {
                        description => 'Indicates this type is an input object. `input_fields` is a valid field.',
                        name => 'INPUT_OBJECT'
                    },
                    {
                        description => 'Indicates this type is a list. `of_type` is a valid field.',
                        name => 'LIST'
                    },
                    {
                        description => 'Indicates this type is a non-null. `of_type` is a valid field.',
                        name => 'NON_NULL'
                    }
                )
            }
        }
    };
};

done_testing;

sub sort_keys {
    my($result, $keys) = @_;

    foreach my $key (@$keys){
        $result->{data}->{__type}->{$key} = [sort {$b->{name} cmp $a->{name}} @{$result->{data}->{__type}->{$key}}];
    }

    return $result;
}