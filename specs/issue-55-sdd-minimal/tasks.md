# Tasks: Issue #55 Minimal SDD Traceability

各taskはRED → GREEN → review → commitの順で実行する。frozen後はこのfileを
変更しない。

### TASK-001: Add focused contract tests and fixtures

- [ ] `tests/check-sdd-contract.bats`へfreeze/verifyのvalid fixture helperを追加する。
- [ ] traceability JSON、mapping、state/tasks、Git baseの全named testを追加する。
- [ ] PR #54型の不整合fixtureを追加する。
- [ ] `bats tests/check-sdd-contract.bats`を実行し、validator欠落による期待したREDを記録する。
- [ ] test fileが400行以内であることを確認する。
- [ ] commitする。

Tests: `tests/check-sdd-contract.bats`の全test。

### TASK-002: Implement the minimal validator

- [ ] `scripts/check-sdd-contract.sh`をfreeze modeから最小実装する。
- [ ] focused testsをGREENにする。
- [ ] verify state/tasks/test-reference/base/Tier検査を追加する前に対応testのREDを確認する。
- [ ] verify testsをGREENにする。
- [ ] Bash syntax、fail-closed diagnostics、250行上限を確認する。
- [ ] commitする。

Tests: `tests/check-sdd-contract.bats`の全test。

### TASK-003: Add CI, reviewer, and documentation integration

- [ ] `tests/sdd-contract-policy.bats`へworkflow/reviewer/docs/size/vendor testを追加する。
- [ ] policy testsの期待したREDを記録する。
- [ ] 既存`.github/workflows/sdd-check.yml`のgateを保持してTier 2 validatorを追加する。
- [ ] `.claude/agents/sdd-reviewer.md`、AGENTS.md、詳細docsを最小更新する。
- [ ] policy testsをGREENにし、validator/test size budgetを再確認する。
- [ ] commitする。

Tests: `tests/sdd-contract-policy.bats`の全test。

### TASK-004: Dogfood and hand off to verify

- [ ] #55自身のtraceabilityをfreeze modeで検証する。
- [ ] traceabilityの全test referenceがexactに1件存在することを確認する。
- [ ] `bats tests/`を全実行する。
- [ ] 全shell syntax、`git diff --check`、vendor boundaryを確認する。
- [ ] validator 250行、focused test 400行の上限を確認する。
- [ ] `.sdd/tasks.json`の対象entryだけをphase `implement`、status `completed`にする。
- [ ] kanbanを表示し、verifyを開始せずcommitする。

Tests: focused tests、policy tests、full `bats tests/`。
