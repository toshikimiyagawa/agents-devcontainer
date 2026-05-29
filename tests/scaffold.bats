#!/usr/bin/env bats

SCAFFOLD="$BATS_TEST_DIRNAME/../scaffold.sh"

setup() {
  TMPDIR="$(mktemp -d)"
  TARGET="$TMPDIR/myproject"
  mkdir -p "$TARGET"

  export GIT_CONFIG_COUNT=1
  export GIT_CONFIG_KEY_0=protocol.file.allow
  export GIT_CONFIG_VALUE_0=always

  # --- ai-sdd-guide fixture ---
  SDD_BARE="$TMPDIR/ai-sdd-guide.git"
  git init --bare "$SDD_BARE" >/dev/null 2>&1

  SDD_WORK="$TMPDIR/sdd-work"
  git clone "$SDD_BARE" "$SDD_WORK" >/dev/null 2>&1
  mkdir -p "$SDD_WORK/integration/agents" "$SDD_WORK/integration/ci"
  echo "# CLAUDE.md example" > "$SDD_WORK/integration/CLAUDE.md.example"
  echo "# AGENTS.md example" > "$SDD_WORK/integration/AGENTS.md.example"
  echo '{"hooks":{}}' > "$SDD_WORK/integration/settings.json.example"
  echo "# sdd-reviewer" > "$SDD_WORK/integration/agents/sdd-reviewer.md"
  echo "name: sdd-check" > "$SDD_WORK/integration/ci/sdd-check.yml"
  (cd "$SDD_WORK" && git add -A && git -c user.name=test -c user.email=test@test.com commit -m "init" >/dev/null 2>&1)
  (cd "$SDD_WORK" && git push >/dev/null 2>&1)

  # --- agents-devcontainer fixture ---
  ADC_BARE="$TMPDIR/agents-devcontainer.git"
  git init --bare "$ADC_BARE" >/dev/null 2>&1

  ADC_WORK="$TMPDIR/adc-work"
  git clone "$ADC_BARE" "$ADC_WORK" >/dev/null 2>&1
  mkdir -p "$ADC_WORK/scaffold"
  cp "$BATS_TEST_DIRNAME/../scaffold/devcontainer.base.json" "$ADC_WORK/scaffold/"
  cp "$BATS_TEST_DIRNAME/../scaffold/merge.sh"               "$ADC_WORK/scaffold/"
  cp "$BATS_TEST_DIRNAME/../scaffold/sdd-update.sh"          "$ADC_WORK/scaffold/"
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
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  [ -f "$TARGET/.devcontainer/devcontainer.json" ]
}

@test "generates devcontainer.project.json" {
  init_git_target
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
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

# --- devcontainer.json content -------------------------------------------------

@test "devcontainer.json is valid JSON" {
  init_git_target
  env AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  run jq empty "$TARGET/.devcontainer/devcontainer.json"
  [ "$status" -eq 0 ]
}

@test "image tag defaults to latest" {
  init_git_target
  env AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  run jq -r '.image' "$TARGET/.devcontainer/devcontainer.json"
  [ "$output" = "ghcr.io/toshikimiyagawa/agents-devcontainer:latest" ]
}

@test "AGENTS_DEVCONTAINER_TAG overrides image tag" {
  init_git_target
  env AGENTS_DEVCONTAINER_TAG=v1.2.3 AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  run jq -r '.image' "$TARGET/.devcontainer/devcontainer.json"
  [ "$output" = "ghcr.io/toshikimiyagawa/agents-devcontainer:v1.2.3" ]
}

@test "name is set to project directory name" {
  init_git_target
  env AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  run jq -r '.name' "$TARGET/.devcontainer/devcontainer.json"
  [ "$output" = "myproject" ]
}

@test "MISE_TRUSTED_CONFIG_PATHS is not present" {
  init_git_target
  env AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  run grep "MISE_TRUSTED_CONFIG_PATHS" "$TARGET/.devcontainer/devcontainer.json"
  [ "$status" -ne 0 ]
}

@test "postCreateCommand is agents-post-create" {
  init_git_target
  env AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  run jq -r '.postCreateCommand' "$TARGET/.devcontainer/devcontainer.json"
  [ "$output" = "agents-post-create" ]
}

@test "postStartCommand is agents-post-start" {
  init_git_target
  env AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
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
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  [ ! -f "$TARGET/.devcontainer/devcontainer.json" ]
}

# --- agents-devcontainer submodule --------------------------------------------

@test "adds agents-devcontainer submodule in git repo" {
  init_git_target
  AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ -d "$TARGET/vendor/agents-devcontainer" ]
  [ -f "$TARGET/vendor/agents-devcontainer/scaffold/merge.sh" ]
}

