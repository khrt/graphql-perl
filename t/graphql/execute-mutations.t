
use strict;
use warnings;

use Test::More;
use Test::Deep;
use JSON qw/encode_json/;

use GraphQL qw/:types/;
use GraphQL::Language::Parser qw/parse/;
use GraphQL::Execute qw/execute/;

{
    package NumberHolder;
    sub theNumber { shift->{the_number} };

    sub new {
        my ($class, $original_number) = @_;
        bless { the_number => $original_number }, $class;
    }

    package Root;
    sub number_holder { shift->{number_holder} };

    sub new {
        my ($class, $original_number) = @_;
        bless {
            number_holder => NumberHolder->new($original_number),
        }, $class;
    }

    sub immediately_change_the_number {
        my ($self, $new_number) = @_;
        $self->{number_holder}{the_number} = $new_number;
        return $self->number_holder;
    }

    sub fail_to_change_the_number {
        die "Cannot change the number\n";
    }
}

my $numberHolderType = GraphQLObjectType(
    fields => {
        theNumber => { type => GraphQLInt },
    },
    name => 'NumberHolder',
);

my $schema = GraphQLSchema(
    query => GraphQLObjectType(
        name => 'Query',
        fields => {
            numberHolder => { type => $numberHolderType },
        },
    ),
    mutation => GraphQLObjectType(
        name => 'Mutation',
        fields => {
            immediatelyChangeTheNumber => {
                type => $numberHolderType,
                args => { newNumber => { type => GraphQLInt } },
                resolve => sub {
                    my ($obj, $args) = @_;
                    return $obj->immediately_change_the_number($args->{newNumber});
                },
            },
            failToChangeTheNumber => {
                type => $numberHolderType,
                args => { newNumber => { type => GraphQLInt } },
                resolve => sub {
                    my ($obj, $args) = @_;
                    return $obj->fail_to_change_the_number($args->{newNumber});
                },
            },
        },
    ),
);

subtest 'evaluates mutations serially' => sub {
    my $doc = <<'EOQ';
mutation M {
  first: immediatelyChangeTheNumber(newNumber: 1) {
    theNumber
  },
  third: immediatelyChangeTheNumber(newNumber: 3) {
    theNumber
  }
  fifth: immediatelyChangeTheNumber(newNumber: 5) {
    theNumber
  }
}
EOQ

    my $result = execute($schema, parse($doc), Root->new(6));
    is_deeply $result, {
        data => {
            first => { theNumber => 1 },
            third => { theNumber => 3 },
            fifth => { theNumber => 5 },
        },
    };
};

subtest 'evaluates mutations correctly in the presence of a failed mutation' => sub {
    my $doc = <<'EOQ';
mutation M {
  first: immediatelyChangeTheNumber(newNumber: 1) {
    theNumber
  },
  third: failToChangeTheNumber(newNumber: 3) {
    theNumber
  }
  fifth: immediatelyChangeTheNumber(newNumber: 5) {
    theNumber
  }
}
EOQ

    my $result = execute($schema, parse($doc), Root->new(6));
    is_deeply $result->{data}, {
        first => { theNumber => 1 },
        third => undef, # null
        fifth => { theNumber => 5 },
    };
    is scalar(@{ $result->{errors} }), 1;
    is $result->{errors}[0]{message}, "Cannot change the number\n";
    is_deeply $result->{errors}[0]{locations}, [{ line => 5, column => 3 }];
};

done_testing;
