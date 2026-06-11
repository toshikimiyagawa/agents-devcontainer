#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../.devcontainer/scripts/agents-dotfiles-sync"

setup() {
  TMPDIR="$(mktemp -d)"
  export UPSTREAM_DIR="$TMPDIR/upstream"
  export PROJECT_DIR="$TMPDIR/project"
  mkdir -p "$UPSTREAM_DIR/.config" "$PROJECT_DIR"
  MANIFEST="$PROJECT_DIR/.agents-dotfiles.lock"
}

teardown() {
  rm -rf "$TMPDIR"
}

# seed a project that exactly mirrors upstream (records baselines, no changes)
seed() {
  run env UPSTREAM_DIR="$UPSTREAM_DIR" PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# --- AC7: no upstream ---------------------------------------------------------
@test "exits 0 and changes nothing when UPSTREAM_DIR is missing" {
  rm -rf "$UPSTREAM_DIR"
  run env UPSTREAM_DIR="$UPSTREAM_DIR" PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skip (no upstream"* ]]
  [ ! -f "$MANIFEST" ]
}

# --- AC5: new upstream file adopted ------------------------------------------
@test "copies a new upstream file and records it in the manifest" {
  echo 'v1' > "$UPSTREAM_DIR/.zshrc"
  run env UPSTREAM_DIR="$UPSTREAM_DIR" PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.zshrc" ]
  run cat "$PROJECT_DIR/.zshrc"
  [ "$output" = "v1" ]
  grep -q '^.zshrc ' "$MANIFEST"
}

# --- seeding: project already mirrors upstream -------------------------------
@test "records baseline without changing a file that already matches upstream" {
  echo 'v1' > "$UPSTREAM_DIR/.zshrc"
  echo 'v1' > "$PROJECT_DIR/.zshrc"
  seed
  grep -q '^.zshrc ' "$MANIFEST"
  run cat "$PROJECT_DIR/.zshrc"
  [ "$output" = "v1" ]
}

# --- AC2: untouched + upstream advanced -> auto-update -----------------------
@test "fast-forwards an untouched file when upstream advances" {
  echo 'v1' > "$UPSTREAM_DIR/.zshrc"
  echo 'v1' > "$PROJECT_DIR/.zshrc"
  seed
  echo 'v2' > "$UPSTREAM_DIR/.zshrc"
  run env UPSTREAM_DIR="$UPSTREAM_DIR" PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  run cat "$PROJECT_DIR/.zshrc"
  [ "$output" = "v2" ]
  # manifest now records the new upstream hash
  newhash="$(sha256sum "$UPSTREAM_DIR/.zshrc" 2>/dev/null | awk '{print $1}' || shasum -a 256 "$UPSTREAM_DIR/.zshrc" | awk '{print $1}')"
  grep -q "^.zshrc $newhash$" "$MANIFEST"
}

# --- AC4: overridden + upstream unchanged -> no change -----------------------
@test "leaves an overridden file alone when upstream is unchanged" {
  echo 'v1' > "$UPSTREAM_DIR/.zshrc"
  echo 'v1' > "$PROJECT_DIR/.zshrc"
  seed
  echo 'mine' > "$PROJECT_DIR/.zshrc"
  run env UPSTREAM_DIR="$UPSTREAM_DIR" PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  run cat "$PROJECT_DIR/.zshrc"
  [ "$output" = "mine" ]
}

# --- AC3: overridden + upstream changed -> conflict (non-destructive) --------
@test "reports a conflict and writes a sidecar when both sides changed" {
  echo 'v1' > "$UPSTREAM_DIR/.zshrc"
  echo 'v1' > "$PROJECT_DIR/.zshrc"
  seed
  echo 'mine' > "$PROJECT_DIR/.zshrc"
  echo 'v2'   > "$UPSTREAM_DIR/.zshrc"
  run env UPSTREAM_DIR="$UPSTREAM_DIR" PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  run cat "$PROJECT_DIR/.zshrc"
  [ "$output" = "mine" ]                       # untouched
  [ -f "$PROJECT_DIR/.zshrc.agents-upstream" ]
  run cat "$PROJECT_DIR/.zshrc.agents-upstream"
  [ "$output" = "v2" ]
  run env UPSTREAM_DIR="$UPSTREAM_DIR" PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPT"
  [[ "$output" == *"need manual review"* ]]
}

# --- AC6: --accept advances baseline, keeps override -------------------------
@test "--accept stops the conflict warning and keeps the local override" {
  echo 'v1' > "$UPSTREAM_DIR/.zshrc"
  echo 'v1' > "$PROJECT_DIR/.zshrc"
  seed
  echo 'mine' > "$PROJECT_DIR/.zshrc"
  echo 'v2'   > "$UPSTREAM_DIR/.zshrc"
  run env UPSTREAM_DIR="$UPSTREAM_DIR" PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPT"   # creates conflict
  run env UPSTREAM_DIR="$UPSTREAM_DIR" PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPT" --accept .zshrc
  [ "$status" -eq 0 ]
  run cat "$PROJECT_DIR/.zshrc"
  [ "$output" = "mine" ]                        # override preserved
  [ ! -f "$PROJECT_DIR/.zshrc.agents-upstream" ] # sidecar cleared
  run env UPSTREAM_DIR="$UPSTREAM_DIR" PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPT"
  [[ "$output" != *"need manual review"* ]]      # no more warning
}

# --- AC8: runtime/personal entries excluded ----------------------------------
@test "excludes .claude .gemini .codex .ssh .zsh_history .gitignore" {
  mkdir -p "$UPSTREAM_DIR/.claude" "$UPSTREAM_DIR/.gemini" "$UPSTREAM_DIR/.codex" "$UPSTREAM_DIR/.ssh"
  echo x > "$UPSTREAM_DIR/.claude/state"
  echo x > "$UPSTREAM_DIR/.gemini/state"
  echo x > "$UPSTREAM_DIR/.codex/state"
  echo x > "$UPSTREAM_DIR/.ssh/id"
  echo x > "$UPSTREAM_DIR/.zsh_history"
  printf '*\n!.gitignore\n' > "$UPSTREAM_DIR/.gitignore"
  echo 'v1' > "$UPSTREAM_DIR/.zshrc"
  run env UPSTREAM_DIR="$UPSTREAM_DIR" PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.zshrc" ]
  [ ! -e "$PROJECT_DIR/.claude/state" ]
  [ ! -e "$PROJECT_DIR/.gemini/state" ]
  [ ! -e "$PROJECT_DIR/.codex/state" ]
  [ ! -e "$PROJECT_DIR/.ssh/id" ]
  [ ! -e "$PROJECT_DIR/.zsh_history" ]
  [ ! -e "$PROJECT_DIR/.gitignore" ]
  ! grep -q '.claude' "$MANIFEST"
  ! grep -q '.gitignore' "$MANIFEST"
}

# --- nested .config file handled per-file ------------------------------------
@test "tracks nested .config files per-file" {
  echo 'a' > "$UPSTREAM_DIR/.config/starship.toml"
  run env UPSTREAM_DIR="$UPSTREAM_DIR" PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.config/starship.toml" ]
  grep -q '^.config/starship.toml ' "$MANIFEST"
}
