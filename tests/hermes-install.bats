#!/usr/bin/env bats

DOCKERFILE="$BATS_TEST_DIRNAME/../.devcontainer/Dockerfile.base"
README="$BATS_TEST_DIRNAME/../README.md"
AGENTS="$BATS_TEST_DIRNAME/../.devcontainer/Agents.md"

@test "installs Hermes Agent via the official installer" {
  grep -q "hermes-agent.nousresearch.com/install.sh" "$DOCKERFILE"
}

@test "installs Hermes per-user (inside the USER ubuntu block)" {
  # Print the current USER context (1 = ubuntu) on the installer line.
  run awk '
    /^USER ubuntu/ { u = 1 }
    /^USER root/   { u = 0 }
    /hermes-agent\.nousresearch\.com\/install\.sh/ { print u }
  ' "$DOCKERFILE"
  [ "$output" = "1" ]
}

@test "skips the interactive setup wizard" {
  grep -Eq "install\.sh \| bash -s -- .*--skip-setup" "$DOCKERFILE"
}

@test "keeps browser tools (no --skip-browser)" {
  run grep -- "--skip-browser" "$DOCKERFILE"
  [ "$status" -ne 0 ]
  run grep -- "--no-playwright" "$DOCKERFILE"
  [ "$status" -ne 0 ]
}

@test "image LABEL description lists Hermes Agent" {
  grep -q "Hermes Agent" "$DOCKERFILE"
}

@test "README lists Hermes Agent" {
  grep -q "Hermes Agent" "$README"
}

@test "Agents.md lists the hermes command" {
  grep -qi "hermes" "$AGENTS"
}

@test "README documents Hermes state persistence" {
  grep -q "dotfiles/.hermes" "$README"
  grep -q "host.*~/.hermes.*共有しない" "$README"
}

@test "Agents.md documents Hermes state persistence" {
  grep -q "dotfiles/.hermes" "$AGENTS"
  grep -q "host.*~/.hermes.*共有しない" "$AGENTS"
}
