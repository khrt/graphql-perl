package GraphQL::Validator::Context;

use strict;
use warnings;

use Carp qw/longmess/;
use DDP {
    # indent => 2,
    # max_depth => 5,
    # index => 0,
    # class => {
    #     internals => 0,
    #     show_methods => 'none',
    # },
    # filters => {
    #     'GraphQL::Language::Token' => sub { shift->desc },
    #     'GraphQL::Language::Source' => sub { shift->name },

    #     'GraphQL::Type::Enum'        => sub { shift->to_string },
    #     'GraphQL::Type::InputObject' => sub { shift->to_string },
    #     'GraphQL::Type::Interface'   => sub { shift->to_string },
    #     'GraphQL::Type::List'        => sub { shift->to_string },
    #     'GraphQL::Type::NonNull'     => sub { shift->to_string },
    #     'GraphQL::Type::Object'      => sub { shift->to_string },
    #     'GraphQL::Type::Scalar'      => sub { shift->to_string },
    #     'GraphQL::Type::Union'       => sub { shift->to_string },
    # },
    # caller_info => 0,
};
use List::Util qw/reduce/;

use GraphQL::Language::Parser;
use GraphQL::Language::Visitor qw/
    visit
    visit_with_typeinfo
/;

sub Kind { 'GraphQL::Language::Parser' }

sub new {
    my ($class, %args) = @_;

    my $self = bless {
        schema => $args{schema},
        ast => $args{ast},
        type_info => $args{type_info},

        errors => [],
        # fragments => {},
        fragment_spreads => {},
        recursively_referenced_fragments => {},
        variable_usages => {},
        recursive_variable_usages => {},
    }, $class;

    return $self;
}

sub report_error {
    my ($self, $error) = @_;
    push @{ $self->{errors} }, $error;
}

sub get_errors { shift->{errors} }
sub get_schema { shift->{schema} }
sub get_document { shift->{ast} }

sub get_fragment {
    my ($self, $name) = @_;

    my $fragments = $self->{fragments};
    if (!$fragments) {
        $self->{fragments} = $fragments = reduce {
            if ($b->{kind} eq Kind->FRAGMENT_DEFINITION) {
                $a->{ $b->{name}{value} } = $b;
            }
            $a;
        } {}, @{ $self->get_document->{definitions} };
    }

    return $fragments->{ $name };
}

sub get_fragment_spreads {
    my ($self, $node) = @_;

    # print 'node '; p $node;
    # warn longmess 'spreads';

    my $spreads = $self->{fragment_spreads}{$node};
    if (!$spreads) {
        $spreads = [];

        my @sets_to_visit = ($node);
        while (@sets_to_visit) {
            my $set = pop @sets_to_visit;

            for my $selection (@{ $set->{selections} }) {
                if ($selection->{kind} eq Kind->FRAGMENT_SPREAD) {
                    push @$spreads, $selection;
                }
                elsif ($selection->{selection_set}) {
                    push @sets_to_visit, $selection->{selection_set};
                }
            }
        }

        $self->{fragment_spreads}{ $node } = $spreads;
    }

    return $spreads;
}

sub get_recursively_referenced_fragments {
    my ($self, $operation) = @_;

    my $fragments = $self->{recursively_referenced_fragments}{ $operation };
    if (!$fragments) {
        $fragments = [];

        my %collected_names;
        my @nodes_to_visit = ($operation->{selection_set});
        while (@nodes_to_visit) {
            my $node = pop @nodes_to_visit;
            my $spreads = $self->get_fragment_spreads($node);

            for my $spread (@$spreads) {
                my $frag_name = $spread->{name}{value};

                unless ($collected_names{ $frag_name }) {
                    $collected_names{ $frag_name } = 1;
                    my $fragment = $self->get_fragment($frag_name);

                    if ($fragment) {
                        push @$fragments, $fragment;
                        push @nodes_to_visit, $fragment->{selection_set};
                    }
                }
            }
        }

        $self->{recursively_referenced_fragments}{ $operation } = $fragments;
    }

    return $fragments;
}

sub get_variable_usages {
    my ($self, $node) = @_;

    my $usages = $self->{variable_usages}{ $node };
    if (!$usages) {
        my @new_usages;
        my $type_info = GraphQL::TypeInfo->new($self->{schema});

        visit($node, visit_with_typeinfo($type_info, {
            VariableDefinition => sub { 0 },
            Variable => sub {
                my (undef, $variable) = @_;
                push @new_usages, { node => $variable, type => $type_info->get_input_type };
                return;
            }
        }));

        $usages = \@new_usages;
        $self->{_variable_usages}{ $node } = $usages;
    }

    return $usages;
}

sub get_recursive_variable_usages {
    my ($self, $operation) = @_;

    my $usages = $self->{recursive_variable_usages}{ $operation };
    if (!$usages) {
        $usages = $self->get_variable_usages($operation);

        my $fragments = $self->get_recursively_referenced_fragments($operation);
        for my $fragment (@$fragments) {
            push @$usages, @{ $self->get_variable_usages($fragment) };
        }

        $self->{recursive_variable_usages}{ $operation } = $usages;
    }

    return $usages;
}

sub get_type { shift->{type_info}->get_type }
sub get_parent_type { shift->{type_info}->get_parent_type }
sub get_input_type { shift->{type_info}->get_input_type }
sub get_field_def { shift->{type_info}->get_field_def }
sub get_directive { shift->{type_info}->get_directive }
sub get_argument { shift->{type_info}->get_argument }

1;

__END__
