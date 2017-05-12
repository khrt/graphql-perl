package GraphQL::Validator::Rule::NoUnusedVariables;

use strict;
use warnings;

use GraphQL::Error qw/GraphQLError/;

sub unused_variable_message {
    my ($var_name, $op_name) = @_;
    return $op_name
        ? qq`Variable "\$$var_name" is never used in operation "$op_name".`
        : qq`Variable "\$$var_name" is never used.`;
}

# No unused variables
#
# A GraphQL operation is only valid if all variables defined by an operation
# are used, either directly or within a spread fragment.
sub validate {
    my ($self, $context) = @_;
    my @variable_defs;

    return {
        OperationDefinition => {
            enter => sub {
                @variable_defs = ();
                return; # void
            },
            leave => sub {
                my (undef, $operation) = @_;


                my %variable_name_used;
                my $usages = $context->get_recursive_variable_usages($operation);
                my $op_name = $operation->{name} ? $operation->{name}{value} : undef;

                for my $u (@$usages) {
                    my $node = $u->{node};
                    $variable_name_used{ $node->{name}{value} } = 1;
                }

                for my $variable_def (@variable_defs) {
                    my $variable_name = $variable_def->{variable}{name}{value};

                    unless ($variable_name_used{ $variable_name }) {
                        $context->report_error(
                            GraphQLError(
                                unused_variable_message($variable_name, $op_name),
                                [$variable_def]
                            )
                        );
                    }
                }

                return; # void
            },
        },
        VariableDefinition => sub {
            my (undef, $def) = @_;
            push @variable_defs, $def;
            return; # void
        },
    };
}

1;

__END__
