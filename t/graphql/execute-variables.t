
use strict;
use warnings;

use Test::More;
use Test::Deep;
use JSON qw/encode_json/;

use GraphQL qw/graphql :types/;
use GraphQL::Language::Parser qw/parse/;
use GraphQL::Execute qw/execute/;
use GraphQL::Util qw/stringify/;

my $TestComplexScalar = GraphQLScalarType(
    name => 'ComplexScalar',
    serialize => sub {
        my $value = shift;
        if ($value eq 'DeserializedValue') {
            return 'SerializedValue';
        }
        return;
    },
    parse_value => sub {
        my $value = shift;
        if ($value eq 'SerializedValue') {
            return 'DeserializedValue';
        }
        return;
    },
    parse_literal => sub {
        my $ast = shift;
        if ($ast->{value} eq 'SerializedValue') {
            return 'DeserializedValue';
        }
        return;
    },
);

my $TestInputObject = GraphQLInputObjectType(
    name => 'TestInputObject',
    fields => {
        a => { type => GraphQLString },
        b => { type => GraphQLList(GraphQLString) },
        c => { type => GraphQLNonNull(GraphQLString) },
        d => { type => $TestComplexScalar },
    }
);

my $TestNestedInputObject = GraphQLInputObjectType(
    name => 'TestNestedInputObject',
    fields => {
        na => { type => GraphQLNonNull($TestInputObject) },
        nb => { type => GraphQLNonNull(GraphQLString) },
    },
);

my $TestType = GraphQLObjectType(
    name => 'TestType',
    fields => {
        fieldWithObjectInput => {
            type => GraphQLString,
            args => { input => { type => $TestInputObject } },
            resolve => sub {
                my (undef, $args) = @_;
                return $args->{input} && stringify($args->{input});
            },
        },
        fieldWithNullableStringInput => {
            type => GraphQLString,
            args => { input => { type => GraphQLString } },
            resolve => sub {
                my (undef, $args) = @_;
                return $args->{input} && stringify($args->{input});
            },
        },
        fieldWithNonNullableStringInput => {
            type => GraphQLString,
            args => { input => { type => GraphQLNonNull(GraphQLString) } },
            resolve => sub {
                my (undef, $args) = @_;
                return $args->{input} && stringify($args->{input});
            },
        },
        fieldWithDefaultArgumentValue => {
            type => GraphQLString,
            args => { input => { type => GraphQLString, default_value => 'Hello World' } },
            resolve => sub {
                my (undef, $args) = @_;
                return $args->{input} && stringify($args->{input});
            },
        },
        fieldWithNestedInputObject => {
            type => GraphQLString,
            args => {
                input => {
                    type => $TestNestedInputObject, default_value => 'Hello World'
                }
            },
            resolve => sub {
                my (undef, $args) = @_;
                return $args->{input} && stringify($args->{input});
            },
        },
        list => {
            type => GraphQLString,
            args => { input => { type => GraphQLList(GraphQLString) } },
            resolve => sub {
                my (undef, $args) = @_;
                return $args->{input} && stringify($args->{input});
            },
        },
        nnList => {
            type => GraphQLString,
            args => { input => { type => GraphQLNonNull(GraphQLList(GraphQLString)) } },
            resolve => sub {
                my (undef, $args) = @_;
                return $args->{input} && stringify($args->{input});
            },
        },
        listNN => {
            type => GraphQLString,
            args => { input => { type => GraphQLList(GraphQLNonNull(GraphQLString)) } },
            resolve => sub {
                my (undef, $args) = @_;
                return $args->{input} && stringify($args->{input});
            },
        },
        nnListNN => {
            type => GraphQLString,
            args => { input => { type => GraphQLNonNull(GraphQLList(GraphQLNonNull(GraphQLString))) } },
            resolve => sub {
                my (undef, $args) = @_;
                return $args->{input} && stringify($args->{input});
            },
        },
    }
);

my $schema = GraphQLSchema(query => $TestType);

