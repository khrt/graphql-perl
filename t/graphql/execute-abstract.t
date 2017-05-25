use strict;
use warnings;

use feature 'say';
use Carp qw/longmess/;
use DDP;
use Test::More;
use Test::Deep;
use JSON qw/encode_json/;

use GraphQL qw/graphql :types/;

{
    package Dog;
    sub new {
        my ($class, $name, $woofs) = @_;
        return bless { name => $name, woofs => $woofs }, $class;
    }

    package Cat;
    sub new {
        my ($class, $name, $meows) = @_;
        return bless { name => $name, meows => $meows }, $class;
    }

    package Human;
    sub new {
        my ($class, $name) = @_;
        return bless { name => $name }, $class;
    }
}

subtest 'is_type_of used to resolve runtime type for Interface' => sub {
    my $PetType = GraphQLInterfaceType(
        name => 'Pet',
        fields => {
            name => { type => GraphQLString },
        },
    );

    my $DogType = GraphQLObjectType(
        name => 'Dog',
        interfaces => [$PetType],
        is_type_of => sub {
            my $obj = shift;
            say 'dog type ' . ref($obj);
            return $obj->isa('Dog');
        },
        fields => {
            name => { type => GraphQLString },
            woofs => { type => GraphQLBoolean },
        },
    );

    my $CatType = GraphQLObjectType(
        name => 'Cat',
        interfaces => [$PetType],
        is_type_of => sub {
            my $obj = shift;
            # warn longmess('w');
            say 'cat type ' . ref($obj);
            return $obj->isa('Cat');
        },
        fields => {
            name => { type => GraphQLString },
            meows => { type => GraphQLBoolean },
        },
    );

    my $schema = GraphQLSchema(
        query => GraphQLObjectType(
            name => 'Query',
            fields => {
                pets => {
                    type => GraphQLList($PetType),
                    resolve => sub {
                        return [Dog->new('Odie', 1), Cat->new('Garfield', 0)];
                    },
                },
            },
        ),
        types => [$CatType, $DogType],
    );

    my $query = '{
      pets {
        name
        ... on Dog {
          woofs
        }
        ... on Cat {
          meows
        }
      }
    }';

    my $result = graphql($schema, $query);
    is_deeply $result, {
        data => {
            pets => [
                {
                    name  => 'Odie',
                    woofs => 1,
                },
                {
                    name  => 'Garfield',
                    meows => undef,# false
                },
            ],
        },
    };
};

subtest 'is_type_of used to resolve runtime type for Union' => sub {
    my $DogType = GraphQLObjectType(
        name => 'Dog',
        is_type_of => sub {
            my $obj = shift;
            return $obj->isa('Dog')
        },
        fields => {
            name => { type => GraphQLString },
            woofs => { type => GraphQLBoolean },
        }
    );

    my $CatType = GraphQLObjectType(
        name => 'Cat',
        is_type_of => sub {
            my $obj = shift;
            return $obj->isa('Cat')
        },
        fields => {
            name => { type => GraphQLString },
            meows => { type => GraphQLBoolean },
        }
    );

    my $PetType = GraphQLUnionType(
        name => 'Pet',
        types => [$DogType, $CatType]
    );

    my $schema = GraphQLSchema(
        query => GraphQLObjectType(
            name => 'Query',
            fields => {
                pets => {
                    type => GraphQLList($PetType),
                    resolve => sub {
                        return [Dog->new('Odie', 1), Cat->new('Garfield', 0)];
                    }
                }
            }
        )
    );

    my $query = '{
      pets {
        ... on Dog {
          name
          woofs
        }
        ... on Cat {
          name
          meows
        }
      }
    }';

    my $result = graphql($schema, $query);
    is_deeply $result, {
        data => {
            pets => [
                {
                    name  => 'Odie',
                    woofs => 1,
                },
                {
                    name  => 'Garfield',
                    meows => undef,# false
                },
            ],
        },
    };
};

