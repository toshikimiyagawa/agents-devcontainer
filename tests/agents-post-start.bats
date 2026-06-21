#!/usr/bin/env bats

POST_START="$BATS_TEST_DIRNAME/../.devcontainer/scripts/agents-post-start"

# Octal permission bits, portable across GNU coreutils (Linux CI) and BSD stat (macOS).
file_perms() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%A' "$1"
}

assert_output_contains() {
  case "$output" in
    *"$1"*) ;;
    *) printf 'expected output to contain: %s\nactual output: %s\n' "$1" "$output" >&2; return 1 ;;
  esac
}

assert_output_not_contains() {
  case "$output" in
    *"$1"*) printf 'expected output not to contain: %s\nactual output: %s\n' "$1" "$output" >&2; return 1 ;;
    *) ;;
  esac
}

setup() {
  TMPDIR="$(mktemp -d)"
  export HOME="$TMPDIR/home"
  mkdir -p "$HOME"

  export MOCK_STATE="$TMPDIR/mock-state"
  mkdir -p "$MOCK_STATE"

  # Mock sudo: execute commands directly
  MOCK_BIN="$TMPDIR/mock-bin"
  mkdir -p "$MOCK_BIN"
  cat > "$MOCK_BIN/sudo" << 'MOCK'
#!/bin/bash
"$@"
MOCK
  chmod +x "$MOCK_BIN/sudo"

  # Mock git: persist the system identity and record writes.
  cat > "$MOCK_BIN/git" << 'MOCK'
#!/bin/bash
if [[ "$1 $2 $3" == "config --system --get-all" && "$4" == "safe.directory" ]]; then
  printf '/workspace\n'
  exit 0
fi
if [[ "$1 $2 $3" == "config --system --get" ]]; then
  case "$4" in
    user.name)  [[ -f "$MOCK_STATE/user.name" ]]  && cat "$MOCK_STATE/user.name"  || exit 1 ;;
    user.email) [[ -f "$MOCK_STATE/user.email" ]] && cat "$MOCK_STATE/user.email" || exit 1 ;;
  esac
  exit 0
fi
if [[ "$1 $2" == "config --system" && "$3" == "user.name" ]]; then
  printf '%s' "$4" > "$MOCK_STATE/user.name"
  printf 'user.name=%s\n' "$4" >> "$MOCK_STATE/writes"
  exit 0
fi
if [[ "$1 $2" == "config --system" && "$3" == "user.email" ]]; then
  printf '%s' "$4" > "$MOCK_STATE/user.email"
  printf 'user.email=%s\n' "$4" >> "$MOCK_STATE/writes"
  exit 0
fi
exit 0
MOCK
  chmod +x "$MOCK_BIN/git"

  # Mock gh: configurable identity provider, unauthenticated by default.
  cat > "$MOCK_BIN/gh" << 'MOCK'
#!/bin/bash
if [[ "$1 $2" == "auth status" ]]; then
  [[ "${GH_AUTHENTICATED:-0}" == 1 ]]
  exit
fi
if [[ "$1 $2 $3 $4" == "api user --jq .name" ]]; then
  printf '%s\n' "${GH_NAME:-}"
  exit 0
fi
if [[ "$1 $2 $3 $4" == "api user --jq .email" ]]; then
  printf '%s\n' "${GH_EMAIL:-}"
  exit 0
fi
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
  perms_dir="$(file_perms "$HOME/.ssh")"
  perms_key="$(file_perms "$HOME/.ssh/id_ed25519_home")"
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

@test "syncs Hermes skills from HOME back to project dotfiles" {
  mkdir -p "$HOME/.hermes/skills/custom-skill"
  echo "custom skill" > "$HOME/.hermes/skills/custom-skill/SKILL.md"

  WORKSPACE="$(dirname "$PROJECT")" run bash "$POST_START"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT/.hermes/skills/custom-skill/SKILL.md" ]
  run cat "$PROJECT/.hermes/skills/custom-skill/SKILL.md"
  [ "$output" = "custom skill" ]
}

# ---------------------------------------------------------------------------
# Git identity tests
# ---------------------------------------------------------------------------

