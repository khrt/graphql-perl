
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../../..";
use harness qw/
    expect_passes_rule
    expect_fails_rule
/;

use GraphQL::Util qw/
    quoted_or_list
/;

sub undefined_field {
    my ($field, $type, $suggested_types, $suggested_fields, $line, $column) = @_;
    return {
        message => GraphQL::Validator::Rule::FieldsOnCorrectType::undefined_field_message(
            $field,
            $type,
            $suggested_types,
            $suggested_fields
        ),
        locations => [{ line => $line, column => $column }],
        path => undef,
    };
}

subtest 'Object field selection' => sub {
    expect_passes_rule('FieldsOnCorrectType', '
      fragment objectFieldSelection on Dog {
        __typename
        name
      }
    ');
};

subtest 'Aliased object field selection' => sub {
    expect_passes_rule('FieldsOnCorrectType', '
      fragment aliasedObjectFieldSelection on Dog {
        tn : __typename
        otherName : name
      }
    ');
};

subtest 'Interface field selection' => sub {
    expect_passes_rule('FieldsOnCorrectType', '
      fragment interfaceFieldSelection on Pet {
        __typename
        name
      }
    ');
};

subtest 'Aliased interface field selection' => sub {
    expect_passes_rule('FieldsOnCorrectType', '
      fragment interfaceFieldSelection on Pet {
        otherName : name
      }
    ');
};

subtest 'Lying alias selection' => sub {
    expect_passes_rule('FieldsOnCorrectType', '
      fragment lyingAliasSelection on Dog {
        name : nickname
      }
    ');
};

subtest 'Ignores fields on unknown type' => sub {
    expect_passes_rule('FieldsOnCorrectType', '
      fragment unknownSelection on UnknownType {
        unknownField
      }
    ');
};

subtest 'reports errors when type is known again' => sub {
    expect_fails_rule('FieldsOnCorrectType', '
      fragment typeKnownAgain on Pet {
        unknown_pet_field {
          ... on Cat {
            unknown_cat_field
          }
        }
      }',
      [ undefined_field('unknown_pet_field', 'Pet', [], [], 3, 9),
        undefined_field('unknown_cat_field', 'Cat', [], [], 5, 13) ]
    );
};

subtest 'Field not defined on fragment' => sub {
    expect_fails_rule('FieldsOnCorrectType', '
      fragment fieldNotDefined on Dog {
        meowVolume
      }',
      [ undefined_field('meowVolume', 'Dog', [], [ 'barkVolume' ], 3, 9) ]
    );
};

subtest 'Ignores deeply unknown field' => sub {
    expect_fails_rule('FieldsOnCorrectType', '
      fragment deepFieldNotDefined on Dog {
        unknown_field {
          deeper_unknown_field
        }
      }',
      [ undefined_field('unknown_field', 'Dog', [], [], 3, 9) ]
    );
};

subtest 'Sub-field not defined' => sub {
    expect_fails_rule('FieldsOnCorrectType', '
      fragment subFieldNotDefined on Human {
        pets {
          unknown_field
        }
      }',
      [ undefined_field('unknown_field', 'Pet', [], [], 4, 11) ]
    );
};

subtest 'Field not defined on inline fragment' => sub {
    expect_fails_rule('FieldsOnCorrectType', '
      fragment fieldNotDefined on Pet {
        ... on Dog {
          meowVolume
        }
      }',
      [undefined_field('meowVolume', 'Dog', [], [ 'barkVolume' ], 4, 11)]
    );
};

subtest 'Aliased field target not defined' => sub {
    expect_fails_rule('FieldsOnCorrectType', '
      fragment aliasedFieldTargetNotDefined on Dog {
        volume : mooVolume
      }',
      [undefined_field('mooVolume', 'Dog', [], [ 'barkVolume' ], 3, 9)]
    );
};

subtest 'Aliased lying field target not defined' => sub {
    expect_fails_rule('FieldsOnCorrectType', '
      fragment aliasedLyingFieldTargetNotDefined on Dog {
        barkVolume : kawVolume
      }',
      [undefined_field('kawVolume', 'Dog', [], [ 'barkVolume' ], 3, 9)]
    );
};

subtest 'Not defined on interface' => sub {
    expect_fails_rule('FieldsOnCorrectType', '
      fragment notDefinedOnInterface on Pet {
        tailLength
      }',
      [ undefined_field('tailLength', 'Pet', [], [], 3, 9) ]
    );
};

subtest 'Defined on implementors but not on interface' => sub {
    expect_fails_rule('FieldsOnCorrectType', '
      fragment definedOnImplementorsButNotInterface on Pet {
        nickname
      }',
      [ undefined_field('nickname', 'Pet', [ 'Dog', 'Cat' ], [ 'name' ], 3, 9) ]
    );
};

subtest 'Meta field selection on union' => sub {
    expect_passes_rule('FieldsOnCorrectType', '
      fragment directFieldSelectionOnUnion on CatOrDog {
        __typename
      }'
    );
};

subtest 'Direct field selection on union' => sub {
    expect_fails_rule('FieldsOnCorrectType', '
      fragment directFieldSelectionOnUnion on CatOrDog {
        directField
      }',
      [ undefined_field('directField', 'CatOrDog', [], [], 3, 9) ]
    );
};

subtest 'Defined on implementors queried on union' => sub {
    expect_fails_rule('FieldsOnCorrectType', '
      fragment definedOnImplementorsQueriedOnUnion on CatOrDog {
        name
      }',
      #TODO: NOTE: ORIG [undefined_field( 'name', 'CatOrDog', ['Being', 'Pet', 'Canine', 'Dog', 'Cat'], [], 3, 9)]
      [undefined_field( 'name', 'CatOrDog', [sort ('Pet', 'Being', 'Canine', 'Dog', 'Cat')], [], 3, 9)]
    );
};

subtest 'valid field in inline fragment' => sub {
    expect_passes_rule('FieldsOnCorrectType', '
      fragment objectFieldSelection on Pet {
        ... on Dog {
          name
        }
        ... {
          name
        }
      }
    ');
};

subtest 'Fields on correct type error message' => sub {
    subtest 'Works with no suggestions' => sub {
        is GraphQL::Validator::Rule::FieldsOnCorrectType::undefined_field_message('f', 'T', [], []),
            'Cannot query field "f" on type "T".';
    };

    subtest 'Works with no small numbers of type suggestions' => sub {
        is GraphQL::Validator::Rule::FieldsOnCorrectType::undefined_field_message('f', 'T', ['A', 'B'], []),
            'Cannot query field "f" on type "T". '
            . 'Did you mean to use an inline fragment on "A" or "B"?';
    };

    subtest 'Works with no small numbers of field suggestions' => sub {
        is GraphQL::Validator::Rule::FieldsOnCorrectType::undefined_field_message('f', 'T', [], ['z', 'y']),
            'Cannot query field "f" on type "T". '
            . 'Did you mean "z" or "y"?';
    };

    subtest 'Only shows one set of suggestions at a time, preferring types' => sub {
        is GraphQL::Validator::Rule::FieldsOnCorrectType::undefined_field_message('f', 'T', ['A', 'B'], ['z', 'y']),
            'Cannot query field "f" on type "T". '
            . 'Did you mean to use an inline fragment on "A" or "B"?';
    };

    subtest 'Limits lots of type suggestions' => sub {
        is GraphQL::Validator::Rule::FieldsOnCorrectType::undefined_field_message('f', 'T', ['A', 'B', 'C', 'D', 'E', 'F'], []),
            'Cannot query field "f" on type "T". '
            . 'Did you mean to use an inline fragment on "A", "B", "C", "D", or "E"?';
    };

    subtest 'Limits lots of field suggestions' => sub {
        is GraphQL::Validator::Rule::FieldsOnCorrectType::undefined_field_message('f', 'T', [], ['z', 'y', 'x', 'w', 'v', 'u']),
            'Cannot query field "f" on type "T". '
            . 'Did you mean "z", "y", "x", "w", or "v"?';
    };
};

done_testing;
