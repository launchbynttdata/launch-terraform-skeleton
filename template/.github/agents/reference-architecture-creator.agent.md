---
name: Terraform Reference Architecture Creator
description: Compatibility stub for agents looking for the legacy reference architecture creator guide.
---

<!-- version: 3.1 -->

# Terraform Reference Architecture Creator

The reference architecture guide has moved to the agent-agnostic instruction layout.

Use these files instead:

- Baseline operating rules: [AGENTS.md](../../AGENTS.md)
- Codex-style workflow skill: [.agents/skills/reference-architecture/SKILL.md](../../.agents/skills/reference-architecture/SKILL.md)
- Cursor project rule: [.cursor/rules/reference-architecture-workflow.mdc](../../.cursor/rules/reference-architecture-workflow.mdc)
- Claude routing rules: [.claude/rules/agent-routing.md](../../.claude/rules/agent-routing.md)
- Shared Terraform standards: [.agents/references/shared/terraform-module-standards.md](../../.agents/references/shared/terraform-module-standards.md)
- Reference architecture standards: [.agents/references/reference-architecture/standards.md](../../.agents/references/reference-architecture/standards.md)
- Reference architecture testing guidance: [.agents/references/reference-architecture/testing.md](../../.agents/references/reference-architecture/testing.md)
- Condensed release history: [.agents/references/reference-architecture/release-history.md](../../.agents/references/reference-architecture/release-history.md)

This file remains only for compatibility with tools or prompts that still inspect `.github/agents/`.
