
use strict;
use warnings;

use FindBin '$Bin';
# use Test::Deep;
use Test::More;
# use Storable qw/dclone/;

use GraphQL::Language::Parser qw/parse/;
use GraphQL::Language::Printer qw/print_doc/;

open my $fh, '<:encoding(UTF-8)', "$Bin/kitchen-sink.graphql" or BAIL_OUT($!);
my $kitchen_sink = join '', <$fh>;
close $fh;

# subtest 'does not alter ast' => sub {
#     my $ast = parse($kitchen_sink);
#     my $ast_before = dclone($ast);
#     print_doc($ast);
#     cmp_deeply $ast, $ast_before;
# };

subtest 'prints minimal ast' => sub {
    my $ast = { kind => 'Field', name => { kind => 'Name', value => 'foo' } };
    is print_doc($ast), 'foo';
};

subtest 'produces helpful error messages' => sub {
    my $bad_ast1 = { random => 'Data' };
    eval { print_doc($bad_ast1) };
    is $@, "Invalid AST Node: {'random' => 'Data'}\n";
};

subtest 'correctly prints non-query operations without name' => sub {
    my $query_ast_shorthanded = parse('query { id, name }');
    is print_doc($query_ast_shorthanded), <<'EOS';
{
  id
  name
}
EOS

    my $mutation_ast = parse('mutation { id, name }');
    is print_doc($mutation_ast), <<'EOS';
mutation {
  id
  name
}
EOS

    my $query_ast_with_artifacts = parse(
      'query ($foo: TestType) @testDirective { id, name }'
    );
    is print_doc($query_ast_with_artifacts), <<'EOS';
query ($foo: TestType) @testDirective {
  id
  name
}
EOS

    my $mutation_ast_with_artifacts = parse(
      'mutation ($foo: TestType) @testDirective { id, name }'
    );
    is print_doc($mutation_ast_with_artifacts), <<'EOS';
mutation ($foo: TestType) @testDirective {
  id
  name
}
EOS
};

subtest 'prints kitchen sink' => sub {
    my $ast = parse($kitchen_sink);
    my $printed = print_doc($ast);
    is $printed, <<'EOS'
query queryName($foo: ComplexType, $site: Site = MOBILE) {
  whoever123is: node(id: [123, 456]) {
    id
    ... on User @defer {
      field2 {
        id
        alias: field1(first: 10, after: $foo) @include(if: $foo) {
          id
          ...frag
        }
      }
    }
    ... @skip(unless: $foo) {
      id
    }
    ... {
      id
    }
  }
}

mutation likeStory {
  like(story: 123) @defer {
    story {
      id
    }
  }
}

subscription StoryLikeSubscription($input: StoryLikeSubscribeInput) {
  storyLikeSubscribe(input: $input) {
    story {
      likers {
        count
      }
      likeSentence {
        text
      }
    }
  }
}

fragment frag on Friend {
  foo(size: $size, bar: $b, obj: {key: "value"})
}

{
  unnamed(truthy: true, falsey: false, nullish: null)
  query
}
EOS
};

done_testing;
