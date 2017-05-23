package GraphQL::Language::Parser;

use strict;
use warnings;

use feature 'say';

use GraphQL::Error qw/syntax_error/;
use GraphQL::Language::Source;
use GraphQL::Language::Token;
use GraphQL::Language::Lexer;

use DDP;# { caller_info => 0, };
use Carp 'longmess';

use Exporter qw/import/;

our @EXPORT_OK = (qw/parse parse_value parse_type/);

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

sub TokenKind { 'GraphQL::Language::Token' }

# Given a GraphQL source, parses it into a Document.
# Throws GraphQLError if a syntax error is encountered.
sub parse {
    my ($source, $options) = @_;
    my $source_obj =
        ref($source)
        ? $source
        : GraphQL::Language::Source->new(body => $source);

    my $lexer =
        GraphQL::Language::Lexer->new(source => $source_obj, options => $options);
    return parse_document($lexer);
}

# Given a string containing a GraphQL value (ex. `[42]`), parse the AST for
# that value.
# Throws GraphQLError if a syntax error is encountered.
#
# This is useful within tools that operate upon GraphQL Values directly and
# in isolation of complete GraphQL documents.
#
# Consider providing the results to the utility function: valueFromAST().
sub parse_value {
    my ($source, $options) = @_;

    my $source_obj =
        # check if it's a string
        $source & ~$source
        ? GraphQL::Language::Source->new(body => $source)
        : $source;

    my $lexer =
        GraphQL::Language::Lexer->new(source => $source_obj, options => $options);

    expect($lexer, TokenKind->SOF);
    my $value = parse_value_literal($lexer, 0);
    expect($lexer, TokenKind->EOF);

    return $value;
}

# Given a string containing a GraphQL Type (ex. `[Int!]`), parse the AST for
# that type.
# Throws GraphQLError if a syntax error is encountered.
#
# This is useful within tools that operate upon GraphQL Types directly and
# in isolation of complete GraphQL documents.
#
# Consider providing the results to the utility function: typeFromAST().
sub parse_type {
    my ($source, $options) = @_;

    my $source_obj =
        # check if it's a string
        $source & ~$source
        ? GraphQL::Language::Source->new(body => $source)
        : $source;

    my $lexer =
        GraphQL::Language::Lexer->new(source => $source_obj, options => $options);

    expect($lexer, TokenKind->SOF);
    my $value = parse_type_reference($lexer, 0);
    expect($lexer, TokenKind->EOF);

    return $value;
}

# Converts a name lex token into a name parse node.
sub parse_name {
    my $lexer = shift;
    my $token = expect($lexer, TokenKind->NAME);
    return {
        kind => NAME,
        value => $token->value,
        loc($lexer, $token),
    };
}

# Implements the parsing rules in the Document section.
#
# Document : Definition+
#
sub parse_document {
    my $lexer = shift;
    my $start = $lexer->token;

    expect($lexer, TokenKind->SOF);

    my @definitions;
    do {
        push @definitions, parse_definition($lexer);
    } while (!skip($lexer, TokenKind->EOF));

    return {
        kind => DOCUMENT,
        definitions => \@definitions,
        loc($lexer, $start),
    };
}

#
# Definition :
#   - OperationDefinition
#   - FragmentDefinition
#   - TypeSystemDefinition
#
sub parse_definition {
    my $lexer = shift;

    if ($lexer->token->kind eq TokenKind->BRACE_L) {
        return parse_operation_definition($lexer);
    }

    if ($lexer->token->kind eq TokenKind->NAME) {
        my $v = $lexer->token->value;

        if (   $v eq 'query'
            || $v eq 'mutation'
            || $v eq 'subscription'
        )
        {
            return parse_operation_definition($lexer);
        }
        elsif ($v eq 'fragment') {
            return parse_fragment_definition($lexer);
        }
        elsif ($v eq 'schema'
            || $v eq 'scalar'
            || $v eq 'type'
            || $v eq 'interface'
            || $v eq 'union'
            || $v eq 'enum'
            || $v eq 'input'
            || $v eq 'extend'
            || $v eq 'directive')
        {
            return parse_type_system_definition($lexer);
        }
    }

    die unexpected($lexer);
}

