@AGENTS.md

# Claude Code Notes

Use `AGENTS.md` as the shared operating contract. Claude-specific routing lives in `.claude/rules/`.

When a task matches primitive module creation, reference architecture creation, or module cleanup, follow the corresponding workflow under `.agents/skills/` and read only the referenced material needed for that task.

Keep `CLAUDE.md` concise. Put task-specific guidance in `.claude/rules/` or `.agents/skills/` rather than expanding this file.
