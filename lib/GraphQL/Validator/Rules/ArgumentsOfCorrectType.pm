package GraphQL::Validator::Rules::ArgumentsOfCorrectType;

use strict;
use warnings;

use GraphQL::Language::Printer qw/print_doc/;

sub bad_value_message {
    my ($arg_name, $type, $value, $verbose_errors) = @_;
    my $message = $verbose_errors ? "\n" . join("\n", $verbose_errors) : '';
    return qq`Argument "$arg_name" has invalid value $value.$message`;
}

# Argument values of correct type
#
# A GraphQL document is only valid if all field argument literal values are
# of the type expected by their position.
sub arguments_of_correct_type {
    my $context = shift;
    return {
        Argument => sub {
            my $node = shift;
            my $arg_def = $context->get_argument;
            if ($arg_def) {
                my $errors =
                    is_valid_literal_value($arg_def->{type}, $node->{value});
                if ($errors && @$errors) {
                    $context->report_error(
                        bad_value_message(
                            $node->{name}{value},
                            $arg_def->{type},
                            print_doc($node->{value}),
                            $errors
                        ),
                        [$node->{value}]
                    );
                }
            }
            return; # false
        },
    };
}


1;

__END__