# Implements the parsing rules in the Operation section.

#
# OperationDefinition :
#  - SelectionSet
#  - OperationType Name? VariableDefinitions? Directives? SelectionSet
#
sub parse_operation_definition {
    my $lexer = shift;
    my $start = $lexer->token;

    if ($lexer->token->kind eq TokenKind->BRACE_L) {
        return {
            kind => OPERATION_DEFINITION,
            operation => 'query',
            name => undef,
            variable_definitions => undef,
            directives => [],
            selection_set => parse_selection_set($lexer),
            loc($lexer, $start),
        };
    }

    my $operation = parse_operation_type($lexer);
    my $name;
    if ($lexer->token->kind eq NAME) {
        $name = parse_name($lexer);
    }

    return {
        kind => OPERATION_DEFINITION,
        operation => $operation,
        name => $name,
        variable_definitions => parse_variable_definitions($lexer),
        directives => parse_directives($lexer),
        selection_set => parse_selection_set($lexer),
        loc($lexer, $start),
    };
}

#
# OperationType : one of `query` `mutation` `subscription`
#
sub parse_operation_type {
    my $lexer = shift;
    my $operation_token = expect($lexer, TokenKind->NAME);

    my $type = do {
        if ($operation_token->value eq 'query') { 'query' }
        elsif ($operation_token->value eq 'mutation') { 'mutation' }
        # NOTE: subscription is an experimental non-spec addition
        elsif ($operation_token->value eq 'subscription') { 'subscription' }
    };

    die unexpected($lexer, $operation_token) unless $type;

    return $type;
}

#
# VariableDefinitions : ( VariableDefinition+ )
#
sub parse_variable_definitions {
    my $lexer = shift;
    return [] if $lexer->token->kind ne TokenKind->PAREN_L;
    return many(
        $lexer,
        TokenKind->PAREN_L,
        \&parse_variable_definition,
        TokenKind->PAREN_R
    );
}

#
# VariableDefinition : Variable : Type DefaultValue?
#
sub parse_variable_definition {
    my $lexer = shift;
    my $start = $lexer->token;
    return {
        kind => VARIABLE_DEFINITION,
        variable => parse_variable($lexer),
        type => (expect($lexer, TokenKind->COLON) && parse_type_reference($lexer)),
        default_value =>
            skip($lexer, TokenKind->EQUALS) ? parse_value_literal($lexer, 1) : undef,
        loc($lexer, $start),
    };
}

#
# Variable : $ Name
#
sub parse_variable {
    my $lexer = shift;
    my $start = $lexer->token;

    expect($lexer, TokenKind->DOLLAR);

    return {
        kind => VARIABLE,
        name => parse_name($lexer),
        loc($lexer, $start),
    };
}

#
# SelectionSet : { Selection+ }
#
sub parse_selection_set {
    my $lexer = shift;
    my $start = $lexer->token;
    return {
        kind => SELECTION_SET,
        selections => many($lexer, TokenKind->BRACE_L, \&parse_selection, TokenKind->BRACE_R),
        loc($lexer, $start),
    };
}

#
# Selection :
#   - Field
#   - FragmentSpread
#   - InlineFragment
#
sub parse_selection {
    my $lexer = shift;
    return $lexer->token->kind eq TokenKind->SPREAD
        ? parse_fragment($lexer)
        : parse_field($lexer);
}

#
# Field : Alias? Name Arguments? Directives? SelectionSet?
#
# Alias: Name :
#
sub parse_field {
    my $lexer = shift;
    my $start = $lexer->token;

    my $name_or_alias = parse_name($lexer);

    my ($alias, $name);

    if (skip($lexer, TokenKind->COLON)) {
        $alias = $name_or_alias;
        $name = parse_name($lexer);
    }
    else {
        $alias = undef;
        $name = $name_or_alias;
    }

    return {
        kind => FIELD,
        alias => $alias,
        name => $name,
        arguments => parse_arguments($lexer),
        directives => parse_directives($lexer),
        selection_set =>
            $lexer->token->kind eq TokenKind->BRACE_L ? parse_selection_set($lexer) : undef,
        loc($lexer, $start),
    };
}

