package GraphQL::Language::Visitor;

use strict;
use warnings;

use feature 'say';
use Carp qw/longmess/;
use Data::Dumper;
use DDP {
    # indent => 2,
    # max_depth => 1,
    # index => 0,
    # class => { internals => 0, show_methods => 'none', },
    # caller_info => 0,
};
use Storable qw/dclone/;

use constant QUERY_DOCUMENT_KEYS => {
    Name => [],

    Document => ['definitions'],
    OperationDefinition => ['name', 'variable_definitions', 'directives', 'selection_set'],
    VariableDefinition => ['variable', 'type', 'default_value'],
    Variable => ['name'],
    SelectionSet => ['selections'],
    Field => ['alias', 'name', 'arguments', 'directives', 'selection_set'],
    Argument => ['name', 'value'],

    FragmentSpread => ['name', 'directives'],
    InlineFragment => ['type_condition', 'directives', 'selection_set'],
    FragmentDefinition => ['name', 'type_condition', 'directives', 'selection_set'],

    IntValue => [],
    FloatValue => [],
    StringValue => [],
    BooleanValue => [],
    NullValue => [],
    EnumValue => [],
    ListValue => ['values'],
    ObjectValue => ['fields'],
    ObjectField => ['name', 'value'],

    Directive => ['name', 'arguments'],

    NamedType => ['name'],
    ListType => ['type'],
    NonNullType => ['type'],

    SchemaDefinition => ['directives', 'operation_types'],
    OperationTypeDefinition => ['type'],

    ScalarTypeDefinition => ['name', 'directives'],
    ObjectTypeDefinition => ['name', 'interfaces', 'directives', 'fields'],
    FieldDefinition => ['name', 'arguments', 'type', 'directives'],
    InputValueDefinition => ['name', 'type', 'default_value', 'directives'],
    InterfaceTypeDefinition => ['name', 'directives', 'fields'],
    UnionTypeDefinition => ['name', 'directives', 'types'],
    EnumTypeDefinition => ['name', 'directives', 'values'],
    EnumValueDefinition => ['name', 'directives'],
    InputObjectTypeDefinition => ['name', 'directives', 'fields'],

    TypeExtensionDefinition => ['definition'],

    DirectiveDefinition => ['name', 'arguments', 'locations'],
};

use constant {
    BREAK => {},
    NULL  => {},
};

use Exporter qw/import/;

our @EXPORT_OK = (qw/
    QUERY_DOCUMENT_KEYS BREAK NULL
    visit visit_in_parallel visit_with_typeinfo
/);

