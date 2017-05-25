
use strict;
use warnings;

use feature 'say';
use DDP;
use Test::More;
use Test::Deep;
use JSON qw/encode_json/;

use GraphQL qw/:types/;
use GraphQL::Error qw/GraphQLError format_error/;
use GraphQL::Execute qw/execute/;
use GraphQL::Language::Parser qw/parse/;
use GraphQL::Language::Visitor qw/NULL/;
use GraphQL::Util::Type qw/is_input_type is_output_type/;

subtest 'throws if no document is provided' => sub {
    my $schema = GraphQLSchema(
      query => GraphQLObjectType(
        name => 'Type',
        fields => {
          a => { type => GraphQLString },
        }
      )
    );

    eval { execute($schema, undef) };
    my $e = $@;
    is $e, "Must provide document\n";
};

subtest 'executes arbitrary code' => sub {
    my $deep_data;
    my $data = {
      a => sub { 'Apple' },
      b => sub { 'Banana' },
      c => sub { 'Cookie' },
      d => sub { 'Donut' },
      e => sub { 'Egg' },
      f => 'Fish',
      pic => sub {
          my $size = shift;
          return 'Pic of size: ' . ($size || 50);
      },
      deep => sub { $deep_data },
    };

    $deep_data = {
      a => sub { 'Already Been Done' },
      b => sub { 'Boring' },
      c => sub { ['Contrived', undef, 'Confusing'] },
      deeper => sub { [$data, undef, $data] }
    };

    my $DeepDataType;
    my $DataType = GraphQLObjectType(
      name => 'DataType',
      fields => sub { {
        a => { type => GraphQLString },
        b => { type => GraphQLString },
        c => { type => GraphQLString },
        d => { type => GraphQLString },
        e => { type => GraphQLString },
        f => { type => GraphQLString },
        pic => {
          args => { size => { type => GraphQLInt } },
          type => GraphQLString,
          resolve => sub {
              my ($obj, $args) = @_;
              return $obj->{pic}->($args->{size});
          }
        },
        deep => { type => $DeepDataType },
      } }
    );

    $DeepDataType = GraphQLObjectType(
      name => 'DeepDataType',
      fields => {
        a => { type => GraphQLString },
        b => { type => GraphQLString },
        c => { type => GraphQLList(GraphQLString) },
        deeper => { type => GraphQLList($DataType) },
      }
    );

    my $schema = GraphQLSchema(
      query => $DataType
    );

    my $doc = <<'EOF';
      query Example($size: Int) {
        a,
        b,
        x: c
        ...c
        f
        ...on DataType {
          pic(size: $size)
        }
        deep {
          a
          b
          c
          deeper {
            a
            b
          }
        }
      }

      fragment c on DataType {
        d
        e
      }
EOF
    my $ast = parse($doc);

    my $res = execute($schema, $ast, $data, undef, { size => 100 }, 'Example');
    is_deeply $res, {
        data => {
            a => 'Apple',
            b => 'Banana',
            x => 'Cookie',
            d => 'Donut',
            e => 'Egg',
            f => 'Fish',
            pic => 'Pic of size: 100',
            deep => {
                a => 'Already Been Done',
                b => 'Boring',
                c => ['Contrived', undef, 'Confusing'],
                deeper => [
                    { a => 'Apple', b => 'Banana' },
                    undef,
                    { a => 'Apple', b => 'Banana' },
                ],
            },
        },
    };
};

