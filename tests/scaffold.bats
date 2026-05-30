#!/usr/bin/env bats

SCAFFOLD="$BATS_TEST_DIRNAME/../scaffold.sh"

setup() {
  TMPDIR="$(mktemp -d)"
  TARGET="$TMPDIR/myproject"
  mkdir -p "$TARGET"

  export GIT_CONFIG_COUNT=1
  export GIT_CONFIG_KEY_0=protocol.file.allow
  export GIT_CONFIG_VALUE_0=always

  # --- agents-devcontainer fixture ---
  ADC_BARE="$TMPDIR/agents-devcontainer.git"
  git init --bare "$ADC_BARE" >/dev/null 2>&1

  ADC_WORK="$TMPDIR/adc-work"
  git clone "$ADC_BARE" "$ADC_WORK" >/dev/null 2>&1
  mkdir -p "$ADC_WORK/scaffold"
  cp "$BATS_TEST_DIRNAME/../scaffold/devcontainer.base.json" "$ADC_WORK/scaffold/"
  cp "$BATS_TEST_DIRNAME/../scaffold/merge.sh"               "$ADC_WORK/scaffold/"
  (cd "$ADC_WORK" && git add -A && git -c user.name=test -c user.email=test@test.com commit -m "init" >/dev/null 2>&1)
  (cd "$ADC_WORK" && git push >/dev/null 2>&1)
}

teardown() {
  rm -rf "$TMPDIR"
}

init_git_target() {
  (cd "$TARGET" && git init >/dev/null 2>&1 && git -c user.name=test -c user.email=test@test.com commit --allow-empty -m "init" >/dev/null 2>&1)
}

# --- devcontainer file generation ----------------------------------------------

@test "generates devcontainer.json" {
  init_git_target
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  [ -f "$TARGET/.devcontainer/devcontainer.json" ]
}

@test "generates devcontainer.project.json" {
  init_git_target
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  [ -f "$TARGET/.devcontainer/devcontainer.project.json" ]
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

@test "creates dotfiles/.codex directory" {
  bash "$SCAFFOLD" "$TARGET"
  [ -d "$TARGET/.devcontainer/dotfiles/.codex" ]
}

# --- devcontainer.json content -------------------------------------------------

@test "devcontainer.json is valid JSON" {
  init_git_target
  env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  run jq empty "$TARGET/.devcontainer/devcontainer.json"
  [ "$status" -eq 0 ]
}

@test "image tag defaults to latest" {
  init_git_target
  env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  run jq -r '.image' "$TARGET/.devcontainer/devcontainer.json"
  [ "$output" = "ghcr.io/toshikimiyagawa/agents-devcontainer:latest" ]
}

@test "AGENTS_DEVCONTAINER_TAG overrides image tag" {
  init_git_target
  env AGENTS_DEVCONTAINER_TAG=v1.2.3 AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  run jq -r '.image' "$TARGET/.devcontainer/devcontainer.json"
  [ "$output" = "ghcr.io/toshikimiyagawa/agents-devcontainer:v1.2.3" ]
}

@test "name is set to project directory name" {
  init_git_target
  env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  run jq -r '.name' "$TARGET/.devcontainer/devcontainer.json"
  [ "$output" = "myproject" ]
}

@test "MISE_TRUSTED_CONFIG_PATHS is not present" {
  init_git_target
  env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  run grep "MISE_TRUSTED_CONFIG_PATHS" "$TARGET/.devcontainer/devcontainer.json"
  [ "$status" -ne 0 ]
}

@test "postCreateCommand is agents-post-create" {
  init_git_target
  env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  run jq -r '.postCreateCommand' "$TARGET/.devcontainer/devcontainer.json"
  [ "$output" = "agents-post-create" ]
}

@test "postStartCommand is agents-post-start" {
  init_git_target
  env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
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

@test ".gitignore includes dotfiles/.codex/" {
  bash "$SCAFFOLD" "$TARGET"
  grep -q "dotfiles/.codex/" "$TARGET/.devcontainer/.gitignore"
}

@test ".gitignore includes dotfiles/.zsh_history" {
  bash "$SCAFFOLD" "$TARGET"
  grep -q "dotfiles/.zsh_history" "$TARGET/.devcontainer/.gitignore"
}

# --- devcontainer skip when already exists -------------------------------------

@test "skips devcontainer setup when .devcontainer already exists" {
  mkdir -p "$TARGET/.devcontainer"
  init_git_target
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  [ ! -f "$TARGET/.devcontainer/devcontainer.json" ]
}

# --- agents-devcontainer submodule --------------------------------------------

@test "adds agents-devcontainer submodule in git repo" {
  init_git_target
  AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  [ -d "$TARGET/vendor/agents-devcontainer" ]
  [ -f "$TARGET/vendor/agents-devcontainer/scaffold/merge.sh" ]
}

@test "skips agents-devcontainer submodule when already exists" {
  init_git_target
  mkdir -p "$TARGET/vendor/agents-devcontainer"
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  [ -d "$TARGET/vendor/agents-devcontainer" ]
}

@test "does not add agents-devcontainer submodule when not a git repo" {
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  [ ! -d "$TARGET/vendor/agents-devcontainer" ]
}

# --- project-tools.yml --------------------------------------------------------

@test "generates project-tools.yml" {
  bash "$SCAFFOLD" "$TARGET"
  [ -f "$TARGET/.devcontainer/project-tools.yml" ]
}

@test "project-tools.yml has comment header" {
  bash "$SCAFFOLD" "$TARGET"
  head -1 "$TARGET/.devcontainer/project-tools.yml" | grep -q "^#"
}

@test "skips project-tools.yml when .devcontainer already exists" {
  mkdir -p "$TARGET/.devcontainer"
  init_git_target
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  [ ! -f "$TARGET/.devcontainer/project-tools.yml" ]
}
