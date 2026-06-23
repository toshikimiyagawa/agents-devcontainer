#!/usr/bin/env bats

setup() {
  REPO_ROOT=$(mktemp -d)
  export REPO_ROOT GIT_BIN=git JQ_BIN=jq
  FEATURE=fixture
  mkdir -p "$REPO_ROOT/specs/$FEATURE" "$REPO_ROOT/.sdd" "$REPO_ROOT/tests"
  printf '%s\n' '- [x] AC-001: fixture' > "$REPO_ROOT/specs/$FEATURE/spec.md"
  printf '%s\n' '# Plan' > "$REPO_ROOT/specs/$FEATURE/plan.md"
  printf '%s\n' '### TASK-001: Fixture' '- [x] complete' > "$REPO_ROOT/specs/$FEATURE/tasks.md"
  printf '%s\n' '@test "fixture passes" {' '  true' '}' > "$REPO_ROOT/tests/fixture.bats"

  git -C "$REPO_ROOT" init -q
  git -C "$REPO_ROOT" config user.email fixture@example.com
  git -C "$REPO_ROOT" config user.name Fixture
  git -C "$REPO_ROOT" commit --allow-empty -qm base
  BASE=$(git -C "$REPO_ROOT" rev-parse HEAD)

  VALIDATOR="$BATS_TEST_DIRNAME/../scripts/check-sdd-contract.sh"
  write_valid_json
  git -C "$REPO_ROOT" add .
  git -C "$REPO_ROOT" commit -qm feature
}

teardown() {
  rm -rf "$REPO_ROOT"
}

write_valid_json() {
  cat > "$REPO_ROOT/specs/$FEATURE/traceability.json" <<'JSON'
{
  "source": {"url": "https://github.com/example/project/issues/1"},
  "criteria": [{
    "issue_ac": "ISSUE-AC-001",
    "text": "fixture criterion",
    "disposition": "implemented",
    "spec_acs": ["AC-001"],
    "tasks": ["TASK-001"],
    "tests": [{"file": "tests/fixture.bats", "name": "fixture passes"}]
  }]
}
JSON
  cat > "$REPO_ROOT/.sdd/state.json" <<JSON
{"feature":"$FEATURE","tier":2,"phase":"verify"}
JSON
  cat > "$REPO_ROOT/.sdd/tasks.json" <<JSON
[{"id":"$FEATURE","phase":"verify","status":"completed","assigned_agent":"codex","handoff":null,"blocked_reason":null}]
JSON
}

check_freeze() {
  run "$VALIDATOR" --feature "$FEATURE" --mode freeze
}

check_verify() {
  run "$VALIDATOR" --feature "$FEATURE" --mode verify --base "$BASE" --expected-tier 2
}

assert_rejected() {
  [ "$status" -eq 1 ]
  [[ "$output" == *"$1"* ]]
}

mutate_traceability() {
  local filter=$1
  jq "$filter" "$REPO_ROOT/specs/$FEATURE/traceability.json" > "$REPO_ROOT/traceability.tmp"
  mv "$REPO_ROOT/traceability.tmp" "$REPO_ROOT/specs/$FEATURE/traceability.json"
}

write_valid_follow_up() {
  write_valid_json
  mutate_traceability '.criteria[0] = {issue_ac:"ISSUE-AC-001",text:"later",disposition:"follow_up",reason:"tracked elsewhere",follow_up:"https://github.com/example/project/issues/2"}'
}

@test "accepts a valid freeze contract" {
  check_freeze
  [ "$status" -eq 0 ]
}

@test "rejects malformed or multi-value traceability JSON" {
  printf '%s\n' '{broken' > "$REPO_ROOT/specs/$FEATURE/traceability.json"
  check_freeze
  assert_rejected "traceability.json"

  write_valid_json
  cp "$REPO_ROOT/specs/$FEATURE/traceability.json" "$REPO_ROOT/one.json"
  cat "$REPO_ROOT/one.json" "$REPO_ROOT/one.json" > "$REPO_ROOT/specs/$FEATURE/traceability.json"
  check_freeze
  assert_rejected "single JSON value"
}

