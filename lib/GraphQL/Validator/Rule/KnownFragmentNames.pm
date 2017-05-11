package GraphQL::Validator::Rule::KnownFragmentNames;

use strict;
use warnings;

sub unknown_fragment_message {
    my $frag_name = shift;
    return qq`Unknown fragment "$frag_name".`;
}

# Known fragment names
#
# A GraphQL document is only valid if all `...Fragment` fragment spreads refer
# to fragments defined in the same document.
sub validate {
    my ($self, $context) = @_;
    return {
        FragmentSpread => sub {
            my (undef, $node) = @_;

            my $frag_name = $node->{name}{value};
            my $frag = $context->get_fragment($frag_name);

            unless ($frag) {
                $context->report_error(
                    unknown_fragment_message($frag_name),
                    [$node->{name}]
                );
            }

            return; # void
        }
    };
}


1;

__END__
