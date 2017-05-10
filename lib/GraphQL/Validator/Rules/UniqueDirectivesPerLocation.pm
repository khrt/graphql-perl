package GraphQL::Validator::Rules::UniqueDirectivesPerLocation;

use strict;
use warnings;

sub duplicate_directive_message {
    my $directive_name = shift;
    return qq`The directive "$directive_name" can only be used once at `
         . qq`this location.`;
}

# Unique directive names per location
#
# A GraphQL document is only valid if all directives at a given location
# are uniquely named.
sub validate {
    my $context = shift;
    return {
        # Many different AST nodes may contain directives. Rather than listing
        # them all, just listen for entering any node, and check to see if it
        # defines any directives.
        enter => sub {
            my $node = shift;
            if ($node->{directives}) {
                my %known_directives;
                for my $directive (@{ $node->{directives} }) {
                    my $directive_name = $directive->{name}{value};
                    if ($known_directives{ $directive_name }) {
                        $context->report_error(
                            duplicate_directive_message($directive_name),
                            [$known_directives{ $directive_name }, $directive]
                        );
                    }
                    else {
                        $known_directives{ $directive_name } = $directive;
                    }
                }
            }
            #TODO return
        },
    };
}


1;

__END__
