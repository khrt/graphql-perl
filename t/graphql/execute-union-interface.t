
use strict;
use warnings;

use DDP;
use Test::More;
use Test::Deep;
use JSON qw/encode_json/;

use GraphQL qw/graphql :types/;
use GraphQL::Language::Parser qw/parse/;
use GraphQL::Execute qw/execute/;

{
    package Dog;
    sub new {
        my ($class, $name, $barks) = @_;
        bless {
            name => $name,
            barks => $barks,
        }, $class;
    }

    package Cat;
    sub new {
        my ($class, $name, $meows) = @_;
        bless {
            name => $name,
            meows => $meows,
        }, $class;
    }

    package Person;
    sub new {
        my ($class, $name, $pets, $friends) = @_;
        bless {
            name => $name,
            pets => $pets,
            friends => $friends,
        }, $class;
    }
}

my $NamedType = GraphQLInterfaceType(
    name => 'Named',
    fields => {
        name => { type => GraphQLString }
    }
);

my $DogType = GraphQLObjectType(
    name => 'Dog',
    interfaces => [$NamedType],
    fields => {
        name => { type => GraphQLString },
        barks => { type => GraphQLBoolean }
    },
    is_type_of => sub {
        my $value = shift;
        $value->isa('Dog');
    },
);

my $CatType = GraphQLObjectType(
    name => 'Cat',
    interfaces => [$NamedType],
    fields => {
        name => { type => GraphQLString },
        meows => { type => GraphQLBoolean }
    },
    is_type_of => sub {
        my $value = shift;
        $value->isa('Cat');
    },
);

my $PetType = GraphQLUnionType(
    name => 'Pet',
    types => [$DogType, $CatType],
    resolve_type => sub {
        my $value = shift;

        if ($value->isa('Dog')) {
            return $DogType;
        }

        if ($value->isa('Cat')) {
            return $CatType;
        }
    }
);

my $PersonType = GraphQLObjectType(
    name => 'Person',
    interfaces => [$NamedType],
    fields => {
        name => { type => GraphQLString },
        pets => { type => GraphQLList($PetType) },
        friends => { type => GraphQLList($NamedType) },
    },
    is_type_of => sub {
        my $value = shift;
        $value->isa('Person')
    },
);

my $schema = GraphQLSchema(
    query => $PersonType,
    types => [$PetType]
);

my $garfield = Cat->new('Garfield', 0);
my $odie = Dog->new('Odie', 1);
my $liz = Person->new('Liz');
my $john = Person->new('John', [$garfield, $odie], [$liz, $odie]);

