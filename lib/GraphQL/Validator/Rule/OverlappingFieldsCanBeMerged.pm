package GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged;

use strict;
use warnings;

use List::Util qw/all reduce/;

sub fields_conflict_message {
    my ($response_name, $reason) = @_; return qq`Fields "$response_name" conflict because ${ \reason_message($reason) }. `
         . qq`Use different aliases on the fields to fetch both if this was intentional.`;
}

sub reason_message {
    my $reason = shift;

    if (ref($reason) eq 'ARRAY') {
        return join ' and ', map {
            qq`subfields "$_->[0]" conflict because ${ \reason_message($_->[1]) }`
        } @$reason;
    }

    return $reason;
}


# Overlapping fields can be merged
#
# A selection set is only valid if all fields (including spreading any
# fragments) either correspond to distinct response names or can be merged
# without ambiguity.
sub validate {
    my ($self, $context) = @_;

    # A memoization for when two fragments are compared "between" each other for
    # conflicts. Two fragments may be compared many times, so memoizing this can
    # dramatically improve the performance of this validator.
    my %compared_fragments;

    # A cache for the "field map" and list of fragment names found in any given
    # selection set. Selection sets may be asked for this information multiple
    # times, so this improves the performance of this validator.
    my %cached_fields_and_fragment_names;

    return {
        SelectionSet => sub {
            my (undef, $selection_set) = @_;
            my $conflicts = find_conflicts_within_selection_set(
                $context,
                \%cached_fields_and_fragment_names,
                \%compared_fragments,
                $context->get_parent_type,
                $selection_set
            );

            # TODO
            for my $rec (@$conflicts) {
                my ($conflict, $fields1, $fields2) = @$rec;
                my ($response_name, $reason) = @$conflict;

                $context->report_error(
                    fields_conflict_message($response_name, $reason),
                    [$fields1, $fields2]
                );
            }

            return; # undef
        },
    };
}

# Algorithm:
#
# Conflicts occur when two fields exist in a query which will produce the same
# response name, but represent differing values, thus creating a conflict.
# The algorithm below finds all conflicts via making a series of comparisons
# between fields. In order to compare as few fields as possible, this makes
# a series of comparisons "within" sets of fields and "between" sets of fields.
#
# Given any selection set, a collection produces both a set of fields by
# also including all inline fragments, as well as a list of fragments
# referenced by fragment spreads.
#
# A) Each selection set represented in the document first compares "within" its
# collected set of fields, finding any conflicts between every pair of
# overlapping fields.
# Note: This is the *only time* that a the fields "within" a set are compared
# to each other. After this only fields "between" sets are compared.
#
# B) Also, if any fragment is referenced in a selection set, then a
# comparison is made "between" the original set of fields and the
# referenced fragment.
#
# C) Also, if multiple fragments are referenced, then comparisons
# are made "between" each referenced fragment.
#
# D) When comparing "between" a set of fields and a referenced fragment, first
# a comparison is made between each field in the original set of fields and
# each field in the the referenced set of fields.
#
# E) Also, if any fragment is referenced in the referenced selection set,
# then a comparison is made "between" the original set of fields and the
# referenced fragment (recursively referring to step D).
#
# F) When comparing "between" two fragments, first a comparison is made between
# each field in the first referenced set of fields and each field in the the
# second referenced set of fields.
#
# G) Also, any fragments referenced by the first must be compared to the
# second, and any fragments referenced by the second must be compared to the
# first (recursively referring to step F).
#
# H) When comparing two fields, if both have selection sets, then a comparison
# is made "between" both selection sets, first comparing the set of fields in
# the first selection set with the set of fields in the second.
#
# I) Also, if any fragment is referenced in either selection set, then a
# comparison is made "between" the other set of fields and the
# referenced fragment.
#
# J) Also, if two fragments are referenced in both selection sets, then a
# comparison is made "between" the two fragments.


