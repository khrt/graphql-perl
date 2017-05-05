
use strict;
use warnings;

use feature 'say';
use DDP;
use Test::More;

use GraphQL::Type qw/:all/;
use GraphQL::Util::Type qw/is_input_type is_output_type/;

my $BlogImage = GraphQLObjectType(
    name => 'Image',
    fields => {
        url => { type => GraphQLString },
        width => { type => GraphQLInt },
        height => { type => GraphQLInt },
    },
);

my $BlogArticle;
my $BlogAuthor;

$BlogAuthor = GraphQLObjectType(
    name => 'Author',
    fields => sub { {
        id => { type => GraphQLString },
        name => { type => GraphQLString },
        pic => {
            args => { width => { type => GraphQLInt }, height => { type => GraphQLInt } },
            type => $BlogImage,
        },
        recent_article => { type => $BlogArticle },
    } },
);

$BlogArticle = GraphQLObjectType(
    name => 'Article',
    fields => {
        id => { type => GraphQLString },
        is_published => { type => GraphQLBoolean },
        author => { type => $BlogAuthor },
        title => { type => GraphQLString },
        body => { type => GraphQLString },
    },
);

my $BlogQuery = GraphQLObjectType(
    name => 'Query',
    fields => {
        article => {
            args => { id => { type => GraphQLString } },
            type => $BlogArticle,
        },
        feed => {
            type => GraphQLList($BlogArticle),
        },
    },
);

my $BlogMutation = GraphQLObjectType(
    name => 'Mutation',
    fields => {
        write_article => {
            type => $BlogArticle,
        },
    },
);

my $BlogSubscription = GraphQLObjectType(
    name => 'Subscription',
    fields => {
        article_subscribe => {
            args => { id => { type => GraphQLString } },
            type => $BlogArticle,
        },
    },
);

my $ObjectType = GraphQLObjectType(
    name => 'Object',
    is_type_of => sub { 1 },
);
my $InterfaceType = GraphQLInterfaceType(name => 'Interface');
my $UnionType = GraphQLUnionType(
    name => 'Union',
    types => [$ObjectType],
);
my $EnumType = GraphQLEnumType(
    name => 'Enum',
    values => { foo => {} },
);
my $InputObjectType = GraphQLInputObjectType(name => 'InputObject');


subtest 'defines a query only schema' => sub {
    my $BlogSchema = GraphQLSchema(query => $BlogQuery);

    is_deeply $BlogSchema->get_query_type, $BlogQuery;

    my $article_field = $BlogQuery->get_fields->{article};
    is $article_field->{type}, $BlogArticle;
    is $article_field->{type}->name, 'Article';
    is $article_field->{name}, 'article';

    my $article_field_type = $article_field->{type};
    my $title_field = $article_field_type->isa('GraphQL::Type::Object')
        && $article_field_type->get_fields->{title};

    is $title_field->{name}, 'title';
    is_deeply $title_field->{type}, GraphQLString;
    is $title_field->{type}->name, 'String';

    my $author_field = $article_field_type->isa('GraphQL::Type::Object')
        && $article_field_type->get_fields->{author};
    my $author_field_type = $author_field->{type};
    my $recent_article_field = $author_field_type->isa('GraphQL::Type::Object')
        && $author_field_type->get_fields->{recent_article};

    is_deeply $recent_article_field->{type}, $BlogArticle;

    my $feed_field = $BlogQuery->get_fields->{feed};
    is $feed_field->{type}->of_type, $BlogArticle;
    is $feed_field->{name}, 'feed';
};

subtest 'defines a mutation schema' => sub {
    my $BlogSchema = GraphQLSchema(
        query => $BlogQuery,
        mutation => $BlogMutation
    );

    is $BlogSchema->get_mutation_type, $BlogMutation;

    my $write_mutation = $BlogMutation->get_fields->{write_article};
    is $write_mutation->{type}, $BlogArticle;
    is $write_mutation->{type}->name, 'Article';
    is $write_mutation->{name}, 'write_article';

};

subtest 'defines a subscription schema' => sub {
    my $BlogSchema = GraphQLSchema(
        query => $BlogQuery,
        subscription => $BlogSubscription
    );

    is_deeply $BlogSchema->get_subscription_type, $BlogSubscription;

    my $sub = $BlogSubscription->get_fields->{article_subscribe};
    is $sub->{type}, $BlogArticle;
    is $sub->{type}->name, 'Article';
    is $sub->{name}, 'article_subscribe';
};

