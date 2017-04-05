
use strict;
use warnings;

use feature 'say';
use DDP;

use Test::More;

use GraphQL::Language::Source;
use GraphQL::Language::Token qw/:kinds/;
use GraphQL::Language::Lexer;

sub lex_one {
    my $str = shift;
    my $lexer = GraphQL::Language::Lexer->new(
        source => GraphQL::Language::Source->new(body => $str)
    );
    return $lexer->advance;
}

subtest 'disallows uncommon control characters' => sub {
    eval { lex_one("\x{0007}") };
    like $@, qr/Syntax Error GraphQL \(1:1\) Cannot contain the invalid character "\\u0007"./;
};

subtest 'accepts BOM header' => sub {
    my $token = lex_one("\x{FEFF} foo");

    is $token->{kind}, NAME;
    is $token->{start}, 2;
    is $token->{end}, 5;
    is $token->{value}, 'foo';
};

subtest 'records line and column' => sub {
    my $token = lex_one("\n \r\n \r  foo\n");

    is $token->{kind}, NAME;
    is $token->{start}, 8; # ?
    is $token->{end}, 11; # ?
    is $token->{line}, 4;
    is $token->{column}, 3;
    is $token->{value}, 'foo';
};

# TODO:
# subtest 'can be JSON.stringified or util.inspected' => sub {
#     my $token = lex_one('foo');
#     expect(JSON.stringify(token)).to.equal(
#         '{"kind":"Name","value":"foo","line":1,"column":1}'
#     );
#     // NB: util.inspect used to suck
#     if (parseFloat(process.version.slice(1)) > 0.10) {
#         expect(require('util').inspect(token)).to.equal(
#             '{ kind: \'Name\', value: \'foo\', line: 1, column: 1 }'
#         );
#     }
# };

