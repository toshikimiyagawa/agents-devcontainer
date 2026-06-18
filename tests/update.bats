#!/usr/bin/env bats

setup() {
  TMPDIR="$(mktemp -d)"
  INTEGRATION="$TMPDIR/integration"
  SCRIPT="$INTEGRATION/update.sh"

  mkdir -p "$INTEGRATION/agents" "$INTEGRATION/ci" "$INTEGRATION/codex"
  cat > "$INTEGRATION/update.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

INTEGRATION="$(cd "$(dirname "$0")" && pwd)"
PROJECT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

log() { printf '[update.sh] %s\n' "$*"; }

if [[ -d "$INTEGRATION/agents" ]]; then
  mkdir -p "$PROJECT/.claude"
  rm -rf "$PROJECT/.claude/agents"
  cp -r "$INTEGRATION/agents" "$PROJECT/.claude/agents"
  log "updated .claude/agents/"
fi

if [[ -f "$INTEGRATION/ci/sdd-check.yml" ]]; then
  mkdir -p "$PROJECT/.github/workflows"
  cp "$INTEGRATION/ci/sdd-check.yml" "$PROJECT/.github/workflows/sdd-check.yml"
  log "updated .github/workflows/sdd-check.yml"
fi

protected=(
  "AGENTS.md:$INTEGRATION/AGENTS.md.example"
  ".claude/settings.json:$INTEGRATION/settings.json.example"
  ".codex/config.toml:$INTEGRATION/codex/config.toml.example"
)

for entry in "${protected[@]}"; do
  rel="${entry%%:*}"
  src="${entry#*:}"
  dest="$PROJECT/$rel"

  if [[ ! -f "$src" ]]; then continue; fi

  if [[ ! -f "$dest" ]]; then
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    log "created $rel (was absent)"
  elif ! diff -q "$src" "$dest" >/dev/null 2>&1; then
    log "diff (protected — review manually): $rel"
    diff "$dest" "$src" || true
  fi
done

CLAUDE="$PROJECT/CLAUDE.md"
if [[ -L "$CLAUDE" ]]; then
  :
elif [[ ! -e "$CLAUDE" ]]; then
  ln -s AGENTS.md "$CLAUDE"
  log "created CLAUDE.md → AGENTS.md symlink"
else
  log "WARNING: CLAUDE.md exists but is not a symlink — run: rm CLAUDE.md && ln -s AGENTS.md CLAUDE.md"
fi

log "done"
SH
  chmod +x "$SCRIPT"

  echo "# reviewer" > "$INTEGRATION/agents/sdd-reviewer.md"
  echo "name: sdd-check" > "$INTEGRATION/ci/sdd-check.yml"
  echo "# agents" > "$INTEGRATION/AGENTS.md.example"
  echo '{"hooks":{}}' > "$INTEGRATION/settings.json.example"
  echo 'sandbox_mode = "workspace-write"' > "$INTEGRATION/codex/config.toml.example"
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
