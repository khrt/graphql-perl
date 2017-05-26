package GraphQL::Validator::Rule::KnownArgumentNames;

use strict;
use warnings;

use GraphQL::Error qw/GraphQLError/;
use GraphQL::Language::Kinds qw/Kind/;
use GraphQL::Language::Parser;
use GraphQL::Util qw/
    stringify_type
    find
    suggestion_list
    quoted_or_list
/;

sub unknown_arg_message {
    my ($arg_name, $field_name, $type, $suggested_args) = @_;

    my $message = qq`Unknown argument "$arg_name" on field "$field_name" of `
                . qq`type "${ stringify_type($type) }".`;

    if ($suggested_args && @$suggested_args) {
        $message .= ' Did you mean ' . quoted_or_list($suggested_args) . '?';
    }

    return $message;
}

sub unknown_directive_arg_message {
    my ($arg_name, $directive_name, $suggested_args) = @_;

    my $message = qq`Unknown argument "$arg_name" on directive "\@$directive_name".`;

    if ($suggested_args && @$suggested_args) {
        $message .= ' Did you mean ' . quoted_or_list($suggested_args) . '?';
    }

    return $message;
}

# Known argument names
#
# A GraphQL field is only valid if all supplied arguments are defined by
# that field.
sub validate {
    my ($self, $context) = @_;
    return {
        Argument => sub {
            my (undef, $node, $key, $parent, $path, $ancestors) = @_;
            my $argument_of = $ancestors->[scalar(@$ancestors) - 1];

            if ($argument_of->{kind} eq Kind->FIELD) {
                my $field_def = $context->get_field_def;
                if ($field_def) {
                    my $field_arg_def = find(
                        $field_def->{args},
                        sub { $_[0]->{name} eq $node->{name}{value} }
                    );

                    if (!$field_arg_def) {
                        my $parent_type = $context->get_parent_type;
                        die unless $parent_type;

                        $context->report_error(
                            GraphQLError(
                                unknown_arg_message(
                                    $node->{name}{value},
                                    $field_def->{name},
                                    $parent_type->{name},
                                    suggestion_list(
                                        $node->{name}{value},
                                        [map { $_->{name} } @{ $field_def->{args} }]
                                    )
                                ),
                                [$node]
                            )
                        );
                    }
                }
            }
            elsif ($argument_of->{kind} eq Kind->DIRECTIVE) {
                my $directive = $context->get_directive;
                if ($directive) {
                    my $directive_arg_def = find(
                        $directive->{args},
                        sub { $_[0]->{name} eq $node->{name}{value} }
                    );

                    if (!$directive_arg_def) {
                        $context->report_error(
                            GraphQLError(
                                unknown_directive_arg_message(
                                    $node->{name}{value},
                                    $directive->{name},
                                    suggestion_list(
                                        $node->{name}{value},
                                        [map { $_->{name} } @{ $directive->{args} }]
                                    )
                                ),
                                [$node]
                            )
                        );
                    }
                }
            }

            return; # void
        }
    }
}

1;

__END__
