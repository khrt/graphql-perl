
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../../..";
use harness qw/
    expect_passes_rule
    expect_fails_rule
/;

sub unknown_arg {
    my ($arg_name, $field_name, $type_name, $suggested_args, $line, $column) = @_;
    return {
        message => GraphQL::Validator::Rule::KnownArgumentNames::unknown_arg_message($arg_name, $field_name, $type_name, $suggested_args),
        locations => [{ line => $line, column => $column }],
        path => undef,
    };
}

sub unknown_directive_arg {
    my ($arg_name, $directive_name, $suggested_args, $line, $column) = @_;
    return {
        message => GraphQL::Validator::Rule::KnownArgumentNames::unknown_directive_arg_message($arg_name, $directive_name, $suggested_args),
        locations => [{ line => $line, column => $column }],
        path => undef,
    };
}

subtest 'single arg is known' => sub {
    expect_passes_rule('KnownArgumentNames', '
      fragment argOnRequiredArg on Dog {
        doesKnowCommand(dogCommand: SIT)
      }
    ');
};

subtest 'multiple args are known' => sub {
    expect_passes_rule('KnownArgumentNames', '
      fragment multipleArgs on ComplicatedArgs {
        multipleReqs(req1: 1, req2: 2)
      }
    ');
};

subtest 'ignores args of unknown fields' => sub {
    expect_passes_rule('KnownArgumentNames', '
      fragment argOnUnknownField on Dog {
        unknownField(unknown_arg: SIT)
      }
    ');
};

subtest 'multiple args in reverse order are known' => sub {
    expect_passes_rule('KnownArgumentNames', '
      fragment multipleArgsReverseOrder on ComplicatedArgs {
        multipleReqs(req2: 2, req1: 1)
      }
    ');
};

subtest 'no args on optional arg' => sub {
    expect_passes_rule('KnownArgumentNames', '
      fragment noArgOnOptionalArg on Dog {
        isHousetrained
      }
    ');
};

subtest 'args are known deeply' => sub {
    expect_passes_rule('KnownArgumentNames', '
      {
        dog {
          doesKnowCommand(dogCommand: SIT)
        }
        human {
          pet {
            ... on Dog {
              doesKnowCommand(dogCommand: SIT)
            }
          }
        }
      }
    ');
};

subtest 'directive args are known' => sub {
    expect_passes_rule('KnownArgumentNames', '
      {
        dog @skip(if: true)
      }
    ');
};

subtest 'undirective args are invalid' => sub {
    expect_fails_rule('KnownArgumentNames', '
      {
        dog @skip(unless: true)
      }
    ', [
      unknown_directive_arg('unless', 'skip', [], 3, 19),
    ]);
};

subtest 'invalid arg name' => sub {
    expect_fails_rule('KnownArgumentNames', '
      fragment invalidArgName on Dog {
        doesKnowCommand(unknown: true)
      }
    ', [
      unknown_arg('unknown', 'doesKnowCommand', 'Dog', [], 3, 25),
    ]);
};

subtest 'unknown args amongst known args' => sub {
    expect_fails_rule('KnownArgumentNames', '
      fragment oneGoodArgOneInvalidArg on Dog {
        doesKnowCommand(whoknows: 1, dogCommand: SIT, unknown: true)
      }
    ', [
      unknown_arg('whoknows', 'doesKnowCommand', 'Dog', [], 3, 25),
      unknown_arg('unknown', 'doesKnowCommand', 'Dog', [], 3, 55),
    ]);
};

subtest 'unknown args deeply' => sub {
    expect_fails_rule('KnownArgumentNames', '
      {
        dog {
          doesKnowCommand(unknown: true)
        }
        human {
          pet {
            ... on Dog {
              doesKnowCommand(unknown: true)
            }
          }
        }
      }
    ', [
      unknown_arg('unknown', 'doesKnowCommand', 'Dog', [], 4, 27),
      unknown_arg('unknown', 'doesKnowCommand', 'Dog', [], 9, 31),
    ]);
};

done_testing;
