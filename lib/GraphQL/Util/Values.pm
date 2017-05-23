package GraphQL::Util::Values;

use strict;
use warnings;

use Exporter qw/import/;

our @EXPORT_OK = (qw/
    get_variable_values
    get_argument_values
/);

use Carp qw/longmess/;
use DDP;

use GraphQL::Error qw/GraphQLError/;
use GraphQL::Language::Parser;
use GraphQL::Language::Printer qw/print_doc/;
use GraphQL::Util qw/
    stringify_type
    key_map

    type_from_ast
    value_from_ast

    is_valid_literal_value

    is_invalid
    is_valid_js_value
/;
use GraphQL::Util::Type qw/
    is_input_type
/;

sub Kind { 'GraphQL::Language::Parser' }

sub get_variable_values {
    my ($schema, $var_def_nodes, $inputs) = @_;

    my %coerced_values;

    for my $var_def_node (@$var_def_nodes) {
        my $var_name = $var_def_node->{variable}{name}{value};
        my $var_type = type_from_ast($schema, $var_def_node->{type});
        if (!is_input_type($var_type)) {
            die GraphQLError(
                qq`Variable "\$$var_name" expected value of type `
              . qq`"${ \print_doc($var_def_node->{type}) }" which cannot be used as an input type.`,
                [$var_def_node->{type}]
            );
        }

        my $value = $inputs->{ $var_name };
        if (is_invalid($value)) {
            my $default_value = $var_def_node->{default_value};
            if ($default_value) {
                $coerced_values{ $var_name } = value_from_ast($default_value, $var_type);
            }

            if ($var_type->isa('GraphQL::Type::NonNull')) {
                die GraphQLError(
                    qq`Variable "\$$var_name" of required type `
                  . qq`"${ stringify_type($var_type) }" was not provided.`,
                    [$var_def_node]
                );
            }
        }
        else {
            my $errors = is_valid_js_value($value, $var_type);
            if ($errors && @$errors) {
                my $message = @$errors ? "\n" . join("\n", @$errors) : '';
                # TODO: stringify
                die GraphQLError(
                    qq`Variable "$${var_name}" got invalid value `
                  . qq`${ stringify($value) }.${message}`,
                    [$var_def_node]
                );
            }

            my $coerced_value = coerce_value($var_type, $value);
            die "Should have reported error.\n" if is_invalid($coerced_value);

            $coerced_values{ $var_name } = $coerced_value;
        }
    }
    return \%coerced_values;
}

# Prepares an object map of argument values given a list of argument
# definitions and list of argument AST nodes.
sub get_argument_values {
    my ($def, $node, $variable_values) = @_;

    # die longmess 'av';

    my $arg_defs = $def->{args};
    my $arg_nodes = $node->{arguments};

    if (!$arg_defs || !$arg_nodes) {
        return {};
    }

    my %coerced_values;
    my $arg_node_map = key_map($arg_nodes, sub { $_[0]->{name}{value} });
    # print 'an '; p $arg_nodes;
    # print 'anm '; p $arg_node_map;

    for my $arg_def (@$arg_defs) {
        my $name = $arg_def->{name};
        my $arg_type = $arg_def->{type};
        my $argument_node = $arg_node_map->{ $name };
        my $default_value = $arg_def->{default_value};

        # print 'name '; p $name;
        # print 'node '; p $argument_node;

        if (!$argument_node) {
            if (defined($default_value)) {
                $coerced_values{ $name } = $default_value;
            }
            elsif ($arg_type->isa('GraphQL::Type::NonNull')) {
                die GraphQLError(
                    qq`Argument "$name" of required type "${ stringify_type($arg_type) }" was not provided.`,
                    [$node]
                );
            }
        }
        elsif ($argument_node->{value}{kind} eq Kind->VARIABLE) {
            my $variable_name = $argument_node->{value}{name}{value};

            if ($variable_values && !is_invalid($variable_values->{ $variable_name })) {
                # Note: this does not check that this variable value is correct.
                # This assumes that this query has been validated and the variable
                # usage here is of the correct type.
                $coerced_values{ $name } = $variable_values->{ $variable_name };
            }
            elsif (!is_invalid($default_value)) {
                $coerced_values{ $name } = $default_value;
            }
            elsif ($arg_type->isa('GraphQL::Type::NonNull')) {
                die GraphQLError(
                    qq`Argument "$name" of requried type "${ stringify_type($arg_type) }" was `
                  . qq`provided the variable "\$$variable_name" which was not provided `
                  . qq`a runtime value.`,
                  [$argument_node->{value}]
                );
            }
        }
        else {
            my $value_node = $argument_node->{value};
            my $coerced_value = value_from_ast($value_node, $arg_type, $variable_values);
            # print 'coerced value '; p $coerced_value;

            if (is_invalid($coerced_value)) {
                my $errors = is_valid_literal_value($arg_type, $value_node);
                my $message = @$errors ? "\n" . join("\n", @$errors) : '';

                die GraphQLError(
                    qq`Argument "$name" got invalid value ${ \print_doc($value_node) }.$message`,
                    [$argument_node->{value}]
                );
            }

            $coerced_values{ $name } = $coerced_value;
        }
    }

    return \%coerced_values;
}

# Given a type and any value, return a runtime value coerced to match the type.
sub coerce_value {
    my ($type, $value) = @_;

    return if is_invalid($value); # Intentionally return no value

    if ($type->isa('GraphQL::Type::NonNull')) {
        return unless $value; # Intentionally return no value
        return coerce_value($type->of_type, $value);
    }

    return unless $value; # Intentionally return no value

    if ($type->isa('GraphQL::Type::List')) {
        die;
    }

    if ($type->isa('GraphQL::Type::InputObject')) {
        die;
    }

    die "Must be input type\n"
        if !$type->isa('GraphQL::Type::Scalar')
        && !$type->isa('GraphQL::Type::Enum');

    my $parsed = $type->parse_value($value);
    unless ($parsed) {
        # null or invalid values represent a failure to parse correctly,
        # in which case no value is returned.
        return;
    }

    return $parsed;
}

1;

__END__
