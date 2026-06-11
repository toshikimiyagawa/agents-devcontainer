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
  # Add dotfiles for scaffold to copy
  mkdir -p "$ADC_WORK/dotfiles/.config"
  echo '# zshrc' > "$ADC_WORK/dotfiles/.zshrc"
  echo '# tmux' > "$ADC_WORK/dotfiles/.tmux.conf"
  touch "$ADC_WORK/dotfiles/.config/.keep"
  # Ship the sync script so the submodule checkout has it (used to seed the manifest)
  mkdir -p "$ADC_WORK/.devcontainer/scripts"
  cp "$BATS_TEST_DIRNAME/../.devcontainer/scripts/agents-dotfiles-sync" "$ADC_WORK/.devcontainer/scripts/"
  chmod +x "$ADC_WORK/.devcontainer/scripts/agents-dotfiles-sync"
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
  [ -d "$TARGET/dotfiles/.claude" ]
}

@test "creates dotfiles/.gemini directory" {
  bash "$SCAFFOLD" "$TARGET"
  [ -d "$TARGET/dotfiles/.gemini" ]
}

@test "creates dotfiles/.codex directory" {
  bash "$SCAFFOLD" "$TARGET"
  [ -d "$TARGET/dotfiles/.codex" ]
}

@test "creates dotfiles/.gitignore" {
  bash "$SCAFFOLD" "$TARGET"
  [ -f "$TARGET/dotfiles/.gitignore" ]
}

@test "dotfiles/.gitignore ignores all by default" {
  bash "$SCAFFOLD" "$TARGET"
  grep -q '^\*$' "$TARGET/dotfiles/.gitignore"
}

@test "dotfiles/.zshrc is committed when vendor has dotfiles" {
  init_git_target
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  git -C "$TARGET" ls-files dotfiles/.zshrc | grep -q "dotfiles/.zshrc"
}

@test "dotfiles/.tmux.conf is committed when vendor has dotfiles" {
  init_git_target
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  git -C "$TARGET" ls-files dotfiles/.tmux.conf | grep -q "dotfiles/.tmux.conf"
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

@test "remoteEnv.CLAUDE_CONFIG_DIR persists Claude config under ~/.claude" {
  init_git_target
  env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  run jq -r '.remoteEnv.CLAUDE_CONFIG_DIR' "$TARGET/.devcontainer/devcontainer.json"
  [ "$output" = "/home/ubuntu/.claude" ]
}

# --- .gitignore content --------------------------------------------------------

@test ".devcontainer/.gitignore does not include dotfiles entries" {
  bash "$SCAFFOLD" "$TARGET"
  ! grep -q "dotfiles/" "$TARGET/.devcontainer/.gitignore"
}

@test "devcontainer.json initializeCommand uses dotfiles/ path" {
  init_git_target
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  grep -q 'dotfiles/.claude' "$TARGET/.devcontainer/devcontainer.json"
  ! grep -q '.devcontainer/dotfiles' "$TARGET/.devcontainer/devcontainer.json"
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

# --- dotfiles provenance manifest ---------------------------------------------

@test "seeds and commits dotfiles/.agents-dotfiles.lock" {
  init_git_target
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  [ -f "$TARGET/dotfiles/.agents-dotfiles.lock" ]
  git -C "$TARGET" ls-files dotfiles/.agents-dotfiles.lock | grep -q ".agents-dotfiles.lock"
  grep -q '^.zshrc ' "$TARGET/dotfiles/.agents-dotfiles.lock"
  grep -q '^.tmux.conf ' "$TARGET/dotfiles/.agents-dotfiles.lock"
}
