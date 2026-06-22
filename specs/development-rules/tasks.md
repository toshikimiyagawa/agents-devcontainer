# Tasks: development-rules

実装計画の詳細は `docs/superpowers/plans/2026-06-22-development-rules.md` を参照。
TDD（RED→GREEN）と頻繁な commit を守ること。

## Task 1 — tests/pre-pr-check.bats（RED）
- [x] `tests/pre-pr-check.bats` を作成する
- [x] `bats tests/pre-pr-check.bats` で RED を確認する
- [x] commit

## Task 2 — scripts/pre-pr-check.sh（GREEN）
- [x] `scripts/pre-pr-check.sh` を実装する、`chmod +x`
- [x] `bats tests/pre-pr-check.bats` で GREEN を確認する
- [x] `bash -n scripts/pre-pr-check.sh` を確認する
- [x] commit

## Task 3 — .gitignore + smoke-devcontainer.yml
- [x] `.gitignore` に `.sdd/smoke-evidence.txt` を追加する
- [x] `smoke-devcontainer.yml` に evidence artifact upload ステップを追加する
- [x] commit

## Task 4 — docs/development/（3ファイル）
- [x] `docs/development/environment-matrix.md` を作成する
- [x] `docs/development/smoke-guide.md` を作成する
- [x] `docs/development/blocker-handling.md` を作成する
- [x] commit

## Task 5 — AGENTS.md（5セクション）
- [x] environment matrix / phase gates / Definition of Done / reporting template / blocker handling を追記する
- [x] commit

## Task 6 — PR template
- [x] `.github/pull_request_template.md` を作成する
- [x] commit

## Task 7 — specs/development-rules/ artifacts
- [ ] `specs/development-rules/spec.md` を作成する
- [ ] `specs/development-rules/plan.md` を作成する
- [ ] `specs/development-rules/tasks.md` を作成する（この file）
- [ ] commit

## Task 8 — 総合検証
- [ ] `bats tests/` 全通過
- [ ] `for f in .devcontainer/scripts/*; do bash -n "$f"; done`
- [ ] `bash -n scripts/*.sh`

## 受け入れ基準 ↔ テスト 対応表

| AC | 検証 |
|---|---|
| 1-5 (AGENTS.md セクション) | Task5 / 目視確認 |
| 6-8 (docs/development/) | Task4 / 目視確認 |
| 9 (pre-pr-check.sh 基本動作) | `pre-pr-check.bats: exits 0 when no devcontainer changes...` |
| 10 (smoke 証跡チェック) | `pre-pr-check.bats: exits 1 when devcontainer change detected but no smoke evidence` |
| 11 (PR template) | Task6 / 目視確認 |
| 12 (.gitignore) | Task3 / `grep smoke-evidence .gitignore` |
| 13 (bats テスト存在) | Task1 |
| 14 (bats tests/ 全通過) | Task8 |
| 15 (bash -n) | Task2 + Task8 |
