# Tasks: 既存devcontainer外部注入

> 他agentが設計コンテキスト無しで実装できるよう、各タスクは具体的に（ファイルパス・関数・テスト）書く。

## 実装タスク（順序付き）

### TASK-001: Dev Container Feature skeleton

- [ ] `features/agents/devcontainer-feature.json`, `features/agents/install.sh`, `features/agents/scripts/` を追加し、Dev Container Feature として agents runtime を注入できる最小骨格を作る。対応AC: AC-001, AC-004, AC-005
- [ ] `tests/feature-agents.bats` を追加し、Feature metadata が valid JSON であること、required fields があること、install script が Debian/Ubuntu 以外を明確に unsupported として扱うことを検証する。対応AC: AC-005, AC-007

### TASK-002: adc up wrapper

- [ ] `bin/adc` を追加し、`adc up [workspace]` が `devcontainer up --workspace-folder <workspace> --additional-features <agents feature>` と repo 外 state mount を組み立てるようにする。対応AC: AC-002, AC-003, AC-004
- [ ] `tests/adc-up.bats` を追加し、`adc up --dry-run <workspace>` の出力に agents Feature、repo 外 mount、workspace folder が含まれ、target repo にファイルが作られないことを検証する。対応AC: AC-002, AC-003, AC-004, AC-007

### TASK-003: External injection documentation

- [ ] `docs/external-injection.md` を追加し、VS Code `dev.containers.defaultFeatures`、dotfiles settings、`adc up`、raw `devcontainer up` の制約、対応 matrix、既存 scaffold 方式との使い分けを記載する。対応AC: AC-001, AC-002, AC-003, AC-004, AC-005
- [ ] `README.md` に外部注入方式への短い導線を追加し、新規repo向け scaffold と既存devcontainer repo向け外部注入を明確に分ける。対応AC: AC-001, AC-002, AC-003, AC-006
- [ ] `tests/external-injection-docs.bats` を追加し、docs に `dev.containers.defaultFeatures`, `adc up`, raw `devcontainer up` の制約、repo を汚さない方針、Debian/Ubuntu 限定が記載されていることを検証する。対応AC: AC-001, AC-002, AC-003, AC-005, AC-007

### TASK-004: Regression verification

- [ ] 既存回帰として `bats tests/feature-agents.bats tests/adc-up.bats tests/external-injection-docs.bats tests/scaffold.bats tests/merge.bats` を実行し、全て green にする。対応AC: AC-006, AC-007

## テスト（受入条件との対応・必須）

- [ ] AC-001 → test: `tests/external-injection-docs.bats` の `@test "documents VS Code defaultFeatures external injection" { ... }`
- [ ] AC-002 → test: `tests/adc-up.bats` の `@test "adc up dry-run injects agents feature with additional-features" { ... }`
- [ ] AC-003 → test: `tests/external-injection-docs.bats` の `@test "documents raw devcontainer up limitation" { ... }`
- [ ] AC-004 → test: `tests/adc-up.bats` の `@test "adc up dry-run keeps state outside target repository" { ... }`
- [ ] AC-005 → test: `tests/feature-agents.bats` の `@test "feature install script declares Debian Ubuntu support boundary" { ... }`
- [ ] AC-006 → test: `tests/scaffold.bats` と `tests/merge.bats` を実行し、既存 scaffold/merge 挙動が green であることを検証する。
- [ ] AC-007 → test: `tests/feature-agents.bats`, `tests/adc-up.bats`, `tests/external-injection-docs.bats` を実行し、Feature metadata、argument generation、docs constraints、repo-clean behavior を検証する。

## 完了の定義

- [ ] 全AC対応テストが green
- [ ] `bats tests/feature-agents.bats tests/adc-up.bats tests/external-injection-docs.bats tests/scaffold.bats tests/merge.bats` が green
- [ ] `.devcontainer/**`, `scaffold/**`, `scripts/smoke-devcontainer.sh`, `tests/smoke-devcontainer.bats` のいずれかを変更した場合は `scripts/smoke-devcontainer.sh` を実行し、未実行なら理由と merge block 条件を PR description に記載
- [ ] CI green
- [ ] sdd-reviewer 合格

