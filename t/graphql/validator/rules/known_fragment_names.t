
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../../..";
use harness qw/
    expect_passes_rule
    expect_fails_rule
/;

sub undef_frag {
    my ($frag_name, $line, $column) = @_;
    return {
        message => GraphQL::Validator::Rule::KnownFragmentNames::unknown_fragment_message($frag_name),
        locations => [ { line => $line, column => $column } ],
        path => undef,
    };
}

subtest 'known fragment names are valid' => sub {
    expect_passes_rule('KnownFragmentNames', '
      {
        human(id: 4) {
          ...HumanFields1
          ... on Human {
            ...HumanFields2
          }
          ... {
            name
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

subtest 'unknown fragment names are invalid' => sub {
    expect_fails_rule('KnownFragmentNames', '
      {
        human(id: 4) {
          ...UnknownFragment1
          ... on Human {
            ...UnknownFragment2
          }
        }
      }
      fragment HumanFields on Human {
        name
        ...UnknownFragment3
      }
    ', [
      undef_frag('UnknownFragment1', 4, 14),
      undef_frag('UnknownFragment2', 6, 16),
      undef_frag('UnknownFragment3', 12, 12)
    ]);
};

done_testing;
