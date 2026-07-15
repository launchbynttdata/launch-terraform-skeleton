# Reference Architecture Guidance Release History

This file preserves the learnings from the previous monolithic reference architecture guide.

## 3.1

- Skeleton updates now add the `.agents/`, `.claude/`, and `.cursor/` guidance trees. Reviewers of automatic update PRs should expect this additive template change.

## 2.0

- Readonly tests must use non-destructive helpers. Add a skeleton transformation verification gate. Include Lambda source directories when examples need deployable source. Avoid duplicate CloudWatch log groups with `terraform-aws-modules/lambda/aws`. Use registry module source formats. Keep output prefixes consistent. Prefer `create_*` feature flags. Strengthen the ban on loose non-empty assertions.

## 1.9

- Complete examples must not redundantly compose `resource_names`. Do not commit `providers.tf` in examples. Use `RunNonDestructiveTest` for readonly tests. Check community module compatibility before choosing versions. Remove stale skeleton names from go.mod, imports, and test functions. Avoid duplicate IAM permissions.

## 1.8

- Strengthen specific-value assertions, differentiate functional and readonly tests, mandate KMS/encryption verification where configured, and require README tables to match actual code.

## 1.7

- Keep cloud-provider guidance balanced. Add Azure networking and security patterns alongside AWS examples.

## 1.6

- Provider SDK verification examples were added for AWS services and read-only versus destructive test flows.

## 1.5

- SDK verification is mandatory for meaningful tests. IAM should use least privilege and avoid duplicated policy attachments. Community module versions need compatibility checks.

## 1.4

- Legacy GitHub agent files required frontmatter first to be recognized.

## 1.3

- Agent guidance moved into `.github/agents/` in the older layout and gained a skeleton cleanup checklist.

## 1.2

- Resource naming module usage was corrected: use `for_each = var.resource_names_map`, `class_env`, required `cloud_resource_type` and `maximum_length`, output format references, and no obsolete `resource_names_strategy` variable.

## 1.1

- Terratest should verify real resource state through provider APIs, and reference architecture tests should cover optional features enabled by examples.

## 1.0

- Initial reference architecture guidance.
