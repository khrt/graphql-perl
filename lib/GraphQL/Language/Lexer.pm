package GraphQL::Language::Lexer;

use strict;
use warnings;

use utf8;
use feature 'say';
use DDP;
use Carp 'longmess';

use GraphQL::Error::SyntaxError qw/syntax_error/;
use GraphQL::Language::Token qw/:kinds/;

sub char_code_at {
    my ($body, $pos) = @_;
    ord(substr($body, $pos, 1));
}

sub print_char_code {
    my $code = shift;

    return EOF if !$code or !defined($code <=> 9**9**9);

    if ($code < 0x007F) {
        my $is_wide = $code <= 32 || $code >= 255;
        return $is_wide
            ? sprintf '"\u%04x"', $code
            : sprintf '"%s"', chr($code);
        #return sprintf q/"\\u%04d"/, $code;
    }
    else {
        return sprintf '"\u%s"', uc(sprintf('%04x', $code));
    }
}

sub new {
    my ($class, %args) = @_;

    my $sof_token = GraphQL::Language::Token->new(
        kind   => SOF,
        start  => 0,
        end    => 0,
        line   => 0,
        column => 0,
    );

    bless {
        source  => $args{source},
        options => $args{options} || {},

        # The previously focused non-ignored token.
        last_token => $sof_token,

        # The currently focused non-ignored token.
        token => $sof_token,

        # The (1-indexed) line containing the current token.
        line => 1,

        # The character offset at which the current line begins.
        line_start => 0,
    }, $class;
}

sub source { shift->{source} }
sub options { shift->{options} }

sub last_token { shift->{last_token} }
sub token { shift->{token} }

sub line { shift->{line} }
sub line_start { shift->{line_start} }

sub advance {
    my $self = shift;
    my $token = $self->{last_token} = $self->token;

    if ($token->kind ne EOF) {
        do {
            $token = $token->{next} = read_token($self, $token);
        } while ($token->kind eq COMMENT);

        $self->{token} = $token;
    }

    return $token;
}

sub read_token {
    my ($lexer, $prev) = @_;

    my $source = $lexer->source;
    my $body = $source->body;
    my $body_length = length $body;

    my $pos = position_after_whitespace($body, $prev->end, $lexer);
    my $line = $lexer->line;
    my $col = 1 + $pos - $lexer->line_start;

    if ($pos >= $body_length) {
        return GraphQL::Language::Token->new(
            kind   => EOF,
            start  => $body_length,
            end    => $body_length,
            line   => $line,
            column => $col,
            prev   => $prev,
        );
    }

    my $code = char_code_at($body, $pos);

    if ($code < 0x0020 && $code != 0x0009 && $code != 0x000A && $code != 0x000D) {
        my $char_code = print_char_code($code);
        die syntax_error($source, $pos,
            "Cannot contain the invalid character ${ \print_char_code($code) }.");
    }

    my $token = do {
        # !
        if ($code == 33) {
            GraphQL::Language::Token->new(
                kind   => BANG,
                start  => $pos,
                end    => $pos + 1,
                line   => $line,
                column => $col,
                prev   => $prev,
            );
        }
        # #
        elsif ($code == 35) {
            read_comment($source, $pos, $line, $col, $prev);
        }
        # $
        elsif ($code == 36) {
            GraphQL::Language::Token->new(
                kind   => DOLLAR,
                start  => $pos,
                end    => $pos + 1,
                line   => $line,
                column => $col,
                prev   => $prev,
            );
        }
        # (
        elsif ($code == 40) {
            GraphQL::Language::Token->new(
                kind   => PAREN_L,
                start  => $pos,
                end    => $pos + 1,
                line   => $line,
                column => $col,
                prev   => $prev,
            );
        }
        # )
        elsif ($code == 41) {
            GraphQL::Language::Token->new(
                kind   => PAREN_R,
                start  => $pos,
                end    => $pos + 1,
                line   => $line,
                column => $col,
                prev   => $prev,
            );
        }
        # .
        elsif ($code == 46) {
            if (   char_code_at($body, $pos+1) == 46
                && char_code_at($body, $pos+2) == 46)
            {
                GraphQL::Language::Token->new(
                    kind   => SPREAD,
                    start  => $pos,
                    end    => $pos + 3,
                    line   => $line,
                    column => $col,
                    prev   => $prev,
                );
            }
        }
        # :
        elsif ($code == 58) {
            GraphQL::Language::Token->new(
                kind   => COLON,
                start  => $pos,
                end    => $pos + 1,
                line   => $line,
                column => $col,
                prev   => $prev,
            );
        }
        # =
        elsif ($code == 61) {
            GraphQL::Language::Token->new(
                kind   => EQUALS,
                start  => $pos,
                end    => $pos + 1,
                line   => $line,
                column => $col,
                prev   => $prev,
            );
        }
        # @
        elsif ($code == 64) {
            GraphQL::Language::Token->new(
                kind   => AT,
                start  => $pos,
                end    => $pos + 1,
                line   => $line,
                column => $col,
                prev   => $prev,
            );
        }
        # [
        elsif ($code == 91) {
            GraphQL::Language::Token->new(
                kind   => BRACKET_L,
                start  => $pos,
                end    => $pos + 1,
                line   => $line,
                column => $col,
                prev   => $prev,
            );
        }
        # ]
        elsif ($code == 93) {
            GraphQL::Language::Token->new(
                kind   => BRACKET_R,
                start  => $pos,
                end    => $pos + 1,
                line   => $line,
                column => $col,
                prev   => $prev,
            );
        }
        # {
        elsif ($code == 123) {
            GraphQL::Language::Token->new(
                kind   => BRACE_L,
                start  => $pos,
                end    => $pos + 1,
                line   => $line,
                column => $col,
                prev   => $prev,
            );
        }
        # |
        elsif ($code == 124) {
            GraphQL::Language::Token->new(
                kind   => PIPE,
                start  => $pos,
                end    => $pos + 1,
                line   => $line,
                column => $col,
                prev   => $prev,
            );
        }
        # }
        elsif ($code == 125) {
            GraphQL::Language::Token->new(
                kind   => BRACE_R,
                start  => $pos,
                end    => $pos + 1,
                line   => $line,
                column => $col,
                prev   => $prev,
            );
        }
        # A-Z _ a-z
        elsif (($code >= 65 && $code <= 90)
            || $code == 95
            || ($code >= 97 && $code <= 122))
        {
            read_name($source, $pos, $line, $col, $prev);
        }
        # - 0-9
        elsif ($code == 45 || ($code >= 48 && $code <= 57)) {
            read_number($source, $pos, $code, $line, $col, $prev);
        }
        # "
        elsif ($code == 34) {
            read_string($source, $pos, $line, $col, $prev);
        }
    };

    unless ($token) {
        die syntax_error($source, $pos, unexpected_character_message($code));
    }

    return $token;
}

