# Project Guidelines

This project follows Spec-Driven Development (SDD).
Read the canonical rules before any work:
- `vendor/ai-sdd-guide/rules/core.md`
- `vendor/ai-sdd-guide/rules/workflow.md`
- `vendor/ai-sdd-guide/rules/subagents.md`
- `vendor/ai-sdd-guide/rules/conventions.md`
- `vendor/ai-sdd-guide/orchestration/rules/orchestration.md`
- `vendor/ai-sdd-guide/catalog/rules/catalog.md`

## Design phases (superpowers required)
Use superpowers skills (brainstorming → writing-plans) for spec/plan/tasks.
Capture output into `specs/<feature>/`. Human approves before freezing.

## Implementation phase (any agent, no superpowers needed)
Implement exactly the frozen `specs/<feature>/tasks.md`. No more, no less.
Every acceptance criterion must map to a passing test.
If the spec is wrong or insufficient: STOP and escalate. Do not redesign.

## Verify phase (superpowers required)
Run the `sdd-reviewer` subagent/prompt against the diff to confirm the implementation
matches the frozen spec. See `vendor/ai-sdd-guide/orchestration/rules/orchestration.md`
for agent-specific instructions (Claude Code / Codex / Gemini CLI).

## Hard rules
- Do not modify files under `specs/` to fit an implementation.
- Do not expand scope beyond approved tasks.
- Do not disable SDD hooks or CI.

Human-facing docs: `vendor/ai-sdd-guide/docs/`
Templates: `vendor/ai-sdd-guide/templates/`
Claude hooks: `.claude/settings.json` (copy from `vendor/ai-sdd-guide/integration/settings.json.example`)
Codex hooks: `.codex/config.toml` (copy from `vendor/ai-sdd-guide/integration/codex/config.toml.example`)
Subagents: `.claude/agents/` (copy from `vendor/ai-sdd-guide/integration/agents/`)

## CLAUDE.md
CLAUDE.md is a symlink to this file. Do not replace it with a regular file.

(If you change the submodule path, update all paths above to match.)

## テスト

```bash
# 実行方法（要 bats-core: brew install bats-core）
bats tests/
```

テストは `tests/` 以下に配置する。`scaffold.sh` の変更には `tests/scaffold.bats` を更新すること。
