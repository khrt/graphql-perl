package GraphQL::Validator::Rules::NoFragmentCycles;

use strict;
use warnings;

sub cycle_error_message {
    my ($frag_name, $spread_names) = @_;
    my $via = scalar @$spread_names ? ' via ' . join(', ', @$spread_names) : '';
    return qq`Cannot spread fragment "$frag_name" within itself$via.`;
}

sub validate {
    my $context = shift;

    # Tracks already visited fragments to maintain O(N) and to ensure that
    # cycles are not redundantly reported.
    my %visited_frags;

    # Array of AST nodes used to produce meaningful errors
    my @spread_path;

    # Position in the spread path
    my %spread_path_index_by_name;


    # This does a straight-forward DFS to find cycles.
    # It does not terminate when a cycle was found but continues to explore
    # the graph to find all possible cycles.
    my $detect_cycle_recursive;
    $detect_cycle_recursive = sub {
        my $frag = shift;
        my $frag_name = $frag->{name}{value};

        $visited_frags{ $frag_name } = 1;

        my $spread_nodes =
            $context->get_fragment_spreads($frag->{selection_set});
        unless ($spread_nodes) {
            return;
        }

        $spread_path_index_by_name{ $frag_name } = scalar @spread_path;

        for my $spread_node (@$spread_nodes) {
            my $spread_name = $spread_node->{name}{value};
            my $cycle_index = $spread_path_index_by_name{ $spread_name };

            if (!defined($cycle_index)) {
                push @spread_path, $spread_node;

                if (!$visited_frags{ $spread_name }) {
                    my $spread_fragment = $context->get_fragment($spread_name);
                    if ($spread_fragment) {
                        $detect_cycle_recursive->($spread_fragment);
                    }
                }

                pop @spread_path;
            }
            else {
                my $cycle_path = splice @spread_path, $cycle_index;
                $context->report_error(
                    cycle_error_message(
                        $spread_name,
                        [map { $_->{name}{value} } @$spread_node]
                    ),
                    [@$cycle_path, @$spread_node]
                );
            }
        }

        $spread_path_index_by_name{ $frag_name } = undef;
    };

    return {
        OperationDefinition => sub { return },
        FragmentDefinition => sub {
            my $node = shift;
            if (!$visited_frags{ $node->{name}{value} }) {
                $detect_cycle_recursive->($node);
            }
            return; # false
        },
    };
}

1;

__END__
