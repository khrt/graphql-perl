
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../../..";
use harness qw/
    expect_passes_rule
    expect_fails_rule
/;

sub unknown_type {
    my ($type_name, $suggested_types, $line, $column) = @_;
    return {
        message => GraphQL::Validator::Rule::KnownTypeNames::unknown_type_message($type_name, $suggested_types),
        locations => [{ line => $line, column => $column }],
        path => undef,
    };
}

subtest 'known type names are valid' => sub {
    expect_passes_rule('KnownTypeNames', '
      query Foo($var: String, $required: [String!]!) {
        user(id: 4) {
          pets { ... on Pet { name }, ...PetFields, ... { name } }
        }
      }
      fragment PetFields on Pet {
        name
      }
    ');
};

subtest 'unknown type names are invalid' => sub {
    expect_fails_rule('KnownTypeNames', '
      query Foo($var: JumbledUpLetters) {
        user(id: 4) {
          name
          pets { ... on Badger { name }, ...PetFields }
        }
      }
      fragment PetFields on Peettt {
        name
      }
    ', [
      unknown_type('JumbledUpLetters', [], 2, 23),
      unknown_type('Badger', [], 5, 25),
      unknown_type('Peettt', [ 'Pet' ], 8, 29)
    ]);
};

subtest 'ignores type definitions' => sub {
    expect_fails_rule('KnownTypeNames', '
      type NotInTheSchema {
        field: FooBar
      }
      interface FooBar {
        field: NotInTheSchema
      }
      union U = A | B
      input Blob {
        field: UnknownType
      }
      query Foo($var: NotInTheSchema) {
        user(id: $var) {
          id
        }
      }
    ', [
      unknown_type('NotInTheSchema', [], 12, 23),
    ]);
};

done_testing;
