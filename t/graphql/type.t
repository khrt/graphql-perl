
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
my $BlogAuthor = GraphQLObjectType(
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

# it's a pity!
$BlogArticle = GraphQLObjectType(
    name => 'Article',
    fields => {
        id => { type => GraphQLString },
        is_published => { type => GraphQLBoolean },
        author => $BlogAuthor,
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


# subtest 'defines a query only schema' => sub {
#     my $BlogSchema = GraphQLSchema(
#         query => $BlogQuery
#     );

#     is $BlogSchema->getQueryType(), $BlogQuery;

#     my $articleField = $BlogQuery->get_fields->[('article' => string)];
#     is $articleField->type, $BlogArticle;
#     is $articleField->type->name, 'Article';
#     is $articleField->name, 'article';

#     my $articleFieldType = $articleField ? $articleField->type : null;

#     my $titleField = $articleFieldType->isa(GraphQLObjectType) &&
#     $articleFieldType->get_fields->[('title' => string)];
#     is $titleField->name, ('title');
#     is $titleField->type, (GraphQLString);
#     is $titleField->type->name, ('String');

#     my $authorField = $articleFieldType->isa(GraphQLObjectType) &&
#     $articleFieldType->get_fields->[('author' => string)];

#     my $authorFieldType = $authorField ? $authorField->type : null;
#     my $recentArticleField = $authorFieldType->isa(GraphQLObjectType) &&
#     $authorFieldType->get_fields->[('recentArticle' => string)];

#     is $recentArticleField->type, ($BlogArticle);

#     my $feedField = $BlogQuery->get_fields->[('feed' => string)];
#     is ($feedField->type => GraphQLList).ofType, $BlogArticle;
#     is $feedField->name, ('feed');

# };

subtest 'defines a mutation schema' => sub {
    my $BlogSchema = GraphQLSchema(
        query => $BlogQuery,
        mutation => $BlogMutation
    );

    is $BlogSchema->get_mutation_type, $BlogMutation;

    my $write_mutation = $BlogMutation->get_fields->{write_article};
    is $write_mutation->type, $BlogArticle;
    is $write_mutation->type->name, 'Article';
    is $write_mutation->name, 'write_article';

};

# subtest 'defines a subscription schema' => sub {
#     my $BlogSchema = GraphQLSchema(
#         query => $BlogQuery,
#         subscription => $BlogSubscription
#     );

#     expect($BlogSchema->getSubscriptionType()).to.equal($BlogSubscription);

#     my $sub = $BlogSubscription->get_fields()[('articleSubscribe' => string)];
#     is $sub && $sub->type, ($BlogArticle);
#     is $sub && $sub->type->name, ('Article');
#     is $sub && $sub->name, ('articleSubscribe');

# };

# subtest 'defines an enum type with deprecated value' => sub {
#     my $EnumTypeWithDeprecatedValue = GraphQLEnumType(
#         name => 'EnumWithDeprecatedValue',
#         values => { foo => { deprecation_reason => 'Just because' } }
#     );

#     expect($EnumTypeWithDeprecatedValue->getValues()[0]).to.deep.equal({
#             name => 'foo',
#             description => undef,
#             is_deprecated => 1,
#             deprecation_reason => 'Just because',
#             value => 'foo'
#         });
# };

# subtest 'defines an object type with deprecated field' => sub {
#     my $TypeWithDeprecatedField = GraphQLObjectType(
#         name => 'foo',
#         fields => {
#             bar => {
#                 type => GraphQLString,
#                 deprecationReason => 'A terrible reason'
#             }
#         }
#     );

#     expect($TypeWithDeprecatedField->get_fields()->bar).to.deep.equal({
#             type => GraphQLString,
#             deprecation_reason => 'A terrible reason',
#             is_deprecated => 1,
#             name => 'bar',
#             args => []
#         });
# };

# subtest 'includes nested input objects in the map' => sub {
#     my $NestedInputObject = GraphQLInputObjectType(
#         name => 'NestedInputObject',
#         fields => { value => { type => GraphQLString } }
#     );
#     my $SomeInputObject = GraphQLInputObjectType(
#         name => 'SomeInputObject',
#         fields => { nested => { type => $NestedInputObject } }
#     );
#     my $SomeMutation = GraphQLObjectType(
#         name => 'SomeMutation',
#         fields => {
#             mutateSomething => {
#                 type => $BlogArticle,
#                 args => { input => { type => $SomeInputObject } }
#             }
#         }
#     );
#     my $SomeSubscription = GraphQLObjectType(
#         name => 'SomeSubscription',
#         fields => {
#             subscribeToSomething => {
#                 type => $BlogArticle,
#                 args => { input => { type => $SomeInputObject } }
#             }
#         }
#     );
#     my $schema = GraphQLSchema(
#         query => $BlogQuery,
#         mutation => $SomeMutation,
#         subscription => $SomeSubscription
#     );
#     expect($schema->getTypeMap()->NestedInputObject).to.equal($NestedInputObject);
# };

# subtest 'includes interfaces\' subtypes in the type map' => sub {
#     my $SomeInterface = GraphQLInterfaceType(
#         name => 'SomeInterface',
#         fields => {
#             f => { type => GraphQLInt }
#         }
#     );

#     my $SomeSubtype = GraphQLObjectType(
#         name => 'SomeSubtype',
#         fields => {
#             f => { type => GraphQLInt }
#         },
#         interfaces => [ $SomeInterface ],
#         is_type_of => () => true
#     );

#     my $schema = GraphQLSchema(
#         query => GraphQLObjectType(
#             name => 'Query',
#             fields => {
#                 iface => { type => $SomeInterface }
#             }
#         ),
#         types => [ $SomeSubtype ]
#     );

#     expect($schema->getTypeMap().SomeSubtype).to.equal($SomeSubtype);
# };

# subtest 'includes interfaces\' thunk subtypes in the type map' => sub {
#     my $SomeInterface = GraphQLInterfaceType(
#         name => 'SomeInterface',
#         fields => {
#             f => { type => GraphQLInt }
#         }
#     );

#     my $SomeSubtype = GraphQLObjectType(
#         name => 'SomeSubtype',
#         fields => {
#             f => { type => GraphQLInt }
#         },
#         interfaces => () => [ $SomeInterface ],
#         is_type_of => () => true
#     );

#     my $schema = GraphQLSchema(
#         query => GraphQLObjectType(
#             name => 'Query',
#             fields => {
#                 iface => { type => $SomeInterface }
#             }
#         ),
#         types => [ $SomeSubtype ]
#     );

#     expect($schema->getTypeMap().SomeSubtype).to.equal($SomeSubtype);
# };


# subtest 'stringifies simple types' => sub {

#     expect(String(GraphQLInt)).to.equal('Int');
#     expect(String(BlogArticle)).to.equal('Article');
#     expect(String(InterfaceType)).to.equal('Interface');
#     expect(String(UnionType)).to.equal('Union');
#     expect(String(EnumType)).to.equal('Enum');
#     expect(String(InputObjectType)).to.equal('InputObject');
#     expect(
#         String(new GraphQLNonNull(GraphQLInt))
#     ).to.equal('Int!');
#     expect(
#         String(new GraphQLList(GraphQLInt))
#     ).to.equal('[Int]');
#     expect(
#         String(new GraphQLNonNull(new GraphQLList(GraphQLInt)))
#     ).to.equal('[Int]!');
#     expect(
#         String(new GraphQLList(new GraphQLNonNull(GraphQLInt)))
#     ).to.equal('[Int!]');
#     expect(
#         String(new GraphQLList(new GraphQLList(GraphQLInt)))
#     ).to.equal('[[Int]]');
# };

# subtest 'identifies input types' => sub {
#     my $expected = [
#         [ GraphQLInt, true ],
#         [ ObjectType, false ],
#         [ InterfaceType, false ],
#         [ UnionType, false ],
#         [ EnumType, true ],
#         [ InputObjectType, true ]
#     ];
#     expected.forEach(([ type, answer ]) => {
#             expect(isInputType(type)).to.equal(answer);
#             expect(isInputType(new GraphQLList(type))).to.equal(answer);
#             expect(isInputType(new GraphQLNonNull(type))).to.equal(answer);
#         });
# };

# subtest 'identifies output types' => sub {
#     my $expected = [
#         [ GraphQLInt, true ],
#         [ ObjectType, true ],
#         [ InterfaceType, true ],
#         [ UnionType, true ],
#         [ EnumType, true ],
#         [ InputObjectType, false ]
#     ];
#     expected.forEach(([ type, answer ]) => {
#             expect(isOutputType(type)).to.equal(answer);
#             expect(isOutputType(new GraphQLList(type))).to.equal(answer);
#             expect(isOutputType(new GraphQLNonNull(type))).to.equal(answer);
#         });
# };

# subtest 'prohibits nesting NonNull inside NonNull' => sub {
#     expect(() =>
#         new GraphQLNonNull(new GraphQLNonNull(GraphQLInt))
#     ).to.throw(
#         'Can only create NonNull of a Nullable GraphQLType but got => Int!.'
#     );
# };

# subtest 'prohibits putting non-Object types in unions' => sub {
#     my $badUnionTypes = [
#         GraphQLInt,
#         new GraphQLNonNull(GraphQLInt),
#         new GraphQLList(GraphQLInt),
#         InterfaceType,
#         UnionType,
#         EnumType,
#         InputObjectType
#     ];
#     badUnionTypes.forEach(x => {
#             expect(() =>
#                 new GraphQLUnionType({ name => 'BadUnion', types: [ x ] }).getTypes()
#             ).to.throw(
#                 `BadUnion may only contain Object types, it cannot contain => ${x}.`
#             );
#         });
# };

# subtest 'allows a thunk for Union\'s types' => sub {
#     my $union = GraphQLUnionType(
#         name => 'ThunkUnion',
#         types => () => [ ObjectType ]
#     );

#     my $types = $union->getTypes();
#     is $types.length, (1);
#     is $types[0], (ObjectType);
# };

# subtest 'does not mutate passed field definitions' => sub {
#     my $fields = {
#         field1 => {
#             type => GraphQLString,
#         },
#         field2 => {
#             type => GraphQLString,
#             args => {
#                 id => {
#                     type => GraphQLString
#                 }
#             }
#         }
#     };
#     my $testObject1 = GraphQLObjectType(
#         name => 'Test1',
#         %$fields,
#     );
#     my $testObject2 = GraphQLObjectType(
#         name => 'Test2',
#         %$fields,
#     );

#     expect($testObject1->get_fields()).to.deep.equal($testObject2->get_fields());
#     expect($fields).to.deep.equal({
#             field1 => {
#                 type => GraphQLString,
#             },
#             field2 => {
#                 type => GraphQLString,
#                 args => {
#                     id => {
#                         type => GraphQLString
#                     }
#                 }
#             }
#         });

#     my $testInputObject1 = GraphQLInputObjectType(
#         name => 'Test1',
#         %$fields
#     );
#     my $testInputObject2 = GraphQLInputObjectType(
#         name => 'Test2',
#         %$fields
#     );

#     expect($testInputObject1->get_fields()).to.deep.equal(
#         $testInputObject2->get_fields()
#     );
#     expect($fields).to.deep.equal({
#             field1 => {
#                 type => GraphQLString,
#             },
#             field2 => {
#                 type => GraphQLString,
#                 args => {
#                     id => {
#                         type => GraphQLString
#                     }
#                 }
#             }
#         });
# };

done_testing;
