package GraphQL::Util;

use strict;
use warnings;

use Exporter qw/import/;

our @EXPORT_OK = (qw/
    assert_valid_name
    find

    quoted_or_list
    suggestion_list

    type_from_ast
/);

# Ensures consoles warnigns are only issued once.
our $has_warned_about_dunder = undef;

my $NAME_RX = qr/^[_a-zA-z][_a-zA-z0-9]*$/;

sub assert_valid_name {
    my ($name, $is_introspection) = @_;

    if (!$name || ref($name)) {
        die "Must be named. Unexpected name: $name.";
    }

    if (!$is_introspection && substr($name, 0, 2) eq '__' && !$has_warned_about_dunder) {
        $has_warned_about_dunder = 1;
        warn  qq`Name "$name" must not begin with "__", which is reserved by `
            . qq`GraphQL instrospection. In a future release of graphql this will `
            . qq`become a hard error.`;
    }

    if ($name !~ m/$NAME_RX/) {
        die qq`Names must match /$NAME_RX/ but "$name" does not.`;
    }
}

sub find {
    my ($list, $predicate) = @_;

    for my $i (@$list) {
        return $i if $predicate->($i);
    }

    return;
}

sub quoted_or_list {
    die
}

sub suggestion_list {
    die
}

sub type_from_ast {
    die
}

1;

__END__
