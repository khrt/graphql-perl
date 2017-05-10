package GraphQL::Validator::Rules::UniqueVariableNames;

use strict;
use warnings;

sub duplicate_variable_message {
    my $variable_name = shift;
    return `There can be only one variable named "${variable_name}".`;
}

# Unique variable names
#
# A GraphQL operation is only valid if all its variables are uniquely named.
sub validate {
    my $context = shift;
    my %known_variable_names;

    return {
        OperationDefinition => sub {
            %known_variable_names = ();
        },
        VariableDefinition => sub {
            my $node = shift;
            my $variable_name = $node->{variable}{name}{value};

            if ($known_variable_names{ $variable_name }) {
                $context->report_error(
                    duplicate_variable_message($variable_name),
                    [$known_variable_names{ $variable_name }, $node->{variable}{name}]
                );
            }
            else {
                $known_variable_names{ $variable_name } = $node->{variable}{name};
            }

            #TODO return
        },
    };
}

1;

__END__
