
use strict;
use warnings;

use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/..";
use harness qw/
    $test_schema
/;

use GraphQL::Language::Parser qw/parse/;
use GraphQL::TypeInfo;
use GraphQL::Validator qw/validate SPECIFIED_RULES/;

sub expect_valid {
    my ($schema, $query_string) = @_;
    my $errors = validate($schema, parse($query_string));
    is_deeply $errors, [], 'Should validate';
}

subtest 'validates queries' => sub {
    expect_valid($test_schema, '
      query {
        catOrDog {
          ... on Cat {
            furColor
          }
          ... on Dog {
            isHousetrained
          }
        }
      }
    ');
};

# NOTE: experimental
subtest 'validates using a custom TypeInfo' => sub {
    # This TypeInfo will never return a valid field.
    my $type_info = GraphQL::TypeInfo->new($test_schema, sub { 0 });

    my $ast = parse('
      query {
        catOrDog {
          ... on Cat {
            furColor
          }
          ... on Dog {
            isHousetrained
          }
        }
      }
    ');

    my $errors = validate($test_schema, $ast, SPECIFIED_RULES, $type_info);
    my @error_messages = map { $_->{message} } @$errors;

    is_deeply \@error_messages, [
        'Cannot query field "catOrDog" on type "QueryRoot". Did you mean "catOrDog"?',
        'Cannot query field "furColor" on type "Cat". Did you mean "furColor"?',
        'Cannot query field "isHousetrained" on type "Dog". Did you mean "isHousetrained"?',
    ];
};

done_testing;
