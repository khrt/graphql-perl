package GraphQL::Validator::Rule::KnownTypeNames;

use strict;
use warnings;

use GraphQL::Error qw/GraphQLError/;
use GraphQL::Util qw/
    stringify_type
    quoted_or_list
    suggestion_list
/;

sub unknown_type_message {
    my ($type, $suggested_types) = @_;
    my $message = qq`Unknown type "${ stringify_type($type) }".`;

    if ($suggested_types && @$suggested_types) {
        $message .= ' Did you mean ' . quoted_or_list($suggested_types) . '?';
    }

    return $message;
}

# Known type names
#
# A GraphQL document is only valid if referenced types (specifically
# variable definitions and fragment conditions) are defined by the type schema.
sub validate {
    my ($self, $context) = @_;
    return {
        # TODO: when validating IDL, re-enable these. Experimental version does not
        # add unreferenced types, resulting in false-positive errors. Squelched
        # errors for now.
        ObjectTypeDefinition => sub { return },
        InterfaceTypeDefinition => sub { return },
        UnionTypeDefinition => sub { return },
        InputObjectTypeDefinition => sub { return },
        NamedType => sub {
            my (undef, $node) = @_;

            my $schema = $context->get_schema;
            my $type_name = $node->{name}{value};
            my $type = $schema->get_type($type_name);

            unless ($type) {
                $context->report_error(
                    GraphQLError(
                        unknown_type_message(
                            $type_name,
                            suggestion_list($type_name, [keys %{ $schema->get_type_map }]),
                        ),
                        [$node]
                    )
                );
            }

            return;
        },
    };
}

1;

__END__