# Find all conflicts found "within" a selection set, including those found
# via spreading in fragments. Called when visiting each SelectionSet in the
# GraphQL Document.
sub find_conflicts_within_selection_set {
    my ($context, $cached_fields_and_fragment_names,
        $compared_fragments, $parent_type, $selection_set) = @_;

    my @conflicts;

    my ($field_map, $fragment_names) = get_fields_and_fragment_names(
        $context, $cached_fields_and_fragment_names, $parent_type, $selection_set
    );

    # (A) Find find all conflicts "within" the fields of this selection set.
    # Note: this is the *only place* `collectConflictsWithin` is called.
    collect_conflicts_within(
        $context,
        \@conflicts,
        $cached_fields_and_fragment_names,
        $compared_fragments,
        $field_map
    );

    # (B) Then collect conflicts between these fields and those represented by
    # each spread fragment name found.
    for (my $i = 0; $i < scalar(@$fragment_names); $i++) {
        collect_conflicts_between_fields_and_fragment(
            $context,
            \@conflicts,
            $cached_fields_and_fragment_names,
            $compared_fragments,
            0,
            $field_map,
            $fragment_names->[$i]
        );

        # (C) Then compare this fragment with all other fragments found in this
        # selection set to collect conflicts between fragments spread together.
        # This compares each item in the list of fragment names to every other item
        # in that same list (except for itself).
        for (my $j = $i + 1; $j < scalar(@$fragment_names); $j++) {
            collect_conflicts_between_fragments(
                $context,
                \@conflicts,
                $cached_fields_and_fragment_names,
                $compared_fragments,
                0,
                $fragment_names->[$i],
                $fragment_names->[$j]
            );
        }
    }

    return \@conflicts;
}

# Collect all conflicts found between a set of fields and a fragment reference
# including via spreading in any nested fragments.
sub collect_conflicts_between_fields_and_fragment {
    my ($context, $conflicts, $cached_fields_and_fragment_names,
        $compared_fragments, $are_mutually_exclusive, $field_map,
        $fragment_name) = @_;

    my $fragment = $context->get_fragment($fragment_name);
    return unless !$fragment;

    my ($field_map2, $fragment_names2) = get_referenced_fields_and_fragment_names(
        $context,
        $cached_fields_and_fragment_names,
        $fragment
    );


    # (D) First collect any conflicts between the provided collection of fields
    # and the collection of fields represented by the given fragment.
    collect_conflicts_between(
        $context,
        $conflicts,
        $cached_fields_and_fragment_names,
        $compared_fragments,
        $are_mutually_exclusive,
        $field_map,
        $field_map2
    );

    # (E) Then collect any conflicts between the provided collection of fields
    # and any fragment names found in the given fragment.
    for (my $i = 0; $i < scalar(@$fragment_names2); $i++) {
        collect_conflicts_between_fields_and_fragment(
            $context,
            $conflicts,
            $cached_fields_and_fragment_names,
            $compared_fragments,
            $are_mutually_exclusive,
            $field_map,
            $fragment_names2->[$i]
        );
    }

    return;
}

