#!/usr/bin/env bash
set -euo pipefail

BATS_BIN="${BATS_BIN:-bats}"
DOCKER_BIN="${DOCKER_BIN:-docker}"
DEVCONTAINER_BIN="${DEVCONTAINER_BIN:-devcontainer}"
GIT_BIN="${GIT_BIN:-git}"
JQ_BIN="${JQ_BIN:-jq}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
tmp_dir=""
initial_status=""
current_stage=""

log() {
  printf '[smoke-devcontainer] %s\n' "$*"
}

fail() {
  printf '[smoke-devcontainer] ERROR: %s\n' "$*" >&2
  exit 1
}

stage() {
  current_stage="$1"
  log "stage: $current_stage"
}

on_error() {
  error_status="$?"
  trap - ERR
  if [[ -n "$current_stage" ]]; then
    printf '[smoke-devcontainer] ERROR: stage failed: %s (exit %s)\n' \
      "$current_stage" "$error_status" >&2
  fi
  exit "$error_status"
}
trap on_error ERR

if [[ -n "${REMOTE_CONTAINERS:-}" || -f /.dockerenv ]]; then
  fail "must be run from the host, not from inside a devcontainer"
fi

for command_path in "$BATS_BIN" "$DOCKER_BIN" "$DEVCONTAINER_BIN" "$GIT_BIN" "$JQ_BIN"; do
  if ! command -v "$command_path" >/dev/null 2>&1; then
    fail "missing required host command: $command_path"
  fi
done

if ! "$DOCKER_BIN" info >/dev/null 2>&1; then
  fail "Docker daemon is not usable"
fi

initial_status="$($GIT_BIN -C "$REPO_ROOT" status --porcelain=v1 --untracked-files=all)"

cleanup() {
  incoming_status="$?"
  trap - ERR
  trap - EXIT
  set +e
  cleanup_failed=0

  if [[ -n "$tmp_dir" ]]; then
    if ! rm -rf "$tmp_dir"; then
      printf '[smoke-devcontainer] ERROR: failed to remove temporary files: %s\n' \
        "$tmp_dir" >&2
      cleanup_failed=1
    fi
  fi

  final_status=""
  if ! final_status="$($GIT_BIN -C "$REPO_ROOT" status --porcelain=v1 --untracked-files=all)"; then
    printf '[smoke-devcontainer] ERROR: failed to inspect final working tree\n' >&2
    cleanup_failed=1
  elif [[ "$final_status" != "$initial_status" ]]; then
    printf '[smoke-devcontainer] ERROR: smoke changed the working tree\n' >&2
    cleanup_failed=1
  fi

  if [[ "$incoming_status" -ne 0 ]]; then
    exit "$incoming_status"
  fi
  if [[ "$cleanup_failed" -ne 0 ]]; then
    exit 1
  fi
  exit "$incoming_status"
}
trap cleanup EXIT

log "WARNING: --remove-existing-container may replace the current dogfood container"

stage host-tests
"$BATS_BIN" "$REPO_ROOT/tests/"

stage base-image-build
"$DOCKER_BIN" build -t agents-devcontainer:pr \
  -f "$REPO_ROOT/.devcontainer/Dockerfile.base" "$REPO_ROOT"

stage derive-config
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/agents-devcontainer-smoke.XXXXXX")"
printf '%s\n' \
  'ARG BASE_IMAGE=agents-devcontainer:pr' \
  'FROM ${BASE_IMAGE}' \
  > "$tmp_dir/Dockerfile"

"$DEVCONTAINER_BIN" read-configuration \
  --workspace-folder "$REPO_ROOT" \
  --config "$REPO_ROOT/.devcontainer/devcontainer.json" \
  > "$tmp_dir/resolved.json"

"$JQ_BIN" --arg root "$REPO_ROOT" --arg dockerfile "$tmp_dir/Dockerfile" '
  .configuration
  | .build = {context: $root, dockerfile: $dockerfile, options: []}
' "$tmp_dir/resolved.json" > "$tmp_dir/devcontainer.json"

stage devcontainer-up
"$DEVCONTAINER_BIN" up \
  --workspace-folder "$REPO_ROOT" \
  --config "$tmp_dir/devcontainer.json" \
  --remove-existing-container

stage container-tests
"$DEVCONTAINER_BIN" exec \
  --workspace-folder "$REPO_ROOT" \
  --config "$tmp_dir/devcontainer.json" \
  bash -lc 'cd /workspace && bats tests/'

stage tool-checks
"$DEVCONTAINER_BIN" exec \
  --workspace-folder "$REPO_ROOT" \
  --config "$tmp_dir/devcontainer.json" \
  bash -lc '
    for tool in codex gemini claude hermes gh yq; do
      if ! command -v "$tool" >/dev/null 2>&1; then
        printf "missing required tool: %s\n" "$tool" >&2
        exit 1
      fi
    done
  '

stage hermes-check
"$DEVCONTAINER_BIN" exec \
  --workspace-folder "$REPO_ROOT" \
  --config "$tmp_dir/devcontainer.json" \
  bash -lc '
    for name in config.yaml .env memories; do
      expected="/workspace/dotfiles/.hermes/$name"
      if [[ ! -L "$HOME/.hermes/$name" ]] \
        || [[ "$(readlink "$HOME/.hermes/$name")" != "$expected" ]]; then
        printf "invalid Hermes persistence layout: %s must link to %s\n" "$name" "$expected" >&2
        exit 1
      fi
    done
    if [[ ! -d "$HOME/.hermes/skills" || -L "$HOME/.hermes/skills" ]]; then
      printf "invalid Hermes persistence layout: skills must be a real directory\n" >&2
      exit 1
    fi
    if ! grep -Eq "[^[:space:]#]" "$HOME/.hermes/config.yaml" \
      && ! grep -Eq "^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=" "$HOME/.hermes/.env"; then
      printf "WARNING: Hermes provider/model configuration is not configured\n" >&2
    fi
  '

log "smoke passed"