subtest 'skips whitespace and comments' => sub {
    my $token;

    $token = lex_one('

    foo


');
    is $token->{kind}, NAME;
    is $token->{start}, 6;
    is $token->{end}, 9;
    is $token->{value}, 'foo';

    $token = lex_one('
    #comment
    foo#comment
');
    is $token->{kind}, NAME;
    is $token->{start}, 18;
    is $token->{end}, 21;
    is $token->{value}, 'foo';

    $token = lex_one(',,,foo,,,');
    is $token->{kind}, NAME;
    is $token->{start}, 3;
    is $token->{end}, 6;
    is $token->{value}, 'foo';
};

subtest 'errors respect whitespace' => sub {
    eval {
        lex_one("

    ?


")
    };
    is $@,
        "Syntax Error GraphQL (3:5) Cannot parse the unexpected character \"?\".\n"
      . "\n"
      . "2: \n"
      . "3:     ?\n"
      . "       ^\n"
      . "4: \n";
};

subtest 'lexes strings' => sub {
    my $token;

    $token = lex_one('"simple"');
    is $token->{kind}, STRING;
    is $token->{start}, 0;
    is $token->{end}, 8;
    is $token->{value}, 'simple';

    $token = lex_one('" white space "');
    is $token->{kind}, STRING;
    is $token->{start}, 0;
    is $token->{end}, 15;
    is $token->{value}, ' white space ';

    $token = lex_one('"quote \\""');
    is $token->{kind}, STRING;
    is $token->{start}, 0;
    is $token->{end}, 10;
    is $token->{value}, 'quote "';

    $token = lex_one('"escaped \\n\\r\\b\\t\\f"');
    is $token->{kind}, STRING;
    is $token->{start}, 0;
    is $token->{end}, 20;
    is $token->{value}, 'escaped \n\r\b\t\f';

    $token = lex_one('"slashes \\\\ \\/"');
    is $token->{kind}, STRING;
    is $token->{start}, 0;
    is $token->{end}, 15;
    is $token->{value}, 'slashes \\ /';

    $token = lex_one('"unicode \\u1234\\u5678\\u90AB\\uCDEF"');
    is $token->{kind}, STRING;
    is $token->{start}, 0;
    is $token->{end}, 34;
    is $token->{value}, "unicode \x{1234}\x{5678}\x{90AB}\x{CDEF}";
};

subtest 'lex reports useful string errors' => sub {
    eval { lex_one('"') };
    like $@, qr/Syntax Error GraphQL \(1:2\) Unterminated string./;

    eval { lex_one('"no end quote') };
    like $@, qr/Syntax Error GraphQL \(1:14\) Unterminated string./;

    eval { lex_one('\'single quotes\'') };
    like $@, qr/Syntax Error GraphQL \(1:1\) Unexpected single quote character \('\), did you mean to use a double quote \("\)\?/;

    eval { lex_one(qq/"contains unescaped \x{0007} control char"/) };
    like $@, qr/Syntax Error GraphQL \(1:21\) Invalid character within String: "\\u0007"\./;

    # TODO
    # NOTE: known issue
    # eval { lex_one(qq/"null-byte is not \x{0000} end of file"/) };
    # like $@, qr/Syntax Error GraphQL \(1:19\) Invalid character within String: "\\u0000"\./;

    eval { lex_one(qq/"multi\nline"/) };
    like $@, qr/Syntax Error GraphQL \(1:7\) Unterminated string/;

    eval { lex_one(qq/"multi\rline"/) };
    like $@, qr/Syntax Error GraphQL \(1:7\) Unterminated string/;

    eval { lex_one('"bad \\z esc"') };
    like $@, qr/Syntax Error GraphQL \(1:7\) Invalid character escape sequence: \\z\./;

    eval { lex_one('"bad \\x esc"') };
    like $@, qr/Syntax Error GraphQL \(1:7\) Invalid character escape sequence: \\x\./;

    eval { lex_one('"bad \\u1 esc"') };
    like $@, qr/Syntax Error GraphQL \(1:7\) Invalid character escape sequence: \\u1 es\./;

    eval { lex_one('"bad \\u0XX1 esc"') };
    like $@, qr/Syntax Error GraphQL \(1:7\) Invalid character escape sequence: \\u0XX1\./;

    eval { lex_one('"bad \\uXXXX esc"') };
    like $@, qr/Syntax Error GraphQL \(1:7\) Invalid character escape sequence: \\uXXXX\./;

    eval { lex_one('"bad \\uFXXX esc"') };
    like $@, qr/Syntax Error GraphQL \(1:7\) Invalid character escape sequence: \\uFXXX\./;

    eval { lex_one('"bad \\uXXXF esc"') };
    like $@, qr/Syntax Error GraphQL \(1:7\) Invalid character escape sequence: \\uXXXF\./;
};

subtest 'lexes numbers' => sub {
    my $token;

    $token = lex_one('4');
    is_deeply [@$token{qw/kind start end value/}], [INT, 0, 1, '4'];

    $token = lex_one('4.123');
    is_deeply [@$token{qw/kind start end value/}], [FLOAT, 0, 5, '4.123'];

    $token = lex_one('-4');
    is_deeply [@$token{qw/kind start end value/}], [INT, 0, 2, '-4'];

    $token = lex_one('9');
    is_deeply [@$token{qw/kind start end value/}], [INT, 0, 1, '9'];

    $token = lex_one('0');
    is_deeply [@$token{qw/kind start end value/}], [INT, 0, 1, '0'];

    $token = lex_one('-4.123');
    is_deeply [@$token{qw/kind start end value/}], [FLOAT, 0, 6, '-4.123'];

    $token = lex_one('0.123');
    is_deeply [@$token{qw/kind start end value/}], [FLOAT, 0, 5, '0.123'];

    $token = lex_one('123e4');
    is_deeply [@$token{qw/kind start end value/}], [FLOAT, 0, 5, '123e4'];

    $token = lex_one('123E4');
    is_deeply [@$token{qw/kind start end value/}], [FLOAT, 0, 5, '123E4'];

    $token = lex_one('123e-4');
    is_deeply [@$token{qw/kind start end value/}], [FLOAT, 0, 6, '123e-4'];

    $token = lex_one('123e+4');
    is_deeply [@$token{qw/kind start end value/}], [FLOAT, 0, 6, '123e+4'];

    $token = lex_one('-1.123e4');
    is_deeply [@$token{qw/kind start end value/}], [FLOAT, 0, 8, '-1.123e4'];

    $token = lex_one('-1.123E4');
    is_deeply [@$token{qw/kind start end value/}], [FLOAT, 0, 8, '-1.123E4'];

    $token = lex_one('-1.123e-4');
    is_deeply [@$token{qw/kind start end value/}], [FLOAT, 0, 9, '-1.123e-4'];

    $token = lex_one('-1.123e+4');
    is_deeply [@$token{qw/kind start end value/}], [FLOAT, 0, 9, '-1.123e+4'];

    $token = lex_one('-1.123e4567');
    is_deeply [@$token{qw/kind start end value/}], [FLOAT, 0, 11, '-1.123e4567'];
};

subtest 'lex reports useful number errors' => sub {
    eval { lex_one('00') };
    like $@, qr/Syntax Error GraphQL \(1:2\) Invalid number, unexpected digit after 0: "0"\./;

    eval { lex_one('+1') };
    like $@, qr/Syntax Error GraphQL \(1:1\) Cannot parse the unexpected character "\+"\./;

    eval { lex_one('1.') };
    like $@, qr/Syntax Error GraphQL \(1:3\) Invalid number, expected digit but got: <EOF>\./;

    eval { lex_one('.123') };
    like $@, qr/Syntax Error GraphQL \(1:1\) Cannot parse the unexpected character "\."\./;

    eval { lex_one('1.A') };
    like $@, qr/Syntax Error GraphQL \(1:3\) Invalid number, expected digit but got: "A"\./;

    eval { lex_one('-A') };
    like $@, qr/Syntax Error GraphQL \(1:2\) Invalid number, expected digit but got: "A"\./;

    eval { lex_one('1.0e') };
    like $@, qr/Syntax Error GraphQL \(1:5\) Invalid number, expected digit but got: <EOF>\./;

    eval { lex_one('1.0eA') };
    like $@, qr/Syntax Error GraphQL \(1:5\) Invalid number, expected digit but got: "A"\./;
};

subtest 'lexes punctuation' => sub {
    my $token;

    $token = lex_one('!');
    is_deeply [@$token{qw/kind start end value/}], [BANG, 0, 1, undef];

    $token = lex_one('$');
    is_deeply [@$token{qw/kind start end value/}], [DOLLAR, 0, 1, undef];

    $token = lex_one('(');
    is_deeply [@$token{qw/kind start end value/}], [PAREN_L, 0, 1, undef];

    $token = lex_one(')');
    is_deeply [@$token{qw/kind start end value/}], [PAREN_R, 0, 1, undef];

    $token = lex_one('...');
    is_deeply [@$token{qw/kind start end value/}], [SPREAD, 0, 3, undef];

    $token = lex_one(':');
    is_deeply [@$token{qw/kind start end value/}], [COLON, 0, 1, undef];

    $token = lex_one('=');
    is_deeply [@$token{qw/kind start end value/}], [EQUALS, 0, 1, undef];

    $token = lex_one('@');
    is_deeply [@$token{qw/kind start end value/}], [AT, 0, 1, undef];

    $token = lex_one('[');
    is_deeply [@$token{qw/kind start end value/}], [BRACKET_L, 0, 1, undef];

    $token = lex_one(']');
    is_deeply [@$token{qw/kind start end value/}], [BRACKET_R, 0, 1, undef];

    $token = lex_one('{');
    is_deeply [@$token{qw/kind start end value/}], [BRACE_L, 0, 1, undef];

    $token = lex_one('|');
    is_deeply [@$token{qw/kind start end value/}], [PIPE, 0, 1, undef];

    $token = lex_one('}');
    is_deeply [@$token{qw/kind start end value/}], [BRACE_R, 0, 1, undef];
};

subtest 'lex reports useful unknown character error' => sub {
    eval { lex_one('..') };
    like $@, qr/Syntax Error GraphQL \(1:1\) Cannot parse the unexpected character "\."\./;

    eval { lex_one('?') };
    like $@, qr/Syntax Error GraphQL \(1:1\) Cannot parse the unexpected character "\?"\./;

    eval { lex_one("\x{203B}") };

    my $substr = substr($@, 0, 74);
    like $@, qr/Syntax Error GraphQL \(1:1\) Cannot parse the unexpected character "\\u203B"\./;

    eval { lex_one("\x{200b}") };
    like $@, qr/Syntax Error GraphQL \(1:1\) Cannot parse the unexpected character "\\u200B"\./;
};

subtest 'lex reports useful information for dashes in names' => sub {
    my $lexer = GraphQL::Language::Lexer->new(
        source => GraphQL::Language::Source->new(body => 'a-b')
    );

    my $first_token = $lexer->advance;
    is_deeply [@$first_token{qw/kind start end value/}], [NAME, 0, 1, 'a'];

    eval { $lexer->advance };
    like $@, qr/Syntax Error GraphQL \(1:3\) Invalid number, expected digit but got: "b"\./;
};

subtest 'produces double linked list of tokens, including comments' => sub {
    my $lexer = GraphQL::Language::Lexer->new(
        source => GraphQL::Language::Source->new(body => "{
            #comment
            field
        }")
    );

    my $startToken = $lexer->token;
    my $endToken;

    do {
        $endToken = $lexer->advance;
        # Lexer advances over ignored comment tokens to make writing parsers
        # easier, but will include them in the linked list result.
        isnt $endToken->kind, COMMENT;
    } while ($endToken->kind ne EOF);

    is $startToken->prev, undef;
    is $endToken->next, undef;

    my @tokens;
    for (my $tok = $startToken; $tok; $tok = $tok->next) {
        if (scalar(@tokens)) {
            # Tokens are double-linked, prev should point to last seen token.
            is_deeply $tok->prev, $tokens[scalar(@tokens)-1];
        }
        push @tokens, $tok;
    }

    my @kinds = map { $_->kind } @tokens;
    is_deeply \@kinds, [qw/<SOF> { Comment Name } <EOF>/];
};

done_testing;