@test "rejects untracked and duplicate issue criteria" {
  mutate_traceability '.criteria = []'
  check_freeze
  assert_rejected "Issue criteria"

  write_valid_json
  mutate_traceability '.criteria += [.criteria[0]]'
  check_freeze
  assert_rejected "duplicate Issue criterion"
}

@test "rejects incomplete implemented mapping" {
  mutate_traceability '.criteria[0].spec_acs = []'
  check_freeze
  assert_rejected "implemented mapping"

  write_valid_json
  mutate_traceability 'del(.criteria[0].spec_acs)'
  check_freeze
  assert_rejected "implemented mapping"

  write_valid_json
  mutate_traceability '.criteria[0].tasks = []'
  check_freeze
  assert_rejected "implemented mapping"

  write_valid_json
  mutate_traceability 'del(.criteria[0].tasks)'
  check_freeze
  assert_rejected "implemented mapping"

  write_valid_json
  mutate_traceability '.criteria[0].tests = []'
  check_freeze
  assert_rejected "implemented mapping"

  write_valid_json
  mutate_traceability 'del(.criteria[0].tests)'
  check_freeze
  assert_rejected "implemented mapping"
}

@test "rejects invalid follow-up mapping" {
  write_valid_follow_up
  mutate_traceability '.criteria[0].reason = ""'
  check_freeze
  assert_rejected "follow_up mapping"

  write_valid_follow_up
  mutate_traceability 'del(.criteria[0].reason)'
  check_freeze
  assert_rejected "follow_up mapping"

  write_valid_follow_up
  mutate_traceability '.criteria[0].follow_up = "http://github.com/example/project/issues/2"'
  check_freeze
  assert_rejected "GitHub Issue URL"

  write_valid_follow_up
  mutate_traceability '.criteria[0].follow_up = "https://example.com/issues/2"'
  check_freeze
  assert_rejected "GitHub Issue URL"

  write_valid_follow_up
  mutate_traceability '.criteria[0].spec_acs = ["AC-001"] | .criteria[0].tasks = ["TASK-001"] | .criteria[0].tests = [{file:"tests/fixture.bats",name:"fixture passes"}]'
  check_freeze
  assert_rejected "follow_up mapping"
}

@test "rejects missing and orphaned spec or task references" {
  mutate_traceability '.criteria[0].spec_acs = ["AC-999"]'
  check_freeze
  assert_rejected "spec AC reference"

  write_valid_json
  mutate_traceability '.criteria[0].tasks = ["TASK-999"]'
  check_freeze
  assert_rejected "task reference"

  write_valid_json
  printf '%s\n' '### TASK-001: Duplicate' >> "$REPO_ROOT/specs/$FEATURE/tasks.md"
  check_freeze
  assert_rejected "duplicate task"

  sed -i.bak '$d' "$REPO_ROOT/specs/$FEATURE/tasks.md" && rm "$REPO_ROOT/specs/$FEATURE/tasks.md.bak"
  write_valid_json
  printf '%s\n' '- [x] AC-001: duplicate' >> "$REPO_ROOT/specs/$FEATURE/spec.md"
  check_freeze
  assert_rejected "duplicate spec AC"

  sed -i.bak '$d' "$REPO_ROOT/specs/$FEATURE/spec.md" && rm "$REPO_ROOT/specs/$FEATURE/spec.md.bak"
  write_valid_json
  printf '%s\n' '- [ ] AC-002: orphan' >> "$REPO_ROOT/specs/$FEATURE/spec.md"
  check_freeze
  assert_rejected "orphaned spec AC"

  sed -i.bak '$d' "$REPO_ROOT/specs/$FEATURE/spec.md" && rm "$REPO_ROOT/specs/$FEATURE/spec.md.bak"
  printf '%s\n' '### TASK-002: Orphan' >> "$REPO_ROOT/specs/$FEATURE/tasks.md"
  check_freeze
  assert_rejected "orphaned task"
}

@test "accepts a valid verify contract" {
  check_verify
  [ "$status" -eq 0 ]
}

