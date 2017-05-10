package GraphQL::Validator::Rules::UniqueFragmentNames;

use strict;
use warnings;

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
        OperationDefinition => sub { return }, #false,
        FragmentDefinition => sub {
            my (undef, $node) = @_;
            my $fragment_name = $node->{name}{value};

            if ($known_fragment_names{ $fragment_name }) {
                $context->report_error(
                    duplicate_fragment_name_message($fragment_name),
                    [$known_fragment_names{ $fragment_name }, $node->{name}]
                );
            }
            else {
                $known_fragment_names{ $fragment_name } = $node->{name};
            }

            return; # false
        },
    };
}

1;

__END__