# visit() will walk through an AST using a depth first traversal, calling
# the visitor's enter function at each node in the traversal, and calling the
# leave function after visiting that node and all of its child nodes.
#
# By returning different values from the enter and leave functions, the
# behavior of the visitor can be altered, including skipping over a sub-tree of
# the AST (by returning false), editing the AST by returning a value or null
# to remove the value, or to stop the whole traversal by returning BREAK.
#
# When using visit() to edit an AST, the original AST will not be modified, and
# a new version of the AST with the changes applied will be returned from the
# visit function.
#
#     const editedAST = visit(ast, {
#       enter(node, key, parent, path, ancestors) {
#         // @return
#         //   undefined: no action
#         //   false: skip visiting this node
#         //   visitor.BREAK: stop visiting altogether
#         //   null: delete this node
#         //   any value: replace this node with the returned value
#       },
#       leave(node, key, parent, path, ancestors) {
#         // @return
#         //   undefined: no action
#         //   false: no action
#         //   visitor.BREAK: stop visiting altogether
#         //   null: delete this node
#         //   any value: replace this node with the returned value
#       }
#     });
#
# Alternatively to providing enter() and leave() functions, a visitor can
# instead provide functions named the same as the kinds of AST nodes, or
# enter/leave visitors at a named key, leading to four permutations of
# visitor API:
#
# 1) Named visitors triggered when entering a node a specific kind.
#
#     visit(ast, {
#       Kind(node) {
#         // enter the "Kind" node
#       }
#     })
#
# 2) Named visitors that trigger upon entering and leaving a node of
#    a specific kind.
#
#     visit(ast, {
#       Kind: {
#         enter(node) {
#           // enter the "Kind" node
#         }
#         leave(node) {
#           // leave the "Kind" node
#         }
#       }
#     })
#
# 3) Generic visitors that trigger upon entering and leaving any node.
#
#     visit(ast, {
#       enter(node) {
#         // enter any node
#       },
#       leave(node) {
#         // leave any node
#       }
#     })
#
# 4) Parallel visitors for entering and leaving nodes of a specific kind.
#
#     visit(ast, {
#       enter: {
#         Kind(node) {
#           // enter the "Kind" node
#         }
#       },
#       leave: {
#         Kind(node) {
#           // leave the "Kind" node
#         }
#       }
#     })
sub visit {
    my ($root, $visitor, $key_map) = @_;
    my $visitor_keys = $key_map || QUERY_DOCUMENT_KEYS;

    my $stack;
    my $in_array = ref $root eq 'ARRAY';
    my $keys = [$root];
    my $index = -1;
    my $edits = [];
    my $parent;
    my $path = [];
    my $ancestors = [];
    my $new_root = $root;

NEXT:
    do {
        $index++;

        my $is_leaving = $index == scalar(@$keys);
        my $is_edited = $is_leaving && scalar(@$edits) != 0;

        my ($key, $node);
        if ($is_leaving) {
            $key = scalar(@$ancestors) == 0 ? undef : pop(@$path);
            $node = $parent;
            $parent = pop(@$ancestors);

            if ($is_edited) {
                $node = defined($node) ? dclone $node : undef;

                my $edit_offset = 0;
                for (my $ii = 0; $ii < scalar(@$edits); $ii++) {
                    my $edit_key = $edits->[$ii][0];
                    my $edit_value = $edits->[$ii][1];

                    if ($in_array) {
                        $edit_key -= $edit_offset;
                    }

                    # inArray && editValue === null
                    if ($in_array && !$edit_value) {
                        splice(@$node, $edit_key, 1);
                        $edit_offset++;
                    }
                    else {
                        if ($in_array) {
                            $node->[$edit_key] = $edit_value;
                        }
                        else {
                            $node->{$edit_key} = $edit_value;
                        }
                    }
                }
            }

            $index = $stack->{index};
            $keys = $stack->{keys};
            $edits = $stack->{edits};
            $in_array = $stack->{in_array};
            $stack = $stack->{prev};
        }
        else {
            $key = $parent ? ($in_array ? $index : $keys->[$index]) : undef;
            $node =
                $parent
                ? ($in_array ? $parent->[$key] : $parent->{$key})
                : $new_root;

            goto NEXT if !$node;
            push @$path, $key if $parent;
        }

        my $result;
        if (ref $node ne 'ARRAY') {
            if (!is_node($node)) {
                my $d = Data::Dumper->new([$node]);
                $d->Indent(0);
                $d->Terse(1);

                # warn longmess 'hi';

                die 'Invalid AST Node: ' . $d->Dump . "\n";
            }

            my $visit_fn = &get_visit_fn($visitor, $node->{kind}, $is_leaving);
            if ($visit_fn) {
                $result = $visit_fn->($visitor, $node, $key, $parent, $path, $ancestors);
                goto END if ref($result) && $result == BREAK;

                # TODO: Perlify all this undefined, null, true, and false

                # if (result === false)
                if (defined($result) && !$result) {
                    if (!$is_leaving) {
                        pop @$path;
                        goto NEXT;
                    }
                }
                # else if (result !== undefined)
                elsif (defined($result)) {
                    push @$edits, [$key, (ref($result) && $result == NULL) ? undef : $result];

                    if (!$is_leaving) {
                        if (is_node($result)) {
                            $node = $result;
                        }
                        else {
                            pop @$path;
                            goto NEXT;
                        }
                    }
                }
            }
        }

        if (!defined($result) && $is_edited) {
            push @$edits, [$key, $node];
        }

        if (!$is_leaving) {
            $stack = {
                in_array => $in_array,
                index => $index,
                keys => $keys,
                edits => $edits,
                prev => $stack,
            };

            $in_array = ref($node) eq 'ARRAY';
            $keys = $in_array ? $node : ($visitor_keys->{ $node->{kind} } || []);
            $index = -1;
            $edits = [];

            if ($parent) {
                push @$ancestors, $parent;
            }

            $parent = $node;
        }
    } while (defined $stack);
END:

    if (scalar @$edits != 0) {
        $new_root = $edits->[scalar(@$edits)-1][1];
    }

    return $new_root;
}

