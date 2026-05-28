#!/usr/bin/env bats

SCAFFOLD="$BATS_TEST_DIRNAME/../scaffold.sh"

setup() {
  TMPDIR="$(mktemp -d)"
  TARGET="$TMPDIR/myproject"
  mkdir -p "$TARGET"

  # Create a local bare repo to act as ai-sdd-guide for submodule tests
  SDD_BARE="$TMPDIR/ai-sdd-guide.git"
  git init --bare "$SDD_BARE" >/dev/null 2>&1

  # Populate the bare repo with integration files
  SDD_WORK="$TMPDIR/sdd-work"
  git -c protocol.file.allow=always clone "$SDD_BARE" "$SDD_WORK" >/dev/null 2>&1
  mkdir -p "$SDD_WORK/integration/agents" "$SDD_WORK/integration/ci"
  echo "# CLAUDE.md example" > "$SDD_WORK/integration/CLAUDE.md.example"
  echo "# AGENTS.md example" > "$SDD_WORK/integration/AGENTS.md.example"
  echo '{"hooks":{}}' > "$SDD_WORK/integration/settings.json.example"
  echo "# sdd-reviewer" > "$SDD_WORK/integration/agents/sdd-reviewer.md"
  echo "name: sdd-check" > "$SDD_WORK/integration/ci/sdd-check.yml"
  (cd "$SDD_WORK" && git add -A && git commit -m "init" >/dev/null 2>&1)
  (cd "$SDD_WORK" && git push >/dev/null 2>&1)

  # Allow local file:// protocol for submodule tests
  export GIT_CONFIG_GLOBAL="$TMPDIR/gitconfig"
  git config --file "$GIT_CONFIG_GLOBAL" protocol.file.allow always
}

teardown() {
  rm -rf "$TMPDIR"
}

# Helper: init target as git repo so submodule works
init_git_target() {
  (cd "$TARGET" && git init >/dev/null 2>&1 && git commit --allow-empty -m "init" >/dev/null 2>&1)
}

# --- devcontainer file generation ----------------------------------------------

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

# --- devcontainer skip when already exists -------------------------------------

@test "skips devcontainer setup when .devcontainer already exists" {
  mkdir -p "$TARGET/.devcontainer"
  init_git_target
  run env AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  # devcontainer.json should NOT be created
  [ ! -f "$TARGET/.devcontainer/devcontainer.json" ]
}

# --- SDD integration ----------------------------------------------------------

@test "adds ai-sdd-guide submodule" {
  init_git_target
  AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ -d "$TARGET/vendor/ai-sdd-guide" ]
  [ -f "$TARGET/vendor/ai-sdd-guide/integration/CLAUDE.md.example" ]
}

@test "copies CLAUDE.md from integration" {
  init_git_target
  AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ -f "$TARGET/CLAUDE.md" ]
}

@test "copies AGENTS.md from integration" {
  init_git_target
  AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ -f "$TARGET/AGENTS.md" ]
}

@test "copies .claude/settings.json from integration" {
  init_git_target
  AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ -f "$TARGET/.claude/settings.json" ]
}

@test "copies .claude/agents/ from integration" {
  init_git_target
  AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ -d "$TARGET/.claude/agents" ]
  [ -f "$TARGET/.claude/agents/sdd-reviewer.md" ]
}

@test "copies .github/workflows/sdd-check.yml from integration" {
  init_git_target
  AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ -f "$TARGET/.github/workflows/sdd-check.yml" ]
}

# --- SDD opt-out ---------------------------------------------------------------

@test "AGENTS_DEVCONTAINER_SDD=0 skips SDD setup" {
  init_git_target
  AGENTS_DEVCONTAINER_SDD=0 AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ ! -d "$TARGET/vendor/ai-sdd-guide" ]
  [ ! -f "$TARGET/CLAUDE.md" ]
}

# --- SDD skip existing files ---------------------------------------------------

@test "does not overwrite existing CLAUDE.md" {
  init_git_target
  echo "custom" > "$TARGET/CLAUDE.md"
  AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  run cat "$TARGET/CLAUDE.md"
  [ "$output" = "custom" ]
}

@test "does not overwrite existing AGENTS.md" {
  init_git_target
  echo "custom" > "$TARGET/AGENTS.md"
  AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  run cat "$TARGET/AGENTS.md"
  [ "$output" = "custom" ]
}

@test "does not overwrite existing .claude/settings.json" {
  init_git_target
  mkdir -p "$TARGET/.claude"
  echo '{"custom":true}' > "$TARGET/.claude/settings.json"
  AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  run cat "$TARGET/.claude/settings.json"
  [ "$output" = '{"custom":true}' ]
}

@test "skips submodule add when vendor/ai-sdd-guide already exists" {
  init_git_target
  mkdir -p "$TARGET/vendor/ai-sdd-guide"
  AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  # Should succeed without error
  [ -d "$TARGET/vendor/ai-sdd-guide" ]
}

# --- SDD requires git repo ----------------------------------------------------

@test "skips SDD setup when target is not a git repo" {
  run bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  # devcontainer should still be created
  [ -f "$TARGET/.devcontainer/devcontainer.json" ]
  # SDD should not be set up
  [ ! -d "$TARGET/vendor/ai-sdd-guide" ]
}
