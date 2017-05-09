package GraphQL::Validator::Rules::NoUnsedVariables;

use strict;
use warnings;

sub unsed_variable_message {
    my ($var_name, $op_name) = @_;
    return $op_name
        ? qq`Variable "\$$var_name" is never used in operation "$op_name".`
        : qq`Variable "\$$var_name" is never used.`;
}

# No unused variables
#
# A GraphQL operation is only valid if all variables defined by an operation
# are used, either directly or within a spread fragment.
sub no_unsed_variables {
    my $context = shift;
    my @variables_defs;

    return {
        OperationDefinition => sub {
            enter => sub {
                @variables_defs = ();
                # TODO return;
            },
            leave => sub {
                my $operation = shift;
                my %variable_name_used;
                my $usages = $context->get_recursive_variable_usages($operation);
                my $op_name = $operation->{name} ? $operation->{name}{value} : undef;

                for my $u (@$usages) {
                    my $node = $u->{node};
                    $variable_name_used{ $node->{name}{value} } = 1;
                }

                for my $variable_def (@variables_defs) {
                    my $variable_name = $variable_def->{variable}{name}{value};

                    unless ($variable_name_used{ $variable_name }) {
                        $context->report_error(
                            unsed_variable_message($variable_name, $op_name),
                            [$variable_def]
                        );
                    }
                }

                # TODO return;
            },
        },
        VariableDefinition => sub {
            my $def = shift;
            push @variables_defs, $def;
        },
    };
}

1;

__END__
