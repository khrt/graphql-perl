
use strict;
use warnings;

use DDP;
use Test::More;
use Test::Deep;
use JSON qw/encode_json/;

use GraphQL qw/graphql :types/;
use GraphQL::Language::Parser qw/parse/;
use GraphQL::Execute qw/execute/;

subtest 'executes using a schema' => sub {
    my ($johnSmith, $article);
    $article = sub {
        my $id = shift;

        return {
            id => $id,
            isPublished => 'true',
            author => $johnSmith,
            title => "My Article $id",
            body => 'This is a post',
            hidden => 'This data is not exposed in the schema',
            keywords => ['foo', 'bar', 1, 1, undef]
        };
    };

    $johnSmith = {
        id => 123,
        name => 'John Smith',
        pic => sub {
            my ($width, $height) = @_;
            get_pic(123, $width, $height);
        },
        recentArticle => $article->(1),
    };

    my $BlogImage = GraphQLObjectType(
        name => 'Image',
        fields => {
            url => { type => GraphQLString },
            width => { type => GraphQLInt },
            height => { type => GraphQLInt },
        },
    );

    my $BlogArticle;
    my $BlogAuthor = GraphQLObjectType(
        name => 'Author',
        fields => sub { {
            id => { type => GraphQLString },
            name => { type => GraphQLString },
            pic => {
                args => {
                    width  => { type => GraphQLInt },
                    height => { type => GraphQLInt }
                },
                type => $BlogImage,
                resolve => sub {
                    my ($obj, $args) = @_;
                    $obj->{pic}->($args->{width}, $args->{height})
                },
            },
            recentArticle => { type => $BlogArticle }
        } },
    );

    $BlogArticle = GraphQLObjectType(
        name => 'Article',
        fields => {
            id => { type => GraphQLNonNull(GraphQLString) },
            isPublished => { type => GraphQLBoolean },
            author => { type => $BlogAuthor },
            title => { type => GraphQLString },
            body => { type => GraphQLString },
            keywords => { type => GraphQLList(GraphQLString) }
        }
    );

    my $BlogQuery = GraphQLObjectType(
        name => 'Query',
        fields => {
            article => {
                type => $BlogArticle,
                args => { id => { type => GraphQLID } },
                resolve => sub {
                    my (undef, $args) = @_;
                    $article->($args->{id});
                },
            },
            feed => {
                type => GraphQLList($BlogArticle),
                resolve => sub {
                    [
                        $article->(1),
                        $article->(2),
                        $article->(3),
                        $article->(4),
                        $article->(5),
                        $article->(6),
                        $article->(7),
                        $article->(8),
                        $article->(9),
                        $article->(10)
                    ]
                },
            },
        }
    );

    my $BlogSchema = GraphQLSchema(
        query => $BlogQuery
    );

    sub get_pic {
        my ($uid, $width, $height) = @_;
        return {
            url => "cdn://$uid",
            width => "$width",
            height => "$height",
        };
    }

    my $request = <<'EOQ';
      {
        feed {
          id,
          title
        },
        article(id: "1") {
          ...articleFields,
          author {
            id,
            name,
            pic(width: 640, height: 480) {
              url,
              width,
              height
            },
            recentArticle {
              ...articleFields,
              keywords
            }
          }
        }
      }

      fragment articleFields on Article {
        id,
        isPublished,
        title,
        body,
        hidden,
        notdefined
      }
EOQ

    # Note: this is intentionally not validating to ensure appropriate
    # behavior occurs when executing an invalid query.
    is_deeply execute($BlogSchema, parse($request)), {
        data => {
            feed => [
                { id => '1', title => 'My Article 1' },
                { id => '2', title => 'My Article 2' },
                { id => '3', title => 'My Article 3' },
                { id => '4', title => 'My Article 4' },
                { id => '5', title => 'My Article 5' },
                { id => '6', title => 'My Article 6' },
                { id => '7', title => 'My Article 7' },
                { id => '8', title => 'My Article 8' },
                { id => '9', title => 'My Article 9' },
                { id => '10', title => 'My Article 10' }
            ],
            article => {
                id => '1',
                isPublished => 1,
                title => 'My Article 1',
                body => 'This is a post',

                author => {
                    id => '123',
                    name => 'John Smith',
                    pic => {
                        url => 'cdn://123',
                        width => 640,
                        height => 480
                    },
                    recentArticle => {
                        id => '1',
                        isPublished => 1,
                        title => 'My Article 1',
                        body => 'This is a post',
                        keywords => ['foo', 'bar', '1', '1', undef],
                    }
                }
            }
        }
    };
};

done_testing;
