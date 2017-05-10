
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../../..";
use harness qw/
    expect_passes_rule
    expect_fails_rule
/;

sub bad_value {
    my ($arg_name, $type_name, $value, $line, $column, $errors) = @_;
    my $real_errors;

    if (!$errors) {
        $real_errors = [
            qq`Expected type "$type_name", found $value.`
        ];
    }
    else {
        $real_errors = $errors;
    }

    return {
        message => GraphQL::Validator::Rules::ArgumentsOfCorrectType::bad_value_message(
            $arg_name, $type_name, $value, $real_errors
        ),
        locations => [{ line => $line, column => $column }],
        path => undef,
    };
}

subtest 'Valid values' => sub {
    subtest 'Good int value' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            intArgField(intArg: 2)
          }
        }
        ');
    };

    subtest 'Good boolean value' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            booleanArgField(booleanArg: true)
          }
        }
        ');
    };

    subtest 'Good string value' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            stringArgField(stringArg: "foo")
          }
        }
        ');
    };

    subtest 'Good float value' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            floatArgField(floatArg: 1.1)
          }
        }
        ');
    };

    subtest 'Int into Float' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            floatArgField(floatArg: 1)
          }
        }
        ');
    };

    subtest 'Int into ID' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            idArgField(idArg: 1)
          }
        }
        ');
    };

    subtest 'String into ID' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            idArgField(idArg: "someIdString")
          }
        }
        ');
    };

    subtest 'Good enum value' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          dog {
            doesKnowCommand(dogCommand: SIT)
          }
        }
        ');
    };

    subtest 'null into nullable type' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            intArgField(intArg: null)
          }
        }
        ');

        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          dog(a: null, b: null, c:{ requiredField: true, intField: null }) {
            name
          }
        }
      ');
    };
};

subtest 'Invalid String values' => sub {
    subtest 'Int into String' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            stringArgField(stringArg: 1)
          }
        }
        ', [
            bad_value('stringArg', 'String', '1', 4, 39)
        ]);
    };

    subtest 'Float into String' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            stringArgField(stringArg: 1.0)
          }
        }
        ', [
            bad_value('stringArg', 'String', '1.0', 4, 39)
        ]);
    };

    subtest 'Boolean into String' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            stringArgField(stringArg: true)
          }
        }
        ', [
            bad_value('stringArg', 'String', 'true', 4, 39)
        ]);
    };

    subtest 'Unquoted String into String' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            stringArgField(stringArg: BAR)
          }
        }
        ', [
            bad_value('stringArg', 'String', 'BAR', 4, 39)
        ]);
    };
};

subtest 'Invalid Int values' => sub {
    subtest 'String into Int' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            intArgField(intArg: "3")
          }
        }
        ', [
            bad_value('intArg', 'Int', '"3"', 4, 33)
        ]);
    };

    subtest 'Big Int into Int' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            intArgField(intArg: 829384293849283498239482938)
          }
        }
      ', [
        bad_value('intArg', 'Int', '829384293849283498239482938', 4, 33)
      ]);
    };

    subtest 'Unquoted String into Int' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            intArgField(intArg: FOO)
          }
        }
        ', [
            bad_value('intArg', 'Int', 'FOO', 4, 33)
        ]);
    };

    subtest 'Simple Float into Int' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            intArgField(intArg: 3.0)
          }
        }
        ', [
          bad_value('intArg', 'Int', '3.0', 4, 33)
        ]);
    };

    subtest 'Float into Int' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            intArgField(intArg: 3.333)
          }
        }
      ', [
        bad_value('intArg', 'Int', '3.333', 4, 33)
      ]);
    };
};

subtest 'Invalid Float values' => sub {
    subtest 'String into Float' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            floatArgField(floatArg: "3.333")
          }
        }
      ', [
        bad_value('floatArg', 'Float', '"3.333"', 4, 37)
      ]);
    };

    subtest 'Boolean into Float' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            floatArgField(floatArg: true)
          }
        }
      ', [
        bad_value('floatArg', 'Float', 'true', 4, 37)
      ]);
    };

    subtest 'Unquoted into Float' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            floatArgField(floatArg: FOO)
          }
        }
      ', [
        bad_value('floatArg', 'Float', 'FOO', 4, 37)
      ]);
    };
};