subtest 'defines an enum type with deprecated value' => sub {
    my $EnumTypeWithDeprecatedValue = GraphQLEnumType(
        name => 'EnumWithDeprecatedValue',
        values => { foo => { deprecation_reason => 'Just because' } }
    );

    is_deeply $EnumTypeWithDeprecatedValue->get_values->[0], {
        name => 'foo',
        description => undef,
        is_deprecated => 1,
        deprecation_reason => 'Just because',
        value => 'foo'
    };
};

subtest 'defines an enum type with a value of `null` and `undefined`' => sub {
    my $EnumTypeWithNullishValue = GraphQLEnumType(
        name => 'EnumWithNullishValue',
        values => {
            NULL => { value => 0 },
            UNDEFINED => { value => undef },
        },
    );

    is_deeply $EnumTypeWithNullishValue->get_values, [
        {
            name               => 'NULL',
            description        => undef,
            is_deprecated      => 0,
            deprecation_reason => undef,
            value              => 'NULL', # XXX WAS value: null
        },
        {
            name               => 'UNDEFINED',
            description        => undef,
            is_deprecated      => 0,
            deprecation_reason => undef,
            value              => 'UNDEFINED', # XXX WAS value: undefined
        },
    ];
};

subtest 'defines an object type with deprecated field' => sub {
    my $TypeWithDeprecatedField = GraphQLObjectType(
        name => 'foo',
        fields => {
            bar => {
                type => GraphQLString,
                deprecation_reason => 'A terrible reason',
            },
        },
    );

    is_deeply $TypeWithDeprecatedField->get_fields->{bar}, {
        type => GraphQLString,
        deprecation_reason => 'A terrible reason',
        is_deprecated => 1,
        name => 'bar',
        args => [],
    };
};

subtest 'includes nested input objects in the map' => sub {
    my $NestedInputObject = GraphQLInputObjectType(
        name => 'NestedInputObject',
        fields => { value => { type => GraphQLString } }
    );
    my $SomeInputObject = GraphQLInputObjectType(
        name => 'SomeInputObject',
        fields => { nested => { type => $NestedInputObject } }
    );
    my $SomeMutation = GraphQLObjectType(
        name => 'SomeMutation',
        fields => {
            mutate_something => {
                type => $BlogArticle,
                args => { input => { type => $SomeInputObject } }
            }
        }
    );
    my $SomeSubscription = GraphQLObjectType(
        name => 'SomeSubscription',
        fields => {
            subscribe_to_something => {
                type => $BlogArticle,
                args => { input => { type => $SomeInputObject } }
            }
        }
    );
    my $schema = GraphQLSchema(
        query => $BlogQuery,
        mutation => $SomeMutation,
        subscription => $SomeSubscription
    );

    is_deeply $schema->get_type_map->{NestedInputObject}, $NestedInputObject;
};

subtest "includes interfaces' subtypes in the type map" => sub {
    my $SomeInterface = GraphQLInterfaceType(
        name => 'SomeInterface',
        fields => {
            f => { type => GraphQLInt },
        },
    );

    my $SomeSubtype = GraphQLObjectType(
        name => 'SomeSubtype',
        fields => {
            f => { type => GraphQLInt },
        },
        interfaces => [ $SomeInterface ],
        is_type_of => sub { 1 },
    );

    my $schema = GraphQLSchema(
        query => GraphQLObjectType(
            name => 'Query',
            fields => {
                iface => { type => $SomeInterface },
            },
        ),
        types => [ $SomeSubtype ]
    );

    is_deeply $schema->get_type_map->{SomeSubtype}, $SomeSubtype;
};

subtest 'includes interfaces\' thunk subtypes in the type map' => sub {
    my $SomeInterface = GraphQLInterfaceType(
        name => 'SomeInterface',
        fields => {
            f => { type => GraphQLInt },
        },
    );

    my $SomeSubtype = GraphQLObjectType(
        name => 'SomeSubtype',
        fields => {
            f => { type => GraphQLInt },
        },
        interfaces => sub { [$SomeInterface] },
        is_type_of => sub { 1 },
    );

    my $schema = GraphQLSchema(
        query => GraphQLObjectType(
            name => 'Query',
            fields => {
                iface => { type => $SomeInterface },
            },
        ),
        types => [$SomeSubtype],
    );

    is_deeply $schema->get_type_map->{SomeSubtype}, $SomeSubtype;
};