@test "skips agents-devcontainer submodule when already exists" {
  init_git_target
  mkdir -p "$TARGET/vendor/agents-devcontainer"
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  [ -d "$TARGET/vendor/agents-devcontainer" ]
}

@test "does not add agents-devcontainer submodule when not a git repo" {
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  [ ! -d "$TARGET/vendor/agents-devcontainer" ]
}

# --- SDD integration ----------------------------------------------------------

@test "adds ai-sdd-guide submodule" {
  init_git_target
  AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ -d "$TARGET/vendor/ai-sdd-guide" ]
  [ -f "$TARGET/vendor/ai-sdd-guide/integration/CLAUDE.md.example" ]
}

@test "copies CLAUDE.md from integration" {
  init_git_target
  AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ -f "$TARGET/CLAUDE.md" ]
}

@test "copies AGENTS.md from integration" {
  init_git_target
  AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ -f "$TARGET/AGENTS.md" ]
}

@test "copies .claude/settings.json from integration" {
  init_git_target
  AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ -f "$TARGET/.claude/settings.json" ]
}

@test "copies .claude/agents/ from integration" {
  init_git_target
  AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ -d "$TARGET/.claude/agents" ]
  [ -f "$TARGET/.claude/agents/sdd-reviewer.md" ]
}

@test "copies .github/workflows/sdd-check.yml from integration" {
  init_git_target
  AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ -f "$TARGET/.github/workflows/sdd-check.yml" ]
}

# --- SDD opt-out ---------------------------------------------------------------

@test "AGENTS_DEVCONTAINER_SDD=0 skips SDD setup" {
  init_git_target
  AGENTS_DEVCONTAINER_SDD=0 AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ ! -d "$TARGET/vendor/ai-sdd-guide" ]
  [ ! -f "$TARGET/CLAUDE.md" ]
}

# --- SDD skip existing files ---------------------------------------------------

@test "does not overwrite existing CLAUDE.md" {
  init_git_target
  echo "custom" > "$TARGET/CLAUDE.md"
  AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  run cat "$TARGET/CLAUDE.md"
  [ "$output" = "custom" ]
}

@test "does not overwrite existing AGENTS.md" {
  init_git_target
  echo "custom" > "$TARGET/AGENTS.md"
  AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  run cat "$TARGET/AGENTS.md"
  [ "$output" = "custom" ]
}

@test "does not overwrite existing .claude/settings.json" {
  init_git_target
  mkdir -p "$TARGET/.claude"
  echo '{"custom":true}' > "$TARGET/.claude/settings.json"
  AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  run cat "$TARGET/.claude/settings.json"
  [ "$output" = '{"custom":true}' ]
}

@test "skips submodule add when vendor/ai-sdd-guide already exists" {
  init_git_target
  mkdir -p "$TARGET/vendor/ai-sdd-guide"
  AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ -d "$TARGET/vendor/ai-sdd-guide" ]
}

# --- SDD requires git repo ----------------------------------------------------

@test "skips SDD setup when target is not a git repo" {
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  [ -f "$TARGET/.devcontainer/devcontainer.json" ]
  [ ! -d "$TARGET/vendor/ai-sdd-guide" ]
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
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  [ ! -f "$TARGET/.devcontainer/project-tools.yml" ]
}
