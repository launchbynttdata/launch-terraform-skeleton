# Primitive Module Creation and Cleanup

Use this reference when converting the skeleton into a primitive module or reviewing a conversion.

## Creation Flow

1. Confirm the provider and one target resource type. Review the provider documentation and a similar primitive for that provider.
2. Run the service documentation check in the primitive standards. Translate documented ranges, enums, formats, and cross-field constraints into variable validation and descriptions. If no suitable public reference is found after a reasonable search, proceed using provider documentation rather than retrying indefinitely.
3. Implement `versions.tf`, `variables.tf`, `main.tf`, and `outputs.tf` using the primitive standards. Set Terraform and provider floors from the features used by those files, not from a generic major range.
4. Build `examples/complete/` with its Terraform files, an accurate README, resource naming, and any deployable prerequisite resources.
5. Before writing cloud-backed tests, run the available example validation flow: formatting and linting, init, validate, plan, apply, plan again, and destroy. The second plan must report no changes, including no `Changes to Outputs`; output-only drift fails the functional test's empty-plan check. Resolve failures before continuing when credentials and environment access permit. Do not open a pull request without at least a successful example plan. If apply was not possible, say so in the pull request.
6. Add the plan-only validation tests in the testing reference and run `terraform test`. Then add Terratest coverage and run the Go quality checks in the testing reference before cloud-backed test execution.
7. Build root `README.md` from `TEMPLATED_README.md`, replace the module-specific title and overview, add usage, retain the development boilerplate, and populate terraform-docs.
8. Run the cleanup and completion checks below.

## Root and Example Documentation

- Do not write root `README.md` from scratch. Start from `TEMPLATED_README.md` and preserve Module Development, Pre-Requisites, Pre-Commit Hooks, Local Validation, Review and Merge Process, and Automatic Updates.
- Do not remove `TEMPLATED_README.md` until all of its required sections have been incorporated into the root README.
- The generated terraform-docs block in the root README must not be empty. Generate it when available; otherwise supply accurate inputs and outputs tables.
- The handwritten usage block in `examples/complete/README.md` must match `examples/complete/main.tf`, including resources, policies, dependencies, variables, inputs, and outputs. Update it whenever the example changes.

## Skeleton Cleanup

Before completion:

- Delete `examples/with_cake/` when it is part of the skeleton.
- Update the Go module path and every test import from `launch-terraform-template` to the new module repository.
- Replace template comments in `tests/testimpl/`, including empty template settings comments.
- Search all Markdown and Go files for `TODO:` and template references. Remove or replace every placeholder, including the hooks documentation placeholder.
- Search for stale resource names, package names, copied snippets, imports, and generated provider files that should not be committed.
- Run `go mod tidy` after renaming imports or adding SDK dependencies.

## Completion Checklist

- Root variables have explicit types, descriptions, required validation, and coherent optional objects.
- The resource name validation encodes the service's documented naming rule, and `tests/validation.tftest.hcl` covers each validation with passing and failing cases.
- Root and example `versions.tf` floors require Terraform and provider versions that support every feature the module uses.
- Root outputs exist in the provider schema, have descriptions, and match the intended composition interface.
- The complete example passes every root variable through, exposes test-consumed outputs, and uses the secure configuration.
- Root and example documentation are synchronized and complete.
- No skeleton resources, TODOs, template names, or stale imports remain.
