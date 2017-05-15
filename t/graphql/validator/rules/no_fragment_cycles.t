
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../../..";
use harness qw/
    expect_passes_rule
    expect_fails_rule
/;

subtest 'single reference is valid' => sub {
    expect_passes_rule('NoFragmentCycles', '
      fragment fragA on Dog { ...fragB }
      fragment fragB on Dog { name }
    ');
};

subtest 'spreading twice is not circular' => sub {
    expect_passes_rule('NoFragmentCycles', '
      fragment fragA on Dog { ...fragB, ...fragB }
      fragment fragB on Dog { name }
    ');
};

subtest 'spreading twice indirectly is not circular' => sub {
    expect_passes_rule('NoFragmentCycles', '
      fragment fragA on Dog { ...fragB, ...fragC }
      fragment fragB on Dog { ...fragC }
      fragment fragC on Dog { name }
    ');
};

subtest 'double spread within abstract types' => sub {
    expect_passes_rule('NoFragmentCycles', '
      fragment nameFragment on Pet {
        ... on Dog { name }
        ... on Cat { name }
      }

      fragment spreadsInAnon on Pet {
        ... on Dog { ...nameFragment }
        ... on Cat { ...nameFragment }
      }
    ');
};

subtest 'does not false positive on unknown fragment' => sub {
    expect_passes_rule('NoFragmentCycles', '
      fragment nameFragment on Pet {
        ...UnknownFragment
      }
    ');
};

subtest 'spreading recursively within field fails' => sub {
    expect_fails_rule('NoFragmentCycles', '
      fragment fragA on Human { relatives { ...fragA } },
    ', [
      { message => GraphQL::Validator::Rule::NoFragmentCycles::cycle_error_message('fragA', []),
        locations => [ { line => 2, column => 45 } ],
        path => undef }
    ]);
};

subtest 'no spreading itself directly' => sub {
    expect_fails_rule('NoFragmentCycles', '
      fragment fragA on Dog { ...fragA }
    ', [
      { message => GraphQL::Validator::Rule::NoFragmentCycles::cycle_error_message('fragA', []),
        locations => [ { line => 2, column => 31 } ],
        path => undef }
    ]);
};

subtest 'no spreading itself directly within inline fragment' => sub {
    expect_fails_rule('NoFragmentCycles', '
      fragment fragA on Pet {
        ... on Dog {
          ...fragA
        }
      }
    ', [
      { message => GraphQL::Validator::Rule::NoFragmentCycles::cycle_error_message('fragA', []),
        locations => [ { line => 4, column => 11 } ],
        path => undef }
    ]);
};

subtest 'no spreading itself indirectly' => sub {
    expect_fails_rule('NoFragmentCycles', '
      fragment fragA on Dog { ...fragB }
      fragment fragB on Dog { ...fragA }
    ', [
      { message => GraphQL::Validator::Rule::NoFragmentCycles::cycle_error_message('fragA', [ 'fragB' ]),
        locations => [ { line => 2, column => 31 }, { line => 3, column => 31 } ],
        path => undef }
    ]);
};

subtest 'no spreading itself indirectly reports opposite order' => sub {
    expect_fails_rule('NoFragmentCycles', '
      fragment fragB on Dog { ...fragA }
      fragment fragA on Dog { ...fragB }
    ', [
      { message => GraphQL::Validator::Rule::NoFragmentCycles::cycle_error_message('fragB', [ 'fragA' ]),
        locations => [ { line => 2, column => 31 }, { line => 3, column => 31 } ],
        path => undef }
    ]);
};


subtest 'no spreading itself indirectly within inline fragment' => sub {
    expect_fails_rule('NoFragmentCycles', '
      fragment fragA on Pet {
        ... on Dog {
          ...fragB
        }
      }
      fragment fragB on Pet {
        ... on Dog {
          ...fragA
        }
      }
    ', [
      { message => GraphQL::Validator::Rule::NoFragmentCycles::cycle_error_message('fragA', [ 'fragB' ]),
        locations => [ { line => 4, column => 11 }, { line => 9, column => 11 } ],
        path => undef }
    ]);
};

