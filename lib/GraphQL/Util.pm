package GraphQL::Util;

use strict;
use warnings;

use DDP;

use Scalar::Util qw/blessed/;
use List::Util qw/reduce max min/;

use Exporter qw/import/;

our @EXPORT_OK = (qw/
    stringify_type

    assert_valid_name
    find

    quoted_or_list
    suggestion_list

    type_from_ast

    key_map

    is_valid_literal_value
/);

use GraphQL::Language::Parser;
use GraphQL::Language::Printer qw/print_doc/;

# use GraphQL::Type qw/:all/;

sub Kind { 'GraphQL::Language::Parser' }

sub stringify_type {
    my $type = shift;
    my $str =
          blessed($type) && $type->can('to_string') ? $type->to_string
        : ref($type) ? ref($type)
        :              $type;
    return \$str;
}

# Ensures consoles warnigns are only issued once.
our $has_warned_about_dunder;

sub assert_valid_name {
    my ($name, $is_introspection) = @_;

    if (!$name || ref($name)) {
        die "Must be named. Unexpected name: $name.";
    }

    if (!$is_introspection && substr($name, 0, 2) eq '__' && !$has_warned_about_dunder) {
        $has_warned_about_dunder = 1;
        warn  qq`Name "$name" must not begin with "__", which is reserved by `
            . qq`GraphQL instrospection. In a future release of graphql this will `
            . qq`become a hard error.`;
    }

    my $name_rx = qr/^[_a-zA-z][_a-zA-z0-9]*$/;
    if ($name !~ m/$name_rx/) {
        die qq`Names must match /$name_rx/ but "$name" does not.`;
    }
}

sub find {
    my ($list, $predicate) = @_;

    for my $i (@$list) {
        return $i if $predicate->($i);
    }

    return;
}

# Given [ A, B, C ] return '"A", "B", or "C"'.
sub quoted_or_list {
    my $items = shift;

    my $max_length = 5;
    my @selected = splice @$items, 0, $max_length;

    my $index = 0;
    return reduce {
        $a . (
              (scalar(@selected) > 2 ? ', ' : ' ')
            . ($index++ == scalar(@selected)-2 ? 'or ' : '')
            . $b
        )
    } map { qq`"$_"` } @selected;
}


