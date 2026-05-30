# Project Guidelines (Claude Code)

This project follows Spec-Driven Development (SDD). The canonical rules live in the submodule.
Read these before any work:

@vendor/ai-sdd-guide/rules/core.md
@vendor/ai-sdd-guide/rules/workflow.md
@vendor/ai-sdd-guide/rules/subagents.md
@vendor/ai-sdd-guide/rules/conventions.md

- 設計フェーズ (spec/plan/tasks/verify) は Claude のみ。superpowers と subagent を使う。
- 実装は他agentでも可。`specs/<feature>/` を契約として厳守する。
- 人間向け解説: `vendor/ai-sdd-guide/docs/`  ／ 雛形: `vendor/ai-sdd-guide/templates/`
- Hooks: `integration/settings.json.example` を `.claude/settings.json` に取り込む。
- Subagents: `integration/agents/` を `.claude/agents/` に取り込む。

## docs/superpowers/ の扱い

`docs/superpowers/specs/` と `docs/superpowers/plans/` はフィーチャーの設計・実装記録。
**PR マージ前に必ずコミットすること。** finishing-a-development-branch の PR 作成ステップで未追跡の `docs/superpowers/` ファイルがあれば、自動的に `git add docs/superpowers/` してコミットしてから push する。

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
