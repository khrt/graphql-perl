package GraphQL::Type::List;

use strict;
use warnings;

use GraphQL::Util::Type qw/is_type/;

sub of_type { shift->{of_type} }

sub new {
    my ($class, $type) = @_;

    die "Can only create List of a GraphQLType but got: $type"
        unless is_type($type);

    my $self = bless { of_type => $type }, $class;
    return $self;
}

sub to_string {
    my $self = shift;
    return '[' . $self->of_type->to_string . ']';
}

sub to_json { shift->to_string }
sub inspect { shift->to_string }

1;

__END__

List Modifier

A list is a kind of type marker, a wrapping type which points to another
type. Lists are often created within the context of defining the fields of
an object type.

Example:

    const PersonType = new GraphQLObjectType({
      name: 'Person',
      fields: () => ({
        parents: { type: new GraphQLList(Person) },
        children: { type: new GraphQLList(Person) },
      })
    })
