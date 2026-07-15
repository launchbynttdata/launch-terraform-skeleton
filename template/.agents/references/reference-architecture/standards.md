# Reference Architecture Standards

Reference architecture modules compose multiple primitives and selected community modules into complete, opinionated infrastructure patterns.

## Architecture

- Compose multiple resources or modules into a coherent pattern.
- Use Launch primitive modules from `terraform.registry.launch.nttdata.com` when available.
- Use mature public registry modules for complex AWS patterns when they reduce implementation risk.
- Use registry source addresses, not `git::` module URLs.
- Use bounded version constraints for internal and community modules.
- Keep feature flags named `create_*` for optional resources.

## Required Structure

```text
examples/complete/
  main.tf
  variables.tf
  outputs.tf
  versions.tf
  test.tfvars
  README.md
tests/
main.tf
variables.tf
outputs.tf
versions.tf
locals.tf
README.md
Makefile
go.mod
go.sum
```

## Composition

- Start with the Launch resource naming module.
- Azure architectures normally create or consume a resource group and pass `location`.
- AWS architectures normally use `data.aws_region.current` and tags.
- Do not ask consumers to provide names for resources the architecture owns.
- Do not duplicate naming modules inside examples when the root module already handles naming.

## Variables

- Include naming context variables required by the resource naming module.
- Use high-level service variables rather than exposing every nested primitive argument directly.
- Validate mutually exclusive fields such as `name` and `name_prefix`.
- Complex object variables need validation for required field groups and contradictory combinations.
- Optional features should have explicit `create_*` booleans and object inputs with safe defaults.

## Outputs

- Expose aggregate identifiers, names, ARNs/IDs, endpoints, and optional feature state.
- Prefix outputs consistently by resource or feature.
- Avoid exposing raw nested module internals unless they are part of the intended public contract.

## Example Requirements

- `examples/complete` is the reference implementation and should enable meaningful optional features.
- Do not commit `examples/complete/providers.tf`; the build system generates `provider.tf`.
- Include required runtime source assets for examples, such as Lambda source directories.
- Keep example README usage, variables, and outputs synchronized with actual example files.

## Common Anti-Patterns

- Replacing composition with one giant raw resource implementation.
- Using `git::` module sources.
- Duplicating provider blocks in examples.
- Composing resource naming in both root and example.
- Creating duplicate IAM permissions or duplicate CloudWatch log groups when community modules can already manage them.
- Using inconsistent output prefixes.
