package test_helper;

# this project's tests randomly fail comparisons due to the uncertain ordering of hash keys.
# test_helper is a shim between the existing tests and GraphQL-Perl as well as JSON to address this issue.
#
# the test_helper package wraps 'graphql' and the lower level 'execute' methods
# so that the response keys can be sorted prior to comparision testing.
#
# similarly 'encode_json' is provide so that JSON will sort before encoding.
#
# place the following in tests that need sorting support.
#
# use lib "t/lib";
# use test_helper qw/graphql execute encode_json/;

use strict;
use warnings;

use Exporter qw/import/;

use JSON qw//;
use GraphQL;
use GraphQL::Execute;

our @ISA       = qw(Exporter);
our @EXPORT_OK = (
    qw/
        graphql
        execute
        encode_json
        /
);

# enable sorted keys in JSON testing
my $json = JSON->new->canonical(1);

sub encode_json {
    $json->encode(shift);
}

sub graphql {
    return sort_response( GraphQL::graphql(@_) );
}

sub execute {
    return sort_response( GraphQL::Execute::execute(@_) );
}

sub sort_response {
    my $resp = shift;

    if (   'HASH' eq ref $resp
        && defined $resp->{data}
        && 'HASH' eq ref $resp->{data} )
    {
        foreach my $key ( keys %{ $resp->{data} } ) {

      # if data looks like json then lets try to parse and re-encode it sorted
            if (   $resp->{data}->{$key}
                && $resp->{data}->{$key} =~ m/^\{[^}]+\}/ )
            {
                $resp->{data}->{$key}
                    = $json->encode( $json->decode( $resp->{data}->{$key} ) );
            }
        }
    }

    return $resp;
}

1;
