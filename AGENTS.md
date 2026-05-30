# Project Guidelines (AGENTS.md)

This project uses Spec-Driven Development (SDD). As an implementation agent your job is to
implement the **frozen spec** — not to design.

## Before coding
1. Find the active spec under `specs/<feature>/` (`spec.md` / `plan.md` / `tasks.md`).
2. Implement exactly the tasks in `tasks.md`. Every acceptance criterion in `spec.md` must map to a test.

## Hard rules (CI enforces these)
- Do NOT change behavior beyond the approved tasks.
- Every acceptance criterion must have a passing test.
- If the spec is wrong, ambiguous, or insufficient: STOP and leave a note for a human. Do not redesign.
- Do not modify files under `specs/` to fit your implementation.

詳細: `vendor/ai-sdd-guide/rules/` (英語) ／ `vendor/ai-sdd-guide/docs/` (日本語)

## テスト

```bash
# 実行方法（要 bats-core: brew install bats-core）
bats tests/
```

テストは `tests/` 以下に配置する。`scaffold.sh` の変更には `tests/scaffold.bats` を更新すること。
