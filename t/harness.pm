package harness;

use strict;
use warnings;

use Test::More;
use Exporter qw/import/;

our @EXPORT_OK = (qw/
    $test_schema

    expect_valid
    expect_invalid

    expect_passes_rule
    expect_fails_rule

    expect_passes_rule_with_schema
    expect_fails_rule_with_schema
/);

use GraphQL qw/:types/;
use GraphQL::Language::Parser qw/parse/;
use GraphQL::Validator qw/validate/;
use GraphQL::Error qw/format_error/;

my $Being = GraphQLInterfaceType(
    name => 'Being',
    fields => sub { {
        name => {
            type => GraphQLString,
            args => { surname => { type => GraphQLBoolean } },
        }
    } },
);

my $Pet = GraphQLInterfaceType(
    name => 'Pet',
    fields => sub { {
        name => {
            type => GraphQLString,
            args => { surname => { type => GraphQLBoolean } },
        },
    } },
);

my $Canine = GraphQLInterfaceType(
    name => 'Canine',
    fields => sub { {
        name => {
            type => GraphQLString,
            args => { surname => { type => GraphQLBoolean } },
        },
    } },
);

my $DogCommand = GraphQLEnumType(
    name => 'DogCommand',
    values => {
        SIT => { value => 0 },
        HEEL => { value => 1 },
        DOWN => { value => 2 },
    },
);

my $Dog = GraphQLObjectType(
    name => 'Dog',
    is_type_of => sub { 1 },
    fields => sub { {
        name => {
            type => GraphQLString,
            args => { surname => { type => GraphQLBoolean } },
        },
        nickname => { type => GraphQLString },
        barkVolume => { type => GraphQLInt },
        barks => { type => GraphQLBoolean },
        doesKnowCommand => {
            type => GraphQLBoolean,
            args => {
                dogCommand => { type => $DogCommand },
            },
        },
        isHousetrained => {
            type => GraphQLBoolean,
            args => {
                atOtherHomes => {
                    type => GraphQLBoolean,
                    defaultValue => 1,
                },
            },
        },
        isAtLocation => {
            type => GraphQLBoolean,
            args => { x => { type => GraphQLInt }, y => { type => GraphQLInt } },
        },
    } },
    interfaces => [$Being, $Pet, $Canine],
);

my $FurColor;
my $Cat = GraphQLObjectType(
    name => 'Cat',
    is_type_of => sub { 1 },
    fields => sub { {
        name => {
            type => GraphQLString,
            args => { surname => { type => GraphQLBoolean } },
        },
        nickname => { type => GraphQLString },
        meows => { type => GraphQLBoolean },
        meowVolume => { type => GraphQLInt },
        furColor => { type => $FurColor },
    } },
    interfaces => [$Being, $Pet],
);

my $CatOrDog = GraphQLUnionType(
    name => 'CatOrDog',
    types => [$Dog, $Cat],
    resolve_type => sub {
        # not used for validation
    },
);

my $Intelligent = GraphQLInterfaceType(
    name => 'Intelligent',
    fields => {
        iq => { type => GraphQLInt }
    }
);

my $Human;
$Human = GraphQLObjectType(
    name => 'Human',
    is_type_of => sub { 1 },
    interfaces => [$Being, $Intelligent],
    fields => sub { {
        name => {
            type => GraphQLString,
            args => { surname => { type => GraphQLBoolean } },
        },
        pets => { type => GraphQLList($Pet) },
        relatives => { type => GraphQLList($Human) },
        iq => { type => GraphQLInt },
    } },
);

my $Alien = GraphQLObjectType(
    name => 'Alien',
    is_type_of => sub { 1 },
    interfaces => [$Being, $Intelligent],
    fields => {
        iq => { type => GraphQLInt },
        name => {
            type => GraphQLString,
            args => { surname => { type => GraphQLBoolean } },
        },
        numEyes => { type => GraphQLInt },
    },
);

my $DogOrHuman = GraphQLUnionType(
    name => 'DogOrHuman',
    types => [$Dog, $Human],
    resolve_type => sub {
        # not used for validation
    },
);

my $HumanOrAlien = GraphQLUnionType(
    name => 'HumanOrAlien',
    types => [$Human, $Alien],
    resolve_type => sub {
        # not used for validation
    },
);

$FurColor = GraphQLEnumType(
    name   => 'FurColor',
    values => {
        BROWN   => { value => 0 },
        BLACK   => { value => 1 },
        TAN     => { value => 2 },
        SPOTTED => { value => 3 },
    },
);

my $ComplexInput = GraphQLInputObjectType(
    name => 'ComplexInput',
    fields => {
        requiredField => { type => GraphQLNonNull(GraphQLBoolean) },
        intField => { type => GraphQLInt },
        stringField => { type => GraphQLString },
        booleanField => { type => GraphQLBoolean },
        stringListField => { type => GraphQLList(GraphQLString) },
    },
);

