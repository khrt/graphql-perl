package GraphQL::Execute;

use strict;
use warnings;

use constant {
    NULLISH => {},
};

use Exporter qw/import/;

our @EXPORT_OK = (qw/
    execute
/);

use feature 'say';
use Carp 'longmess';
use DDP {
    indent => 2,
    max_depth => 5,
    index => 0,
    class => {
        internals => 1,
        show_methods => 'none',
    },
    filters => {
        'GraphQL::Language::Token' => sub { shift->desc },
        'GraphQL::Language::Source' => sub { shift->name },

        'GraphQL::Type::Enum'        => sub { shift->to_string },
        'GraphQL::Type::InputObject' => sub { shift->to_string },
        'GraphQL::Type::Interface'   => sub { shift->to_string },
        'GraphQL::Type::List'        => sub { shift->to_string },
        'GraphQL::Type::NonNull'     => sub { shift->to_string },
        'GraphQL::Type::Object'      => sub { shift->to_string },
        'GraphQL::Type::Scalar'      => sub { shift->to_string },
        'GraphQL::Type::Union'       => sub { shift->to_string },
        },
    caller_info => 0,
};
use List::Util qw/reduce/;
use Scalar::Util qw/blessed reftype/;

use GraphQL::Error qw/
    located_error
    GraphQLError
/;
use GraphQL::Language::Parser;
use GraphQL::Type qw/:all/;
use GraphQL::Type::Introspection qw/
    SchemaMetaFieldDef
    TypeMetaFieldDef
    TypeNameMetaFieldDef
/;
use GraphQL::Util qw/
    stringify_type
    find type_from_ast
/;
use GraphQL::Util::Type qw/
    is_abstract_type
    is_leaf_type
/;
use GraphQL::Util::Values qw/
    get_variable_values
    get_argument_values
/;

sub Kind { 'GraphQL::Language::Parser' }

# Implements the "Evaluating requests" section of the GraphQL specification.
#
# Returns a data object.
#
# If the arguments to this function do not result in a legal execution context,
# a GraphQLError will be thrown immediately explaining the invalid input.
sub execute {
    my ($schema, $document, $root_value, $context_value, $variable_values,
        $operation_name) = @_;

    die "Must provide schema\n" unless $schema;
    die "Must provide document\n" unless $document;

    die "Schema must be an instance of GraphQLSchema.\n"
        unless $schema->isa('GraphQL::Type::Schema');

    # Variables, if provided, must be an object.
    die "Variables must be provided as an HASH where each property is a variable value.\n"
        if $variable_values && ref($variable_values) ne 'HASH';

    # If a valid context cannot be created due to incorrect arguments,
    # this will throw an error.
    my $context = build_execution_context(
        $schema,
        $document,
        $root_value,
        $context_value,
        $variable_values,
        $operation_name
    );

    # Return data described by
    # The "Response" section of the GraphQL specification.
    #
    # If errors are encountered while executing a GraphQL field, only that
    # field and its descendants will be omitted, and sibling fields will still
    # be executed.
    my $data = execute_operation($context, $context->{operation}, $root_value);
    return {
        data => $data,
        (@{ $context->{errors} } ? (errors => $context->{errors}) : ()),
    };
}

# Constructs a ExecutionContext object from the arguments passed to
# execute, which we will pass throughout the other execution methods.
#
# Throws a GraphQLError if a valid execution context cannot be created.
sub build_execution_context {
    my ($schema, $document, $root_value, $context_value, $raw_variable_values,
        $operation_name) = @_;

    my $operation;
    my %fragments;

    for my $def (@{ $document->{definitions} }) {
        if ($def->{kind} eq Kind->OPERATION_DEFINITION) {
            if (!$operation_name && $operation) {
                die "Must provide operation name if query contains multiple operations.\n"
            }

            if (  !$operation_name
                || $def->{name} && $def->{name}{value} eq $operation_name)
            {
                $operation = $def;
            }
        }
        elsif ($def->{kind} eq Kind->FRAGMENT_DEFINITION) {
            $fragments{ $def->{name}{value} } = $def;
        }
        else {
            die GraphQLError(
                "GraphQL cannot execute a request containing a $def->{kind}.",
                [$def]
            );
        }
    }

    unless ($operation) {
        if ($operation_name) {
            die qq`Unknown operation named "$operation_name".\n`;
        }
        else {
            die "Must provide an operation.\n";
        }
    }

    my $variable_values = get_variable_values(
        $schema,
        $operation->{variable_definitions} || [],
        $raw_variable_values || {}
    );

    return {
        schema => $schema,
        fragments => \%fragments,
        root_value => $root_value,
        context_value => $context_value,
        operation => $operation,
        variable_values => $variable_values,
        errors => [],
    };
}

