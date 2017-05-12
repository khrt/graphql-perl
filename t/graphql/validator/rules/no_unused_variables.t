
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../../..";
use harness qw/
    expect_passes_rule
    expect_fails_rule
/;

sub unused_var {
    my ($var_name, $op_name, $line, $column) = @_;
    return {
        message => GraphQL::Validator::Rule::NoUnusedVariables::unused_variable_message($var_name, $op_name),
        locations => [{ line => $line, column => $column }],
        path => undef,
    };
}

subtest 'uses all variables' => sub {
    expect_passes_rule('NoUnusedVariables', '
      query ($a: String, $b: String, $c: String) {
        field(a: $a, b: $b, c: $c)
      }
    ');
};

subtest 'uses all variables deeply' => sub {
    expect_passes_rule('NoUnusedVariables', '
      query Foo($a: String, $b: String, $c: String) {
        field(a: $a) {
          field(b: $b) {
            field(c: $c)
          }
        }
      }
    ');
};

subtest 'uses all variables deeply in inline fragments' => sub {
    expect_passes_rule('NoUnusedVariables', '
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

subtest 'uses all variables in fragments' => sub {
    expect_passes_rule('NoUnusedVariables', '
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

subtest 'variable used by fragment in multiple operations' => sub {
    expect_passes_rule('NoUnusedVariables', '
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

subtest 'variable used by recursive fragment' => sub {
    expect_passes_rule('NoUnusedVariables', '
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

subtest 'variable not used' => sub {
    expect_fails_rule('NoUnusedVariables', '
      query ($a: String, $b: String, $c: String) {
        field(a: $a, b: $b)
      }
    ', [
      unused_var('c', undef, 2, 38)
    ]);
};

subtest 'multiple variables not used' => sub {
    expect_fails_rule('NoUnusedVariables', '
      query Foo($a: String, $b: String, $c: String) {
        field(b: $b)
      }
    ', [
      unused_var('a', 'Foo', 2, 17),
      unused_var('c', 'Foo', 2, 41)
    ]);
};

subtest 'variable not used in fragments' => sub {
    expect_fails_rule('NoUnusedVariables', '
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
        field
      }
    ', [
      unused_var('c', 'Foo', 2, 41)
    ]);
};

subtest 'multiple variables not used in fragments' => sub {
    expect_fails_rule('NoUnusedVariables', '
      query Foo($a: String, $b: String, $c: String) {
        ...FragA
      }
      fragment FragA on Type {
        field {
          ...FragB
        }
      }
      fragment FragB on Type {
        field(b: $b) {
          ...FragC
        }
      }
      fragment FragC on Type {
        field
      }
    ', [
      unused_var('a', 'Foo', 2, 17),
      unused_var('c', 'Foo', 2, 41)
    ]);
};

subtest 'variable not used by unreferenced fragment' => sub {
    expect_fails_rule('NoUnusedVariables', '
      query Foo($b: String) {
        ...FragA
      }
      fragment FragA on Type {
        field(a: $a)
      }
      fragment FragB on Type {
        field(b: $b)
      }
    ', [
      unused_var('b', 'Foo', 2, 17)
    ]);
};

subtest 'variable not used by fragment used by other operation' => sub {
    expect_fails_rule('NoUnusedVariables', '
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
      unused_var('b', 'Foo', 2, 17),
      unused_var('a', 'Bar', 5, 17)
    ]);
};

done_testing;