subtest 'Handles objects and nullability' => sub {
    subtest 'using inline structs' => sub {
        subtest 'executes with complex input' => sub {
            my $doc = '
            {
              fieldWithObjectInput(input: {a: "foo", b: ["bar"], c: "baz"})
            }
            ';
            my $ast = parse($doc);

            is_deeply execute($schema, $ast), {
                data => {
                    fieldWithObjectInput => encode_json({ a => 'foo', b => ['bar'], c => 'baz' }),
                }
            };
        };

        subtest 'properly parses single value to list' => sub {
            my $doc = '
            {
              fieldWithObjectInput(input: {a: "foo", b: "bar", c: "baz"})
            }
            ';
            my $ast = parse($doc);

            is_deeply execute($schema, $ast), {
                data => {
                    fieldWithObjectInput => encode_json({ a => 'foo', b => ['bar'], c => 'baz'}),
                }
            };
        };

        subtest 'properly parses null value to null' => sub {
            my $doc = '
            {
              fieldWithObjectInput(input: {a: null, b: null, c: "C", d: null})
            }
            ';
            my $ast = parse($doc);

            is_deeply execute($schema, $ast), {
                data => {
                    fieldWithObjectInput => encode_json({ a => undef, b => undef, c => 'C', d => undef }),
                }
            };
        };

        subtest 'properly parses null value in list' => sub {
            my $doc = '
            {
              fieldWithObjectInput(input: {b: ["A",null,"C"], c: "C"})
            }
            ';
            my $ast = parse($doc);

            is_deeply execute($schema, $ast), {
                data => {
                    fieldWithObjectInput => encode_json({ b => ['A', undef, 'C'], c => 'C' })
                }
            };
        };

        subtest 'does not use incorrect value' => sub {
            my $doc = '
            {
              fieldWithObjectInput(input: ["foo", "bar", "baz"])
            }
            ';
            my $ast = parse($doc);

            my $result = execute($schema, $ast);

            cmp_deeply $result, {
                data => {
                    fieldWithObjectInput => undef
                },
                errors => [noclass(superhashof({
                    message => qq'Argument "input" got invalid value ["foo", "bar", "baz"].\nExpected "TestInputObject", found not an object.',
                    # path => ['fieldWithObjectInput']
                }))],
            };
        };

        subtest 'properly runs parseLiteral on complex scalar types' => sub {
            my $doc = '
            {
              fieldWithObjectInput(input: {c: "foo", d: "SerializedValue"})
            }
            ';
            my $ast = parse($doc);

            is_deeply execute($schema, $ast), {
                data => {
                    fieldWithObjectInput => encode_json({ c => 'foo',d => 'DeserializedValue' }),
                }
            };
        };
    };

    subtest 'using variables' => sub {
        my $doc = <<'EOQ';

        query q($input: TestInputObject) {
          fieldWithObjectInput(input: $input)
        }
EOQ
        my $ast = parse($doc);

        subtest 'executes with complex input' => sub {
            my $params = { input => { a => 'foo', b => ['bar'], c => 'baz' } };
            my $result = execute($schema, $ast, undef, undef, $params);

            is_deeply $result, {
                data => { fieldWithObjectInput => encode_json($params->{input}) }
            };
        };

        subtest 'uses default value when not provided' => sub {
            my $withDefaultsAST = parse(
<<'EOQ'
          query q($input: TestInputObject = {a: "foo", b: ["bar"], c: "baz"}) {
            fieldWithObjectInput(input: $input)
          }
EOQ
            );

            my $result = execute($schema, $withDefaultsAST);
            is_deeply $result, {
                data => {
                    fieldWithObjectInput => encode_json({
                        a => 'foo', b => ['bar'], c => 'baz',
                    }),
                },
            };
        };

        subtest 'properly parses single value to list' => sub {
            my $params = { input => { a => 'foo', b => 'bar', c => 'baz' } };
            my $result =  execute($schema, $ast, undef, undef, $params);

            is_deeply $result, {
                data => {
                    fieldWithObjectInput => encode_json({
                        a => 'foo', b => ['bar'], c => 'baz'
                    }),
                },
            };
        };

        subtest 'executes with complex scalar input' => sub {
            my $params = { input => { c => 'foo', d => 'SerializedValue' } };
            my $result =  execute($schema, $ast, undef, undef, $params);

            is_deeply $result, {
                data => {
                    fieldWithObjectInput => encode_json({
                        c => 'foo', d => 'DeserializedValue'
                    }),
                },
            };
        };

        subtest 'errors on null for nested non-null' => sub {
            my $params = { input => { a => 'foo', b => 'bar', c => undef } };

            eval {
                execute($schema, $ast, undef, undef, $params);
            };
            my $e = $@;

            cmp_deeply $e, noclass(superhashof({
                locations => [{ line => 2, column => 17 }],
                message => qq'Variable "\$input" got invalid value ${ \encode_json($params->{input}) }.\nIn field "c": Expected "String!", found null.'
            }));
        };

        subtest 'errors on incorrect type' => sub {
            my $params = { input => 'foo bar' };

            eval {
                execute($schema, $ast, undef, undef, $params);
            };
            my $e = $@;

            cmp_deeply $e, noclass(superhashof({
                locations => [{ line => 2, column => 17 }],
                message => qq'Variable "\$input" got invalid value "foo bar".\nExpected "TestInputObject", found not an object.'
            }));
        };

        subtest 'errors on omission of nested non-null' => sub {
            my $params = { input => { a => 'foo', b => 'bar' } };

            eval {
                execute($schema, $ast, undef, undef, $params);
            };
            my $e = $@;

            cmp_deeply $e, noclass(superhashof({
                locations => [{ line => 2, column => 17 }],
                message => qq'Variable "\$input" got invalid value {"a":"foo","b":"bar"}.\nIn field "c": Expected "String!", found null.'
            }));
        };

        subtest 'errors on deep nested errors and with many errors' => sub {
            my $nestedDoc = <<'EOQ';

          query q($input: TestNestedInputObject) {
            fieldWithNestedObjectInput(input: $input)
          }
EOQ
            my $nestedAst = parse($nestedDoc);
            my $params = { input => { na => { a => 'foo' } } };

            eval {
                execute($schema, $nestedAst, undef, undef, $params);
            };
            my $e = $@;

            # NOTE: Flunky because of unordered hashes
            cmp_deeply $e, noclass(superhashof({
                locations => [{ line => 2, column => 19 }],
                message => qq'Variable "\$input" got invalid value ${ \encode_json($params->{input}) }.'
                    . qq'\nIn field "nb": Expected "String!", found null.'
                    . qq'\nIn field "na": In field "c": Expected "String!", found null.'
            }));
        };

        subtest 'errors on addition of unknown input field' => sub {
            my $params = {
                input => { a => 'foo', b => 'bar', c => 'baz', extra => 'dog' }
            };

            eval {
                execute($schema, $ast, undef, undef, $params);
            };
            my $e = $@;

            cmp_deeply $e, noclass(superhashof({
                locations => [{ line => 2, column => 17 }],
                message => qq'Variable "\$input" got invalid value ${ \encode_json($params->{input}) }.\nIn field "extra": Unknown field.'
            }));
        };
    };
};

