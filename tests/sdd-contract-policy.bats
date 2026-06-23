#!/usr/bin/env bats

setup() {
  REPO_ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)
}

assert_contains() {
  grep -F -- "$2" "$REPO_ROOT/$1" >/dev/null
}

@test "workflow preserves existing gates and adds the Tier 2 validator" {
  workflow=.github/workflows/sdd-check.yml
  assert_contains "$workflow" "- name: Spec gate"
  assert_contains "$workflow" "- name: Tests"
  assert_contains "$workflow" "run: bats tests/"
  assert_contains "$workflow" "No blocked tasks allowed on merge."
  assert_contains "$workflow" "Every in_progress or pending implement task must have a handoff.md."
  assert_contains "$workflow" 'test("^sdd:tier-[012]$")'
  assert_contains "$workflow" 'Tier labels must be unique'
  assert_contains "$workflow" 'if [ "$tier" = 2 ]; then'
  assert_contains "$workflow" 'scripts/check-sdd-contract.sh \'
  assert_contains "$workflow" '--feature "$(jq -r .feature .sdd/state.json)" \'
  assert_contains "$workflow" '--mode verify \'
  assert_contains "$workflow" '--base "${{ github.event.pull_request.base.sha }}" \'
  assert_contains "$workflow" '--expected-tier 2'
}

@test "reviewer compares source meaning and completion evidence" {
  reviewer=.claude/agents/sdd-reviewer.md
  assert_contains "$reviewer" "GitHub Issue"
  assert_contains "$reviewer" "traceability.json"
  assert_contains "$reviewer" "validator green is insufficient"
  assert_contains "$reviewer" "reviewer identity is not machine-authenticated"
  assert_contains "$reviewer" "past TDD execution is not machine-authenticated"
  assert_contains "$reviewer" "commands and test counts"
  assert_contains "$reviewer" "reviewed SHA"
  assert_contains "$reviewer" "PASS/FAIL"
}

@test "docs define the practical trust boundary" {
  docs=docs/development/sdd-traceability.md
  [ -f "$REPO_ROOT/$docs" ]
  assert_contains "$docs" "Machine-checked"
  assert_contains "$docs" "Independent review"
  assert_contains "$docs" "reviewer identity is not machine-authenticated"
  assert_contains "$docs" "past TDD execution is not machine-authenticated"
  assert_contains "$docs" "malformed or multi-value JSON"
  assert_contains "$docs" "untracked or duplicate Issue AC"
  assert_contains "$docs" "incomplete implemented mapping"
  assert_contains "$docs" "invalid follow-up reason or Issue URL"
  assert_contains "$docs" "missing or orphaned spec AC or task"
  assert_contains "$docs" "state feature, tier, or phase mismatch"
  assert_contains "$docs" "missing, duplicate, blocked, incomplete, or noncanonical task state"
  assert_contains "$docs" "missing or duplicate exact Bats declaration"
  assert_contains "$docs" "unavailable base or feature mismatch"
  assert_contains "$docs" "expected Tier mismatch"
  assert_contains "$docs" "PR #54 inconsistent-state fixture"
}

@test "implementation plan requires RED before GREEN" {
  assert_contains specs/issue-55-sdd-minimal/tasks.md "RED → GREEN"
  report=.superpowers/sdd/task-3-report.md
  [ -f "$REPO_ROOT/$report" ]
  assert_contains "$report" "## RED evidence"
  assert_contains "$report" "first five"
  assert_contains "$report" "## GREEN evidence"
}

@test "enforces validator and test size budgets" {
  [ "$(wc -l < "$REPO_ROOT/scripts/check-sdd-contract.sh")" -le 250 ]
  [ "$(wc -l < "$REPO_ROOT/tests/check-sdd-contract.bats")" -le 400 ]
  assert_contains AGENTS.md "250 lines"
  assert_contains AGENTS.md "400 lines"
  assert_contains docs/development/sdd-traceability.md "250 lines"
  assert_contains docs/development/sdd-traceability.md "400 lines"
}

@test "vendored SDD guide remains unchanged" {
  git -C "$REPO_ROOT" diff --quiet --submodule=short origin/main...HEAD -- vendor/ai-sdd-guide
  git -C "$REPO_ROOT" diff --quiet --submodule=short -- vendor/ai-sdd-guide
}
