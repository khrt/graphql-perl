package GraphQL::TypeInfo;

use strict;
use warnings;

use feature 'say';
use DDP {
    # max_depth => 1,
};

use GraphQL::Type::Introspection qw/
    SchemaMetaFieldDef
    TypeMetaFieldDef
    TypeNameMetaFieldDef
/;

use GraphQL::Util qw/
    type_from_ast
    find
/;

use GraphQL::Util::Type qw/
    get_named_type
    get_nullable_type
    is_composite_type
    is_input_type
    is_output_type
/;

use GraphQL::Language::Parser;

sub Kind { 'GraphQL::Language::Parser' }

sub schema { shift->{_schema} }

# This experimental optional second parameter is only needed in order
# to support non-spec-compliant codebases. You should never need to use it.
# It may disappear in the future.
sub new {
    my ($class, $schema, $get_field_def_fn) = @_;

    my $self = bless {
        _schema => $schema,
        _type_stack => [],
        _parent_type_stack => [],
        _input_type_stack => [],
        _field_def_stack => [],
        _directive => undef,
        _argument => undef,
        _enum_value => undef,
        _get_field_def => $get_field_def_fn || \&_get_field_def,
    }, $class;

    return $self;
}

sub get_type {
    my $self = shift;
    if (scalar @{ $self->{_type_stack} } > 0) {
        return $self->{_type_stack}[scalar(@{ $self->{_type_stack} }) - 1];
    }
    return;
}

sub get_parent_type {
    my $self = shift;
    if (scalar @{ $self->{_parent_type_stack} } > 0) {
        return $self->{_parent_type_stack}[scalar(@{ $self->{_parent_type_stack} }) - 1];
    }
    return;
}

sub get_input_type {
    my $self = shift;
    if (scalar @{ $self->{_input_type_stack} } > 0) {
        return $self->{_input_type_stack}[ scalar(@{ $self->{_input_type_stack} }) - 1];
    }
    return;
}

sub get_field_def {
    my $self = shift;
    if (scalar @{ $self->{_field_def_stack} } > 0) {
        return $self->{_field_def_stack}[ scalar(@{ $self->{_field_def_stack} }) - 1];
    }
    return;
}

sub get_directive {
    my $self = shift;
    return $self->{_directive};
}

sub get_argument {
    my $self = shift;
    return $self->{_argument};
}

sub get_enum_value {
    my $self = shift;
    return $self->{_enum_value};
}

