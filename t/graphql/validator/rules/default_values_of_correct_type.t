
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../../..";
use harness qw/
    expect_passes_rule
    expect_fails_rule
/;

#
sub default_for_non_null_arg_message {
    my ($var_name, $type, $guess_type) = @_;
    return qq`Variable "\$$var_name" of type "$type" is required and `
         . qq`will not use the default value. `
         . qq`Perhaps you meant to use type "$guess_type".`;
}

sub bad_value_for_default_arg_message {
    my ($var_name, $type, $value, $verbose_errors) = @_;
    my $message = $verbose_errors ? "\n" . join("\n", @$verbose_errors) : '';
    return qq`Variable "\$$var_name" of type "$type" has invalid `
         . qq`default value $value.$message`;
}
#

sub default_for_non_null_arg {
    my ($var_name, $type_name, $guess_type_name, $line, $column) = @_;
    return {
        message => default_for_non_null_arg_message($var_name, $type_name, $guess_type_name),
        locations => [{ line => $line, column => $column }],
        path => undef,
    };
}

sub bad_value {
    my ($var_name, $type_name, $val, $line, $column, $errors) = @_;

    my $real_errors;
    if (!$errors) {
        $real_errors = [qq`Expected type "${type_name}", found ${val}.`];
    }
    else {
        $real_errors = $errors;
    }

    return {
        message => bad_value_for_default_arg_message($var_name, $type_name, $val, $real_errors),
        locations => [ { line => $line, column => $column } ],
        path => undef,
    };
}

subtest 'variables with no default values' => sub {
    expect_passes_rule('DefaultValuesOfCorrectType', '
      query NullableValues($a: Int, $b: String, $c: ComplexInput) {
        dog { name }
      }
    ');
};

subtest 'required variables without default values' => sub {
    expect_passes_rule('DefaultValuesOfCorrectType', '
      query RequiredValues($a: Int!, $b: String!) {
        dog { name }
      }
    ');
};

subtest 'variables with valid default values' => sub {
      expect_passes_rule('DefaultValuesOfCorrectType', '
      query WithDefaultValues(
        $a: Int = 1,
        $b: String = "ok",
        $c: ComplexInput = { requiredField: true, intField: 3 }
      ) {
        dog { name }
      }
    ');
};

subtest 'variables with valid default null values' => sub {
    expect_passes_rule('DefaultValuesOfCorrectType', '
      query WithDefaultValues(
        $a: Int = null,
        $b: String = null,
        $c: ComplexInput = { requiredField: true, intField: null }
      ) {
        dog { name }
      }
    ');
};

subtest 'variables with invalid default null values' => sub {
    expect_fails_rule('DefaultValuesOfCorrectType', '
      query WithDefaultValues(
        $a: Int! = null,
        $b: String! = null,
        $c: ComplexInput = { requiredField: null, intField: null }
      ) {
        dog { name }
      }',
      [
          default_for_non_null_arg('a', 'Int!', 'Int', 3, 20),
          bad_value('a', 'Int!', 'null', 3, 20, ['Expected "Int!", found null.' ]),
          default_for_non_null_arg('b', 'String!', 'String', 4, 23),
          bad_value('b', 'String!', 'null', 4, 23, ['Expected "String!", found null.']),
          bad_value('c', 'ComplexInput', '{requiredField: null, intField: null}', 5, 28, ['In field "requiredField": Expected "Boolean!", found null.']),
      ]);
};

subtest 'no required variables with default values' => sub {
    expect_fails_rule('DefaultValuesOfCorrectType', '
      query UnreachableDefaultValues($a: Int! = 3, $b: String! = "default") {
        dog { name }
      }
      ', [
        default_for_non_null_arg('a', 'Int!', 'Int', 2, 49),
        default_for_non_null_arg('b', 'String!', 'String', 2, 66)
    ]);
};

subtest 'variables with invalid default values' => sub {
    expect_fails_rule('DefaultValuesOfCorrectType', '
      query InvalidDefaultValues(
        $a: Int = "one",
        $b: String = 4,
        $c: ComplexInput = "notverycomplex"
      ) {
        dog { name }
      }
      ', [
        bad_value('a', 'Int', '"one"', 3, 19, [
                'Expected type "Int", found "one".'
        ]),
        bad_value('b', 'String', '4', 4, 22, [
                'Expected type "String", found 4.'
        ]),
        bad_value('c', 'ComplexInput', '"notverycomplex"', 5, 28, [
                'Expected "ComplexInput", found not an object.'
        ])
    ]);
};

subtest 'complex variables missing required field' => sub {
    expect_fails_rule('DefaultValuesOfCorrectType', '
      query MissingRequiredField($a: ComplexInput = {intField: 3}) {
        dog { name }
      }
    ', [
        bad_value('a', 'ComplexInput', '{intField: 3}', 2, 53, [
            'In field "requiredField": Expected "Boolean!", found null.'
        ])
    ]);
};

subtest 'list variables with invalid item' => sub {
    expect_fails_rule('DefaultValuesOfCorrectType', '
      query InvalidItem($a: [String] = ["one", 2]) {
        dog { name }
      }
    ', [
        bad_value('a', '[String]', '["one", 2]', 2, 40, [
            'In element #1: Expected type "String", found 2.'
        ])
    ]);
};

done_testing;
