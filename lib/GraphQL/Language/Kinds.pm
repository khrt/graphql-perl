package GraphQL::Language::Kinds;

use strict;
use warnings;

use constant {
    # Name
    NAME => 'Name',

    # Document
    DOCUMENT => 'Document',
    OPERATION_DEFINITION => 'OperationDefinition',
    VARIABLE_DEFINITION => 'VariableDefinition',
    VARIABLE => 'Variable',
    SELECTION_SET => 'SelectionSet',
    FIELD => 'Field',
    ARGUMENT => 'Argument',

    # Fragments
    FRAGMENT_SPREAD => 'FragmentSpread',
    INLINE_FRAGMENT => 'InlineFragment',
    FRAGMENT_DEFINITION => 'FragmentDefinition',

    # Values
    INT => 'IntValue',
    FLOAT => 'FloatValue',
    STRING => 'StringValue',
    BOOLEAN => 'BooleanValue',
    NULL => 'NullValue',
    ENUM => 'EnumValue',
    LIST => 'ListValue',
    OBJECT => 'ObjectValue',
    OBJECT_FIELD => 'ObjectField',

    # Directives
    DIRECTIVE => 'Directive',

    # Types
    NAMED_TYPE => 'NamedType',
    LIST_TYPE => 'ListType',
    NON_NULL_TYPE => 'NonNullType',

    # Type System Definitions
    SCHEMA_DEFINITION => 'SchemaDefinition',
    OPERATION_TYPE_DEFINITION => 'OperationTypeDefinition',

    # Type Definitions
    SCALAR_TYPE_DEFINITION => 'ScalarTypeDefinition',
    OBJECT_TYPE_DEFINITION => 'ObjectTypeDefinition',
    FIELD_DEFINITION => 'FieldDefinition',
    INPUT_VALUE_DEFINITION => 'InputValueDefinition',
    INTERFACE_TYPE_DEFINITION => 'InterfaceTypeDefinition',
    UNION_TYPE_DEFINITION => 'UnionTypeDefinition',
    ENUM_TYPE_DEFINITION => 'EnumTypeDefinition',
    ENUM_VALUE_DEFINITION => 'EnumValueDefinition',
    INPUT_OBJECT_TYPE_DEFINITION => 'InputObjectTypeDefinition',

    # Type Extensions
    TYPE_EXTENSION_DEFINITION => 'TypeExtensionDefinition',

    # Directive Definitions
    DIRECTIVE_DEFINITION => 'DirectiveDefinition',
};

use Exporter qw/import/;

our @EXPORT_OK = (qw/
    Kind

    NAME
    DOCUMENT
    OPERATION_DEFINITION
    VARIABLE_DEFINITION
    VARIABLE
    SELECTION_SET
    FIELD
    ARGUMENT
    FRAGMENT_SPREAD
    INLINE_FRAGMENT
    FRAGMENT_DEFINITION
    INT
    FLOAT
    STRING
    BOOLEAN
    NULL
    ENUM
    LIST
    OBJECT
    OBJECT_FIELD
    DIRECTIVE
    NAMED_TYPE
    LIST_TYPE
    NON_NULL_TYPE
    SCHEMA_DEFINITION
    OPERATION_TYPE_DEFINITION
    SCALAR_TYPE_DEFINITION
    OBJECT_TYPE_DEFINITION
    FIELD_DEFINITION
    INPUT_VALUE_DEFINITION
    INTERFACE_TYPE_DEFINITION
    UNION_TYPE_DEFINITION
    ENUM_TYPE_DEFINITION
    ENUM_VALUE_DEFINITION
    INPUT_OBJECT_TYPE_DEFINITION
    TYPE_EXTENSION_DEFINITION
    DIRECTIVE_DEFINITION
/);

our %EXPORT_TAGS = (
    all => [qw/
        NAME
        DOCUMENT
        OPERATION_DEFINITION
        VARIABLE_DEFINITION
        VARIABLE
        SELECTION_SET
        FIELD
        ARGUMENT
        FRAGMENT_SPREAD
        INLINE_FRAGMENT
        FRAGMENT_DEFINITION
        INT
        FLOAT
        STRING
        BOOLEAN
        NULL
        ENUM
        LIST
        OBJECT
        OBJECT_FIELD
        DIRECTIVE
        NAMED_TYPE
        LIST_TYPE
        NON_NULL_TYPE
        SCHEMA_DEFINITION
        OPERATION_TYPE_DEFINITION
        SCALAR_TYPE_DEFINITION
        OBJECT_TYPE_DEFINITION
        FIELD_DEFINITION
        INPUT_VALUE_DEFINITION
        INTERFACE_TYPE_DEFINITION
        UNION_TYPE_DEFINITION
        ENUM_TYPE_DEFINITION
        ENUM_VALUE_DEFINITION
        INPUT_OBJECT_TYPE_DEFINITION
        TYPE_EXTENSION_DEFINITION
        DIRECTIVE_DEFINITION
    /],
);

sub Kind { __PACKAGE__ }

1;

__END__
