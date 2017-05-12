
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../../..";
use harness qw/
    expect_passes_rule
    expect_fails_rule
/;

sub undef_var {
    my ($var_name, $l1, $c1, $op_name, $l2, $c2) = @_;
    return {
        message => GraphQL::Validator::Rule::NoUndefinedVariables::undefined_var_message($var_name, $op_name),
        locations => [{ line => $l1, column => $c1 }, { line => $l2, column => $c2 }],
        path => undef,
    };
}

subtest 'all variables defined' => sub {
    expect_passes_rule('NoUndefinedVariables', '
      query Foo($a: String, $b: String, $c: String) {
        field(a: $a, b: $b, c: $c)
      }
    ');
};

subtest 'all variables deeply defined' => sub {
    expect_passes_rule('NoUndefinedVariables', '
      query Foo($a: String, $b: String, $c: String) {
        field(a: $a) {
          field(b: $b) {
            field(c: $c)
          }
        }
      }
    ');
};

subtest 'all variables deeply in inline fragments defined' => sub {
    expect_passes_rule('NoUndefinedVariables', '
      query Foo($a: String, $b: String, $c: String) {
        ... on Type {
          field(a: $a) {
            field(b: $b) {
              ... on Type {
                field(c: $c)
              }
            }
          }
        }
      }
    ');
};

subtest 'all variables in fragments deeply defined' => sub {
    expect_passes_rule('NoUndefinedVariables', '
      query Foo($a: String, $b: String, $c: String) {
        ...FragA
      }
      fragment FragA on Type {
        field(a: $a) {
          ...FragB
        }
      }
      fragment FragB on Type {
        field(b: $b) {
          ...FragC
        }
      }
      fragment FragC on Type {
        field(c: $c)
      }
    ');
};

subtest 'variable within single fragment defined in multiple operations' => sub {
    expect_passes_rule('NoUndefinedVariables', '
      query Foo($a: String) {
        ...FragA
      }
      query Bar($a: String) {
        ...FragA
      }
      fragment FragA on Type {
        field(a: $a)
      }
    ');
};

subtest 'variable within fragments defined in operations' => sub {
    expect_passes_rule('NoUndefinedVariables', '
      query Foo($a: String) {
        ...FragA
      }
      query Bar($b: String) {
        ...FragB
      }
      fragment FragA on Type {
        field(a: $a)
      }
      fragment FragB on Type {
        field(b: $b)
      }
    ');
};

subtest 'variable within recursive fragment defined' => sub {
    expect_passes_rule('NoUndefinedVariables', '
      query Foo($a: String) {
        ...FragA
      }
      fragment FragA on Type {
        field(a: $a) {
          ...FragA
        }
      }
    ');
};

subtest 'variable not defined' => sub {
    expect_fails_rule('NoUndefinedVariables', '
      query Foo($a: String, $b: String, $c: String) {
        field(a: $a, b: $b, c: $c, d: $d)
      }
    ', [
      undef_var('d', 3, 39, 'Foo', 2, 7)
    ]);
};

subtest 'variable not defined by un-named query' => sub {
    expect_fails_rule('NoUndefinedVariables', '
      {
        field(a: $a)
      }
    ', [
      undef_var('a', 3, 18, '', 2, 7)
    ]);
};

subtest 'multiple variables not defined' => sub {
    expect_fails_rule('NoUndefinedVariables', '
      query Foo($b: String) {
        field(a: $a, b: $b, c: $c)
      }
    ', [
      undef_var('a', 3, 18, 'Foo', 2, 7),
      undef_var('c', 3, 32, 'Foo', 2, 7)
    ]);
};

subtest 'variable in fragment not defined by un-named query' => sub {
    expect_fails_rule('NoUndefinedVariables', '
      {
        ...FragA
      }
      fragment FragA on Type {
        field(a: $a)
      }
    ', [
      undef_var('a', 6, 18, '', 2, 7)
    ]);
};

subtest 'variable in fragment not defined by operation' => sub {
    expect_fails_rule('NoUndefinedVariables', '
      query Foo($a: String, $b: String) {
        ...FragA
      }
      fragment FragA on Type {
        field(a: $a) {
          ...FragB
        }
      }
      fragment FragB on Type {
        field(b: $b) {
          ...FragC
        }
      }
      fragment FragC on Type {
        field(c: $c)
      }
    ', [
      undef_var('c', 16, 18, 'Foo', 2, 7)
    ]);
};

subtest 'multiple variables in fragments not defined' => sub {
    expect_fails_rule('NoUndefinedVariables', '
      query Foo($b: String) {
        ...FragA
      }
      fragment FragA on Type {
        field(a: $a) {
          ...FragB
        }
      }
      fragment FragB on Type {
        field(b: $b) {
          ...FragC
        }
      }
      fragment FragC on Type {
        field(c: $c)
      }
    ', [
      undef_var('a', 6, 18, 'Foo', 2, 7),
      undef_var('c', 16, 18, 'Foo', 2, 7)
    ]);
};

subtest 'single variable in fragment not defined by multiple operations' => sub {
    expect_fails_rule('NoUndefinedVariables', '
      query Foo($a: String) {
        ...FragAB
      }
      query Bar($a: String) {
        ...FragAB
      }
      fragment FragAB on Type {
        field(a: $a, b: $b)
      }
    ', [
      undef_var('b', 9, 25, 'Foo', 2, 7),
      undef_var('b', 9, 25, 'Bar', 5, 7)
    ]);
};

subtest 'variables in fragment not defined by multiple operations' => sub {
    expect_fails_rule('NoUndefinedVariables', '
      query Foo($b: String) {
        ...FragAB
      }
      query Bar($a: String) {
        ...FragAB
      }
      fragment FragAB on Type {
        field(a: $a, b: $b)
      }
    ', [
      undef_var('a', 9, 18, 'Foo', 2, 7),
      undef_var('b', 9, 25, 'Bar', 5, 7)
    ]);
};

subtest 'variable in fragment used by other operation' => sub {
    expect_fails_rule('NoUndefinedVariables', '
      query Foo($b: String) {
        ...FragA
      }
      query Bar($a: String) {
        ...FragB
      }
      fragment FragA on Type {
        field(a: $a)
      }
      fragment FragB on Type {
        field(b: $b)
      }
    ', [
      undef_var('a', 9, 18, 'Foo', 2, 7),
      undef_var('b', 12, 18, 'Bar', 5, 7)
    ]);
};

subtest 'multiple undef variables produce multiple errors' => sub {
    expect_fails_rule('NoUndefinedVariables', '
      query Foo($b: String) {
        ...FragAB
      }
      query Bar($a: String) {
        ...FragAB
      }
      fragment FragAB on Type {
        field1(a: $a, b: $b)
        ...FragC
        field3(a: $a, b: $b)
      }
      fragment FragC on Type {
        field2(c: $c)
      }
    ', [
      undef_var('a', 9, 19, 'Foo', 2, 7),
      undef_var('a', 11, 19, 'Foo', 2, 7),
      undef_var('c', 14, 19, 'Foo', 2, 7),
      undef_var('b', 9, 26, 'Bar', 5, 7),
      undef_var('b', 11, 26, 'Bar', 5, 7),
      undef_var('c', 14, 19, 'Bar', 5, 7),
    ]);
};

done_testing;
