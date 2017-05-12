
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../../..";
use harness qw/
    expect_passes_rule
    expect_fails_rule
/;

sub no_scalar_subselection {
    my ($field, $type, $line, $column) = @_;
    return {
        message => GraphQL::Validator::Rule::ScalarLeafs::no_subselection_allowed_message($field, $type),
        locations => [{ line => $line, column => $column }],
        path => undef,
    };
}

sub missing_obj_subselection {
    my ($field, $type, $line, $column) = @_;
    return {
        message => GraphQL::Validator::Rule::ScalarLeafs::required_subselection_message($field, $type),
        locations => [{ line => $line, column => $column }],
        path => undef,
    };
}

subtest 'valid scalar selection' => sub {
    expect_passes_rule('ScalarLeafs', '
      fragment scalarSelection on Dog {
        barks
      }
    ');
};

subtest 'object type missing selection' => sub {
    expect_fails_rule('ScalarLeafs', '
      query directQueryOnObjectWithoutSubFields {
        human
      }
    ', [ missing_obj_subselection('human', 'Human', 3, 9) ]);
};

subtest 'interface type missing selection' => sub {
    expect_fails_rule('ScalarLeafs', '
      {
        human { pets }
      }
    ', [ missing_obj_subselection('pets', '[Pet]', 3, 17) ]);
};

subtest 'valid scalar selection with args' => sub {
    expect_passes_rule('ScalarLeafs', '
      fragment scalarSelectionWithArgs on Dog {
        doesKnowCommand(dogCommand: SIT)
      }
    ');
};

subtest 'scalar selection not allowed on Boolean' => sub {
    expect_fails_rule('ScalarLeafs', '
      fragment scalarSelectionsNotAllowedOnBoolean on Dog {
        barks { sinceWhen }
      }
    ',
    [ no_scalar_subselection('barks', 'Boolean', 3, 15) ] );
};

subtest 'scalar selection not allowed on Enum' => sub {
    expect_fails_rule('ScalarLeafs', '
      fragment scalarSelectionsNotAllowedOnEnum on Cat {
        furColor { inHexdec }
      }
    ',
    [ no_scalar_subselection('furColor', 'FurColor', 3, 18) ] );
};

subtest 'scalar selection not allowed with args' => sub {
    expect_fails_rule('ScalarLeafs', '
      fragment scalarSelectionsNotAllowedWithArgs on Dog {
        doesKnowCommand(dogCommand: SIT) { sinceWhen }
      }
    ',
    [ no_scalar_subselection('doesKnowCommand', 'Boolean', 3, 42) ] );
};

subtest 'Scalar selection not allowed with directives' => sub {
    expect_fails_rule('ScalarLeafs', '
      fragment scalarSelectionsNotAllowedWithDirectives on Dog {
        name @include(if: true) { isAlsoHumanName }
      }
    ',
    [ no_scalar_subselection('name', 'String', 3, 33) ] );
};

subtest 'Scalar selection not allowed with directives and args' => sub {
    expect_fails_rule('ScalarLeafs', '
      fragment scalarSelectionsNotAllowedWithDirectivesAndArgs on Dog {
        doesKnowCommand(dogCommand: SIT) @include(if: true) { sinceWhen }
      }
    ',
    [ no_scalar_subselection('doesKnowCommand', 'Boolean', 3, 61) ] );
};

done_testing;
