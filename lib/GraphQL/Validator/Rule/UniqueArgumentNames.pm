package GraphQL::Validator::Rule::UniqueArgumentNames;

use strict;
use warnings;

sub duplicate_arg_message {
    my $arg_name = shift;
    return qq`There can be only one argument named "$arg_name".`;
}

# Unique argument names
#
# A GraphQL field or directive is only valid if all supplied arguments are
# uniquely named.
sub validate {
    my ($self, $context) = @_;
    my %known_arg_names;
    return {
        Field => sub {
            %known_arg_names = ();
            return; # void
        },
        Directive => sub {
            %known_arg_names = ();
            return; # void
        },
        Argument => sub {
            my (undef, $node) = @_;
            my $arg_name = $node->{name}{value};

            if ($known_arg_names{ $arg_name }) {
                $context->report_error(
                    duplicate_arg_message($arg_name),
                    [$known_arg_names{ $arg_name }, $node->{name}]
                );
            }
            else {
                $known_arg_names{ $arg_name } = $node->{name};
            }

            return; # false
        },
    };
}

1;

__END__
