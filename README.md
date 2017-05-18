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

## Object Types and Fields

[GraphQL::Language::Object](https://metacpan.org/pod/GraphQL::Language::Object)

## Object

Object represents a list of named fields, each of which yield a value of a
specific type.

- name
- fields

    ["Fields"](#fields)

- description
- interfaces
- is\_type\_of

### Fields

- type
- args

    ["Arguments"](#arguments)

- resolve
- description
- deprecation\_reason

### Arguments

    GraphQLObjectType(
        name => '',
        fields => {
            ...
        },
    );

## Scalar Types

GraphQL provides a number of built‐in scalars, but type systems can add
additional scalars with semantic meaning.

- GraphQLBoolean
- GraphQLFloat
- GraphQLInt
- GraphQLID
- GraphQLString

[GraphQL::Language::Scalar](https://metacpan.org/pod/GraphQL::Language::Scalar)

## Enumeration Types

Enumeration types are a special kind of scalar that is restricted to a
particular set of allowed values.

    GraphQLEnumType(
        name => 'Color',
        values => {
            RED => { value => 0 },
            GREEN => { value => 1 },
            BLUE => { value => 2 },
        },
    );

[GraphQL::Language::Enum](https://metacpan.org/pod/GraphQL::Language::Enum)

## Lists

List modifier marks type as _List_, which indicates that this field will return
an array of that type.

    GraphQLList($Type);

The ["Non-Null"](#non-null) and ["List"](#list) modifiers can be combined.

    GraphQLList(GraphQLNonNull($Type)); # [$Type!]

[GraphQL::Language::List](https://metacpan.org/pod/GraphQL::Language::List)

## Non-Null

The Non-Null type modifier means that server always expects to return a
non-null value for a field.
Getting a null value will trigger a GraphQL execution error, letting the client
know that something has gone wrong.

    GraphQLList($Type);

The ["Non-Null"](#non-null) and ["List"](#list) modifiers can be combined.

    GraphQLNonNull(GraphQLList($Type)); # [$Type]!

[GraphQL::Language::NonNull](https://metacpan.org/pod/GraphQL::Language::NonNull)

## Interfaces

Like many type systems, GraphQL supports interfaces. An Interface is an abstract
type that includes a certain set of fields that a type must include to implement
the interface.

- name
- fields

    ["Fields"](#fields)

- description
- resolve\_type

    GraphQLInterfaceType(
        name => 'Interface',
        fields => {
            ...
        },
    );

[GraphQL::Language::Interface](https://metacpan.org/pod/GraphQL::Language::Interface)

## Union Types

Union types are very similar to interfaces, but they don't get to specify any
common fields between the types.

    GraphQLUnionType(
        name => 'Union',
        types => [$Type0, $Type1],
    );

[GraphQL::Language::Union](https://metacpan.org/pod/GraphQL::Language::Union)

# SCHEMA

Every GraphQL service has a _query_ type and may or may not have a _mutation_ type.
These types are the same as a regular object type, but they are special because
they define the entry point of every GraphQL query.

    GraphQLSchema(
        query => $Query,
        mutation => $Mutation,
    );

[GraphQL::Type::Schema](https://metacpan.org/pod/GraphQL::Type::Schema).

# VALIDATION

# EXECUTION

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
