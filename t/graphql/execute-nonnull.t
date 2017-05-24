
use strict;
use warnings;

use DDP;
use Test::More;
use Test::Deep;
use JSON qw/encode_json/;

use GraphQL qw/:types/;
use GraphQL::Language::Parser qw/parse/;
use GraphQL::Execute qw/execute/;

my $sync_error = bless { message => 'sync' }, 'GraphQL::Error';
my $nonundef_sync_error = bless { message => 'nonundefSync' }, 'GraphQL::Error';

my $throwing_data;
$throwing_data = {
    sync => sub { die $sync_error; },
    nonundefSync => sub { die $nonundef_sync_error; },
    nest => sub {
        return $throwing_data;
    },
    nonundefNest => sub {
        return $throwing_data;
    },
};

my $undefing_data;
$undefing_data = {
    sync => sub { undef },
    nonNullSync => sub { undef },
    nest => sub {
        return $undefing_data;
    },
    nonNullNest => sub {
        return $undefing_data;
    },
};

my $data_type;
$data_type = GraphQLObjectType(
    name => 'DataType',
    fields => sub {
        sync => { type => GraphQLString },
        nonNullSync => { type => GraphQLNonNull(GraphQLString) },
        nest => { type => $data_type },
        nonNullNest => { type => GraphQLNonNull($data_type) },
    }
);
my $schema = GraphQLSchema(
    query => $data_type
);

subtest 'nulls a nullable field' => sub {
    my $doc = <<'EOQ';
      query Q {
        sync
      }
EOQ

    my $ast = parse($doc);
    # p execute($schema, $ast, $throwing_data);

    cmp_deeply execute($schema, $ast, $throwing_data), {
        data => {
            sync => undef,
        },
        errors => [noclass(superhashof({
            message => $sync_error->{message},
            locations => [{ line => 3, column => 9 }]
        }))],
    };
};

subtest 'nulls a synchronously returned object that contains a non-nullable field that throws synchronously' => sub {
    my $doc = <<'EOQ';
      query Q {
        nest {
          nonNullSync,
        }
      }
EOQ

    my $ast = parse($doc);

    cmp_deeply execute($schema, $ast, $throwing_data), {
        data => {
            nest => undef
        },
        errors => [noclass(superhashof({
            message => $nonundef_sync_error->{message},
            locations => [{ line => 4, column => 11 }]
        }))],
    };
};


subtest 'nulls a nullable field that synchronously returns undef' => sub {
    my $doc = <<'EOQ';
      query Q {
        sync
      }
EOQ

    my $ast = parse($doc);

    my $expected = {
        data => {
            sync => undef,
        }
    };

    cmp_deeply execute($schema, $ast, $undefing_data), $expected;
};

subtest 'nulls a synchronously returned object that contains a non-nullable field that returns undef synchronously' => sub {
    my $doc = <<'EOQ';
      query Q {
        nest {
          nonNullSync,
        }
      }
EOQ

    my $ast = parse($doc);

    cmp_deeply execute($schema, $ast, $undefing_data), {
        data => {
            nest => undef
        },
        errors => [noclass(superhashof({
            message => 'Cannot return undef for non-nullable field DataType.nonNullSync.',
            locations => [{ line => 4, column => 11 }]
        }))],
    }
};


subtest 'nulls the top level if sync non-nullable field throws' => sub {
    my $doc = <<'EOQ';
      query Q { nonNullSync }
EOQ

    cmp_deeply execute($schema, parse($doc), $throwing_data), {
        data => undef,
        errors => [noclass(superhashof({
            message => $nonundef_sync_error->{message},
            locations => [{ line => 2, column => 17 }]
        }))]
    };
};

subtest 'nulls the top level if sync non-nullable field returns undef' => sub {
    my $doc = <<'EOQ';
      query Q { nonNullSync }
EOQ

    cmp_deeply execute($schema, parse($doc), $undefing_data), {
        data => undef,
        errors => [noclass(superhashof({
            message => 'Cannot return undef for non-nullable field DataType.nonnulnull.',
            locations => [{ line => 2, column => 17 }],
        }))],
    };
};

done_testing;
