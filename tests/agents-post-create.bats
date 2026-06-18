#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../.devcontainer/scripts/agents-post-create"

setup() {
  TMPDIR="$(mktemp -d)"
  export HOME="$TMPDIR/home"
  export AGENTS_DOTFILES_PROJECT="$TMPDIR/workspace/dotfiles"
  mkdir -p "$HOME" "$TMPDIR/bin" "$AGENTS_DOTFILES_PROJECT"
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

@test "links Hermes state directory from project dotfiles" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -d "$AGENTS_DOTFILES_PROJECT/.hermes" ]
  [ -L "$HOME/.hermes" ]
  [ "$(readlink "$HOME/.hermes")" = "$AGENTS_DOTFILES_PROJECT/.hermes" ]
}

@test "re-running keeps Hermes state link idempotent" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  echo "configured" > "$AGENTS_DOTFILES_PROJECT/.hermes/config.yaml"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -L "$HOME/.hermes" ]
  [ "$(readlink "$HOME/.hermes")" = "$AGENTS_DOTFILES_PROJECT/.hermes" ]
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
test -L "$HOME/.hermes"
test "$(readlink "$HOME/.hermes")" = "$AGENTS_DOTFILES_PROJECT/.hermes"
exit 0
SH
  chmod +x "$TMPDIR/bin/hermes"
  export HERMES_CALL_LOG="$TMPDIR/hermes-calls.log"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  run cat "$HERMES_CALL_LOG"
  [ "$output" = "skills install --yes skills-sh/obra/superpowers" ]
  [ -f "$AGENTS_DOTFILES_PROJECT/.hermes/.agents-superpowers-installed" ]
}

@test "skips Hermes superpowers install when marker exists" {
  mkdir -p "$AGENTS_DOTFILES_PROJECT/.hermes"
  touch "$AGENTS_DOTFILES_PROJECT/.hermes/.agents-superpowers-installed"
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