# Given an invalid input string and a list of valid options, returns a filtered
# list of valid options sorted based on their similarity with the input.
sub suggestion_list {
    my ($input, $options) = @_;

    my %options_by_distance;
    my $o_length = scalar(@$options);
    my $input_threshold = scalar(split //, $input) / 2;

    for (my $i = 0; $i < $o_length; $i++) {
        my $distance = _lexical_distance($input, $options->[$i]);
        my $threshold = max($input_threshold, scalar(split //, $options->[$i]) / 2, 1);
        if ($distance <= $threshold) {
            $options_by_distance{ $options->[$i] } = $distance;
        }
    }

    my @res =
        sort { $options_by_distance{a} <=> $options_by_distance{b} }
        keys %options_by_distance;
    return \@res;
}

# Computes the lexical distance between strings A and B.
#
# The "distance" between two strings is given by counting the minimum number
# of edits needed to transform string A into string B. An edit can be an
# insertion, deletion, or substitution of a single character, or a swap of two
# adjacent characters.
#
# This distance can be useful for detecting typos in input or sorting
#
# @param {string} a
# @param {string} b
# @return {int} distance in number of edits
#
sub _lexical_distance {
    my ($arg1, $arg2) = @_;

    my @x = split //, $arg1;
    my @y = split //, $arg2;
    my $x_length = scalar(@x);
    my $y_length = scalar(@y);

    my @d;

    for (my $i = 0; $i <= $x_length; $i++) {
        $d[$i] = [$i];
    }

    for (my $j = 1; $j <= $y_length; $j++) {
        $d[0][$j] = $j;
    }

    for (my $i = 1; $i <= $x_length; $i++) {
        for (my $j = 1; $j <= $y_length; $j++) {
            my $cost = $x[$i - 1] eq $y[$j - 1] ? 0 : 1;

            $d[$i][$j] = min(
                $d[$i - 1][$j] + 1,
                $d[$i][$j - 1] + 1,
                $d[$i - 1][$j - 1] + $cost
            );

            if (   $i > 1
                && $j > 1
                && $x[$i - 1] eq $y[$j - 2]
                && $x[$i - 2] eq $y[$j - 1])
            {
                $d[$i][$j] = min($d[$i][$j], $d[$i - 2][$j - 2] + $cost);
            }
        }
    }

    return $d[$x_length][$y_length];
}

# Given a Schema and an AST node describing a type, return a GraphQLType
# definition which applies to that type. For example, if provided the parsed
# AST node for `[User]`, a GraphQLList instance will be returned, containing
# the type called "User" found in the schema. If a type called "User" is not
# found in the schema, then undefined will be returned.
sub type_from_ast {
    my ($schema, $type_node) = @_;
    my $inner_type;

    if ($type_node->{kind} eq Kind->LIST_TYPE) {
        $inner_type = type_from_ast($schema, $type_node->{type});
        return $inner_type && GraphQL::Type::GraphQLList($inner_type);
    }

    if ($type_node->{kind} eq Kind->NON_NULL_TYPE) {
        $inner_type = type_from_ast($schema, $type_node->{type});
        return $inner_type && GraphQL::Type::GraphQLNonNull($inner_type);
    }

    die "Must be a named type.\n" if $type_node->{kind} ne Kind->NAMED_TYPE;

    return $schema->get_type($type_node->{name}{value});
}

sub key_map {
    my ($list, $key_fn) = @_;

    my %result;
    for my $i (@$list) {
        my $key = $key_fn->($i);
        $result{ $key } = $i;
    }

    return \%result;
}

sub is_valid_literal_value {
    my ($type, $value_node) = @_;

    # A value must be provided if the type is non-null.
    if ($type->isa('GraphQL::Type::NonNull')) {
        if (!$value_node || ($value_node->{kind} eq Kind->NULL)) {
            return [qq`Expected "${ \$type->to_string}", found null.`];
        }
        return is_valid_literal_value($type->of_type, $value_node);
    }

    if (!$value_node || ($value_node->{kind} eq Kind->NULL)) {
        return [];
    }

    # This function only tests literals, and assumes variables will provide
    # values of the correct type.
    if ($value_node->{kind} eq Kind->VARIABLE) {
        return [];
    }

    # Lists accept a non-list value as a list of one.
    if ($type->isa('GraphQL::Type::List')) {
        my $item_type = $type->of_type;
        if ($value_node->{kind} eq Kind->LIST) {
            my $index = 1;
            return reduce {
                my $errors = is_valid_literal_value($item_type, $b);
                push @$a, map { "In element #$index: $_" } @$errors;
                $a;
            } [], @{ $value_node->{values} };
        }
        return is_valid_literal_value($item_type, $value_node);
    }

    # Input objects check each defined field and look for undefined fields.
    if ($type->isa('GraphQL::Type::InputObject')) {
        if ($value_node->{kind} ne Kind->OBJECT) {
            return [qq`Expected "${ \$type->name }", found not an object.`];
        }

        my $fields = $type->get_fields;
        my @errors;

        # Ensure every provided field is defined.
        my $field_nodes = $value_node->{fields};
        for my $provided_field_node (@$field_nodes) {
            if (!$fields->{ $provided_field_node->{name}{value} }) {
                push @errors,
                    qq`In field "${ \$provided_field_node->{name}{value} }": Unknown field.`;
            }
        }

        # Ensure every defined field is valid.
        my $field_node_map = key_map($field_nodes, sub { $_[0]->{name}{value} });
        for my $field_name (keys %$fields) {
            my $result = is_valid_literal_value(
                $fields->{ $field_name }{type},
                $field_node_map->{ $field_name } && $field_node_map->{ $field_name }{value}
            );
            push @errors, map { qq`In field "$field_name": $_`  } @$result;
        }

        return \@errors;
    }

    die 'Must be input type'
        if !$type->isa('GraphQL::Type::Scalar')
        && !$type->isa('GraphQL::Type::Enum');

    # Scalar/Enum input checks to ensure the type can parse the value to
    # a non-null value.
    my $parse_result = $type->parse_literal($value_node);
# print 'parse_result '; p $parse_result;
    unless (defined $parse_result) {
        return [qq`Expected type "${ \$type->name }", found ${ \print_doc($value_node) }.`];
    }

    return [];
}

1;

__END__
