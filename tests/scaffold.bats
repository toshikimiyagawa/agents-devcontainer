#!/usr/bin/env bats

SCAFFOLD="$BATS_TEST_DIRNAME/../scaffold.sh"

setup() {
  TMPDIR="$(mktemp -d)"
  TARGET="$TMPDIR/myproject"
  mkdir -p "$TARGET"
}

teardown() {
  rm -rf "$TMPDIR"
}

# --- file generation -----------------------------------------------------------

@test "generates devcontainer.json" {
  run bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  [ -f "$TARGET/.devcontainer/devcontainer.json" ]
}

@test "generates .gitignore" {
  bash "$SCAFFOLD" "$TARGET"
  [ -f "$TARGET/.devcontainer/.gitignore" ]
}

@test "creates dotfiles/.claude directory" {
  bash "$SCAFFOLD" "$TARGET"
  [ -d "$TARGET/.devcontainer/dotfiles/.claude" ]
}

@test "creates dotfiles/.gemini directory" {
  bash "$SCAFFOLD" "$TARGET"
  [ -d "$TARGET/.devcontainer/dotfiles/.gemini" ]
}

# --- devcontainer.json content -------------------------------------------------

@test "devcontainer.json is valid JSON" {
  bash "$SCAFFOLD" "$TARGET"
  run jq empty "$TARGET/.devcontainer/devcontainer.json"
  [ "$status" -eq 0 ]
}

@test "image tag defaults to latest" {
  bash "$SCAFFOLD" "$TARGET"
  run jq -r '.image' "$TARGET/.devcontainer/devcontainer.json"
  [ "$output" = "ghcr.io/toshikimiyagawa/agents-devcontainer:latest" ]
}

@test "AGENTS_DEVCONTAINER_TAG overrides image tag" {
  AGENTS_DEVCONTAINER_TAG=v1.2.3 bash "$SCAFFOLD" "$TARGET"
  run jq -r '.image' "$TARGET/.devcontainer/devcontainer.json"
  [ "$output" = "ghcr.io/toshikimiyagawa/agents-devcontainer:v1.2.3" ]
}

@test "name is set to project directory name" {
  bash "$SCAFFOLD" "$TARGET"
  run jq -r '.name' "$TARGET/.devcontainer/devcontainer.json"
  [ "$output" = "myproject" ]
}

@test "MISE_TRUSTED_CONFIG_PATHS is not present" {
  bash "$SCAFFOLD" "$TARGET"
  run grep "MISE_TRUSTED_CONFIG_PATHS" "$TARGET/.devcontainer/devcontainer.json"
  [ "$status" -ne 0 ]
}

@test "postCreateCommand is agents-post-create" {
  bash "$SCAFFOLD" "$TARGET"
  run jq -r '.postCreateCommand' "$TARGET/.devcontainer/devcontainer.json"
  [ "$output" = "agents-post-create" ]
}

@test "postStartCommand is agents-post-start" {
  bash "$SCAFFOLD" "$TARGET"
  run jq -r '.postStartCommand' "$TARGET/.devcontainer/devcontainer.json"
  [ "$output" = "agents-post-start" ]
}

# --- .gitignore content --------------------------------------------------------

@test ".gitignore includes dotfiles/.claude/" {
  bash "$SCAFFOLD" "$TARGET"
  grep -q "dotfiles/.claude/" "$TARGET/.devcontainer/.gitignore"
}

@test ".gitignore includes dotfiles/.gemini/" {
  bash "$SCAFFOLD" "$TARGET"
  grep -q "dotfiles/.gemini/" "$TARGET/.devcontainer/.gitignore"
}

@test ".gitignore includes dotfiles/.zsh_history" {
  bash "$SCAFFOLD" "$TARGET"
  grep -q "dotfiles/.zsh_history" "$TARGET/.devcontainer/.gitignore"
}

# --- error cases ---------------------------------------------------------------

@test "exits with error if .devcontainer already exists" {
  mkdir -p "$TARGET/.devcontainer"
  run bash "$SCAFFOLD" "$TARGET"
  [ "$status" -ne 0 ]
}