subtest 'resolve_type on Interface yields useful error' => sub {
    my ($HumanType, $DogType, $CatType);

    my $PetType = GraphQLInterfaceType(
        name => 'Pet',
        resolve_type => sub {
            my $obj = shift;
            return
                  $obj->isa('Dog')   ? $DogType
                : $obj->isa('Cat')   ? $CatType
                : $obj->isa('Human') ? $HumanType
                :                      undef;
            },
        fields => {
            name => { type => GraphQLString }
        },
    );

    $HumanType = GraphQLObjectType(
        name => 'Human',
        fields => {
            name => { type => GraphQLString },
        },
    );

    $DogType = GraphQLObjectType(
        name => 'Dog',
        interfaces => [$PetType],
        fields => {
            name => { type => GraphQLString },
            woofs => { type => GraphQLBoolean },
        },
    );

    $CatType = GraphQLObjectType(
        name => 'Cat',
        interfaces => [$PetType],
        fields => {
            name => { type => GraphQLString },
            meows => { type => GraphQLBoolean },
        },
    );

    my $schema = GraphQLSchema(
        query => GraphQLObjectType(
            name => 'Query',
            fields => {
                pets => {
                    type => GraphQLList($PetType),
                    resolve => sub {
                        return [
                            Dog->new('Odie', 1),
                            Cat->new('Garfield', 0),
                            Human->new('Jon'),
                        ];
                    },
                },
            },
        ),
        types => [$CatType, $DogType],
    );

    my $query = '{
      pets {
        name
        ... on Dog {
          woofs
        }
        ... on Cat {
          meows
        }
      }
    }';

    my $result = graphql($schema, $query);

    cmp_deeply $result, {
        data => {
            pets => [
                {
                    name  => 'Odie',
                    woofs => 1, # true
                },
                {
                    name  => 'Garfield',
                    meows => undef, # false
                },
                undef,
            ],
        },
        errors => [
            noclass(superhashof({
                message => 'Runtime Object type "Human" is not a possible type for "Pet".',
                locations => [{ line => 2, column => 7 }],
                # TODO path => ['pets', 2]
            })),
        ],
    };
};

subtest 'resolve_type on Union yields useful error' => sub {
    my $HumanType = GraphQLObjectType(
        name => 'Human',
        fields => {
            name => { type => GraphQLString },
        }
    );

    my $DogType = GraphQLObjectType(
        name => 'Dog',
        fields => {
            name => { type => GraphQLString },
            woofs => { type => GraphQLBoolean },
        }
    );

    my $CatType = GraphQLObjectType(
        name => 'Cat',
        fields => {
            name => { type => GraphQLString },
            meows => { type => GraphQLBoolean },
        }
    );

    my $PetType = GraphQLUnionType(
        name => 'Pet',
        resolve_type => sub {
            my $obj = shift;
            return
                  $obj->isa('Dog')   ? $DogType
                : $obj->isa('Cat')   ? $CatType
                : $obj->isa('Human') ? $HumanType
                :                      undef;
            },
        types => [$DogType, $CatType]
    );


    my $schema = GraphQLSchema(
        query => GraphQLObjectType(
            name => 'Query',
            fields => {
                pets => {
                    type => GraphQLList($PetType),
                    resolve => sub {
                        return [
                            Dog->new('Odie', 1),
                            Cat->new('Garfield', 0),
                            Human->new('Jon')
                        ];
                    }
                }
            }
        )
    );

    my $query = '{
      pets {
        ... on Dog {
          name
          woofs
        }
        ... on Cat {
          name
          meows
        }
      }
    }';

    my $result = graphql($schema, $query);

    cmp_deeply $result, {
        data => {
            pets => [
                {
                    name  => 'Odie',
                    woofs => 1, # true
                },
                {
                    name  => 'Garfield',
                    meows => undef, # false
                },
                undef
            ],
        },
        errors => [
            noclass(superhashof({
                message => 'Runtime Object type "Human" is not a possible type for "Pet".',
                locations => [{ line => 2, column => 7 }],
                # TODO path => ['pets', 2]
            })),
        ],
    };
};

subtest 'resolve_type allows resolving with type name' => sub {
    my $PetType = GraphQLInterfaceType(
        name => 'Pet',
        resolve_type => sub {
            my $obj = shift;
            return
                  $obj->isa('Dog') ? 'Dog'
                : $obj->isa('Cat') ? 'Cat'
                :                    undef;
        },
        fields => {
            name => { type => GraphQLString },
        },
    );

    my $DogType = GraphQLObjectType(
        name => 'Dog',
        interfaces => [$PetType],
        fields => {
            name => { type => GraphQLString },
            woofs => { type => GraphQLBoolean },
        },
    );

    my $CatType = GraphQLObjectType(
        name => 'Cat',
        interfaces => [$PetType],
        fields => {
            name => { type => GraphQLString },
            meows => { type => GraphQLBoolean },
        },
    );

    my $schema = GraphQLSchema(
        query => GraphQLObjectType(
            name => 'Query',
            fields => {
                pets => {
                    type => GraphQLList($PetType),
                    resolve => sub {
                        return [
                            Dog->new('Odie', 1),
                            Cat->new('Garfield', 0)
                      ];
                    }
                }
            }
        ),
        types => [$CatType, $DogType],
    );

    my $query = '{
      pets {
        name
        ... on Dog {
          woofs
        }
        ... on Cat {
          meows
        }
      }
    }';

    my $result = graphql($schema, $query);

    is_deeply $result, {
        data => {
            pets => [
                { name => 'Odie', woofs => 1 },
                { name => 'Garfield', meows => undef },
            ]
        }
    };
};

done_testing;
