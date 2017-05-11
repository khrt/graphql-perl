package GraphQL::Validator;

use strict;
use warnings;

use DDP;

use Exporter qw/import/;
our @EXPORT_OK = (qw/validate SPECIFIED_RULES/);

use GraphQL::Language::Visitor qw/
    visit
    visit_in_parallel
    visit_with_typeinfo
/;
use GraphQL::TypeInfo;
use GraphQL::Validator::Context;
use GraphQL::Validator::Rule::UniqueOperationNames;
use GraphQL::Validator::Rule::LoneAnonymousOperation;
use GraphQL::Validator::Rule::KnownTypeNames;
use GraphQL::Validator::Rule::FragmentsOnCompositeTypes;
use GraphQL::Validator::Rule::VariablesAreInputTypes;
use GraphQL::Validator::Rule::ScalarLeafs;
use GraphQL::Validator::Rule::FieldsOnCorrectType;
use GraphQL::Validator::Rule::UniqueFragmentNames;
use GraphQL::Validator::Rule::KnownFragmentNames;
use GraphQL::Validator::Rule::NoUnusedFragments;
use GraphQL::Validator::Rule::PossibleFragmentSpreads;
use GraphQL::Validator::Rule::NoFragmentCycles;
use GraphQL::Validator::Rule::UniqueVariableNames;
use GraphQL::Validator::Rule::NoUndefinedVariables;
use GraphQL::Validator::Rule::NoUnusedVariables;
use GraphQL::Validator::Rule::KnownDirectives;
use GraphQL::Validator::Rule::UniqueDirectivesPerLocation;
use GraphQL::Validator::Rule::KnownArgumentNames;
use GraphQL::Validator::Rule::UniqueArgumentNames;
use GraphQL::Validator::Rule::ArgumentsOfCorrectType;
# use GraphQL::Validator::Rule::ProvidedNonNullArguments;
use GraphQL::Validator::Rule::DefaultValuesOfCorrectType;
use GraphQL::Validator::Rule::VariablesInAllowedPosition;
use GraphQL::Validator::Rule::OverlappingFieldsCanBeMerged;
use GraphQL::Validator::Rule::UniqueInputFieldNames;

use constant {
    SPECIFIED_RULES => [
        # Spec Section: "Operation Name Uniqueness"
        'UniqueOperationNames',

        # Spec Section: "Lone Anonymous Operation"
        'LoneAnonymousOperation',

        # Spec Section: "Fragment Spread Type Existence"
        'KnownTypeNames',

        # Spec Section: "Fragments on Composite Types"
        'FragmentsOnCompositeTypes',

        # Spec Section: "Variables are Input Types"
        'VariablesAreInputTypes',

        # Spec Section: "Leaf Field Selections"
        'ScalarLeafs',

        # Spec Section: "Field Selections on Objects, Interfaces, and Unions Types"
        'FieldsOnCorrectType',

        # Spec Section: "Fragment Name Uniqueness"
        'UniqueFragmentNames',

        # Spec Section: "Fragment spread target defined"
        'KnownFragmentNames',

        # Spec Section: "Fragments must be used"
        'NoUnusedFragments',

        # Spec Section: "Fragment spread is possible"
        'PossibleFragmentSpreads',

        # Spec Section: "Fragments must not form cycles"
        'NoFragmentCycles',

        # Spec Section: "Variable Uniqueness"
        'UniqueVariableNames',

        # Spec Section: "All Variable Used Defined"
        'NoUndefinedVariables',

        # Spec Section: "All Variables Used"
        'NoUnusedVariables',

        # Spec Section: "Directives Are Defined"
        'KnownDirectives',

        # Spec Section: "Directives Are Unique Per Location"
        'UniqueDirectivesPerLocation',

        # Spec Section: "Argument Names"
        'KnownArgumentNames',

        # Spec Section: "Argument Uniqueness"
        'UniqueArgumentNames',

        # Spec Section: "Argument Values Type Correctness"
        'ArgumentsOfCorrectType',

        # Spec Section: "Argument Optionality"
        #TODO 'ProvidedNonNullArguments',

        # Spec Section: "Variable Default Values Are Correctly Typed"
        'DefaultValuesOfCorrectType',

        # Spec Section: "All Variable Usages Are Allowed"
        'VariablesInAllowedPosition',

        # Spec Section: "Field Selection Merging"
        'OverlappingFieldsCanBeMerged',

        # Spec Section: "Input Object Field Uniqueness"
        'UniqueInputFieldNames',
    ],
};

sub validate {
    my ($schema, $ast, $rules, $type_info) = @_;

    die "Must provide schema\n" unless $schema;
    die "Must provide document\n" unless $ast;

    die "Schema must be an instance of GraphQL::Type::Schema.\n"
        unless $schema->isa('GraphQL::Type::Schema');

    return visit_using_rules(
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

    my @visitors =
        map { "GraphQL::Validator::Rule::$_"->validate($context) } @$rules;

    # Visit the whole document with each instance of all provided rules.
    visit($ast, visit_with_typeinfo($type_info, visit_in_parallel(\@visitors)));

    return $context->get_errors;
}


1;

__END__
