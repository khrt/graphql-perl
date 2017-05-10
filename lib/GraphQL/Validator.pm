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
use GraphQL::Validator::Rules::UniqueOperationNames;
use GraphQL::Validator::Rules::LoneAnonymousOperation;
use GraphQL::Validator::Rules::KnownTypeNames;
use GraphQL::Validator::Rules::FragmentsOnCompositeTypes;
use GraphQL::Validator::Rules::VariablesAreInputTypes;
use GraphQL::Validator::Rules::ScalarLeafs;
use GraphQL::Validator::Rules::FieldsOnCorrectType;
use GraphQL::Validator::Rules::UniqueFragmentNames;
use GraphQL::Validator::Rules::KnownFragmentNames;
use GraphQL::Validator::Rules::NoUnusedFragments;
use GraphQL::Validator::Rules::PossibleFragmentSpreads;
use GraphQL::Validator::Rules::NoFragmentCycles;
use GraphQL::Validator::Rules::UniqueVariableNames;
use GraphQL::Validator::Rules::NoUndefinedVariables;
use GraphQL::Validator::Rules::NoUnusedVariables;
use GraphQL::Validator::Rules::KnownDirectives;
use GraphQL::Validator::Rules::UniqueDirectivesPerLocation;
use GraphQL::Validator::Rules::KnownArgumentNames;
use GraphQL::Validator::Rules::UniqueArgumentNames;
use GraphQL::Validator::Rules::ArgumentsOfCorrectType;
# use GraphQL::Validator::Rules::ProvidedNonNullArguments;
use GraphQL::Validator::Rules::DefaultValuesOfCorrectType;
use GraphQL::Validator::Rules::VariablesInAllowedPosition;
use GraphQL::Validator::Rules::OverlappingFieldsCanBeMerged;
use GraphQL::Validator::Rules::UniqueInputFieldNames;

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
        map { "GraphQL::Validator::Rules::$_"->validate($context) } @$rules;

    # Visit the whole document with each instance of all provided rules.
    visit($ast, visit_with_typeinfo($type_info, visit_in_parallel(\@visitors)));

    return $context->get_errors;
}


1;

__END__