# Implements the "Evaluating operations" section of the spec.
sub execute_operation {
    my ($exe_context, $operation, $root_value) = @_;

    my $type = get_operation_root_type($exe_context->{schema}, $operation);
    my $fields = collect_fields(
        $exe_context,
        $type,
        $operation->{selection_set},
        {},
        {}
    );
    # print 'eo fields '; p $fields;

    my $path;
    return execute_fields($exe_context, $type, $root_value, $path, $fields);
}

# Extracts the root type of the operation from the schema.
sub get_operation_root_type {
    my ($schema, $operation) = @_;

    if ($operation->{operation} eq 'query') {
        return $schema->get_query_type;
    }
    elsif ($operation->{operation} eq 'mutation') {
        my $mutation_type = $schema->get_mutation_type;
        unless ($mutation_type) {
            die GraphQLError(
                'Schema is not configured for mutations',
                [$operation]
            );
        }
        return $mutation_type;
    }
    elsif ($operation->{operation} eq 'subscription') {
        my $subscription_type = $schema->get_subscription_type;
        unless ($subscription_type) {
            die GraphQLError(
                'Schema is not configued for subscriptions',
                [$operation]
            );
        }
        return $subscription_type;
    }
    else {
        die GraphQLError(
            'Can only execute queries, mutations and subscriptions',
            [$operation]
        );
    }
}

# Implements the "Evaluating selection sets" section of the spec
# for "read" mode.
sub execute_fields {
    my ($exe_context, $parent_type, $source_value, $path, $fields) = @_;

    return reduce {
        my $field_nodes = $fields->{ $b };
        my $field_path = add_path($path, $b);
        my $result = resolve_field(
            $exe_context,
            $parent_type,
            $source_value,
            $field_nodes,
            $field_path
        );
        # print 'ef ' . $b . ' '; p $result;

        # Replace NULLISH with undef
        if (defined($result) && ref($result) && $result == NULLISH) {
            $result = undef;
        }
        # Skip node
        elsif (!defined $result) {
            warn "$b NOT DEFINED SKIPPING...";
            return $a;
        }

        $a->{ $b } = $result;
        $a;
    } {}, keys %$fields;
}

# Given a selectionSet, adds all of the fields in that selection to
# the passed in map of fields, and returns it at the end.
#
# CollectFields requires the "runtime type" of an object. For a field which
# returns an Interface or Union type, the "runtime type" will be the actual
# Object type returned by that field.
sub collect_fields {
    my ($exe_context, $runtime_type, $selection_set, $fields,
        $visited_fragment_names) = @_;

    for my $selection (@{ $selection_set->{selections} }) {
        # print 'cf '; p $selection;

        if ($selection->{kind} eq Kind->FIELD) {
            unless (should_include_node($exe_context, $selection->{directives})) {
                next;
            }

            my $name = get_field_entry_key($selection);
            if (!$fields->{ $name }) {
                $fields->{ $name } = [];
            }

            push @{ $fields->{ $name } }, $selection;
        }
        elsif ($selection->{kind} eq Kind->INLINE_FRAGMENT) {
            if (   !should_include_node($exe_context, $selection->{directives})
                || !does_fragment_condition_match($exe_context, $selection, $runtime_type))
            {
                next;
            }

            collect_fields(
                $exe_context,
                $runtime_type,
                $selection->{selection_set},
                $fields,
                $visited_fragment_names
            );
        }
        elsif ($selection->{kind} eq Kind->FRAGMENT_SPREAD) {
            my $frag_name = $selection->{name}{value};
            if ($visited_fragment_names->{ $frag_name }
                || !should_include_node($exe_context, $selection->{directives}))
            {
                next;
            }

            $visited_fragment_names->{ $frag_name } = 1;

            my $fragment = $exe_context->{fragments}{ $frag_name };
            if (!$fragment
                || !does_fragment_condition_match($exe_context, $fragment, $runtime_type))
            {
                next;    # TODO
            }

            collect_fields(
                $exe_context,
                $runtime_type,
                $fragment->{selection_set},
                $fields,
                $visited_fragment_names
            );
        }
    }

    return $fields;
}

