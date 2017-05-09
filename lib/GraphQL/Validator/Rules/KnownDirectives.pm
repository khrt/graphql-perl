package GraphQL::Validator::Rules::KnownDirectives;

use strict;
use warnings;

use GraphQL::Type::Directive;
use GraphQL::Language::Parser;
use GraphQL::Util qw/find/;

use DDP;

sub DirectiveLocation { 'GraphQL::Type::Directive' }
sub Kind { 'GraphQL::Language::Parser' }

sub unknown_directive_message {
    my $directive_name = shift;
    return qq`Unknown directive "$directive_name".`;
}

sub misplaced_directive_message {
    my ($directive_name, $location) = @_;
    return qq`Directive "$directive_name" may not be used on $location.`;
}

# Known directives
#
# A GraphQL document is only valid if all `@directives` are known by the
# schema and legally positioned.
sub known_directives {
    my $context = shift;
    return {
        Directive => sub {
            my ($node, $key, $parent, $path, $ancestors) = @_;
            my $directive_def = find(
                $context->get_schema->get_directives,
                sub { $_->{name} eq $node->{name}{value} }
            );

            if (!$directive_def) {
                $context->report_error(
                    unknown_directive_message($node->{name}{value}),
                    [$node]
                );
                return;
            }

            # TODO
            my $candidate_location = get_directive_location_for_ast_path($ancestors);
            p $candidate_location;
            if (!$candidate_location) {
                $context->report_error(
                    misplaced_directive_message($node->{name}{value}, $node->{type}),
                    [$node]
                );
            }
            # TODO
            elsif (grep { die $candidate_location } @{ $directive_def->{locations} }) {
                $context->report_error(
                    misplaced_directive_message($node->{name}{value}, $candidate_location),
                    [$node]
                );
            }
            # TODO return?
        }
    };
}

sub get_directive_location_for_ast_path {
    my $ancestors = shift;
    my $applied_to = $ancestors->[scalar(@$ancestors) - 1];

    if ($applied_to->{kind} eq Kind->OPERATION_DEFINITION) {
        if ($applied_to->{operation} eq 'query') { return DirectiveLocation->QUERY }
        elsif ($applied_to->{operation} eq 'mutation') { return DirectiveLocation->MUTATION }
        elsif ($applied_to->{operation} eq 'subscription') { return DirectiveLocation->SUBSCRIPTION }
    }
    elsif ($applied_to->{kind} eq Kind->FIELD) {
        return DirectiveLocation->FIELD;
    }
    elsif ($applied_to->{kind} eq Kind->FRAGMENT_SPREAD) {
        return DirectiveLocation->FRAGMENT_SPREAD;
    }
    elsif ($applied_to->{kind} eq Kind->INLINE_FRAGMENT) {
        return DirectiveLocation->INLINE_FRAGMENT;
    }
    elsif ($applied_to->{kind} eq Kind->FRAGMENT_DEFINITION) {
        return DirectiveLocation->FRAGMENT_DEFINITION;
    }
    elsif ($applied_to->{kind} eq Kind->SCHEMA_DEFINITION) {
        return DirectiveLocation->SCHEMA;
    }
    elsif ($applied_to->{kind} eq Kind->SCALAR_TYPE_DEFINITION) {
        return DirectiveLocation->SCALAR;
    }
    elsif ($applied_to->{kind} eq Kind->OBJECT_TYPE_DEFINITION) {
        return DirectiveLocation->OBJECT;
    }
    elsif ($applied_to->{kind} eq Kind->FIELD_DEFINITION) {
        return DirectiveLocation->FIELD_DEFINITION;
    }
    elsif ($applied_to->{kind} eq Kind->INTERFACE_TYPE_DEFINITION) {
        return DirectiveLocation->INTERFACE;
    }
    elsif ($applied_to->{kind} eq Kind->UNION_TYPE_DEFINITION) {
        return DirectiveLocation->UNION;
    }
    elsif ($applied_to->{kind} eq Kind->ENUM_TYPE_DEFINITION) {
        return DirectiveLocation->ENUM;
    }
    elsif ($applied_to->{kind} eq Kind->ENUM_VALUE_DEFINITION) {
        return DirectiveLocation->ENUM_VALUE;
    }
    elsif ($applied_to->{kind} eq Kind->INPUT_OBJECT_TYPE_DEFINITION) {
        return DirectiveLocation->INPUT_OBJECT;
    }
    elsif ($applied_to->{kind} eq Kind->INPUT_VALUE_DEFINITION) {
        my $parent_node = $ancestors->[scalar(@$ancestors) - 3];
        return $parent_node->{kind} eq Kind->INPUT_OBJECT_TYPE_DEFINITION
            ? DirectiveLocation->INPUT_FIELD_DEFINITION
            : DirectiveLocation->ARGUMENT_DEFINITION;
    }

    return;
}

1;

__END__