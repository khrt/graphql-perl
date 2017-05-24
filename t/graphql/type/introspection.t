
use strict;
use warnings;

use DDP;
use Test::More;
use Test::Deep;
use JSON qw/encode_json/;

use GraphQL qw/graphql :types/;

my $introspection_query = <<'EOQ';
  query IntrospectionQuery {
    __schema {
      queryType { name }
      mutationType { name }
      subscriptionType { name }
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
    fields(includeDeprecated: true) {
      name
      description
      args {
        ...InputValue
      }
      type {
        ...TypeRef
      }
      isDeprecated
      deprecationReason
    }
    inputFields {
      ...InputValue
    }
    interfaces {
      ...TypeRef
    }
    enumValues(includeDeprecated: true) {
      name
      description
      isDeprecated
      deprecationReason
    }
    possibleTypes {
      ...TypeRef
    }
  }

  fragment InputValue on __InputValue {
    name
    description
    type { ...TypeRef }
    defaultValue
  }

  fragment TypeRef on __Type {
    kind
    name
    ofType {
      kind
      name
      ofType {
        kind
        name
        ofType {
          kind
          name
          ofType {
            kind
            name
            ofType {
              kind
              name
              ofType {
                kind
                name
                ofType {
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

subtest 'executes an introspection query'=> sub {
    my $EmptySchema = GraphQLSchema(
        query =>  GraphQLObjectType(
            name => 'QueryRoot',
            fields => {
                onlyField => { type => GraphQLString }
            }
        )
    );

    cmp_deeply graphql($EmptySchema, $introspection_query), {
        data => {
            __schema => {
                mutationType => undef,
                subscriptionType => undef,
                queryType => {
                    name => 'QueryRoot',
                },
                types => [
                    {
                        kind => 'OBJECT',
                        name => 'QueryRoot',
                        inputFields => undef,
                        interfaces => [],
                        enumValues => undef,
                        possibleTypes => undef,
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
                                isDeprecated => JSON::false,
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
                                isDeprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'mutationType',
                                args => [],
                                type => {
                                    kind => 'OBJECT',
                                    name => '__Type',
                                    of_type => undef
                                },
                                isDeprecated => JSON::false,
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
                                isDeprecated => JSON::false,
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
                                isDeprecated => JSON::false,
                                deprecation_reason => undef
                            }
                        ],
                        inputFields => undef,
                        interfaces => [],
                        enumValues => undef,
                        possibleTypes => undef,
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
                                isDeprecated => JSON::false,
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
                                isDeprecated => JSON::false,
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
                                isDeprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'fields',
                                args => [
                                    {
                                        name => 'includeDeprecated',
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
                                isDeprecated => JSON::false,
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
                                isDeprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'possibleTypes',
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
                                isDeprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'enumValues',
                                args => [
                                    {
                                        name => 'includeDeprecated',
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
                                isDeprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'inputFields',
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
                                isDeprecated => JSON::false,
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
                                isDeprecated => JSON::false,
                                deprecation_reason => undef
                            }
                        ],
                        inputFields => undef,
                        interfaces => [],
                        enumValues => undef,
                        possibleTypes => undef,
                    },
                    {
                        kind => 'ENUM',
                        name => '__TypeKind',
                        fields => undef,
                        inputFields => undef,
                        interfaces => undef,
                        enumValues => [
                            {
                                name => 'SCALAR',
                                isDeprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'OBJECT',
                                isDeprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'INTERFACE',
                                isDeprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'UNION',
                                isDeprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'ENUM',
                                isDeprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'INPUT_OBJECT',
                                isDeprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'LIST',
                                isDeprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'NON_NULL',
                                isDeprecated => JSON::false,
                                deprecation_reason => undef
                            }
                        ],
                        possibleTypes => undef,
                    },
                    {
                        kind => 'SCALAR',
                        name => 'String',
                        fields => undef,
                        inputFields => undef,
                        interfaces => undef,
                        enumValues => undef,
                        possibleTypes => undef,
                    },
                    {
                        kind => 'SCALAR',
                        name => 'Boolean',
                        fields => undef,
                        inputFields => undef,
                        interfaces => undef,
                        enumValues => undef,
                        possibleTypes => undef,
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
                                isDeprecated => JSON::false,
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
                                isDeprecated => JSON::false,
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
                                isDeprecated => JSON::false,
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
                                isDeprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'isDeprecated',
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
                                isDeprecated => JSON::false,
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
                                isDeprecated => JSON::false,
                                deprecation_reason => undef
                            }
                        ],
                        inputFields => undef,
                        interfaces => [],
                        enumValues => undef,
                        possibleTypes => undef,
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
                                isDeprecated => JSON::false,
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
                                isDeprecated => JSON::false,
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
                                isDeprecated => JSON::false,
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
                                isDeprecated => JSON::false,
                                deprecation_reason => undef
                            }
                        ],
                        inputFields => undef,
                        interfaces => [],
                        enumValues => undef,
                        possibleTypes => undef,
                    },
                    {
                        kind => 'OBJECT',
                        name => '__EnumValue',
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
                                isDeprecated => JSON::false,
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
                                isDeprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'isDeprecated',
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
                                isDeprecated => JSON::false,
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
                                isDeprecated => JSON::false,
                                deprecation_reason => undef
                            }
                        ],
                        inputFields => undef,
                        interfaces => [],
                        enumValues => undef,
                        possibleTypes => undef,
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
                                isDeprecated => JSON::false,
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
                                isDeprecated => JSON::false,
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
                                isDeprecated => JSON::false,
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
                                isDeprecated => JSON::false,
                                deprecation_reason => undef
                            },
                            {
                                name => 'onOperation',
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
                                isDeprecated => JSON::true,
                                deprecation_reason => 'Use `locations`.'
                            },
                            {
                                name => 'onFragment',
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
                                isDeprecated => JSON::true,
                                deprecation_reason => 'Use `locations`.'
                            },
                            {
                                name => 'onField',
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
                                isDeprecated => JSON::true,
                                deprecation_reason => 'Use `locations`.'
                            }
                        ],
                        inputFields => undef,
                        interfaces => [],
                        enumValues => undef,
                        possibleTypes => undef,
                    },
                    {
                        kind => 'ENUM',
                        name => '__DirectiveLocation',
                        fields => undef,
                        inputFields => undef,
                        interfaces => undef,
                        enumValues => [
                            {
                                name => 'QUERY',
                                isDeprecated => JSON::false
                            },
                            {
                                name => 'MUTATION',
                                isDeprecated => JSON::false
                            },
                            {
                                name => 'SUBSCRIPTION',
                                isDeprecated => JSON::false
                            },
                            {
                                name => 'FIELD',
                                isDeprecated => JSON::false
                            },
                            {
                                name => 'FRAGMENT_DEFINITION',
                                isDeprecated => JSON::false
                            },
                            {
                                name => 'FRAGMENT_SPREAD',
                                isDeprecated => JSON::false
                            },
                            {
                                name => 'INLINE_FRAGMENT',
                                isDeprecated => JSON::false
                            },
                        ],
                        possibleTypes => undef,
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
            c => { type => GraphQLString, default_value => undef }
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
            inputFields {
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

    eval { graphql($schema, $request) };
    die p $@;
    warn 'x ' x 100;

    cmp_deeply graphql($schema, $request), superhashof({
        data => {
            __schema => {
                types => [
                    {
                        kind => 'INPUT_OBJECT',
                        name => 'TestInputObject',
                        inputFields => [
                            {
                                name => 'a',
                                type => {
                                    kind => 'SCALAR',
                                    name => 'String',
                                    of_type => undef,
                                },
                                default_value => '"foo"'
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
                                default_value => 'null'
                            }
                        ]
                    }
                ]
            }
        }
    });
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
          fields(includeDeprecated: true) {
            name
            isDeprecated,
            deprecation_reason
          }
        }
      }
EOQ

    is_deeply graphql($schema, $request), {
        data => {
            __type => {
                name => 'TestType',
                fields => [
                    {
                        name => 'nonDeprecated',
                        isDeprecated => JSON::false,
                        deprecation_reason => undef,
                    },
                    {
                        name => 'deprecated',
                        isDeprecated => JSON::true,
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
          trueFields: fields(includeDeprecated: true) {
            name
          }
          falseFields: fields(includeDeprecated: false) {
            name
          }
          omittedFields: fields {
            name
          }
        }
      }
EOQ

    is_deeply graphql($schema, $request), {
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
          enumValues(includeDeprecated: true) {
            name
            isDeprecated,
            deprecation_reason
          }
        }
      }
EOQ

    is_deeply graphql($schema, $request), {
        data => {
            __type => {
                name => 'TestEnum',
                enumValues => [
                    {
                        name => 'NONDEPRECATED',
                        isDeprecated => JSON::false,
                        deprecation_reason => undef,
                    },
                    {
                        name => 'DEPRECATED',
                        isDeprecated => JSON::true,
                        deprecation_reason => 'Removed in 1.0'
                    },
                    {
                        name => 'ALSONONDEPRECATED',
                        isDeprecated => JSON::false,
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
          trueValues: enumValues(includeDeprecated: true) {
            name
          }
          falseValues: enumValues(includeDeprecated: false) {
            name
          }
          omittedValues: enumValues {
            name
          }
        }
      }
EOQ

    is_deeply graphql($schema, $request), {
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
            message => missingFieldArgMessage('__type', 'name', 'String!'),
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

    is_deeply graphql($schema, $request), {
        data => {
            schemaType => {
                name => '__Schema',
                description => 'A GraphQL Schema defines the capabilities of a GraphQL server. It exposes all available types and directives on the server, as well as the entry points for query, mutation, and subscription operations.',
                fields => [
                    {
                        name => 'types',
                        description => 'A list of all types supported by this server.'
                    },
                    {
                        name => 'queryType',
                        description => 'The type that query operations will be rooted at.'
                    },
                    {
                        name => 'mutationType',
                        description => 'If this server supports mutation, the type that mutation operations will be rooted at.'
                    },
                    {
                        name => 'subscriptionType',
                        description => 'If this server support subscription, the type that subscription operations will be rooted at.',
                    },
                    {
                        name => 'directives',
                        description => 'A list of all directives supported by this server.'
                    }
                ]
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
          enumValues {
            name,
            description
          }
        }
      }
EOQ

    is_deeply graphql($schema, $request), {
        data => {
            typeKindType => {
                name => '__TypeKind',
                description => 'An enum describing what kind of type a given `__Type` is.',
                enumValues => [
                    {
                        description => 'Indicates this type is a scalar.',
                        name => 'SCALAR'
                    },
                    {
                        description => 'Indicates this type is an object. '
                            . '`fields` and `interfaces` are valid fields.',
                        name => 'OBJECT'
                    },
                    {
                        description => 'Indicates this type is an interface. '
                            . '`fields` and `possibleTypes` are valid fields.',
                        name => 'INTERFACE'
                    },
                    {
                        description => 'Indicates this type is a union. '
                            . '`possibleTypes` is a valid field.',
                        name => 'UNION'
                    },
                    {
                        description => 'Indicates this type is an enum. '
                            . '`enumValues` is a valid field.',
                        name => 'ENUM'
                    },
                    {
                        description => 'Indicates this type is an input object. '
                            . '`inputFields` is a valid field.',
                        name => 'INPUT_OBJECT'
                    },
                    {
                        description => 'Indicates this type is a list. '
                            . '`of_type` is a valid field.',
                        name => 'LIST'
                    },
                    {
                        description => 'Indicates this type is a non-null. '
                            . '`of_type` is a valid field.',
                        name => 'NON_NULL'
                    }
                ]
            }
        }
    };
};

done_testing;
