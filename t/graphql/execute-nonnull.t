
use strict;
use warnings;

use DDP;
use Test::More;
use Test::Deep;
use JSON qw/encode_json/;

use GraphQL qw/:types/;
use GraphQL::Execute qw/execute/;
use GraphQL::Language::Parser qw/parse/;
use GraphQL::Nullish qw/NULLISH/;

my $sync_error = bless { message => 'sync' }, 'GraphQL::Error';
my $nonnull_sync_error = bless { message => 'nonNullSync' }, 'GraphQL::Error';

my $throwing_data;
$throwing_data = {
    sync => sub { die $sync_error; },
    nonNullSync => sub { die $nonnull_sync_error; },
    nest => sub {
        return $throwing_data;
    },
    nonNullNest => sub {
        return $throwing_data;
    },
};

my $nulling_data;
$nulling_data = {
    sync => sub { NULLISH },
    nonNullSync => sub { NULLISH },
    nest => sub {
        return $nulling_data;
    },
    nonNullNest => sub {
        return $nulling_data;
    },
};

my $data_type;
$data_type = GraphQLObjectType(
    name => 'DataType',
    fields => sub { {
        sync => { type => GraphQLString },
        nonNullSync => { type => GraphQLNonNull(GraphQLString) },
        nest => { type => $data_type },
        nonNullNest => { type => GraphQLNonNull($data_type) },
    } },
);
my $schema = GraphQLSchema(
    query => $data_type,
);

subtest 'nulls a nullable field' => sub {
    my $doc = <<'EOQ';
      query Q {
        sync
      }
EOQ

    my $ast = parse($doc);

    cmp_deeply execute($schema, $ast, $throwing_data), {
        data => {
            sync => undef,
        },
        errors => [noclass(superhashof({
            message => $sync_error->{message},
            locations => [{ line => 2, column => 9 }]
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
            message => $nonnull_sync_error->{message},
            locations => [{ line => 3, column => 11 }]
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

    cmp_deeply execute($schema, $ast, $nulling_data), $expected;
};

subtest 'nulls a returned object that contains a non-nullable field that returns null' => sub {
    plan skip_all => 'TODO';

    my $doc = <<'EOQ';
      query Q {
        nest {
          nonNullSync
        }
      }
EOQ

    my $ast = parse($doc);
# p execute($schema, $ast, $nulling_data);
    cmp_deeply execute($schema, $ast, $nulling_data), {
        data => {
            nest => undef
        },
        errors => [noclass(superhashof({
            message => 'Cannot return null for non-nullable field DataType.nonNullSync.',
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
            message => $nonnull_sync_error->{message},
            locations => [{ line => 1, column => 17 }]
        }))]
    };
};

subtest 'nulls the top level if sync non-nullable field returns undef' => sub {
    plan skip_all => 'TODO';

    my $doc = <<'EOQ';
      query Q { nonNullSync }
EOQ

    cmp_deeply execute($schema, parse($doc), $nulling_data), {
        data => undef,
        errors => [noclass(superhashof({
            message => 'Cannot return undef for non-nullable field DataType.nonnulnull.',
            locations => [{ line => 2, column => 17 }],
        }))],
    };
};

done_testing;
