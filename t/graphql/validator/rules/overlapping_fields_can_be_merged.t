
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../../..";
use harness qw/
    expect_passes_rule
    expect_fails_rule
/;

subtest 'unique fields' => sub {
    expect_passes_rule('OverlappingFieldsCanBeMerged', '
      fragment uniqueFields on Dog {
        name
        nickname
      }
    ');
};

subtest 'identical fields' => sub {
    expect_passes_rule('OverlappingFieldsCanBeMerged', '
      fragment mergeIdenticalFields on Dog {
        name
        name
      }
    ');
};

subtest 'identical fields with identical args' => sub {
    expect_passes_rule('OverlappingFieldsCanBeMerged', '
      fragment mergeIdenticalFieldsWithIdenticalArgs on Dog {
        doesKnowCommand(dogCommand: SIT)
        doesKnowCommand(dogCommand: SIT)
      }
    ');
};

subtest 'identical fields with identical directives' => sub {
    expect_passes_rule('OverlappingFieldsCanBeMerged', '
      fragment mergeSameFieldsWithSameDirectives on Dog {
        name @include(if: true)
        name @include(if: true)
      }
    ');
};

subtest 'different args with different aliases' => sub {
    expect_passes_rule('OverlappingFieldsCanBeMerged', '
      fragment differentArgsWithDifferentAliases on Dog {
        knowsSit: doesKnowCommand(dogCommand: SIT)
        knowsDown: doesKnowCommand(dogCommand: DOWN)
      }
    ');
};

subtest 'different directives with different aliases' => sub {
    expect_passes_rule('OverlappingFieldsCanBeMerged', '
      fragment differentDirectivesWithDifferentAliases on Dog {
        nameIfTrue: name @include(if: true)
        nameIfFalse: name @include(if: false)
      }
    ');
};

# TODO
# subtest 'different skip/include directives accepted' => sub {
#     # Note: Differing skip/include directives don't create an ambiguous return
#     # value and are acceptable in conditions where differing runtime values
#     # may have the same desired effect of including or skipping a field.
#     expect_passes_rule('OverlappingFieldsCanBeMerged', '
#       fragment differentDirectivesWithDifferentAliases on Dog {
#         name @include(if: true)
#         name @include(if: false)
#       }
#     ');
# };

# subtest 'Same aliases with different field targets' => sub {
#     expect_fails_rule('OverlappingFieldsCanBeMerged', '
#       fragment sameAliasesWithDifferentFieldTargets on Dog {
#         fido: name
#         fido: nickname
#       }
#     ', [
#       { message => GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message(
#           'fido',
#           'name and nickname are different fields'
#         ),
#         locations => [{ line => 3, column => 9 }, { line => 4, column => 9 }],
#         path => undef }
#     ]);
# };

# subtest 'Same aliases allowed on non-overlapping fields' => sub {
#     # This is valid since no object can be both a "Dog" and a "Cat", thus
#     # these fields can never overlap.
#     expect_passes_rule('OverlappingFieldsCanBeMerged', '
#       fragment sameAliasesWithDifferentFieldTargets on Pet {
#         ... on Dog {
#           name
#         }
#         ... on Cat {
#           name: nickname
#         }
#       }
#     ');
# };

# subtest 'Alias masking direct field access' => sub {
#     expect_fails_rule('OverlappingFieldsCanBeMerged', '
#       fragment aliasMaskingDirectFieldAccess on Dog {
#         name: nickname
#         name
#       }
#     ', [
#       { message => GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message(
#           'name',
#           'nickname and name are different fields'
#         ),
#         locations => [{ line => 3, column => 9 }, { line => 4, column => 9 }],
#         path => undef }
#     ]);
# };

# subtest 'different args, second adds an argument' => sub {
#     expect_fails_rule('OverlappingFieldsCanBeMerged', '
#       fragment conflictingArgs on Dog {
#         doesKnowCommand
#         doesKnowCommand(dogCommand: HEEL)
#       }
#     ', [
#       { message => GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message(
#           'doesKnowCommand',
#           'they have differing arguments'
#         ),
#         locations => [ { line => 3, column => 9 }, { line => 4, column => 9 } ],
#         path => undef }
#     ]);
# };

# subtest 'different args, second missing an argument' => sub {
#     expect_fails_rule('OverlappingFieldsCanBeMerged', '
#       fragment conflictingArgs on Dog {
#         doesKnowCommand(dogCommand: SIT)
#         doesKnowCommand
#       }
#     ', [
#       { message => GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message(
#           'doesKnowCommand',
#           'they have differing arguments'
#         ),
#         locations => [{ line => 3, column => 9 }, { line => 4, column => 9 }],
#         path => undef }
#     ]);
# };

# subtest 'conflicting args' => sub {
#     expect_fails_rule('OverlappingFieldsCanBeMerged', '
#       fragment conflictingArgs on Dog {
#         doesKnowCommand(dogCommand: SIT)
#         doesKnowCommand(dogCommand: HEEL)
#       }
#     ', [
#       { message => GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message(
#           'doesKnowCommand',
#           'they have differing arguments'
#         ),
#         locations => [{ line => 3, column => 9 }, { line => 4, column => 9 }],
#         path => undef }
#     ]);
# };

# subtest 'allows different args where no conflict is possible' => sub {
#     # This is valid since no object can be both a "Dog" and a "Cat", thus
#     # these fields can never overlap.
#     expect_passes_rule('OverlappingFieldsCanBeMerged', '
#       fragment conflictingArgs on Pet {
#         ... on Dog {
#           name(surname: true)
#         }
#         ... on Cat {
#           name
#         }
#       }
#     ');
# };

# subtest 'encounters conflict in fragments' => sub {
#     expect_fails_rule('OverlappingFieldsCanBeMerged', '
#       {
#         ...A
#         ...B
#       }
#       fragment A on Type {
#         x: a
#       }
#       fragment B on Type {
#         x: b
#       }
#     ', [
#       { message => GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message('x', 'a and b are different fields'),
#         locations => [{ line => 7, column => 9 }, { line => 10, column => 9 }],
#         path => undef }
#     ]);
# };

# subtest 'reports each conflict once' => sub {
#     expect_fails_rule('OverlappingFieldsCanBeMerged', '
#       {
#         f1 {
#           ...A
#           ...B
#         }
#         f2 {
#           ...B
#           ...A
#         }
#         f3 {
#           ...A
#           ...B
#           x: c
#         }
#       }
#       fragment A on Type {
#         x: a
#       }
#       fragment B on Type {
#         x: b
#       }
#     ', [
#       { message => GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message('x', 'a and b are different fields'),
#         locations => [{ line => 18, column => 9 }, { line => 21, column => 9 }],
#         path => undef },
#       { message => GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message('x', 'c and a are different fields'),
#         locations => [{ line => 14, column => 11 }, { line => 18, column => 9 }],
#         path => undef },
#       { message => GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message('x', 'c and b are different fields'),
#         locations => [{ line => 14, column => 11 }, { line => 21, column => 9 }],
#         path => undef }
#     ]);
# };

# subtest 'deep conflict' => sub {
#     expect_fails_rule('OverlappingFieldsCanBeMerged', '
#       {
#         field {
#           x: a
#         },
#         field {
#           x: b
#         }
#       }
#     ', [
#       { message => GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message(
#           'field', [['x', 'a and b are different fields']]
#         ),
#         locations => [
#           { line => 3, column => 9 },
#           { line => 4, column => 11 },
#           { line => 6, column => 9 },
#           { line => 7, column => 11 } ],
#         path => undef },
#     ]);
# };

# subtest 'deep conflict with multiple issues' => sub {
#     expect_fails_rule('OverlappingFieldsCanBeMerged', '
#       {
#         field {
#           x: a
#           y: c
#         },
#         field {
#           x: b
#           y: d
#         }
#       }
#     ', [
#       { message => GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message(
#           'field', [
#             ['x', 'a and b are different fields'],
#             ['y', 'c and d are different fields']
#           ]
#         ),
#         locations => [
#           { line => 3, column => 9 },
#           { line => 4, column => 11 },
#           { line => 5, column => 11 },
#           { line => 7, column => 9 },
#           { line => 8, column => 11 },
#           { line => 9, column => 11 } ],
#         path => undef },
#     ]);
# };

# subtest 'very deep conflict' => sub {
#     expect_fails_rule('OverlappingFieldsCanBeMerged', '
#       {
#         field {
#           deepField {
#             x: a
#           }
#         },
#         field {
#           deepField {
#             x: b
#           }
#         }
#       }
#     ', [
#       { message => GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message(
#           'field',
#           [['deepField', [['x', 'a and b are different fields']]]]
#         ),
#         locations => [
#           { line => 3, column => 9 },
#           { line => 4, column => 11 },
#           { line => 5, column => 13 },
#           { line => 8, column => 9 },
#           { line => 9, column => 11 },
#           { line => 10, column => 13 } ],
#         path => undef },
#     ]);
# };

# subtest 'reports deep conflict to nearest common ancestor' => sub {
#     expect_fails_rule('OverlappingFieldsCanBeMerged', '
#       {
#         field {
#           deepField {
#             x: a
#           }
#           deepField {
#             x: b
#           }
#         },
#         field {
#           deepField {
#             y
#           }
#         }
#       }
#     ', [
#       { message => GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message(
#           'deepField', [['x', 'a and b are different fields']]
#         ),
#         locations => [
#           { line => 4, column => 11 },
#           { line => 5, column => 13 },
#           { line => 7, column => 11 },
#           { line => 8, column => 13 } ],
#         path => undef },
#     ]);
# };

# subtest 'reports deep conflict to nearest common ancestor in fragments' => sub {
#     expect_fails_rule('OverlappingFieldsCanBeMerged', '
#       {
#         field {
#           ...F
#         }
#         field {
#           ...F
#         }
#       }
#       fragment F on T {
#         deepField {
#           deeperField {
#             x: a
#           }
#           deeperField {
#             x: b
#           }
#         },
#         deepField {
#           deeperField {
#             y
#           }
#         }
#       }
#     ', [
#       { message => GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message(
#           'deeperField', [['x', 'a and b are different fields']]
#         ),
#         locations => [
#           { line => 12, column => 11 },
#           { line => 13, column => 13 },
#           { line => 15, column => 11 },
#           { line => 16, column => 13 } ],
#         path => undef },
#     ]);
# };

# subtest 'reports deep conflict in nested fragments' => sub {
#     expect_fails_rule('OverlappingFieldsCanBeMerged', '
#       {
#         field {
#           ...F
#         }
#         field {
#           ...I
#         }
#       }
#       fragment F on T {
#         x: a
#         ...G
#       }
#       fragment G on T {
#         y: c
#       }
#       fragment I on T {
#         y: d
#         ...J
#       }
#       fragment J on T {
#         x: b
#       }
#     ', [
#       { message => GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message(
#           'field', [['x', 'a and b are different fields'],
#                     ['y', 'c and d are different fields']]
#         ),
#         locations => [
#           { line => 3, column => 9 },
#           { line => 11, column => 9 },
#           { line => 15, column => 9 },
#           { line => 6, column => 9 },
#           { line => 22, column => 9 },
#           { line => 18, column => 9 } ],
#         path => undef },
#     ]);
# };

# subtest 'ignores unknown fragments' => sub {
#     expect_passes_rule('OverlappingFieldsCanBeMerged', '
#     {
#       field
#       ...Unknown
#       ...Known
#     }

#     fragment Known on T {
#       field
#       ...OtherUnknown
#     }
#     ');
# };

# subtest 'return types must be unambiguous' => sub {
#     my (
#         $SomeBox,
#         $StringBox,
#         $IntBox,
#         $NonNullStringBox1,
#         $NonNullStringBox2,
#     );

#     $SomeBox = GraphQLInterfaceType(
#         name => 'SomeBox',
#         resolveType => sub { $StringBox },
#         fields => sub { {
#                 deepBox => { type => $SomeBox },
#                 unrelatedField => { type => GraphQLString }
#         } }
#     );

#     $StringBox = GraphQLObjectType(
#         name => 'StringBox',
#         interfaces => [$SomeBox],
#         fields => sub { {
#             scalar => { type => GraphQLString },
#             deepBox => { type => $StringBox },
#             unrelatedField => { type => GraphQLString },
#             listStringBox => { type => GraphQLList($StringBox) },
#             stringBox => { type => $StringBox },
#             intBox => { type => $IntBox },
#         } }
#     );

#     $IntBox = GraphQLObjectType(
#         name => 'IntBox',
#         interfaces => [$SomeBox],
#         fields => sub { {
#             scalar => { type => GraphQLInt },
#             deepBox => { type => $IntBox },
#             unrelatedField => { type => GraphQLString },
#             listStringBox => { type => GraphQLList($StringBox) },
#             stringBox => { type => $StringBox },
#             intBox => { type => $IntBox },
#         } }
#     );

#     $NonNullStringBox1 = GraphQLInterfaceType(
#         name => 'NonNullStringBox1',
#         resolveType => sub { $StringBox },
#         fields => {
#             scalar => { type => GraphQLNonNull(GraphQLString) }
#         }
#     );

#     my $NonNullStringBox1Impl = GraphQLObjectType(
#         name => 'NonNullStringBox1Impl',
#         interfaces => [$SomeBox, $NonNullStringBox1],
#         fields => {
#             scalar => { type => GraphQLNonNull(GraphQLString) },
#             unrelatedField => { type => GraphQLString },
#             deepBox => { type => $SomeBox },
#         }
#     );

#     $NonNullStringBox2 = GraphQLInterfaceType(
#         name => 'NonNullStringBox2',
#         resolveType => sub { $StringBox },
#         fields => {
#             scalar => { type => GraphQLNonNull(GraphQLString) }
#         }
#     );

#     my $NonNullStringBox2Impl = GraphQLObjectType(
#         name => 'NonNullStringBox2Impl',
#         interfaces => [$SomeBox, $NonNullStringBox2],
#         fields => {
#             scalar => { type => GraphQLNonNull(GraphQLString) },
#             unrelatedField => { type => GraphQLString },
#             deepBox => { type => $SomeBox },
#         }
#     );

#     my $Connection = GraphQLObjectType(
#         name => 'Connection',
#         fields => {
#             edges => {
#                 type => GraphQLList(GraphQLObjectType(
#                         name => 'Edge',
#                         fields => {
#                             node => {
#                                 type => GraphQLObjectType(
#                                     name => 'Node',
#                                     fields => {
#                                         id => { type => GraphQLID },
#                                         name => { type => GraphQLString }
#                                     }
#                                 )
#                             }
#                         }
#                     ))
#             }
#         }
#     );

#     my $schema = GraphQLSchema(
#         query => GraphQLObjectType(
#             name => 'QueryRoot',
#             fields => sub { {
#                 someBox => { type => $SomeBox },
#                 connection => { type => $Connection }
#             } }
#         ),
#         types => [$IntBox, $StringBox, $NonNullStringBox1Impl, $NonNullStringBox2Impl]
#     );

#     subtest 'conflicting return types which potentially overlap' => sub {
#       # This is invalid since an object could potentially be both the Object
#       # type IntBox and the interface type NonNullStringBox1. While that
#       # condition does not exist in the current schema, the schema could
#       # expand in the future to allow this. Thus it is invalid.
#       expect_fails_ruleWithSchema($schema, 'OverlappingFieldsCanBeMerged', '
#         {
#           someBox {
#             ...on IntBox {
#               scalar
#             }
#             ...on NonNullStringBox1 {
#               scalar
#             }
#           }
#         }
#       ', [
#         { message => GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message(
#             'scalar',
#             'they return conflicting types Int and String!'
#           ),
#           locations => [{ line => 5, column => 15 }, { line => 8, column => 15 }],
#           path => undef }
#       ]);
#     };

#     subtest 'compatible return shapes on different return types' => sub {
#       # In this case 'deepBox' returns 'SomeBox' in the first usage, and
#       # 'StringBox' in the second usage. These return types are not the same!
#       # however this is valid because the return *shapes* are compatible.
#       expect_passes_ruleWithSchema($schema, 'OverlappingFieldsCanBeMerged', '
#       {
#         someBox {
#           ... on SomeBox {
#             deepBox {
#               unrelatedField
#             }
#           }
#           ... on StringBox {
#             deepBox {
#               unrelatedField
#             }
#           }
#         }
#       }
#       ');
#     };

#     subtest 'disallows differing return types despite no overlap' => sub {
#       expect_fails_ruleWithSchema($schema, 'OverlappingFieldsCanBeMerged', '
#         {
#           someBox {
#             ... on IntBox {
#               scalar
#             }
#             ... on StringBox {
#               scalar
#             }
#           }
#         }
#       ', [
#         { message => GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message(
#             'scalar',
#             'they return conflicting types Int and String'
#           ),
#           locations => [{ line => 5, column => 15 }, { line => 8, column => 15 }],
#           path => undef }
#       ]);
#     };

#     subtest 'reports correctly when a non-exclusive follows an exclusive' => sub {
#       expect_fails_ruleWithSchema($schema, 'OverlappingFieldsCanBeMerged', '
#         {
#           someBox {
#             ... on IntBox {
#               deepBox {
#                 ...X
#               }
#             }
#           }
#           someBox {
#             ... on StringBox {
#               deepBox {
#                 ...Y
#               }
#             }
#           }
#           memoed: someBox {
#             ... on IntBox {
#               deepBox {
#                 ...X
#               }
#             }
#           }
#           memoed: someBox {
#             ... on StringBox {
#               deepBox {
#                 ...Y
#               }
#             }
#           }
#           other: someBox {
#             ...X
#           }
#           other: someBox {
#             ...Y
#           }
#         }
#         fragment X on SomeBox {
#           scalar
#         }
#         fragment Y on SomeBox {
#           scalar: unrelatedField
#         }
#       ', [
#         { message => GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message(
#             'other',
#             [['scalar', 'scalar and unrelatedField are different fields']]
#           ),
#           locations => [
#             { line => 31, column => 11 },
#             { line => 39, column => 11 },
#             { line => 34, column => 11 },
#             { line => 42, column => 11 },
#           ],
#           path => undef }
#       ]);
#     };

#     subtest 'disallows differing return type nullability despite no overlap' => sub {
#       expect_fails_ruleWithSchema($schema, 'OverlappingFieldsCanBeMerged', '
#         {
#           someBox {
#             ... on NonNullStringBox1 {
#               scalar
#             }
#             ... on StringBox {
#               scalar
#             }
#           }
#         }
#       ', [
#         { message => GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message(
#             'scalar',
#             'they return conflicting types String! and String'
#           ),
#           locations => [{ line => 5, column => 15 }, { line => 8, column => 15 }],
#           path => undef }
#       ]);
#     };

#     subtest 'disallows differing return type list despite no overlap' => sub {
#       expect_fails_ruleWithSchema($schema, 'OverlappingFieldsCanBeMerged', '
#         {
#           someBox {
#             ... on IntBox {
#               box: listStringBox {
#                 scalar
#               }
#             }
#             ... on StringBox {
#               box: stringBox {
#                 scalar
#               }
#             }
#           }
#         }
#       ', [
#         { message => GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message(
#             'box',
#             'they return conflicting types [StringBox] and StringBox'
#           ),
#           locations => [{ line => 5, column => 15 }, { line => 10, column => 15 }],
#           path => undef }
#       ]);

#       expect_fails_ruleWithSchema($schema, 'OverlappingFieldsCanBeMerged', '
#         {
#           someBox {
#             ... on IntBox {
#               box: stringBox {
#                 scalar
#               }
#             }
#             ... on StringBox {
#               box: listStringBox {
#                 scalar
#               }
#             }
#           }
#         }
#       ', [
#         { message => GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message(
#             'box',
#             'they return conflicting types StringBox and [StringBox]'
#           ),
#           locations => [{ line => 5, column => 15 }, { line => 10, column => 15 }],
#           path => undef }
#       ]);
#     };

#     subtest 'disallows differing subfields' => sub {
#       expect_fails_ruleWithSchema($schema, 'OverlappingFieldsCanBeMerged', '
#         {
#           someBox {
#             ... on IntBox {
#               box: stringBox {
#                 val: scalar
#                 val: unrelatedField
#               }
#             }
#             ... on StringBox {
#               box: stringBox {
#                 val: scalar
#               }
#             }
#           }
#         }
#       ', [
#         { message => GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message(
#             'val',
#             'scalar and unrelatedField are different fields'
#           ),
#           locations => [{ line => 6, column => 17 }, { line => 7, column => 17 }],
#           path => undef }
#       ]);
#     };

#     subtest 'disallows differing deep return types despite no overlap' => sub {
#       expect_fails_ruleWithSchema($schema, 'OverlappingFieldsCanBeMerged', '
#         {
#           someBox {
#             ... on IntBox {
#               box: stringBox {
#                 scalar
#               }
#             }
#             ... on StringBox {
#               box: intBox {
#                 scalar
#               }
#             }
#           }
#         }
#       ', [
#         { message => GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message(
#             'box',
#             [['scalar', 'they return conflicting types String and Int']]
#           ),
#           locations => [
#             { line => 5, column => 15 },
#             { line => 6, column => 17 },
#             { line => 10, column => 15 },
#             { line => 11, column => 17 } ],
#           path => undef }
#       ]);
#     };

#     subtest 'allows non-conflicting overlaping types' => sub {
#       expect_passes_ruleWithSchema($schema, 'OverlappingFieldsCanBeMerged', '
#         {
#           someBox {
#             ... on IntBox {
#               scalar: unrelatedField
#             }
#             ... on StringBox {
#               scalar
#             }
#           }
#         }
#       ');
#     };

#     subtest 'same wrapped scalar return types' => sub {
#       expect_passes_ruleWithSchema($schema, 'OverlappingFieldsCanBeMerged', '
#         {
#           someBox {
#             ...on NonNullStringBox1 {
#               scalar
#             }
#             ...on NonNullStringBox2 {
#               scalar
#             }
#           }
#         }
#       ');
#     };

#     subtest 'allows inline typeless fragments' => sub {
#       expect_passes_ruleWithSchema($schema, 'OverlappingFieldsCanBeMerged', '
#         {
#           a
#           ... {
#             a
#           }
#         }
#       ');
#     };

#     subtest 'compares deep types including list' => sub {
#       expect_fails_ruleWithSchema($schema, 'OverlappingFieldsCanBeMerged', '
#         {
#           connection {
#             ...edgeID
#             edges {
#               node {
#                 id: name
#               }
#             }
#           }
#         }

#         fragment edgeID on Connection {
#           edges {
#             node {
#               id
#             }
#           }
#         }
#       ', [
#         { message => GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message(
#             'edges',
#             [['node', [['id', 'name and id are different fields']]]]
#           ),
#           locations => [
#             { line => 5, column => 13 },
#             { line => 6, column => 15 },
#             { line => 7, column => 17 },
#             { line => 14, column => 11 },
#             { line => 15, column => 13 },
#             { line => 16, column => 15 },
#           ],
#           path => undef }
#       ]);
#     };

#     subtest 'ignores unknown types' => sub {
#       expect_passes_ruleWithSchema($schema, 'OverlappingFieldsCanBeMerged', '
#         {
#           someBox {
#             ...on UnknownType {
#               scalar
#             }
#             ...on NonNullStringBox2 {
#               scalar
#             }
#           }
#         }
#       ');
#     };

#     subtest 'error message contains hint for alias conflict' => sub {
#       # The error template should end with a hint for the user to try using
#       # different aliases.
#       my $error = GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged::fields_conflict_message('x', 'a and b are different fields');
#       is $error,
#         'Fields "x" conflict because a and b are different fields. Use '
#         . 'different aliases on the fields to fetch both if this was intentional.';
#     };
# };

done_testing;