subtest 'can introspect on union and intersection types' => sub {
    my $ast = parse('
      {
        Named: __type(name: "Named") {
          kind
          name
          fields { name }
          interfaces { name }
          possibleTypes { name }
          enumValues { name }
          inputFields { name }
        }
        Pet: __type(name: "Pet") {
          kind
          name
          fields { name }
          interfaces { name }
          possibleTypes { name }
          enumValues { name }
          inputFields { name }
        }
      }
    ');

    is_deeply execute($schema, $ast), {
        data => {
            Named => {
                kind => 'INTERFACE',
                name => 'Named',
                fields => [
                    { name => 'name' }
                ],
                interfaces => undef,
                possibleTypes => [
                    { name => 'Person' },
                    { name => 'Dog' },
                    { name => 'Cat' },
                ],
                enumValues => undef,
                inputFields => undef
            },
            Pet => {
                kind => 'UNION',
                name => 'Pet',
                fields => undef,
                interfaces => undef,
                possibleTypes => [
                    { name => 'Dog' },
                    { name => 'Cat' }
                ],
                enumValues => undef,
                inputFields => undef
            }
        }
    };
};

subtest 'executes using union types' => sub {

    # NOTE: This is an *invalid* query, but it should be an *executable* query.
    my $ast = parse('
        {
        __typename
        name
        pets {
          __typename
          name
          barks
          meows
        }
      }
    ');

    is_deeply execute($schema, $ast, $john), {
        data => {
            __typename => 'Person',
            name => 'John',
            pets => [
                { __typename => 'Cat', name => 'Garfield', meows => 0 },
                { __typename => 'Dog', name => 'Odie', barks => 1 }
            ]
        }
    };
};

subtest 'executes union types with inline fragments' => sub {

    # This is the valid version of the query in the above test.
    my $ast = parse('
      {
        __typename
        name
        pets {
          __typename
          ... on Dog {
            name
            barks
          }
          ... on Cat {
            name
            meows
          }
        }
      }
    ');

    is_deeply execute($schema, $ast, $john), {
        data => {
            __typename => 'Person',
            name => 'John',
            pets => [
                { __typename => 'Cat', name => 'Garfield', meows => 0 },
                { __typename => 'Dog', name => 'Odie', barks => 1 }
            ]
        }
    };
};

subtest 'executes using interface types' => sub {

    # NOTE: This is an *invalid* query, but it should be an *executable* query.
    my $ast = parse('
      {
        __typename
        name
        friends {
          __typename
          name
          barks
          meows
        }
      }
    ');

    is_deeply execute($schema, $ast, $john), {
        data => {
            __typename => 'Person',
            name       => 'John',
            friends    => [
                { __typename => 'Person', name => 'Liz' },
                { __typename => 'Dog',    name => 'Odie', barks => 1 }
            ]
        }
    };
};

subtest 'executes union types with inline fragments' => sub {

    # This is the valid version of the query in the above test.
    my $ast = parse('
      {
        __typename
        name
        friends {
          __typename
          name
          ... on Dog {
            barks
          }
          ... on Cat {
            meows
          }
        }
      }
    ');

    is_deeply execute($schema, $ast, $john), {
        data => {
            __typename => 'Person',
            name => 'John',
            friends => [
                { __typename => 'Person', name => 'Liz' },
                { __typename => 'Dog', name => 'Odie', barks => 1 }
            ]
        }
    };
};

subtest 'allows fragment conditions to be abstract types' => sub {

    my $ast = parse('
      {
        __typename
        name
        pets { ...PetFields }
        friends { ...FriendFields }
      }

      fragment PetFields on Pet {
        __typename
        ... on Dog {
          name
          barks
        }
        ... on Cat {
          name
          meows
        }
      }

      fragment FriendFields on Named {
        __typename
        name
        ... on Dog {
          barks
        }
        ... on Cat {
          meows
        }
      }
    ');

    is_deeply execute($schema, $ast, $john), {
        data => {
            __typename => 'Person',
            name => 'John',
            pets => [
                { __typename => 'Cat', name => 'Garfield', meows => 0 },
                { __typename => 'Dog', name => 'Odie', barks => 1 }
            ],
            friends => [
                { __typename => 'Person', name => 'Liz' },
                { __typename => 'Dog', name => 'Odie', barks => 1 }
            ]
        }
    };
};

subtest 'gets execution info in resolver' => sub {
    my $encounteredContext;
    my $encounteredSchema;
    my $encounteredRootValue;

    my $PersonType2;
    my $NamedType2 = GraphQLInterfaceType(
        name => 'Named',
        fields => {
            name => { type => GraphQLString }
        },
        resolve_type => sub {
            my ($obj, $context, $info) = @_;
            $encounteredContext = $context;
            $encounteredSchema = $info->{_schema};
            $encounteredRootValue = $info->{rootValue};
            return $PersonType2;
        },
    );

    $PersonType2 = GraphQLObjectType(
      name => 'Person',
      interfaces => [$NamedType2],
      fields => {
        name => { type => GraphQLString },
        friends => { type => GraphQLList($NamedType2) },
      },
    );

    my $schema2 = GraphQLSchema(
      query => $PersonType2
    );

    my $john2 = Person->new('John', [], [$liz]);

    my $context = { authToken => '123abc' };

    my $ast = parse('{ name, friends { name } }');

    is_deeply execute($schema2, $ast, $john2, $context), {
      data => { name => 'John', friends => [{ name => 'Liz' }] }
    };
    is_deeply $encounteredContext, $context;
    is_deeply $encounteredSchema, $schema2;
    is_deeply $encounteredRootValue, $john2;
};

done_testing;