#
# Arguments : ( Argument+ )
#
sub parse_arguments {
    my $lexer = shift;
    return $lexer->token->kind eq TokenKind->PAREN_L
        ? many($lexer, TokenKind->PAREN_L, \&parse_argument, TokenKind->PAREN_R)
        : [];
}

#
# Argument : Name : Value
#
sub parse_argument {
    my $lexer = shift;
    my $start = $lexer->token;
    return {
        kind => ARGUMENT,
        name => parse_name($lexer),
        value => (expect($lexer, TokenKind->COLON) && parse_value_literal($lexer, 0)),
        loc($lexer, $start),
    };
}

# Implements the parsing rules in the Fragments section
#
# FragmentSpread : ... FragmentName Directives?
#
# InlineFragment : ... TypeCondition? Directives? SelectionSet
#
sub parse_fragment {
    my $lexer = shift;
    my $start = $lexer->token;

    expect($lexer, TokenKind->SPREAD);

    if ($lexer->token->kind eq NAME && $lexer->token->value ne 'on') {
        return {
            kind => FRAGMENT_SPREAD,
            name => parse_fragment_name($lexer),
            directives => parse_directives($lexer),
            loc($lexer, $start),
        };
    }

    my $type_condition;
    if ($lexer->token->value && $lexer->token->value eq 'on') {
        $lexer->advance;
        $type_condition = parse_named_type($lexer),
    }

    return {
        kind => INLINE_FRAGMENT,
        type_condition => $type_condition,
        directives => parse_directives($lexer),
        selection_set => parse_selection_set($lexer),
        loc($lexer, $start),
    };
}

#
# FramentDefinition :
#   - fragment FragmentName on TypeCondition Directives? SelectionSet
#
# TypeCondition : NamedType
#
sub parse_fragment_definition {
    my $lexer = shift;
    my $start = $lexer->token;

    expect_keyword($lexer, 'fragment');

    return {
        kind => FRAGMENT_DEFINITION,
        name => parse_fragment_name($lexer),
        type_condition => (expect_keyword($lexer, 'on') && parse_named_type($lexer)),
        directives => parse_directives($lexer),
        selection_set => parse_selection_set($lexer),
        loc($lexer, $start),
    };
}

#
# FragmentName : Name but not `on`
#
sub parse_fragment_name {
    my $lexer = shift;

    if ($lexer->token->value eq 'on') {
        die unexpected($lexer);
    }

    return parse_name($lexer);
}

# Implements the parsing rules in the Values section.
#
# Value[Const] :
#   - [~Const] Variable
#   - IntValue
#   - FloatValue
#   - StringValue
#   - BooleanValue
#   - NullValue
#   - EnumValue
#   - ListValue[?Const]
#   - ObjectValue[?Const]
#
# BooleanValue : one of `true` `false`
#
# NullValue : `null`
#
# EnumValue : Name but not `true`, `false or `null`
#
sub parse_value_literal {
    my ($lexer, $is_const) = @_;
    my $token = $lexer->token;

    if ($token->kind eq TokenKind->BRACKET_L) {
        return parse_list($lexer, $is_const);
    }
    elsif ($token->kind eq TokenKind->BRACE_L) {
        return parse_object($lexer, $is_const);
    }
    elsif ($token->kind eq TokenKind->INT) {
        $lexer->advance;
        return {
            kind => INT,
            value => $token->value,
            loc($lexer, $token),
        };
    }
    elsif ($token->kind eq TokenKind->FLOAT) {
        $lexer->advance;
        return {
            kind => FLOAT,
            value => $token->value,
            loc($lexer, $token),
        };
    }
    elsif ($token->kind eq TokenKind->STRING) {
        $lexer->advance;
        return {
            kind => STRING,
            value => $token->value,
            loc($lexer, $token),
        };
    }
    elsif ($token->kind eq TokenKind->NAME) {
        if ($token->value eq 'true' || $token->value eq 'false') {
            $lexer->advance;
            return {
                kind => BOOLEAN,
                value => $token->value eq 'true' ? 1 : 0,
                loc($lexer, $token),
            };
        }
        elsif ($token->value eq 'null') {
            $lexer->advance;
            return {
                kind => NULL,
                loc($lexer, $token),
            };
        }

        $lexer->advance;
        return {
            kind => ENUM,
            value => $token->value,
            loc($lexer, $token),
        };
    }
    elsif ($token->kind eq TokenKind->DOLLAR) {
        return parse_variable($lexer) unless $is_const;
    }

    die unexpected($lexer);
}