# Determines if a field should be included based on the @include and @skip
# directives, where @skip has higher precidence than @include.
sub should_include_node {
    my ($exe_context, $directives) = @_;

    my $skip_node = $directives && find(
        $directives,
        sub { $_[0]->{name}{value} eq GraphQLSkipDirective->name }
    );

    if ($skip_node) {
        my $values = get_argument_values(
            GraphQLSkipDirective,
            $skip_node,
            $exe_context->{variable_values}
        );
        return if $values->{if};
    }

    my $include_node = $directives && find(
        $directives,
        sub { $_[0]->{name}{value} eq GraphQLIncludeDirective->name }
    );

    if ($include_node) {
        my $values = get_argument_values(
            GraphQLIncludeDirective,
            $include_node,
            $exe_context->{variable_values}
        );
        return if !$values->{if};
    }

    return 1;
}

# Determines if a fragment is applicable to the given type.
sub does_fragment_condition_match {
    my ($exe_context, $fragment, $type) = @_;

    my $type_condition_node = $fragment->{type_condition};
    unless ($type_condition_node) {
        return 1;
    }

    my $conditional_type = type_from_ast($exe_context->{schema}, $type_condition_node);
    if ($conditional_type->to_string eq $type->to_string) {
        return 1;
    }

    if (is_abstract_type($conditional_type)) {
        return $exe_context->{schema}->is_possible_type($conditional_type, $type);
    }

    return; # false
}

# Implements the logic to compute the key of a given field's entry
sub get_field_entry_key {
    my $node = shift;
    return $node->{alias} ? $node->{alias}{value} : $node->{name}{value};
}

# Resolves the field on the given source object. In particular, this
# figures out the value that the field returns by calling its resolve function,
# then calls completeValue to complete promises, serialize scalars, or execute
# the sub-selection-set for objects.
sub resolve_field {
    my ($exe_context, $parent_type, $source, $field_nodes, $path) = @_;

    my $field_node = $field_nodes->[0];
    my $field_name = $field_node->{name}{value};

    my $field_def = get_field_def($exe_context->{schema}, $parent_type, $field_name);
    return unless $field_def;

    my $return_type = $field_def->{type};
    my $resolve_fn = $field_def->{resolve} || \&default_field_resolver;

    # The resolve function's optional third argument is a context value that
    # is provided to every resolve function within an execution. It is commonly
    # used to represent an authenticated user, or request-specific caches.
    my $context = $exe_context->{context_value};

    # The resolve function's optional fourth argument is a collection of
    # information about the current execution state.
    my %info = (
        field_name => $field_name,
        field_nodes => $field_nodes,
        return_type => $return_type,
        parent_type => $parent_type,
        path => $path,
        schema => $exe_context->{schema},
        fragments => $exe_context->{fragments},
        root_value => $exe_context->{root_value},
        operation => $exe_context->{operation},
        variable_values => $exe_context->{variable_values},
    );

    # Get the resolve function, regardless of if its result if normal
    # or abrupt (error).
    my $result = resolve_field_value_or_error(
        $exe_context,
        $field_def,
        $field_node,
        $resolve_fn,
        $source,
        $context,
        \%info
    );

    return complete_value_catching_error(
        $exe_context,
        $return_type,
        $field_nodes,
        \%info,
        $path,
        $result
    );
}

# Isolates the "ReturnOrAbrupt" behavior to not de-opt the `resolveField`
# function. Returns the result of resolveFn or the abrupt-return Error object.
sub resolve_field_value_or_error {
    my ($exe_context, $field_def, $field_node,
        $resolve_fn, $source, $context, $info) = @_;

    my $res = eval {
        # Build a Perl object of arguments from the field.arguments AST, using the
        # variables scope to fulfill any variable references.
        # TODO: find a way to memoize, in case this field is within a List type.
        my $args = get_argument_values(
            $field_def,
            $field_node,
            $exe_context->{variable_values}
        );
        # print 'rfvor args '; p $args;

        $resolve_fn->($source, $args, $context, $info);
    };
    # print 'field def '; p $field_def;
    # printf "rfvor res %20s: ", $info->{field_name}; p $res;
    # print "          ^\n\n";

    if (my $e = $@) {
        # print 'eval of rfvor '; warn $e;
        return blessed($e) ? $e : GraphQLError($e, [$field_node]);
    };

    return $res;
}

