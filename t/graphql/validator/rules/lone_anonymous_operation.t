
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../../..";
use harness qw/
    expect_passes_rule
    expect_fails_rule
/;

sub anon_not_alone {
    my ($line, $column) = @_;
    return {
        message => GraphQL::Validator::Rule::LoneAnonymousOperation::anon_operation_not_alone_message(),
        locations => [{ line => $line, column => $column }],
        path => undef,
    };
}

subtest 'no operations' => sub {
    expect_passes_rule('LoneAnonymousOperation', '
      fragment fragA on Type {
        field
      }
    ');
};

subtest 'one anon operation' => sub {
    expect_passes_rule('LoneAnonymousOperation', '
      {
        field
      }
    ');
  };

subtest 'multiple named operations' => sub {
    expect_passes_rule('LoneAnonymousOperation', '
      query Foo {
        field
      }

      query Bar {
        field
      }
    ');
};

subtest 'anon operation with fragment' => sub {
    expect_passes_rule('LoneAnonymousOperation', '
      {
        ...Foo
      }
      fragment Foo on Type {
        field
      }
    ');
};

subtest 'multiple anon operations' => sub {
    expect_fails_rule('LoneAnonymousOperation', '
      {
        fieldA
      }
      {
        fieldB
      }
    ', [
      anon_not_alone(2, 7),
      anon_not_alone(5, 7)
    ]);
};

subtest 'anon operation with a mutation' => sub {
    expect_fails_rule('LoneAnonymousOperation', '
      {
        fieldA
      }
      mutation Foo {
        fieldB
      }
    ', [
      anon_not_alone(2, 7)
    ]);
};

subtest 'anon operation with a subscription' => sub {
    expect_fails_rule('LoneAnonymousOperation', '
      {
        fieldA
      }
      subscription Foo {
        fieldB
      }
    ', [
      anon_not_alone(2, 7)
    ]);
};

done_testing;
