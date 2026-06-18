# Tasks: hermes-superpowers-bootstrap

`docs/superpowers/plans/2026-06-19-hermes-superpowers-bootstrap.md` の同名タスクを参照。

## Task 1 — postCreate bootstrap wiring

- [ ] `tests/agents-post-create.bats` に fake `hermes` を使う RED tests を追加する。対応AC: AC1, AC2, AC3, AC4, AC5
- [ ] `.devcontainer/scripts/agents-post-create` に Hermes superpowers bootstrap helper を追加する。対応AC: AC1, AC2, AC3, AC4, AC5
- [ ] `bats tests/agents-post-create.bats` で GREEN を確認する。

## Task 2 — docs and docs tests

- [ ] `tests/hermes-install.bats` に docs 検証を追加する。対応AC: AC6, AC7
- [ ] `README.md` に Hermes superpowers bootstrap を追記する。対応AC: AC6
- [ ] `.devcontainer/Agents.md` に Hermes superpowers bootstrap の運用ルールを追記する。対応AC: AC7
- [ ] `bats tests/hermes-install.bats` で GREEN を確認する。

## Task 3 — full verification

- [ ] `for f in .devcontainer/scripts/*; do bash -n "$f"; done` を実行する。
- [ ] `bats tests/` を実行する。

## 受入条件とテスト対応

| AC | Test |
|---|---|
| AC1 | `tests/agents-post-create.bats: installs Hermes superpowers after linking Hermes state` |
| AC2 | `tests/agents-post-create.bats: skips Hermes superpowers bootstrap when hermes command is unavailable` |
| AC3 | `tests/agents-post-create.bats: installs Hermes superpowers after linking Hermes state` |
| AC4 | `tests/agents-post-create.bats: skips Hermes superpowers install when marker exists` |
| AC5 | `tests/agents-post-create.bats: keeps postCreate successful when Hermes superpowers install fails` |
| AC6 | `tests/hermes-install.bats: README documents Hermes superpowers bootstrap` |
| AC7 | `tests/hermes-install.bats: Agents.md documents Hermes superpowers bootstrap` |
| AC8 | `bats tests/` |
