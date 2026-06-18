#!/usr/bin/env bats
# Assertions on the committed dogfood .devcontainer/devcontainer.json.
# This file is JSONC (has // comments), so assert with grep rather than jq.

DEVCONTAINER_JSON="$BATS_TEST_DIRNAME/../.devcontainer/devcontainer.json"

@test "dogfood devcontainer.json sets CLAUDE_CONFIG_DIR to /home/ubuntu/.claude" {
  grep -Eq '"CLAUDE_CONFIG_DIR"[[:space:]]*:[[:space:]]*"/home/ubuntu/\.claude"' "$DEVCONTAINER_JSON"
}

@test "dogfood devcontainer.json initializeCommand creates dotfiles/.hermes" {
  grep -q 'dotfiles/.hermes' "$DEVCONTAINER_JSON"
}
