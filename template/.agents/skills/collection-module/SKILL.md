---
name: collection-module
description: Create, clean up, validate, test, or document a Launch Terraform collection module.
---

# Collection Module Workflow

Use this skill for repositories named `tf-<provider>-module_collection-<service>` or tasks that explicitly ask for a collection module.

A collection composes released Launch modules into one independently deployable cloud service. It is broader than a primitive, which wraps one resource type, and narrower than a reference architecture, which encodes a production platform pattern.

## Read First

1. Read `AGENTS.md`.
2. Read `.agents/references/shared/terraform-module-standards.md`.
3. Read `.agents/references/collection/standards.md`.
4. Read `.agents/references/collection/testing.md` before writing or changing tests.
5. Read `.agents/references/collection/release-history.md` only when changing this guidance or investigating why a rule exists.

## Workflow

1. Confirm the repository name matches `tf-<provider>-module_collection-<service>` and that `.copier-answers.yml` exists. If either is missing, stop and report; do not rename or re-template the repository.
2. Classify every candidate resource as core, optional dependency, or platform choice, using the boundary test in the collection standards. Record the table in the README overview before writing Terraform. Stop and wait for the user when:
   - the request is mostly platform choices: report that it is a reference architecture and suggest a `tf-<provider>-module_reference-<architecture>` repository;
   - the request is one resource type: report that it is a primitive and suggest a `tf-<provider>-module_primitive-<resource>` repository;
   - the request bundles parts with different lifecycles, such as a shared environment and the applications deployed into it: propose the separate collections.
3. Build the composition inventory. For each module, record the repository, the release tag to pin, its `required_version`, its provider constraints, and the inputs and outputs you will use. Read each interface at that release tag, not at `main`.
4. If a required primitive does not exist or has no usable release, stop and report it. Do not inline the resource and do not substitute a community module without the user's approval.
5. Set version floors before writing Terraform: the Terraform floor is the highest of the root's own needs and every composed module's `required_version`; the provider constraint must fall inside every composed module's provider constraint.
6. Remove skeleton remnants and rename template resources, tests, imports, package names, and README content.
7. Implement the root module from module calls only, following the composition, optional-dependency, naming, and output rules in the collection standards.
8. Build `examples/complete/` for the path where the module creates its dependencies. When the module has any optional dependency, add `examples/existing_dependencies/` for the path where the caller supplies them.
9. Validate every example before writing tests: formatting and linting, init, validate, plan, apply, a second plan that reports no changes including no `Changes to Outputs`, and destroy. Plan one invalid input for each cross-field validation and confirm the custom error message, as the collection testing reference describes. Do not open a pull request without at least a successful plan of every example; if apply was not possible, say so in the pull request. Do not use `go test ./...` as a local check; that command applies the examples.
10. Set the latest supported Go baseline and refresh the complete Go dependency graph as required by the shared Terraform module standards.
11. Add Terratest coverage that verifies each composed resource and the relationships between them, following the collection testing reference.
12. Build root `README.md` from `TEMPLATED_README.md`, keep the classification table in the overview, preserve the skeleton development sections, and populate terraform-docs.
13. Run the cleanup checks in the shared standards and the completion gate below.

## Completion Gate

- The classification table is in the README, and the module contains no platform-choice resources.
- The root module contains only `module` blocks plus variables, locals, outputs, and `versions.tf`; it has no `resource` blocks, no provider blocks, and no `git::` sources.
- Every composed module is a released Launch registry module pinned to `~> MAJOR.MINOR` of the tag whose interface was read, or a community module the user approved.
- Terraform and provider floors cover every composed module, and the provider constraint lies inside every composed module's constraint.
- Each optional dependency is one object variable whose validation allows exactly one of the create and existing paths, and downstream modules and outputs read the resolved value from a local.
- `for_each` keys are static caller-supplied strings, never apply-time or sensitive values.
- The root generates names through the resource naming module, created components accept a name override, and components supplied by identifier take no name.
- Outputs are prefixed by component, resolve to the same value whether a dependency was created or supplied, and are marked sensitive when a composed output is sensitive.
- `examples/complete` passes through every root variable, and the examples together exercise the create and existing paths, a generated name, and a name override.
- Every example applies cleanly and its second plan reports no changes, with `IS_TERRAFORM_IDEMPOTENT_APPLY` left enabled.
- Tests assert the relationships between composed resources, not only each resource on its own. Expected values come from inputs, prerequisites, or calculated names, not from a copy of the output under test.
- Cross-field validations guard null-unsafe calls with conditionals. A negative plan for each one fails with the validation message and does not also report `Invalid function argument` or `Invalid index`.
- Every description that says a value is valid only when another input is set has a validation, or it says that the cloud API enforces the rule.
- Readonly tests use `lib.RunNonDestructiveTest` with a `TestComposable*` implementation function.
- No skeleton resources, stale imports, TODO placeholders, or template names remain.
