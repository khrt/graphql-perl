package GraphQL::Language::Source;

use strict;
use warnings;

sub new {
    my ($class, %args) = @_;
    bless {
        body => $args{body},
        name => $args{name} || 'GraphQL',
    }, $class;
}

sub body { shift->{body} }
sub name { shift->{name} }

1;

__END__
