#!/usr/bin/env bats
# Assertions on the committed Hermes config baked into Dockerfile.base.

DOCKERFILE="$BATS_TEST_DIRNAME/../.devcontainer/Dockerfile.base"
HERMES_INIT="$BATS_TEST_DIRNAME/../.devcontainer/scripts/hermes-init.sh"

# --- hermes-init.sh exists and is executable -----------------------------------

@test "hermes-init.sh exists" {
  [ -f "$HERMES_INIT" ]
}

@test "hermes-init.sh is executable" {
  [ -x "$HERMES_INIT" ]
}

# --- Dockerfile.base calls hermes-init.sh after Hermes install -----------------

@test "Dockerfile.base runs hermes-init.sh after the installer" {
  run grep -n "hermes-init\.sh" "$DOCKERFILE"
  # The init.sh line must appear after the installer line.
  # Installer is on line 104; init.sh is on a later line.
  run awk '
    /hermes-agent\.nousresearch\.com\/install\.sh/  { i = NR }
    /hermes-init\.sh/ && NR > i { print "ok"; exit }
  ' "$DOCKERFILE"
  [[ "$output" == "ok" ]]
}

@test "hermes-init.sh is copied into the image" {
  grep -q "hermes-init.sh" "$DOCKERFILE"
}

# --- hermes-init.sh contains correct model config ------------------------------

@test "hermes-init.sh sets model default to qwen3.6-35b-a3b" {
  grep -q "qwen3.6-35b-a3b" "$HERMES_INIT"
}

@test "hermes-init.sh sets provider to custom" {
  grep -q "provider: custom" "$HERMES_INIT"
}

@test "hermes-init.sh points to vllm.solvelio.com" {
  grep -q "vllm.solvelio.com" "$HERMES_INIT"
}

@test "hermes-init.sh sets base_url to /v1 endpoint" {
  grep -q "https://vllm.solvelio.com/v1" "$HERMES_INIT"
}
