---
name: primitive-module
description: Create, clean up, validate, test, or document a Launch Terraform primitive module.
---

# Primitive Module Workflow

Use this skill for repositories named `tf-<provider>-module_primitive-<resource>` or tasks that explicitly ask for a primitive module.

## Read First

1. Read `AGENTS.md`.
2. Read `.agents/references/shared/terraform-module-standards.md`.
3. Read `.agents/references/primitive/standards.md`.
4. Read `.agents/references/primitive/creation.md` when creating a module from this skeleton or completing template cleanup.
5. Read `.agents/references/primitive/testing.md` before writing or changing tests.
6. Read `.agents/references/primitive/release-history.md` only when changing this guidance or investigating why a rule exists.

## Workflow

1. Confirm the target cloud provider and single resource type.
2. Inspect the existing repository structure and current Terraform files.
3. Remove skeleton remnants and rename template resources, tests, imports, package names, and README content.
4. Implement one primitive resource interface with explicit variable types, descriptions, validations, resource outputs, and provider constraints.
5. Build `examples/complete/` as the canonical secure usage example.
6. Keep `README.md` derived from `TEMPLATED_README.md`; replace the module-specific sections and preserve skeleton development boilerplate.
7. Add or update Terratest code so assertions verify specific expected values and security settings through provider APIs when applicable.
8. Run focused validation, then broader checks such as formatting, linting, Terraform init/validate/plan for the example, README generation, and Go test build or Terratest where practical.

## Completion Gate

- The module contains one primary resource type and no architecture-level business logic.
- Example variables pass through all root variables.
- Example README matches `examples/complete/main.tf`.
- Root README retains the non-module-specific sections from `TEMPLATED_README.md` and has a populated terraform-docs block.
- Functional and readonly tests are meaningfully different.
- Tests avoid `assert.NotEmpty` or `require.NotEmpty` when a specific expected value is known.
- Security features configured by the module are verified through provider APIs where practical.
- No TODO placeholders, skeleton resources, stale imports, or template names remain.