sub parse_const_value {
    my $lexer = shift;
    return parse_value_literal($lexer, 1);
}

sub parse_value_value {
    my $lexer = shift;
    return parse_value_literal($lexer, 0);
}

#
# ListValue[Const] :
#   - [ ]
#   - [ Value[?Const]+ ]
#
sub parse_list {
    my ($lexer, $is_const) = @_;
    my $start = $lexer->token;
    my $item = $is_const ? \&parse_const_value : \&parse_value_value;
    return {
        kind => LIST,
        values => any($lexer, TokenKind->BRACKET_L, $item, TokenKind->BRACKET_R),
        loc($lexer, $start),
    };
}

#
# ObjectValue[Const] :
#   - { }
#   - { ObjectField[?Const]+ }
#
sub parse_object {
    my ($lexer, $is_const) = @_;
    my $start = $lexer->token;
    expect($lexer, TokenKind->BRACE_L);

    my @fields;
    while (!skip($lexer, TokenKind->BRACE_R)) {
        push @fields, parse_object_field($lexer, $is_const);
    }

    return {
        kind => OBJECT,
        fields => \@fields,
        loc($lexer, $start),
    };
}

#
# ObjectField[Const] : Name : Value[?Const]
#
sub parse_object_field {
    my ($lexer, $is_const) = @_;
    my $start = $lexer->token;
    return {
        kind => OBJECT_FIELD,
        name => parse_name($lexer),
        value => (expect($lexer, TokenKind->COLON) && parse_value_literal($lexer, $is_const)),
        loc($lexer, $start),
    };
}

# Implements the parsing rules in the Directives section.
#
# Directives : Directive+
#
sub parse_directives {
    my $lexer = shift;
    my @directives;
    while ($lexer->token->kind eq TokenKind->AT) {
        push @directives, parse_directive($lexer);
    }
    return \@directives;
}

#
# Directive : @ Name Arguments?
#
sub parse_directive {
    my $lexer = shift;
    my $start = $lexer->token;
    expect($lexer, TokenKind->AT);
    return {
        kind => DIRECTIVE,
        name => parse_name($lexer),
        arguments => parse_arguments($lexer),
        loc($lexer, $start),
    };
}

# Implements the parsing rules in the Types section.
#
# Type :
#    - NamedType
#    - ListType
#    - NonNullType
#
sub parse_type_reference {
    my $lexer = shift;
    my $start = $lexer->token;
    my $type;

    if (skip($lexer, TokenKind->BRACKET_L)) {
        $type = parse_type_reference($lexer);
        expect($lexer, TokenKind->BRACKET_R);

        $type = {
            kind => LIST_TYPE,
            type => $type,
            loc($lexer, $start),
        };
    }
    else {
        $type = parse_named_type($lexer);
    }

    if (skip($lexer, TokenKind->BANG)) {
        return {
            kind => NON_NULL_TYPE,
            type => $type,
            loc($lexer, $start),
        };
    }

    return $type;
}

#
# NamedType : Name
#
sub parse_named_type {
    my $lexer = shift;
    my $start = $lexer->token;
    return {
        kind => NAMED_TYPE,
        name => parse_name($lexer),
        loc($lexer, $start),
    };
}