# Flow doesn't yet handle this case.
sub enter {
    my ($self, $node) = @_;
    my $schema = $self->schema;

    if ($node->{kind} eq Kind->SELECTION_SET) {
        my $named_type = get_named_type($self->get_type);
        push @{ $self->{_parent_type_stack} },
            is_composite_type($named_type) ? $named_type : undef;
    }
    elsif ($node->{kind} eq Kind->FIELD) {
        my $parent_type = $self->get_parent_type;

        my $field_def;
        if ($parent_type) {
            $field_def = $self->{_get_field_def}->($schema, $parent_type, $node);
        }

        push @{ $self->{_field_def_stack} }, $field_def;
        push @{ $self->{_type_stack} }, $field_def && $field_def->{type};
    }
    elsif ($node->{kind} eq Kind->DIRECTIVE) {
        $self->{_directive} = $schema->get_directive($node->{name}{value});
    }
    elsif ($node->{kind} eq Kind->OPERATION_DEFINITION) {
        my $type;

        if ($node->{operation} eq 'query') {
            $type = $schema->get_query_type;
        }
        elsif ($node->{operation} eq 'mutation') {
            $type = $schema->get_mutation_type;
        }
        elsif ($node->{operation} eq 'subscription') {
            $type = $schema->get_subscription_type;
        }

        push @{ $self->{_type_stack} }, $type;
    }
    elsif ($node->{kind} eq Kind->INLINE_FRAGMENT
        || $node->{kind} eq Kind->FRAGMENT_DEFINITION)
    {
        my $type_condition_ast = $node->{type_condition};
        my $output_type = $type_condition_ast
            ? type_from_ast($schema, $type_condition_ast)
            : $self->get_type;

        push @{ $self->{_type_stack} },
            is_output_type($output_type) ? $output_type : undef;
    }
    elsif ($node->{kind} eq Kind->VARIABLE_DEFINITION) {
        my $input_type = type_from_ast($schema, $node->{type});
        push @{ $self->{_input_type_stack} },
            is_input_type($input_type) ? $input_type : undef;
    }
    elsif ($node->{kind} eq Kind->ARGUMENT) {
        my ($arg_def, $arg_type);
        my $field_or_directive = $self->get_directive || $self->get_field_def;

        if ($field_or_directive) {
            $arg_def = find(
                $field_or_directive->{args},
                sub { my $arg = shift; $arg->{name} eq $node->{name}{value} },
            );

            if ($arg_def) {
                $arg_type = $arg_def->{type};
            }
        }

        $self->{_argument} = $arg_def;
        push @{ $self->{_input_type_stack} }, $arg_type;
    }
    elsif ($node->{kind} eq Kind->LIST) {
        my $list_type = get_nullable_type($self->get_input_type);
        push @{ $self->{_input_type_stack} },
            $list_type->isa('GraphQL::Type::List') ? $list_type->of_type : undef;
    }
    elsif ($node->{kind} eq Kind->OBJECT_FIELD) {
        my $object_type = get_named_type($self->get_input_type);
        my $field_type;

        if ($object_type && $object_type->isa('GraphQL::Type::InputObject')) {
            my $input_field = $object_type->get_fields->{ $node->{name}{value} };
            $field_type = $input_field ? $input_field->{type} : undef;
        }

        push @{ $self->{_input_type_stack} }, $field_type;
    }
    elsif ($node->{kind} eq Kind->ENUM) {
        my $enum_type = get_named_type($self->get_input_type);
        my $enum_value;

        if ($enum_type && $enum_type->isa('GraphQL::Type::Enum')) {
            $enum_value = $enum_type->get_value($node->{value});
        }

        $self->{_enum_value} = $enum_value;
    }

    return;
}

sub leave {
    my ($self, $node) = @_;

    if ($node->{kind} eq Kind->SELECTION_SET) {
        pop @{ $self->{_parent_type_stack} };
    }
    elsif ($node->{kind} eq Kind->FIELD) {
        pop @{ $self->{_field_def_stack} };
        pop @{ $self->{_type_stack} };
    }
    elsif ($node->{kind} eq Kind->DIRECTIVE) {
        $self->{_directive} = undef;
    }
    elsif ($node->{kind} eq Kind->OPERATION_DEFINITION
        || $node->{kind} eq Kind->INLINE_FRAGMENT
        || $node->{kind} eq Kind->FRAGMENT_DEFINITION)
    {
        pop @{ $self->{_type_stack} };
    }
    elsif ($node->{kind} eq Kind->VARIABLE_DEFINITION) {
        pop @{ $self->{_input_type_stack} };
    }
    elsif ($node->{kind} eq Kind->ARGUMENT) {
        $self->{_argument} = undef;
        pop @{ $self->{_input_type_stack} };
    }
    elsif ($node->{kind} eq Kind->LIST
        || $node->{kind} eq Kind->OBJECT_FIELD)
    {
        pop @{ $self->{_input_type_stack} };
    }
    elsif ($node->{kind} eq Kind->ENUM) {
        $self->{_enum_value} = undef;
    }

    return;
}

# Not exactly the same as the executor's definition of getFieldDef, in this
# statically evaluated environment we do not always have an Object type,
# and need to handle Interface and Union types.
sub _get_field_def {
    my ($schema, $parent_type, $field_node) = @_;
    my $name = $field_node->{name}{value};

    if (   $name eq SchemaMetaFieldDef->{name}
        && $schema->get_query_type == $parent_type)
    {
        return SchemaMetaFieldDef;
    }

    if (   $name eq TypeMetaFieldDef->{name}
        && $schema->get_query_type == $parent_type)
    {
        return TypeMetaFieldDef;
    }

    if (   $name eq TypeNameMetaFieldDef->{name}
        && is_composite_type($parent_type))
    {
        return TypeNameMetaFieldDef;
    }

    if (   $parent_type->isa('GraphQL::Type::Object')
        || $parent_type->isa('GraphQL::Type::Interface'))
    {
        return $parent_type->get_fields->{ $name };
    }

    return;
}

1;

__END__