subtest 'Invalid Boolean value' => sub {
    subtest 'Int into Boolean' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            booleanArgField(booleanArg: 2)
          }
        }
      ', [
        bad_value('booleanArg', 'Boolean', '2', 4, 41)
      ]);
    };

    subtest 'Float into Boolean' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            booleanArgField(booleanArg: 1.0)
          }
        }
      ', [
        bad_value('booleanArg', 'Boolean', '1.0', 4, 41)
      ]);
    };

    subtest 'String into Boolean' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            booleanArgField(booleanArg: "true")
          }
        }
      ', [
        bad_value('booleanArg', 'Boolean', '"true"', 4, 41)
      ]);
    };

    subtest 'Unquoted into Boolean' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            booleanArgField(booleanArg: TRUE)
          }
        }
      ', [
        bad_value('booleanArg', 'Boolean', 'TRUE', 4, 41)
      ]);
    };
};

subtest 'Invalid ID value' => sub {
    subtest 'Float into ID' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            idArgField(idArg: 1.0)
          }
        }
      ', [
        bad_value('idArg', 'ID', '1.0', 4, 31)
      ]);
    };

    subtest 'Boolean into ID' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            idArgField(idArg: true)
          }
        }
      ', [
        bad_value('idArg', 'ID', 'true', 4, 31)
      ]);
    };

    subtest 'Unquoted into ID' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            idArgField(idArg: SOMETHING)
          }
        }
      ', [
        bad_value('idArg', 'ID', 'SOMETHING', 4, 31)
      ]);
    };
};

subtest 'Invalid Enum value' => sub {
    subtest 'Int into Enum' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          dog {
            doesKnowCommand(dogCommand: 2)
          }
        }
      ', [
        bad_value('dogCommand', 'DogCommand', '2', 4, 41)
      ]);
    };

    subtest 'Float into Enum' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          dog {
            doesKnowCommand(dogCommand: 1.0)
          }
        }
      ', [
        bad_value('dogCommand', 'DogCommand', '1.0', 4, 41)
      ]);
    };

    subtest 'String into Enum' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          dog {
            doesKnowCommand(dogCommand: "SIT")
          }
        }
      ', [
        bad_value('dogCommand', 'DogCommand', '"SIT"', 4, 41)
      ]);
    };

    subtest 'Boolean into Enum' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          dog {
            doesKnowCommand(dogCommand: true)
          }
        }
      ', [
        bad_value('dogCommand', 'DogCommand', 'true', 4, 41)
      ]);
    };

    subtest 'Unknown Enum Value into Enum' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          dog {
            doesKnowCommand(dogCommand: JUGGLE)
          }
        }
      ', [
        bad_value('dogCommand', 'DogCommand', 'JUGGLE', 4, 41)
      ]);
    };

    subtest 'Different case Enum Value into Enum' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          dog {
            doesKnowCommand(dogCommand: sit)
          }
        }
      ', [
        bad_value('dogCommand', 'DogCommand', 'sit', 4, 41)
      ]);
    };
};

subtest 'Valid List value' => sub {
    subtest 'Good list value' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            stringListArgField(stringListArg: ["one", null, "two"])
          }
        }
        ');
    };

    subtest 'Empty list value' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            stringListArgField(stringListArg: [])
          }
        }
        ');
    };

    subtest 'Null value' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            stringListArgField(stringListArg: null)
          }
        }
        ');
    };

    subtest 'Single value into List' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            stringListArgField(stringListArg: "one")
          }
        }
        ');
    };
};

subtest 'Invalid List value' => sub {
    subtest 'Incorrect item type' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            stringListArgField(stringListArg: ["one", 2])
          }
        }
        ', [
            bad_value('stringListArg', '[String]', '["one", 2]', 4, 47,
                ['In element #1: Expected type "String", found 2.']),
        ]);
    };

    subtest 'Single value of incorrect type' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            stringListArgField(stringListArg: 1)
          }
        }
        ', [
            bad_value('stringListArg', 'String', '1', 4, 47),
        ]);
    };
};

subtest 'Valid non-nullable value' => sub {
    subtest 'Arg on optional arg' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          dog {
            isHousetrained(atOtherHomes: true)
          }
        }
        ');
    };

    subtest 'No Arg on optional arg' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          dog {
            isHousetrained
          }
        }
        ');
    };

    subtest 'Multiple args' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            multipleReqs(req1: 1, req2: 2)
          }
        }
        ');
    };

    subtest 'Multiple args reverse order' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            multipleReqs(req2: 2, req1: 1)
          }
        }
        ');
    };

    subtest 'No args on multiple optional' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            multipleOpts
          }
        }
        ');
    };

    subtest 'One arg on multiple optional' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            multipleOpts(opt1: 1)
          }
        }
        ');
    };

    subtest 'Second arg on multiple optional' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            multipleOpts(opt2: 1)
          }
        }
        ');
    };

    subtest 'Multiple reqs on mixedList' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            multipleOptAndReq(req1: 3, req2: 4)
          }
        }
        ');
    };

    subtest 'Multiple reqs and one opt on mixedList' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            multipleOptAndReq(req1: 3, req2: 4, opt1: 5)
          }
        }
        ');
    };

    subtest 'All reqs and opts on mixedList' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            multipleOptAndReq(req1: 3, req2: 4, opt1: 5, opt2: 6)
          }
        }
        ');
    };
};

