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
    syntax_error
/);

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

    return bless {
        message => $message,
        locations => $_locations,
        path => $path,
        nodes => $nodes,
        source => $_source,
        positions => $_positions,
        original_error => $original_error,
    }, __PACKAGE__;
}

sub format_error {
    my $error = shift;
    die "Received null or undefined error.\n" unless $error;
    return {
        message => $error->{message},
        locations => $error->{locations},
        path => $error->{path},
    };
}

# Given an arbitrary Error, presumably thrown while attempting to execute a
# GraphQL operation, produce a new GraphQLError aware of the location in the
# document responsible for the original Error.
sub located_error {
    my ($original_error, $nodes, $path) = @_;

    # warn longmess 'located error';

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

sub syntax_error {
    my ($source, $position, $description) = @_;
    my $location = get_location($source, $position);

    my $error = sprintf "Syntax Error %s (%d:%d) %s\n\n%s",
        $source->name, $location->{line}, $location->{column}, $description,
        _highlight_source_at_location($source, $location);

    return $error;
}

sub _highlight_source_at_location {
    my ($source, $location) = @_;

    my $line = $location->{line};

    my $prev_line_num = $line - 1;
    my $line_num = $line;
    my $next_line_num = $line + 1;

    my $pad_len = length($next_line_num);

    my @lines = split /\n/, $source->body, -1;

    return
        ($line >= 2
            ? _lpad($pad_len, $prev_line_num) . ': ' . $lines[$line - 2] . "\n" : '')
        . _lpad($pad_len, $line_num) . ': ' . $lines[$line - 1] . "\n"
        . (join ' ', ('') x (2+$pad_len+$location->{column})) . "^\n"
        . ($line < scalar(@lines)
            ? _lpad($pad_len, $next_line_num) . ': ' . $lines[$line] . "\n" : '');
}

sub _lpad {
    my ($len, $str) = @_;
    return (join ' ', ('') x ($len-length($str)+1)) . $str;
}

1;

__END__