# This is a small wrapper around complete_value which detects and logs errors
# in the execution context.
sub complete_value_catching_error {
    my ($exe_context, $return_type, $field_nodes, $info, $path, $result) = @_;

    # If the field type is non-nullable, then it is resolved without any
    # protection from errors, however it still properly locates the error.
    if ($return_type->isa('GraphQL::Type::NonNull')) {
        return complete_value_with_located_error(
            $exe_context,
            $return_type,
            $field_nodes,
            $info,
            $path,
            $result
        );
    }

    # Otherwise, error protection is applied, logging the error and resolving
    # a null value for this field if one is encountered.
    my $res = eval {
        complete_value_with_located_error(
            $exe_context,
            $return_type,
            $field_nodes,
            $info,
            $path,
            $result
        );
    };
    # printf "cvce res %20s: ", $info->{field_name}; p $res;

    if (my $e = $@) {
        # print 'eval of cvwle '; p $e;
        # If `complete_value_with_located_error` returned abruptly (threw an error),
        # log the error and return null.
        push @{ $exe_context->{errors} }, $e;
        return NULLISH;
    };

    return $res;
}

# This is a small wrapper around completeValue which annotates errors with
# location information.
sub complete_value_with_located_error {
    my ($exe_context, $return_type, $field_nodes, $info, $path, $result) = @_;

    my $res = eval {
        complete_value(
            $exe_context,
            $return_type,
            $field_nodes,
            $info,
            $path,
            $result
        );
    };

    if (my $e = $@) {
        # print 'eval of cv '; p $e;
        die located_error($e, $field_nodes, response_path_as_array($path));
    };

    return $res;
}

# Implements the instructions for completeValue as defined in the
# "Field entries" section of the spec.
#
# If the field type is Non-Null, then this recursively completes the value
# for the inner type. It throws a field error if that completion returns null,
# as per the "Nullability" section of the spec.
#
# If the field type is a List, then this recursively completes the value
# for the inner type on each item in the list.
#
# If the field type is a Scalar or Enum, ensures the completed value is a legal
# value of the type by calling the `serialize` method of GraphQL type
# definition.
#
# If the field is an abstract type, determine the runtime type of the value
# and then complete based on that type
#
# Otherwise, the field type expects a sub-selection set, and will complete the
# value by evaluating all sub-selections.
sub complete_value {
    my ($exe_context, $return_type, $field_nodes, $info, $path, $result) = @_;

    # say '-';
    # print 'cv res '; p $result;
    # print 'cv rt '; p $return_type;

    # If result is an Error, throw a located error.
    if ($result && blessed($result) && $result->isa('GraphQL::Error')) {
        die $result;
    }

    # If field type is NonNull, complete for inner type, and throw field error
    # if result is null.
    if ($return_type && $return_type->isa('GraphQL::Type::NonNull')) {
        my $completed = complete_value(
            $exe_context,
            $return_type->of_type,
            $field_nodes,
            $info,
            $path,
            $result
        );

        # if (!$completed) { # null
        if (!defined($completed)) { # null
        # if ($completed && ref($completed) && $completed == NULLISH) {
            die GraphQLError(
                "Cannot return null for non-nullable field $info->{parent_type}{name}.$info->{field_name}.",
                $field_nodes
            );
        }

        return $completed;
    }

    # If result value is null-ish (null, undefined, or NaN) then return null.
    unless ($result) {
        say 'NULLISH';
        return NULLISH; # null
    }

    # If field type is List, complete each item in the list with the inner type
    if ($return_type->isa('GraphQL::Type::List')) {
        # say 'list';
        return complete_list_value(
            $exe_context,
            $return_type,
            $field_nodes,
            $info,
            $path,
            $result
        );
    }

    # If field type is a leaf type, Scalar or Enum, serialize to a valid value,
    # returning null if serialization is not possible.
    if (is_leaf_type($return_type)) {
        # say 'leaf';
        return complete_leaf_value($return_type, $result);
    }

    # If field type is an abstract type, Interface or Union, determine the
    # runtime Object type and complete for that type.
    # print 'before abstract '; p $return_type;
    if (is_abstract_type($return_type)) {
        # say 'abstract';
        return complete_abstract_value(
            $exe_context,
            $return_type,
            $field_nodes,
            $info,
            $path,
            $result
        );
    }

    # If field type is Object, execute and complete all sub-selections.
    if ($return_type->isa('GraphQL::Type::Object')) {
        # say 'object';
        return complete_object_value(
            $exe_context,
            $return_type,
            $field_nodes,
            $info,
            $path,
            $result
        );
    }

    # Not reachable. All possible output types have been considered.
    die qq`Cannot complete value of unexpected type "${ stringify_type($return_type) }".`;
}

