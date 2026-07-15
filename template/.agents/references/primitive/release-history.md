# Primitive Module Guidance Release History

This file preserves the learnings from the previous monolithic primitive module guide.

## 2.1

- Skeleton updates now add the `.agents/`, `.claude/`, and `.cursor/` guidance trees. Reviewers of automatic update PRs should expect this additive template change.

## 2.0

- Split the legacy GitHub agent guide into an agent-agnostic skill and focused reference files. The legacy file is a compatibility stub; operational standards, creation and cleanup guidance, test guidance, and historical rationale now live separately.

## 1.13

- AWS primitive modules should consult official AWS API references where practical and translate documented ranges, enums, formats, and cross-field constraints into Terraform validations and variable descriptions.

## 1.12

- Root `README.md` should be built from `TEMPLATED_README.md`; preserve skeleton boilerplate and only replace module-specific sections.

## 1.11

- Optional object variables need cross-field validation for paired fields, conditional requirements, and contradictory sentinel values.

## 1.10

- Add mechanical checks for loose test assertions and README/example drift. When `main.tf` changes, revisit the example README and tests.

## 1.9

- Regula/OPA references were removed from the skeleton. Use the current unified Terraform check workflow and current Makefile targets.

## 1.8

- Avoid Terraform reserved variable names. Verify output attributes against provider schema. Keep example outputs aligned with tests. Use account-scoped unique names where cloud resources require uniqueness.

## 1.7

- Treat specific-value assertions, differentiated functional/readonly tests, security verification, README accuracy, and template cleanup as high-severity requirements.

## 1.6

- Remove skeleton placeholders, generate terraform-docs output, require output descriptions, validate bounded inputs, and keep examples complete.

## 1.5

- Examples should use security-first defaults and cleanup should search broadly for skeleton/template references.

## 1.4

- Legacy GitHub agent files required frontmatter first to be recognized.

## 1.3

- Agent guidance moved into `.github/agents/` in the older layout and gained a skeleton cleanup checklist.

## 1.2

- Resource naming module usage was corrected: use `for_each = var.resource_names_map`, `class_env`, required `cloud_resource_type` and `maximum_length`, and output format references such as `module.resource_names["key"].format`.

## 1.1

- Terratest should verify real resource state through provider APIs, not only Terraform outputs.

## 1.0

- Initial primitive module guidance.
