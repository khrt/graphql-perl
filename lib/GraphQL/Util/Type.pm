package GraphQL::Util::Type;

use strict;
use warnings;

use GraphQL::Util qw/assert_valid_name/;

use Exporter qw/import/;

our @EXPORT_OK = (qw/
    is_type           assert_type
    is_input_type     assert_input_type
    is_output_type    assert_output_type
    is_leaf_type      assert_leaf_type
    is_composite_type assert_composite_type
    is_abstract_type  assert_abstract_type
    is_named_type     assert_named_type
    get_named_type
    resolve_thunk

    is_plain_obj
    is_type_subtype_of

    define_enum_values
    define_field_map
    define_interfaces
    define_types
/);

sub is_type {
    my $type = shift;
    return
           $type->isa('GraphQL::Type::Scalar')
        || $type->isa('GraphQL::Type::Object')
        || $type->isa('GraphQL::Type::Interface')
        || $type->isa('GraphQL::Type::Union')
        || $type->isa('GraphQL::Type::Enum')
        || $type->isa('GraphQL::Type::InputObject')
        || $type->isa('GraphQL::Type::List')
        || $type->isa('GraphQL::Type::NonNull');
}

sub assert_type {
    my $type = shift;
    die "Expected ${ \ref($type) } to be a GraphQL type." unless is_type($type);
    return $type;
}

sub is_input_type {
    my $type = shift;
    my $named_type = get_named_type($type);
    return
           $named_type->isa('GraphQL::Type::Scalar')
        || $named_type->isa('GraphQL::Type::Enum')
        || $named_type->isa('GraphQL::Type::InputObject');
}

sub assert_input_type {
    my $type = shift;
    die "Expected ${ \ref($type) } to be a GraphQL input type." unless is_input_type($type);
    return $type;
}

sub is_output_type {
    my $type = shift;
    my $named_type = get_named_type($type);
    return
           $named_type->isa('GraphQL::Type::Scalar')
        || $named_type->isa('GraphQL::Type::Object')
        || $named_type->isa('GraphQL::Type::Interface')
        || $named_type->isa('GraphQL::Type::Union')
        || $named_type->isa('GraphQL::Type::Enum');
}

sub assert_output_type {
    my $type = shift;
    die "Expected ${ \ref($type) } to be a GraphQL output type." unless is_output_type($type);
    return $type;
}

sub is_leaf_type {
    my $type = shift;
    return
           $type->isa('GraphQL::Type::Scalar')
        || $type->isa('GraphQL::Type::Enum');
}

sub assert_leaf_type {
    my $type = shift;
    die "Expected ${ \ref($type) } to be a GraphQL leaf type." unless is_leaf_type($type);
    return $type;
}

sub is_composite_type {
    my $type = shift;
    return
           $type->isa('GraphQL::Type::Object')
        || $type->isa('GraphQL::Type::Interface')
        || $type->isa('GraphQL::Type::Union');
}

sub assert_composite_type {
    my $type = shift;
    die "Expected ${ \ref($type) } to be a GraphQL composite type." unless is_composite_type($type);
    return $type;
}

sub is_abstract_type {
    my $type = shift;
    return
           $type->isa('GraphQL::Type::Interface')
        || $type->isa('GraphQL::Type::Union');
}

sub assert_abstract_type {
    my $type = shift;
    die "Expected ${ \ref($type) } to be a GraphQL abstract type." unless is_abstract_type($type);
    return $type;
}

sub is_named_type {
    my $type = shift;
    return
           $type->isa('GraphQL::Type::Scalar')
        || $type->isa('GraphQL::Type::Object')
        || $type->isa('GraphQL::Type::Interface')
        || $type->isa('GraphQL::Type::Union')
        || $type->isa('GraphQL::Type::Enum')
        || $type->isa('GraphQL::Type::InputObject');
}

sub assert_named_type {
    my $type = shift;
    die "Expected ${ \ref($type) } to be a GraphQL named type." unless is_named_type($type);
    return $type;
}

