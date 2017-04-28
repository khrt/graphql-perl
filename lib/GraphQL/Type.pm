package GraphQL::Type;

use strict;
use warnings;

# use GraphQL::Type::Schema;
use GraphQL::Type::Enum;
use GraphQL::Type::InputObject;
use GraphQL::Type::Interface;
use GraphQL::Type::List;
use GraphQL::Type::NonNull;
use GraphQL::Type::Object;
use GraphQL::Type::Scalar;
use GraphQL::Type::Union;

use GraphQL::Language::Parser;

use POSIX qw/ceil floor/;

use Exporter qw/import/;

our @EXPORT_OK = (qw/
    GraphQLSchema

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
/);

our %EXPORT_TAGS = (
    all => [qw/
        GraphQLSchema

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
    /],
);

use constant {
    # As per the GraphQL Spec, Integers are only treated as valid when a valid
    # 32-bit signed integer, providing the broadest support across platforms.
    #
    # n.b. JavaScript's integers are safe between -(2^53 - 1) and 2^53 - 1 because
    # they are internally represented as IEEE 754 doubles.
    MIN_INT => -2147483648,
    MAX_INT => 2147483647,
};

sub Kind { 'GraphQL::Language::Parser' }

# Base types
sub GraphQLSchema {
    my $schema;
    # TODO
    eval {
        require GraphQL::Type::Schema;
        $schema = GraphQL::Type::Schema->new(@_);
    };
    return $schema;
}

sub GraphQLScalarType { GraphQL::Type::Scalar->new(@_) }
sub GraphQLObjectType { GraphQL::Type::Object->new(@_) }
sub GraphQLInterfaceType { GraphQL::Type::Interface->new(@_) }
sub GraphQLUnionType { GraphQL::Type::Union->new(@_) }
sub GraphQLEnumType { GraphQL::Type::Enum->new(@_) }
sub GraphQLInputObjectType { GraphQL::Type::InputObject->new(@_) }

sub GraphQLList { GraphQL::Type::List->new(@_) }
sub GraphQLNonNull { GraphQL::Type::NonNull->new(@_) }

# Scalars
sub GraphQLBoolean {
    GraphQL::Type::Scalar->new(
        name => 'Boolean',
        description => 'The `Boolean` scalar type represents `true` or `false`.',
        serialize => sub { $_[1] ? 1 : 0 },
        parse_value => sub { $_[1] ? 1 : 0 },
        parse_literal => sub {
            my ($ast) = shift;
            return $ast->{kind} eq Kind->BOOLEAN ? $ast->{value} : undef;
        },
    );
}

sub GraphQLFloat {
    GraphQL::Type::Scalar->new(
        name => 'Float',
        description =>
              'The `Float` scalar type represents signed double-precision fractional '
            . 'values as specified by '
            . '[IEEE 754](http://en.wikipedia.org/wiki/IEEE_floating_point).',
        serialize => \&coerce_float,
        parse_value => \&coerce_float,
        parse_literal => sub {
            my $ast = $_[1];
            return $ast->{kind} eq Kind->FLOAT || $ast->{kind} eq Kind->INT
                ? $ast->{value}
                : undef;
        },
    );
}

sub GraphQLID {
    GraphQL::Type::Scalar->new(
        name => 'ID',
        description =>
              'The `ID` scalar type represents a unique identifier, often used to '
            . 'refetch an object or as key for a cache. The ID type appears in a JSON '
            . 'response as a String; however, it is not intended to be human-readable. '
            . 'When expected as an input type, any string (such as `"4"`) or integer '
            . '(such as `4`) input value will be accepted as an ID.',
        serialize => sub { $_[1] },
        parse_value => sub { $_[1] },
        parse_literal => sub {
            my ($ast) = shift;
            return $ast->{kind} eq Kind->STRING || $ast->{kind} eq Kind->INT
                ? $ast->{value}
                : undef;
        },
    );
}

sub GraphQLInt {
    GraphQL::Type::Scalar->new(
        name => 'Int',
        description =>
              'The `Int` scalar type represents non-fractional signed whole numeric '
            . 'values. Int can represent values between -(2^31) and 2^31 - 1.',
        serialize => \&coerce_int,
        parse_value => \&coerce_int,
        parse_literal => sub {
            my $ast = $_[1];
            if ($ast->{kind} eq Kind->INT) {
                # TODO: func
                my $num = parseInt($ast->{value}, 10);
                if ($num >= MIN_INT && $num <= MAX_INT) {
                    return $num;
                }
            }
            return;
        },
    );
}

sub GraphQLString {
    GraphQL::Type::Scalar->new(
        name => 'String',
        description =>
              'The `String` scalar type represents textual data, represented as UTF-8 '
            . 'character sequences. The String type is most often used by GraphQL to '
            . 'represent free-form human-readable text.',
        serialize => sub { $_[1] },
        parse_value => sub { $_[1] },
        parse_literal => sub {
            my ($ast) = shift;
            return $ast->{kind} eq Kind->STRING ? $ast->{value} : undef;
        },
    );
}

# Coercions
sub coerce_int {
    my $value = $_[1];

    if ($value eq '') {
        die 'Int cannot represent non 32-bit signed integer value: (empty string)';
    }

    my $num = $value+0;
    if ($num == $value && $num >= MIN_INT && $num <= MAX_INT) {
        return $num < 0 ? ceil($num) : floor($num);
    }

    die "Int cannot represent non 32-bit signed integer value: $value";
}

sub coerce_float {
    my $value = $_[1];

    if ($value eq '') {
        die 'Float cannot represent non numeric value: (empty string)';
    }

    my $num = $value+0;
    if ($num == $value) {
        return $num;
    }

    die "Float cannot represent non numeric value: $value";
}

1;

__END__
