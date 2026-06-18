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
