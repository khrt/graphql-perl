
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../../..";
use harness qw/
    expect_passes_rule
    expect_fails_rule
/;

sub duplicate_field {
    my ($name, $l1, $c1, $l2, $c2) = @_;
    return {
        message => GraphQL::Validator::Rule::UniqueInputFieldNames::duplicate_input_field_message($name),
        locations => [{ line => $l1, column => $c1 }, { line => $l2, column => $c2 }],
        path => undef,
    };
}

subtest 'input object with fields' => sub {
    expect_passes_rule('UniqueInputFieldNames', '
      {
        field(arg: { f: true })
      }
    ');
};

subtest 'same input object within two args' => sub {
    expect_passes_rule('UniqueInputFieldNames', '
      {
        field(arg1: { f: true }, arg2: { f: true })
      }
    ');
};

subtest 'multiple input object fields' => sub {
    expect_passes_rule('UniqueInputFieldNames', '
      {
        field(arg: { f1: "value", f2: "value", f3: "value" })
      }
    ');
};

subtest 'allows for nested input objects with similar fields' => sub {
    expect_passes_rule('UniqueInputFieldNames', '
      {
        field(arg: {
          deep: {
            deep: {
              id: 1
            }
            id: 1
          }
          id: 1
        })
      }
    ');
};

subtest 'duplicate input object fields' => sub {
    expect_fails_rule('UniqueInputFieldNames', '
      {
        field(arg: { f1: "value", f1: "value" })
      }
    ', [
      duplicate_field('f1', 3, 22, 3, 35)
    ]);
};

subtest 'many duplicate input object fields' => sub {
    expect_fails_rule('UniqueInputFieldNames', '
      {
        field(arg: { f1: "value", f1: "value", f1: "value" })
      }
    ', [
      duplicate_field('f1', 3, 22, 3, 35),
      duplicate_field('f1', 3, 22, 3, 48)
    ]);
};

done_testing;
