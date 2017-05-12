
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../../..";
use harness qw/
    expect_passes_rule
    expect_fails_rule
/;

sub duplicate_op {
    my ($op_name, $l1, $c1, $l2, $c2) = @_;
    return {
        message => GraphQL::Validator::Rule::UniqueOperationNames::duplicate_operation_name_message($op_name),
        locations => [{ line => $l1, column => $c1 }, { line => $l2, column => $c2 }],
        path => undef,
    };
}

subtest 'no operations' => sub {
    expect_passes_rule('UniqueOperationNames', '
      fragment fragA on Type {
        field
      }
    ');
};

subtest 'one anon operation' => sub {
    expect_passes_rule('UniqueOperationNames', '
      {
        field
      }
    ');
};

subtest 'one named operation' => sub {
    expect_passes_rule('UniqueOperationNames', '
      query Foo {
        field
      }
    ');
};

subtest 'multiple operations' => sub {
    expect_passes_rule('UniqueOperationNames', '
      query Foo {
        field
      }

      query Bar {
        field
      }
    ');
};

subtest 'multiple operations of different types' => sub {
    expect_passes_rule('UniqueOperationNames', '
      query Foo {
        field
      }

      mutation Bar {
        field
      }

      subscription Baz {
        field
      }
    ');
};

subtest 'fragment and operation named the same' => sub {
    expect_passes_rule('UniqueOperationNames', '
      query Foo {
        ...Foo
      }
      fragment Foo on Type {
        field
      }
    ');
};

subtest 'multiple operations of same name' => sub {
    expect_fails_rule('UniqueOperationNames', '
      query Foo {
        fieldA
      }
      query Foo {
        fieldB
      }
    ', [
      duplicate_op('Foo', 2, 13, 5, 13)
    ]);
};

subtest 'multiple ops of same name of different types (mutation)' => sub {
    expect_fails_rule('UniqueOperationNames', '
      query Foo {
        fieldA
      }
      mutation Foo {
        fieldB
      }
    ', [
      duplicate_op('Foo', 2, 13, 5, 16)
    ]);
};

subtest 'multiple ops of same name of different types (subscription)' => sub {
    expect_fails_rule('UniqueOperationNames', '
      query Foo {
        fieldA
      }
      subscription Foo {
        fieldB
      }
    ', [
      duplicate_op('Foo', 2, 13, 5, 20)
    ]);
};

done_testing;
