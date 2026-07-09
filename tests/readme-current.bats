#!/usr/bin/env bats

README="$BATS_TEST_DIRNAME/../README.md"
AGENTS="$BATS_TEST_DIRNAME/../.devcontainer/Agents.md"

assert_file_contains() {
  grep -F -- "$2" "$1" >/dev/null
}

assert_file_not_contains() {
  ! grep -F -- "$2" "$1" >/dev/null
}

@test "README does not advertise an unpublished concrete image tag" {
  assert_file_not_contains "$README" "AGENTS_DEVCONTAINER_TAG=v0.1.0"
  assert_file_contains "$README" "AGENTS_DEVCONTAINER_TAG=<published-tag>"
}

@test "README documents project-tools as the first path for project-specific tools" {
  assert_file_contains "$README" ".devcontainer/project-tools.yml"
  assert_file_contains "$README" "agents-tools-install"
  assert_file_contains "$README" "Dockerfile が必要な場合"
}

@test "Agents.md documents current dotfiles layout" {
  assert_file_not_contains "$AGENTS" "/workspace/.devcontainer/dotfiles/"
  assert_file_not_contains "$AGENTS" "/opt/agents/dotfiles/"
  assert_file_contains "$AGENTS" "/workspace/dotfiles/"
  assert_file_contains "$AGENTS" "vendor/agents-devcontainer/dotfiles"
}

@test "Agents.md does not claim scaffold installs ai-sdd-guide" {
  assert_file_not_contains "$AGENTS" 'scaffold.sh` が git submodule として `vendor/ai-sdd-guide'
  assert_file_contains "$AGENTS" "agents-devcontainer とは独立して導入"
}
