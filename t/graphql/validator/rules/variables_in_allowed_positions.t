
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../../..";
use harness qw/
    expect_passes_rule
    expect_fails_rule
/;

subtest 'Boolean => Boolean' => sub {
    expect_passes_rule('VariablesInAllowedPosition', '
      query Query($booleanArg: Boolean)
      {
        complicatedArgs {
          booleanArgField(booleanArg: $booleanArg)
        }
      }
    ');
};

subtest 'Boolean => Boolean within fragment' => sub {
    expect_passes_rule('VariablesInAllowedPosition', '
      fragment booleanArgFrag on ComplicatedArgs {
        booleanArgField(booleanArg: $booleanArg)
      }
      query Query($booleanArg: Boolean)
      {
        complicatedArgs {
          ...booleanArgFrag
        }
      }
    ');

    expect_passes_rule('VariablesInAllowedPosition', '
      query Query($booleanArg: Boolean)
      {
        complicatedArgs {
          ...booleanArgFrag
        }
      }
      fragment booleanArgFrag on ComplicatedArgs {
        booleanArgField(booleanArg: $booleanArg)
      }
    ');
};

subtest 'Boolean! => Boolean' => sub {
    expect_passes_rule('VariablesInAllowedPosition', '
      query Query($nonNullBooleanArg: Boolean!)
      {
        complicatedArgs {
          booleanArgField(booleanArg: $nonNullBooleanArg)
        }
      }
    ');
};

subtest 'Boolean! => Boolean within fragment' => sub {
    expect_passes_rule('VariablesInAllowedPosition', '
      fragment booleanArgFrag on ComplicatedArgs {
        booleanArgField(booleanArg: $nonNullBooleanArg)
      }

      query Query($nonNullBooleanArg: Boolean!)
      {
        complicatedArgs {
          ...booleanArgFrag
        }
      }
    ');
};

subtest 'Int => Int! with default' => sub {
    expect_passes_rule('VariablesInAllowedPosition', '
      query Query($intArg: Int = 1)
      {
        complicatedArgs {
          nonNullIntArgField(nonNullIntArg: $intArg)
        }
      }
    ');
};

subtest '[String] => [String' => sub {
    expect_passes_rule('VariablesInAllowedPosition', '
      query Query($stringListVar: [String])
      {
        complicatedArgs {
          stringListArgField(stringListArg: $stringListVar)
        }
      }
    ');
};

subtest '[String!] => [String' => sub {
    expect_passes_rule('VariablesInAllowedPosition', '
      query Query($stringListVar: [String!])
      {
        complicatedArgs {
          stringListArgField(stringListArg: $stringListVar)
        }
      }
    ');
};

subtest 'String => [String] in item position' => sub {
    expect_passes_rule('VariablesInAllowedPosition', '
      query Query($stringVar: String)
      {
        complicatedArgs {
          stringListArgField(stringListArg: [$stringVar])
        }
      }
    ');
};

subtest 'String! => [String] in item position' => sub {
    expect_passes_rule('VariablesInAllowedPosition', '
      query Query($stringVar: String!)
      {
        complicatedArgs {
          stringListArgField(stringListArg: [$stringVar])
        }
      }
    ');
};

subtest 'ComplexInput => ComplexInput' => sub {
    expect_passes_rule('VariablesInAllowedPosition', '
      query Query($complexVar: ComplexInput)
      {
        complicatedArgs {
          complexArgField(complexArg: $complexVar)
        }
      }
    ');
};

subtest 'ComplexInput => ComplexInput in field position' => sub {
    expect_passes_rule('VariablesInAllowedPosition', '
      query Query($boolVar: Boolean = false)
      {
        complicatedArgs {
          complexArgField(complexArg: {requiredArg: $boolVar})
        }
      }
    ');
};

subtest 'Boolean! => Boolean! in directive' => sub {
    expect_passes_rule('VariablesInAllowedPosition', '
      query Query($boolVar: Boolean!)
      {
        dog @include(if: $boolVar)
      }
    ');
};

subtest 'Boolean => Boolean! in directive with default' => sub {
    expect_passes_rule('VariablesInAllowedPosition', '
      query Query($boolVar: Boolean = false)
      {
        dog @include(if: $boolVar)
      }
    ');
};

subtest 'Int => Int' => sub {
    expect_fails_rule('VariablesInAllowedPosition', '
      query Query($intArg: Int) {
        complicatedArgs {
          nonNullIntArgField(nonNullIntArg: $intArg)
        }
      }
    ', [
      { message => GraphQL::Validator::Rule::VariablesInAllowedPosition::bad_var_pos_message('intArg', 'Int', 'Int!'),
        locations => [ { line => 2, column => 19 }, { line => 4, column => 45 } ],
        path => undef }
    ]);
};

subtest 'Int => Int! within fragment' => sub {
    expect_fails_rule('VariablesInAllowedPosition', '
      fragment nonNullIntArgFieldFrag on ComplicatedArgs {
        nonNullIntArgField(nonNullIntArg: $intArg)
      }

      query Query($intArg: Int) {
        complicatedArgs {
          ...nonNullIntArgFieldFrag
        }
      }
    ', [
      { message => GraphQL::Validator::Rule::VariablesInAllowedPosition::bad_var_pos_message('intArg', 'Int', 'Int!'),
        locations => [ { line => 6, column => 19 }, { line => 3, column => 43 } ],
        path => undef }
    ]);
};

subtest 'Int => Int! within nested fragment' => sub {
    expect_fails_rule('VariablesInAllowedPosition', '
      fragment outerFrag on ComplicatedArgs {
        ...nonNullIntArgFieldFrag
      }

      fragment nonNullIntArgFieldFrag on ComplicatedArgs {
        nonNullIntArgField(nonNullIntArg: $intArg)
      }

      query Query($intArg: Int) {
        complicatedArgs {
          ...outerFrag
        }
      }
    ', [
      { message => GraphQL::Validator::Rule::VariablesInAllowedPosition::bad_var_pos_message('intArg', 'Int', 'Int!'),
        locations => [ { line => 10, column => 19 }, { line => 7, column => 43 } ],
        path => undef }
    ]);
};

subtest 'String over Boolean' => sub {
    expect_fails_rule('VariablesInAllowedPosition', '
      query Query($stringVar: String) {
        complicatedArgs {
          booleanArgField(booleanArg: $stringVar)
        }
      }
    ', [
      { message => GraphQL::Validator::Rule::VariablesInAllowedPosition::bad_var_pos_message('stringVar', 'String', 'Boolean'),
        locations => [ { line => 2, column => 19 }, { line => 4, column => 39 } ],
        path => undef }
    ]);
};

subtest 'String => [String' => sub {
    expect_fails_rule('VariablesInAllowedPosition', '
      query Query($stringVar: String) {
        complicatedArgs {
          stringListArgField(stringListArg: $stringVar)
        }
      }
    ', [
      { message => GraphQL::Validator::Rule::VariablesInAllowedPosition::bad_var_pos_message('stringVar', 'String', '[String]'),
        locations => [ { line => 2, column => 19 }, { line => 4, column => 45 } ],
        path => undef }
    ]);
};

subtest 'Boolean => Boolean! in directive' => sub {
    expect_fails_rule('VariablesInAllowedPosition', '
      query Query($boolVar: Boolean) {
        dog @include(if: $boolVar)
      }
    ', [
      { message => GraphQL::Validator::Rule::VariablesInAllowedPosition::bad_var_pos_message('boolVar', 'Boolean', 'Boolean!'),
        locations => [ { line => 2, column => 19 }, { line => 3, column => 26 } ],
        path => undef }
    ]);
};

subtest 'String => Boolean! in directive' => sub {
    expect_fails_rule('VariablesInAllowedPosition', '
      query Query($stringVar: String) {
        dog @include(if: $stringVar)
      }
    ', [
      { message => GraphQL::Validator::Rule::VariablesInAllowedPosition::bad_var_pos_message('stringVar', 'String', 'Boolean!'),
        locations => [ { line => 2, column => 19 }, { line => 3, column => 26 } ],
        path => undef }
    ]);
};

done_testing;
