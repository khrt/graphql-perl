package GraphQL::Validator::Rule::DefaultValuesOfCorrectType;

use strict;
use warnings;

use GraphQL::Error qw/GraphQLError/;
use GraphQL::Language::Printer qw/print_doc/;
use GraphQL::Util qw/is_valid_literal_value/;

sub default_for_non_null_arg_message {
    my ($var_name, $type, $guess_type) = @_;
    return qq`Variable "\$$var_name" of type "${ \$type->to_string }" is required and `
         . qq`will not use the default value. `
         . qq`Perhaps you meant to use type "${ \$guess_type->to_string }".`;
}

sub bad_value_for_default_arg_message {
    my ($var_name, $type, $value, $verbose_errors) = @_;
    my $message = $verbose_errors ? "\n" . join("\n", @$verbose_errors) : '';
    return qq`Variable "\$$var_name" of type "${ \$type->to_string }" has invalid `
         . qq`default value $value.$message`;
}

# Variable default values of correct type
#
# A GraphQL document is only valid if all variable default values are of the
# type expected by their definition.
sub validate {
    my ($self, $context) = @_;
    return {
        VariableDefinition => sub {
            my (undef, $node) = @_;

            my $name = $node->{variable}{name}{value};
            my $default_value = $node->{default_value};
            my $type = $context->get_input_type;

            if ($type->isa('GraphQL::Type::NonNull') && $default_value) {
                $context->report_error(
                    GraphQLError(
                        default_for_non_null_arg_message($name, $type, $type->of_type),
                        [$default_value]
                    )
                );
            }

            if ($type && $default_value) {
                my $errors = is_valid_literal_value($type, $default_value);
                if ($errors && @$errors) {
                    $context->report_error(
                        GraphQLError(
                            bad_value_for_default_arg_message(
                                $name, $type, print_doc($default_value), $errors
                            ),
                            [$default_value]
                        )
                    );
                }
            }

            return; # false
        },
        SelectionSet => sub { return }, # false
        FragmentDefinition => sub { return }, # false
    };
}

1;

__END__
