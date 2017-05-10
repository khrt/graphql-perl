package GraphQL::Util;

use strict;
use warnings;

use DDP;

use List::Util qw/reduce/;

use Exporter qw/import/;

our @EXPORT_OK = (qw/
    assert_valid_name
    find

    quoted_or_list
    suggestion_list

    type_from_ast

    key_map

    is_valid_literal_value
/);

use GraphQL::Language::Parser;
use GraphQL::Language::Printer qw/print_doc/;

sub Kind { 'GraphQL::Language::Parser' }


# Ensures consoles warnigns are only issued once.
our $has_warned_about_dunder;
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

sub key_map {
    my ($list, $key_fn) = @_;

    my %result;
    for my $i (@$list) {
        my $key = $key_fn->($i);
        $result{ $key } = $i;
    }

    return \%result;
}

sub is_valid_literal_value {
    my ($type, $value_node) = @_;

    # A value must be provided if the type is non-null.
    if ($type->isa('GraphQL::Type::NonNull')) {
        if (!$value_node || ($value_node->{kind} eq Kind->NULL)) {
            return [qq`Expected "${ \$type->to_string}", found null.`];
        }
        return is_valid_literal_value($type->of_type, $value_node);
    }

    if (!$value_node || ($value_node->{kind} eq Kind->NULL)) {
        return [];
    }

    # This function only tests literals, and assumes variables will provide
    # values of the correct type.
    if ($value_node->{kind} eq Kind->VARIABLE) {
        return [];
    }

    # Lists accept a non-list value as a list of one.
    if ($type->isa('GraphQL::Type::List')) {
        my $item_type = $type->of_type;
        if ($value_node->{kind} eq Kind->LIST) {
            my $index = 1;
            return reduce {
                my $errors = is_valid_literal_value($item_type, $b);
                push @$a, map { "In element #$index: $_" } @$errors;
                $a;
            } [], @{ $value_node->{values} };
        }
        return is_valid_literal_value($item_type, $value_node);
    }

    # Input objects check each defined field and look for undefined fields.
    if ($type->isa('GraphQL::Type::InputObject')) {
        if ($value_node->{kind} ne Kind->OBJECT) {
            return [qq`Expected "${ \$type->name }", found not an object.`];
        }

        my $fields = $type->get_fields;
        my @errors;

        # Ensure every provided field is defined.
        my $field_nodes = $value_node->{fields};
        for my $provided_field_node (@$field_nodes) {
            if (!$fields->{ $provided_field_node->{name}{value} }) {
                push @errors,
                    qq`In field "${ \$provided_field_node->{name}{value} }": Unknown field.`;
            }
        }

        # Ensure every defined field is valid.
        my $field_node_map = key_map($field_nodes, sub { $_[0]->{name}{value} });
        for my $field_name (keys %$fields) {
            my $result = is_valid_literal_value(
                $fields->{ $field_name }{type},
                $field_node_map->{ $field_name } && $field_node_map->{ $field_name }{value}
            );
            push @errors, map { qq`In field "$field_name": $_`  } @$result;
        }

        return \@errors;
    }

    die 'Must be input type'
        if !$type->isa('GraphQL::Type::Scalar')
        && !$type->isa('GraphQL::Type::Enum');

    # Scalar/Enum input checks to ensure the type can parse the value to
    # a non-null value.
    my $parse_result = $type->parse_literal($value_node);
# print 'parse_result '; p $parse_result;
    unless (defined $parse_result) {
        return [qq`Expected type "${ \$type->name }", found ${ \print_doc($value_node) }.`];
    }

    return [];
}

1;

__END__
