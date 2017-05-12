
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../../..";
use harness qw/
    expect_passes_rule
    expect_fails_rule
/;

sub unused_frag {
    my ($frag_name, $line, $column) = @_;
    return {
        message => GraphQL::Validator::Rule::NoUnusedFragments::unused_frag_message($frag_name),
        locations => [{ line => $line, column => $column }],
        path => undef,
    };
}

subtest 'all fragment names are used' => sub {
    expect_passes_rule('NoUnusedFragments', '
      {
        human(id: 4) {
          ...HumanFields1
          ... on Human {
            ...HumanFields2
          }
        }
      }
      fragment HumanFields1 on Human {
        name
        ...HumanFields3
      }
      fragment HumanFields2 on Human {
        name
      }
      fragment HumanFields3 on Human {
        name
      }
    ');
};

subtest 'all fragment names are used by multiple operations' => sub {
    expect_passes_rule('NoUnusedFragments', '
      query Foo {
        human(id: 4) {
          ...HumanFields1
        }
      }
      query Bar {
        human(id: 4) {
          ...HumanFields2
        }
      }
      fragment HumanFields1 on Human {
        name
        ...HumanFields3
      }
      fragment HumanFields2 on Human {
        name
      }
      fragment HumanFields3 on Human {
        name
      }
    ');
};

subtest 'contains unknown fragments' => sub {
    expect_fails_rule('NoUnusedFragments', '
      query Foo {
        human(id: 4) {
          ...HumanFields1
        }
      }
      query Bar {
        human(id: 4) {
          ...HumanFields2
        }
      }
      fragment HumanFields1 on Human {
        name
        ...HumanFields3
      }
      fragment HumanFields2 on Human {
        name
      }
      fragment HumanFields3 on Human {
        name
      }
      fragment Unused1 on Human {
        name
      }
      fragment Unused2 on Human {
        name
      }
    ', [
      unused_frag('Unused1', 22, 7),
      unused_frag('Unused2', 25, 7),
    ]);
};

subtest 'contains unknown fragments with ref cycle' => sub {
    expect_fails_rule('NoUnusedFragments', '
      query Foo {
        human(id: 4) {
          ...HumanFields1
        }
      }
      query Bar {
        human(id: 4) {
          ...HumanFields2
        }
      }
      fragment HumanFields1 on Human {
        name
        ...HumanFields3
      }
      fragment HumanFields2 on Human {
        name
      }
      fragment HumanFields3 on Human {
        name
      }
      fragment Unused1 on Human {
        name
        ...Unused2
      }
      fragment Unused2 on Human {
        name
        ...Unused1
      }
    ', [
      unused_frag('Unused1', 22, 7),
      unused_frag('Unused2', 26, 7),
    ]);
};

subtest 'contains unknown and undef fragments' => sub {
    expect_fails_rule('NoUnusedFragments', '
      query Foo {
        human(id: 4) {
          ...bar
        }
      }
      fragment foo on Human {
        name
      }
    ', [
      unused_frag('foo', 7, 7),
    ]);
};

done_testing;
