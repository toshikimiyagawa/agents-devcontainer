#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

ADC="$BATS_TEST_DIRNAME/../bin/adc"

setup() {
  TMPDIR="$(mktemp -d)"
  TARGET="$TMPDIR/target-repo"
  mkdir -p "$TARGET"
  before_listing="$TMPDIR/before.txt"
  after_listing="$TMPDIR/after.txt"
}

teardown() {
  rm -rf "$TMPDIR"
}

list_target() {
  find "$TARGET" -mindepth 1 -maxdepth 3 -print | sort
}

@test "adc up dry-run injects agents feature with additional-features" {
  run "$ADC" up --dry-run "$TARGET"
  [ "$status" -eq 0 ]
  [[ "$output" == *"devcontainer up"* ]]
  [[ "$output" == *"--workspace-folder"* ]]
  [[ "$output" == *"$TARGET"* ]]
  [[ "$output" == *"--additional-features"* ]]
  [[ "$output" == *"ghcr.io/toshikimiyagawa/agents-devcontainer/agents:1"* ]]
}

@test "adc up dry-run keeps state outside target repository" {
  list_target > "$before_listing"
  run "$ADC" up --dry-run "$TARGET"
  [ "$status" -eq 0 ]
  list_target > "$after_listing"
  diff -u "$before_listing" "$after_listing"
  [[ "$output" == *"--mount"* ]]
  [[ "$output" == *"target=/usr/local/share/agents-devcontainer/state"* ]]
  [[ "$output" != *"source=$TARGET"* ]]
  [[ "$output" != *"$TARGET/.devcontainer"* ]]
}

@test "adc help documents raw devcontainer up limitation" {
  run "$ADC" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"adc up"* ]]
  [[ "$output" == *"raw devcontainer up"* ]]
  [[ "$output" == *"does not apply VS Code defaultFeatures"* ]]
}

@test "adc up fails clearly when devcontainer CLI is missing" {
  run -127 env PATH="/usr/bin:/bin" "$ADC" up "$TARGET"
  [[ "$output" == *"devcontainer CLI not found"* ]]
}
