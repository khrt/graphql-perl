
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../../..";
use harness qw/
    expect_passes_rule
    expect_fails_rule
/;

sub duplicate_arg {
    my ($arg_name, $l1, $c1, $l2, $c2) = @_;
    return {
        message => GraphQL::Validator::Rule::UniqueArgumentNames::duplicate_arg_message($arg_name),
        locations => [{ line => $l1, column => $c1 }, { line => $l2, column => $c2 }],
        path => undef,
    };
}

subtest 'no arguments on field' => sub {
    expect_passes_rule('UniqueArgumentNames', '
      {
        field
      }
    ');
};

subtest 'no arguments on directive' => sub {
    expect_passes_rule('UniqueArgumentNames', '
      {
        field @directive
      }
    ');
};

subtest 'argument on field' => sub {
    expect_passes_rule('UniqueArgumentNames', '
      {
        field(arg: "value")
      }
    ');
};

subtest 'argument on directive' => sub {
    expect_passes_rule('UniqueArgumentNames', '
      {
        field @directive(arg: "value")
      }
    ');
};

subtest 'same argument on two fields' => sub {
    expect_passes_rule('UniqueArgumentNames', '
      {
        one: field(arg: "value")
        two: field(arg: "value")
      }
    ');
};

subtest 'same argument on field and directive' => sub {
    expect_passes_rule('UniqueArgumentNames', '
      {
        field(arg: "value") @directive(arg: "value")
      }
    ');
};

subtest 'same argument on two directives' => sub {
    expect_passes_rule('UniqueArgumentNames', '
      {
        field @directive1(arg: "value") @directive2(arg: "value")
      }
    ');
};

subtest 'multiple field arguments' => sub {
    expect_passes_rule('UniqueArgumentNames', '
      {
        field(arg1: "value", arg2: "value", arg3: "value")
      }
    ');
};

subtest 'multiple directive arguments' => sub {
    expect_passes_rule('UniqueArgumentNames', '
      {
        field @directive(arg1: "value", arg2: "value", arg3: "value")
      }
    ');
};

subtest 'duplicate field arguments' => sub {
    expect_fails_rule('UniqueArgumentNames', '
      {
        field(arg1: "value", arg1: "value")
      }
    ', [
      duplicate_arg('arg1', 3, 15, 3, 30)
    ]);
};

subtest 'many duplicate field arguments' => sub {
    expect_fails_rule('UniqueArgumentNames', '
      {
        field(arg1: "value", arg1: "value", arg1: "value")
      }
    ', [
      duplicate_arg('arg1', 3, 15, 3, 30),
      duplicate_arg('arg1', 3, 15, 3, 45)
    ]);
};

subtest 'duplicate directive arguments' => sub {
    expect_fails_rule('UniqueArgumentNames', '
      {
        field @directive(arg1: "value", arg1: "value")
      }
    ', [
      duplicate_arg('arg1', 3, 26, 3, 41)
    ]);
};

subtest 'many duplicate directive arguments' => sub {
    expect_fails_rule('UniqueArgumentNames', '
      {
        field @directive(arg1: "value", arg1: "value", arg1: "value")
      }
    ', [
      duplicate_arg('arg1', 3, 26, 3, 41),
      duplicate_arg('arg1', 3, 26, 3, 56)
    ]);
};

done_testing;
