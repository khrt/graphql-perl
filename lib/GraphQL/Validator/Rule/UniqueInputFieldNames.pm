package GraphQL::Validator::Rule::UniqueInputFieldNames;

use strict;
use warnings;

use GraphQL::Language::Visitor qw/FALSE/;
use GraphQL::Error qw/GraphQLError/;

sub duplicate_input_field_message {
    my $field_name = shift;
    return qq`There can be only one input field named "$field_name".`;
}

# Unique input field names
#
# A GraphQL input object value is only valid if all supplied fields are
# uniquely named.
sub validate {
    my ($self, $context) = @_;

    my @known_name_stack;
    my %known_names;

    return {
        ObjectValue => {
            enter => sub {
                push @known_name_stack, \%known_names;
                %known_names = ();
                return; # void
            },
            leave => sub {
                %known_names = %{ pop @known_name_stack };
                return; # void
            }
        },
        ObjectField => sub {
            my (undef, $node) = @_;
            my $field_name = $node->{name}{value};

            if ($known_names{ $field_name }) {
                $context->report_error(
                    GraphQLError(
                        duplicate_input_field_message($field_name),
                        [$known_names{ $field_name }, $node->{name}]
                    )
                );
            }
            else {
                $known_names{ $field_name } = $node->{name};
            }

            return FALSE;
        },
    };
}

1;

__END__