# Complete a list value by completing each item in the list with the inner type
sub complete_list_value {
    my ($exe_context, $return_type, $field_nodes, $info, $path, $result) = @_;

    # print 'clv result '; p $result;
    die "Expected Iterable, but did not find one for field $info->{parent_type}{name}.$info->{field_name}."
        if ref($result) ne 'ARRAY';

    my $item_type = $return_type->of_type;
    my @completed_results;

    my $index = 0;
    for my $item (@$result) {
        # No need to modify the info object containing the path,
        # since from here on it is not ever accessed by resolver functions.
        my $field_path = add_path($path, $index++);
        my $completed_item = complete_value_catching_error(
            $exe_context,
            $item_type,
            $field_nodes,
            $info,
            $field_path,
            $item
        );
        # print 'list item '; p $item;
        # print 'list item type '; p $item_type;
        # printf "clv ci %20s: ", $info->{field_name}; p $completed_item;

        # Replace NULLISH with undef
        if (defined($completed_item) && ref($completed_item) && $completed_item == NULLISH) {
            $completed_item = undef;
        }

        push @completed_results, $completed_item;
    }

    return \@completed_results;
}

# Complete a Scalar or Enum by serializing to a valid value,
# throwing an error if serialization is not possible.
sub complete_leaf_value {
    my ($return_type, $result) = @_;

    # print 'clv rt '; p $return_type;
    # print 'clv r '; p $result;
    die 'Missing serialzie method on type' unless $return_type->can('serialize');

    my $serialized_result = $return_type->serialize($result);
    # print 'clv sr '; p $serialized_result;
    # TODO: check condition
    unless (defined($serialized_result)) {
        # TODO: return Error
        die {
            message => qq`Expected a value of type "${ stringify_type($return_type) }" but `
                . qq`received: ${ stringify_type($result) }`,
        };
    }

    return $serialized_result;
}

# Complete a value of an abstract type by determining the runtime object type
# of that value, then complete the value for that type.
sub complete_abstract_value {
    my ($exe_context, $return_type, $field_nodes, $info, $path, $result) = @_;

    # print 'abs rettyp '; p $return_type;
    my $runtime_type = $return_type->resolve_type
        ? $return_type->resolve_type->($result, $exe_context->{context_value}, $info)
        : default_resolve_type_fn($result, $exe_context->{context_value}, $info, $return_type);
    # print 'abs runtyp '; p $runtime_type;

    return complete_object_value(
        $exe_context,
        ensure_valid_runtime_type(
            $runtime_type,
            $exe_context,
            $return_type,
            $field_nodes,
            $info,
            $result
        ),
        $field_nodes,
        $info,
        $path,
        $result
    );
}

sub ensure_valid_runtime_type {
    my ($runtime_type_or_name, $exe_context, $return_type,
        $field_nodes, $info, $result) = @_;

    # say "\n";
    # print 'rton '; p $runtime_type_or_name;
    my $runtime_type = !ref($runtime_type_or_name)
        ? $exe_context->{schema}->get_type($runtime_type_or_name)
        : $runtime_type_or_name;
    # print 'evrt '; p $runtime_type;

    unless ($runtime_type->isa('GraphQL::Type::Object')) {
        die GraphQLError(
            qq`Abstract type $return_type->{name} must resolve to an Object type at `
          . qq`runtime for field $info->{parent_type}{name}.$info->{field_name} with `
          . qq`value "${ stringify_type($result) }", received "${ stringify_type($runtime_type) }".`,
          $field_nodes
        );
    }

    if (!$exe_context->{schema}->is_possible_type($return_type, $runtime_type)) {
        die GraphQLError(
            qq`Runtime Object type "$runtime_type->{name}" is not a possible type `
          . qq`for "$return_type->{name}".`,
          $field_nodes
        );
    }

    return $runtime_type;
}

