package GraphQL::Validator::Rules::KnownTypeNames;

use strict;
use warnings;

use GraphQL::Util qw/quoted_or_list/;

sub unknown_type_message {
    my ($type, $suggested_types) = @_;
    my $message = qq`Unknown type "${ \$type->to_string }".`;

    if ($suggested_types) {
        $message .= ' Did you mean ' . quoted_or_list($suggested_types) . '?';
    }

    return $message;
}

# Known type names
#
# A GraphQL document is only valid if referenced types (specifically
# variable definitions and fragment conditions) are defined by the type schema.
sub known_type_names {
    my $context = shift;
    return {
        # TODO: when validating IDL, re-enable these. Experimental version does not
        # add unreferenced types, resulting in false-positive errors. Squelched
        # errors for now.
        ObjectTypeDefinition => sub { return },
        InterfaceTypeDefinition => sub { return },
        UnionTypeDefinition => sub { return },
        InputObjectTypeDefinition => sub { return },
        NamedType => sub {
            my $node = shift;
            my $schema = $context->get_schema;
            my $type_name = $node->{name}{value};
            my $type = $schema->get_type($type_name);

            unless ($type) {
                $context->report_error(
                    unknown_type_message(
                        $type_name,
                        suggestion_list($type_name, keys %{ $schema->get_type_map }),
                    ),
                    [$node]
                );
            }

            # return?
        },
    };
}

1;

__END__
