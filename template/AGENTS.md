# Launch Terraform Module Agent Guide

This repository follows the Launch Terraform module standards. Keep this file small: it is the shared baseline for coding agents and should not contain workflow playbooks or long reference material.

## Working Agreement

- Read the current files before making changes. Do not assume the generated template still matches this repository.
- Make the smallest change that satisfies the requested outcome.
- Keep primitive modules and reference architecture modules distinct.
- Prefer clear Terraform, explicit variable types, useful descriptions, and validation for constrained inputs.
- Treat examples and tests as part of the public contract. Update them with implementation changes.
- Do not preserve skeleton placeholders, TODOs, or copied template names in completed modules.
- Do not introduce provider-specific guidance into shared rules unless it is clearly labeled by provider.
- Use `mise` for local tool execution when available. Prefer `mise run <task>` for configured tasks and `mise exec -- <command>` otherwise.
- Use SSH-based Git remotes or `gh` for GitHub repository operations. If SSH or `gh` is not working, stop and resolve that rather than silently switching to HTTPS Git remotes.
- GitHub API access through `gh api` or `gh api graphql` is acceptable when repository metadata is needed.

## Module Types

- Primitive modules wrap one cloud resource type and expose a reusable, low-opinion interface.
- Reference architecture modules compose primitives and selected mature community modules into opinionated infrastructure patterns.
- If the requested work does not clearly identify the module type, inspect the repository name and module structure before proceeding.

## Task Routing

- For primitive module creation or cleanup, use `.agents/skills/primitive-module/SKILL.md`.
- For reference architecture creation or cleanup, use `.agents/skills/reference-architecture/SKILL.md`.
- For shared Terraform standards, read `.agents/references/shared/terraform-module-standards.md`.
- For long examples, historical rationale, and provider-specific notes, read only the reference files routed by the selected skill.
- Do not load every file in `.agents/references/` by default.

## Validation Expectations

- Run the narrowest useful validation first, then broaden when the change affects shared behavior.
- Before considering module creation complete, validate formatting, linting, Terraform initialization/validation for examples, README generation, and Terratest readiness where practical.
- If full cloud-backed tests cannot be run, state what was validated and what remains unproven.
