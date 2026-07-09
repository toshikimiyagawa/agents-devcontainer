#!/usr/bin/env bats

DOC="$BATS_TEST_DIRNAME/../docs/external-injection.md"
README="$BATS_TEST_DIRNAME/../README.md"

assert_file_contains() {
  grep -F -- "$2" "$1" >/dev/null
}

@test "documents VS Code defaultFeatures external injection" {
  assert_file_contains "$DOC" "dev.containers.defaultFeatures"
  assert_file_contains "$DOC" "ghcr.io/toshikimiyagawa/agents-devcontainer/agents:1"
  assert_file_contains "$DOC" "Reopen in Container"
  assert_file_contains "$DOC" "dotfiles.repository"
  assert_file_contains "$DOC" "dotfiles.installCommand"
}

@test "documents raw devcontainer up limitation" {
  assert_file_contains "$DOC" "raw devcontainer up"
  assert_file_contains "$DOC" "does not apply VS Code defaultFeatures"
  assert_file_contains "$DOC" "adc up"
}

@test "documents repo-clean policy and initial support matrix" {
  assert_file_contains "$DOC" "target repository"
  assert_file_contains "$DOC" "must not be modified"
  assert_file_contains "$DOC" "Debian/Ubuntu"
  assert_file_contains "$DOC" "Alpine"
  assert_file_contains "$DOC" "Fedora"
  assert_file_contains "$DOC" "sudo-less"
}

@test "README links scaffold and external injection paths separately" {
  assert_file_contains "$README" "scaffold"
  assert_file_contains "$README" "既存devcontainer"
  assert_file_contains "$README" "docs/external-injection.md"
  assert_file_contains "$README" "adc up"
}

@test "README documents devcontainer smoke boundary for external injection changes" {
  assert_file_contains "$README" "scripts/smoke-devcontainer.sh"
  assert_file_contains "$README" ".devcontainer/Dockerfile.base"
  assert_file_contains "$README" "scaffold/**"
  assert_file_contains "$README" "features/agents/**"
  assert_file_contains "$README" "bin/adc"
  assert_file_contains "$README" "full devcontainer smoke は不要"
}