subtest 'Invalid non-nullable value' => sub {
    subtest 'Incorrect value type' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            multipleReqs(req2: "two", req1: "one")
          }
        }
        ', [
            bad_value('req2', 'Int', '"two"', 4, 32),
            bad_value('req1', 'Int', '"one"', 4, 45),
        ]);
    };

    subtest 'Incorrect value and missing argument' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            multipleReqs(req1: "one")
          }
        }
        ', [
            bad_value('req1', 'Int', '"one"', 4, 32),
        ]);
    };

    subtest 'Null value' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            multipleReqs(req1: null)
          }
        }
        ', [
            bad_value('req1', 'Int!', 'null', 4, 32, [
                    'Expected "Int!", found null.'
                ]),
        ]);
    };
};

subtest 'Valid input object value' => sub {
   subtest 'Optional arg, despite required field in type' => sub {
       expect_passes_rule('ArgumentsOfCorrectType', '
       {
         complicatedArgs {
           complexArgField
         }
       }
       ');
   };

    subtest 'Partial object, only required' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            complexArgField(complexArg: { requiredField: true })
          }
        }
        ');
    };

    subtest 'Partial object, required field can be falsey' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            complexArgField(complexArg: { requiredField: false })
          }
        }
        ');
    };

    subtest 'Partial object, including required' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            complexArgField(complexArg: { requiredField: true, intField: 4 })
          }
        }
        ');
    };

   subtest 'Full object' => sub {
       expect_passes_rule('ArgumentsOfCorrectType', '
       {
         complicatedArgs {
           complexArgField(complexArg: {
             requiredField: true,
             intField: 4,
             stringField: "foo",
             booleanField: false,
             stringListField: ["one", "two"]
           })
         }
       }
       ');
   };

   subtest 'Full object with fields in different order' => sub {
       expect_passes_rule('ArgumentsOfCorrectType', '
       {
         complicatedArgs {
           complexArgField(complexArg: {
             stringListField: ["one", "two"],
             booleanField: false,
             requiredField: true,
             stringField: "foo",
             intField: 4,
           })
         }
       }
     ');
   };
};

subtest 'Invalid input object value' => sub {
    subtest 'Partial object, missing required' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            complexArgField(complexArg: { intField: 4 })
          }
        }
        ', [
            bad_value('complexArg', 'ComplexInput', '{intField: 4}', 4, 41, [
                'In field "requiredField": Expected "Boolean!", found null.'
            ]),
        ]);
    };

    subtest 'Partial object, invalid field type' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            complexArgField(complexArg: {
              stringListField: ["one", 2],
              requiredField: true,
            })
          }
        }
        ', [
            bad_value(
                'complexArg',
                'ComplexInput',
                '{stringListField: ["one", 2], requiredField: true}',
                4,
                41,
                ['In field "stringListField": In element #1: Expected type "String", found 2.']
            ),
        ]);
    };

    subtest 'Partial object, unknown field arg', => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          complicatedArgs {
            complexArgField(complexArg: {
              requiredField: true,
              unknownField: "value"
            })
          }
        }
        ',
        [
            bad_value(
                'complexArg',
                'ComplexInput',
                '{requiredField: true, unknownField: "value"}',
                4,
                41,
                [ 'In field "unknownField": Unknown field.' ]
            ),
        ]);
    };
};

subtest 'Directive arguments' => sub {
    subtest 'with directives of valid types' => sub {
        expect_passes_rule('ArgumentsOfCorrectType', '
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

    subtest 'with directive with incorrect types' => sub {
        expect_fails_rule('ArgumentsOfCorrectType', '
        {
          dog @include(if: "yes") {
            name @skip(if: ENUM)
          }
        }
        ',
          [
            bad_value('if', 'Boolean', '"yes"', 3, 28),
            bad_value('if', 'Boolean', 'ENUM', 4, 28),
        ]);
    };
};

done_testing;
