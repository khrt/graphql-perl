package GraphQL::Validator::Rule::NoUnusedFragments;

use strict;
use warnings;

sub unsed_frag_message {
    my $frag_name = shift;
    return qq`Fragment "$frag_name" is never used.`;
}

# No unused fragments
#
# A GraphQL document is only valid if all fragment definitions are spread
# within operations, or spread within other fragments spread within operations.
sub validate {
    my ($self, $context) = @_;
    my (@operation_defs, @fragment_defs);

    return {
        OperationDefinition => sub {
            my (undef, $node) = @_;
            push @operation_defs, $node;
            return; # false
        },
        FragmentDefinition => sub {
            my (undef, $node) = @_;
            push @fragment_defs, $node;
            return; # false
        },
        Document => {
            leave => sub {
                my %fragment_name_used;
                for my $operation (@operation_defs) {
                    my $frags = $context->get_recursively_referenced_fragments($operation);
                    for my $frag (@$frags) {
                        $fragment_name_used{ $frag->{name}{value} } = 1;
                    }
                }

                for my $frag_def (@fragment_defs) {
                    my $frag_name = $frag_def->{name}{value};
                    unless ($fragment_name_used{ $frag_name }) {
                        $context->report_error(
                            unsed_frag_message($frag_name),
                            [$frag_def]
                        );
                    }
                }

                return; # void
            },
        },
    };
}

1;

__END__
