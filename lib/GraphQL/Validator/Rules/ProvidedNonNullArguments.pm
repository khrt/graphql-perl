package GraphQL::Validator::Rules::ProvidedNonNullArguments;

use strict;
use warnings;

use GraphQL::Util qw/key_map/;

sub missing_field_arg_message {
    my ($field_name, $arg_name, $type) = @_;
    return qq`Field "${field_name}" argument "${arg_name}" of type `
         . qq`"${ \$type->to_string }" is required but not provided.`;
}

sub missing_directive_arg_message {
    my ($directive_name, $arg_name, $type) = @_;
    return qq`Directive "@${directive_name}" argument "${arg_name}" of type `
         . qq`"${ \$type->to_string }" is required but not provided.`;
}

# Provided required arguments
#
# A field or directive is only valid if all required (non-null) field arguments
# have been provided.
sub validate {
    my ($self, $context) = @_;
    return {
        Field => {
            # Validate on leave to allow for deeper errors to appear first->
            leave => sub {
                my (undef, $node) = @_;

                my $field_def = $context->get_field_def;
                if (!$field_def) {
                    return; # false
                }

                my $arg_nodes = $node->arguments || [];
                my $arg_node_map = key_map($arg_nodes, sub { $_[0]->{name}{value} });

                for my $arg_def (@{ $field_def->{args} }) {
                    my $arg_node = $arg_node_map->{ $arg_def->{name} };
                    if (!$arg_node && $arg_def->type->isa('GraphQL::Type::NonNull')) {
                        $context->report_error(
                            missing_field_arg_message(
                                $node->{name}{value},
                                $arg_def->{name},
                                $arg_def->{type}
                            ),
                            [$node]
                        );
                    }
                };

                return; # void
            }
        },
        Directive => {
            # Validate on leave to allow for deeper errors to appear first.
            leave => sub {
                my (undef, $node) = @_;

                my $directive_def = $context->get_directive;
                if (!$directive_def) {
                    return; # false
                }

                my $arg_nodes = $node->arguments || [];
                my $arg_node_map = key_map($arg_nodes, sub { $_[0]->{name}{value} });

                for my $arg_def (@{ $directive_def->{args} }) {
                    my $arg_node = $arg_node_map->{ $arg_def->{name} };
                    if (!$arg_node && $arg_def->type->isa('GraphQL::Type::NonNull')) {
                        $context->report_error(
                            missing_directive_arg_message(
                                $node->{name}{value},
                                $arg_def->{name},
                                $arg_def->{type}
                            ),
                            [$node]
                        );
                    }
                };

                return; # void
            }
        },
    };
}

1;

__END__
