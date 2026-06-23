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

For a Tier 2 freeze, run `scripts/check-sdd-contract.sh --feature <feature> --mode
freeze`. Before verify, use the PR base and Tier 2 label with `--mode verify --base
<commit> --expected-tier 2`; missing, malformed, inconsistent, or ambiguous contract
data fails closed. Keep `ISSUE-AC-NNN`, `AC-NNN`, and `TASK-NNN` mappings unique.
The validator and focused Bats file must remain within 250 lines and 400 lines.
See `docs/development/sdd-traceability.md` for the trust boundary and checklist.

## Verify phase (superpowers required)
Run the `sdd-reviewer` subagent/prompt against the diff to confirm the implementation
matches the frozen spec. See `vendor/ai-sdd-guide/orchestration/rules/orchestration.md`
for agent-specific instructions (Claude Code / Codex / Gemini CLI).
Validator green does not replace independent comparison with the source Issue or
review of whether mapped tests prove their acceptance criteria.

## Hard rules
- Do not modify files under `specs/` to fit an implementation.
- Do not expand scope beyond approved tasks.
- Do not disable SDD hooks or CI.
- **Never push directly to `main`.** Always use a feature branch and open a PR.

Human-facing docs: `vendor/ai-sdd-guide/docs/`
Templates: `vendor/ai-sdd-guide/templates/`
Claude hooks: `.claude/settings.json` (copy from `vendor/ai-sdd-guide/integration/settings.json.example`)
Codex hooks: `.codex/config.toml` (copy from `vendor/ai-sdd-guide/integration/codex/config.toml.example`)
Subagents: `.claude/agents/` (copy from `vendor/ai-sdd-guide/integration/agents/`)

## CLAUDE.md
CLAUDE.md is a symlink to this file. Do not replace it with a regular file.

(If you change the submodule path, update all paths above to match.)

## サブモジュール管理の注意

`vendor/ai-sdd-guide` はこのリポジトリ自身の開発用サブモジュール。消費プロジェクトには不要。

`.gitmodules` に `update = none` を設定しているため、消費プロジェクトが
`git submodule update --init --recursive` を実行しても `ai-sdd-guide` はスキップされる。

このリポジトリ自身で `vendor/ai-sdd-guide` を使う場合は明示的にパス指定する：
```bash
git submodule update --init vendor/ai-sdd-guide
```

## テスト

```bash
# 実行方法（要 bats-core: brew install bats-core）
bats tests/
```

テストは `tests/` 以下に配置する。`scaffold.sh` の変更には `tests/scaffold.bats` を更新すること。
