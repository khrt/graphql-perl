package GraphQL::Validator::Rule::LoneAnonymousOperation;

use strict;
use warnings;

use GraphQL::Language::Parser;

sub Kind { 'GraphQL::Language::Parser' }

sub anon_operation_not_alone_message {
    return 'This anonymous operation must be the only defined operation.';
}

# Lone anonymous operation
#
# A GraphQL document is only valid if when it contains an anonymous operation
# (the query short-hand) that it contains only that one operation definition.
sub validate {
    my ($self, $context) = @_;
    my $operation_count = 0;

    return {
        Document => sub {
            my (undef, $node) = @_;
            $operation_count =
                scalar grep { $_->{kind} eq Kind->OPERATION_DEFINITION }
                @{ $node->{definitions} };

            return; # void
        },
        OperationDefinition => sub {
            my (undef, $node) = @_;

            if (!$node->{name} && $operation_count > 1) {
                $context->report_error(
                    anon_operation_not_alone_message,
                    [$node]
                );
            }

            return; # void
        },
    };
}

1;

__END__
