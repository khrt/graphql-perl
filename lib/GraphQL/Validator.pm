package GraphQL::Validator;

use strict;
use warnings;

 use constant {
     SPECIFIED_RULES => [
#         # Spec Section: "Operation Name Uniqueness"
#         UniqueOperationNames,

#         # Spec Section: "Lone Anonymous Operation"
#         LoneAnonymousOperation,

#         # Spec Section: "Fragment Spread Type Existence"
#         KnownTypeNames,

#         # Spec Section: "Fragments on Composite Types"
#         FragmentsOnCompositeTypes,

#         # Spec Section: "Variables are Input Types"
#         VariablesAreInputTypes,

#         # Spec Section: "Leaf Field Selections"
#         ScalarLeafs,

#         # Spec Section: "Field Selections on Objects, Interfaces, and Unions Types"
#         FieldsOnCorrectType,

#         # Spec Section: "Fragment Name Uniqueness"
#         UniqueFragmentNames,

#         # Spec Section: "Fragment spread target defined"
#         KnownFragmentNames,

#         # Spec Section: "Fragments must be used"
#         NoUnusedFragments,

#         # Spec Section: "Fragment spread is possible"
#         PossibleFragmentSpreads,

#         # Spec Section: "Fragments must not form cycles"
#         NoFragmentCycles,

#         # Spec Section: "Variable Uniqueness"
#         UniqueVariableNames,

#         # Spec Section: "All Variable Used Defined"
#         NoUndefinedVariables,

#         # Spec Section: "All Variables Used"
#         NoUnusedVariables,

#         # Spec Section: "Directives Are Defined"
#         KnownDirectives,

#         # Spec Section: "Directives Are Unique Per Location"
#           UniqueDirectivesPerLocation

#         # Spec Section: "Argument Names"
#         KnownArgumentNames,

#         # Spec Section: "Argument Uniqueness"
#         UniqueArgumentNames,

#         # Spec Section: "Argument Values Type Correctness"
#         ArgumentsOfCorrectType,

#         # Spec Section: "Argument Optionality"
#         ProvidedNonNullArguments,

#         # Spec Section: "Variable Default Values Are Correctly Typed"
#         DefaultValuesOfCorrectType,

#         # Spec Section: "All Variable Usages Are Allowed"
#         VariablesInAllowedPosition,

#         # Spec Section: "Field Selection Merging"
#           OverlappingFieldsCanBeMerged

#         # Spec Section: "Input Object Field Uniqueness"
#         UniqueInputFieldNames,

#         ValidationContext,
     ],
 };

use GraphQL::Validator::Context;
use GraphQL::TypeInfo;

sub validate {
    my ($schema, $ast, $rules, $type_info) = @_;

    die "Must provide schema\n" unless $schema;
    die "Must provide document\n" unless $ast;

    die "Schema must be an instance of GraphQL::Type::Schema.\n"
        unless $schema->isa('GraphQL::Type::Schema');

    return _visit_using_rules(
        $schema,
        $type_info || GraphQL::TypeInfo->new($schema),
        $ast,
        $rules || SPECIFIED_RULES,
    );
}

# This uses a specialized visitor which runs multiple visitors in parallel,
# while maintaining the visitor skip and break API.
sub visit_using_rules {
    my ($schema, $type_info, $ast, $rules) = @_;

    my $context = GraphQL::Validator::Context->new(
        schema => $schema,
        ast => $ast,
        type_info => $type_info,
    );

    my @visitors = map { $_->($context) } @$rules;

    # Visit the whole document with each instance of all provided rules.
    visit($ast, visit_with_typeinfo($type_info, visit_in_parallel(@visitors)));

    return $context->get_errors;
}


1;

__END__
