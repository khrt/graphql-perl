
use strict;
use warnings;

use DDP;
use Test::Deep;
use Test::More;
use JSON qw/encode_json/;

use GraphQL qw/:types/;
use GraphQL::Error qw/format_error/;
use GraphQL::Language::Parser qw/parse/;
use GraphQL::Execute qw/execute/;

sub check {
    my ($test_type, $test_data, $expected, $name) = @_;

    my $data = { test => $test_data };

    my $data_type;
    $data_type = GraphQLObjectType(
      name => 'DataType',
      fields => sub { {
        test => { type => $test_type },
        nest => { type => $data_type, resolve => sub { $data } },
      } },
    );

    my $schema = GraphQLSchema(query => $data_type);
    my $ast = parse('{ nest { test } }');

    my $result = execute($schema, $ast, $data);
    cmp_deeply $result, $expected, $name;
}

subtest 'Execute: Accepts any iterable as list value' => sub {
    # check(
    #     GraphQLList(GraphQLString),
    #     new Set(['apple', 'banana', 'apple', 'coconut']),
    #     { data => { nest => { test => ['apple', 'banana', 'coconut'] } } },
    #     'Accepts a Set as a List value'
    # );

    # function* yieldItems() {
    #   yield 'one';
    #   yield 2;
    #   yield true;
    # }

    # check(
    #     GraphQLList(GraphQLString),
    #     yieldItems(),
    #     { data => { nest => { test => ['one', '2', 'true'] } } },
    #     'Accepts an Generator function as a List value'
    # );

    check(
        GraphQLList(GraphQLString),
        ['one', 'two'],
        { data => { nest => { test => ['one', 'two'] } } },
        'Accepts function arguments as a List value'
    );

    check(
        GraphQLList(GraphQLString),
        'Singluar',
        {
            data => { nest => { test => undef } },
            errors => [noclass(superhashof({
                message => "Expected Iterable, but did not find one for field DataType.test.\n",
                locations => [{ line => 1, column => 10 }],
                # path => ['nest', 'test'],
            }))],
        },
        'Does not accept (Iterable) String-literal as a List value'
    );
};

subtest 'Execute: Handles list nullability' => sub {
    subtest '[T]' => sub {
        my $type = GraphQLList(GraphQLInt);

        check(
            $type, [1, 2],
            { data => { nest => { test => [1, 2] } } },
            'Contains values'
        );

        check(
            $type,
            [1, undef, 2],
            { data => { nest => { test => [1, undef, 2] } } },
            'Contains null'
        );

        check($type, undef, { data => { nest => { test => undef } } },
            'Returns null');
    };

    plan skip_all => 'TODO';

    subtest '[T]!' => sub {
        my $type = GraphQLNonNull(GraphQLList(GraphQLInt));

        check(
            $type, [1, 2],
            { data => { nest => { test => [1, 2] } } },
            'Contains values'
        );

        check(
            $type,
            [1, undef, 2],
            { data => { nest => { test => [1, undef, 2] } } },
            'Contains null'
        );

        check(
            $type,
            undef,
            {
                data   => { nest => undef },
                errors => [noclass(superhashof({
                    message => 'Cannot return null for non-nullable field DataType.test.',
                    locations => [{ line => 1, column => 10 }],
                    # path => ['nest', 'test']
                }))],
            },
            'Returns null'
        );
    };

    subtest '[T!]' => sub {
        my $type = GraphQLList(GraphQLNonNull(GraphQLInt));

        check(
            $type, [1, 2],
            { data => { nest => { test => [1, 2] } } },
            'Contains values'
        );

        check(
            $type,
            [1, undef, 2],
            {
                data => { nest => { test => undef } },
                errors => [noclass(superhashof({
                    message => 'Cannot return null for non-nullable field DataType.test.',
                    locations => [{ line => 1, column => 10 }],
                    # path => ['nest', 'test', 1]
                }))],
            },
            'Contains null'
        );

        check(
            $type,
            undef,
            { data => { nest => { test => undef } } },
            'Returns null'
        );
    };

    subtest '[T!]!' => sub {
        my $type = GraphQLNonNull(GraphQLList(GraphQLNonNull(GraphQLInt)));

        check(
            $type, [1, 2],
            { data => { nest => { test => [1, 2] } } },
            'Contains values'
        );

        check(
            $type,
            [1, undef, 2],
            {
                data => { nest => undef },
                errors => [noclass(superhashof({
                    message => 'Cannot return null for non-nullable field DataType.test.',
                    locations => [{ line => 1, column => 10 }],
                    # path => ['nest', 'test', 1]
                }))],
            },
            'Contains null'
        );

        check(
            $type,
            undef,
            {
                data => { nest => undef },
                errors => [noclass(superhashof({
                    message => 'Cannot return null for non-nullable field DataType.test.',
                    locations => [{ line => 1, column => 10 }],
                    # path => ['nest', 'test']
                }))],
            },
            'Returns null'
        );
    };
};

done_testing;
