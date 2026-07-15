---
name: Terraform Primitive Module Creator
description: Compatibility stub for agents looking for the legacy primitive module creator guide.
---

<!-- version: 2.1 -->

# Terraform Primitive Module Creator

The primitive module guide has moved to the agent-agnostic instruction layout.

Use these files instead:

- Baseline operating rules: [AGENTS.md](../../AGENTS.md)
- Reusable workflow: [.agents/skills/primitive-module/SKILL.md](../../.agents/skills/primitive-module/SKILL.md)
- Shared Terraform standards: [.agents/references/shared/terraform-module-standards.md](../../.agents/references/shared/terraform-module-standards.md)
- Primitive interface standards: [.agents/references/primitive/standards.md](../../.agents/references/primitive/standards.md)
- Creation, cleanup, and documentation guidance: [.agents/references/primitive/creation.md](../../.agents/references/primitive/creation.md)
- Terratest guidance: [.agents/references/primitive/testing.md](../../.agents/references/primitive/testing.md)
- Condensed release history and preserved learnings: [.agents/references/primitive/release-history.md](../../.agents/references/primitive/release-history.md)
- Cursor project rule: [.cursor/rules/primitive-module-workflow.mdc](../../.cursor/rules/primitive-module-workflow.mdc)
- Claude routing rules: [.claude/rules/agent-routing.md](../../.claude/rules/agent-routing.md) and [.claude/rules/terraform-files.md](../../.claude/rules/terraform-files.md)

This file remains only for compatibility with tools or prompts that still inspect `.github/agents/`.
