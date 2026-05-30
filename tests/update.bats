#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../vendor/ai-sdd-guide/integration/update.sh"
INTEGRATION="$BATS_TEST_DIRNAME/../vendor/ai-sdd-guide/integration"

setup() {
  TMPDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR"
}

# --- managed files (overwrite) ------------------------------------------------

@test "update: .claude/agents/ is created when absent" {
  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  [ -f "$TMPDIR/.claude/agents/sdd-reviewer.md" ]
}

@test "update: .claude/agents/ is updated from integration (overwrites old content)" {
  mkdir -p "$TMPDIR/.claude/agents"
  echo "# old content" > "$TMPDIR/.claude/agents/sdd-reviewer.md"

  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  expected=$(cat "$INTEGRATION/agents/sdd-reviewer.md")
  run cat "$TMPDIR/.claude/agents/sdd-reviewer.md"
  [ "$output" = "$expected" ]
}

@test "update: sdd-check.yml is created when absent" {
  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  [ -f "$TMPDIR/.github/workflows/sdd-check.yml" ]
}

@test "update: sdd-check.yml is updated (overwrites old content)" {
  mkdir -p "$TMPDIR/.github/workflows"
  echo "old-content" > "$TMPDIR/.github/workflows/sdd-check.yml"

  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  expected=$(cat "$INTEGRATION/ci/sdd-check.yml")
  run cat "$TMPDIR/.github/workflows/sdd-check.yml"
  [ "$output" = "$expected" ]
}

# --- protected files (no overwrite) ------------------------------------------

@test "update: CLAUDE.md is created when absent" {
  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  [ -f "$TMPDIR/CLAUDE.md" ]
}

@test "update: CLAUDE.md is not overwritten when it exists" {
  echo "# my custom CLAUDE.md" > "$TMPDIR/CLAUDE.md"

  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  run cat "$TMPDIR/CLAUDE.md"
  [ "$output" = "# my custom CLAUDE.md" ]
}

@test "update: AGENTS.md is created when absent" {
  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  [ -f "$TMPDIR/AGENTS.md" ]
}

@test "update: AGENTS.md is not overwritten when it exists" {
  echo "# my custom AGENTS.md" > "$TMPDIR/AGENTS.md"

  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  run cat "$TMPDIR/AGENTS.md"
  [ "$output" = "# my custom AGENTS.md" ]
}

@test "update: .claude/settings.json is created when absent" {
  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  [ -f "$TMPDIR/.claude/settings.json" ]
}

@test "update: .claude/settings.json is not overwritten when it exists" {
  mkdir -p "$TMPDIR/.claude"
  echo '{"custom":true}' > "$TMPDIR/.claude/settings.json"

  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  run cat "$TMPDIR/.claude/settings.json"
  [ "$output" = '{"custom":true}' ]
}
