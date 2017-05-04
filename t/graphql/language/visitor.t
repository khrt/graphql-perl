
use strict;
use warnings;

use feature 'say';
use FindBin '$Bin';
use DDP {
    # indent  => 2,
    # class   => { internals => 1, show_methods => 'none', },
    # filters => {
    #     'GraphQL::Language::Token' => sub { $_[0]->desc },
    # },
};
use Test::More;

use GraphQL::Language::Parser qw/parse/;
use GraphQL::Language::Visitor qw/
    visit visit_in_parallel visit_with_typeinfo
    NULL BREAK
/;

subtest 'visitor' => sub {
    subtest 'allows editing a node both on enter and on leave' => sub {
        my $ast = parse('{ a, b, c { a, b, c } }', { no_location => 1, });

        my $selection_set = {};

        my $edited_ast = visit($ast, {
            OperationDefinition => {
                enter => sub {
                    my ($self, $node) = @_;
                    my $selection_set = $node->{selection_set};
                    return {
                        %$node,
                        selection_set => {
                            kind => 'SelectionSet',
                            selections => [],
                        },
                        did_enter => 1,
                    };
                },
                leave => sub {
                    my ($self, $node) = @_;
                    return { %$node, %$selection_set, did_leave => 1, };
                },
            },
        });

        is_deeply $edited_ast, {
            %$ast,
            definitions => [
                {
                    %{ $ast->{definitions}[0] },
                    selection_set => {
                        kind => 'SelectionSet',
                        selections => [],
                    },
                    did_enter => 1,
                    did_leave => 1,
                },
           ],
        };
    };

    subtest 'allows editing the root node on enter and on leave' => sub {
       my $ast = parse('{ a, b, c { a, b, c } }', { no_location => 1 });
       my $definitions = { definitions => $ast->{definitions} };

        my $edited_ast = visit($ast, {
            Document => {
                enter => sub {
                    my ($self, $node) = @_;
                    return {
                        %$node,
                        definitions => [],
                        did_enter   => 1,
                    };
                },
                leave => sub {
                    my ($self, $node) = @_;
                    return { %$node, %$definitions, did_leave => 1, };
                },
            },
        });

        is_deeply $edited_ast, {
            %$ast,
            did_enter => 1,
            did_leave => 1,
        };
    };

    subtest 'allows for editing on enter' => sub {
        my $ast = parse('{ a, b, c { a, b, c } }', { no_location => 1 });
        my $edited_ast = visit($ast, {
            enter => sub {
                my ($self, $node) = @_;
                if ($node->{kind} eq 'Field' && $node->{name}{value} eq 'b') {
                    return NULL;
                }

                return;
            },
        });

        is_deeply $ast, parse('{ a, b, c { a, b, c } }', { no_location => 1 }), 'ast';
        is_deeply $edited_ast, parse('{ a,    c { a,    c } }', { no_location => 1 }), 'edited ast';
    };

    subtest 'allows for editing on leave' => sub {
        my $ast = parse('{ a, b, c { a, b, c } }', { no_location => 1 });
        my $edited_ast = visit($ast, {
            leave => sub {
                my ($self, $node) = @_;
                if ($node->{kind} eq 'Field' && $node->{name}{value} eq 'b') {
                    return NULL;
                }

                return;
            },
        });

        is_deeply $ast, parse('{ a, b, c { a, b, c } }', { no_location => 1 }), 'ast';
        is_deeply $edited_ast, parse('{ a,    c { a,    c } }', { no_location => 1 }), 'edited ast';
    };

    subtest 'visits edited node' => sub {
        my $added_field = {
            kind => 'Field',
            name => { kind => 'Name', value => '__typename' },
        };
        my $did_visit_added_field;

        my $ast = parse('{ a { x } }');
        visit($ast, {
            enter => sub {
                my ($self, $node) = @_;

                if ($node->{kind} eq 'Field' && $node->{name}{value} eq 'a') {
                    return {
                        kind => 'Field',
                        selection_set => [$added_field, $node->{selection_set}],
                    };
                }

                if (   $node->{kind} eq $added_field->{kind}
                    && $node->{name}{kind} eq $added_field->{name}{kind}
                    && $node->{name}{value} eq $added_field->{name}{value})
                {
                    $did_visit_added_field = 1;
                }

                return;
            }
        });

        is $did_visit_added_field, 1;
    };

    subtest 'allows skipping a sub-tree' => sub {
        my @visited;

        my $ast = parse('{ a, b { x }, c }');
        visit($ast, {
            enter => sub {
                my ($self, $node) = @_;
                push @visited, ['enter', $node->{kind}, $node->{value}];
                if ($node->{kind} eq 'Field' && $node->{name}{value} eq 'b') {
                    return NULL;
                }

                return;
            },
            leave => sub {
                my ($self, $node) = @_;
                push @visited, [ 'leave', $node->{kind}, $node->{value} ];
                return;
            },
        });

        is_deeply \@visited, [
          ['enter', 'Document', undef],
          ['enter', 'OperationDefinition', undef],
          ['enter', 'SelectionSet', undef],
          ['enter', 'Field', undef],
          ['enter', 'Name', 'a'],
          ['leave', 'Name', 'a'],
          ['leave', 'Field', undef],
          ['enter', 'Field', undef],
          ['enter', 'Field', undef],
          ['enter', 'Name', 'c'],
          ['leave', 'Name', 'c'],
          ['leave', 'Field', undef],
          ['leave', 'SelectionSet', undef],
          ['leave', 'OperationDefinition', undef],
          ['leave', 'Document', undef],
        ];
    };

    subtest 'allows early exit while visiting' => sub {
        my @visited;

        my $ast = parse('{ a, b { x }, c }');
        visit($ast, {
          enter => sub {
              my ($self, $node) = @_;
              push @visited, ['enter', $node->{kind}, $node->{value}];
              if ($node->{kind} eq 'Name' && $node->{value} eq 'x') {
                  return BREAK;
              }
              return;
          },
          leave => sub {
              my ($self, $node) = @_;
              push @visited, ['leave', $node->{kind}, $node->{value}];
              return;
          }
        });

        is_deeply \@visited, [
          ['enter', 'Document', undef],
          ['enter', 'OperationDefinition', undef],
          ['enter', 'SelectionSet', undef],
          ['enter', 'Field', undef],
          ['enter', 'Name', 'a'],
          ['leave', 'Name', 'a'],
          ['leave', 'Field', undef],
          ['enter', 'Field', undef],
          ['enter', 'Name', 'b'],
          ['leave', 'Name', 'b'],
          ['enter', 'SelectionSet', undef],
          ['enter', 'Field', undef],
          ['enter', 'Name', 'x' ]
        ];
    };

    subtest 'allows early exit while leaving' => sub {
        my @visited;

        my $ast = parse('{ a, b { x }, c }');
        visit($ast, {
            enter => sub {
                my ($self, $node) = @_;
                push @visited, ['enter', $node->{kind}, $node->{value}];
                return;
            },
            leave => sub {
                my ($self, $node) = @_;
                push @visited, ['leave', $node->{kind}, $node->{value}];
                if ($node->{kind} eq 'Name' && $node->{value} eq 'x') {
                    return BREAK;
                }
                return;
            }
        });

        is_deeply \@visited, [
            ['enter', 'Document', undef],
            ['enter', 'OperationDefinition', undef],
            ['enter', 'SelectionSet', undef],
            ['enter', 'Field', undef],
            ['enter', 'Name', 'a'],
            ['leave', 'Name', 'a'],
            ['leave', 'Field', undef],
            ['enter', 'Field', undef],
            ['enter', 'Name', 'b'],
            ['leave', 'Name', 'b'],
            ['enter', 'SelectionSet', undef],
            ['enter', 'Field', undef],
            ['enter', 'Name', 'x'],
            ['leave', 'Name', 'x']
        ];
    };

    subtest 'allows a named functions visitor API' => sub {
        my @visited;
        my $ast = parse('{ a, b { x }, c }');

        visit($ast, {
                Name => sub {
                    my ($self, $node) = @_;
                    push @visited, ['enter', $node->{kind}, $node->{value}];
                    return;
                },
                SelectionSet => {
                    enter => sub {
                        my ($self, $node) = @_;
                        push @visited, ['enter', $node->{kind}, $node->{value}];
                        return;
                    },
                    leave => sub {
                        my ($self, $node) = @_;
                        push @visited, ['leave', $node->{kind}, $node->{value}];
                        return;
                    }
                }
            });

        is_deeply \@visited, [
            ['enter', 'SelectionSet', undef],
            ['enter', 'Name', 'a'],
            ['enter', 'Name', 'b'],
            ['enter', 'SelectionSet', undef],
            ['enter', 'Name', 'x'],
            ['leave', 'SelectionSet', undef],
            ['enter', 'Name', 'c'],
            ['leave', 'SelectionSet', undef],
        ];
    };

    subtest 'visits kitchen sink' => sub {
        open my $fh, '<:encoding(UTF-8)', "$Bin/kitchen-sink.graphql" or BAIL_OUT($!);
        my $kitchen_sink = join '', <$fh>;
        close $fh;

        my $ast = eval { parse($kitchen_sink) } or die $@;
        my @visited;

        visit($ast, {
            enter => sub {
                my ($self, $node, $key, $parent) = @_;
                push @visited, ['enter', $node->{kind}, $key, ref($parent) eq 'HASH' ? $parent->{kind} : undef];
                return;
            },
            leave => sub {
                my ($self, $node, $key, $parent) = @_;
                push @visited, ['leave', $node->{kind}, $key, ref($parent) eq 'HASH' ? $parent->{kind} : undef];
                return;
            }
        });

        is_deeply \@visited, [
            ['enter', 'Document', undef, undef],
            ['enter', 'OperationDefinition', 0, undef],
            ['enter', 'Name', 'name', 'OperationDefinition'],
            ['leave', 'Name', 'name', 'OperationDefinition'],
            ['enter', 'VariableDefinition', 0, undef],
            ['enter', 'Variable', 'variable', 'VariableDefinition'],
            ['enter', 'Name', 'name', 'Variable'],
            ['leave', 'Name', 'name', 'Variable'],
            ['leave', 'Variable', 'variable', 'VariableDefinition'],
            ['enter', 'NamedType', 'type', 'VariableDefinition'],
            ['enter', 'Name', 'name', 'NamedType'],
            ['leave', 'Name', 'name', 'NamedType'],
            ['leave', 'NamedType', 'type', 'VariableDefinition'],
            ['leave', 'VariableDefinition', 0, undef],
            ['enter', 'VariableDefinition', 1, undef],
            ['enter', 'Variable', 'variable', 'VariableDefinition'],
            ['enter', 'Name', 'name', 'Variable'],
            ['leave', 'Name', 'name', 'Variable'],
            ['leave', 'Variable', 'variable', 'VariableDefinition'],
            ['enter', 'NamedType', 'type', 'VariableDefinition'],
            ['enter', 'Name', 'name', 'NamedType'],
            ['leave', 'Name', 'name', 'NamedType'],
            ['leave', 'NamedType', 'type', 'VariableDefinition'],
            ['enter', 'EnumValue', 'default_value', 'VariableDefinition'],
            ['leave', 'EnumValue', 'default_value', 'VariableDefinition'],
            ['leave', 'VariableDefinition', 1, undef],
            ['enter', 'SelectionSet', 'selection_set', 'OperationDefinition'],
            ['enter', 'Field', 0, undef],
            ['enter', 'Name', 'alias', 'Field'],
            ['leave', 'Name', 'alias', 'Field'],
            ['enter', 'Name', 'name', 'Field'],
            ['leave', 'Name', 'name', 'Field'],
            ['enter', 'Argument', 0, undef],
            ['enter', 'Name', 'name', 'Argument'],
            ['leave', 'Name', 'name', 'Argument'],
            ['enter', 'ListValue', 'value', 'Argument'],
            ['enter', 'IntValue', 0, undef],
            ['leave', 'IntValue', 0, undef],
            ['enter', 'IntValue', 1, undef],
            ['leave', 'IntValue', 1, undef],
            ['leave', 'ListValue', 'value', 'Argument'],
            ['leave', 'Argument', 0, undef],
            ['enter', 'SelectionSet', 'selection_set', 'Field'],
            ['enter', 'Field', 0, undef],
            ['enter', 'Name', 'name', 'Field'],
            ['leave', 'Name', 'name', 'Field'],
            ['leave', 'Field', 0, undef],
            ['enter', 'InlineFragment', 1, undef],
            ['enter', 'NamedType', 'type_condition', 'InlineFragment'],
            ['enter', 'Name', 'name', 'NamedType'],
            ['leave', 'Name', 'name', 'NamedType'],
            ['leave', 'NamedType', 'type_condition', 'InlineFragment'],
            ['enter', 'Directive', 0, undef],
            ['enter', 'Name', 'name', 'Directive'],
            ['leave', 'Name', 'name', 'Directive'],
            ['leave', 'Directive', 0, undef],
            ['enter', 'SelectionSet', 'selection_set', 'InlineFragment'],
            ['enter', 'Field', 0, undef],
            ['enter', 'Name', 'name', 'Field'],
            ['leave', 'Name', 'name', 'Field'],
            ['enter', 'SelectionSet', 'selection_set', 'Field'],
            ['enter', 'Field', 0, undef],
            ['enter', 'Name', 'name', 'Field'],
            ['leave', 'Name', 'name', 'Field'],
            ['leave', 'Field', 0, undef],
            ['enter', 'Field', 1, undef],
            ['enter', 'Name', 'alias', 'Field'],
            ['leave', 'Name', 'alias', 'Field'],
            ['enter', 'Name', 'name', 'Field'],
            ['leave', 'Name', 'name', 'Field'],
            ['enter', 'Argument', 0, undef],
            ['enter', 'Name', 'name', 'Argument'],
            ['leave', 'Name', 'name', 'Argument'],
            ['enter', 'IntValue', 'value', 'Argument'],
            ['leave', 'IntValue', 'value', 'Argument'],
            ['leave', 'Argument', 0, undef],
            ['enter', 'Argument', 1, undef],
            ['enter', 'Name', 'name', 'Argument'],
            ['leave', 'Name', 'name', 'Argument'],
            ['enter', 'Variable', 'value', 'Argument'],
            ['enter', 'Name', 'name', 'Variable'],
            ['leave', 'Name', 'name', 'Variable'],
            ['leave', 'Variable', 'value', 'Argument'],
            ['leave', 'Argument', 1, undef],
            ['enter', 'Directive', 0, undef],
            ['enter', 'Name', 'name', 'Directive'],
            ['leave', 'Name', 'name', 'Directive'],
            ['enter', 'Argument', 0, undef],
            ['enter', 'Name', 'name', 'Argument'],
            ['leave', 'Name', 'name', 'Argument'],
            ['enter', 'Variable', 'value', 'Argument'],
            ['enter', 'Name', 'name', 'Variable'],
            ['leave', 'Name', 'name', 'Variable'],
            ['leave', 'Variable', 'value', 'Argument'],
            ['leave', 'Argument', 0, undef],
            ['leave', 'Directive', 0, undef],
            ['enter', 'SelectionSet', 'selection_set', 'Field'],
            ['enter', 'Field', 0, undef],
            ['enter', 'Name', 'name', 'Field'],
            ['leave', 'Name', 'name', 'Field'],
            ['leave', 'Field', 0, undef],
            ['enter', 'FragmentSpread', 1, undef],
            ['enter', 'Name', 'name', 'FragmentSpread'],
            ['leave', 'Name', 'name', 'FragmentSpread'],
            ['leave', 'FragmentSpread', 1, undef],
            ['leave', 'SelectionSet', 'selection_set', 'Field'],
            ['leave', 'Field', 1, undef],
            ['leave', 'SelectionSet', 'selection_set', 'Field'],
            ['leave', 'Field', 0, undef],
            ['leave', 'SelectionSet', 'selection_set', 'InlineFragment'],
            ['leave', 'InlineFragment', 1, undef],
            ['enter', 'InlineFragment', 2, undef],
            ['enter', 'Directive', 0, undef],
            ['enter', 'Name', 'name', 'Directive'],
            ['leave', 'Name', 'name', 'Directive'],
            ['enter', 'Argument', 0, undef],
            ['enter', 'Name', 'name', 'Argument'],
            ['leave', 'Name', 'name', 'Argument'],
            ['enter', 'Variable', 'value', 'Argument'],
            ['enter', 'Name', 'name', 'Variable'],
            ['leave', 'Name', 'name', 'Variable'],
            ['leave', 'Variable', 'value', 'Argument'],
            ['leave', 'Argument', 0, undef],
            ['leave', 'Directive', 0, undef],
            ['enter', 'SelectionSet', 'selection_set', 'InlineFragment'],
            ['enter', 'Field', 0, undef],
            ['enter', 'Name', 'name', 'Field'],
            ['leave', 'Name', 'name', 'Field'],
            ['leave', 'Field', 0, undef],
            ['leave', 'SelectionSet', 'selection_set', 'InlineFragment'],
            ['leave', 'InlineFragment', 2, undef],
            ['enter', 'InlineFragment', 3, undef],
            ['enter', 'SelectionSet', 'selection_set', 'InlineFragment'],
            ['enter', 'Field', 0, undef],
            ['enter', 'Name', 'name', 'Field'],
            ['leave', 'Name', 'name', 'Field'],
            ['leave', 'Field', 0, undef],
            ['leave', 'SelectionSet', 'selection_set', 'InlineFragment'],
            ['leave', 'InlineFragment', 3, undef],
            ['leave', 'SelectionSet', 'selection_set', 'Field'],
            ['leave', 'Field', 0, undef],
            ['leave', 'SelectionSet', 'selection_set', 'OperationDefinition'],
            ['leave', 'OperationDefinition', 0, undef],
            ['enter', 'OperationDefinition', 1, undef],
            ['enter', 'Name', 'name', 'OperationDefinition'],
            ['leave', 'Name', 'name', 'OperationDefinition'],
            ['enter', 'SelectionSet', 'selection_set', 'OperationDefinition'],
            ['enter', 'Field', 0, undef],
            ['enter', 'Name', 'name', 'Field'],
            ['leave', 'Name', 'name', 'Field'],
            ['enter', 'Argument', 0, undef],
            ['enter', 'Name', 'name', 'Argument'],
            ['leave', 'Name', 'name', 'Argument'],
            ['enter', 'IntValue', 'value', 'Argument'],
            ['leave', 'IntValue', 'value', 'Argument'],
            ['leave', 'Argument', 0, undef],
            ['enter', 'Directive', 0, undef],
            ['enter', 'Name', 'name', 'Directive'],
            ['leave', 'Name', 'name', 'Directive'],
            ['leave', 'Directive', 0, undef],
            ['enter', 'SelectionSet', 'selection_set', 'Field'],
            ['enter', 'Field', 0, undef],
            ['enter', 'Name', 'name', 'Field'],
            ['leave', 'Name', 'name', 'Field'],
            ['enter', 'SelectionSet', 'selection_set', 'Field'],
            ['enter', 'Field', 0, undef],
            ['enter', 'Name', 'name', 'Field'],
            ['leave', 'Name', 'name', 'Field'],
            ['leave', 'Field', 0, undef],
            ['leave', 'SelectionSet', 'selection_set', 'Field'],
            ['leave', 'Field', 0, undef],
            ['leave', 'SelectionSet', 'selection_set', 'Field'],
            ['leave', 'Field', 0, undef],
            ['leave', 'SelectionSet', 'selection_set', 'OperationDefinition'],
            ['leave', 'OperationDefinition', 1, undef],
            ['enter', 'OperationDefinition', 2, undef],
            ['enter', 'Name', 'name', 'OperationDefinition'],
            ['leave', 'Name', 'name', 'OperationDefinition'],
            ['enter', 'VariableDefinition', 0, undef],
            ['enter', 'Variable', 'variable', 'VariableDefinition'],
            ['enter', 'Name', 'name', 'Variable'],
            ['leave', 'Name', 'name', 'Variable'],
            ['leave', 'Variable', 'variable', 'VariableDefinition'],
            ['enter', 'NamedType', 'type', 'VariableDefinition'],
            ['enter', 'Name', 'name', 'NamedType'],
            ['leave', 'Name', 'name', 'NamedType'],
            ['leave', 'NamedType', 'type', 'VariableDefinition'],
            ['leave', 'VariableDefinition', 0, undef],
            ['enter', 'SelectionSet', 'selection_set', 'OperationDefinition'],
            ['enter', 'Field', 0, undef],
            ['enter', 'Name', 'name', 'Field'],
            ['leave', 'Name', 'name', 'Field'],
            ['enter', 'Argument', 0, undef],
            ['enter', 'Name', 'name', 'Argument'],
            ['leave', 'Name', 'name', 'Argument'],
            ['enter', 'Variable', 'value', 'Argument'],
            ['enter', 'Name', 'name', 'Variable'],
            ['leave', 'Name', 'name', 'Variable'],
            ['leave', 'Variable', 'value', 'Argument'],
            ['leave', 'Argument', 0, undef],
            ['enter', 'SelectionSet', 'selection_set', 'Field'],
            ['enter', 'Field', 0, undef],
            ['enter', 'Name', 'name', 'Field'],
            ['leave', 'Name', 'name', 'Field'],
            ['enter', 'SelectionSet', 'selection_set', 'Field'],
            ['enter', 'Field', 0, undef],
            ['enter', 'Name', 'name', 'Field'],
            ['leave', 'Name', 'name', 'Field'],
            ['enter', 'SelectionSet', 'selection_set', 'Field'],
            ['enter', 'Field', 0, undef],
            ['enter', 'Name', 'name', 'Field'],
            ['leave', 'Name', 'name', 'Field'],
            ['leave', 'Field', 0, undef],
            ['leave', 'SelectionSet', 'selection_set', 'Field'],
            ['leave', 'Field', 0, undef],
            ['enter', 'Field', 1, undef],
            ['enter', 'Name', 'name', 'Field'],
            ['leave', 'Name', 'name', 'Field'],
            ['enter', 'SelectionSet', 'selection_set', 'Field'],
            ['enter', 'Field', 0, undef],
            ['enter', 'Name', 'name', 'Field'],
            ['leave', 'Name', 'name', 'Field'],
            ['leave', 'Field', 0, undef],
            ['leave', 'SelectionSet', 'selection_set', 'Field'],
            ['leave', 'Field', 1, undef],
            ['leave', 'SelectionSet', 'selection_set', 'Field'],
            ['leave', 'Field', 0, undef],
            ['leave', 'SelectionSet', 'selection_set', 'Field'],
            ['leave', 'Field', 0, undef],
            ['leave', 'SelectionSet', 'selection_set', 'OperationDefinition'],
            ['leave', 'OperationDefinition', 2, undef],
            ['enter', 'FragmentDefinition', 3, undef],
            ['enter', 'Name', 'name', 'FragmentDefinition'],
            ['leave', 'Name', 'name', 'FragmentDefinition'],
            ['enter', 'NamedType', 'type_condition', 'FragmentDefinition'],
            ['enter', 'Name', 'name', 'NamedType'],
            ['leave', 'Name', 'name', 'NamedType'],
            ['leave', 'NamedType', 'type_condition', 'FragmentDefinition'],
            ['enter', 'SelectionSet', 'selection_set', 'FragmentDefinition'],
            ['enter', 'Field', 0, undef],
            ['enter', 'Name', 'name', 'Field'],
            ['leave', 'Name', 'name', 'Field'],
            ['enter', 'Argument', 0, undef],
            ['enter', 'Name', 'name', 'Argument'],
            ['leave', 'Name', 'name', 'Argument'],
            ['enter', 'Variable', 'value', 'Argument'],
            ['enter', 'Name', 'name', 'Variable'],
            ['leave', 'Name', 'name', 'Variable'],
            ['leave', 'Variable', 'value', 'Argument'],
            ['leave', 'Argument', 0, undef],
            ['enter', 'Argument', 1, undef],
            ['enter', 'Name', 'name', 'Argument'],
            ['leave', 'Name', 'name', 'Argument'],
            ['enter', 'Variable', 'value', 'Argument'],
            ['enter', 'Name', 'name', 'Variable'],
            ['leave', 'Name', 'name', 'Variable'],
            ['leave', 'Variable', 'value', 'Argument'],
            ['leave', 'Argument', 1, undef],
            ['enter', 'Argument', 2, undef],
            ['enter', 'Name', 'name', 'Argument'],
            ['leave', 'Name', 'name', 'Argument'],
            ['enter', 'ObjectValue', 'value', 'Argument'],
            ['enter', 'ObjectField', 0, undef],
            ['enter', 'Name', 'name', 'ObjectField'],
            ['leave', 'Name', 'name', 'ObjectField'],
            ['enter', 'StringValue', 'value', 'ObjectField'],
            ['leave', 'StringValue', 'value', 'ObjectField'],
            ['leave', 'ObjectField', 0, undef],
            ['leave', 'ObjectValue', 'value', 'Argument'],
            ['leave', 'Argument', 2, undef],
            ['leave', 'Field', 0, undef],
            ['leave', 'SelectionSet', 'selection_set', 'FragmentDefinition'],
            ['leave', 'FragmentDefinition', 3, undef],
            ['enter', 'OperationDefinition', 4, undef],
            ['enter', 'SelectionSet', 'selection_set', 'OperationDefinition'],
            ['enter', 'Field', 0, undef],
            ['enter', 'Name', 'name', 'Field'],
            ['leave', 'Name', 'name', 'Field'],
            ['enter', 'Argument', 0, undef],
            ['enter', 'Name', 'name', 'Argument'],
            ['leave', 'Name', 'name', 'Argument'],
            ['enter', 'BooleanValue', 'value', 'Argument'],
            ['leave', 'BooleanValue', 'value', 'Argument'],
            ['leave', 'Argument', 0, undef],
            ['enter', 'Argument', 1, undef],
            ['enter', 'Name', 'name', 'Argument'],
            ['leave', 'Name', 'name', 'Argument'],
            ['enter', 'BooleanValue', 'value', 'Argument'],
            ['leave', 'BooleanValue', 'value', 'Argument'],
            ['leave', 'Argument', 1, undef],
            ['enter', 'Argument', 2, undef],
            ['enter', 'Name', 'name', 'Argument'],
            ['leave', 'Name', 'name', 'Argument'],
            ['enter', 'NullValue', 'value', 'Argument'],
            ['leave', 'NullValue', 'value', 'Argument'],
            ['leave', 'Argument', 2, undef],
            ['leave', 'Field', 0, undef],
            ['enter', 'Field', 1, undef],
            ['enter', 'Name', 'name', 'Field'],
            ['leave', 'Name', 'name', 'Field'],
            ['leave', 'Field', 1, undef],
            ['leave', 'SelectionSet', 'selection_set', 'OperationDefinition'],
            ['leave', 'OperationDefinition', 4, undef],
            ['leave', 'Document', undef, undef]
        ];
    };
};

