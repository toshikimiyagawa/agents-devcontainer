#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../.devcontainer/scripts/agents-post-create"

setup() {
  TMPDIR="$(mktemp -d)"
  export HOME="$TMPDIR/home"
  export AGENTS_DOTFILES_PROJECT="$TMPDIR/workspace/dotfiles"
  mkdir -p "$HOME" "$TMPDIR/bin" "$AGENTS_DOTFILES_PROJECT"
  mkdir -p "$HOME/.hermes/hermes-agent/venv/bin"
  echo "image install" > "$HOME/.hermes/hermes-agent/venv/bin/hermes"
  export PATH="$TMPDIR/bin:$PATH"
  cat > "$TMPDIR/bin/agents-dotfiles-sync" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$TMPDIR/bin/agents-dotfiles-sync"
  cat > "$TMPDIR/bin/git" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$TMPDIR/bin/git"
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "keeps Hermes install directory while linking user state paths" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -d "$AGENTS_DOTFILES_PROJECT/.hermes" ]
  [ -d "$HOME/.hermes" ]
  [ ! -L "$HOME/.hermes" ]
  [ -f "$HOME/.hermes/hermes-agent/venv/bin/hermes" ]
  [ -L "$HOME/.hermes/config.yaml" ]
  [ "$(readlink "$HOME/.hermes/config.yaml")" = "$AGENTS_DOTFILES_PROJECT/.hermes/config.yaml" ]
  [ -f "$AGENTS_DOTFILES_PROJECT/.hermes/config.yaml" ]
  [ -L "$HOME/.hermes/.env" ]
  [ "$(readlink "$HOME/.hermes/.env")" = "$AGENTS_DOTFILES_PROJECT/.hermes/.env" ]
  [ -f "$AGENTS_DOTFILES_PROJECT/.hermes/.env" ]
  [ -d "$HOME/.hermes/skills" ]
  [ ! -L "$HOME/.hermes/skills" ]
  [ -d "$AGENTS_DOTFILES_PROJECT/.hermes/skills" ]
  [ -L "$HOME/.hermes/memories" ]
  [ "$(readlink "$HOME/.hermes/memories")" = "$AGENTS_DOTFILES_PROJECT/.hermes/memories" ]
}

@test "creates Hermes file state targets before linking them" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  run bash -c 'printf "value\n" > "$HOME/.hermes/.env"'
  [ "$status" -eq 0 ]
  run cat "$AGENTS_DOTFILES_PROJECT/.hermes/.env"
  [ "$output" = "value" ]

  run bash -c 'printf "setting: true\n" > "$HOME/.hermes/config.yaml"'
  [ "$status" -eq 0 ]
  run cat "$AGENTS_DOTFILES_PROJECT/.hermes/config.yaml"
  [ "$output" = "setting: true" ]
}

@test "restores Hermes skills from persisted state without symlinking skills directory" {
  mkdir -p "$AGENTS_DOTFILES_PROJECT/.hermes/skills/superpowers"
  echo "persisted skill" > "$AGENTS_DOTFILES_PROJECT/.hermes/skills/superpowers/SKILL.md"
  touch "$AGENTS_DOTFILES_PROJECT/.hermes/.agents-superpowers-installed"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -d "$HOME/.hermes/skills" ]
  [ ! -L "$HOME/.hermes/skills" ]
  run cat "$HOME/.hermes/skills/superpowers/SKILL.md"
  [ "$output" = "persisted skill" ]
}

@test "re-running keeps Hermes state links idempotent" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  echo "configured" > "$AGENTS_DOTFILES_PROJECT/.hermes/config.yaml"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -d "$HOME/.hermes" ]
  [ ! -L "$HOME/.hermes" ]
  [ -f "$HOME/.hermes/hermes-agent/venv/bin/hermes" ]
  [ -L "$HOME/.hermes/config.yaml" ]
  run cat "$HOME/.hermes/config.yaml"
  [ "$output" = "configured" ]
}

