# NAME

GraphQL - A Perl port of the reference implementation of [GraphQL](http://graphql.org/).

# SYNOPSIS

    use GraphQL qw/:types graphql/;

    my $schema = GraphQLSchema(
        query => $Query,
        mutation => $Mutation;
    );

    my $result = graphql($schema, $query);

# DESCRIPTION

GraphQL is a port of the [reference GraphQL implementation](https://github.com/graphql/graphql-js)
implements GraphQL types, parser, validation, execution, and introspection.

# TYPES

To import all available GraphQL types use `:types` tag from [GraphQL](https://metacpan.org/pod/GraphQL) class.

## Object Types and Fields

## Object

Object represents a list of named fields, each of which yield a value of a
specific type.

    GraphQLObjectType(
        name => '',
        fields => {
            ...
        },
    );

Possible parameters of an object:

- name;
- fields - see ["Fields"](#fields);
- description - optional;
- interfaces - optional;
- is\_type\_of - optional;

### Fields

List of named fields.

    {
        args => {
            ...
        },
        type => GraphQLString,
        resolve => sub {
            my ($obj, $args) = @_;
            ...
        },
    }

Possible argument of a field:

- type;
- args - see ["Arguments"](#arguments);
- resolve - must a code ref if passed;
- description - optional;
- deprecation\_reason - optional;

### Arguments

Arguments are applicable to fields and should defined like a HASH ref of
arguments of HASH ref with type.

    {
        arg_name => {
            type => GraphQL,
            description => 'Argument description',
        },
    }

Possible parameters of an argument:

- type;
- description - optional;
- default\_value - optional;

[GraphQL::Language::Object](https://metacpan.org/pod/GraphQL::Language::Object)

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

- name;
- fields - see ["Fields"](#fields);
- description - optional;
- resolve\_type - must be a CODE ref, optional;

    GraphQLInterfaceType(
        name => 'Interface',
        fields => {
            ...
        },
        resolve_type => {
            my ($obj, $context, $info) = @_;
            ...
        }
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

## Schema

Every GraphQL service has a _query_ type and may or may not have a _mutation_ type.
These types are the same as a regular object type, but they are special because
they define the entry point of every GraphQL query.

    GraphQLSchema(
        query => $Query,
        mutation => $Mutation,
    );

[GraphQL::Type::Schema](https://metacpan.org/pod/GraphQL::Type::Schema).

# INTROSPECTION

[GraphQL::Type::Introspection](https://metacpan.org/pod/GraphQL::Type::Introspection).

# LIMITATIONS

`Boolean`, `NULL`.

# EXAMPLES

See [tests](https://github.com/khrt/graphql-perl/tree/master/t/graphql) and [harness](https://github.com/khrt/graphql-perl/blob/master/t/harness.pm).

# GITHUB

[https://github.com/khrt/graphql-perl](https://github.com/khrt/graphql-perl)

# AUTHOR

Artur Khabibullin - rtkh@cpan.org

# LICENSE

This module and all the modules in this package are governed by the same license
as Perl itself.
