# Issue #55 Minimal SDD Traceability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a small repository-local Tier 2 traceability validator without replacing existing SDD gates or attempting to authenticate human process evidence.

**Architecture:** A single Bash script validates one fixed JSON contract with jq and checks repository state in freeze/verify modes. Existing GitHub Actions gates remain intact and call the validator only as an additional Tier 2 check; an independent reviewer owns semantic comparison with the source Issue.

**Tech Stack:** Bash 3.2, Git, jq, Bats, GitHub Actions YAML.

## Global Constraints

- `scripts/check-sdd-contract.sh` must remain at or below 250 lines.
- `tests/check-sdd-contract.bats` must remain at or below 400 lines.
- Do not add JSON Schema files, a schema interpreter, process evidence, attestation, or a Bats wrapper.
- Do not modify `vendor/ai-sdd-guide` or PR #54 implementation files.
- Preserve existing Tier 0/1, spec, blocked-task, implement-handoff, and full-Bats gates.
- Use only Bash 3.2, Git, jq, and Bats; no network or new package dependency.
- Missing dependencies/artifacts, JSON/Git errors, and required-data failures exit 1; CLI usage errors exit 2.
- Do not modify frozen files under `specs/` during implementation.

## File map

- `scripts/check-sdd-contract.sh`: fixed-format freeze/verify validator.
- `tests/check-sdd-contract.bats`: validator behavior and PR #54 regression fixture.
- `tests/fixtures/sdd-contract-minimal/pr54-invalid/`: stable inconsistent-state fixture.
- `tests/sdd-contract-policy.bats`: additive CI, reviewer, docs, size, TDD contract, and vendor assertions.
- `.github/workflows/sdd-check.yml`: existing workflow plus Tier 2 validator invocation.
- `.claude/agents/sdd-reviewer.md`: semantic source-Issue review boundary.
- `AGENTS.md`: concise hard gate and detailed-doc link.
- `docs/development/sdd-traceability.md`: human workflow and finite negative checklist.

---

### TASK-001: Add focused contract tests and fixtures

**Files:**
- Create: `tests/check-sdd-contract.bats`
- Create: `tests/fixtures/sdd-contract-minimal/pr54-invalid/.sdd/state.json`
- Create: `tests/fixtures/sdd-contract-minimal/pr54-invalid/.sdd/tasks.json`
- Create: `tests/fixtures/sdd-contract-minimal/pr54-invalid/specs/development-rules/tasks.md`

**Interfaces:**
- Tests invoke `scripts/check-sdd-contract.sh` with `REPO_ROOT`, `GIT_BIN`, and `JQ_BIN` overrides.
- A valid temporary fixture contains `spec.md`, `plan.md`, `tasks.md`, `traceability.json`, `.sdd/state.json`, and `.sdd/tasks.json`.

- [ ] Create a Bats `setup` that builds one valid fixture and an exact Bats declaration:

```bash
setup() {
  REPO_ROOT=$(mktemp -d)
  export REPO_ROOT GIT_BIN=git JQ_BIN=jq
  FEATURE=fixture
  mkdir -p "$REPO_ROOT/specs/$FEATURE" "$REPO_ROOT/.sdd" "$REPO_ROOT/tests"
  printf '%s\n' '- [x] AC-001: fixture' > "$REPO_ROOT/specs/$FEATURE/spec.md"
  printf '%s\n' '# Plan' > "$REPO_ROOT/specs/$FEATURE/plan.md"
  printf '%s\n' '### TASK-001: Fixture' '- [x] complete' > "$REPO_ROOT/specs/$FEATURE/tasks.md"
  printf '%s\n' '@test "fixture passes" {' '  true' '}' > "$REPO_ROOT/tests/fixture.bats"
}
```

- [ ] Add these exact tests:

```text
accepts a valid freeze contract
rejects malformed or multi-value traceability JSON
rejects untracked and duplicate issue criteria
rejects incomplete implemented mapping
rejects invalid follow-up mapping
rejects missing and orphaned spec or task references
accepts a valid verify contract
rejects state feature tier or phase mismatch
rejects missing duplicate or noncanonical feature task
rejects blocked tasks and unchecked task boxes
rejects missing or duplicate Bats test declarations
rejects unavailable base and feature mismatch
rejects expected tier mismatch
rejects the PR 54 inconsistent state fixture
```

- [ ] Make every negative test assert exit 1 and an artifact/invariant-specific diagnostic.
- [ ] Run `bats tests/check-sdd-contract.bats`; expect RED because the validator does not exist.
- [ ] Run `wc -l tests/check-sdd-contract.bats`; require at most 400.
- [ ] Commit with `test(issue-55-sdd-minimal): define contract behavior`.

### TASK-002: Implement the minimal validator

**Files:**
- Create: `scripts/check-sdd-contract.sh`
- Modify: `tests/check-sdd-contract.bats` only to correct a test defect; behavior expansion requires escalation.

**Interfaces:**

```text
scripts/check-sdd-contract.sh --feature SLUG --mode freeze
scripts/check-sdd-contract.sh --feature SLUG --mode verify --base COMMIT --expected-tier 2
```

- [ ] Implement strict, single-use argument parsing with these helpers:

```bash
usage() { printf 'usage: %s --feature SLUG --mode freeze|verify [--base COMMIT --expected-tier 2]\n' "$0" >&2; exit 2; }
fail() { printf '[sdd-contract] ERROR: %s\n' "$*" >&2; exit 1; }
```

