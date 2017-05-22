use strict;
use warnings;

use Test::More;
use JSON qw/encode_json/;

use GraphQL qw/:types/;
use GraphQL::Language::Parser qw/parse/;
use GraphQL::Execute qw/execute/;

my $schema = GraphQLSchema(
    query => GraphQLObjectType(
        name => 'TestType',
        fields => {
            a => { type => GraphQLString },
            b => { type => GraphQLString },
        },
    ),
);

my %data = (
    a => sub { 'a' },
    b => sub { 'b' },
);

sub execute_test_query {
    my $doc = shift;
    return execute($schema, parse($doc), \%data);
}

subtest 'works without directives' => sub {
    is_deeply execute_test_query('{ a, b }'), { data => { a => 'a', b => 'b' } },
        'basic query works';
};

subtest 'works on scalars' => sub {
    is_deeply execute_test_query('{ a, b @include(if: true) }'),
        { data => { a => 'a', b => 'b' } }, 'if true includes scalar';

    is_deeply execute_test_query('{ a, b @include(if: false) }'),
        { data => { a => 'a' } }, 'if false omits on scalar';

    is_deeply execute_test_query('{ a, b @skip(if: false) }'),
        { data => { a => 'a', b => 'b' } }, 'unless false includes scalar';

    is_deeply execute_test_query('{ a, b @skip(if: true) }'),
        { data => { a => 'a' } }, 'unless true omits scalar';
};

subtest 'works on fragment spreads' => sub {
    my $q;

    $q = <<'EOQ';
query Q {
  a
  ...Frag @include(if: false)
}
fragment Frag on TestType {
  b
}
EOQ
    is_deeply execute_test_query($q), { data => { a => 'a' } }, 'if false omits fragment spread';

    $q = <<'EOQ';
query Q {
  a
  ...Frag @include(if: true)
}
fragment Frag on TestType {
  b
}
EOQ
    is_deeply execute_test_query($q), { data => { a => 'a', b => 'b' } }, 'if true includes fragment spread';

    $q = <<'EOQ';
query Q {
  a
  ...Frag @skip(if: false)
}
fragment Frag on TestType {
  b
}
EOQ
    is_deeply execute_test_query($q), { data => { a => 'a', b => 'b' } }, 'unless false includes fragment spread';

    $q = <<'EOQ';
query Q {
  a
  ...Frag @skip(if: true)
}
fragment Frag on TestType {
  b
}
EOQ
    is_deeply execute_test_query($q), { data => { a => 'a' } }, 'unless true omits fragment spread';
};

subtest 'works on inline fragment' => sub {
    my $q;

    $q = <<'EOQ';
query Q {
  a
  ... on TestType @include(if: false) {
    b
  }
}
EOQ
    is_deeply execute_test_query($q), { data => { a => 'a' } },
        'if false omits inline fragment';

    $q = <<'EOQ';
query Q {
  a
  ... on TestType @include(if: true) {
    b
  }
}
EOQ
    is_deeply execute_test_query($q), { data => { a => 'a', b => 'b' } },
        'if true includes inline fragment' ;

    $q = <<'EOQ';
query Q {
  a
  ... on TestType @skip(if: false) {
    b
  }
}
EOQ
    is_deeply execute_test_query($q), { data => { a => 'a', b => 'b' } },
        'unless false includes inline fragment' ;

    $q = <<'EOQ';
query Q {
  a
  ... on TestType @skip(if: true) {
    b
  }
}
EOQ
    is_deeply execute_test_query($q), { data => { a => 'a' } },
        'unless true includes inline fragment' ;
};

subtest 'works on anonymous inline fragment' => sub {
    my $q;

    $q = <<'EOQ';
query Q {
  a
  ... @include(if: false) {
    b
  }
}
EOQ
    is_deeply execute_test_query($q), { data => { a => 'a' } },
        'if false omits anonymous inline fragment';

    $q = <<'EOQ';
query Q {
  a
  ... @include(if: true) {
    b
  }
}
EOQ
    is_deeply execute_test_query($q), { data => { a => 'a', b => 'b' } },
        'if true includes anonymous inline fragment';

    $q = <<'EOQ';
query Q {
  a
  ... @skip(if: false) {
    b
  }
}
EOQ
    is_deeply execute_test_query($q), { data => { a => 'a', b => 'b' } },
        'unless false includes anonymous inline fragment';

    $q = <<'EOQ';
query Q {
  a
  ... @skip(if: true) {
    b
  }
}
EOQ
    is_deeply execute_test_query($q), { data => { a => 'a' } },
        'unless true includes anonymous inline fragment';
};

subtest 'works with skip and include directives' => sub {
    is_deeply execute_test_query('{ a, b @include(if: true) @skip(if: false) }'),
        { data => { a => 'a', b => 'b' } }, 'include and no skip';

    is_deeply execute_test_query('{ a, b @include(if: true) @skip(if: true) }'),
        { data => { a => 'a' } }, 'include and skip';

    is_deeply execute_test_query('{ a, b @include(if: false) @skip(if: false) }'),
        { data => { a => 'a' } }, 'no include or skip';
};

done_testing;