# Complete an Object value by executing all sub-selections.
sub complete_object_value {
    my ($exe_context, $return_type, $field_nodes, $info, $path, $result) = @_;

    # If there is an is_type_of predicate function, call it with the
    # current result. If is_type_of returns false, then raise an error rather
    # than continuing execution.
    if ($return_type->is_type_of) {
        my $is_type_of =
            $return_type->is_type_of->($result, $exe_context->{context_value}, $info);
        # print 'cov itf '; p $is_type_of;

        if (!$is_type_of) {
            die invalid_return_type_error($return_type, $result, $field_nodes);
        }
    }

    return collect_and_execute_subfields(
        $exe_context,
        $return_type,
        $field_nodes,
        $info,
        $path,
        $result
    );
}

sub invalid_return_type_error {
    my ($return_type, $result, $field_nodes) = @_;
    return GraphQLError(
        qq`Expected value of type "$return_type->{name}" but got: ${ stringify_type($result) }.`,
        $field_nodes
    );
}

sub collect_and_execute_subfields {
    my ($exe_context, $return_type, $field_nodes, $info, $path, $result) = @_;

    # Collect sub-fields to execute to complete this value.
    my $sub_field_nodes = {};
    my $visited_fragment_names = {};

    for my $field_node (@$field_nodes) {
        my $selection_set = $field_node->{selection_set};
        if ($selection_set) {
            $sub_field_nodes = collect_fields(
                $exe_context,
                $return_type,
                $selection_set,
                $sub_field_nodes,
                $visited_fragment_names
            );
        }
    }

    return execute_fields($exe_context, $return_type, $result, $path, $sub_field_nodes);
}

# If a resolve_type function is not given, then a default resolve behavior is
# used which tests each possible type for the abstract type by calling
# is_type_of for the object being coerced, returning the first type that matches.
sub default_resolve_type_fn {
    my ($value, $context, $info, $abstract_type) = @_;

    my $possible_types = $info->{schema}->get_possible_types($abstract_type);

    for my $type (@$possible_types) {
        if ($type->is_type_of) {
            my $is_type_of_result = $type->is_type_of->($value, $context, $info);
            return $type if $is_type_of_result;
        }
    }

    return;
}

# If a resolve function is not given, then a default resolve behavior is used
# which takes the property of the source object of the same name as the field
# and returns it as the result, or if it's a function, returns the result
# of calling that function while passing along args and context.
sub default_field_resolver {
    my ($source, $args, $context, $info) = @_;
    # say ' >>> default field resolver >>> ';

    return if reftype($source) ne 'HASH' && ref($source) ne 'CODE';

    my $property = blessed($source) && $source->can($info->{field_name})
        ? $source->${ \$info->{field_name} }($args, $context, $info)
        : $source->{ $info->{field_name} };

    if (ref($property) eq 'CODE') {
        $property = $source->{ $info->{field_name} }->($args, $context, $info);
    }

    # print " >>> res of $info->{field_name} "; p $property;
    return $property;
}

# This method looks up the field on the given type defintion.
# It has special casing for the two introspection fields, __schema
# and __typename. __typename is special because it can always be
# queried as a field, even in situations where no other fields
# are allowed, like on a Union. __schema could get automatically
# added to the query type, but that would require mutating type
# definitions, which would cause issues.
sub get_field_def {
    my ($schema, $parent_type, $field_name) = @_;

    if ($field_name eq SchemaMetaFieldDef->{name}
        && $schema->get_query_type == $parent_type)
    {
        return SchemaMetaFieldDef;
    }
    elsif ($field_name eq TypeMetaFieldDef->{name}
        && $schema->get_query_type == $parent_type)
    {
        return TypeMetaFieldDef;
    }
    elsif ($field_name eq TypeNameMetaFieldDef->{name}
        && $schema->get_query_type == $parent_type)
    {
        return TypeNameMetaFieldDef;
    }

    return $parent_type->get_fields->{ $field_name };
}


# Path

sub response_path_as_array {
    my $path = shift;
    my @flattened;
    my $curr = $path;

    # while (@$curr) {
    #     push @flattened, $curr->{key};
    #     $curr = $curr->prev;
    # }

    return [reverse(@flattened)];
}

sub add_path {
    my ($path, $index) = @_;
    return;
}

1;

__END__
