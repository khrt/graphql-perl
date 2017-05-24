package GraphQL::Util;

use strict;
use warnings;

use DDP;

use JSON qw/encode_json/;
use List::Util qw/reduce max min/;
use Scalar::Util qw/blessed/;

use Exporter qw/import/;

our @EXPORT_OK = (qw/
    assert_valid_name
    find
    key_map

    is_invalid
    is_valid_js_value
    is_valid_literal_value

    quoted_or_list
    stringify_type
    stringify
    suggestion_list

    type_from_ast
    value_from_ast

    is_collection
/);

use GraphQL::Language::Parser;
use GraphQL::Language::Printer qw/print_doc/;

# use GraphQL::Type qw/:all/;

sub Kind { 'GraphQL::Language::Parser' }

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

sub key_map {
    my ($list, $key_fn) = @_;

    my %result;
    for my $i (@$list) {
        my $key = $key_fn->($i);
        next unless $key;
        $result{ $key } = $i;
    }

    return \%result;
}

sub is_invalid {
    my $value = shift;
    # TODO warn 'SHOULD NOT BE USED!';
    return 0;
    # return !defined($value) || $value ne $value;
}

# Given a JavaScript value and a GraphQL type, determine if the value will be
# accepted for that type. This is primarily useful for validating the
# runtime values of query variables.
sub is_valid_js_value {
    my ($value, $type) = @_;

    # A value must be provided if the type is non-null.
    if ($type->isa('GraphQL::Type::NonNull')) {
        unless($value) {
            return [qq`Expected "${ stringify_type($type) }", found null.`];
        }
        return is_valid_js_value($value, $type->of_type);
    }

    return [] unless $value;

    # List accept a non-list value as a list of one.
    if ($type->isa('GraphQL::Type::List')) {
        my $item_type = $type->of_type;
        if (is_collection($value)) {
            my @errors;
            my $index = 0;
            for my $item (@$value) {
                my $e = is_valid_js_value($item, $item_type);
                push @errors, map { qq`In element #$index: $_` } @$e;
                $index++;
            }
            return \@errors;
        }

        return is_valid_js_value($value, $item_type);
    }

    # Input objects check each defined field.
    if ($type->isa('GraphQL::Type::InputObject')) {
        if (!$value || ref($value) ne 'HASH') {
            return [qq`Expected "$type->{name}", found not an object.`];
        }

        my $fields = $type->get_fields;
        my @errors;

        # Ensure every provided field is defined.
        for my $provided_field (keys %$value) {
            unless ($fields->{ $provided_field }) {
                push @errors, qq`In field "$provided_field": Unknown field.`;
            }
        }

        # Ensure every defined field is valid.
        for my $field_name (keys %$fields) {
            my $new_errors = is_valid_js_value($value->{ $field_name }, $fields->{ $field_name }->{type});
            push @errors, map { qq`In field "$field_name": $_` } @$new_errors;
        }

        return \@errors;
    }

    die "Must be input type\n"
        if !$type->isa('GraphQL::Type::Scalar')
        && !$type->isa('GraphQL::Type::Enum');

    # Scalar/Enum input type checks to ensure the type can parse the value to
    # a non-null value.
    eval {
        my $parse_result = $type->parse_value($value);
        unless ($parse_result) {
            return [
                qq`Expected type "$type->{name}", found $value.`
            ];
        }
    };

    if (my $e = $@) {
        # TODO: e is not object
        p $e;
        return [
            qq`Expected type "$type->{name}", found $value: $e->{message}`
        ];
    };

    return [];
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

sub stringify_type {
    my $type = shift;
    my $str =
          blessed($type) && $type->can('to_string') ? $type->to_string
        : ref($type) ? ref($type)
        :              $type;
    return \$str;
}

sub stringify {
    my $value = shift;
    return ref($value) ? encode_json($value) : qq'"$value"';
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

# Produces a JavaScript value given a GraphQL Value AST.
#
# A GraphQL type must be provided, which will be used to interpret different
# GraphQL Value literals.
#
# Returns `undefined` when the value could not be validly coerced according to
# the provided type.
#
# | GraphQL Value        | JSON Value    |
# | -------------------- | ------------- |
# | Input Object         | Object        |
# | List                 | Array         |
# | Boolean              | Boolean       |
# | String               | String        |
# | Int / Float          | Number        |
# | Enum Value           | Mixed         |
# | NullValue            | null          |
sub value_from_ast {
    my ($value_node, $type, $variables) = @_;

    unless ($value_node) {
        # When there is no node, then there is also no value.
        # Importantly, this is different from returning the value null.
        return;
    }

    if ($type->isa('GraphQL::Type::NonNull')) {
        if ($value_node->{kind} eq Kind->NULL) {
            return; # Invalid: intentionally return no value.
        }

        return value_from_ast($value_node, $type->of_type, $variables);
    }

    if ($value_node->{kind} eq Kind->NULL) {
        # This is explicitly returning the value null.
        # TODO
        return JSON::null;
    }

    if ($value_node->{kind} eq Kind->VARIABLE) {
        my $variable_name = $value_node->{name}{value};
        if (!$variables || is_invalid($variables->{ $variable_name })) {
            # No valid return value.
            return;
        }

        # Note: we're not doing any checking that this variable is correct. We're
        # assuming that this query has been validated and the variable usage here
        # is of the correct type.
        return $variables->{ $variable_name };
    }

    if ($type->isa('GraphQL::Type::List')) {
        my $item_type = $type->of_type;

        if ($value_node->{kind} eq Kind->LIST) {
            my @coerced_values;
            my $item_nodes = $value_node->{values};

            for my $item_node (@$item_nodes) {
                if (is_missing_variable($item_node, $variables)) {
                    # If an array contains a missing variable, it is either
                    # coerced to null or if the item type is non-null, it
                    # considered invalid
                    if ($item_type->isa('GraphQL::Type::NonNull')) {
                        return; # Invalid: intentionally return no value.
                    }
                    push @coerced_values, undef; # null
                }
                else {
                    my $item_value = value_from_ast($item_node, $item_type, $variables);
                    if (is_invalid($item_value)) {
                        return; # Invalid: intentionally return no value.
                    }
                    push @coerced_values, $item_value;
                }
            }

            return \@coerced_values;
        }

        my $coerced_value = value_from_ast($value_node, $item_type, $variables);
        if (is_invalid($coerced_value)) {
            return; # Invalid: intentionally return no value.
        }

        return [$coerced_value];
    }

    if ($type->isa('GraphQL::Type::InputObject')) {
        if ($value_node->{kind} ne Kind->OBJECT) {
            return; # Invalid: intentionally return no value.
        }

        my %coerced_obj;
        my $fields = $type->get_fields;
        my $field_nodes = key_map(
            $value_node->{fields},
            sub { $_[0]->{name}{value} }
        );
        my @field_names = keys %$fields;

        for my $field_name (@field_names) {
            my $field = $fields->{ $field_name };
            my $field_node = $field_nodes->{ $field_name };

            if (!$field_node
                || is_missing_variable($field_node->{value}, $variables))
            {
                if (defined($field->{default_value})) {
                    $coerced_obj{ $field_name } = $field->{default_value};
                }
                elsif ($field->{type}->isa('GraphQL::Type::NonNull')) {
                    return;    # Invalid: intentionally return no value.
                }

                next;
            }

            my $field_value =
                value_from_ast($field_node->{value}, $field->{type}, $variables);
            if (is_invalid($field_value)) {
                return; # Invalid: intentionally return no value.
            }

            $coerced_obj{ $field_name } = $field_value;
        }

        return \%coerced_obj;
    }

    die "Must be input type\n"
        if !$type->isa('GraphQL::Type::Scalar')
        && !$type->isa('GraphQL::Type::Enum');

    my $parsed = $type->parse_literal($value_node);
    # TODO: Boolean
    unless (defined($parsed)) {
        # null or invalid values represent a failure to parse correctly,
        # in which case no value is returned.
        return;
    }

    return $parsed;
}

# Returns true if the provided valueNode is a variable which is not defined
# in the set of variables.
sub is_missing_variable {
    my ($value_node, $variables) = @_;
    return $value_node->{kind} eq Kind->VARIABLE &&
        (!$variables || is_invalid($variables->{ $value_node->{name}{value} }));
}

sub is_collection {
    my $obj = shift;
    return ref($obj) eq 'ARRAY' || (ref($obj) eq 'HASH' && scalar(keys %$obj) > 1);

}

1;

__END__