subtest 'Handles nullable scalars' => sub {
    subtest 'allows nullable inputs to be omitted' => sub {
        my $doc = '
        {
          fieldWithNullableStringInput
        }
        ';
        my $ast = parse($doc);

        is_deeply execute($schema, $ast), {
            data => {
                fieldWithNullableStringInput => undef
            }
        };
    };

    subtest 'allows nullable inputs to be omitted in a variable' => sub {
        my $doc = '
        query SetsNullable($value: String) {
          fieldWithNullableStringInput(input: $value)
        }
        ';
        my $ast = parse($doc);

        is_deeply execute($schema, $ast), {
            data => {
                fieldWithNullableStringInput => undef
            }
        };
    };

    subtest 'allows nullable inputs to be omitted in an unlisted variable' => sub {
        my $doc = '
        query SetsNullable {
          fieldWithNullableStringInput(input: $value)
        }
        ';
        my $ast = parse($doc);

        is_deeply execute($schema, $ast), {
            data => {
                fieldWithNullableStringInput => undef
            }
        };
    };

    subtest 'allows nullable inputs to be set to null in a variable' => sub {
        my $doc = '
        query SetsNullable($value: String) {
          fieldWithNullableStringInput(input: $value)
        }
        ';
        my $ast = parse($doc);

        is_deeply execute($schema, $ast, undef, undef, { value => undef }), {
            data => {
                fieldWithNullableStringInput => undef
            }
        };
    };

    subtest 'allows nullable inputs to be set to a value in a variable' => sub {
        my $doc = '
        query SetsNullable($value: String) {
          fieldWithNullableStringInput(input: $value)
        }
        ';
        my $ast = parse($doc);

        is_deeply execute($schema, $ast, undef, undef, { value => 'a' }), {
            data => {
                fieldWithNullableStringInput => '"a"'
            }
        };
    };

    subtest 'allows nullable inputs to be set to a value directly' => sub {
        my $doc = '
        {
          fieldWithNullableStringInput(input: "a")
        }
        ';
        my $ast = parse($doc);

        is_deeply execute($schema, $ast), {
            data => {
                fieldWithNullableStringInput => '"a"'
            }
        };
    };
};

