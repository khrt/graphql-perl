
use strict;
use warnings;

use DDP;
use Test::More;
use Test::Deep;

use GraphQL qw/graphql/;
use GraphQL::Type qw/:all/;

my $ColorType = GraphQLEnumType(
    name => 'Color',
    values => {
        RED => { value => 0 },
        GREEN => { value => 1 },
        BLUE => { value => 2 },
    },
);

my $Complex1 = { someRandomFunction => sub { {} } };
my $Complex2 = { someRandomValue => 123 };

my $ComplexEnum = GraphQLEnumType(
    name => 'Complex',
    values => {
        ONE => { value => $Complex1 },
        TWO => { value => $Complex2 },
    }
);

my $QueryType = GraphQLObjectType(
    name => 'Query',
    fields => {
        colorEnum => {
            type => $ColorType,
            args => {
                fromEnum => { type => $ColorType },
                fromInt => { type => GraphQLInt },
                fromString => { type => GraphQLString },
            },
            resolve => sub {
                my ($value, $args) = @_;

                my $fromEnum = $args->{fromEnum};
                my $fromInt = $args->{fromInt};
                my $fromString = $args->{fromString};

                return
                      defined($fromInt)    ? $fromInt
                    : defined($fromString) ? $fromString
                    :                        $fromEnum;
            }
        },
        colorInt => {
            type => GraphQLInt,
            args => {
                fromEnum => { type => $ColorType },
                fromInt => { type => GraphQLInt },
            },
            resolve => sub {
                my ($value, $args) = @_;
                return defined($args->{fromInt}) ? $args->{fromInt} : $args->{fromEnum};
            }
        },
        complexEnum => {
            type => $ComplexEnum,
            args => {
                fromEnum => {
                    type => $ComplexEnum,
                    # Note => default_value is provided an *internal* representation for
                    # Enums, rather than the string name.
                    default_value => $Complex1
                },
                provideGoodValue => { type => GraphQLBoolean },
                provideBadValue => { type => GraphQLBoolean }
            },
            resolve => sub {
                my ($value, $args) = @_;

                if ($args->{provideGoodValue}) {
                    # Note => this is one of the references of the internal values which
                    # ComplexEnum allows.
                    return $Complex2;
                }
                if ($args->{provideBadValue}) {
                    # Note => similar shape, but not the same *reference*
                    # as Complex2 above. Enum internal values require === equality.
                    return { someRandomValue => 123 };
                }
                return $args->{fromEnum};
            },
        },
    },
);

my $MutationType = GraphQLObjectType(
    name => 'Mutation',
    fields => {
        favoriteEnum => {
            type => $ColorType,
            args => { color => { type => $ColorType } },
            resolve => sub {
                my $obj = shift;
                return $obj->{color};
            },
        },
    },
);

my $SubscriptionType = GraphQLObjectType(
    name => 'Subscription',
    fields => {
        subscribeToEnum => {
            type => $ColorType,
            args => { color => { type => $ColorType } },
            resolve => sub {
                my $obj = shift;
                return $obj->{color};
            },
        },
    },
);

my $schema = GraphQLSchema(
    query => $QueryType,
    mutation => $MutationType,
    subscription => $SubscriptionType
);

# subtest 'accepts enum literals as input' => sub {
#     my $result = graphql($schema, '{ colorInt(fromEnum: GREEN) }');
#     is_deeply $result, { data => { colorInt => 1 } };
# };

# subtest 'enum may be output type' => sub {
#     my $result = graphql($schema, '{ colorEnum(fromInt: 1) }');
#     p $result;
#     is_deeply $result, { data => { colorEnum => 'GREEN' } };
# };

# subtest 'enum may be both input and output type' => sub {
#     my $result = graphql($schema, '{ colorEnum(fromEnum: GREEN) }');
#     p $result;
#     is_deeply $result, { data => { colorEnum => 'GREEN' } };
# };

# subtest 'does not accept string literals' => sub {
#     my $result = graphql($schema, '{ colorEnum(fromEnum: "GREEN") }');
#     cmp_deeply $result, {
#         errors => [
#             superhashof{
#                 message => qq`Argument "fromEnum" has invalid value "GREEN".\nExpected type "Color", found "GREEN".`,
#                 locations => [{ line => 1, column => 23 }],
#             },
#         ],
#     };
# };

# subtest 'does not accept incorrect internal value' => sub {
#     my $result = graphql($schema, '{ colorEnum(fromString: "GREEN") }');
#     p $result;
#     cmp_deeply $result, {
#         data => { colorEnum => undef },
#         errors => [{
#             message => 'Expected a value of type "Color" but received: GREEN',
#             locations => [{ line => 1, column => 3 }]
#         }]
#     };
# };

# subtest 'does not accept internal value in place of enum literal' => sub {
#     my $result = graphql($schema, '{ colorEnum(fromEnum: 1) }');
#     cmp_deeply $result, {
#         errors => [superhashof({
#             message => qq`Argument "fromEnum" has invalid value 1.\nExpected type "Color", found 1.`,
#             locations => [{ line => 1, column => 23 }],
#         })]
#     };
# };