subtest 'no spreading itself deeply' => sub {
    plan skip_all => 'FAILS';

    expect_fails_rule('NoFragmentCycles', '
      fragment fragA on Dog { ...fragB }
      fragment fragB on Dog { ...fragC }
      fragment fragC on Dog { ...fragO }
      fragment fragX on Dog { ...fragY }
      fragment fragY on Dog { ...fragZ }
      fragment fragZ on Dog { ...fragO }
      fragment fragO on Dog { ...fragP }
      fragment fragP on Dog { ...fragA, ...fragX }
    ', [
      { message => GraphQL::Validator::Rule::NoFragmentCycles::cycle_error_message('fragA', [ 'fragB', 'fragC', 'fragO', 'fragP' ]),
        locations => [
          { line => 2, column => 31 },
          { line => 3, column => 31 },
          { line => 4, column => 31 },
          { line => 8, column => 31 },
          { line => 9, column => 31 } ],
        path => undef },
      { message => GraphQL::Validator::Rule::NoFragmentCycles::cycle_error_message('fragO', [ 'fragP', 'fragX', 'fragY', 'fragZ' ]),
        locations => [
          { line => 8, column => 31 },
          { line => 9, column => 41 },
          { line => 5, column => 31 },
          { line => 6, column => 31 },
          { line => 7, column => 31 } ],
        path => undef }
    ]);
};

subtest 'no spreading itself deeply two paths' => sub {
    expect_fails_rule('NoFragmentCycles', '
      fragment fragA on Dog { ...fragB, ...fragC }
      fragment fragB on Dog { ...fragA }
      fragment fragC on Dog { ...fragA }
    ', [
      { message => GraphQL::Validator::Rule::NoFragmentCycles::cycle_error_message('fragA', [ 'fragB' ]),
        locations => [ { line => 2, column => 31 }, { line => 3, column => 31 } ],
        path => undef },
      { message => GraphQL::Validator::Rule::NoFragmentCycles::cycle_error_message('fragA', [ 'fragC' ]),
        locations => [ { line => 2, column => 41 }, { line => 4, column => 31 } ],
        path => undef }
    ]);
};

subtest 'no spreading itself deeply two paths -- alt traverse order' => sub {
    plan skip_all => 'FAILS';

    expect_fails_rule('NoFragmentCycles', '
      fragment fragA on Dog { ...fragC }
      fragment fragB on Dog { ...fragC }
      fragment fragC on Dog { ...fragA, ...fragB }
    ', [
      { message => GraphQL::Validator::Rule::NoFragmentCycles::cycle_error_message('fragA', [ 'fragC' ]),
        locations => [ { line => 2, column => 31 }, { line => 4, column => 31 } ],
        path => undef },
      { message => GraphQL::Validator::Rule::NoFragmentCycles::cycle_error_message('fragC', [ 'fragB' ]),
        locations => [ { line => 4, column => 41 }, { line => 3, column => 31 } ],
        path => undef }
    ]);
};

subtest 'no spreading itself deeply and immediately' => sub {
    plan skip_all => 'FAILS';

    expect_fails_rule('NoFragmentCycles', '
      fragment fragA on Dog { ...fragB }
      fragment fragB on Dog { ...fragB, ...fragC }
      fragment fragC on Dog { ...fragA, ...fragB }
    ', [
      { message => GraphQL::Validator::Rule::NoFragmentCycles::cycle_error_message('fragB', []),
        locations => [ { line => 3, column => 31 } ],
        path => undef },
      { message => GraphQL::Validator::Rule::NoFragmentCycles::cycle_error_message('fragA', [ 'fragB', 'fragC' ]),
        locations => [
          { line => 2, column => 31 },
          { line => 3, column => 41 },
          { line => 4, column => 31 } ],
        path => undef },
      { message => GraphQL::Validator::Rule::NoFragmentCycles::cycle_error_message('fragB', [ 'fragC' ]),
        locations => [ { line => 3, column => 41 }, { line => 4, column => 41 } ],
        path => undef }
    ]);
};

done_testing;