# Implements the parsing tules in the Type Definition section.
#
# TypeSystemDefinition :
#   - SchemaDefinition
#   - TypeDefinition
#   - TypeExtensionDefinition
#   - DirectiveDefinition
#
# TypeDefiniton :
#   - ScalarTypeDefinition
#   - ObjectTypeDefinition
#   - InterfaceTypeDefinition
#   - UnionTypeDefinition
#   - EnumTypeDefinition
#   - InputObjectTypeDefinition
#
sub parse_type_system_definition {
    my $lexer = shift;

    die unexpected($lexer) if $lexer->token->kind ne NAME;

    my $obj = do {
        my $value = $lexer->token->value;

        if    ($value eq 'schema')    { parse_schema_definition($lexer) }
        elsif ($value eq 'scalar')    { parse_scalar_type_definition($lexer) }
        elsif ($value eq 'type')      { parse_object_type_definition($lexer) }
        elsif ($value eq 'interface') { parse_interface_type_definition($lexer) }
        elsif ($value eq 'union')     { parse_union_type_definition($lexer) }
        elsif ($value eq 'enum')      { parse_enum_type_definition($lexer) }
        elsif ($value eq 'input')     { parse_input_object_type_definition($lexer) }
        elsif ($value eq 'extend')    { parse_type_extension_definition($lexer) }
        elsif ($value eq 'directive') { parse_directive_definition($lexer) }
    };

    die unexpected($lexer) unless $obj;
    return $obj;
}

#
# SchemaDefinition : schema Directives? { OperationTypeDefinition+ }
#
# OperationTypeDefinition : OperationType : NamedType
#
sub parse_schema_definition {
    my $lexer = shift;
    my $start = $lexer->token;

    expect_keyword($lexer, 'schema');

    my $directives = parse_directives($lexer);
    my $operation_types = many(
        $lexer,
        TokenKind->BRACE_L,
        \&parse_operation_type_definition,
        TokenKind->BRACE_R
    );
    return {
        kind => SCHEMA_DEFINITION,
        directives => $directives,
        operation_types => $operation_types,
    };
}

sub parse_operation_type_definition {
    my $lexer = shift;
    my $start = $lexer->token;

    my $operation = parse_operation_type($lexer);
    expect($lexer, TokenKind->COLON);
    my $type = parse_named_type($lexer);

    return {
        kind => OPERATION_TYPE_DEFINITION,
        operation => $operation,
        type => $type,
        loc($lexer, $start),
    };
}

#
# ScalarTypeDefinition : scalar Name Directives?
#
sub parse_scalar_type_definition {
    my $lexer = shift;
    my $start = $lexer->token;

    expect_keyword($lexer, 'scalar');

    my $name = parse_name($lexer);
    my $directives = parse_directives($lexer);

    return {
        kind => SCALAR_TYPE_DEFINITION,
        name => $name,
        directives => $directives,
        loc($lexer, $start),
    };
}

#
# ObjectTypeDefinition :
#   - type Name ImplementsInterfaces? Directives? { FieldDefinition+ }
#
sub parse_object_type_definition {
    my $lexer = shift;
    my $start = $lexer->token;

    expect_keyword($lexer, 'type');

    my $name = parse_name($lexer);
    my $interfaces = parse_implements_interfaces($lexer);
    my $directives = parse_directives($lexer);
    my $fields = any(
        $lexer,
        TokenKind->BRACE_L,
        \&parse_field_definition,
        TokenKind->BRACE_R
    );
    return {
        kind => OBJECT_TYPE_DEFINITION,
        name => $name,
        interfaces => $interfaces,
        directives => $directives,
        fields => $fields,
        loc($lexer, $start),
    };
}

#
# ImplementsInterfaces : implements NamedType+
#
sub parse_implements_interfaces {
    my $lexer = shift;
    my @types;

    if ($lexer->token->value && $lexer->token->value eq 'implements') {
        $lexer->advance;
        do {
            push @types, parse_named_type($lexer);
        } while ($lexer->token->kind eq TokenKind->NAME);
    }

    return \@types;
}

#
# FieldDefinition : Name ArgumentsDefinition? : Type Directives?
#
sub parse_field_definition {
    my $lexer = shift;
    my $start = $lexer->token;
    my $name = parse_name($lexer);
    my $args = parse_argument_defs($lexer);

    expect($lexer, TokenKind->COLON);

    my $type = parse_type_reference($lexer);
    my $directives = parse_directives($lexer);

    return {
        kind => FIELD_DEFINITION,
        name => $name,
        arguments => $args,
        type => $type,
        directives => $directives,
        loc($lexer, $start),
    };
}

