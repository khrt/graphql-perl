package GraphQL::Validator::Rules::FragmentsOnCompositeTypes;

use strict;
use warnings;

use GraphQL::Language::Printer qw/print_doc/;
use GraphQL::Util qw/type_from_ast/;
use GraphQL::Util::Type qw/is_composite_type/;

sub inline_fragment_on_non_composite_error_message {
    my $type = shift;
    return qq`Fragment cannot condition on non composite type "${ \$type->to_string }".`;
}

sub fragment_on_non_composite_error_message {
    my ($frag_name, $type) = @_;
    return qq`Fragment "$frag_name" cannot condition on non composite `
         . qq`type "${ \$type->to_string }".`;
}

# Fragments on composite type
#
# Fragments use a type condition to determine if they apply, since fragments
# can only be spread into a composite type (object, interface, or union), the
# type condition must also be a composite type.
sub validate {
    my $context = shift;
    return {
        InlineFragment => sub {
            my $node = shift;

            if ($node->{type_condition}) {
                my $type = type_from_ast($context->get_schema, $node->{type_condition});
                if ($type && !is_composite_type($type)) {
                    $context->report_error(
                        inline_fragment_on_non_composite_error_message(
                            print_doc($node->{type_condition}),
                        ),
                        [$node->{type_condition}]
                    )
                }
            }
            # TODO return undef?
        },
        FragmentDefinition => sub {
            my $node = shift;

            my $type = type_from_ast($context->get_schema, $node->{type_condition});
            if ($type && !is_composite_type($type)) {
                $context->report_error(
                    fragment_on_non_composite_error_message(
                        $node->{name}{value},
                        print_doc($node->{type_condition})
                    ),
                    [$node->{type_condition}]
                );
            }
            # TODO return undef?
        },
    };
}

1;

__END__
