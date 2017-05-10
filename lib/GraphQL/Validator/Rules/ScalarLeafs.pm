package GraphQL::Validator::Rules::ScalarLeafs;

use strict;
use warnings;

use GraphQL::Util::Type qw/
    get_named_type
    is_leaf_type
/;

sub no_subselection_allowed_message {
    my ($field_name, $type) = @_;
    return qq`Field "$field_name" must not have a selection since `
         . qq`type "${ \$type->to_string }" has no subfields.`;
}

sub required_subselection_message {
    my ($field_name, $type) = @_;
    return qq`Field "$field_name" of type "${ \$type->to_string }" must have a `
         . qq`selection of subfields. Did you mean "$field_name { ... }"?`;
}

# Scalar leafs
#
# A graph_qL document is valid only if all leaf fields (fields without
# sub selections) are of scalar or enum types.
sub validate {
    my ($self, $context) = @_;

    return {
        Field => sub {
            my (undef, $node) = @_;
            my $type = $context->get_type;

            if ($type) {
                if (is_leaf_type(get_named_type($type))) {
                    if ($node->{selection_set}) {
                        $context->report_error(
                            no_subselection_allowed_message($node->{name}{value}, $type),
                            [$node->{selection_set}]
                        );
                    }
                }
                elsif (!$node->{selection_set}) {
                    $context->report_error(
                        required_subselection_message($node->{name}{value}, $type),
                        [$node]
                    );
                }
            }

            return; # void
        },
    };
}

1;

__END__
