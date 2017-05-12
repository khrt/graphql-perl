
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../../..";
use harness qw/
    expect_passes_rule
    expect_fails_rule
/;

sub duplicate_variable {
    my ($name, $l1, $c1, $l2, $c2) = @_;
    return {
        message => GraphQL::Validator::Rule::UniqueVariableNames::duplicate_variable_message($name),
        locations => [{ line => $l1, column => $c1 }, { line => $l2, column => $c2 }],
        path => undef,
    };
}

subtest 'unique variable names' => sub {
    expect_passes_rule('UniqueVariableNames', '
      query A($x: Int, $y: String) { __typename }
      query B($x: String, $y: Int) { __typename }
    ');
};

subtest 'duplicate variable names' => sub {
    expect_fails_rule('UniqueVariableNames', '
      query A($x: Int, $x: Int, $x: String) { __typename }
      query B($x: String, $x: Int) { __typename }
      query C($x: Int, $x: Int) { __typename }
    ', [
      duplicate_variable('x', 2, 16, 2, 25),
      duplicate_variable('x', 2, 16, 2, 34),
      duplicate_variable('x', 3, 16, 3, 28),
      duplicate_variable('x', 4, 16, 4, 25)
    ]);
};

done_testing;
