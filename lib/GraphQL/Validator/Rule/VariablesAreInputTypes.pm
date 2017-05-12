package GraphQL::Validator::Rule::VariablesAreInputTypes;

use strict;
use warnings;

use GraphQL::Error qw/GraphQLError/;
use GraphQL::Language::Printer qw/print_doc/;
use GraphQL::Util qw/type_from_ast/;
use GraphQL::Util::Type qw/is_input_type/;

sub non_input_type_on_var_message {
    my ($variable_name, $type_name) = @_;
    return qq`Variable "\$$variable_name" cannot be non-input type "$type_name".`;
}

# Variables are input types
#
# A GraphQL operation is only valid if all the variables it defines are of
# input types (scalar, enum, or input object).
sub validate {
    my ($self, $context) = @_;
    return {
        VariableDefinition => sub {
            my (undef, $node) = @_;
            my $type = type_from_ast($context->get_schema, $node->{type});

            # If the variable type is not an input type, return an error.
            if ($type && !is_input_type($type)) {
                my $variable_name = $node->{variable}{name}{value};
                $context->report_error(
                    GraphQLError(
                        non_input_type_on_var_message($variable_name, print_doc($node->{type})),
                        [$node->{type}]
                    )
                );
            }

            return; # void
        }
    };
}

1;

__END__