subtest 'Handles non-nullable scalars' => sub {
    subtest 'allows non-nullable inputs to be omitted given a default' => sub {
        my $doc = '
        query SetsNonNullable($value: String = "default") {
          fieldWithNonNullableStringInput(input: $value)
        }
        ';

        is_deeply execute($schema, parse($doc)), {
            data => {
                fieldWithNonNullableStringInput => '"default"'
            }
        };
    };

    subtest 'does not allow non-nullable inputs to be omitted in a variable' => sub {
        my $doc = '
        query SetsNonNullable($value: String!) {
          fieldWithNonNullableStringInput(input: $value)
        }
        ';

        eval {
            execute($schema, parse($doc));
        };
        my $e = $@;

        cmp_deeply $e, noclass(superhashof({
            locations => [{ line => 2, column => 31 }],
            message => 'Variable "$value" of required type "String!" was not provided.'
        }));
    };

    subtest 'does not allow non-nullable inputs to be set to null in a variable' => sub {
        plan skip_all => 'TODO';

        my $doc = '
        query SetsNonNullable($value: String!) {
          fieldWithNonNullableStringInput(input: $value)
        }
        ';
        my $ast = parse($doc);

        eval {
            execute($schema, $ast, undef, undef, { value => undef });
        };
        my $e = $@;

        cmp_deeply $e, noclass(superhashof({
            locations => [{ line => 2, column => 31 }],
            message => qq'Variable "\$value" got invalid value null.\nExpected "String!", found null.'
        }));
    };

    subtest 'allows non-nullable inputs to be set to a value in a variable' => sub {
        my $doc = '
        query SetsNonNullable($value: String!) {
          fieldWithNonNullableStringInput(input: $value)
        }
        ';
        my $ast = parse($doc);

        is_deeply execute($schema, $ast, undef, undef, { value => 'a' }), {
            data => {
                fieldWithNonNullableStringInput => '"a"'
            }
        };
    };

    subtest 'allows non-nullable inputs to be set to a value directly' => sub {
        my $doc = '
        {
          fieldWithNonNullableStringInput(input: "a")
        }
        ';
        my $ast = parse($doc);

        is_deeply execute($schema, $ast), {
            data => {
                fieldWithNonNullableStringInput => '"a"'
            }
        };
    };

    subtest 'reports error for missing non-nullable inputs' => sub {
        my $doc = '
      {
        fieldWithNonNullableStringInput
      }
        ';
        my $ast = parse($doc);

        cmp_deeply execute($schema, $ast), {
            data => {
                fieldWithNonNullableStringInput => undef
            },
            errors => [noclass(superhashof({
                message => 'Argument "input" of required type "String!" was not provided.',
                locations => [{ line => 3, column => 9 }],
                # path => ['fieldWithNonNullableStringInput']
            }))]
        };
    };
};

