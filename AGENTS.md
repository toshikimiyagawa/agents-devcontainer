# Project Guidelines

**この AGENTS.md がこのリポジトリ開発ルールの canonical な正本である。** README と
`.devcontainer/Agents.md` は概要と本ファイルへのリンクに限定し、ここと矛盾するルールを
複製しない。詳細解説は `docs/development/` に置き、本ファイルからリンクする。

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

## Environment matrix

| Environment | 実装 | Bats | image build | dogfood smoke |
|---|---|---|---|---|
| host（通常 clone、/Users 配下） | ✓ | ✓ | ✓ | ✓ |
| host（linked worktree） | ✓ | ✓ | ✓ | ✗ |
| devcontainer 内 | ✓ | ✓ | ✗ | ✗ |
| CI（ubuntu-latest） | — | ✓ | ✓ | ✓ |

smoke は必ず `/Users` 配下の**通常 clone** から実行すること。linked worktree での smoke は
設計上サポートしない（smoke は消費プロジェクト = 通常 clone の体験をシミュレートするため）。

詳細: `docs/development/environment-matrix.md`

## Phase gates

### design preflight
- [ ] `specs/<feature>/spec.md` が存在する
- [ ] environment matrix で実装環境を確認した

### implementation gate
```bash
bats tests/
for f in .devcontainer/scripts/*; do bash -n "$f"; done
bash -n scripts/*.sh
```

### verify gate
```bash
bats tests/                  # clean state で全通過
git status --porcelain        # 空であること（未コミット変更なし）
# + sdd-reviewer subagent を実行し PASS
```

### pre-PR gate
```bash
scripts/pre-pr-check.sh
```

### pre-merge gate（CI 自動）
- `sdd-check`: spec gate + orchestration check
- `test`: `bats tests/`
- `smoke-devcontainer`: devcontainer 関連パス変更時に実行

## Definition of Done

「実装完了」と「issue 完了」は別物。`.sdd/tasks.json` は canonical な
`vendor/ai-sdd-guide/orchestration/schema/tasks.schema.json` に従い、status は
`pending` / `in_progress` / `completed` / `blocked` のみ。**新しい status 値を導入しない。**
この区別は既存の `phase` と `status` の組み合わせで表現する:

| 状態 | phase | status | 意味 |
|---|---|---|---|
| 実装完了 | `implement` | `completed` | `tasks.md` 全タスク完了 + `bats tests/` green。host smoke / SDD review / PR は未実施 |
| issue 完了 | `done` | `completed` | verify gate 通過 + host smoke green + CI green + PR merged |

「実装完了」に到達しても issue は完了ではない。host smoke・SDD review・PR・CI が残る。

## smoke / draft / merge policy

- devcontainer 関連変更（`scripts/devcontainer-paths.txt` のパターンに一致）は、
  **host full smoke が green になるまで完了扱いにしない**。
- 検証済み smoke 証跡（`scripts/smoke-devcontainer.sh` が生成する `.sdd/smoke-evidence.txt`、
  HEAD 一致・成功マーカー必須）がない devcontainer 関連 PR は **ready にせず draft に留める**。
- smoke を skip / warning 化して gate を通さない。証跡は `scripts/pre-pr-check.sh` が内容検証する。

## Reporting template

各 phase 完了時に以下のテンプレートを使用する:

```
## Phase report: <phase名>
- spec: specs/<feature>/spec.md
- current phase / status: <implement|verify|done> / <completed|blocked>（schema 準拠）
- changed files: <リスト>
- bats tests/: PASS / FAIL (<N> tests)
- bash -n: PASS / FAIL
- host smoke: PASS / FAIL / NOT_RUN（理由）
- sdd-reviewer: PASS / FAIL / NOT_RUN
- PR URL: <url or N/A>
- CI: <green | pending | N/A>
- 未実施項目: <リスト or なし>
```

## Blocker handling

frozen `tasks.md` の範囲外の問題で作業が止まった場合:
1. 即座に停止する
2. `.sdd/tasks.json` の当該 feature を `blocked` に設定し `blocked_reason` に詳細を記入
3. follow-up issue を作成（再現手順・影響 AC・元 issue の resume 条件を含める）
4. resume は follow-up issue close または human の明示指示のみ

scope creep を spec 変更で吸収してはいけない。必ず follow-up issue を作成する。

詳細: `docs/development/blocker-handling.md`
