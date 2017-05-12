package GraphQL::Validator::Rule::VariablesInAllowedPosition;

use strict;
use warnings;

use GraphQL::Error qw/GraphQLError/;
use GraphQL::Util qw/type_from_ast/;
use GraphQL::Util::Type qw/is_type_subtype_of/;

sub bad_var_pos_message {
    my ($var_name, $var_type, $expected_type) = @_;
    return qq`Variable "\$$var_name" of type "${ \$var_type->to_string }" used in `
         . qq`position expecting type "${ \$expected_type->to_string }".`;
}

# Variables passed to field arguments conform to type
sub validate {
    my ($self, $context) = @_;
    my %var_def_map;

    return {
        OperationDefinition => {
            enter => sub {
                %var_def_map = ();
                return; # void
            },
            leave => sub {
                my $operation = shift;
                my $usages = $context->get_recursive_variable_usages($operation);

                for my $usage (@$usages) {
                    my $node = $usage->{node};
                    my $type = $usage->{type};

                    my $var_name = $node->{name}{value};
                    my $var_def = $var_def_map{ $var_name };
                    if ($var_def && $type) {
                        # A var type is allowed if it is the same or more strict (e.g. is
                        # a subtype of) than the expected type. It can be more strict if
                        # the variable type is non-null when the expected type is nullable.
                        # If both are list types, the variable item type can be more strict
                        # than the expected item type (contravariant).
                        my $schema = $context->get_schema;
                        my $var_type = type_from_ast($schema, $var_def->type);
                        if ($var_type &&
                            !is_type_sub_type_of($schema, effective_type($var_type, $var_def), $type))
                        {
                            $context->report_error(
                                GraphQLError(
                                    bad_var_pos_message($var_name, $var_type, $type),
                                    [$var_def, $node]
                                )
                            );
                        }
                    }
                };

                return; # void
            }
        },
        VariableDefinition => sub {
            my $node = shift;
            $var_def_map{ $node->{variable}{name}{value} } = $node;
            return; # void
        },
    };
}

# If a variable definition has a default value, it's effectively non-null.
sub effective_type {
    my ($var_type, $var_def) = @_;
    return !$var_def->{default_value} || $var_type->isa('GraphQL::Type::NonNull')
        ? $var_type
        : GraphQLNonNull($var_type);
}

1;

__END__
