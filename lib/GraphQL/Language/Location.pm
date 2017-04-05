package GraphQL::Language::Location;

use strict;
use warnings;

use Exporter 'import';

our @EXPORT_OK = (qw/get_location/);

sub get_location {
    my ($source, $position) = @_;

    my $body = $source->body;
    my $line = 1;
    my $column = $position + 1;

    while (($body =~ /(\r\n|[\n\r])/g) && $-[0] < $position) {
        $line++;
        $column = $position + 1 - ($-[0] + length($1));
    }

    return { line => $line, column => $column };
}

1;

__END__