sub get_named_type {
    my $type = shift;
    my $unmodified_type = $type;
    if (   $unmodified_type->isa('GraphQL::Type::List')
        || $unmodified_type->isa('GraphQL::Type::NonNull'))
    {
        $unmodified_type = $unmodified_type->of_type;
    }
    return $unmodified_type;
}

# Used while defining GraphQL types to allow for circular references in
# otherwise immutable type definitions.
sub resolve_thunk {
    my $thunk = shift;
    # TODO: CODE can be HASH or ARRAY
    return ref($thunk) eq 'CODE' ? { $thunk->() } : $thunk;
}

sub is_plain_obj {
    my $obj = shift;
    return $obj
        && (ref($obj) eq 'HASH'
        || (ref($obj) ne 'CODE' && $obj->isa('HASH')));
}

sub is_type_subtype_of {
    my ($schema, $maybe_subtype, $super_type) = @_;

    # Equivalent type is a valid subtype
    return 1 if $maybe_subtype->to_string eq $super_type->to_string;

    # If super_type is non-null, maybe_subtype must also be non-null.
    if ($super_type->isa('GraphQL::Type::NonNull')) {
        if ($maybe_subtype->isa('GraphQL::Type::NonNull')) {
            return is_type_subtype_of($schema, $maybe_subtype->of_type,
                $super_type->of_type);
        }
        return;
    }
    elsif ($maybe_subtype->isa('GraphQL::Type::NonNull')) {
        # If super_type is nullable, maybe_subtype may be non-null or nullable.
        return is_type_subtype_of($schema, $maybe_subtype->of_type, $super_type);
    }

    # If super_type is a list, maybe_subtype type must also be a list.
    if ($super_type->isa('GraphQL::Type::List')) {
        if ($maybe_subtype->isa('GraphQL::Type::List')) {
            return is_type_subtype_of($schema, $maybe_subtype->of_type,
                $super_type->of_type);
        }
        return;
    }
    elsif ($maybe_subtype->isa('GraphQL::Type::List')) {
        # If super_type is not a list, maybe_subtype must also be not a list.
        return;
    }

    # If super_type type is an abstract type, maybe_subtype type may be a
    # currently possible object type.
    if (   is_abstract_type($super_type)
        && maybe_subtype->isa('GraphQL::Type::Object')
        && $schema->is_possible_type($super_type, $maybe_subtype))
    {
        return 1;
    }

    # Otherwise, the child type is not a valid subtype of the parent type.
    return;
}


# If a resolver is defined, it must be a function
sub is_valid_resolver {
    my $resolver = shift;
    return !$resolver || ref($resolver) eq 'CODE';
}

sub define_enum_values {
    my ($type, $value_map) = @_;

    die qq`$type->{name} values must be an object with value names as keys.`
        unless is_plain_obj($value_map);

    my @value_names = keys %$value_map;
    die qq`$type->{name} values must be an object with value names as keys.`
        unless scalar @value_names > 0;

    my @values;
    for my $value_name (@value_names) {
        assert_valid_name($value_name);
        my $value = $value_map->{$value_name};

        die   qq`$type->{name}.$value_name must refer to an object with a "value" key `
            . qq`representing an internal value but fot $value.` unless is_plain_obj($value);

        die   qq`$type->{name}.$value_name should provide "deprecation_reason" instead `
            . qq`of "is_deprecated".` if $value->{is_deprecated};

        push @values, {
            name => $value_name,
            description => $value->{description},
            is_deprecated => $value->{deprecation_reason} ? 1 : 0,
            deprecation_reason => $value->{deprecation_reason},
            value => $value->{value} ? $value->{value} : $value_name,
        };
    }

    return \@values;
}