subtest 'Handles lists and nullability' => sub {
    subtest 'allows lists to be null' => sub {
        my $doc = '
        query q($input: [String]) {
          list(input: $input)
        }
        ';
        my $ast = parse($doc);

        is_deeply execute($schema, $ast, undef, undef, { input => undef }), {
            data => {
                list => undef
            }
        };
    };

    subtest 'allows lists to contain values' => sub {
        my $doc = '
        query q($input: [String]) {
          list(input: $input)
        }
        ';
        my $ast = parse($doc);

        is_deeply execute($schema, $ast, undef, undef, { input => ['A'] }), {
            data => {
                list => '["A"]'
            }
        };
    };

    subtest 'allows lists to contain null' => sub {
        my $doc = '
        query q($input: [String]) {
          list(input: $input)
        }
        ';
        my $ast = parse($doc);

        is_deeply execute($schema, $ast, undef, undef, { input => ['A', undef, 'B'] }), {
            data => {
                list => '["A",null,"B"]'
            }
        };
    };

    subtest 'does not allow non-null lists to be null' => sub {
        my $doc = '
        query q($input: [String]!) {
          nnList(input: $input)
        }
        ';
        my $ast = parse($doc);

        eval {
            execute($schema, $ast, undef, undef, { input => undef });
        };

        my $e = $@;

        cmp_deeply $e, noclass(superhashof({
            locations => [{ line => 2, column => 17 }],
            message => qq'Variable "\$input" got invalid value null.\nExpected "[String]!", found null.'
        }));
    };

    subtest 'allows non-null lists to contain values' => sub {
        my $doc = '
        query q($input: [String]!) {
          nnList(input: $input)
        }
        ';
        my $ast = parse($doc);

        is_deeply execute($schema, $ast, undef, undef, { input => ['A'] }), {
            data => {
                nnList => '["A"]'
            }
        };
    };

    subtest 'allows non-null lists to contain null' => sub {
        my $doc = '
        query q($input: [String]!) {
          nnList(input: $input)
        }
        ';
        my $ast = parse($doc);

        is_deeply execute($schema, $ast, undef, undef, { input => ['A', undef, 'B'] }), {
            data => {
                nnList => '["A",null,"B"]'
            }
        };
    };

    subtest 'allows lists of non-nulls to be null' => sub {
        my $doc = '
        query q($input: [String!]) {
          listNN(input: $input)
        }
        ';
        my $ast = parse($doc);

        is_deeply execute($schema, $ast, undef, undef, { input => undef }), {
            data => {
                listNN => undef
            }
        };
    };

    subtest 'allows lists of non-nulls to contain values' => sub {
        my $doc = '
        query q($input: [String!]) {
          listNN(input: $input)
        }
        ';
        my $ast = parse($doc);

        is_deeply execute($schema, $ast, undef, undef, { input => ['A'] }), {
            data => {
                listNN => '["A"]'
            }
        };
    };

    subtest 'does not allow lists of non-nulls to contain null' => sub {
        my $doc = '
        query q($input: [String!]) {
          listNN(input: $input)
        }
        ';
        my $ast = parse($doc);
        my $vars = { input => ['A', undef, 'B'] };

        eval {
            execute($schema, $ast, undef, undef, $vars);
        };
        my $e = $@;

        cmp_deeply $e, noclass(superhashof({
            locations => [{ line => 2, column => 17 }],
            message => 'Variable "$input" got invalid value ["A",null,"B"].'
                . qq'\nIn element #1: Expected "String!", found null.'
        }));
    };

    subtest 'does not allow non-null lists of non-nulls to be null' => sub {
        my $doc = '
        query q($input: [String!]!) {
          nnListNN(input: $input)
        }
        ';
        my $ast = parse($doc);

        eval {
            execute($schema, $ast, undef, undef, { input => undef });
        };
        my $e = $@;

        cmp_deeply $e, noclass(superhashof({
                    locations => [{ line => 2, column => 17 }],
                    message => qq'Variable "\$input" got invalid value null.\nExpected "[String!]!", found null.'
                }));
    };

    subtest 'allows non-null lists of non-nulls to contain values' => sub {
        my $doc = '
        query q($input: [String!]!) {
          nnListNN(input: $input)
        }
        ';
        my $ast = parse($doc);

        is_deeply execute($schema, $ast, undef, undef, { input => ['A'] }), {
            data => {
                nnListNN => '["A"]'
            }
        };
    };

    subtest 'does not allow non-null lists of non-nulls to contain null' => sub {
        my $doc = '
        query q($input: [String!]!) {
          nnListNN(input: $input)
        }
        ';
        my $ast = parse($doc);
        my $vars = { input => ['A', undef, 'B'] };

        eval {
            execute($schema, $ast, undef, undef, $vars);
        };
        my $e = $@;

        cmp_deeply $e, noclass(superhashof({
            locations => [{ line => 2, column => 17 }],
            message => qq'Variable "\$input" got invalid value ["A",null,"B"].\nIn element #1: Expected "String!", found null.'
        }));
    };

    subtest 'does not allow invalid types to be used as values' => sub {
        my $doc = '
        query q($input: TestType!) {
          fieldWithObjectInput(input: $input)
        }
        ';
        my $ast = parse($doc);
        my $vars = { input => { list => ['A', 'B'] } };

        eval {
            execute($schema, $ast, undef, undef, $vars);
        };
        my $e = $@;

        cmp_deeply $e, noclass(superhashof({
            locations => [{ line => 2, column => 25 }],
            message => 'Variable "$input" expected value of type "TestType!" which cannot be used as an input type.'
        }));
    };

    subtest 'does not allow unknown types to be used as values' => sub {
        my $doc = '
        query q($input: UnknownType!) {
          fieldWithObjectInput(input: $input)
        }
        ';
        my $ast = parse($doc);
        my $vars = { input => 'whoknows' };

        eval {
            execute($schema, $ast, undef, undef, $vars);
        };
        my $e = $@;

        cmp_deeply $e, noclass(superhashof({
            locations => [{ line => 2, column => 25 }],
            message => 'Variable "$input" expected value of type "UnknownType!" which cannot be used as an input type.'
        }));
    };
};