# Find all conflicts found between two selection sets, including those found
# via spreading in fragments. Called when determining if conflicts exist
# between the sub-fields of two overlapping fields.
sub find_conflicts_between_subselection_sets {
    my ($context, $cached_fields_and_fragment_names,
        $compared_fragments, $are_mutually_exclusive,
        $parent_type1, $selection_set1,
        $parent_type2, $selection_set2) = @_;

    my @conflicts;

    my ($field_map1, $fragment_names1) = get_fields_and_fragment_names(
        $context,
        $cached_fields_and_fragment_names,
        $parent_type1,
        $selection_set1
    );
    my ($field_map2, $fragment_names2) = get_fields_and_fragment_names(
        $context,
        $cached_fields_and_fragment_names,
        $parent_type2,
        $selection_set2
    );

    # (H) First, collect all conflicts between these two collections of field.
    collect_conflicts_between(
        $context,
        \@conflicts,
        $cached_fields_and_fragment_names,
        $compared_fragments,
        $are_mutually_exclusive,
        $field_map1,
        $field_map2
    );

    # (I) Then collect conflicts between the first collection of fields and
    # those referenced by each fragment name associated with the second.
    for (my $j = 0; $j < scalar(@$fragment_names2); $j++) {
        collect_conflicts_between_fields_and_fragment(
            $context,
            \@conflicts,
            $cached_fields_and_fragment_names,
            $compared_fragments,
            $are_mutually_exclusive,
            $field_map1,
            $fragment_names2->[$j]
        );
    }

    # (I) Then collect conflicts between the second collection of fields and
    # those referenced by each fragment name associated with the first.
    for (my $i = 0; $i < scalar(@$fragment_names1); $i++) {
        collect_conflicts_between_fields_and_fragment(
            $context,
            \@conflicts,
            $cached_fields_and_fragment_names,
            $compared_fragments,
            $are_mutually_exclusive,
            $field_map2,
            $fragment_names1->[$i]
        );
    }

    # (J) Also collect conflicts between any fragment names by the first and
    # fragment names by the second. This compares each item in the first set of
    # names to each item in the second set of names.
    for (my $i = 0; $i < scalar(@$fragment_names1); $i++) {
        for (my $j = 0; $j < scalar(@$fragment_names2); $j++) {
            collect_conflicts_between_fragments(
                $context,
                \@conflicts,
                $cached_fields_and_fragment_names,
                $compared_fragments,
                $are_mutually_exclusive,
                $fragment_names1->[$i],
                $fragment_names2->[$j]
            );
        }
    }

    return \@conflicts;
}

# Collect all Conflicts "within" one collection of fields.
sub collect_conflicts_within {
    my ($context, $conflicts, $cached_fields_and_fragment_names,
        $compared_fragments, $field_map) = @_;

    # A field map is a keyed collection, where each key represents a response
    # name and the value at that key is a list of all fields which provide that
    # response name. For every response name, if there are multiple fields, they
    # must be compared to find a potential conflict.
    for my $response_name (keys %$field_map) {
        my $fields = $field_map->{ $response_name };

        # This compares every field in the list to every other field in this list
        # (except to itself). If the list only has one item, nothing needs to
        # be compared.
        if (scalar(@$fields) > 1) {
            for (my $i = 0; $i < scalar(@$fields); $i++) {
                for (my $j = 0; $j < scalar(@$fields); $j++) {
                    my $conflict = find_conflict(
                        $context,
                        $cached_fields_and_fragment_names,
                        $compared_fragments,
                        0, # within one collection is never mutually exclusive
                        $response_name,
                        $fields->[$i],
                        $fields->[$j]
                    );

                    push @$conflicts, $conflict if $conflict;
                }
            }
        }
    }

    return;
}

# Collect all Conflicts between two collections of fields. This is similar to,
# but different from the `collectConflictsWithin` sub above. This check
# assumes that `collectConflictsWithin` has already been called on each
# provided collection of fields. This is true because this validator traverses
# each individual selection set.
sub collect_conflicts_between {
    my ($context, $conflicts, $cached_fields_and_fragment_names, $compared_fragments,
        $parent_fields_are_mutually_exclusive, $field_map1, $field_map2) = @_;

    # A field map is a keyed collection, where each key represents a response
    # name and the value at that key is a list of all fields which provide that
    # response name. For any response name which appears in both provided field
    # maps, each field from the first field map must be compared to every field
    # in the second field map to find potential conflicts.
    for my $response_name (keys %$field_map1) {
        my $fields2 = $field_map2->{ $response_name };
        if ($fields2) {
            my $fields1 = $field_map1->{ $response_name };
            for (my $i = 0; $i < $fields1.length; $i++) {
                for (my $j = 0; $j < $fields2.length; $j++) {
                    my $conflict = find_conflict(
                        $context,
                        $cached_fields_and_fragment_names,
                        $compared_fragments,
                        $parent_fields_are_mutually_exclusive,
                        $response_name,
                        $fields1->[$i],
                        $fields2->[$j]
                    );
                    push @$conflicts, $conflict if $conflict;
                }
            }
        }
    };

    return;
}

