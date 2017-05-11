package GraphQL::Validator::Rule::PossibleFragmentSpreads;

use strict;
use warnings;

use GraphQL::Util qw/type_from_ast/;
use GraphQL::Util::TypeComparators qw/do_types_overlap/;

sub type_incompatible_spread_message {
    my ($frag_name, $parent_type, $frag_type) = @_;
    return qq`Fragment "${frag_name}" cannot be spread here as objects of `
         . qq`type "${ \$parent_type->to_string }" can never be of type "${ \$frag_type->to_string }".`;
}

sub type_incompatible_anon_spread_message {
    my ($parent_type, $frag_type) = @_;
    return qq`Fragment cannot be spread here as objects of `
         . qq`type "${ \$parent_type->to_string }" can never be of type "${ \$frag_type->to_string }".`;
}

# Possible fragment spread
#
# A fragment spread is only valid if the type condition could ever possibly
# be true: if there is a non-empty intersection of the possible parent types,
# and possible types which pass the type condition->
sub validate {
    my ($self, $context) = @_;
    return {
        InlineFragment => sub {
            my (undef, $node) = @_;

            my $frag_type = $context->get_type;
            my $parent_type = $context->get_parent_type;

            if (   $frag_type
                && $parent_type
                && !do_types_overlap($context->get_schema, $frag_type, $parent_type))
            {
                $context->report_error(
                    type_incompatible_anon_spread_message($parent_type, $frag_type),
                    [$node]
                );
            }

            return; # void
        },
        FragmentSpread => sub {
            my (undef, $node) = @_;

            my $frag_name = $node->name->value;
            my $frag_type = get_fragment_type($context, $frag_name);
            my $parent_type = $context->get_parent_type;

            if (   $frag_type
                && $parent_type
                && !do_types_overlap($context->get_schema, $frag_type, $parent_type))
            {
                $context->report_error(
                    type_incompatible_spread_message($frag_name, $parent_type, $frag_type),
                    [$node]
                );
            }

            return; # void
        },
    };
}

sub get_fragment_type {
    my ($context, $name) = @_;
    my $frag = $context->get_fragment($name);
    return $frag && type_from_ast($context->get_schema, $frag->{type_condition});
}

1;

__END__
