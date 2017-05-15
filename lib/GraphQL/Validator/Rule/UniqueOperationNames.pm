package GraphQL::Validator::Rule::UniqueOperationNames;

use strict;
use warnings;

use GraphQL::Error qw/GraphQLError/;
use GraphQL::Language::Visitor qw/FALSE/;

sub duplicate_operation_name_message {
    my $operation_name = shift;
    return qq`There can be only one operation named "${operation_name}".`;
}

# Unique operation names
#
# A GraphQL document is only valid if all defined operations have unique names.
sub validate {
    my ($self, $context) = @_;
    my %known_operation_names;

    return {
        OperationDefinition => sub {
            my (undef, $node) = @_;
            my $operation_name = $node->{name};

            if ($operation_name) {
                if ($known_operation_names{ $operation_name->{value} }) {
                    $context->report_error(
                        GraphQLError(
                            duplicate_operation_name_message($operation_name->{value}),
                            [$known_operation_names{ $operation_name->{value} }, $operation_name]
                        )
                    );
                }
                else {
                    $known_operation_names{ $operation_name->{value} } = $operation_name;
                }
            }

            return FALSE;
        },
        FragmentDefinition => sub { FALSE },
    };
}

1;

__END__
