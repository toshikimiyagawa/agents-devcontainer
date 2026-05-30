# Spec: decouple-sdd

## Intent

`agents-devcontainer` を devcontainer 管理に専念させ、SDD（ai-sdd-guide）の配布責務を外す。
消費プロジェクトは `vendor/agents-devcontainer`（devcontainer）と `vendor/ai-sdd-guide`（SDD）を
それぞれ独立した submodule として管理する。

agents-devcontainer 自身の開発は引き続き ai-sdd-guide（`vendor/ai-sdd-guide` submodule）を使う。
scaffold.sh が消費プロジェクトに ai-sdd-guide を配布する処理のみを削除する。

## Acceptance Criteria

1. `scaffold.sh` を実行しても `vendor/ai-sdd-guide` submodule が消費プロジェクトに追加されない
2. `scaffold.sh` を実行しても `CLAUDE.md`, `AGENTS.md`, `.claude/settings.json`, `.github/workflows/sdd-check.yml` が消費プロジェクトにコピーされない
3. `scaffold/sdd-update.sh` が削除されている
4. `vendor/ai-sdd-guide/integration/update.sh` が存在し、managed ファイル（`.claude/agents/`, `sdd-check.yml`）を上書き更新し、protected ファイル（`CLAUDE.md`, `AGENTS.md`, `.claude/settings.json`）は上書きせず diff を表示する
5. `bats tests/` が全て通る（`tests/sdd-update.bats` は削除済み）
6. README.md に `--recursive` 不要の旨と、消費プロジェクトでの ai-sdd-guide 独立管理の案内が記載されている
