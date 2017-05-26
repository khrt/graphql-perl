package GraphQL::Type::Directive;

use strict;
use warnings;

use constant {
    # Operations
    QUERY => 'QUERY',
    MUTATION => 'MUTATION',
    SUBSCRIPTION => 'SUBSCRIPTION',
    FIELD => 'FIELD',
    FRAGMENT_DEFINITION => 'FRAGMENT_DEFINITION',
    FRAGMENT_SPREAD => 'FRAGMENT_SPREAD',
    INLINE_FRAGMENT => 'INLINE_FRAGMENT',
    # Schema Definitions
    SCHEMA => 'SCHEMA',
    SCALAR => 'SCALAR',
    OBJECT => 'OBJECT',
    FIELD_DEFINITION => 'FIELD_DEFINITION',
    ARGUMENT_DEFINITION => 'ARGUMENT_DEFINITION',
    INTERFACE => 'INTERFACE',
    UNION => 'UNION',
    ENUM => 'ENUM',
    ENUM_VALUE => 'ENUM_VALUE',
    INPUT_OBJECT => 'INPUT_OBJECT',
    INPUT_FIELD_DEFINITION => 'INPUT_FIELD_DEFINITION',
};

# use Exporter qw/import/;

# our @EXPORT_OK = qw/
#     QUERY
#     MUTATION
#     SUBSCRIPTION
#     FIELD
#     FRAGMENT_DEFINITION
#     FRAGMENT_SPREAD
#     INLINE_FRAGMENT
#     SCHEMA
#     SCALAR
#     OBJECT
#     FIELD_DEFINITION
#     ARGUMENT_DEFINITION
#     INTERFACE
#     UNION
#     ENUM
#     ENUM_VALUE
#     INPUT_OBJECT
#     INPUT_FIELD_DEFINITION
# /;

# our %EXPORT_TAGS = (
#     DirectiveLocation => [qw/
#         QUERY
#         MUTATION
#         SUBSCRIPTION
#         FIELD
#         FRAGMENT_DEFINITION
#         FRAGMENT_SPREAD
#         INLINE_FRAGMENT
#         SCHEMA
#         SCALAR
#         OBJECT
#         FIELD_DEFINITION
#         ARGUMENT_DEFINITION
#         INTERFACE
#         UNION
#         ENUM
#         ENUM_VALUE
#         INPUT_OBJECT
#         INPUT_FIELD_DEFINITION
#     /],
# );

use GraphQL::Util qw/assert_valid_name/;
use GraphQL::Util::Type qw/is_input_type/;

sub name { shift->{name} }
sub description { shift->{description} }
sub locations { shift->{locations} }
sub args { shift->{args} }

sub new {
    my ($class, %config) = @_;

    die "Directive must be named.\n" unless $config{name};
    assert_valid_name($config{name});

    die "Must provide locations for directive.\n"
        if ref($config{locations}) ne 'ARRAY';

    my $self = bless {
        name => $config{name},
        description => $config{description},
        locations => $config{locations},

        args => [],
    }, $class;

    my $args = $config{args};
    if ($args) {
        die "\@$config{name} args must be an object with argument names as keys.\n"
            if ref($args) ne 'HASH';

        for my $arg_name (keys %$args) {
            assert_valid_name($arg_name);

            my $arg = $args->{ $arg_name };
            die "\@$config{name}($arg_name:) argument type must be "
              . "Input Type but got: ${ \$arg->{type}->to_string }.\n" unless is_input_type($arg->{type});

            push @{ $self->{args} }, {
                name => $arg_name,
                description => $arg->{description},
                type => $arg->{type},
                default_value => $arg->{default_value},
            };
        }
    }

    return $self;
}

1;

__END__
