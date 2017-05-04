package GraphQL::Type::NonNull;

use strict;
use warnings;

use GraphQL::Util::Type qw/is_type/;

sub of_type { shift->{of_type} }

sub new {
    my ($class, $type) = @_;

    die "Can only create NonNull of a Nullable GraphQLType but got: ${ \$type->to_string }.\n"
        if !is_type($type) || $type->isa('GraphQL::Type::NonNull');

    my $self = bless { of_type => $type }, $class;
    return $self;
}

sub to_string {
    my $self = shift;
    return $self->of_type->to_string . '!';
}

sub to_json { shift->to_string }
sub inspect { shift->to_string }


1;

__END__
 * Non-Null Modifier
 *
 * A non-null is a kind of type marker, a wrapping type which points to another
 * type. Non-null types enforce that their values are never null and can ensure
 * an error is raised if this ever occurs during a request. It is useful for
 * fields which you can make a strong guarantee on non-nullability, for example
 * usually the id field of a database row will never be null.
 *
 * Example:
 *
 *     const RowType = new GraphQLObjectType({
 *       name: 'Row',
 *       fields: () => ({
 *         id: { type: new GraphQLNonNull(GraphQLString) },
 *       })
 *     })
 *
 * Note: the enforcement of non-nullability occurs within the executor.
