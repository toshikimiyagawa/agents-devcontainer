#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../scaffold/sdd-update.sh"

setup() {
  TMPDIR="$(mktemp -d)"
  mkdir -p "$TMPDIR/vendor/ai-sdd-guide/integration/agents"
  mkdir -p "$TMPDIR/vendor/ai-sdd-guide/integration/ci"

  # Seed integration sources
  echo "# sdd-reviewer v2" > "$TMPDIR/vendor/ai-sdd-guide/integration/agents/sdd-reviewer.md"
  echo "name: sdd-check-v2" > "$TMPDIR/vendor/ai-sdd-guide/integration/ci/sdd-check.yml"
  echo "# CLAUDE.md upstream" > "$TMPDIR/vendor/ai-sdd-guide/integration/CLAUDE.md.example"
  echo "# AGENTS.md upstream" > "$TMPDIR/vendor/ai-sdd-guide/integration/AGENTS.md.example"
  echo '{"upstream":true}' > "$TMPDIR/vendor/ai-sdd-guide/integration/settings.json.example"
}

teardown() {
  rm -rf "$TMPDIR"
}

# --- managed files (overwrite) ------------------------------------------------

@test "sdd-update: .claude/agents/ is updated from integration" {
  mkdir -p "$TMPDIR/.claude/agents"
  echo "# old" > "$TMPDIR/.claude/agents/sdd-reviewer.md"

  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  run cat "$TMPDIR/.claude/agents/sdd-reviewer.md"
  [ "$output" = "# sdd-reviewer v2" ]
}

@test "sdd-update: .claude/agents/ is created when absent" {
  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  [ -f "$TMPDIR/.claude/agents/sdd-reviewer.md" ]
}

@test "sdd-update: sdd-check.yml is updated" {
  mkdir -p "$TMPDIR/.github/workflows"
  echo "old-content" > "$TMPDIR/.github/workflows/sdd-check.yml"

  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  run cat "$TMPDIR/.github/workflows/sdd-check.yml"
  [ "$output" = "name: sdd-check-v2" ]
}

@test "sdd-update: .github/workflows/ is created when absent" {
  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  [ -f "$TMPDIR/.github/workflows/sdd-check.yml" ]
}

# --- protected files (no overwrite) -------------------------------------------

@test "sdd-update: CLAUDE.md is not overwritten when it exists" {
  echo "# my custom CLAUDE.md" > "$TMPDIR/CLAUDE.md"

  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  run cat "$TMPDIR/CLAUDE.md"
  [ "$output" = "# my custom CLAUDE.md" ]
}

@test "sdd-update: AGENTS.md is not overwritten when it exists" {
  echo "# my custom AGENTS.md" > "$TMPDIR/AGENTS.md"

  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  run cat "$TMPDIR/AGENTS.md"
  [ "$output" = "# my custom AGENTS.md" ]
}

@test "sdd-update: .claude/settings.json is not overwritten when it exists" {
  mkdir -p "$TMPDIR/.claude"
  echo '{"custom":true}' > "$TMPDIR/.claude/settings.json"

  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  run cat "$TMPDIR/.claude/settings.json"
  [ "$output" = '{"custom":true}' ]
}

@test "sdd-update: CLAUDE.md is created when absent" {
  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  [ -f "$TMPDIR/CLAUDE.md" ]
  run cat "$TMPDIR/CLAUDE.md"
  [ "$output" = "# CLAUDE.md upstream" ]
}

# --- error handling -----------------------------------------------------------

@test "sdd-update: fails when vendor/ai-sdd-guide/integration not found" {
  run bash "$SCRIPT" "$TMPDIR/nonexistent"
  [ "$status" -ne 0 ]
}
