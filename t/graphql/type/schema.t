
use strict;
use warnings;

use Test::More;

use GraphQL::Type qw/:all/;

my $ImplementingType;

my $InterfaceType = GraphQLInterfaceType(
    name => 'Interface',
    fields => { fieldName => { type => GraphQLString } },
    resolve_type => sub {
        return $ImplementingType;
    },
);

$ImplementingType = GraphQLObjectType(
    name => 'Object',
    interfaces => [ $InterfaceType ],
    fields => { fieldName => { type => GraphQLString, resolve => sub { '' } } },
);

my $Schema = GraphQLSchema(
    query => GraphQLObjectType(
        name => 'Query',
        fields => {
            getObject => {
                type => $InterfaceType,
                resolve => sub {
                    return {};
                }
            }
        }
    ),
);

subtest 'Type System: Schema' => sub {
    subtest 'Getting possible types' => sub {
        subtest 'throws human-reable error if schema.types is not defined' => sub {
            eval {
                $Schema->is_possible_type($InterfaceType, $ImplementingType);
            };
            my $e = $@;
            is $e, "Could not find possible implementing types for Interface in schema. "
                 . "Check that schema.types is defined and is an array of all possible "
                 . "types in the schema.\n";
        };
    };
};

done_testing;