@test "missing identity warns without failing or writing empty values" {
  WORKSPACE="$(dirname "$PROJECT")" run env \
    -u GIT_AUTHOR_NAME -u GIT_AUTHOR_EMAIL \
    -u GIT_COMMITTER_NAME -u GIT_COMMITTER_EMAIL \
    bash "$POST_START"

  [ "$status" -eq 0 ]
  assert_output_contains "WARNING"
  assert_output_contains "user.name"
  assert_output_contains "user.email"
  assert_output_contains "git config"
  [ ! -e "$MOCK_STATE/user.name" ]
  [ ! -e "$MOCK_STATE/user.email" ]
}

@test "authenticated gh identity populates system git config" {
  GH_AUTHENTICATED=1 GH_NAME="Test User" GH_EMAIL="test@example.com" \
    WORKSPACE="$(dirname "$PROJECT")" run env \
    -u GIT_AUTHOR_NAME -u GIT_AUTHOR_EMAIL \
    bash "$POST_START"

  [ "$status" -eq 0 ]
  [ "$(cat "$MOCK_STATE/user.name")" = "Test User" ]
  [ "$(cat "$MOCK_STATE/user.email")" = "test@example.com" ]
  assert_output_not_contains "WARNING"
}

@test "explicit identity is preserved while gh fills the missing value" {
  GH_AUTHENTICATED=1 GH_NAME="GitHub Name" GH_EMAIL="github@example.com" \
    GIT_AUTHOR_NAME="Explicit Name" WORKSPACE="$(dirname "$PROJECT")" \
    run env -u GIT_AUTHOR_EMAIL bash "$POST_START"

  [ "$status" -eq 0 ]
  [ "$(cat "$MOCK_STATE/user.name")" = "Explicit Name" ]
  [ "$(cat "$MOCK_STATE/user.email")" = "github@example.com" ]
}

@test "existing system identity prevents a warning when providers are unavailable" {
  printf 'Existing Name' > "$MOCK_STATE/user.name"
  printf 'existing@example.com' > "$MOCK_STATE/user.email"

  WORKSPACE="$(dirname "$PROJECT")" run env \
    -u GIT_AUTHOR_NAME -u GIT_AUTHOR_EMAIL \
    bash "$POST_START"

  [ "$status" -eq 0 ]
  assert_output_not_contains "WARNING"
}

@test "partial gh identity writes only the non-empty value and warns for email" {
  GH_AUTHENTICATED=1 GH_NAME="Test User" GH_EMAIL="" \
    WORKSPACE="$(dirname "$PROJECT")" run env \
    -u GIT_AUTHOR_NAME -u GIT_AUTHOR_EMAIL \
    bash "$POST_START"

  [ "$status" -eq 0 ]
  [ "$(cat "$MOCK_STATE/user.name")" = "Test User" ]
  [ ! -e "$MOCK_STATE/user.email" ]
  assert_output_contains "WARNING"
  assert_output_contains "user.email"
}

@test "empty existing system identity is treated as missing" {
  : > "$MOCK_STATE/user.name"
  : > "$MOCK_STATE/user.email"

  WORKSPACE="$(dirname "$PROJECT")" run env \
    -u GIT_AUTHOR_NAME -u GIT_AUTHOR_EMAIL \
    bash "$POST_START"

  [ "$status" -eq 0 ]
  assert_output_contains "WARNING"
  assert_output_contains "user.name"
  assert_output_contains "user.email"
}

@test "null gh identity is not written as a git identity" {
  GH_AUTHENTICATED=1 GH_NAME="Test User" GH_EMAIL="null" \
    WORKSPACE="$(dirname "$PROJECT")" run env \
    -u GIT_AUTHOR_NAME -u GIT_AUTHOR_EMAIL \
    bash "$POST_START"

  [ "$status" -eq 0 ]
  [ "$(cat "$MOCK_STATE/user.name")" = "Test User" ]
  [ ! -e "$MOCK_STATE/user.email" ]
  assert_output_contains "WARNING"
  assert_output_contains "user.email"
}
