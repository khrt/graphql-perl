# NAME

GraphQL - A Perl implementation of [GraphQL](http://graphql.org/).

# SYNOPSIS

    use GraphQL qw/:types graphql/;

    ...

# DESCRIPTION

# EXPORTS

    graphql

    :types

# TYPES

## The Query and Mutation Types

## Object Types and Fields

    GraphQLObjectType(
        name => '',
        fields => {

        },
    );

## Scalar Types

### Boolean

    GraphQLBoolean;

### Float

    GraphQLFloat;

### Int

    GraphQLInt;

### ID

    GraphQLID;

### String

    GraphQLString;

## Enumeration Types

## Lists

    GraphQLList($Type);

## Non-Null

    GraphQLList($Type);

## Interfaces

    GraphQLInterfaceType(
        name => '',
        fields => {

        },
    );

## Union Types

    GraphQLUnionType(
        name => '',
        types => [$Type0, $Type1],
    );

## Input Types

    GraphQLInputObjectType(
        name => '',
        fields => {

        },
    );

# SCHEMA

    GraphQLSchema(

    );

# PARSER

Pure Perl. [GraphQL::Language::Parser](https://metacpan.org/pod/GraphQL::Language::Parser).

    my $ast = parse($schema);

# VALIDATION

    $errors = validate(
        $schema,
        $ast,
        $rules,
        $type_info
    );

# EXECUTION

    execute(
        $schema,
        $ast,
        $root_value,
        $context,
        $variable_values,
        $operation_name
    );

# EXAMPLES

See _examples_ directory.

# GITHUB

[https://github.com/khrt/graphql-perl](https://github.com/khrt/graphql-perl)

# ACKNOWLEDGEMENTS

# AUTHOR

Artur Khabibullin - rtkh@cpan.org

# LICENSE

This module and all the modules in this package are governed by the same license
as Perl itself.
