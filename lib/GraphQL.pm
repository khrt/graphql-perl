package GraphQL;

use strict;
use warnings;

use Exporter qw/import/;

our @EXPORT_OK = qw(graphql);

use GraphQL::Language::Parser qw/parse/;
use GraphQL::Language::Source;
use GraphQL::Execute qw/execute/;
use GraphQL::Validator qw/validate/;

our $VERSION = 0.01;

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

GraphQL - A Perl implementation of L<GraphQL|http://graphql.org/>.

=head1 SYNOPSIS

    use GraphQL qw/:types graphql/;

    ...

=head1 DESCRIPTION

=head1 EXPORTS

    graphql

    :types

=head1 TYPES

=head2 Object Types and Fields

L<GraphQL::Language::Object>

=head2 Object

Object represents a list of named fields, each of which yield a value of a
specific type.

=over

=item name

=item fields

L</Fields>

=item description

=item interfaces

=item is_type_of

=back


=head3 Fields

=over

=item type

=item args

L</Arguments>

=item resolve

=item description

=item deprecation_reason

=back


=head3 Arguments



    GraphQLObjectType(
        name => '',
        fields => {
            ...
        },
    );

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

=item name

=item fields

L</Fields>

=item description

=item resolve_type

=back

    GraphQLInterfaceType(
        name => 'Interface',
        fields => {
            ...
        },
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

=head1 SCHEMA

Every GraphQL service has a I<query> type and may or may not have a I<mutation> type.
These types are the same as a regular object type, but they are special because
they define the entry point of every GraphQL query.

    GraphQLSchema(
        query => $Query,
        mutation => $Mutation,
    );

L<GraphQL::Type::Schema>.

=head1 VALIDATION

=head1 EXECUTION

=head1 EXAMPLES

See I<examples> directory.

=head1 GITHUB

L<https://github.com/khrt/graphql-perl|https://github.com/khrt/graphql-perl>

=head1 ACKNOWLEDGEMENTS

=head1 AUTHOR

Artur Khabibullin - rtkh@cpan.org

=head1 LICENSE

This module and all the modules in this package are governed by the same license
as Perl itself.

=cut