# subtest 'does not accept enum literal in place of int' => sub {
#     my $result = graphql($schema, '{ colorEnum(fromInt : GREEN) }');
#     p $result;
#     cmp_deeply $result, {
#         errors => [superhashof({
#             message => qq`Argument "fromInt" has invalid value GREEN.\nExpected type "Int", found GREEN.`,
#             locations => [{ line => 1, column => 22 }]
#         })]
#     };
# };

# subtest 'accepts JSON string as enum variable' => sub {
#     my $result = graphql(
#         $schema,
#         'query test($color: Color!) { colorEnum(fromEnum: $color) }',
#         undef,
#         undef,
#         { color => 'BLUE' }
#     );
#     p $result;
#     is_deeply $result, { data => { colorEnum => 'BLUE' } };
# };

# subtest 'accepts enum literals as input arguments to mutations' => sub {
#     my $result = graphql(
#         $schema,
#         'mutation x($color: Color!) { favoriteEnum(color: $color) }',
#         undef,
#         undef,
#         { color => 'GREEN' }
#     );
#     p $result;
#     is_deeply $result, { data => { favoriteEnum => 'GREEN' } };
# };

# subtest 'accepts enum literals as input arguments to subscriptions' => sub {
#     my $result = graphql(
#         $schema,
#         'subscription x($color: Color!) { subscribeToEnum(color: $color) }',
#         undef,
#         undef,
#         { color => 'GREEN' }
#     );
#     p $result;
#     is_deeply $result, { data => { subscribeToEnum => 'GREEN' } };
# };

# subtest 'does not accept internal value as enum variable' => sub {
#     my $result = graphql(
#         $schema,
#         'query test($color: Color!) { colorEnum(fromEnum: $color) }',
#         undef,
#         undef,
#         { color => 2 }
#     );
#     p $result;
#     cmp_deeply $result, {
#         errors => [superhashof({
#             message => qq`Variable "\$color" got invalid value 2.\nExpected type "Color", found 2.`,
#             locations => [{ line => 1, column => 12 }]
#         })]
#     };
# };

# subtest 'does not accept string variables as enum input' => sub {
#     my $result = graphql(
#         $schema,
#         'query test($color: String!) { colorEnum(fromEnum: $color) }',
#         undef,
#         undef,
#         { color => 'BLUE' }
#     );
#     cmp_deeply $result, {
#         errors => [superhashof({
#             message => 'Variable "$color" of type "String!" used in position expecting type "Color".',
#             locations => [{ line => 1, column => 12 }, { line => 1, column => 51 }]
#         })]
#     };
# };

# subtest 'does not accept internal value variable as enum input' => sub {
#     my $result = graphql(
#         $schema,
#         'query test($color: Int!) { colorEnum(fromEnum: $color) }',
#         undef,
#         undef,
#         { color => 2 }
#     );
#     cmp_deeply $result, {
#         errors => [superhashof({
#             message => 'Variable "$color" of type "Int!" used in position expecting type "Color".',
#             locations => [{ line => 1, column => 12 }, { line => 1, column => 48 }]
#         })]
#     };
# };

# subtest 'enum value may have an internal value of 0' => sub {
#     my $result = graphql($schema, '
#         {
#             colorEnum(fromEnum: RED)
#             colorInt(fromEnum: RED)
#         }
#     ');
#     p $result;
#     is_deeply $result, {
#         data => {
#             colorEnum => 'RED',
#             colorInt => 0,
#         },
#     };
# };

# subtest 'enum inputs may be nullable' => sub {
#     my $result = graphql($schema, '
#         {
#             colorEnum
#             colorInt
#         }
#     ');
#     p $result;
#     is_deeply $result, {
#         data => {
#             colorEnum => undef,
#             colorInt => undef,
#         },
#     };
# };

# subtest 'presents a get_values API for complex enums' => sub {
#     my $values = $ComplexEnum->get_values;
#     is scalar @$values, 2;

#     my $one = (grep { $_->{name} eq 'ONE' } @$values)[0];
#     is $one->{name}, 'ONE';
#     is_deeply $one->{value}, $Complex1;

#     my $two = (grep { $_->{name} eq 'TWO' } @$values)[0];
#     is $two->{name}, 'TWO';
#     is_deeply $two->{value}, $Complex2;
# };

# subtest 'presents a get_value API for complex enums' => sub {
#     my $oneValue = $ComplexEnum->get_value('ONE');
#     is $oneValue->{name}, 'ONE';
#     is $oneValue->{value}, $Complex1;

#     my $badUsage = $ComplexEnum->get_value($Complex1);
#     is $badUsage, undef;
# };

subtest 'may be internally represented with complex values' => sub {
    my $result = graphql($schema, '{
        first: complexEnum
        second: complexEnum(fromEnum: TWO)
        good: complexEnum(provideGoodValue: true)
        bad: complexEnum(provideBadValue: true)
    }');
    p $result;
    cmp_deeply $result, {
        data => {
            first => 'ONE',
            second => 'TWO',
            good => 'TWO',
            bad => undef,
        },
        errors => [superhashof({
            message => 'Expected a value of type "Complex" but received: HASH',
            locations => [{ line => 5, column => 9 }]
        })]
    };
};

# subtest 'can be introspected without error' => sub {
#     my $result = graphql($schema, $introspectionQuery);
#     ok !$result->{errors};
# };

done_testing;
