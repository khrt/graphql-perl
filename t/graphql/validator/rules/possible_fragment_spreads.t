
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../../..";
use harness qw/
    expect_passes_rule
    expect_fails_rule
/;

sub error {
    my ($fragName, $parentType, $fragType, $line, $column) = @_;
    return {
        message => GraphQL::Validator::Rule::PossibleFragmentSpreads::type_incompatible_spread_message($fragName, $parentType, $fragType),
        locations => [{ line => $line, column => $column }],
        path => undef,
    };
}

sub error_anon {
    my ($parentType, $fragType, $line, $column) = @_;
    return {
        message => GraphQL::Validator::Rule::PossibleFragmentSpreads::type_incompatible_anon_spread_message($parentType, $fragType),
        locations => [{ line => $line, column => $column }],
        path => undef,
    };
}

subtest 'of the same object' => sub {
    expect_passes_rule('PossibleFragmentSpreads', '
      fragment objectWithinObject on Dog { ...dogFragment }
      fragment dogFragment on Dog { barkVolume }
    ');
};

subtest 'of the same object with inline fragment' => sub {
    expect_passes_rule('PossibleFragmentSpreads', '
      fragment objectWithinObjectAnon on Dog { ... on Dog { barkVolume } }
    ');
};

subtest 'object into an implemented interface' => sub {
    expect_passes_rule('PossibleFragmentSpreads', '
      fragment objectWithinInterface on Pet { ...dogFragment }
      fragment dogFragment on Dog { barkVolume }
    ');
};

subtest 'object into containing union' => sub {
    expect_passes_rule('PossibleFragmentSpreads', '
      fragment objectWithinUnion on CatOrDog { ...dogFragment }
      fragment dogFragment on Dog { barkVolume }
    ');
};

subtest 'union into contained object' => sub {
    expect_passes_rule('PossibleFragmentSpreads', '
      fragment unionWithinObject on Dog { ...catOrDogFragment }
      fragment catOrDogFragment on CatOrDog { __typename }
    ');
};

subtest 'union into overlapping interface' => sub {
    expect_passes_rule('PossibleFragmentSpreads', '
      fragment unionWithinInterface on Pet { ...catOrDogFragment }
      fragment catOrDogFragment on CatOrDog { __typename }
    ');
};

subtest 'union into overlapping union' => sub {
    expect_passes_rule('PossibleFragmentSpreads', '
      fragment unionWithinUnion on DogOrHuman { ...catOrDogFragment }
      fragment catOrDogFragment on CatOrDog { __typename }
    ');
};

subtest 'interface into implemented object' => sub {
    expect_passes_rule('PossibleFragmentSpreads', '
      fragment interfaceWithinObject on Dog { ...petFragment }
      fragment petFragment on Pet { name }
    ');
};

subtest 'interface into overlapping interface' => sub {
    expect_passes_rule('PossibleFragmentSpreads', '
      fragment interfaceWithinInterface on Pet { ...beingFragment }
      fragment beingFragment on Being { name }
    ');
};

subtest 'interface into overlapping interface in inline fragment' => sub {
    expect_passes_rule('PossibleFragmentSpreads', '
      fragment interfaceWithinInterface on Pet { ... on Being { name } }
    ');
};

subtest 'interface into overlapping union' => sub {
    expect_passes_rule('PossibleFragmentSpreads', '
      fragment interfaceWithinUnion on CatOrDog { ...petFragment }
      fragment petFragment on Pet { name }
    ');
};

subtest 'different object into object' => sub {
    expect_fails_rule('PossibleFragmentSpreads', '
      fragment invalidObjectWithinObject on Cat { ...dogFragment }
      fragment dogFragment on Dog { barkVolume }
    ', [error('dogFragment', 'Cat', 'Dog', 2, 51)]);
};

subtest 'different object into object in inline fragment' => sub {
    expect_fails_rule('PossibleFragmentSpreads', '
      fragment invalidObjectWithinObjectAnon on Cat {
        ... on Dog { barkVolume }
      }
    ', [error_anon('Cat', 'Dog', 3, 9)]);
};

subtest 'object into not implementing interface' => sub {
    expect_fails_rule('PossibleFragmentSpreads', '
      fragment invalidObjectWithinInterface on Pet { ...humanFragment }
      fragment humanFragment on Human { pets { name } }
    ', [error('humanFragment', 'Pet', 'Human', 2, 54)]);
};

subtest 'object into not containing union' => sub {
    expect_fails_rule('PossibleFragmentSpreads', '
      fragment invalidObjectWithinUnion on CatOrDog { ...humanFragment }
      fragment humanFragment on Human { pets { name } }
    ', [error('humanFragment', 'CatOrDog', 'Human', 2, 55)]);
};

subtest 'union into not contained object' => sub {
    expect_fails_rule('PossibleFragmentSpreads', '
      fragment invalidUnionWithinObject on Human { ...catOrDogFragment }
      fragment catOrDogFragment on CatOrDog { __typename }
    ', [error('catOrDogFragment', 'Human', 'CatOrDog', 2, 52)]);
};

subtest 'union into non overlapping interface' => sub {
    expect_fails_rule('PossibleFragmentSpreads', '
      fragment invalidUnionWithinInterface on Pet { ...humanOrAlienFragment }
      fragment humanOrAlienFragment on HumanOrAlien { __typename }
    ', [error('humanOrAlienFragment', 'Pet', 'HumanOrAlien', 2, 53)]);
};

subtest 'union into non overlapping union' => sub {
    expect_fails_rule('PossibleFragmentSpreads', '
      fragment invalidUnionWithinUnion on CatOrDog { ...humanOrAlienFragment }
      fragment humanOrAlienFragment on HumanOrAlien { __typename }
    ', [error('humanOrAlienFragment', 'CatOrDog', 'HumanOrAlien', 2, 54)]);
};

subtest 'interface into non implementing object' => sub {
    expect_fails_rule('PossibleFragmentSpreads', '
      fragment invalidInterfaceWithinObject on Cat { ...intelligentFragment }
      fragment intelligentFragment on Intelligent { iq }
    ', [error('intelligentFragment', 'Cat', 'Intelligent', 2, 54)]);
};

subtest 'interface into non overlapping interface' => sub {
    expect_fails_rule('PossibleFragmentSpreads', '
      fragment invalidInterfaceWithinInterface on Pet {
        ...intelligentFragment
      }
      fragment intelligentFragment on Intelligent { iq }
    ', [error('intelligentFragment', 'Pet', 'Intelligent', 3, 9)]);
};

subtest 'interface into non overlapping interface in inline fragment' => sub {
    expect_fails_rule('PossibleFragmentSpreads', '
      fragment invalidInterfaceWithinInterfaceAnon on Pet {
        ...on Intelligent { iq }
      }
    ', [error_anon('Pet', 'Intelligent', 3, 9)]);
};

subtest 'interface into non overlapping union' => sub {
    expect_fails_rule('PossibleFragmentSpreads', '
      fragment invalidInterfaceWithinUnion on HumanOrAlien { ...petFragment }
      fragment petFragment on Pet { name }
    ', [error('petFragment', 'HumanOrAlien', 'Pet', 2, 62)]);
};

done_testing;