subtest 'merges parallel fragments' => sub{
    my $ast = parse('
      { a, ...FragOne, ...FragTwo }

      fragment FragOne on Type {
        b
        deep { b, deeper: deep { b } }
      }

      fragment FragTwo on Type {
        c
        deep { c, deeper: deep { c } }
      }
    ');

    my $Type;
    $Type = GraphQLObjectType(
      name => 'Type',
      fields => sub { {
        a => { type => GraphQLString, resolve => sub { 'Apple' } },
        b => { type => GraphQLString, resolve => sub { 'Banana' } },
        c => { type => GraphQLString, resolve => sub { 'Cherry' } },
        deep => { type => $Type, resolve => sub { {} } },
      } },
    );
    my $schema = GraphQLSchema(query => $Type);

    is_deeply execute($schema, $ast), {
        data => {
            a => 'Apple',
            b => 'Banana',
            c => 'Cherry',
            deep => {
                b => 'Banana',
                c => 'Cherry',
                deeper => {
                    b => 'Banana',
                    c => 'Cherry'
                }
            }
        }
    };
};

subtest 'provides info about current execution state' => sub {
    plan skip_all => 'FAILS';

    my $ast = parse('query ($var: String) { result: test }');
    my $info;
    my $schema = GraphQLSchema(
        query => GraphQLObjectType(
            name => 'Test',
            fields => {
                test => {
                    type => GraphQLString,
                    resolve => sub {
                        my ($val, $args, $ctx, $_info) = @_;
                        $info = $_info;
                    },
                },
            },
        )
    );
    my $rootValue = { root => 'val' };

    execute($schema, $ast, $rootValue, undef, { var => 123 });

    is_deeply [sort keys %$info], [qw/
      field_name
      field_nodes
      fragments
      operation
      parent_type
      path
      return_type
      root_value
      schema
      variable_values
    /];
    is $info->{field_name}, 'test';
    is scalar(@{ $info->{field_nodes} }), 1;
    is $info->{field_nodes}[0], $ast->{definitions}[0]{selection_set}{selections}[0];
    is $info->{return_type}->name, GraphQLString->name;
    is $info->{parent_type}, $schema->get_query_type;
    is_deeply $info->{path}, { prev => undef, key => 'result' };
    is $info->{schema}, $schema;
    is $info->{root_value}, $rootValue;
    is $info->{operation}, $ast->{definitions}[0];
    is_deeply $info->{variable_values}, { var => '123' };
};

subtest 'threads root value context correctly' => sub {
    my $doc = 'query Example { a }';
    my $data = {
        context_thing => 'thing',
    };

    my $resolved_root_value;

    my $schema = GraphQLSchema(
        query => GraphQLObjectType(
            name => 'Type',
            fields => {
                a => {
                    type => GraphQLString,
                    resolve => sub {
                        my ($root_value) = @_;
                        $resolved_root_value = $root_value;
                    },
                },
            },
        )
    );

    execute($schema, parse($doc), $data);
    is $resolved_root_value->{context_thing}, 'thing';
};

subtest 'correctly threads arguments' => sub {
    my $doc = <<'EOF';
      query Example {
        b(num_arg: 123, string_arg: "foo")
      }
EOF

    my $resolved_args;
    my $schema = GraphQLSchema(
        query => GraphQLObjectType(
            name => 'Type',
            fields => {
                b => {
                    args => {
                        num_arg => { type => GraphQLInt },
                        string_arg => { type => GraphQLString }
                    },
                    type => GraphQLString,
                    resolve => sub {
                        my (undef, $args) = @_;
                        $resolved_args = $args;
                    }
                }
            }
        )
    );

    execute($schema, parse($doc));
    # print 'res args '; p $resolved_args;

    is $resolved_args->{num_arg}, 123;
    is $resolved_args->{string_arg}, 'foo';
};

# TODO
# subtest 'nulls out error subtrees' => sub {
#     my $doc = '{
#       sync
#       syncError
#       syncRawError
#       syncReturnError
#       syncReturnErrorList
#     }';

#     my $data = {
#       sync => sub {
#         return 'sync';
#       },
#       syncError => sub {
#         die Error('Error getting syncError');
#       },
#       syncRawError => sub {
#         # eslint-disable
#         die 'Error getting syncRawError';
#         # eslint-enable
#       },
#       syncReturnError => sub {
#         return Error('Error getting syncReturnError');
#       },
#       syncReturnErrorList => sub {
#         return [
#           'sync0',
#           Error('Error getting syncReturnErrorList1'),
#           'sync2',
#           Error('Error getting syncReturnErrorList3')
#         ];
#       },
#     };

#     my $ast = parse($doc);
#     my $schema = GraphQLSchema(
#       query => GraphQLObjectType(
#         name => 'Type',
#         fields => {
#           sync => { type => GraphQLString },
#           syncError => { type => GraphQLString },
#           syncRawError => { type => GraphQLString },
#           syncReturnError => { type => GraphQLString },
#           syncReturnErrorList => { type => GraphQLList(GraphQLString) },
#         }
#       )
#     );

#     my $result = execute($schema, $ast, $data);

#     is_deeply $result->{data}, {
#       sync => 'sync',
#       syncError => undef,
#       syncRawError => undef,
#       syncReturnError => undef,
#       syncReturnErrorList => ['sync0', undef, 'sync2', undef],
#     };

#     ok $result->{errors} && @{ $result->{errors} };

#     p $result->{errors};

#     is_deeply [map { format_error($_) } @{ $result->{errors} }], [
#         {
#             message   => 'Error getting syncError',
#             locations => [{ line => 3, column => 7 }],
#             path      => ['syncError']
#         },
#         {
#             message   => 'Error getting syncRawError',
#             locations => [{ line => 4, column => 7 }],
#             path      => ['syncRawError']
#         },
#         {
#             message   => 'Error getting syncReturnError',
#             locations => [{ line => 5, column => 7 }],
#             path      => ['syncReturnError']
#         },
#         {
#             message   => 'Error getting syncReturnErrorList1',
#             locations => [{ line => 6, column => 7 }],
#             path      => ['syncReturnErrorList', 1]
#         },
#         {
#             message   => 'Error getting syncReturnErrorList3',
#             locations => [{ line => 6, column => 7 }],
#             path      => ['syncReturnErrorList', 3]
#         },
#     ];
# };

# TODO: GraphQLError
subtest 'Full response path is included for non-nullable fields' => sub {
    plan skip_all => 'FAILS';

    my $A; $A = GraphQLObjectType(
        name => 'A',
        fields => sub { {
            nullableA => {
                type => $A,
                resolve => sub { {} },
            },
            nonNullA => {
                type    => GraphQLNonNull($A),
                resolve => sub { {} },
            },
            throws => {
                type    => GraphQLNonNull(GraphQLString),
                resolve => sub {
                    die GraphQLError('Catch me if you can');
                },
            },
        } },
    );
    my $queryType = GraphQLObjectType(
        name   => 'query',
        fields => sub { {
            nullableA => {
                type    => $A,
                resolve => sub { {} },
            }
        } },
    );
    my $schema = GraphQLSchema(
      query => $queryType,
    );

    my $query = <<EOF;
      query {
        nullableA {
          aliasedA: nullableA {
            nonNullA {
              anotherA: nonNullA {
                throws
              }
            }
          }
        }
      }
EOF

    my $result = execute($schema, parse($query));
    p $result, max_depth => 10;
    is_deeply $result, {
        data => {
            nullableA => {
                aliasedA => undef,
            },
        },
        errors => [{
            message => 'Catch me if you can',
            locations => [{ line => 7, column => 17 }],
            path => ['nullableA', 'aliasedA', 'nonNullA', 'anotherA', 'throws'],
        }],
    };
};

subtest 'uses the inline operation if no operation name is provided' => sub {
    my $doc = '{ a }';
    my $data = { a => 'b' };
    my $ast = parse($doc);
    my $schema = GraphQLSchema(
        query => GraphQLObjectType(
            name   => 'Type',
            fields => {
                a => { type => GraphQLString },
            }
        )
    );

    my $result = execute($schema, $ast, $data);
    is_deeply $result, { data => { a => 'b' } };
};

subtest 'uses the only operation if no operation name is provided' => sub {
    my $doc = 'query Example { a }';
    my $data = { a => 'b' };
    my $ast = parse($doc);
    my $schema = GraphQLSchema(
        query => GraphQLObjectType(
            name => 'Type',
            fields => {
                a => { type => GraphQLString },
            }
        )
    );

    my $result = execute($schema, $ast, $data);

    is_deeply $result, { data => { a => 'b' } };
};

subtest 'uses the named operation if operation name is provided' => sub {
    my $doc = 'query Example { first: a } query OtherExample { second: a }';
    my $data = { a => 'b' };
    my $ast = parse($doc);
    my $schema = GraphQLSchema(
        query => GraphQLObjectType(
            name => 'Type',
            fields => {
                a => { type => GraphQLString },
            }
        )
    );

    my $result = execute($schema, $ast, $data, undef, undef, 'OtherExample');

    is_deeply $result, { data => { second => 'b' } };
};

subtest 'throws if no operation is provided' => sub {
    my $doc = 'fragment Example on Type { a }';
    my $data = { a => 'b' };
    my $ast = parse($doc);
    my $schema = GraphQLSchema(
        query => GraphQLObjectType(
            name => 'Type',
            fields => {
                a => { type => GraphQLString },
            }
        )
    );

    eval { execute($schema, $ast, $data) };
    my $e = $@;
    is $e, "Must provide an operation.\n";
};

subtest 'throws if no operation name is provided with multiple operations' => sub {
    my $doc = 'query Example { a } query OtherExample { a }';
    my $data = { a => 'b' };
    my $ast = parse($doc);
    my $schema = GraphQLSchema(
      query => GraphQLObjectType(
        name => 'Type',
        fields => {
          a => { type => GraphQLString },
        }
      )
    );

    eval { execute($schema, $ast, $data) };
    my $e = $@;
    is $e, "Must provide operation name if query contains multiple operations.\n";
};

subtest 'throws if unknown operation name is provided' => sub {
    my $doc = 'query Example { a } query OtherExample { a }';
    my $data = { a => 'b' };
    my $ast = parse($doc);
    my $schema = GraphQLSchema(
        query => GraphQLObjectType(
            name => 'Type',
            fields => {
                a => { type => GraphQLString },
            }
        )
    );

    eval { execute($schema, $ast, $data, undef, undef, 'UnknownExample') };
    my $e = $@;
    is $e, qq`Unknown operation named "UnknownExample".\n`;
};

subtest 'uses the query schema for queries' => sub {
    my $doc = 'query Q { a } mutation M { c } subscription S { a }';
    my $data = { a => 'b', c => 'd' };
    my $ast = parse($doc);
    my $schema = GraphQLSchema(
        query => GraphQLObjectType(
            name => 'Q',
            fields => {
                a => { type => GraphQLString },
            }
        ),
        mutation => GraphQLObjectType(
            name => 'M',
            fields => {
                c => { type => GraphQLString },
            }
        ),
        subscription => GraphQLObjectType(
            name => 'S',
            fields => {
                a => { type => GraphQLString },
            }
        )
    );

    my $result = execute($schema, $ast, $data, undef, {}, 'Q');
    is_deeply $result, { data => { a => 'b' } };
};

subtest 'uses the mutation schema for mutations' => sub {
    my $doc = 'query Q { a } mutation M { c }';
    my $data = { a => 'b', c => 'd' };
    my $ast = parse($doc);
    my $schema = GraphQLSchema(
        query => GraphQLObjectType(
            name => 'Q',
            fields => {
                a => { type => GraphQLString },
            }
        ),
        mutation => GraphQLObjectType(
            name => 'M',
            fields => {
                c => { type => GraphQLString },
            }
        )
    );

    my $mutationResult = execute($schema, $ast, $data, undef, {}, 'M');
    is_deeply $mutationResult, { data => { c => 'd' } };
};

subtest 'uses the subscription schema for subscriptions' => sub {
    my $doc = 'query Q { a } subscription S { a }';
    my $data = { a => 'b', c => 'd' };
    my $ast = parse($doc);
    my $schema = GraphQLSchema(
        query => GraphQLObjectType(
            name => 'Q',
            fields => {
                a => { type => GraphQLString },
            }
        ),
        subscription => GraphQLObjectType(
            name => 'S',
            fields => {
                a => { type => GraphQLString },
            }
        )
    );

    my $subscription_result = execute($schema, $ast, $data, undef, {}, 'S');
    is_deeply $subscription_result, { data => { a => 'b' } };
};

subtest 'Avoids recursion' => sub {
    my $doc = '
      query Q {
        a
        ...Frag
        ...Frag
      }

      fragment Frag on Type {
        a,
        ...Frag
      }
    ';
    my $data = { a => 'b' };
    my $ast = parse($doc);
    my $schema = GraphQLSchema(
        query => GraphQLObjectType(
            name => 'Type',
            fields => {
                a => { type => GraphQLString },
            }
        ),
    );

    my $queryResult = execute($schema, $ast, $data, undef, {}, 'Q');
    is_deeply $queryResult, { data => { a => 'b' } };
};

subtest 'does not include illegal fields in output' => sub {
    my $doc = 'mutation M {
      thisIsIllegalDontIncludeMe
    }';
    my $ast = parse($doc);
    my $schema = GraphQLSchema(
        query => GraphQLObjectType(
            name => 'Q',
            fields => {
                a => { type => GraphQLString },
            }
        ),
        mutation => GraphQLObjectType(
            name => 'M',
            fields => {
                c => { type => GraphQLString },
            }
        ),
    );

    my $mutationResult = execute($schema, $ast);
    is_deeply $mutationResult, { data => {} };
};