@test "rejects state feature tier or phase mismatch" {
  jq '.feature = "other"' "$REPO_ROOT/.sdd/state.json" > "$REPO_ROOT/state.tmp" && mv "$REPO_ROOT/state.tmp" "$REPO_ROOT/.sdd/state.json"
  check_verify
  assert_rejected "state feature"

  write_valid_json
  jq '.tier = 1' "$REPO_ROOT/.sdd/state.json" > "$REPO_ROOT/state.tmp" && mv "$REPO_ROOT/state.tmp" "$REPO_ROOT/.sdd/state.json"
  check_verify
  assert_rejected "state tier"

  write_valid_json
  jq '.phase = "implement"' "$REPO_ROOT/.sdd/state.json" > "$REPO_ROOT/state.tmp" && mv "$REPO_ROOT/state.tmp" "$REPO_ROOT/.sdd/state.json"
  check_verify
  assert_rejected "state phase"
}

@test "rejects missing duplicate or noncanonical feature task" {
  printf '%s\n' '[]' > "$REPO_ROOT/.sdd/tasks.json"
  check_verify
  assert_rejected "feature task"

  write_valid_json
  jq '. += [.[0]]' "$REPO_ROOT/.sdd/tasks.json" > "$REPO_ROOT/tasks.tmp" && mv "$REPO_ROOT/tasks.tmp" "$REPO_ROOT/.sdd/tasks.json"
  check_verify
  assert_rejected "duplicate feature task"

  write_valid_json
  jq '.[0].unexpected = true' "$REPO_ROOT/.sdd/tasks.json" > "$REPO_ROOT/tasks.tmp" && mv "$REPO_ROOT/tasks.tmp" "$REPO_ROOT/.sdd/tasks.json"
  check_verify
  assert_rejected "canonical tasks.json"
}

@test "rejects blocked tasks and incomplete feature status" {
  jq '. += [{id:"unrelated",phase:"implement",status:"blocked",assigned_agent:null,handoff:null,blocked_reason:"fixture"}]' "$REPO_ROOT/.sdd/tasks.json" > "$REPO_ROOT/tasks.tmp" && mv "$REPO_ROOT/tasks.tmp" "$REPO_ROOT/.sdd/tasks.json"
  check_verify
  assert_rejected "blocked task"

  write_valid_json
  jq '.[0].status = "in_progress"' "$REPO_ROOT/.sdd/tasks.json" > "$REPO_ROOT/tasks.tmp" && mv "$REPO_ROOT/tasks.tmp" "$REPO_ROOT/.sdd/tasks.json"
  check_verify
  assert_rejected "feature status"
}

@test "rejects missing or duplicate Bats test declarations" {
  rm "$REPO_ROOT/tests/fixture.bats"
  check_verify
  assert_rejected "test file"

  printf '%s\n' '@test "fixture passes" {' '  true' '}' '@test "fixture passes" {' '  true' '}' > "$REPO_ROOT/tests/fixture.bats"
  check_verify
  assert_rejected "Bats declaration"
}

@test "rejects unavailable base and feature mismatch" {
  run "$VALIDATOR" --feature "$FEATURE" --mode verify --base missing-base --expected-tier 2
  assert_rejected "base"

  mkdir -p "$REPO_ROOT/specs/other"
  printf '%s\n' '# changed' > "$REPO_ROOT/specs/other/spec.md"
  git -C "$REPO_ROOT" add specs/other/spec.md
  git -C "$REPO_ROOT" commit -qm other-feature
  check_verify
  assert_rejected "changed feature"
}

@test "rejects expected tier mismatch" {
  run "$VALIDATOR" --feature "$FEATURE" --mode verify --base "$BASE" --expected-tier 1
  assert_rejected "expected tier"
}

@test "rejects the PR 54 inconsistent state fixture" {
  local fixture="$BATS_TEST_DIRNAME/fixtures/sdd-contract-minimal/pr54-invalid"
  FEATURE=development-rules
  mv "$REPO_ROOT/specs/fixture" "$REPO_ROOT/specs/$FEATURE"
  cp "$fixture/.sdd/state.json" "$REPO_ROOT/.sdd/state.json"
  cp "$fixture/.sdd/tasks.json" "$REPO_ROOT/.sdd/tasks.json"
  cp "$fixture/specs/development-rules/tasks.md" "$REPO_ROOT/specs/$FEATURE/tasks.md"
  check_verify
  assert_rejected "feature task"
}
