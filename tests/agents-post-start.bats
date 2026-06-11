#!/usr/bin/env bats

POST_START="$BATS_TEST_DIRNAME/../.devcontainer/scripts/agents-post-start"

setup() {
  TMPDIR="$(mktemp -d)"
  export HOME="$TMPDIR/home"
  mkdir -p "$HOME"

  # Mock sudo: execute commands directly
  MOCK_BIN="$TMPDIR/mock-bin"
  mkdir -p "$MOCK_BIN"
  cat > "$MOCK_BIN/sudo" << 'MOCK'
#!/bin/bash
"$@"
MOCK
  chmod +x "$MOCK_BIN/sudo"

  # Mock git: no-op
  cat > "$MOCK_BIN/git" << 'MOCK'
#!/bin/bash
exit 0
MOCK
  chmod +x "$MOCK_BIN/git"

  # Mock gh: not authenticated (so identity block is skipped)
  cat > "$MOCK_BIN/gh" << 'MOCK'
#!/bin/bash
if [[ "$1 $2" == "auth status" ]]; then exit 1; fi
exit 0
MOCK
  chmod +x "$MOCK_BIN/gh"

  export PATH="$MOCK_BIN:$PATH"

  PROJECT="$TMPDIR/workspace/dotfiles"
  mkdir -p "$PROJECT"
  export PROJECT
}

teardown() {
  rm -rf "$TMPDIR"
}

# ---------------------------------------------------------------------------
# SSH sync tests
# ---------------------------------------------------------------------------

@test "copies .ssh keys to HOME when keys exist in project dotfiles" {
  mkdir -p "$PROJECT/.ssh"
  echo "ssh-ed25519 AAAA..." > "$PROJECT/.ssh/id_ed25519_home"
  echo "Host llm01" > "$PROJECT/.ssh/config"

  WORKSPACE="$(dirname "$PROJECT")" run bash "$POST_START"
  [ "$status" -eq 0 ]
  [ -f "$HOME/.ssh/id_ed25519_home" ]
  [ -f "$HOME/.ssh/config" ]
}

@test "sets 700 on ~/.ssh and 600 on key files" {
  mkdir -p "$PROJECT/.ssh"
  echo "ssh-ed25519 AAAA..." > "$PROJECT/.ssh/id_ed25519_home"

  WORKSPACE="$(dirname "$PROJECT")" run bash "$POST_START"
  [ "$status" -eq 0 ]
  perms_dir="$(stat -f '%A' "$HOME/.ssh")"
  perms_key="$(stat -f '%A' "$HOME/.ssh/id_ed25519_home")"
  [ "$perms_dir" = "700" ]
  [ "$perms_key" = "600" ]
}

@test "skips .ssh copy when project .ssh has no files" {
  mkdir -p "$PROJECT/.ssh"
  touch "$PROJECT/.ssh/.gitignore"   # hidden only — should be skipped

  WORKSPACE="$(dirname "$PROJECT")" run bash "$POST_START"
  [ "$status" -eq 0 ]
  [ ! -f "$HOME/.ssh/config" ]
}

@test "exits 0 when project dotfiles directory does not exist" {
  rm -rf "$PROJECT"

  WORKSPACE="$(dirname "$PROJECT")" run bash "$POST_START"
  [ "$status" -eq 0 ]
}