- [ ] Before reading fields, require `jq -s 'length == 1'` for each JSON artifact.
- [ ] Validate traceability with one fixed jq expression. It must check exact object keys, URL/ID formats, unique Issue ACs, and disposition conditions. Do not read a schema file.
- [ ] Extract IDs only from these forms:

```text
- [ ] AC-NNN: text
- [x] AC-NNN: text
### TASK-NNN: text
```

- [ ] Compare sorted unique sets so every spec AC and task appears in traceability and every mapped ID exists.
- [ ] Make `freeze` return after the fixed JSON and ID checks pass.
- [ ] Add `verify` checks in this order: state shape/value; canonical tasks array; unique current task; global blocked count; unchecked checkbox count; referenced test containment/exact declaration; base resolution/diff; feature and Tier equality.
- [ ] Resolve changed feature paths with `git diff --name-only -z "$base"...HEAD -- specs` and a NUL-safe loop. More than one changed feature or a changed feature different from `--feature` fails.
- [ ] Reject referenced symlinks and physical parent paths outside `REPO_ROOT`. Count a declaration only when the trimmed line equals `@test "<name>" {`.
- [ ] Run `bats tests/check-sdd-contract.bats`; expect every focused test GREEN.
- [ ] Run `bash -n scripts/check-sdd-contract.sh` and both size checks; expect success and at most 250/400 lines.
- [ ] Commit with `feat(issue-55-sdd-minimal): add fixed contract validator`.

### TASK-003: Add CI, reviewer, and documentation integration

**Files:**
- Create: `tests/sdd-contract-policy.bats`
- Modify: `.github/workflows/sdd-check.yml`
- Modify: `.claude/agents/sdd-reviewer.md`
- Modify: `AGENTS.md`
- Create: `docs/development/sdd-traceability.md`

**Interfaces:**
- CI passes PR base SHA and the single numeric Tier label to the validator.
- Reviewer output contains source comparison, AC/test findings, scope findings, commands/counts, reviewed SHA, and PASS/FAIL.

- [ ] Add these exact policy tests before production/doc changes:

```text
workflow preserves existing gates and adds the Tier 2 validator
reviewer compares source meaning and completion evidence
docs define the practical trust boundary
implementation plan requires RED before GREEN
enforces validator and test size budgets
vendored SDD guide remains unchanged
```

- [ ] Run `bats tests/sdd-contract-policy.bats`; expect the first five new policies to RED and vendor boundary to GREEN.
- [ ] Keep the existing workflow jobs and checks. Add only Tier-label extraction and this Tier 2 call:

```bash
scripts/check-sdd-contract.sh \
  --feature "$(jq -r .feature .sdd/state.json)" \
  --mode verify \
  --base "${{ github.event.pull_request.base.sha }}" \
  --expected-tier 2
```

- [ ] Update reviewer instructions to compare GitHub Issue semantics with traceability/spec/tests and state that validator green is insufficient.
- [ ] Add concise AGENTS gates and detailed docs with the finite negative checklist from the frozen design.
- [ ] State explicitly that reviewer identity and past TDD execution are not machine-authenticated.
- [ ] Run policy and focused tests; expect GREEN.
- [ ] Re-run size, symlink, vendor, and `git diff --check` assertions.
- [ ] Commit with `ci(issue-55-sdd-minimal): add practical traceability gate`.

### TASK-004: Dogfood and hand off to verify

**Files:**
- Modify: `.sdd/tasks.json`
- Do not modify: `specs/`, `.sdd/state.json`, catalog status, vendor files.

**Interfaces:**
- Implementation completion leaves task phase `implement`, sets status `completed`, and does not start verify.

- [ ] Run `scripts/check-sdd-contract.sh --feature issue-55-sdd-minimal --mode freeze`; expect exit 0.
- [ ] For every test reference in traceability, verify file existence and exactly one declaration, then run the referenced Bats file.
- [ ] Run `bats tests/`; expect zero failures.
- [ ] Run `bash -n scripts/*.sh` and `for f in .devcontainer/scripts/*; do bash -n "$f"; done`; expect success.
- [ ] Run `wc -l scripts/check-sdd-contract.sh tests/check-sdd-contract.bats`; require at most 250 and 400.
- [ ] Run `git diff --check` and `git diff --submodule=short origin/main...HEAD -- vendor/ai-sdd-guide`; expect no output.
- [ ] Update only the current `.sdd/tasks.json` entry to phase `implement`, status `completed`, blocked_reason `null`.
- [ ] Run `bash vendor/ai-sdd-guide/orchestration/tools/kanban.sh` and stop before verify.
- [ ] Commit with `chore(issue-55-sdd-minimal): complete implementation handoff`.

## Acceptance-criterion coverage

- AC-001–AC-005: TASK-001/TASK-002 freeze tests.
- AC-006–AC-009: TASK-001/TASK-002 verify tests.
- AC-010–AC-012: TASK-003 policy tests.
- AC-013: TASK-001 complete negative suite and PR #54 fixture.
- AC-014: Every implementation task's recorded RED/GREEN cycle plus TASK-003 policy test.
- AC-015: TASK-003/TASK-004 line-budget policy and command.
- AC-016: TASK-003/TASK-004 vendor-boundary test and diff.