sub is_node {
    my $maybe_node = shift;
    return
           ref($maybe_node) eq 'HASH'
        && $maybe_node->{kind}
        && !ref($maybe_node->{kind});
}

# Creates a new visitor instance which delegates to many visitors to run in
# parallel. Each visitor will be visited for each node before moving on.
#
# If a prior visitor edits a node, no following visitors will see that node.
sub visit_in_parallel {
    my $visitors = shift;
    my @skipping = (undef) x scalar(@$visitors);

    return {
        enter => sub {
            my $visitor = shift;
            my ($node) = @_;

            for (my $i = 0; $i < scalar(@$visitors); $i++) {
                if (!$skipping[$i]) {
                    my $fn = get_visit_fn($visitors->[$i], $node->{kind}, undef);
                    if ($fn) {
                        my $result = $fn->($visitors->[$i], @_);
                        # if (result === false)
                        if (defined($result) && !$result) {
                            $skipping[$i] = $node;
                        }
                        elsif ($result && $result == BREAK) {
                            $skipping[$i] = BREAK;
                        }
                        # else if (result !== undefined)
                        elsif (defined($result)) {
                            return $result;
                        }
                    }
                }
            }

            return;
        },
        leave => sub {
            my $visitor = shift;
            my ($node) = @_;

            for (my $i = 0; $i < scalar(@$visitors); $i++) {
                if (!$skipping[$i]) {
                    my $fn = get_visit_fn($visitors->[$i], $node->{kind}, 1);
                    if ($fn) {
                        my $result = $fn->($visitors->[$i], @_);
                        if ($result && $result == BREAK) {
                            $skipping[$i] = BREAK;
                        }
                        elsif ($result) {
                            return $result;
                        }
                    }
                }
                elsif ($skipping[$i] == $node) {
                    $skipping[$i] = undef;
                }
            }

            return;
        },
    };
}

# Creates a new visitor instance which maintains a provided TypeInfo instance
# along with visiting visitor.
sub visit_with_typeinfo {
    my ($type_info, $visitor) = @_;
    return {
        enter => sub {
            my $v = shift;
            my ($node) = @_;

            $type_info->enter($node);

            my $fn = get_visit_fn($visitor, $node->{kind}, undef);
            return unless $fn;

            my $result = $fn->($visitor, @_);
            if (defined($result)) {
                $type_info->leave($node);

                if (is_node($result)) {
                    $type_info->enter($result);
                }

                return $result;
            }

            return;
        },
        leave => sub {
            my $v = shift;
            my ($node) = @_;

            my $fn = get_visit_fn($visitor, $node->{kind}, 1);

            my $result;
            if ($fn) {
                $result = $fn->($visitor, @_);
            }

            $type_info->leave($node);
            return $result;
        },
    };
}

# Given a visitor instance, if it is leaving or not, and a node kind, return
# the function the visitor runtime should call.
sub get_visit_fn {
    my ($visitor, $kind, $is_leaving) = @_;

    # say '>>> get visit fn';
    # p $visitor;
    # say "kind: $kind; is_leaving: ${ \($is_leaving ? 1 : 0) }";
    # say '. . .';

    my $kind_visitor = $visitor->{$kind};
    # warn 'kind_visitor '; p $kind_visitor;

    if ($kind_visitor) {
        if (!$is_leaving && ref($kind_visitor) eq 'CODE') {
            # { Kind() {} }
            return $kind_visitor;
        }
        return if ref($kind_visitor) eq 'CODE';

        my $kind_specific_visitor =
            $is_leaving ? $kind_visitor->{leave} : $kind_visitor->{enter};
        if (ref($kind_specific_visitor) eq 'CODE') {
            # { Kind: { enter() {}, leave() {} } }
            return $kind_specific_visitor;
        }
    }
    else {
        my $specific_visitor = $is_leaving ? $visitor->{leave} : $visitor->{enter};
        # warn 'specific_visitor'; p $specific_visitor;
        if ($specific_visitor) {
            if (ref($specific_visitor) eq 'CODE') {
                # { enter() {}, leave() {} }
                return $specific_visitor;
            }

            my $specific_kind_visitor = $specific_visitor->{$kind};
            if (ref($specific_kind_visitor) eq 'CODE') {
                # { enter: { Kind() {} }, leave: { Kind() {} } }
                return $specific_kind_visitor;
            }
        }
    }
}

1;

__END__
