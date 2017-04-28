package GraphQL::Language::Printer;

use strict;
use warnings;

use Exporter qw/import/;

our @EXPORT_OK = (qw/print_doc/);

use GraphQL::Language::Visitor qw/visit/;

my %ast_reducer = (
    Name => sub { $_[1]->{value} },
    Variable => sub { '$' . $_[1]->{name} },

    # Document

    Document => sub { mjoin("\n\n", @{ $_[1]->{definitions} }) . "\n" },

    OperationDefinition => sub {
        my ($self, $node) = @_;
        my $op = $node->{operation};
        my $name = $node->{name};
        my $var_defs = wrap('(', mjoin(', ', @{ $node->{variable_definitions} }), ')');
        my $directives = mjoin(' ', @{ $node->{directives} });
        my $selection_set = $node->{selection_set};

        # Anonymous queries with no directives or variable defintions can
        # use the query short form.
        return !$name && !$directives && !$var_defs && $op eq 'query'
            ? $selection_set
            : mjoin(' ', $op, mjoin('', $name, $var_defs), $directives, $selection_set);
    },

    VariableDefinition => sub {
        my ($self, $node) = @_;
        return $node->{variable} . ': ' . $node->{type} . wrap(' = ', $node->{default_value});
    },

    SelectionSet => sub { block(@{ $_[1]->{selections} }) },

    Field => sub {
        my ($self, $node) = @_;
        my $alias = $node->{alias};
        my $name = $node->{name};
        my $args = $node->{arguments};
        my $directives = $node->{directives};
        my $selection_set = $node->{selection_set};

        return mjoin(
            ' ',
            wrap('', $alias, ': ') . $name . wrap('(', mjoin(', ', @$args), ')'),
            mjoin(' ', @$directives), $selection_set
        );
    },

    Argument => sub {
        my ($self, $node) = @_;
        my $name = $node->{name};
        my $value = $node->{value};
        return $name . ': ' . $value;
    },

    # Fragments

    FragmentSpread => sub {
        my ($self, $node) = @_;
        my $name = $node->{name};
        my $directives = $node->{directives};
        return '...' . $name . wrap(' ', mjoin(' ', @$directives));
    },

    InlineFragment => sub {
        my ($self, $node) = @_;
        my $type_condition = $node->{type_condition};
        my $directives = $node->{directives};
        my $selection_set = $node->{selection_set};
        return mjoin(
            ' ', '...',
            wrap('on ', $type_condition),
            mjoin(' ', @$directives),
            $selection_set
        );
    },

    FragmentDefinition => sub {
        my ($self, $node) = @_;
        my $name = $node->{name};
        my $type_condition = $node->{type_condition};
        my $directives = $node->{directives};
        my $selection_set = $node->{selection_set};
        return
              "fragment $name on $type_condition "
            . wrap('', mjoin(' ', @$directives), ' ')
            . $selection_set;
    },

    # Value

    IntValue => sub {
        my ($self, $node) = @_;
        return $node->{value};
    },
    FloatValue => sub {
        my ($self, $node) = @_;
        return $node->{value};
    },
    StringValue => sub {
        my ($self, $node) = @_;
        my $value = $node->{value};
        return stringify($value);
    },
    BooleanValue => sub {
        my ($self, $node) = @_;
        my $value = $node->{value};
        return $value ? 'true' : 'false';
    },
    NullValue => sub { 'null' },
    EnumValue => sub {
        my ($self, $node) = @_;
        return $node->{value};
    },
    ListValue => sub {
        my ($self, $node) = @_;
        my $values = $node->{values};
        return '[' . mjoin(', ', @$values) . ']';
    },
    ObjectValue => sub {
        my ($self, $node) = @_;
        my $fields = $node->{fields};
        return '{' . mjoin(', ', @$fields) . '}';
    },
    ObjectField => sub {
        my ($self, $node) = @_;
        my $name = $node->{name};
        my $value = $node->{value};
        return $name . ': ' . $value;
    },

    # Directive

    Directive => sub {
        my ($self, $node) = @_;
        my $name = $node->{name};
        my $args = $node->{arguments};
        return '@' . $name . wrap('(', mjoin(', ', @$args), ')');
    },

    # Type

    NamedType => sub {
        my ($self, $node) = @_;
        return $node->{name};
    },
    ListType => sub {
        my ($self, $node) = @_;
        my $type = $node->{type};
        return '[' . $type . ']';
    },
    NonNullType => sub {
        my ($self, $node) = @_;
        my $type = $node->{type};
        return $type . '!';
    },

    # Type System Definitions

    SchemaDefinition => sub {
        my ($self, $node) = @_;
        my $directives = $node->{directives};
        my $operation_types = $node->{operation_types};
        return mjoin(' ', 'schema', mjoin(' ', @$directives), block($operation_types));
    },

    OperationTypeDefinition => sub {
        my ($self, $node) = @_;
        my $operation = $node->{operation};
        my $type = $node->{type};
        return $operation . ': ' . $type;
    },

    ScalarTypeDefinition => sub {
        my ($self, $node) = @_;
        my $name = $node->{name};
        my $directives = $node->{directives};
        return mjoin(' ', 'scalar', $name, mjoin(' ', @$directives));
    },

    ObjectTypeDefinition => sub {
        my ($self, $node) = @_;
        my $name = $node->{name};
        my $interfaces = $node->{interfaces};
        my $directives = $node->{directives};
        my $fields = $node->{fields};
        return mjoin(' ', 'type',
            $name,
            wrap('implements ', mjoin(', ', @$interfaces)),
            mjoin(' ', @$directives),
            block($fields)
        );
    },

    FieldDefinition => sub {
        my ($self, $node) = @_;
        my $name = $node->{name};
        my $args = $node->{arguments};
        my $type = $node->{type};
        my $directives = $node->{directives};
        return
              $name
            . wrap('(', mjoin(', ', @$args), ')')
            . ': '
            . $type
            . wrap(' ', mjoin(' ', @$directives));
    },

    InputValueDefinition => sub {
        my ($self, $node) = @_;
        my $name = $node->{name};
        my $type = $node->{type};
        my $default_value = $node->{default_value};
        my $directives = $node->{directives};
        return mjoin(
            ' ',
            $name . ': ' . $type,
            wrap('= ', $default_value),
            mjoin(@$directives, ' ')
        );
    },

    InterfaceTypeDefinition => sub {
        my ($self, $node) = @_;
        my $name = $node->{name};
        my $directives = $node->{directives};
        my $fields = $node->{fields};
        return mjoin(
            ' ',
            'interface',
            $name,
            mjoin(' ', @$directives),
            block($fields));
    },

    UnionTypeDefinition => sub {
        my ($self, $node) = @_;
        my $name = $node->{name};
        my $directives = $node->{directives};
        my $types = $node->{types};
        return mjoin(
            ' ',
            'union',
            $name,
            mjoin(' ', @$directives),
            '= ' . mjoin(' | ', @$types)
        );
    },

    EnumTypeDefinition => sub {
        my ($self, $node) = @_;
        my $name = $node->{name};
        my $directives = $node->{directives};
        my $values = $node->{values};
        return mjoin(' ',
            'enum',
            $name,
            mjoin(' ', @$directives),
            block($values)
        );
    },

    EnumValueDefinition => sub {
        my ($self, $node) = @_;
        my $name = $node->{name};
        my $directives = $node->{directives};
        return mjoin(' ', $name, mjoin(' ', @$directives)),
    },

    InputObjectTypeDefinition => sub {
        my ($self, $node) = @_;
        my $name = $node->{name};
        my $directives = $node->{directives};
        my $fields = $node->{fields};
        return mjoin(
            ' ',
            'input',
            $name,
            mjoin(' ', @$directives),
            block($fields)
        ),
    },

    TypeExtensionDefinition => sub {
        my ($self, $node) = @_;
        my $definition = $node->{definition};
        return "extend $definition";
    },

    DirectiveDefinition => sub {
        my ($self, $node) = @_;
        my $name = $node->{name};
        my $args = $node->{arguments};
        my $locations = $node->{locations};
        return 'directive @' . $name . wrap('(', mjoin(', ', @$args), ')')
            . ' on ' . mjoin(' | ', @$locations);
    },
);

#
# Given maybeArray, print an empty string if it is null or empty, otherwise
# print all items together separated by separator if provided
#
sub mjoin {
    my ($separator, @maybe_array) = @_;
    return @maybe_array
        ? join($separator || '', grep { $_ } @maybe_array)
        : '';
}

#
# Given array, print each item on its own line, wrapped in an
# indented "{ }" block.
#
sub block {
    my @array = @_;
    return scalar(@array) > 0
        ? indent("{\n" . mjoin("\n", @array)) . "\n}"
        : '{}';
}

#
# If maybeString is not null or empty, then wrap with start and end, otherwise
# print an empty string.
#
sub wrap {
    my ($start, $maybe_string, $end) = @_;
    return $maybe_string
        ? $start . $maybe_string . ($end || '')
        : '';
}

sub indent {
    my $maybe_string = shift;
    return unless $maybe_string;
    $maybe_string =~ s/\n/\n  /g;
    return $maybe_string;
}

sub stringify {
    my $string = shift;
    $string =~ s/"/\\"/g;
    return qq/"$string"/;
}

sub print_doc {
    my $ast = shift;
    return visit($ast, { leave => \%ast_reducer });
}

1;

__END__
