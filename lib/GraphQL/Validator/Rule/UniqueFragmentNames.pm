package GraphQL::Validator::Rule::UniqueFragmentNames;

use strict;
use warnings;

use GraphQL::Error qw/GraphQLError/;
use GraphQL::Language::Visitor qw/FALSE/;

sub duplicate_fragment_name_message {
    my $frag_name = shift;
    return qq`There can be only one fragment named "$frag_name".`;
}

# Unique fragment names
#
# A GraphQL document is only valid if all defined fragments have unique names.
sub validate {
    my ($self, $context) = @_;
    my %known_fragment_names;

    return {
        OperationDefinition => sub { FALSE },
        FragmentDefinition => sub {
            my (undef, $node) = @_;
            my $fragment_name = $node->{name}{value};

            if ($known_fragment_names{ $fragment_name }) {
                $context->report_error(
                    GraphQLError(
                        duplicate_fragment_name_message($fragment_name),
                        [$known_fragment_names{ $fragment_name }, $node->{name}]
                    )
                );
            }
            else {
                $known_fragment_names{ $fragment_name } = $node->{name};
            }

            return FALSE;
        },
    };
}

1;

__END__
