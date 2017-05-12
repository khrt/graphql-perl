
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../../..";
use harness qw/
    expect_passes_rule
    expect_fails_rule
/;

sub error {
    my ($frag_name, $type_name, $line, $column) = @_;
    return {
        message => GraphQL::Validator::Rule::FragmentsOnCompositeTypes::fragment_on_non_composite_error_message($frag_name, $type_name),
        locations => [{ line => $line, column => $column }],
        path => undef,
    };
}

subtest 'object is valid fragment type' => sub {
    expect_passes_rule('FragmentsOnCompositeTypes', '
      fragment validFragment on Dog {
        barks
      }
    ');
};

subtest 'interface is valid fragment type' => sub {
    expect_passes_rule('FragmentsOnCompositeTypes', '
      fragment validFragment on Pet {
        name
      }
    ');
};

subtest 'object is valid inline fragment type' => sub {
    expect_passes_rule('FragmentsOnCompositeTypes', '
      fragment validFragment on Pet {
        ... on Dog {
          barks
        }
      }
    ');
};

subtest 'inline fragment without type is valid' => sub {
    expect_passes_rule('FragmentsOnCompositeTypes', '
      fragment validFragment on Pet {
        ... {
          name
        }
      }
    ');
};

subtest 'union is valid fragment type' => sub {
    expect_passes_rule('FragmentsOnCompositeTypes', '
      fragment validFragment on CatOrDog {
        __typename
      }
    ');
};

subtest 'scalar is invalid fragment type' => sub {
    expect_fails_rule('FragmentsOnCompositeTypes', '
      fragment scalarFragment on Boolean {
        bad
      }
    ', [error('scalarFragment', 'Boolean', 2, 34)]);
};

subtest 'enum is invalid fragment type' => sub {
    expect_fails_rule('FragmentsOnCompositeTypes', '
      fragment scalarFragment on FurColor {
        bad
      }
    ', [error('scalarFragment', 'FurColor', 2, 34)]);
};

subtest 'input object is invalid fragment type' => sub {
    expect_fails_rule('FragmentsOnCompositeTypes', '
      fragment inputFragment on ComplexInput {
        stringField
      }
    ', [error('inputFragment', 'ComplexInput', 2, 33)]);
};

subtest 'scalar is invalid inline fragment type' => sub {
    expect_fails_rule('FragmentsOnCompositeTypes', '
      fragment invalidFragment on Pet {
        ... on String {
          barks
        }
      }
    ',
    [{ message => GraphQL::Validator::Rule::FragmentsOnCompositeTypes::inline_fragment_on_non_composite_error_message('String'),
        locations => [ { line => 3, column => 16 } ],
        path => undef, }]);
};

done_testing;
