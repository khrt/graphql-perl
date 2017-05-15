
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../../..";
use harness qw/
    expect_passes_rule
    expect_fails_rule
/;

sub missing_field_arg {
    my ($fieldName, $argName, $typeName, $line, $column) = @_;
    return {
        message => GraphQL::Validator::Rule::ProvidedNonNullArguments::missing_field_arg_message($fieldName, $argName, $typeName),
        locations => [{ line => $line, column => $column }],
        path => undef,
    };
}

sub missing_directive_arg {
    my ($directiveName, $argName, $typeName, $line, $column) = @_;
    return {
        message => GraphQL::Validator::Rule::ProvidedNonNullArguments::missing_directive_arg_message($directiveName, $argName, $typeName),
        locations => [{ line => $line, column => $column }],
        path => undef,
    };
}

subtest 'ignores unknown arguments' => sub {
    expect_passes_rule('ProvidedNonNullArguments', '
      {
        dog {
          isHousetrained(unknownArgument: true)
        }
      }
    ');
};

subtest 'Valid non-nullable value' => sub {
    subtest 'Arg on optional arg' => sub {
        expect_passes_rule('ProvidedNonNullArguments', '
        {
          dog {
            isHousetrained(atOtherHomes: true)
          }
        }
        ');
    };

    subtest 'No Arg on optional arg' => sub {
        expect_passes_rule('ProvidedNonNullArguments', '
        {
          dog {
            isHousetrained
          }
        }
        ');
    };

    subtest 'Multiple args' => sub {
        expect_passes_rule('ProvidedNonNullArguments', '
        {
          complicatedArgs {
            multipleReqs(req1: 1, req2: 2)
          }
        }
        ');
    };

    subtest 'Multiple args reverse order' => sub {
        expect_passes_rule('ProvidedNonNullArguments', '
        {
          complicatedArgs {
            multipleReqs(req2: 2, req1: 1)
          }
        }
        ');
    };

    subtest 'No args on multiple optional' => sub {
        expect_passes_rule('ProvidedNonNullArguments', '
        {
          complicatedArgs {
            multipleOpts
          }
        }
        ');
    };

    subtest 'One arg on multiple optional' => sub {
        expect_passes_rule('ProvidedNonNullArguments', '
        {
          complicatedArgs {
            multipleOpts(opt1: 1)
          }
        }
        ');
    };

    subtest 'Second arg on multiple optional' => sub {
        expect_passes_rule('ProvidedNonNullArguments', '
        {
          complicatedArgs {
            multipleOpts(opt2: 1)
          }
        }
        ');
    };

    subtest 'Multiple reqs on mixedList' => sub {
        expect_passes_rule('ProvidedNonNullArguments', '
        {
          complicatedArgs {
            multipleOptAndReq(req1: 3, req2: 4)
          }
        }
        ');
    };

    subtest 'Multiple reqs and one opt on mixedList' => sub {
        expect_passes_rule('ProvidedNonNullArguments', '
        {
          complicatedArgs {
            multipleOptAndReq(req1: 3, req2: 4, opt1: 5)
          }
        }
        ');
    };

    subtest 'All reqs and opts on mixedList' => sub {
        expect_passes_rule('ProvidedNonNullArguments', '
        {
          complicatedArgs {
            multipleOptAndReq(req1: 3, req2: 4, opt1: 5, opt2: 6)
          }
        }
        ');
    };
};

subtest 'Invalid non-nullable value' => sub {
    subtest 'Missing one non-nullable argument' => sub {
        expect_fails_rule('ProvidedNonNullArguments', '
        {
          complicatedArgs {
            multipleReqs(req2: 2)
          }
        }
        ', [
            missing_field_arg('multipleReqs', 'req1', 'Int!', 4, 13)
        ]);
    };

    subtest 'Missing multiple non-nullable arguments' => sub {
        plan skip_all => 'FAILS';

        expect_fails_rule('ProvidedNonNullArguments', '
        {
          complicatedArgs {
            multipleReqs
          }
        }
        ', [
            missing_field_arg('multipleReqs', 'req1', 'Int!', 4, 13),
            missing_field_arg('multipleReqs', 'req2', 'Int!', 4, 13),
        ]);
    };

    subtest 'Incorrect value and missing argument' => sub {
        expect_fails_rule('ProvidedNonNullArguments', '
        {
          complicatedArgs {
            multipleReqs(req1: "one")
          }
        }
        ', [
            missing_field_arg('multipleReqs', 'req2', 'Int!', 4, 13),
        ]);
    };
};

subtest 'Directive arguments' => sub {
    subtest 'ignores unknown directives' => sub {
        expect_passes_rule('ProvidedNonNullArguments', '
        {
          dog @unknown
        }
        ');
    };

    subtest 'with directives of valid types' => sub {
        expect_passes_rule('ProvidedNonNullArguments', '
        {
          dog @include(if: true) {
            name
          }
          human @skip(if: false) {
            name
          }
        }
        ');
    };

    subtest 'with directive with missing types' => sub {
        expect_fails_rule('ProvidedNonNullArguments', '
        {
          dog @include {
            name @skip
          }
        }
        ', [
            missing_directive_arg('include', 'if', 'Boolean!', 3, 15),
            missing_directive_arg('skip', 'if', 'Boolean!', 4, 18)
        ]);
    };
};

done_testing;
