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

## サブモジュール管理の注意

`vendor/ai-sdd-guide` はこのリポジトリ自身の開発用サブモジュール。消費プロジェクトには不要。

**消費プロジェクトでサブモジュールを更新する際は `--recursive` を使わないこと。**
`--recursive` を使うと `vendor/agents-devcontainer/vendor/ai-sdd-guide` が意図せず初期化される。

```bash
# 正しい更新方法（消費プロジェクト側）
git submodule update --init
git submodule update --remote vendor/agents-devcontainer

# NG
git submodule update --init --recursive  # ai-sdd-guide がネストして取り込まれる
```

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