#
# ArgumentsDefinition : ( InputValueDefinition+ )
#
sub parse_argument_defs {
    my $lexer = shift;
    return $lexer->token->kind eq TokenKind->PAREN_L
        ? many($lexer, TokenKind->PAREN_L, \&parse_input_value_def, TokenKind->PAREN_R)
        : [];
}

#
# InputValueDefinition : Name : Type DefaultValue? Directives?
#
sub parse_input_value_def {
    my $lexer = shift;
    my $start = $lexer->token;
    my $name = parse_name($lexer);

    expect($lexer, TokenKind->COLON);

    my $type = parse_type_reference($lexer);

    my $default_value;
    if (skip($lexer, TokenKind->EQUALS)) {
        $default_value = parse_const_value($lexer);
    }

    my $directives = parse_directives($lexer);

    return {
        kind => INPUT_VALUE_DEFINITION,
        name => $name,
        type => $type,
        default_value => $default_value,
        directives => $directives,
        loc($lexer, $start),
    };
}

#
# InterfaceTypeDefinition : interface Name Directives? { FieldDefinition+ }
#
sub parse_interface_type_definition {
    my $lexer = shift;
    my $start = $lexer->token;

    expect_keyword($lexer, 'interface');

    my $name = parse_name($lexer);
    my $directives = parse_directives($lexer);
    my $fields = any($lexer, TokenKind->BRACE_L, \&parse_field_definition, TokenKind->BRACE_R);

    return {
        kind => INTERFACE_TYPE_DEFINITION,
        name => $name,
        directives => $directives,
        fields => $fields,
        loc($lexer, $start),
    };
}

#
# UnionTypeDefinition : union Name Directives? = UnionMemebers
#
sub parse_union_type_definition {
    my $lexer = shift;
    my $start = $lexer->token;

    expect_keyword($lexer, 'union');

    my $name = parse_name($lexer);
    my $directives = parse_directives($lexer);

    expect($lexer, TokenKind->EQUALS);

    my $types = parse_union_members($lexer);

    return {
        kind => UNION_TYPE_DEFINITION,
        name => $name,
        directives => $directives,
        types => $types,
        loc($lexer, $start),
    };
}

#
# UnionMembers :
#   - NamedType
#   - UnionMembers | NamedType
#
sub parse_union_members {
    my $lexer = shift;
    my @members;

    do {
        push @members, parse_named_type($lexer);
    } while (skip($lexer, TokenKind->PIPE));

    return \@members;
}

#
# EnumTypeDefinition : enum Name Directives? { EnumValueDefinition+ }
#
sub parse_enum_type_definition {
    my $lexer = shift;
    my $start = $lexer->token;

    expect_keyword($lexer, 'enum');

    my $name = parse_name($lexer);
    my $directives = parse_directives($lexer);
    my $values = many(
        $lexer,
        TokenKind->BRACE_L,
        \&parse_enum_value_definition,
        TokenKind->BRACE_R
    );

    return {
        kind => ENUM_TYPE_DEFINITION,
        name => $name,
        directives => $directives,
        values => $values,
        loc($lexer, $start),
    };
}

#
# EnumValueDefinition : EnumValue Directives?
#
# EnumValue : Name
#
sub parse_enum_value_definition {
    my $lexer = shift;
    my $start = $lexer->token;
    my $name = parse_name($lexer);
    my $directives = parse_directives($lexer);
    return {
        kind => ENUM_VALUE_DEFINITION,
        name => $name,
        directives => $directives,
        loc($lexer, $start),
    };
}

#
# InputObjectTypeDefinition : input Name Directives? { InputValueDefinition+ }
#
sub parse_input_object_type_definition {
    my $lexer = shift;
    my $start = $lexer->token;

    expect_keyword($lexer, 'input');

    my $name = parse_name($lexer);
    my $directives = parse_directives($lexer);
    my $fields = any($lexer, TokenKind->BRACE_L, \&parse_input_value_def, TokenKind->BRACE_R);

    return {
        kind => INPUT_OBJECT_TYPE_DEFINITION,
        name => $name,
        directives => $directives,
        fields => $fields,
        loc($lexer, $start),
    };
}