# Report a message that an unexpected character was encountered.
sub unexpected_character_message {
    my $code = shift;

    my $message;
    if ($code == 39) {
        $message = 'Unexpected single quote character (\'), did you mean to use '
            . 'a double quote (")?';
    }
    else {
        $message = "Cannot parse the unexpected character ${ \print_char_code($code) }.";
    }

    return $message;
}

sub position_after_whitespace {
    my ($body, $start_position, $lexer) = @_;

    my $body_length = length $body;
    my $pos = $start_position;

    while ($pos < $body_length) {
        my $code = char_code_at($body, $pos);

        # tab | space | comma | bom
        if ($code == 9 || $code == 32 || $code == 44 || $code == 0xFEFF) {
            ++$pos;
        }
        # new line
        elsif ($code == 10) {
            ++$pos;
            ++$lexer->{line};
            $lexer->{line_start} = $pos;
        }
        # carriage return
        elsif ($code == 13) {
            # new line
            if (char_code_at($body, $pos+1) == 10) {
                $pos += 2;
            }
            else {
                ++$pos;
            }

            ++$lexer->{line};
            $lexer->{line_start} = $pos;
        }
        else {
            last;
        }
    }

    return $pos;
}

#
#  * #[\u0009\u0020-\uFFFF]*
#
sub read_comment {
    my ($source, $start, $line, $col, $prev) = @_;
    my $body = $source->body;
    my $code;
    my $pos = $start;

    do {
        $code = char_code_at($body, ++$pos);
    } while ($code && ($code > 0x001F || $code == 0x0009)); # SourceCharacter but not LineTerminator

    return GraphQL::Language::Token->new(
        kind   => COMMENT,
        start  => $start,
        end    => $pos,
        line   => $line,
        column => $col,
        prev   => $prev,
        value  => substr($body, $start+1, ($pos - $start+1)),
    );
}

#
#  * Int:   -?(0|[1-9][0-9]*)
#  * Float: -?(0|[1-9][0-9]*)(\.[0-9]+)?((E|e)(+|-)?[0-9]+)?
#
sub read_number {
    my ($source, $start, $first_code, $line, $col, $prev) = @_;
    my $body = $source->body;
    my $code = $first_code;
    my $pos = $start;
    my $is_float = undef;

    if ($code == 45) { # -
        $code = char_code_at($body, ++$pos);
    }

    if ($code == 48) { # 0
        $code = char_code_at($body, ++$pos);
        if ($code >= 48 && $code <= 57) {
            die syntax_error($source, $pos,
                "Invalid number, unexpected digit after 0: ${ \print_char_code($code) }.");
        }
    }
    else {
        $pos = read_digits($source, $pos, $code);
        $code = char_code_at($body, $pos);
    }

    if ($code == 46) { # .
        $is_float = 1;

        $code = char_code_at($body, ++$pos);
        $pos = read_digits($source, $pos, $code);
        $code = char_code_at($body, $pos);
    }

    if ($code == 69 || $code == 101) { # E e
        $is_float = 1;

        $code = char_code_at($body, ++$pos);
        if ($code == 43 || $code == 45) { # + -
            $code = char_code_at($body, ++$pos);
        }
        $pos = read_digits($source, $pos, $code);
    }

    return GraphQL::Language::Token->new(
        kind   => $is_float ? FLOAT : INT,
        start  => $start,
        end    => $pos,
        line   => $line,
        column => $col,
        prev   => $prev,
        value  => substr($body, $start, $pos - $start),
    );
}