@test "keeps existing Claude Gemini Codex links working" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.claude")" = "$AGENTS_DOTFILES_PROJECT/.claude" ]
  [ "$(readlink "$HOME/.gemini")" = "$AGENTS_DOTFILES_PROJECT/.gemini" ]
  [ "$(readlink "$HOME/.codex")" = "$AGENTS_DOTFILES_PROJECT/.codex" ]
}

@test "installs Hermes superpowers after linking Hermes state" {
  cat > "$TMPDIR/bin/hermes" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$HERMES_CALL_LOG"
test -d "$HOME/.hermes"
test ! -L "$HOME/.hermes"
test -f "$HOME/.hermes/hermes-agent/venv/bin/hermes"
test -d "$HOME/.hermes/skills"
test ! -L "$HOME/.hermes/skills"
mkdir -p "$HOME/.hermes/skills/superpowers"
echo "installed skill" > "$HOME/.hermes/skills/superpowers/SKILL.md"
exit 0
SH
  chmod +x "$TMPDIR/bin/hermes"
  export HERMES_CALL_LOG="$TMPDIR/hermes-calls.log"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  run cat "$HERMES_CALL_LOG"
  [ "$output" = "skills install --yes skills-sh/obra/superpowers" ]
  [ -f "$AGENTS_DOTFILES_PROJECT/.hermes/.agents-superpowers-installed" ]
  run cat "$AGENTS_DOTFILES_PROJECT/.hermes/skills/superpowers/SKILL.md"
  [ "$output" = "installed skill" ]
}

@test "skips Hermes superpowers install when marker exists" {
  mkdir -p "$AGENTS_DOTFILES_PROJECT/.hermes"
  touch "$AGENTS_DOTFILES_PROJECT/.hermes/.agents-superpowers-installed"
  mkdir -p "$HOME/.hermes/skills/superpowers"
  echo "installed skill" > "$HOME/.hermes/skills/superpowers/SKILL.md"
  cat > "$TMPDIR/bin/hermes" <<'SH'
#!/usr/bin/env bash
echo "unexpected hermes call" >&2
exit 99
SH
  chmod +x "$TMPDIR/bin/hermes"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hermes superpowers already bootstrapped"* ]]
}

@test "does not skip Hermes superpowers install when marker exists but skill is absent" {
  mkdir -p "$AGENTS_DOTFILES_PROJECT/.hermes"
  touch "$AGENTS_DOTFILES_PROJECT/.hermes/.agents-superpowers-installed"
  cat > "$TMPDIR/bin/hermes" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$HERMES_CALL_LOG"
mkdir -p "$HOME/.hermes/skills/superpowers"
echo "installed skill" > "$HOME/.hermes/skills/superpowers/SKILL.md"
exit 0
SH
  chmod +x "$TMPDIR/bin/hermes"
  export HERMES_CALL_LOG="$TMPDIR/hermes-calls.log"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  run cat "$HERMES_CALL_LOG"
  [ "$output" = "skills install --yes skills-sh/obra/superpowers" ]
  run cat "$AGENTS_DOTFILES_PROJECT/.hermes/skills/superpowers/SKILL.md"
  [ "$output" = "installed skill" ]
}

@test "keeps postCreate successful when Hermes superpowers install fails" {
  cat > "$TMPDIR/bin/hermes" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$HERMES_CALL_LOG"
exit 42
SH
  chmod +x "$TMPDIR/bin/hermes"
  export HERMES_CALL_LOG="$TMPDIR/hermes-calls.log"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  script_output="$output"
  run cat "$HERMES_CALL_LOG"
  [ "$output" = "skills install --yes skills-sh/obra/superpowers" ]
  [ ! -f "$AGENTS_DOTFILES_PROJECT/.hermes/.agents-superpowers-installed" ]
  [[ "$script_output" == *"warn: Hermes superpowers bootstrap failed"* ]]
}

@test "skips Hermes superpowers bootstrap when hermes command is unavailable" {
  PATH="$TMPDIR/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skip Hermes superpowers bootstrap (hermes command not found)"* ]]
  [ ! -f "$AGENTS_DOTFILES_PROJECT/.hermes/.agents-superpowers-installed" ]
}
