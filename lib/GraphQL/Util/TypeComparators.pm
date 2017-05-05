package GraphQL::Util::TypeComparators;

use strict;
use warnings;

use Exporter qw/import/;

our @EXPORT_OK = (qw/
    is_equal_type
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

1;

__END__
