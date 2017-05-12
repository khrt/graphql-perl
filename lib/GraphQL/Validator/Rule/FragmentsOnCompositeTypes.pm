package GraphQL::Validator::Rule::FragmentsOnCompositeTypes;

use strict;
use warnings;

use GraphQL::Error qw/GraphQLError/;
use GraphQL::Language::Printer qw/print_doc/;
use GraphQL::Util qw/
    stringify_type
    type_from_ast
/;
use GraphQL::Util::Type qw/is_composite_type/;

sub inline_fragment_on_non_composite_error_message {
    my $type = shift;
    return qq`Fragment cannot condition on non composite type "${ stringify_type($type) }".`;
}

sub fragment_on_non_composite_error_message {
    my ($frag_name, $type) = @_;
    return qq`Fragment "$frag_name" cannot condition on non composite `
         . qq`type "${ stringify_type($type) }".`;
}

# Fragments on composite type
#
# Fragments use a type condition to determine if they apply, since fragments
# can only be spread into a composite type (object, interface, or union), the
# type condition must also be a composite type.
sub validate {
    my ($self, $context) = @_;
    return {
        InlineFragment => sub {
            my (undef, $node) = @_;

            if ($node->{type_condition}) {
                my $type = type_from_ast($context->get_schema, $node->{type_condition});
                if ($type && !is_composite_type($type)) {
                    $context->report_error(
                        GraphQLError(
                            inline_fragment_on_non_composite_error_message(
                                print_doc($node->{type_condition}),
                            ),
                            [$node->{type_condition}]
                        )
                    )
                }
            }

            return; # void;
        },
        FragmentDefinition => sub {
            my (undef, $node) = @_;

            my $type = type_from_ast($context->get_schema, $node->{type_condition});
            if ($type && !is_composite_type($type)) {
                $context->report_error(
                    GraphQLError(
                        fragment_on_non_composite_error_message(
                            $node->{name}{value},
                            print_doc($node->{type_condition})
                        ),
                        [$node->{type_condition}]
                    )
                );
            }

            return; # void;
        },
    };
}

1;

__END__
