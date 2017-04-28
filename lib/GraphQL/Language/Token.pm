package GraphQL::Language::Token;

use strict;
use warnings;

use constant {
    SOF       => '<SOF>',
    EOF       => '<EOF>',
    BANG      => '!',
    DOLLAR    => '$',
    PAREN_L   => '(',
    PAREN_R   => ')',
    SPREAD    => '...',
    COLON     => ':',
    EQUALS    => '=',
    AT        => '@',
    BRACKET_L => '[',
    BRACKET_R => ']',
    BRACE_L   => '{',
    PIPE      => '|',
    BRACE_R   => '}',
    NAME      => 'Name',
    INT       => 'Int',
    FLOAT     => 'Float',
    STRING    => 'String',
    COMMENT   => 'Comment',
};

use Exporter qw/import/;

our @EXPORT_OK = (qw/
    SOF EOF BANG DOLLAR PAREN_L PAREN_R SPREAD COLON EQUALS AT
    BRACKET_L BRACKET_R BRACE_L PIPE BRACE_R NAME INT FLOAT STRING COMMENT
/);

our %EXPORT_TAGS = (
    kinds => [qw/
        SOF EOF BANG DOLLAR PAREN_L PAREN_R SPREAD COLON EQUALS AT
        BRACKET_L BRACKET_R BRACE_L PIPE BRACE_R NAME INT FLOAT STRING COMMENT
    /],
);

sub new {
    my ($class, %args) = @_;
    bless {
        # The kind of Token.
        kind => undef,

        # The character offset at which this Node begins.
        start => undef,

        # The character offset at which this Node ends.
        end => undef,

        # The 1-indexed line number on which this Token appears.
        line => undef,

        # The 1-indexed column number at which this Token begins.
        column => undef,

        # For non-punctuation tokens, represents the interpreted value of the token.
        value => undef,

        # Tokens exist as nodes in a double-linked-list amongst all tokens
        # including ignored tokens. <SOF> is always the first node and <EOF>
        # the last.
        prev => undef,
        next => undef,

        %args,
    }, $class;
}

sub kind { shift->{kind} }

sub start { shift->{start} }
sub end { shift->{end} }

sub line { shift->{line} }
sub column { shift->{column} }

sub value { shift->{value} }

sub prev { shift->{prev} }
sub next { shift->{next} }

sub inspect {
    my $self = shift;
    return {
        kind   => $self->kind,
        value  => $self->value,
        line   => $self->line,
        column => $self->column,
    };
}

sub desc {
    my $self = shift;
    return $self->value ? "$self->{kind} \"$self->{value}\"" : $self->kind;
}

1;

__END__