# Determines if there is a conflict between two particular fields, including
# comparing their sub-fields.
sub find_conflict {
    my ($context, $cached_fields_and_fragment_names,
        $compared_fragments, $parent_fields_are_mutually_exclusive,
        $response_name, $field1, $field2) = @_;

    my ($parent_type1, $node1, $def1) = @$field1;
    my ($parent_type2, $node2, $def2) = @$field2;

    # If it is known that two fields could not possibly apply at the same
    # time, due to the parent types, then it is safe to permit them to diverge
    # in aliased field or arguments used as they will not present any ambiguity
    # by differing.
    # It is known that two parent types could never overlap if they are
    # different Object types. Interface or Union types might overlap - if not
    # in the current state of the schema, then perhaps in some future version,
    # thus may not safely diverge.
    my $are_mutually_exclusive = $parent_fields_are_mutually_exclusive
        || $parent_type1 != $parent_type2
        && $parent_type1->isa('GraphQL::Type::Object')
        && $parent_type2->isa('GraphQL::Type::Object');

    # The return type for each field.
    my $type1 = $def1 && $def1->{type};
    my $type2 = $def2 && $def2->{type};

    if (!$are_mutually_exclusive) {
        # Two aliases must refer to the same field.
        my $name1 = $node1->{name}{value};
        my $name2 = $node2->{name}{value};
        if ($name1 ne $name2) {
            return [
                [$response_name, "$name1 and $name2 are different fields"],
                [$node1],
                [$node1]
            ];
        }

        # Two field calls must have the same arguments.
        if (!same_arguments($node1->{arguments} || [], $node2->{arguments} || [])) {
            return [
                [$response_name, 'they have differing arguments'],
                [$node1],
                [$node2]
            ];
        }
    }

    if ($type1 && $type2 && do_types_conflict($type1, $type2)) {
        return [
            [$response_name, "they return conflicting types ${ \$type1->to_string } and ${ \$type2->to_string }"],
            [$node1],
            [$node2]
        ];
    }

    # Collect and compare sub-fields. Use the same "visited fragment names" list
    # for both collections so fields in a fragment reference are never
    # compared to themselves.
    my $selection_set1 = $node1->{selection_set};
    my $selection_set2 = $node2->{selection_set};
    if ($selection_set1 && $selection_set2) {
        my $conflicts = find_conflicts_between_sub_selection_sets(
            $context,
            $cached_fields_and_fragment_names,
            $compared_fragments,
            $are_mutually_exclusive,
            get_named_type($type1),
            $selection_set1,
            get_named_type($type2),
            $selection_set2
        );
        return subfield_conflicts($conflicts, $response_name, $node1, $node2);
    }

    return;
}

sub same_arguments {
    my ($arguments1, $arguments2) = @_;

    return if scalar(@$arguments1) != scalar(@$arguments2);

    return all {
        my $arg1 = $_;
        my $arg2 = find(
            $arguments2, sub { $_[0]->{name}{value} eq $arg1->{name}{value} }
        );
        $arg2 && same_value($arg1->{value}, $arg2->{value});
    } @$arguments1;
}

sub same_value {
    my ($value1, $value2) = @_;
    return (!$value1 && !$value2) || print_doc($value1) eq print_doc($value2);
}

# Two types conflict if both types could not apply to a value simultaneously.
# Composite types are ignored as their individual field types will be compared
# later recursively. However List and Non-Null types must match.
sub do_types_conflict {
    my ($type1, $type2) = @_;

    if ($type1->isa('GraphQL::Type::List')) {
        return $type2->isa('GraphQL::Type::List')
            ? do_types_conflict($type1->of_type, $type2->of_type)
            : 1;
    }

    if ($type2->isa('GraphQL::Type::List')) {
        return type1->isa('GraphQL::Type::List')
            ? do_types_conflict($type1->of_type, $type2->of_type)
            : 1;
    }

    if ($type1->isa('GraphQL::Type::NonNull')) {
        return type2->isa('GraphQL::Type::NonNull')
            ? do_types_conflict($type1->of_type, $type2->of_type)
            : 1;
    }

    if ($type2->isa('GraphQL::Type::NonNull')) {
        return type1->isa('GraphQL::Type::NonNull')
            ? do_types_conflict($type1->of_type, $type2->of_type)
            : 1;
    }

    if (is_leaf_type($type1) || is_leaf_type($type2)) {
        return $type1 != $type2;
    }

    return;
}

