package GraphQL::Util::TypeComparators;

use strict;
use warnings;

use List::Util qw/any/;
use Exporter qw/import/;

use GraphQL::Util::Type qw/
    is_abstract_type
/;

our @EXPORT_OK = (qw/
    is_equal_type
    do_types_overlap
/);

sub is_equal_type {
    my ($type_a, $type_b) = @_;

    # Equivalent types are equal.
    if ($type_a->to_string eq $type_b->to_string) {
        return 1;
    }

    # If either type is non-null, the other must also be non-null.
    if ($type_a->isa('GraphQL::Type::NonNull') && $type_b->isa('GraphQL::Type::NonNull')) {
        return is_equal_type($type_a->of_type, $type_b->of_type);
    }

    # If either type is a list, the other must also be a list.
    if ($type_a->isa('GraphQL::Type::List') && $type_b->isa('GraphQL::Type::List')) {
        return is_equal_type($type_a->of_type, $type_b->of_type);
    }

    # Otherwise the types are not equal.
    return;
}

# Provided two composite types, determine if they "overlap". Two composite
# types overlap when the Sets of possible concrete types for each intersect.
#
# This is often used to determine if a fragment of a given type could possibly
# be visited in a context of another type.
#
# This function is commutative.
sub do_types_overlap {
    my ($schema, $type_a, $type_b) = @_;

    # So flow is aware this is constant
    my $_type_b = $type_b;

    # Equivalent types overlap
    if ($type_a == $_type_b) {
        return 1;
    }

    if (is_abstract_type($type_a)) {
        if (is_abstract_type($_type_b)) {
            # If both types are abstract, then determine if there is any intersection
            # between possible concrete types of each.
            return any { $schema->is_possible_type($_type_b, $_) }
            @{ $schema->get_possible_types($type_a) };
        }

        # Determine if the latter type is a possible concrete type of the former.
        return $schema->is_possible_type($type_a, $_type_b);
    }

    if (is_abstract_type($_type_b)) {
        # Determine if the former type is a possible concrete type of the latter.
        return $schema->is_possible_type($_type_b, $type_a);
    }

    # Otherwise the types do not overlap.
    return;
}

1;

__END__
