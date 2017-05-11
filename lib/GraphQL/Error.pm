package GraphQL::Error;

use strict;
use warnings;

use GraphQL::Language::Location qw/get_location/;

use Exporter qw/import/;

our @EXPORT_OK = (qw/
    GraphQLError

    format_error
/);

# sub new {
#     my ($class, %args) = @_;

#     my $self = bless {
#         message => '',
#         nodes => [],
#         source => [],
#         positions => [],
#         path => [],
#         original_error => [],
#     }, $class;

#     return $self;
# }

# sub name {}
# sub stack {}
# sub message {}
# sub original_error {}

sub format_error {
    my $error = shift;
    die "Received null or undefined error.\n" unless $error;
    return {
        message => $error->{message},
        locations => $error->{locations},
        path => $error->{path},
    };
}

sub GraphQLError {
    my ($message, $nodes, $source, $positions, $path, $original_error) = @_;

    # Compute locations in the source for the given nodes/positions.
    my $_source = $source;
    if (!$_source && $nodes && @$nodes) {
        my $node = $nodes->[0];
        $_source = $node && $node->{loc} && $node->{loc}{source};
    }

    my $_positions = $positions;
    if (!$_positions && $nodes) {
        $_positions = [map { $_->{loc}{start} } grep { %{ $_->{loc} } } @$nodes];
    }

    if ($_positions && !@$_positions) {
        $_positions = undef;
    }

    my $_locations;
    if ($_source && $_positions) {
        $_locations = [map { get_location($_source, $_) } @$_positions];
    }

    return {
        message => $message,
        locations => $_locations,
        path => $path,
        nodes => $nodes,
        source => $_source,
        positions => $_positions,
        original_error => $original_error,
    };
}

1;

__END__