subtest 'stringifies simple types' => sub {
    is GraphQLInt->to_string, 'Int';
    is $BlogArticle->to_string, 'Article';
    is $InterfaceType->to_string, 'Interface';
    is $UnionType->to_string, 'Union';
    is $EnumType->to_string, 'Enum';
    is $InputObjectType->to_string, 'InputObject';
    is GraphQLNonNull(GraphQLInt)->to_string, 'Int!';
    is GraphQLList(GraphQLInt)->to_string, '[Int]';
    is GraphQLNonNull(GraphQLList(GraphQLInt))->to_string, '[Int]!';
    is GraphQLList(GraphQLNonNull(GraphQLInt))->to_string, '[Int!]';
    is GraphQLList(GraphQLList(GraphQLInt))->to_string, '[[Int]]';
};

subtest 'identifies input types' => sub {
    my @expected = (
        [GraphQLInt, 1],
        [$ObjectType, ''],
        [$InterfaceType, ''],
        [$UnionType, ''],
        [$EnumType, 1],
        [$InputObjectType, 1]
    );

    for my $p (@expected) {
        my ($type, $answer) = @$p;

        is is_input_type($type), $answer;
        is is_input_type(GraphQLList($type)), $answer;
        is is_input_type(GraphQLNonNull($type)), $answer;
    }
};

subtest 'identifies output types' => sub {
    my @expected = (
        [GraphQLInt, 1],
        [$ObjectType, 1],
        [$InterfaceType, 1],
        [$UnionType, 1],
        [$EnumType, 1],
        [$InputObjectType, '']
    );

    for my $p (@expected) {
        my ($type, $answer) = @$p;

        is is_output_type($type), $answer;
        is is_output_type(GraphQLList($type)), $answer;
        is is_output_type(GraphQLNonNull($type)), $answer;
    }
};

subtest 'prohibits nesting NonNull inside NonNull' => sub {
    eval { GraphQLNonNull(GraphQLNonNull(GraphQLInt)) };
    my $e = $@;
    is $e, "Can only create NonNull of a Nullable GraphQLType but got: Int!.\n";
};

subtest 'prohibits putting non-Object types in unions' => sub {
    my @bad_union_types = (
        GraphQLInt,
        GraphQLNonNull(GraphQLInt),
        GraphQLList(GraphQLInt),
        $InterfaceType,
        $UnionType,
        $EnumType,
        $InputObjectType
    );

    for my $x (@bad_union_types) {
        eval {
            GraphQLUnionType(name => 'BadUnion', types => [$x])->get_types
        };
        my $e = $@;
        is $e, "BadUnion may only contain Object types, it cannot contain: ${ \$x->to_string }.\n";
    }
};

subtest 'allows a thunk for Union\'s types' => sub {
    my $union = GraphQLUnionType(
        name => 'ThunkUnion',
        types => sub { [$ObjectType] },
    );

    my $types = $union->get_types;
    is scalar(@$types), 1;
    is_deeply $types->[0], $ObjectType;
};

subtest 'does not mutate passed field definitions' => sub {
    my $fields = {
        field1 => {
            type => GraphQLString,
        },
        field2 => {
            type => GraphQLString,
            args => {
                id => {
                    type => GraphQLString
                }
            }
        }
    };
    my $testObject1 = GraphQLObjectType(
        name => 'Test1',
        fields => $fields,
    );
    my $testObject2 = GraphQLObjectType(
        name => 'Test2',
        fields => $fields,
    );

    is_deeply $testObject1->get_fields, $testObject2->get_fields;
    is_deeply $fields, {
        field1 => {
            type => GraphQLString,
        },
        field2 => {
            type => GraphQLString,
            args => {
                id => {
                    type => GraphQLString
                }
            }
        }
        };

    my $testInputObject1 = GraphQLInputObjectType(
        name => 'Test1',
        fields => $fields,
    );
    my $testInputObject2 = GraphQLInputObjectType(
        name => 'Test2',
        fields => $fields,
    );

    is_deeply $testInputObject1->get_fields, $testInputObject2->get_fields;
    is_deeply $fields, {
        field1 => {
            type => GraphQLString,
        },
        field2 => {
            type => GraphQLString,
            args => {
                id => {
                    type => GraphQLString
                }
            }
        }
    };
};

done_testing;