my $ComplicatedArgs = GraphQLObjectType(
  name => 'ComplicatedArgs',
  # TODO List
  # TODO Coercion
  # TODO NotNulls
  fields => sub { {
    intArgField => {
      type => GraphQLString,
      args => { intArg => { type => GraphQLInt } },
    },
    nonNullIntArgField => {
      type => GraphQLString,
      args => { nonNullIntArg => { type => GraphQLNonNull(GraphQLInt) } },
    },
    stringArgField => {
      type => GraphQLString,
      args => { stringArg => { type => GraphQLString } },
    },
    booleanArgField => {
      type => GraphQLString,
      args => { booleanArg => { type => GraphQLBoolean } },
    },
    enumArgField => {
      type => GraphQLString,
      args => { enumArg => { type => $FurColor } },
    },
    floatArgField => {
      type => GraphQLString,
      args => { floatArg => { type => GraphQLFloat } },
    },
    idArgField => {
      type => GraphQLString,
      args => { idArg => { type => GraphQLID } },
    },
    stringListArgField => {
      type => GraphQLString,
      args => { stringListArg => { type => GraphQLList(GraphQLString) } },
    },
    complexArgField => {
      type => GraphQLString,
      args => { complexArg => { type => $ComplexInput } },
    },
    multipleReqs => {
      type => GraphQLString,
      args => {
        req1 => { type => GraphQLNonNull(GraphQLInt) },
        req2 => { type => GraphQLNonNull(GraphQLInt) },
      },
    },
    multipleOpts => {
      type => GraphQLString,
      args => {
        opt1 => {
          type => GraphQLInt,
          defaultValue => 0,
        },
        opt2 => {
          type => GraphQLInt,
          defaultValue => 0,
        },
      },
    },
    multipleOptAndReq => {
      type => GraphQLString,
      args => {
        req1 => { type => GraphQLNonNull(GraphQLInt) },
        req2 => { type => GraphQLNonNull(GraphQLInt) },
        opt1 => {
          type => GraphQLInt,
          defaultValue => 0,
        },
        opt2 => {
          type => GraphQLInt,
          defaultValue => 0,
        },
      },
    },
  } },
);

my $QueryRoot = GraphQLObjectType(
    name => 'QueryRoot',
    fields => sub { {
        human => {
            args => { id => { type => GraphQLID } },
            type => $Human,
        },
        alien => { type => $Alien },
        dog => { type => $Dog },
        cat => { type => $Cat },
        pet => { type => $Pet },
        catOrDog => { type => $CatOrDog },
        dogOrHuman => { type => $DogOrHuman },
        humanOrAlien => { type => $HumanOrAlien },
        complicatedArgs => { type => $ComplicatedArgs },
    } },
);

our $test_schema = GraphQLSchema(
    query => $QueryRoot,
    types => [$Cat, $Dog, $Human, $Alien],
    directives => [
        GraphQLIncludeDirective,
        GraphQLSkipDirective,
        GraphQLDirective(
            name => 'onQuery',
            locations => ['QUERY'],
        ),
        GraphQLDirective(
            name => 'onMutation',
            locations => ['MUTATION'],
        ),
        GraphQLDirective(
            name => 'onSubscription',
            locations => ['SUBSCRIPTION'],
        ),
        GraphQLDirective(
            name => 'onField',
            locations => ['FIELD'],
        ),
        GraphQLDirective(
            name => 'onFragmentDefinition',
            locations => ['FRAGMENT_DEFINITION'],
        ),
        GraphQLDirective(
            name => 'onFragmentSpread',
            locations => ['FRAGMENT_SPREAD'],
        ),
        GraphQLDirective(
            name => 'onInlineFragment',
            locations => ['INLINE_FRAGMENT'],
        ),
        GraphQLDirective(
            name => 'onSchema',
            locations => ['SCHEMA'],
        ),
        GraphQLDirective(
            name => 'onScalar',
            locations => ['SCALAR'],
        ),
        GraphQLDirective(
            name => 'onObject',
            locations => ['OBJECT'],
        ),
        GraphQLDirective(
            name => 'onFieldDefinition',
            locations => ['FIELD_DEFINITION'],
        ),
        GraphQLDirective(
            name => 'onArgumentDefinition',
            locations => ['ARGUMENT_DEFINITION'],
        ),
        GraphQLDirective(
            name => 'onInterface',
            locations => ['INTERFACE'],
        ),
        GraphQLDirective(
            name => 'onUnion',
            locations => ['UNION'],
        ),
        GraphQLDirective(
            name => 'onEnum',
            locations => ['ENUM'],
        ),
        GraphQLDirective(
            name => 'onEnumValue',
            locations => ['ENUM_VALUE'],
        ),
        GraphQLDirective(
            name => 'onInputObject',
            locations => ['INPUT_OBJECT'],
        ),
        GraphQLDirective(
            name => 'onInputFieldDefinition',
            locations => ['INPUT_FIELD_DEFINITION'],
        ),
    ]
);

sub expect_valid {
    my ($schema, $rules, $query_string) = @_;
    my $errors = validate($schema, parse($query_string), $rules);

    # use DDP;
    # print 'errors '; my $e = [map { format_error($_) } @$errors]; p $e;

    is_deeply $errors, [], 'Should validate';
}

sub expect_invalid {
    my ($schema, $rules, $query_string, $expected_errors) = @_;
    my $errors = validate($schema, parse($query_string), $rules);

    ok(scalar(@$errors) >= 1, 'Should not validate');
    # use DDP;
    # print 'errors '; my $e = [map { format_error($_) } @$errors]; p $e;
    # print 'expected errors '; p $expected_errors;
    is_deeply [map { format_error($_) } @$errors], $expected_errors;
}

sub expect_passes_rule {
    my ($rule, $query_string) = @_;
    expect_valid($test_schema, [$rule], $query_string);
}

sub expect_fails_rule {
    my ($rule, $query_string, $errors) = @_;
    expect_invalid($test_schema, [$rule], $query_string, $errors);
}

sub expect_passes_rule_with_schema {
    my ($schema, $rule, $query_string, $errors) = @_;
    expect_valid($schema, [$rule], $query_string, $errors);
}

sub expect_fails_rule_with_schema {
    my ($schema, $rule, $query_string, $errors) = @_;
    expect_invalid($schema, [$rule], $query_string, $errors);
}
