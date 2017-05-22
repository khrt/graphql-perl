package GraphQL::Error;

use strict;
use warnings;

use GraphQL::Language::Location qw/get_location/;

use Carp qw/longmess/;
use DDP;
use Exporter qw/import/;

our @EXPORT_OK = (qw/
    GraphQLError

    format_error
    located_error
/);

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

# Given an arbitrary Error, presumably thrown while attempting to execute a
# GraphQL operation, produce a new GraphQLError aware of the location in the
# document responsible for the original Error.
sub located_error {
    my ($original_error, $nodes, $path) = @_;



    # Note: this uses a brand-check to support GraphQL errors originating from
    # other contexts.
    if ($original_error && $original_error->{path}) {
        return $original_error;
    }

    my $message =
          $original_error
        ? $original_error->{message} || String($original_error)
        : 'An unknown error occurred.';

    return GraphQLError(
        $message,
        $original_error && $original_error->{nodes} || $nodes,
        $original_error && $original_error->{source},
        $original_error && $original_error->{positions},
        $path,
        $original_error
    );
}

1;

__END__
