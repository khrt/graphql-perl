package GraphQL::Validator::Rules::FieldsOnCorrectType;

use strict;
use warnings;

use GraphQL::Util qw/
    suggestion_list
    quoted_or_list
/;

sub undefined_field_message {
    my ($field_name, $type, $suggested_type_names, $suggested_field_names) = @_;
    my $message = qq`Cannot query field "$field_name" on type "${ \$type->to_string }".`;

    if ($suggested_type_names) {
        my $suggestions = quoted_or_list($suggested_type_names);
        $message .= "Did you mean to use an inline fragment on $suggestions?";
    }
    elsif ($suggested_field_names) {
        my $suggestions = quoted_or_list($suggested_field_names);
        $message .= "Did you mean $suggestions?";
    }

    return $message;
}

# Fields on correct type
#
# A GraphQL document is only valid if all fields selected are defined by the
# parent type, or are an allowed meta field such as __typename.
sub fields_on_correct_type {
    my $context = shift;
    return {
        Field => sub {
            my $node = shift;
            my $type = $context->get_parent_type;

            if ($type) {
                my $field_def = $context->get_field_def;
                unless ($field_def) {
                    # This field doesn't exist, lets look for suggestions.
                    my $schema = $context->get_schema;
                    my $field_name = $node->{name}{value};

                    # First determine if there are any suggested types to
                    # condition on.
                    my $suggested_type_names = get_suggested_type_names(
                        $schema, $type, $field_name
                    );

                    # If there are no suggested types, then perhaps this was a type?
                    my $suggested_field_names = scalar(@$suggested_type_names) != 0
                        ? []
                        : get_suggested_field_names($schema, $type, $field_name);

                    # Report an error, including helpful suggestions.
                    $context->report_error(
                        undefined_field_message(
                            $field_name,
                            $type->name,
                            $suggested_type_names,
                            $suggested_field_names
                        ),
                        [$node]
                    );
                }
            }
            #TODO XXX? return??
        }
    }
}

# Go through all of the implementations of type, as well as the interfaces
# that they implement. If any of those types include the provided field,
# suggest them, sorted by how often the type is referenced,  starting
# with Interfaces.
sub get_suggested_type_names {
    my ($schema, $type, $field_name) = @_;

    if (is_abstract_type($type)) {
        my @suggested_object_types;
        my %interface_usage_count;

        for my $possible_type (@{ $schema->get_possible_types($type) }) {
            unless ($possible_type->get_fields->{ $field_name }) {
                return;
            }

            # This object type defines this field.
            push @suggested_object_types, $possible_type->name;

            for my $possible_interface (@{ $possible_type->get_interfaces }) {
                unless ($possible_interface->get_fields->{ $field_name }) {
                    return;
                }

                # This interface type defines this field.
                $interface_usage_count{ $possible_interface->name }++;
            }
        }

        # Suggest interface types based on how common they are.
        # TODO
        my @suggested_interface_types =
            sort { $interface_usage_count{$b} <=> $interface_usage_count{$a} }
            keys %interface_usage_count;

        # Suggest both interface and object types.
        return [@suggested_interface_types, @suggested_object_types];
    }

    # Otherwise, must be an Object type, which does not have possible fields.
    return;
}

# For the field name provided, determine if there are any similar field names
# that may be the result of a typo.
sub get_suggested_field_names {
    my ($schema, $type, $field_name) = @_;

    if ($type->isa('GraphQL::Type::Object')
        || $type->isa('GraphQL::Type::Interface'))
    {
        my $possible_field_names = keys %{ $type->get_fields };
        return suggestion_list($field_name, $possible_field_names);
    }

    # Otherwise, must be a Union type, which does not define fields.
    return;
}

1;

__END__
