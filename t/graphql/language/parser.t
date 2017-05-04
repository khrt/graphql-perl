
use strict;
use warnings;

use DDP {
    # indent  => 2,
    # index   => 0,
    # class   => { internals => 1, show_methods => 'none', },
    #     filters => {
    #         'GraphQL::Language::Token' => sub {
    #             my $t = shift->inspect;
    #             sprintf "{ %s }", join ', ', map { sprintf "%s: %s", $_, $t->{$_} // 'undef' } keys %$t;
    #         },
    #         'GraphQL::Language::Source' => sub { '...' },
    #     },
};
use Test::Deep;
use Test::More;
use FindBin '$Bin';

use GraphQL::Language::Source;
use GraphQL::Language::Token;
use GraphQL::Language::Lexer;
use GraphQL::Language::Parser qw/parse parse_value parse_type/;

sub TokenKind { 'GraphQL::Language::Token' }
sub Kind { 'GraphQL::Language::Parser' }

subtest 'parse provides useful errors' => sub {
    eval { parse('{') };
    is $@, <<EOM;
Syntax Error GraphQL (1:2) Expected Name, found <EOF>

1: {
    ^
EOM
    # TODO
    # expect(caughtError.positions).to.deep.equal([ 1 ]);
    # expect(caughtError.locations).to.deep.equal([
    #   { line: 1, column: 2 }
    # ]);

    eval { parse(
"{ ...MissingOn }
fragment MissingOn Type
")
    };
    like $@, qr/Syntax Error GraphQL \(2:20\) Expected "on", found Name "Type"/;

    eval { parse('{ field: {} }') };
    like $@, qr/Syntax Error GraphQL \(1:10\) Expected Name, found \{/;

    eval { parse('notanoperation Foo { field }') };
    like $@, qr/Syntax Error GraphQL \(1:1\) Unexpected Name "notanoperation"/;

    eval { parse('...') };
    like $@, qr/Syntax Error GraphQL \(1:1\) Unexpected \.\.\./;
};

subtest 'parse provides useful error when using source' => sub {
    eval {
        parse(
            GraphQL::Language::Source->new(
                body => 'query',
                name => 'MyQuery.graphql'
            )
        );
    };
    like $@, qr/Syntax Error MyQuery\.graphql \(1:6\) Expected \{, found <EOF>/;
};

subtest 'parses variable inline values' => sub {
    eval { parse('{ field(complex: { a: { b: [ $var ] } }) }') };
    is $@, '';
};

subtest 'parses constant default values' => sub {
    eval { parse('query Foo($x: Complex = { a: { b: [ $var ] } }) { field }') };
    like $@, qr/Syntax Error GraphQL \(1:37\) Unexpected \$/;
};

subtest 'does not accept fragments named "on"' => sub {
    eval { parse('fragment on on on { on }') };
    like $@, qr/Syntax Error GraphQL \(1:10\) Unexpected Name "on"/;
};

subtest 'does not accept fragments spread of "on"' => sub {
    eval { parse('{ ...on }') };
    like $@, qr/Syntax Error GraphQL \(1:9\) Expected Name, found }/;
};

subtest 'parses multi-byte characters' => sub {
    # NOTE: \u0A0A could be naively interpretted as two line-feed chars.
    my $result = parse(qq/
        # This comment has a \x{0A0A} multi-byte character.
        { field(arg: "Has a \x{0A0A} multi-byte character.") }
    /);

    cmp_deeply $result, superhashof({
        definitions => [superhashof({
            selection_set => superhashof({
                selections => [superhashof({
                    arguments => [superhashof({
                        value => superhashof({
                            kind => Kind->STRING,
                            value => "Has a \x{0A0A} multi-byte character."
                        })
                    })]
                })]
            })
        })]
    });
};

subtest 'parses kitchen sink' => sub {
    open my $fh, '<:encoding(UTF-8)', "$Bin/kitchen-sink.graphql" or BAIL_OUT($!);
    my $kitchen_sink = join '', <$fh>;
    close $fh;

    eval { parse($kitchen_sink) };
    is $@, '';
};

subtest 'allows non-keywords anywhere a Name is allowed' => sub {
    my @non_keywords = (qw/
        on
        fragment
        query
        mutation
        subscription
        true
        false
        /);

    for my $keyword (@non_keywords) {
        my $fragment_name = $keyword;

        # You can't define or reference a fragment named `on`.
        if ($keyword eq 'on') {
            $fragment_name = 'a';
        }

        my $query = <<EOQ;
query $keyword {
... $fragment_name
... on $keyword { field }
}
fragment $fragment_name on Type {
$keyword($keyword: \$$keyword) \@$keyword($keyword: $keyword)
}
EOQ

        eval { parse($query) };
        is $@, '';
    }
};

subtest 'parses anonymous mutation operations' => sub {
    eval {
        parse('
            mutation {
            mutationField
            }
            ')
    };
    is $@, '';
};

subtest 'parses anonymous subscription operations' => sub {
    eval {
        parse('
            subscription {
            subscriptionField
            }
            ')
    };
    is $@, '';
};

subtest 'parses named mutation operations' => sub {
    eval {
        parse('
            mutation Foo {
            mutationField
            }
            ');
    };
    is $@, '';
};

subtest 'parses named subscription operations' => sub {
    eval {
        parse('
            subscription Foo {
            subscriptionField
            }
            ')
    };
    is $@, '';
};

subtest 'creates ast' => sub {
    my $source = GraphQL::Language::Source->new(body => "{
  node(id: 4) {
    id,
    name
  }
}
");
    my $result = parse($source);

    cmp_deeply $result, {
        kind => Kind->DOCUMENT,
        loc => superhashof({ start => 0, end => 41 }),
        definitions => [
            {
                kind => Kind->OPERATION_DEFINITION,
                loc => superhashof({ start => 0, end => 40 }),
                operation => 'query',
                name => undef,
                variable_definitions => undef,
                directives => [],
                selection_set => {
                    kind => Kind->SELECTION_SET,
                    loc => superhashof({ start => 0, end => 40 }),
                    selections => [
                        {
                            kind => Kind->FIELD,
                            loc => superhashof({ start => 4, end => 38 }),
                            alias => undef,
                            name => {
                                kind => Kind->NAME,
                                loc => superhashof({ start => 4, end => 8 }),
                                value => 'node',
                            },
                            arguments => [
                                {
                                    kind => Kind->ARGUMENT,
                                    name => {
                                        kind => Kind->NAME,
                                        loc => superhashof({ start => 9, end => 11 }),
                                        value => 'id',
                                    },
                                    value => {
                                        kind => Kind->INT,
                                        loc => superhashof({ start => 13, end => 14 }),
                                        value => '4',
                                    },
                                    loc => superhashof({ start => 9, end => 14 })
                                }
                            ],
                            directives => [],
                            selection_set => {
                                kind => Kind->SELECTION_SET,
                                loc => superhashof({ start => 16, end => 38 }),
                                selections => [
                                    {
                                        kind => Kind->FIELD,
                                        loc => superhashof({ start => 22, end => 24 }),
                                        alias => undef,
                                        name => {
                                            kind => Kind->NAME,
                                            loc => superhashof({ start => 22, end => 24 }),
                                            value => 'id',
                                        },
                                        arguments => [],
                                        directives => [],
                                        selection_set => undef,
                                    },
                                    {
                                        kind => Kind->FIELD,
                                        loc => superhashof({ start => 30, end => 34 }),
                                        alias => undef,
                                        name => {
                                            kind => Kind->NAME,
                                            loc => superhashof({ start => 30, end => 34 }),
                                            value => 'name',
                                        },
                                        arguments => [],
                                        directives => [],
                                        selection_set => undef,
                                    }
                                ]
                            }
                        }
                    ]
                }
            }
        ]
    };
};

subtest 'allows parsing without source location information' => sub {
    my $source = GraphQL::Language::Source->new(body => '{ id }');
    my $result = parse($source, { no_location => 1 });
    is $result->{loc}, undef;
};

subtest 'contains location information that only stringifys start/end' => sub {
    my $source = GraphQL::Language::Source->new(body => '{ id }');
    my $result = parse($source);
    cmp_deeply $result->{loc}, superhashof({ start => 0, end => 6 });

    # NB: util.inspect used to suck
    # TODO: if (parseFloat(process.version.slice(1)) > 0.10) {
    # TODO:     expect(require('util').inspect(result.loc)).to.equal(
    # TODO:         '{ start: 0, end: 6 }'
    # TODO:     );
    # TODO: }
};

subtest 'contains references to source' => sub {
    my $source = GraphQL::Language::Source->new(body => '{ id }');
    my $result = parse($source);
    is_deeply $result->{loc}{source}, $source;
};

subtest 'contains references to start and end tokens' => sub {
    my $source = GraphQL::Language::Source->new(body => '{ id }');
    my $result = parse($source);
    is $result->{loc}{start_token}->kind, TokenKind->SOF;
    is $result->{loc}{end_token}->kind, TokenKind->EOF;
};

subtest 'parse_value' => sub {
    subtest 'parses null value' => sub {
        my $value = parse_value('null');
        cmp_deeply $value, {
            kind => Kind->NULL,
            loc => superhashof({ start => 0, end => 4 }),
        };
    };

    subtest 'parses list values' => sub {
        my $value = parse_value('[123 "abc"]');
        cmp_deeply $value, {
            kind => Kind->LIST,
            loc => superhashof({ start => 0, end => 11 }),
            values => [
                {
                    kind => Kind->INT,
                    loc => superhashof({ start => 1, end => 4 }),
                    value => '123',
                },
                {
                    kind => Kind->STRING,
                    loc => superhashof({ start => 5, end => 10 }),
                    value => 'abc',
                }
            ],
        };
    };
};

subtest 'parse_type' => sub {
    subtest 'parses well known types' => sub {
        my $type = parse_type('String');
        cmp_deeply $type, {
            kind => Kind->NAMED_TYPE,
            loc => superhashof({ start => 0, end => 6 }),
            name => {
                kind => Kind->NAME,
                loc => superhashof({ start => 0, end => 6 }),
                value => 'String',
            }
        };
    };

    subtest 'parses custom types' => sub {
        my $type = parse_type('MyType');
        cmp_deeply $type, {
            kind => Kind->NAMED_TYPE,
            loc => superhashof({ start => 0, end => 6 }),
            name => {
                kind => Kind->NAME,
                loc => superhashof({ start => 0, end => 6 }),
                value => 'MyType',
            }
        };
    };

    subtest 'parses list types' => sub {
        my $type = parse_type('[MyType]');
        cmp_deeply $type, {
            kind => Kind->LIST_TYPE,
            loc => superhashof({ start => 0, end => 8 }),
            type => {
                kind => Kind->NAMED_TYPE,
                loc => superhashof({ start => 1, end => 7 }),
                name => {
                    kind => Kind->NAME,
                    loc => superhashof({ start => 1, end => 7 }),
                    value => 'MyType',
                },
            }
        };
    };

    subtest 'parses non-null types' => sub {
        my $type = parse_type('MyType!');
        cmp_deeply $type, {
            kind => Kind->NON_NULL_TYPE,
            loc => superhashof({ start => 0, end => 7 }),
            type => {
                kind => Kind->NAMED_TYPE,
                loc => superhashof({ start => 0, end => 6 }),
                name => {
                    kind => Kind->NAME,
                    loc => superhashof({ start => 0, end => 6 }),
                    value => 'MyType',
                },
            }
        };
    };

    subtest 'parses nested types' => sub {
        my $type = parse_type('[MyType!]');
        cmp_deeply $type, {
            kind => Kind->LIST_TYPE,
            loc => superhashof({ start => 0, end => 9 }),
            type => {
                kind => Kind->NON_NULL_TYPE,
                loc => superhashof({ start => 1, end => 8 }),
                type => {
                    kind => Kind->NAMED_TYPE,
                    loc => superhashof({ start => 1, end => 7 }),
                    name => {
                        kind => Kind->NAME,
                        loc => superhashof({ start => 1, end => 7 }),
                        value => 'MyType',
                    },
                },
            }
        };
    };
};

done_testing;