subtest 'Execute: Uses argument default values' => sub {
    subtest 'when no argument provided' => sub {
        my $ast = parse('{ fieldWithDefaultArgumentValue }');

        is_deeply execute($schema, $ast), {
            data => {
                fieldWithDefaultArgumentValue => '"Hello World"'
            }
        };
    };

    subtest 'when omitted variable provided' => sub {
        my $ast = parse(
<<'EOQ'
        query optionalVariable($optional: String) {
            fieldWithDefaultArgumentValue(input: $optional)
        }
EOQ
        );

        is_deeply execute($schema, $ast), {
            data => {
                fieldWithDefaultArgumentValue => '"Hello World"'
            }
        };
    };

    subtest 'not when argument cannot be coerced' => sub {
        my $ast = parse(
<<'EOQ'
{
  fieldWithDefaultArgumentValue(input: WRONG_TYPE)
}
EOQ
        );

        cmp_deeply execute($schema, $ast), {
            data => {
                fieldWithDefaultArgumentValue => undef
            },
            errors => [noclass(superhashof({
                message => qq'Argument "input" got invalid value WRONG_TYPE.\nExpected type "String", found WRONG_TYPE.',
                locations => [{ line => 2, column => 40 }],
                # path => ['fieldWithDefaultArgumentValue']
            }))]
        };
    };
};

done_testing;
