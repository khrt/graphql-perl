
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../../..";
use harness qw/
    expect_passes_rule
    expect_fails_rule
/;

sub duplicate_directive {
    my ($directiveName, $l1, $c1, $l2, $c2) = @_;
    return {
        message => GraphQL::Validator::Rule::UniqueDirectivesPerLocation::duplicate_directive_message($directiveName),
        locations => [{ line => $l1, column => $c1 }, { line => $l2, column => $c2 }],
        path => undef,
    };
}

subtest 'no directives' => sub {
    expect_passes_rule('UniqueDirectivesPerLocation', '
      fragment Test on Type {
        field
      }
    ');
};

subtest 'unique directives in different locations' => sub {
    expect_passes_rule('UniqueDirectivesPerLocation', '
      fragment Test on Type @directiveA {
        field @directiveB
      }
    ');
};

subtest 'unique directives in same locations' => sub {
    expect_passes_rule('UniqueDirectivesPerLocation', '
      fragment Test on Type @directiveA @directiveB {
        field @directiveA @directiveB
      }
    ');
};

subtest 'same directives in different locations' => sub {
    expect_passes_rule('UniqueDirectivesPerLocation', '
      fragment Test on Type @directiveA {
        field @directiveA
      }
    ');
};

subtest 'same directives in similar locations' => sub {
    expect_passes_rule('UniqueDirectivesPerLocation', '
      fragment Test on Type {
        field @directive
        field @directive
      }
    ');
};

subtest 'duplicate directives in one location' => sub {
    expect_fails_rule('UniqueDirectivesPerLocation', '
      fragment Test on Type {
        field @directive @directive
      }
    ', [
      duplicate_directive('directive', 3, 15, 3, 26)
    ]);
};

subtest 'many duplicate directives in one location' => sub {
    expect_fails_rule('UniqueDirectivesPerLocation', '
      fragment Test on Type {
        field @directive @directive @directive
      }
    ', [
      duplicate_directive('directive', 3, 15, 3, 26),
      duplicate_directive('directive', 3, 15, 3, 37)
    ]);
};

subtest 'different duplicate directives in one location' => sub {
    expect_fails_rule('UniqueDirectivesPerLocation', '
      fragment Test on Type {
        field @directiveA @directiveB @directiveA @directiveB
      }
    ', [
      duplicate_directive('directiveA', 3, 15, 3, 39),
      duplicate_directive('directiveB', 3, 27, 3, 51)
    ]);
};

subtest 'duplicate directives in many locations' => sub {
    expect_fails_rule('UniqueDirectivesPerLocation', '
      fragment Test on Type @directive @directive {
        field @directive @directive
      }
    ', [
      duplicate_directive('directive', 2, 29, 2, 40),
      duplicate_directive('directive', 3, 15, 3, 26)
    ]);
};

done_testing;