#
# DirectiveDefinition :
#   - directive @ Name ArgumentsDefinition? on DirectiveLocations
#
sub parse_directive_definition {
    my $lexer = shift;
    my $start = $lexer->token;

    expect_keyword($lexer, 'directive');
    expect($lexer, TokenKind->AT);

    my $name = parse_name($lexer);
    my $args = parse_argument_defs($lexer);

    expect_keyword($lexer, 'on');

    my $locations = parse_directive_locations($lexer);

    return {
        kind => DIRECTIVE_DEFINITION,
        name => $name,
        arguments => $args,
        locations => $locations,
        loc($lexer, $start),
    };
}

#
# DirectiveLocations :
#   - Name
#   - DirectiveLocations | Name
#
sub parse_directive_locations {
    my $lexer = shift;
    my @locations;

    do {
        push @locations, parse_name($lexer);
    } while (skip($lexer, TokenKind->PIPE));

    return \@locations;
}

#
# Core parsing utility functions
#

sub loc {
    my ($lexer, $start_token) = @_;
    return if $lexer->options->{no_location};
    return loc => {
        start       => $start_token->start,
        end         => $lexer->last_token->end,
        start_token => $start_token,
        end_token   => $lexer->last_token,
        source      => $lexer->source,
    };
}

# If the next token is of the given kind, return true after advancing
# the lexer. Otherwise, do not change the parser state and return false.
sub skip {
    my ($lexer, $kind) = @_;
    my $match = $lexer->token->kind eq $kind;
    $lexer->advance if $match;
    return $match;
}

# If the next token is of the given kind, return that token after advancing
# the lexer. Otherwise, do not change the parser state and throw an error.
sub expect {
    my ($lexer, $kind) = @_;
    my $token = $lexer->token;

    if ($token->kind eq $kind) {
        $lexer->advance;
        return $token;
    }

#use Carp 'longmess';
#warn longmess 'how';
    die syntax_error(
        $lexer->source,
        $token->start,
        "Expected $kind, found ${ \$token->desc }"
    );
}

# If the next token is a keyword with the given value, return that token after
# advance the lexer. Otherwise, do not change the parser state and return false.
sub expect_keyword {
    my ($lexer, $value) = @_;
    my $token = $lexer->token;

    if ($token->kind eq TokenKind->NAME && $token->value eq $value) {
        $lexer->advance;
        return $token;
    }

    die syntax_error(
        $lexer->source,
        $token->start,
        "Expected \"$value\", found ${ \$token->desc }"
    );
}

# Helper function for create an error when an unexpected lexed token
# is encountered.
sub unexpected {
    my ($lexer, $at_token) = @_;
    my $token = $at_token || $lexer->token;

    # use Carp 'longmess';
    # warn longmess 'how';
    return syntax_error(
        $lexer->source,
        $token->start,
        "Unexpected ${ \$token->desc }"
    );
}

# Return a possibly empty list if parse nodes, determined by
# the parseFn. This lis begins with a lex token of openKind
# and ends with a lex token of closeKind. Advances the parser
# to the next lex token after the closing token.
sub any {
    my ($lexer, $open_kind, $parse_fn, $close_kind) = @_;

    expect($lexer, $open_kind);

    my @nodes;
    while (!skip($lexer, $close_kind)) {
        push @nodes, $parse_fn->($lexer);
    }

    return \@nodes;
}

# Returns a non-empty list of parse nodes, determined by
# the parseFn. This list being with a lex token of openKind
# and ends with a lex token of closeKind. Advances the parser
# to the next lex token after the closing token.
sub many {
    my ($lexer, $open_kind, $parse_fn, $close_kind) = @_;

    expect($lexer, $open_kind);

    my @nodes = ($parse_fn->($lexer));
    while (!skip($lexer, $close_kind)) {
        push @nodes, $parse_fn->($lexer);
    }

    return \@nodes;
}

1;

__END__