sub read_digits {
    my ($source, $start, $first_code) = @_;
    my $body = $source->body;
    my $pos = $start;
    my $code = $first_code;

    if ($code < 48 || $code > 57) { # 0-9
        die syntax_error($source, $pos,
            "Invalid number, expected digit but got: ${ \print_char_code($code) }.");
    }

    do {
        $code = char_code_at($body, ++$pos);
    } while ($code >= 48 && $code <= 57);

    return $pos;
}

sub read_string {
    my ($source, $start, $line, $col, $prev) = @_;
    my $body = $source->body;
    my $pos = $start+1;
    my $chunk_start = $pos;
    my $code = 0;
    my $value = '';

    while (
        $pos < length($body)
        && ($code = char_code_at($body, $pos))
        # not LineTerminator
        && $code != 0x000A && $code != 0x000D
        # not Quote "
        && $code != 34
      )
    {
        # SourceCharacter
        if ($code < 0x0020 && $code != 0x0009) {
            die syntax_error($source, $pos,
                "Invalid character within String: ${ \print_char_code($code) }.");
        }

        ++$pos;

        if ($code == 92) { # \
            $value .= substr($body, $chunk_start, $pos-1-$chunk_start); # value += slice.call(body, chunkStart, position - 1);
            $code = char_code_at($body, $pos);

            if ($code == 34) { $value .= '"' }
            elsif ($code == 47) { $value .= '/' }
            elsif ($code == 92) { $value .= '\\' }
            elsif ($code == 98) { $value .= '\b' }
            elsif ($code == 102) { $value .= '\f' }
            elsif ($code == 110) { $value .= '\n' }
            elsif ($code == 114) { $value .= '\r' }
            elsif ($code == 116) { $value .= '\t' }
            elsif ($code == 117) { # u
                my $char_code = uni_char_code(
                    char_code_at($body, $pos+1),
                    char_code_at($body, $pos+2),
                    char_code_at($body, $pos+3),
                    char_code_at($body, $pos+4)
                );

                if ($char_code < 0) {
                    die syntax_error($source, $pos,
                        "Invalid character escape sequence: \\u${ \substr($body, $pos+1, 4) }."
                    );
                }

                $value .= chr($char_code);
                $pos += 4;
            }
            else {
                die syntax_error($source, $pos,
                    "Invalid character escape sequence: \\${ \chr($code) }.");
            }

            ++$pos;
            $chunk_start = $pos;
        }
    }

    if ($code != 34) { # quote "
        die syntax_error($source, $pos, 'Unterminated string.');
    }

    $value .= substr($body, $chunk_start, $pos-$chunk_start);
    return GraphQL::Language::Token->new(
        kind   => STRING,
        start  => $start,
        end    => $pos + 1,
        line   => $line,
        column => $col,
        prev   => $prev,
        value  => $value,
    );
}

#
# Converts four hexidecimal chars to the integer that the
# string represents. For example, uniCharCode('0','0','0','f')
# will return 15, and uniCharCode('0','0','f','f') returns 255.
#
# Returns a negative number on error, if a char was invalid.
#
# This is implemented by noting that char2hex() returns undef on error,
# which means the result of ORing the char2hex() will also be negative.
#
sub uni_char_code {
    my ($w, $x, $y, $z) = @_;

    $w = char2hex($w) // return -1;
    $x = char2hex($x) // return -1;
    $y = char2hex($y) // return -1;
    $z = char2hex($z) // return -1;

    return $w << 12 | $x << 8 | $y << 4 | $z;
}

#
# Converts a hex character to its integer value.
# '0' becomes 0, '9' becomes 9
# 'A' becomes 10, 'F' becomes 15
# 'a' becomes 10, 'f' becomes 15
#
#  Returns undef on error.
#
sub char2hex {
    my $z = shift;
    return (
        $z >= 48 && $z <= 57  ? $z - 48 :    # 0-9
        $z >= 65 && $z <= 70  ? $z - 55 :    # A-F
        $z >= 97 && $z <= 102 ? $z - 87 :    # a-f
        undef
    );
}

#
#  * Reads an alphanumeric + underscore name from the source.
#  *
#  * [_A-Za-z][_0-9A-Za-z]*
#
sub read_name {
    my ($source, $pos, $line, $col, $prev) = @_;
    my $body = $source->body;
    my $body_length = length($body);
    my $end = $pos + 1;
    my $code = 0;

    while (
           $end != $body_length
        && ($code = char_code_at($body, $end))
        && (
            $code == 95    # _
            || $code >= 48 && $code <= 57     # 0-9
            || $code >= 65 && $code <= 90     # A-Z
            || $code >= 97 && $code <= 122    # a-z
        )
      )
    {
        ++$end;
    }

    return GraphQL::Language::Token->new(
        kind   => NAME,
        start  => $pos,
        end    => $end,
        line   => $line,
        column => $col,
        prev   => $prev,
        value  => substr($body, $pos, $end - $pos),
    );
}

1;

__END__
