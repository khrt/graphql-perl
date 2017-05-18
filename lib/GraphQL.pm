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

=head2 The Query and Mutation Types

=head2 Object Types and Fields

    GraphQLObjectType(
        name => '',
        fields => {

        },
    );

=head2 Scalar Types

=head3 Boolean

    GraphQLBoolean;

=head3 Float

    GraphQLFloat;

=head3 Int

    GraphQLInt;

=head3 ID

    GraphQLID;

=head3 String

    GraphQLString;

=head2 Enumeration Types

=head2 Lists

    GraphQLList($Type);

=head2 Non-Null

    GraphQLList($Type);

=head2 Interfaces

    GraphQLInterfaceType(
        name => '',
        fields => {

        },
    );

=head2 Union Types

    GraphQLUnionType(
        name => '',
        types => [$Type0, $Type1],
    );

=head2 Input Types

    GraphQLInputObjectType(
        name => '',
        fields => {

        },
    );

=head1 SCHEMA

    GraphQLSchema(

    );

=head1 PARSER

Pure Perl. L<GraphQL::Language::Parser>.

    my $ast = parse($schema);

=head1 VALIDATION

    $errors = validate(
        $schema,
        $ast,
        $rules,
        $type_info
    );

=head1 EXECUTION

    execute(
        $schema,
        $ast,
        $root_value,
        $context,
        $variable_values,
        $operation_name
    );

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
