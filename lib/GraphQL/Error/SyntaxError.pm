package GraphQL::Error::SyntaxError;

use strict;
use warnings;

use DDP;

use GraphQL::Language::Location qw/get_location/;

use Exporter 'import';

our @EXPORT_OK = (qw/syntax_error/);

sub syntax_error {
    my ($source, $position, $description) = @_;
    my $location = get_location($source, $position);

    my $error = sprintf "Syntax Error %s (%d:%d) %s\n\n%s",
        $source->name, $location->{line}, $location->{column}, $description,
        highlight_source_at_location($source, $location);

    return $error;
}

sub highlight_source_at_location {
    my ($source, $location) = @_;

    my $line = $location->{line};

    my $prev_line_num = $line - 1;
    my $line_num = $line;
    my $next_line_num = $line + 1;

    my $pad_len = length($next_line_num);

    my @lines = split /\n/, $source->body, -1;

    return
        ($line >= 2
            ? lpad($pad_len, $prev_line_num) . ': ' . $lines[$line - 2] . "\n" : '')
        . lpad($pad_len, $line_num) . ': ' . $lines[$line - 1] . "\n"
        . (join ' ', ('') x (2+$pad_len+$location->{column})) . "^\n"
        . ($line < scalar(@lines)
            ? lpad($pad_len, $next_line_num) . ': ' . $lines[$line] . "\n" : '');
}

sub lpad {
    my ($len, $str) = @_;
    return (join ' ', ('') x ($len-length($str)+1)) . $str;
}

1;

__END__
