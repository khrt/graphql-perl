package GraphQL;

use strict;
use warnings;

use Exporter qw/import/;

our @EXPORT_OK = (qw/
    graphql

    GraphQLSchema

    GraphQLDirective

    GraphQLScalarType
    GraphQLObjectType
    GraphQLInterfaceType
    GraphQLUnionType
    GraphQLEnumType
    GraphQLInputObjectType

    GraphQLList
    GraphQLNonNull

    GraphQLBoolean
    GraphQLFloat
    GraphQLID
    GraphQLInt
    GraphQLString

    GraphQLIncludeDirective
    GraphQLSkipDirective
    GraphQLDeprecatedDirective
/);

our %EXPORT_TAGS = (
    types => [qw/
        GraphQLSchema

        GraphQLDirective

        GraphQLScalarType
        GraphQLObjectType
        GraphQLInterfaceType
        GraphQLUnionType
        GraphQLEnumType
        GraphQLInputObjectType

        GraphQLList
        GraphQLNonNull

        GraphQLBoolean
        GraphQLFloat
        GraphQLID
        GraphQLInt
        GraphQLString

        GraphQLIncludeDirective
        GraphQLSkipDirective
        GraphQLDeprecatedDirective
    /],
);

use GraphQL::Execute qw/execute/;
use GraphQL::Language::Parser qw/parse/;
use GraphQL::Language::Source;
use GraphQL::Type qw/:all/;
use GraphQL::Validator qw/validate/;

our $VERSION = 0.02;

sub graphql {
    my ($schema, $request, $root_value, $context, $variable_values, $operation_name) = @_;

    my $source = GraphQL::Language::Source->new(
        body => $request || '',
        name => 'GraphQL request',
    );
    my $ast = parse($source);
    my $validation_errors = validate($schema, $ast);

    if (scalar(@$validation_errors)) {
        return { errors => $validation_errors };
    }

    return execute(
        $schema,
        $ast,
        $root_value,
        $context,
        $variable_values,
        $operation_name
    );
}

1;

__END__

=encoding utf8

=head1 NAME

GraphQL - A Perl port of the reference implementation of L<GraphQL|http://graphql.org/>.

=head1 SYNOPSIS

    use GraphQL qw/:types graphql/;

    my $schema = GraphQLSchema(
        query => $Query,
        mutation => $Mutation;
    );

    my $result = graphql($schema, $query);


=head1 DESCRIPTION

GraphQL is a port of the L<reference GraphQL implementation|https://github.com/graphql/graphql-js>
implements GraphQL types, parser, validation, execution, and introspection.

=head1 TYPES

To import all available GraphQL types use C<:types> tag from L<GraphQL> class.

=head2 Object Types and Fields

=head2 Object

Object represents a list of named fields, each of which yield a value of a
specific type.

    GraphQLObjectType(
        name => '',
        fields => {
            ...
        },
    );

Possible parameters of an object:

=over

=item * name;

=item * fields - see L</Fields>;

=item * description - optional;

=item * interfaces - optional;

=item * is_type_of - optional;

=back

=head3 Fields

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

=over

=item * type;

=item * args - see L</Arguments>;

=item * resolve - must a code ref if passed;

=item * description - optional;

=item * deprecation_reason - optional;

=back


=head3 Arguments

Arguments are applicable to fields and should defined like a HASH ref of
arguments of HASH ref with type.

    {
        arg_name => {
            type => GraphQL,
            description => 'Argument description',
        },
    }

Possible parameters of an argument:

=over

=item * type;

=item * description - optional;

=item * default_value - optional;

=back

L<GraphQL::Language::Object>

=head2 Scalar Types

GraphQL provides a number of built‐in scalars, but type systems can add
additional scalars with semantic meaning.

=over

=item * GraphQLBoolean

=item * GraphQLFloat

=item * GraphQLInt

=item * GraphQLID

=item * GraphQLString

=back

L<GraphQL::Language::Scalar>

=head2 Enumeration Types

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

L<GraphQL::Language::Enum>

=head2 Lists

List modifier marks type as I<List>, which indicates that this field will return
an array of that type.

    GraphQLList($Type);

The L</Non-Null> and L</List> modifiers can be combined.

    GraphQLList(GraphQLNonNull($Type)); # [$Type!]

L<GraphQL::Language::List>

=head2 Non-Null

The Non-Null type modifier means that server always expects to return a
non-null value for a field.
Getting a null value will trigger a GraphQL execution error, letting the client
know that something has gone wrong.

    GraphQLList($Type);

The L</Non-Null> and L</List> modifiers can be combined.

    GraphQLNonNull(GraphQLList($Type)); # [$Type]!

L<GraphQL::Language::NonNull>

=head2 Interfaces

Like many type systems, GraphQL supports interfaces. An Interface is an abstract
type that includes a certain set of fields that a type must include to implement
the interface.

=over

=item * name;

=item * fields - see L</Fields>;

=item * description - optional;

=item * resolve_type - must be a CODE ref, optional;

=back

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

L<GraphQL::Language::Interface>

=head2 Union Types

Union types are very similar to interfaces, but they don't get to specify any
common fields between the types.

    GraphQLUnionType(
        name => 'Union',
        types => [$Type0, $Type1],
    );

L<GraphQL::Language::Union>

=head2 Schema

Every GraphQL service has a I<query> type and may or may not have a I<mutation> type.
These types are the same as a regular object type, but they are special because
they define the entry point of every GraphQL query.

    GraphQLSchema(
        query => $Query,
        mutation => $Mutation,
    );

L<GraphQL::Type::Schema>.

=head1 INTROSPECTION

L<GraphQL::Type::Introspection>.

=head1 LIMITATIONS

C<Boolean>, C<NULL>.

=head1 EXAMPLES

See I<examples> directory.

=head1 GITHUB

L<https://github.com/khrt/graphql-perl|https://github.com/khrt/graphql-perl>

=head1 AUTHOR

Artur Khabibullin - rtkh@cpan.org

=head1 LICENSE

This module and all the modules in this package are governed by the same license
as Perl itself.

=cut