subtest 'visit_in_parallel' => sub {
    # Note: nearly identical to the above test of the same test but
    # using visit_in_parallel.
    subtest 'allows skipping a sub-tree' => sub {
        my @visited;
        my $ast = parse('{ a, b { x }, c }');

        visit($ast, visit_in_parallel([{
            enter => sub {
                my ($self, $node) = @_;
                push @visited, ['enter', $node->{kind}, $node->{value}];
                if ($node->{kind} eq 'Field' && $node->{name}{value} eq 'b') {
                    return 0;
                }
                return;
            },
            leave => sub {
                my ($self, $node) = @_;
                push @visited, ['leave', $node->{kind}, $node->{value}];
                return;
            }
        }]));

        is_deeply \@visited, [
            ['enter', 'Document', undef],
            ['enter', 'OperationDefinition', undef],
            ['enter', 'SelectionSet', undef],
            ['enter', 'Field', undef],
            ['enter', 'Name', 'a'],
            ['leave', 'Name', 'a'],
            ['leave', 'Field', undef],
            ['enter', 'Field', undef],
            ['enter', 'Field', undef],
            ['enter', 'Name', 'c'],
            ['leave', 'Name', 'c'],
            ['leave', 'Field', undef],
            ['leave', 'SelectionSet', undef],
            ['leave', 'OperationDefinition', undef],
            ['leave', 'Document', undef],
        ];
    };

    subtest 'allows skipping different sub-trees' => sub {
        my @visited;
        my $ast = parse('{ a { x }, b { y } }');

        visit($ast, visit_in_parallel([
            {
                enter => sub {
                    my ($self, $node) = @_;
                    push @visited, ['no-a', 'enter', $node->{kind}, $node->{value}];
                    if ($node->{kind} eq 'Field' && $node->{name}{value} eq 'a') {
                        return 0;
                    }
                    return;
                },
                leave => sub {
                    my ($self, $node) = @_;
                    push @visited, ['no-a', 'leave', $node->{kind}, $node->{value}];
                    return;
                },
            },
            {
                enter => sub {
                    my ($self, $node) = @_;
                    push @visited, ['no-b', 'enter', $node->{kind}, $node->{value}];
                    if ($node->{kind} eq 'Field' && $node->{name}{value} eq 'b') {
                        return 0;
                    }
                    return;
                },
                leave => sub {
                    my ($self, $node) = @_;
                    push @visited, ['no-b', 'leave', $node->{kind}, $node->{value}];
                    return;
                },
            },
        ]));

        is_deeply \@visited, [
            ['no-a', 'enter', 'Document', undef],
            ['no-b', 'enter', 'Document', undef],
            ['no-a', 'enter', 'OperationDefinition', undef],
            ['no-b', 'enter', 'OperationDefinition', undef],
            ['no-a', 'enter', 'SelectionSet', undef],
            ['no-b', 'enter', 'SelectionSet', undef],
            ['no-a', 'enter', 'Field', undef],
            ['no-b', 'enter', 'Field', undef],
            ['no-b', 'enter', 'Name', 'a'],
            ['no-b', 'leave', 'Name', 'a'],
            ['no-b', 'enter', 'SelectionSet', undef],
            ['no-b', 'enter', 'Field', undef],
            ['no-b', 'enter', 'Name', 'x'],
            ['no-b', 'leave', 'Name', 'x'],
            ['no-b', 'leave', 'Field', undef],
            ['no-b', 'leave', 'SelectionSet', undef],
            ['no-b', 'leave', 'Field', undef],
            ['no-a', 'enter', 'Field', undef],
            ['no-b', 'enter', 'Field', undef],
            ['no-a', 'enter', 'Name', 'b'],
            ['no-a', 'leave', 'Name', 'b'],
            ['no-a', 'enter', 'SelectionSet', undef],
            ['no-a', 'enter', 'Field', undef],
            ['no-a', 'enter', 'Name', 'y'],
            ['no-a', 'leave', 'Name', 'y'],
            ['no-a', 'leave', 'Field', undef],
            ['no-a', 'leave', 'SelectionSet', undef],
            ['no-a', 'leave', 'Field', undef],
            ['no-a', 'leave', 'SelectionSet', undef],
            ['no-b', 'leave', 'SelectionSet', undef],
            ['no-a', 'leave', 'OperationDefinition', undef],
            ['no-b', 'leave', 'OperationDefinition', undef],
            ['no-a', 'leave', 'Document', undef],
            ['no-b', 'leave', 'Document', undef],
        ];
    };

    # Note: nearly identical to the above test of the same test but
    # using visit_in_parallel.
    subtest 'allows early exit while visiting' => sub {
        my @visited;
        my $ast = parse('{ a, b { x }, c }');

        visit($ast, visit_in_parallel([{
            enter => sub {
                my ($self, $node) = @_;
                push @visited, ['enter', $node->{kind}, $node->{value}];
                if ($node->{kind} eq 'Name' && $node->{value} eq 'x') {
                    return BREAK;
                }
                return;
            },
            leave => sub {
                my ($self, $node) = @_;
                push @visited, ['leave', $node->{kind}, $node->{value}];
                return;
            }
        }]));

        is_deeply \@visited, [
            ['enter', 'Document', undef],
            ['enter', 'OperationDefinition', undef],
            ['enter', 'SelectionSet', undef],
            ['enter', 'Field', undef],
            ['enter', 'Name', 'a'],
            ['leave', 'Name', 'a'],
            ['leave', 'Field', undef],
            ['enter', 'Field', undef],
            ['enter', 'Name', 'b'],
            ['leave', 'Name', 'b'],
            ['enter', 'SelectionSet', undef],
            ['enter', 'Field', undef],
            ['enter', 'Name', 'x' ]
        ];
    };

    subtest 'allows early exit from different points' => sub {
        my @visited;
        my $ast = parse('{ a { y }, b { x } }');

        visit($ast, visit_in_parallel([
            {
                enter => sub {
                    my ($self, $node) = @_;
                    push @visited, ['break-a', 'enter', $node->{kind}, $node->{value}];
                    if ($node->{kind} eq 'Name' && $node->{value} eq 'a') {
                        return BREAK;
                    }
                    return;
                },
                leave => sub {
                    my ($self, $node) = @_;
                    push @visited, ['break-a', 'leave', $node->{kind}, $node->{value}];
                    return;
                }
            },
            {
                enter => sub {
                    my ($self, $node) = @_;
                    push @visited, ['break-b', 'enter', $node->{kind}, $node->{value}];
                    if ($node->{kind} eq 'Name' && $node->{value} eq 'b') {
                        return BREAK;
                    }
                    return;
                },
                leave => sub {
                    my ($self, $node) = @_;
                    push @visited, ['break-b', 'leave', $node->{kind}, $node->{value}];
                    return;
                }
            },
        ]));

        is_deeply \@visited, [
            [ 'break-a', 'enter', 'Document', undef],
            [ 'break-b', 'enter', 'Document', undef],
            [ 'break-a', 'enter', 'OperationDefinition', undef],
            [ 'break-b', 'enter', 'OperationDefinition', undef],
            [ 'break-a', 'enter', 'SelectionSet', undef],
            [ 'break-b', 'enter', 'SelectionSet', undef],
            [ 'break-a', 'enter', 'Field', undef],
            [ 'break-b', 'enter', 'Field', undef],
            [ 'break-a', 'enter', 'Name', 'a'],
            [ 'break-b', 'enter', 'Name', 'a'],
            [ 'break-b', 'leave', 'Name', 'a'],
            [ 'break-b', 'enter', 'SelectionSet', undef],
            [ 'break-b', 'enter', 'Field', undef],
            [ 'break-b', 'enter', 'Name', 'y'],
            [ 'break-b', 'leave', 'Name', 'y'],
            [ 'break-b', 'leave', 'Field', undef],
            [ 'break-b', 'leave', 'SelectionSet', undef],
            [ 'break-b', 'leave', 'Field', undef],
            [ 'break-b', 'enter', 'Field', undef],
            [ 'break-b', 'enter', 'Name', 'b' ]
        ];
    };

    # Note: nearly identical to the above test of the same test but
    # using visit_in_parallel.
    subtest 'allows early exit while leaving' => sub {
        my @visited;
        my $ast = parse('{ a, b { x }, c }');

        visit($ast, visit_in_parallel([{
            enter => sub {
                my ($self, $node) = @_;
                push @visited, ['enter', $node->{kind}, $node->{value} ];
                return;
            },
            leave => sub {
                my ($self, $node) = @_;
                push @visited, ['leave', $node->{kind}, $node->{value} ];
                if ($node->{kind} eq 'Name' && $node->{value} eq 'x') {
                    return BREAK;
                }
                return;
            }
        }]));

        is_deeply \@visited, [
            [ 'enter', 'Document', undef],
            [ 'enter', 'OperationDefinition', undef],
            [ 'enter', 'SelectionSet', undef],
            [ 'enter', 'Field', undef],
            [ 'enter', 'Name', 'a'],
            [ 'leave', 'Name', 'a'],
            [ 'leave', 'Field', undef],
            [ 'enter', 'Field', undef],
            [ 'enter', 'Name', 'b'],
            [ 'leave', 'Name', 'b'],
            [ 'enter', 'SelectionSet', undef],
            [ 'enter', 'Field', undef],
            [ 'enter', 'Name', 'x'],
            [ 'leave', 'Name', 'x' ]
        ];
    };

    subtest 'allows early exit from leaving different points' => sub {
        my @visited;
        my $ast = parse('{ a { y }, b { x } }');

        visit($ast, visit_in_parallel([
            {
                enter => sub {
                    my ($self, $node) = @_;
                    push @visited, ['break-a', 'enter', $node->{kind}, $node->{value}];
                    return;
                },
                leave => sub {
                    my ($self, $node) = @_;
                    push @visited, ['break-a', 'leave', $node->{kind}, $node->{value}];
                    if ($node->{kind} eq 'Field' && $node->{name}{value} eq 'a') {
                        return BREAK;
                    }
                    return;
                }
            },
            {
                enter => sub {
                    my ($self, $node) = @_;
                    push @visited, ['break-b', 'enter', $node->{kind}, $node->{value}];
                    return
                },
                leave => sub {
                    my ($self, $node) = @_;
                    push @visited, ['break-b', 'leave', $node->{kind}, $node->{value}];
                    if ($node->{kind} eq 'Field' && $node->{name}{value} eq 'b') {
                        return BREAK;
                    }
                    return;
                }
            },
        ]));

        is_deeply \@visited, [
            [ 'break-a', 'enter', 'Document', undef],
            [ 'break-b', 'enter', 'Document', undef],
            [ 'break-a', 'enter', 'OperationDefinition', undef],
            [ 'break-b', 'enter', 'OperationDefinition', undef],
            [ 'break-a', 'enter', 'SelectionSet', undef],
            [ 'break-b', 'enter', 'SelectionSet', undef],
            [ 'break-a', 'enter', 'Field', undef],
            [ 'break-b', 'enter', 'Field', undef],
            [ 'break-a', 'enter', 'Name', 'a'],
            [ 'break-b', 'enter', 'Name', 'a'],
            [ 'break-a', 'leave', 'Name', 'a'],
            [ 'break-b', 'leave', 'Name', 'a'],
            [ 'break-a', 'enter', 'SelectionSet', undef],
            [ 'break-b', 'enter', 'SelectionSet', undef],
            [ 'break-a', 'enter', 'Field', undef],
            [ 'break-b', 'enter', 'Field', undef],
            [ 'break-a', 'enter', 'Name', 'y'],
            [ 'break-b', 'enter', 'Name', 'y'],
            [ 'break-a', 'leave', 'Name', 'y'],
            [ 'break-b', 'leave', 'Name', 'y'],
            [ 'break-a', 'leave', 'Field', undef],
            [ 'break-b', 'leave', 'Field', undef],
            [ 'break-a', 'leave', 'SelectionSet', undef],
            [ 'break-b', 'leave', 'SelectionSet', undef],
            [ 'break-a', 'leave', 'Field', undef],
            [ 'break-b', 'leave', 'Field', undef],
            [ 'break-b', 'enter', 'Field', undef],
            [ 'break-b', 'enter', 'Name', 'b'],
            [ 'break-b', 'leave', 'Name', 'b'],
            [ 'break-b', 'enter', 'SelectionSet', undef],
            [ 'break-b', 'enter', 'Field', undef],
            [ 'break-b', 'enter', 'Name', 'x'],
            [ 'break-b', 'leave', 'Name', 'x'],
            [ 'break-b', 'leave', 'Field', undef],
            [ 'break-b', 'leave', 'SelectionSet', undef],
            [ 'break-b', 'leave', 'Field', undef]
        ];
    };

    subtest 'allows for editing on enter' => sub {
        my @visited;
        my $ast = parse('{ a, b, c { a, b, c } }', { no_location => 1 });

        my $edited_ast = visit($ast, visit_in_parallel([
            {
                enter => sub {
                    my ($self, $node) = @_;
                    if ($node->{kind} eq 'Field' && $node->{name}{value} eq 'b') {
                        return NULL;
                    }
                    return;
                },
            },
            {
                enter => sub {
                    my ($self, $node) = @_;
                    push @visited, ['enter', $node->{kind}, $node->{value}];
                    return;
                },
                leave => sub {
                    my ($self, $node) = @_;
                    push @visited, ['leave', $node->{kind}, $node->{value}];
                    return;
                },
            },
        ]));

        is_deeply $ast,        parse('{ a, b, c { a, b, c } }', { no_location => 1 });
        is_deeply $edited_ast, parse('{ a,    c { a,    c } }', { no_location => 1 });

        is_deeply \@visited, [
            [ 'enter', 'Document', undef],
            [ 'enter', 'OperationDefinition', undef],
            [ 'enter', 'SelectionSet', undef],
            [ 'enter', 'Field', undef],
            [ 'enter', 'Name', 'a'],
            [ 'leave', 'Name', 'a'],
            [ 'leave', 'Field', undef],
            [ 'enter', 'Field', undef],
            [ 'enter', 'Name', 'c'],
            [ 'leave', 'Name', 'c'],
            [ 'enter', 'SelectionSet', undef],
            [ 'enter', 'Field', undef],
            [ 'enter', 'Name', 'a'],
            [ 'leave', 'Name', 'a'],
            [ 'leave', 'Field', undef],
            [ 'enter', 'Field', undef],
            [ 'enter', 'Name', 'c'],
            [ 'leave', 'Name', 'c'],
            [ 'leave', 'Field', undef],
            [ 'leave', 'SelectionSet', undef],
            [ 'leave', 'Field', undef],
            [ 'leave', 'SelectionSet', undef],
            [ 'leave', 'OperationDefinition', undef],
            [ 'leave', 'Document', undef]
        ];
    };

    subtest 'allows for editing on leave' => sub {
        my @visited;
        my $ast = parse('{ a, b, c { a, b, c } }', { no_location => 1 });

        my $edited_ast = visit($ast, visit_in_parallel([
            {
                leave => sub {
                    my ($self, $node) = @_;
                    if ($node->{kind} eq 'Field' && $node->{name}{value} eq 'b') {
                        return NULL;
                    }
                    return;
                }
            },
            {
                enter => sub {
                    my ($self, $node) = @_;
                    push @visited, ['enter', $node->{kind}, $node->{value}];
                    return;
                },
                leave => sub {
                    my ($self, $node) = @_;
                    push @visited, ['leave', $node->{kind}, $node->{value}];
                    return;
                }
            },
        ]));

        is_deeply $ast,        parse('{ a, b, c { a, b, c } }', { no_location => 1 });
        is_deeply $edited_ast, parse('{ a,    c { a,    c } }', { no_location => 1 });

        is_deeply \@visited, [
            [ 'enter', 'Document', undef],
            [ 'enter', 'OperationDefinition', undef],
            [ 'enter', 'SelectionSet', undef],
            [ 'enter', 'Field', undef],
            [ 'enter', 'Name', 'a'],
            [ 'leave', 'Name', 'a'],
            [ 'leave', 'Field', undef],
            [ 'enter', 'Field', undef],
            [ 'enter', 'Name', 'b'],
            [ 'leave', 'Name', 'b'],
            [ 'enter', 'Field', undef],
            [ 'enter', 'Name', 'c'],
            [ 'leave', 'Name', 'c'],
            [ 'enter', 'SelectionSet', undef],
            [ 'enter', 'Field', undef],
            [ 'enter', 'Name', 'a'],
            [ 'leave', 'Name', 'a'],
            [ 'leave', 'Field', undef],
            [ 'enter', 'Field', undef],
            [ 'enter', 'Name', 'b'],
            [ 'leave', 'Name', 'b'],
            [ 'enter', 'Field', undef],
            [ 'enter', 'Name', 'c'],
            [ 'leave', 'Name', 'c'],
            [ 'leave', 'Field', undef],
            [ 'leave', 'SelectionSet', undef],
            [ 'leave', 'Field', undef],
            [ 'leave', 'SelectionSet', undef],
            [ 'leave', 'OperationDefinition', undef],
            [ 'leave', 'Document', undef]
        ];
    };
};

