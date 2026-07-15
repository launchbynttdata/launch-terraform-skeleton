---
paths:
  - "**/*.tf"
  - "examples/**/*.tf"
  - "tests/**/*.go"
  - "README.md"
  - "TEMPLATED_README.md"
---

# Terraform Module Files

- Keep module type boundaries clear: primitives wrap one resource type; reference architectures compose complete patterns.
- Keep examples synchronized with root variables, outputs, and README usage snippets.
- Prefer provider API constraints, Terraform validation blocks, and specific test assertions over loose or non-empty checks.
- Remove skeleton placeholders and stale template references before completion.
