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
- Terraform evaluates both sides of `||`, so `var.x == null || var.x >= 0` fails at plan when `var.x` is null. Write `var.x == null ? true : var.x >= 0`. The same applies to attribute access on a null object, such as `var.obj.field` when `var.obj` is null.
- Validate a rule only when the module can evaluate all of it. Take bounds from the provider schema at the declared floor and from current service documentation, not from an older provider release. When a service rule depends on context the module cannot see, such as the environment type, a quota, or a total across resources it does not own, describe the rule in the variable and leave enforcement to the API.
- When the provider floor changes, recheck every validation and precondition derived from the old schema.
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
- Do not set a floor higher than the features require. A sibling module's constraint is not a justification.
- Set the root floor from the root module's own arguments. A sibling primitive used only by `examples/complete/` does not raise the root floor; the example declares that higher floor instead.
- The floor must be real: if the module uses a resource argument or behavior introduced in a specific provider release, the constraint must require at least that release.
- Prefer an explicit comment in `versions.tf` when a floor exists because of a particular feature.
- Keep provider configuration out of the root module; examples own provider configuration.

## Service Documentation Check

Derive validation ranges, enum values, formats, and cross-field constraints from the provider schema and the cloud service's own documentation. If no suitable public reference is found after a reasonable search, skip the step and do not retry indefinitely.

- AWS: consult the official AWS service API reference when practical.
- Azure: consult the Microsoft Learn page for the service and its REST API reference. Azure often documents limits that apply to a total across nested items, such as the summed CPU and memory of every container in a Container App.
- GCP: consult the service's API reference.

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
