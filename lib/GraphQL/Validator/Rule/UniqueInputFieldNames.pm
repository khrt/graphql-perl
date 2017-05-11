package GraphQL::Validator::Rule::UniqueInputFieldNames;

use strict;
use warnings;

sub duplicate_input_field_message {
    my $field_name = shift;
    return qq`There can be only one input field named "$field_name".`;
}

# Unique input field names
#
# A GraphQL input object value is only valid if all supplied fields are
# uniquely named.
sub validate {
    my $context = shift;

    my @known_name_stack;
    my %known_names;

    return {
        ObjectValue => {
            enter => sub {
                push @known_name_stack, %known_names;
                %known_names = ();
                return; # void
            },
            leave => sub {
                %known_names = pop @known_name_stack;
                return; # void
            }
        },
        ObjectField => sub {
            my $node = shift;
            my $field_name = $node->{name}{value};

            if ($known_names{ $field_name }) {
                $context->report_error(
                    duplicate_input_field_message($field_name),
                    [$known_names{ $field_name }, $node->{name}]
                );
            }
            else {
                $known_names{ $field_name } = $node->{name};
            }

            return; # false
        },
    };
}

1;

__END__
