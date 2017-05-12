
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../../..";
use harness qw/
    expect_passes_rule
    expect_fails_rule
/;

sub duplicate_frag {
    my ($frag_name, $l1, $c1, $l2, $c2) = @_;
    return {
        message => GraphQL::Validator::Rule::UniqueFragmentNames::duplicate_fragment_name_message($frag_name),
        locations => [{ line => $l1, column => $c1 }, { line => $l2, column => $c2 }],
        path => undef,
    };
}

subtest 'no fragments' => sub {
    expect_passes_rule('UniqueFragmentNames', '
      {
        field
      }
    ');
};

subtest 'one fragment' => sub {
    expect_passes_rule('UniqueFragmentNames', '
      {
        ...fragA
      }

      fragment fragA on Type {
        field
      }
    ');
};

subtest 'many fragments' => sub {
    expect_passes_rule('UniqueFragmentNames', '
      {
        ...fragA
        ...fragB
        ...fragC
      }
      fragment fragA on Type {
        fieldA
      }
      fragment fragB on Type {
        fieldB
      }
      fragment fragC on Type {
        fieldC
      }
    ');
};

subtest 'inline fragments are always unique' => sub {
    expect_passes_rule('UniqueFragmentNames', '
      {
        ...on Type {
          fieldA
        }
        ...on Type {
          fieldB
        }
      }
    ');
};

subtest 'fragment and operation named the same' => sub {
    expect_passes_rule('UniqueFragmentNames', '
      query Foo {
        ...Foo
      }
      fragment Foo on Type {
        field
      }
    ');
};

subtest 'fragments named the same' => sub {
    expect_fails_rule('UniqueFragmentNames', '
      {
        ...fragA
      }
      fragment fragA on Type {
        fieldA
      }
      fragment fragA on Type {
        fieldB
      }
    ', [
      duplicate_frag('fragA', 5, 16, 8, 16)
    ]);
};

subtest 'fragments named the same without being referenced' => sub {
    expect_fails_rule('UniqueFragmentNames', '
      fragment fragA on Type {
        fieldA
      }
      fragment fragA on Type {
        fieldB
      }
    ', [
      duplicate_frag('fragA', 2, 16, 5, 16)
    ]);
};

done_testing;