subtest 'does not include arguments that were not set' => sub {
    plan skip_all => 'FAILS';

    my $schema = GraphQLSchema(
        query => GraphQLObjectType(
            name => 'Type',
            fields => {
                field => {
                    type => GraphQLString,
                    resolve => sub {
                        my ($data, $args) = @_;
                        return $args;
                    },
                    args => {
                        a => { type => GraphQLBoolean },
                        b => { type => GraphQLBoolean },
                        c => { type => GraphQLBoolean },
                        d => { type => GraphQLInt },
                        e => { type => GraphQLInt },
                    },
                }
            }
        )
    );

    my $query = parse('{ field(a: true, c: false, e: 0) }');
    my $result = execute($schema, $query);

    is_deeply $result, {
        data => {
                   # { "a": true,"c": false,"e": 0 }
            field => { a => 1, c => 0, e => 0 }
        }
    };
};

subtest 'fails when an is_type_of check is not met' => sub {
    {
        package Special;
        sub new {
            my ($class, $value) = @_;
            return bless { value => $value }, $class;
        }
        sub value { shift->{value} }

        package NotSpecial;
        sub new {
            my ($class, $value) = @_;
            return bless { value => $value }, $class;
        }
        sub value { shift->{value} }
    }

    my $SpecialType = GraphQLObjectType(
        name => 'SpecialType',
        is_type_of => sub {
            my $obj = shift;
            return $obj->isa('Special');
        },
        fields => {
            value => { type => GraphQLString }
        }
    );

    my $schema = GraphQLSchema(
        query => GraphQLObjectType(
            name => 'Query',
            fields => {
                specials => {
                    type => GraphQLList($SpecialType),
                    resolve => sub {
                        my $root_value = shift;
                        return $root_value->{specials};
                    }
                }
            }
        )
    );

    my $query = parse('{ specials { value } }');
    my $value = {
        specials => [Special->new('foo'), NotSpecial->new('bar')]
    };
    my $result = execute($schema, $query, $value);

    is_deeply $result->{data}, {
        specials => [
            { value => 'foo' },
            undef,
        ],
    };
    is scalar(@{ $result->{errors} }), 1;
    cmp_deeply $result->{errors}[0],
        noclass(superhashof({
            message => 'Expected value of type "SpecialType" but got: NotSpecial.',
            locations => [{ line => 1, column => 3 }]
        }));
};

subtest 'fails to execute a query containing a type definition' => sub {
    my $query = parse('
      { foo }

      type Query { foo: String }
    ');

    my $schema = GraphQLSchema(
        query => GraphQLObjectType(
            name => 'Query',
            fields => {
                foo => { type => GraphQLString }
            }
        )
    );

    my $caught_error;
    eval { execute($schema, $query) };

    if (my $e = $@) {
        $caught_error = $e;
    }

    cmp_deeply $caught_error, noclass(superhashof({
        message => 'GraphQL cannot execute a request containing a ObjectTypeDefinition.',
        locations => [ { line => 4, column => 7 } ]
    }));
};

done_testing;
