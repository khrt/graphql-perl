package GraphQL::Type;

use strict;
use warnings;

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
    #GraphQLField

our %EXPORT_TAGS = (
    all => [qw/
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
        #GraphQLField
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
    {
        require GraphQL::Type::Schema;
        $schema = GraphQL::Type::Schema->new(@_);
    };
    return $schema;
}

sub GraphQLDirective { GraphQL::Type::Directive->new(@_) }
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
        serialize => sub { $_[0] ? 1 : 0 },
        parse_value => sub { $_[0] ? 1 : 0 },
        parse_literal => sub {
            my $ast = shift;
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
            my $ast = shift;
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
        serialize => sub { $_[0] },
        parse_value => sub { $_[0] },
        parse_literal => sub {
            my $ast = shift;
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
            my $ast = shift;
            if ($ast->{kind} eq Kind->INT) {
                my $num = int $ast->{value};
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
        serialize => sub { $_[0] },
        parse_value => sub { $_[0] },
        parse_literal => sub {
            my $ast = shift;
            return $ast->{kind} eq Kind->STRING ? $ast->{value} : undef;
        },
    );
}

# Directives

sub DirectiveLocation { 'GraphQL::Type::Directive' }

# Used to conditionally include fields or fragments.
sub GraphQLIncludeDirective {
    GraphQL::Type::Directive->new(
        name => 'include',
        description =>
              'Directs the executor to include this field or fragment only when '
            . 'the `if` argument is true.',
        locations => [
            DirectiveLocation->FIELD,
            DirectiveLocation->FRAGMENT_SPREAD,
            DirectiveLocation->INLINE_FRAGMENT,
        ],
        args => {
            if => {
                type => GraphQLNonNull(GraphQLBoolean),
                description => 'Included when true.',
            },
        },
    );
}

# Used to conditionally skip (exclude) fields or fragments.
sub GraphQLSkipDirective {
    GraphQL::Type::Directive->new(
        name => 'skip',
        description =>
              'Directs the executor to skip this field or fragment when the `if` '
            . 'argument is true.',
        locations => [
            DirectiveLocation->FIELD,
            DirectiveLocation->FRAGMENT_SPREAD,
            DirectiveLocation->INLINE_FRAGMENT,
        ],
        args => {
            if => {
                type => GraphQLNonNull(GraphQLBoolean),
                description => 'Skipped when true.',
            },
        },
    );
}

# Used to declare element of a GraphQL schema as deprecated.
sub GraphQLDeprecatedDirective {
    GraphQL::Type::Directive->new(
        name => 'deprecated',
        description =>
              'Explains why this element was deprecated, usually also including a '
            . 'suggestion for how to access supported similar data. Formatted '
            . 'in [Markdown](https://daringfireball.net/projects/markdown/).',
        locations => [
            DirectiveLocation->FIELD_DEFINITION,
            DirectiveLocation->ENUM_VALUE,
        ],
        args => {
            reason => {
                type => GraphQLString,
                description =>
                      'Explains why this element was deprecated, usually also including a '
                    . 'suggestion for how to access supported similar data. Formatted '
                    . 'in [Markdown](https://daringfireball.net/projects/markdown/).',
                default_value => 'No longer supported',
            }
        },
    );
}

# Other
# sub GraphQLField {
#     my %config = @_;
#     return {
#         name => $config{name},
#         description => $config{description},
#         # type => GraphQLOutputType,
#         args => $config{args} || [],
#         resolve => undef,
#         is_deprecated => undef,
#         deprecation_reason => undef,
#     }
# }

# Coercions
sub coerce_int {
    my $value = shift;

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
    my $value = shift;

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