sub define_field_map {
    my ($type, $fields_thunk) = @_;

    my $field_map = resolve_thunk($fields_thunk);
    die   qq`$type->{name} fields must be an object with field names as keys or a `
        . qq`function which returns such an object.\n` unless is_plain_obj($field_map);

    my @field_names = keys %$field_map;
    die   qq`$type->{name} fields must be an object with field names as keys or a `
        . qq`function which returns such an object.\n` unless scalar(@field_names);

    my %result_field_map;
    for my $field_name (@field_names) {
        assert_valid_name($field_name);

        my $field_config = $field_map->{$field_name};
        die qq`$type->{name}.$field_name field config must be an object\n`
            unless is_plain_obj($field_config);
        die   qq`$type->{name}.$field_name should provide "deprecation_reason" instead `
            . qq`of "is_deprecated".` if $field_config->{is_deprecated};

        my $field = {
            %$field_config,
            is_deprecated => $field_config->{deprecation_reason} ? 1 : 0,
            name => $field_name,
        };
        die   qq`$type->{name}.$field_name field type must be output type but `
            . qq`got: $field->{type}` unless is_output_type($type);
        die   qq`$type->{name}.$field_name field resolver must be a function if `
            . qq`prodived, but got: $field->{resolve}.` unless is_valid_resolver($field->{resolve});

        my $args_config = $field_config->{args};
        if (!$args_config) {
            $field->{args} = [];
        }
        else {
            die   qq`$type->{name}.$field_name args must be an object with argument `
                . qq`names as keys.` unless is_plain_obj($args_config);

            my @args;
            for my $arg_name (keys %$args_config) {
                assert_valid_name($arg_name);

                my $arg = $args_config->{$arg_name};
                die   qq`$type->{name}.$field_name($arg_name:) argument type must be `
                    . qq`Input Type but got: $arg->{type}` unless is_input_type($arg->{type});

                push @args, {
                    name => $arg_name,
                    description => $arg->{description} ? $arg->{description} : undef,
                    type => $arg->{type},
                    default_value => $arg->{default_value},
                };
            }

            $field->{args} = \@args;
        }

        $result_field_map{$field_name} = $field;
    }

    return \%result_field_map;
}

sub define_interfaces {
    my ($type, $interfaces_thunk) = @_;
    my $interfaces = resolve_thunk($interfaces_thunk);
    return [] unless $interfaces;

    die   qq`$type->{name} intrefaces must be an Array or a function returns `
        . qq`an Array.` if ref($interfaces) ne 'ARRAY';

    for my $iface (@$interfaces) {
        die   qq`$type->{name} may only implement Interface types, it cannot `
            . qq`implement: $iface` unless $iface->isa('GraphQL::Type::Interface');

        if (ref($iface->{resolve_type}) ne 'CODE') {
            die   qq`Interface Type "$iface->{name}" does not provide a "resolve_type" `
                . qq`function and implementing Type "$type->{name}" does not provide a `
                . qq`"is_type_of" function. There is no way to resolve this implementing `
                . qq`type during exection.` if ref($type->{is_type_of}) ne 'CODE';
        }
    }

    return $interfaces;
}

sub define_types {
    my ($union_type, $types_thunk) = @_;
    my $types = resolve_thunk($types_thunk);

    die   qq`Must provide Array of type or a function which returns `
        . qq`such an array for Union $union_type->{name}.` if ref($types) ne 'ARRAY' || !scalar(@$types);

    for my $obj_type (@$types) {
        die   qq`$union_type->{name} may only contain Object types, it cannot contain: `
            . qq`${ \$obj_type->to_string }.\n` unless $obj_type->isa('GraphQL::Type::Object');

        if (ref($union_type->{resolve_type}) ne 'CODE') {
            die   qq`Union type "$union_type->{name}" does not provide a "resolve_type" `
                . qq`function and possible type "$obj_type->{name}" does not provide an `
                . qq`"is_type_of" function. There is no way to resolve this possible type `
                . qq`during exection.` if $obj_type->{is_type_of} ne 'CODE';
        }
    }

    return $types;
}

1;

__END__
