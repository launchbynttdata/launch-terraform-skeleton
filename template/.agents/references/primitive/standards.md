# Primitive Module Standards

Primitive modules wrap one cloud resource type and keep the interface reusable. They are comprehensive production wrappers, not minimal examples or opinionated architectures.

## Architecture

- Include one primary cloud resource type.
- Do not add business logic or multi-resource architecture behavior.
- Use a descriptive Terraform resource name based on the resource type; do not use `this`.
- Expose every non-deprecated, non-computed argument that a typical production deployment would configure. Optional attributes normally default to `null` so Terraform omits them unless chosen.
- Export useful resource attributes individually. Do not output the complete resource object.
- Keep secure defaults in the example, especially encryption and private access patterns where the provider supports them.

## Required Structure

```text
examples/complete/
  main.tf
  variables.tf
  outputs.tf
  versions.tf
  README.md
tests/
  post_deploy_functional/
  post_deploy_functional_readonly/
  testimpl/
main.tf
variables.tf
outputs.tf
versions.tf
README.md
TEMPLATED_README.md
Makefile
go.mod
go.sum
```

## Provider Notes

- Azure resources commonly use explicit `location`, `resource_group_name`, and nested configuration blocks.
- AWS resources commonly use `data.aws_region.current`, tags for grouping, and separate resources for versioning, policies, encryption, or logging when the provider models them separately.
- GCP resources commonly distinguish project, location, labels, and IAM binding patterns.

## Variables

- Give every variable an explicit type and useful description.
- Use `snake_case`, provider argument names where practical, and concise group headings for related inputs.
- Do not use Terraform-reserved names such as `source`, `target`, `version`, `count`, `for`, or `provider`.
- Required infrastructure inputs have no default. Optional flags should default to `false` or the safer option. Tags or labels should default to an empty map.
- Use `object()` with `optional()` attributes for structured optional configuration.
- Add validation for provider-enforced numeric bounds, enums, formats, mutually exclusive inputs, and cross-field requirements.
- Nullable validation expressions must avoid evaluating null values, for example with a conditional expression. Use `try()` for nested optional object attributes.
- Optional object descriptions must explain conditional field requirements and prohibited combinations.

For every optional object, validate all of the following where applicable:

- Individual enum, range, and format constraints.
- Fields that must be provided together.
- Fields required when another field is set or active.
- Fields prohibited by an off or disabled sentinel value.

## Resources and Outputs

- Map variables directly to resource arguments. Use dynamic blocks for optional nested blocks when the provider supports them.
- Avoid lifecycle blocks and data sources unless they are necessary for the resource contract.
- AWS often models configuration as separate resources rather than nested blocks; follow the provider schema.
- Place tags or labels at the end of resource blocks where the local provider convention supports it.
- Every output needs a short description and must reference an attribute verified in the provider schema.
- Use generic output names such as `id`, `name`, `arn`, `url`, or `fqdn`, without resource-type prefixes.
- When `id` is the same value as another output, say so in the `id` description.
- Do not mark outputs sensitive by default; callers handle sensitivity in their own interface.

## Version Constraints

- Set a Terraform version and provider constraints that avoid untested major upgrades.
- Pin providers to an appropriate compatible minor range, following the current skeleton and provider-specific precedent.
- Keep provider configuration out of the root module; examples own provider configuration.

## AWS API Reference Check

For AWS primitive modules, consult the official AWS service API reference when practical. Derive validation ranges, enum values, formats, and cross-field constraints from the API reference and provider schema. If no suitable public API reference is found after a reasonable search, skip the step and do not retry indefinitely.

## Example Requirements

- The example must pass through every root module variable.
- Mutually exclusive root variables should both be represented with coherent defaults.
- The example should demonstrate the secure pattern for the resource type.
- `examples/complete/README.md` usage must exactly match `examples/complete/main.tf`.
- Example outputs must expose every value used by tests.
- Use the Launch resource naming module correctly: `for_each = var.resource_names_map`, `class_env`, numeric `instance_env` and `instance_resource`, and each entry's `name` and `max_length` for `cloud_resource_type` and `maximum_length`.
- Read naming outputs by map key, for example `module.resource_names["<key>"].standard`. Account-scoped names need a random suffix when concurrent or sequential tests could collide.
- Use the provider's regional convention for the naming module. AWS and GCP patterns may need hyphens removed from region names.

## Common Anti-Patterns

- Wrapping more than one primary resource type.
- Using `assert.NotEmpty` where a specific expected value is known.
- Copying functional tests into readonly tests unchanged.
- Leaving an empty terraform-docs block.
- Writing root `README.md` from scratch and dropping skeleton boilerplate.
- Leaving `TEMPLATED_README.md` content unincorporated.
