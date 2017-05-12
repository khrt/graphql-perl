
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../../..";
use harness qw/
    expect_passes_rule
    expect_fails_rule
/;

subtest 'input types are valid' => sub {
    expect_passes_rule('VariablesAreInputTypes', '
      query Foo($a: String, $b: [Boolean!]!, $c: ComplexInput) {
        field(a: $a, b: $b, c: $c)
      }
    ');
};

subtest 'output types are invalid' => sub {
    expect_fails_rule('VariablesAreInputTypes', '
      query Foo($a: Dog, $b: [[CatOrDog!]]!, $c: Pet) {
        field(a: $a, b: $b, c: $c)
      }
    ', [
      { locations => [ { line => 2, column => 21 } ],
        message => GraphQL::Validator::Rule::VariablesAreInputTypes::non_input_type_on_var_message('a', 'Dog'),
        path => undef },
      { locations => [ { line => 2, column => 30 } ],
        message => GraphQL::Validator::Rule::VariablesAreInputTypes::non_input_type_on_var_message('b', '[[CatOrDog!]]!'),
        path => undef },
      { locations => [ { line => 2, column => 50 } ],
        message => GraphQL::Validator::Rule::VariablesAreInputTypes::non_input_type_on_var_message('c', 'Pet'),
        path => undef },
    ]);
};

done_testing;