subtest 'visit_with_type_info' => sub {
#    subtest 'maintains type info during visit' => sub {
#        my @visited;
#        my $type_info = new TypeInfo(testSchema);
#        my $ast = parse('{ human(id: 4) { name, pets { name }, unknown } }');

#        visit($ast, visit_with_typeinfo($type_info, {
#            enter => sub {
#                my ($self, $node) = @_;
#                my $parent_type = $type_info->get_parent_type;
#                my $type = $type_info->get_type;
#                my $input_type = $type_info->get_input_type;
#                push @visited, [
#                    'enter',
#                    $node->{kind},
#                    $node->{kind} eq 'Name' ? $node->{value} : NULL,
#                    $parent_type ? String($parent_type) : NULL,
#                    $type ? String($type) : NULL,
#                    $input_type ? String($input_type) : NULL
#                ];
#                return;
#            },
#            leave => sub {
#                my ($self, $node) = @_;
#                my $parent_type = $type_info->get_parent_type;
#                my $type = $type_info->get_type;
#                my $input_type = $type_info->get_input_type;
#                push @visited, [
#                    'leave',
#                    $node->{kind},
#                    $node->{kind} eq 'Name' ? $node->{value} : NULL,
#                    $parent_type ? String($parent_type) : NULL,
#                    $type ? String($type) : NULL,
#                    $input_type ? String($input_type) : NULL
#                ];
#                return;
#            }
#        }));

#        is_deeply \@visited, [
#            [ 'enter', 'Document', NULL, NULL, NULL, NULL],
#            [ 'enter', 'OperationDefinition', NULL, NULL, 'QueryRoot', NULL],
#            [ 'enter', 'SelectionSet', NULL, 'QueryRoot', 'QueryRoot', NULL],
#            [ 'enter', 'Field', NULL, 'QueryRoot', 'Human', NULL],
#            [ 'enter', 'Name', 'human', 'QueryRoot', 'Human', NULL],
#            [ 'leave', 'Name', 'human', 'QueryRoot', 'Human', NULL],
#            [ 'enter', 'Argument', NULL, 'QueryRoot', 'Human', 'ID'],
#            [ 'enter', 'Name', 'id', 'QueryRoot', 'Human', 'ID'],
#            [ 'leave', 'Name', 'id', 'QueryRoot', 'Human', 'ID'],
#            [ 'enter', 'IntValue', NULL, 'QueryRoot', 'Human', 'ID'],
#            [ 'leave', 'IntValue', NULL, 'QueryRoot', 'Human', 'ID'],
#            [ 'leave', 'Argument', NULL, 'QueryRoot', 'Human', 'ID'],
#            [ 'enter', 'SelectionSet', NULL, 'Human', 'Human', NULL],
#            [ 'enter', 'Field', NULL, 'Human', 'String', NULL],
#            [ 'enter', 'Name', 'name', 'Human', 'String', NULL],
#            [ 'leave', 'Name', 'name', 'Human', 'String', NULL],
#            [ 'leave', 'Field', NULL, 'Human', 'String', NULL],
#            [ 'enter', 'Field', NULL, 'Human', '[Pet]', NULL],
#            [ 'enter', 'Name', 'pets', 'Human', '[Pet]', NULL],
#            [ 'leave', 'Name', 'pets', 'Human', '[Pet]', NULL],
#            [ 'enter', 'SelectionSet', NULL, 'Pet', '[Pet]', NULL],
#            [ 'enter', 'Field', NULL, 'Pet', 'String', NULL],
#            [ 'enter', 'Name', 'name', 'Pet', 'String', NULL],
#            [ 'leave', 'Name', 'name', 'Pet', 'String', NULL],
#            [ 'leave', 'Field', NULL, 'Pet', 'String', NULL],
#            [ 'leave', 'SelectionSet', NULL, 'Pet', '[Pet]', NULL],
#            [ 'leave', 'Field', NULL, 'Human', '[Pet]', NULL],
#            [ 'enter', 'Field', NULL, 'Human', NULL, NULL],
#            [ 'enter', 'Name', 'unknown', 'Human', NULL, NULL],
#            [ 'leave', 'Name', 'unknown', 'Human', NULL, NULL],
#            [ 'leave', 'Field', NULL, 'Human', NULL, NULL],
#            [ 'leave', 'SelectionSet', NULL, 'Human', 'Human', NULL],
#            [ 'leave', 'Field', NULL, 'QueryRoot', 'Human', NULL],
#            [ 'leave', 'SelectionSet', NULL, 'QueryRoot', 'QueryRoot', NULL],
#            [ 'leave', 'OperationDefinition', NULL, NULL, 'QueryRoot', NULL],
#            [ 'leave', 'Document', NULL, NULL, NULL, NULL ]
#        ];
#    };

#    subtest 'maintains type info during edit' => sub {
#        my @visited;
#        my $type_info = new TypeInfo(testSchema);
#        my $ast = parse(
#            '{ human(id: 4) { name, pets }, alien }'
#        );
#
#        my $edited_ast = visit($ast, visit_with_typeinfo($type_info, {
#            enter => sub {
#                my ($self, $node) = @_;
#                my $parent_type = $type_info->get_parent_type;
#                my $type = $type_info->get_type;
#                my $input_type = $type_info->get_input_type;
#                push @visited, [
#                    'enter',
#                    $node->{kind},
#                    $node->{kind} eq 'Name' ? $node->{value} : NULL,
#                    $parent_type ? String($parent_type) : NULL,
#                    $type ? String($type) : NULL,
#                    $input_type ? String($input_type) : NULL
#                ];
#
#                # Make a query valid by adding missing selection sets.
#                if (   $node->{kind} eq 'Field'
#                    && !$node->{selectionSet}
#                    && isCompositeType(getNamedType($type)))
#                {
#                    return {
#                        kind => 'Field',
#                        alias => $node->{alias},
#                        name => $node->{name},
#                        arguments => $node->{arguments},
#                        directives => $node->{directives},
#                        selectionSet => {
#                            kind => 'SelectionSet',
#                            selections => [{
#                                kind => 'Field',
#                                name => { kind => 'Name', value => '__typename' },
#                            }],
#                        },
#                    };
#                }
#
#                return;
#            },
#            leave => sub {
#                my ($self, $node) = @_;
#                my $parent_type = $type_info->get_parent_type;
#                my $type = $type_info->get_type;
#                my $input_type = $type_info->get_input_type;
#                push @visited, [
#                    'leave',
#                    $node->{kind},
#                    $node->{kind} eq 'Name' ? $node->{value} : NULL,
#                    $parent_type ? String($parent_type) : NULL,
#                    $type ? String($type) : NULL,
#                    $input_type ? String($input_type) : NULL
#                ];
#                return;
#            }
#        }));
#
#        is_deeply print($ast), print(parse(
#            '{ human(id: 4) { name, pets }, alien }'
#        ));
#
#        is_deeply print($edited_ast), print(parse(
#            '{ human(id: 4) { name, pets { __typename } }, alien { __typename } }'
#        ));
#
#        is_deeply \@visited, [
#            [ 'enter', 'Document', NULL, NULL, NULL, NULL],
#            [ 'enter', 'OperationDefinition', NULL, NULL, 'QueryRoot', NULL],
#            [ 'enter', 'SelectionSet', NULL, 'QueryRoot', 'QueryRoot', NULL],
#            [ 'enter', 'Field', NULL, 'QueryRoot', 'Human', NULL],
#            [ 'enter', 'Name', 'human', 'QueryRoot', 'Human', NULL],
#            [ 'leave', 'Name', 'human', 'QueryRoot', 'Human', NULL],
#            [ 'enter', 'Argument', NULL, 'QueryRoot', 'Human', 'ID'],
#            [ 'enter', 'Name', 'id', 'QueryRoot', 'Human', 'ID'],
#            [ 'leave', 'Name', 'id', 'QueryRoot', 'Human', 'ID'],
#            [ 'enter', 'IntValue', NULL, 'QueryRoot', 'Human', 'ID'],
#            [ 'leave', 'IntValue', NULL, 'QueryRoot', 'Human', 'ID'],
#            [ 'leave', 'Argument', NULL, 'QueryRoot', 'Human', 'ID'],
#            [ 'enter', 'SelectionSet', NULL, 'Human', 'Human', NULL],
#            [ 'enter', 'Field', NULL, 'Human', 'String', NULL],
#            [ 'enter', 'Name', 'name', 'Human', 'String', NULL],
#            [ 'leave', 'Name', 'name', 'Human', 'String', NULL],
#            [ 'leave', 'Field', NULL, 'Human', 'String', NULL],
#            [ 'enter', 'Field', NULL, 'Human', '[Pet]', NULL],
#            [ 'enter', 'Name', 'pets', 'Human', '[Pet]', NULL],
#            [ 'leave', 'Name', 'pets', 'Human', '[Pet]', NULL],
#            [ 'enter', 'SelectionSet', NULL, 'Pet', '[Pet]', NULL],
#            [ 'enter', 'Field', NULL, 'Pet', 'String!', NULL],
#            [ 'enter', 'Name', '__typename', 'Pet', 'String!', NULL],
#            [ 'leave', 'Name', '__typename', 'Pet', 'String!', NULL],
#            [ 'leave', 'Field', NULL, 'Pet', 'String!', NULL],
#            [ 'leave', 'SelectionSet', NULL, 'Pet', '[Pet]', NULL],
#            [ 'leave', 'Field', NULL, 'Human', '[Pet]', NULL],
#            [ 'leave', 'SelectionSet', NULL, 'Human', 'Human', NULL],
#            [ 'leave', 'Field', NULL, 'QueryRoot', 'Human', NULL],
#            [ 'enter', 'Field', NULL, 'QueryRoot', 'Alien', NULL],
#            [ 'enter', 'Name', 'alien', 'QueryRoot', 'Alien', NULL],
#            [ 'leave', 'Name', 'alien', 'QueryRoot', 'Alien', NULL],
#            [ 'enter', 'SelectionSet', NULL, 'Alien', 'Alien', NULL],
#            [ 'enter', 'Field', NULL, 'Alien', 'String!', NULL],
#            [ 'enter', 'Name', '__typename', 'Alien', 'String!', NULL],
#            [ 'leave', 'Name', '__typename', 'Alien', 'String!', NULL],
#            [ 'leave', 'Field', NULL, 'Alien', 'String!', NULL],
#            [ 'leave', 'SelectionSet', NULL, 'Alien', 'Alien', NULL],
#            [ 'leave', 'Field', NULL, 'QueryRoot', 'Alien', NULL],
#            [ 'leave', 'SelectionSet', NULL, 'QueryRoot', 'QueryRoot', NULL],
#            [ 'leave', 'OperationDefinition', NULL, NULL, 'QueryRoot', NULL],
#            [ 'leave', 'Document', NULL, NULL, NULL, NULL ]
#        ];
#    };
};

 done_testing;