# Given a selection set, return the collection of fields (a mapping of response
# name to field nodes and definitions) as well as a list of fragment names
# referenced via fragment spreads.
sub get_fields_and_fragment_names {
    my ($context, $cached_fields_and_fragment_names, $parent_type, $selection_set) = @_;

    my $cached = $cached_fields_and_fragment_names->{$selection_set};
    if (!$cached) {
        my $node_and_defs = {};
        my $fragment_names = {};

        _collect_fields_and_fragment_names(
            $context,
            $parent_type,
            $selection_set,
            $node_and_defs,
            $fragment_names
        );

        $cached = [$node_and_defs, keys %$fragment_names];
        $cached_fields_and_fragment_names->{ $selection_set } = $cached;
    }

    return $cached;
}

# Given a reference to a fragment, return the represented collection of fields
# as well as a list of nested fragment names referenced via fragment spreads.
sub get_referenced_fields_and_fragment_names {
    my ($context, $cached_fields_and_fragment_names, $fragment) = @_;

  # Short-circuit building a type from the node if possible.
  my $cached = $cached_fields_and_fragment_names->{ $fragment->{selection_set} };
  if ($cached) {
    return $cached;
  }

  my $fragment_type = type_from_ast($context->get_schema, $fragment->{type_condition});
  return get_fields_and_fragment_names(
    $context,
    $cached_fields_and_fragment_names,
    $fragment_type,
    $fragment->{selection_set}
  );
}

sub _collect_fields_and_fragment_names {
    my ($context, $parent_type, $selection_set, $node_and_defs, $fragment_names) = @_;

    for (my $i = 0; $i < scalar(@{ $selection_set->{selections} }); $i++) {
        my $selection = $selection_set->{selections}[$i];

        if ($selection->{kind} eq Kind->FIELD) {
            my $field_name = $selection->{name}->{value};
            my $field_def;

            if ($parent_type->isa('GraphQL::Type::Object') || $parent_type->isa('GraphQL::Type::Interface')) {
                $field_def = $parent_type->get_fields->{ $field_name };
            }

            my $response_name = $selection->{alias} ? $selection->{alias}->{value} : $field_name;
            if (!$node_and_defs->{ $response_name }) {
                $node_and_defs->{ $response_name } = [];
            }

            push @{ $node_and_defs->{ $response_name } }, [$parent_type, $selection, $field_def];
        }
        elsif ($selection->{kind} eq Kind->FRAGMENT_SPREAD) {
            $fragment_names->{ $selection->{name}->{value} } = 1;
        }
        elsif ($selection->{kind} eq Kind->INLINE_FRAGMENT) {
            my $type_condition = $selection->{type_condition};
            my $inline_fragment_type = $type_condition
                ? type_from_ast($context->get_schema, $type_condition)
                : $parent_type;

            _collect_fields_and_fragment_names($context, $inline_fragment_type,
                $selection->{selection_set}, $node_and_defs, $fragment_names);
        }
    }

    return;
}

# Given a series of Conflicts which occurred between two sub-fields, generate
# a single Conflict.
sub subfield_conflicts {
    my ($conflicts, $response_name, $node1, $node2) = @_;

    if (scalar(@$conflicts) > 0) {
        # TODO
        die;
        # return [
        #     [$response_name, conflicts.map(([ reason ]) => reason) ],
        #     conflicts.reduce(
        #         (all_fields, [ , fields1 ]) => all_fields.concat(fields1),
        #         [ node1 ]
        #     ),
        #     conflicts.reduce(
        #         (all_fields, [ , , fields2 ]) => all_fields.concat(fields2),
        #         [ node2 ]
        #     )
        # ];
    }

    return;
}


1;

__END__
