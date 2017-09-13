
use strict;
use warnings;

use Test::More;
use Test::Deep;

use GraphQL qw/:types/;
use GraphQL::Language::Parser qw/parse/;

use lib "t/lib";
use test_helper qw/graphql execute encode_json/;

sub testSchema {
    my $testField = shift;
    return GraphQLSchema(
        query => GraphQLObjectType(
            name => 'Query',
            fields => {
                test => $testField,
            },
        ),
    );
}

subtest 'default function accesses properties' => sub {
    my $schema = testSchema({ type => GraphQLString });

    my $source = {
        test => 'testValue'
    };

    is_deeply graphql($schema, '{ test }', $source), {
        data => {
            test => 'testValue'
        }
    };
};

subtest 'default function calls methods' => sub {
    my $schema = testSchema({ type => GraphQLString });

    my $source;
    $source = {
        _secret => 'secretValue',
        test => sub { $source->{_secret} },
    };

    is_deeply graphql($schema, '{ test }', $source), {
        data => {
            test => 'secretValue'
        }
    };
};

subtest 'default function passes args and context' => sub {
    my $schema = testSchema({
        type => GraphQLInt,
        args => {
            addend1 => { type => GraphQLInt },
        },
    });

    {
        package Adder;

        sub new {
            my ($class, $num) = @_;
            bless { _num => $num }, $class;
        }

        sub test {
            my ($self, $args, $context) = @_;
            return $self->{_num} + $args->{addend1} + $context->{addend2};
        }
    }
    my $source = Adder->new(700);

    is_deeply graphql($schema, '{ test(addend1: 80) }', $source, { addend2 => 9 }),
        { data => { test => 789 } };
};

subtest 'uses provided resolve function' => sub {
    my $schema = testSchema({
            type => GraphQLString,
            args => {
                aStr => { type => GraphQLString },
                aInt => { type => GraphQLInt },
            },
            resolve => sub {
                my ($source, $args) = @_;
                encode_json([$source, $args]);
            }
        });

    is_deeply graphql($schema, '{ test }'), { data => { test => '[null,{}]' } };

    is_deeply graphql($schema, '{ test }', 'Source!'), {
        data => { test => '["Source!",{}]' }
    };

    is_deeply graphql($schema, '{ test(aStr: "String!") }', 'Source!'), {
        data => { test => '["Source!",{"aStr":"String!"}]' }
    };

    is_deeply graphql($schema, '{ test(aInt: -123, aStr: "String!") }', 'Source!'), {
        data => { test => '["Source!",{"aInt":-123,"aStr":"String!"}]' }
    };
};

done_testing;
