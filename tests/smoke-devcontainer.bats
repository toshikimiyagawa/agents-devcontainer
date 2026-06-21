#!/usr/bin/env bats

SOURCE_SMOKE="$BATS_TEST_DIRNAME/../scripts/smoke-devcontainer.sh"
REAL_JQ="$(command -v jq)"

setup() {
  TEST_TMP="$(mktemp -d)"
  REPO="$TEST_TMP/repo"
  BIN="$TEST_TMP/bin"
  CALLS="$TEST_TMP/calls"
  CONTAINER_HOME="$TEST_TMP/container-home"
  CONTAINER_BIN="$TEST_TMP/container-bin"
  CONTAINER_DOTFILES="$TEST_TMP/container-workspace/dotfiles/.hermes"
  mkdir -p "$REPO/scripts" "$REPO/tests" "$REPO/.devcontainer" "$BIN"
  mkdir -p "$CONTAINER_HOME/.hermes" "$CONTAINER_BIN"
  mkdir -p "$CONTAINER_DOTFILES/memories" "$CONTAINER_HOME/.hermes/skills"
  : > "$CALLS"
  printf '{}\n' > "$REPO/.devcontainer/devcontainer.json"
  printf 'model: test\n' > "$CONTAINER_DOTFILES/config.yaml"
  printf 'API_KEY=test\n' > "$CONTAINER_DOTFILES/.env"
  ln -s "$CONTAINER_DOTFILES/config.yaml" "$CONTAINER_HOME/.hermes/config.yaml"
  ln -s "$CONTAINER_DOTFILES/.env" "$CONTAINER_HOME/.hermes/.env"
  ln -s "$CONTAINER_DOTFILES/memories" "$CONTAINER_HOME/.hermes/memories"
  for tool in codex gemini claude hermes gh yq; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$CONTAINER_BIN/$tool"
    chmod +x "$CONTAINER_BIN/$tool"
  done

  if [[ -f "$SOURCE_SMOKE" ]]; then
    if [[ -f /.dockerenv ]]; then
      sed 's/ || -f \/.dockerenv//' "$SOURCE_SMOKE" > "$REPO/scripts/smoke-devcontainer.sh"
    else
      cp "$SOURCE_SMOKE" "$REPO/scripts/smoke-devcontainer.sh"
    fi
  else
    printf '#!/usr/bin/env bash\nexit 127\n' > "$REPO/scripts/smoke-devcontainer.sh"
  fi
  chmod +x "$REPO/scripts/smoke-devcontainer.sh"

  make_fake_bats
  make_fake_docker
  make_fake_git
  make_fake_devcontainer

  export CALLS REPO TEST_TMP CONTAINER_HOME CONTAINER_BIN CONTAINER_DOTFILES
  export BATS_BIN="$BIN/bats"
  export DOCKER_BIN="$BIN/docker"
  export DEVCONTAINER_BIN="$BIN/devcontainer"
  export GIT_BIN="$BIN/git"
  export JQ_BIN="$REAL_JQ"
  export FAKE_GIT_STATUS_INITIAL=""
  export FAKE_GIT_STATUS_FINAL=""
  unset REMOTE_CONTAINERS FAKE_DOCKER_INFO_FAIL FAKE_DOCKER_BUILD_FAIL
  unset FAKE_DEVCONTAINER_FAIL FAKE_MISSING_TOOL
}

teardown() {
  rm -rf "$TEST_TMP"
}

make_fake_bats() {
  cat > "$BIN/bats" <<'EOF'
#!/usr/bin/env bash
printf 'bats %s\n' "$*" >> "$CALLS"
exit "${FAKE_BATS_STATUS:-0}"
EOF
  chmod +x "$BIN/bats"
}

make_fake_docker() {
  cat > "$BIN/docker" <<'EOF'
#!/usr/bin/env bash
printf 'docker %s\n' "$*" >> "$CALLS"
case "$1" in
  info) [[ -z "${FAKE_DOCKER_INFO_FAIL:-}" ]] ;;
  build)
    if [[ -n "${FAKE_DOCKER_BUILD_FAIL:-}" ]]; then exit 42; fi
    ;;
esac
EOF
  chmod +x "$BIN/docker"
}

make_fake_git() {
  cat > "$BIN/git" <<'EOF'
#!/usr/bin/env bash
printf 'git %s\n' "$*" >> "$CALLS"
if [[ "$*" == *"status --porcelain=v1 --untracked-files=all"* ]]; then
  count_file="$TEST_TMP/git-status-count"
  count=0
  [[ -f "$count_file" ]] && count="$(cat "$count_file")"
  count=$((count + 1))
  printf '%s' "$count" > "$count_file"
  if [[ "$count" -eq 1 ]]; then
    printf '%s' "${FAKE_GIT_STATUS_INITIAL:-}"
  else
    printf '%s' "${FAKE_GIT_STATUS_FINAL:-${FAKE_GIT_STATUS_INITIAL:-}}"
  fi
fi
EOF
  chmod +x "$BIN/git"
}

make_fake_devcontainer() {
  cat > "$BIN/devcontainer" <<'EOF'
#!/usr/bin/env bash
subcommand="$1"
shift
printf 'devcontainer %s %s\n' "$subcommand" "$*" >> "$CALLS"

if [[ "$subcommand" = "read-configuration" ]]; then
  cat <<'JSON'
{"configuration":{"name":"smoke-test","build":{"context":"..","dockerfile":"../.devcontainer/Dockerfile","options":["--pull"]},"workspaceFolder":"/workspace","postCreateCommand":"agents-post-create","postStartCommand":"agents-post-start"}}
JSON
  exit 0
fi

if [[ "${FAKE_DEVCONTAINER_FAIL:-}" = "$subcommand" ]]; then
  exit 43
fi

if [[ "$subcommand" = "up" ]]; then
  while [[ "$#" -gt 0 ]]; do
    if [[ "$1" = "--config" ]]; then
      config="$2"
      printf '%s' "$config" > "$TEST_TMP/temp-config-path"
      cp "$config" "$TEST_TMP/captured-config.json"
      dockerfile="$("${REAL_JQ_FOR_FAKE:-jq}" -r '.build.dockerfile' "$config")"
      cp "$dockerfile" "$TEST_TMP/captured-Dockerfile"
      break
    fi
    shift
  done
fi

if [[ "$subcommand" = "exec" ]]; then
  command_string="${@: -1}"
  if [[ "$command_string" = *"for tool in codex"* ]]; then
    if [[ -n "${FAKE_MISSING_TOOL:-}" ]]; then
      rm -f "$CONTAINER_BIN/$FAKE_MISSING_TOOL"
    fi
    HOME="$CONTAINER_HOME" PATH="$CONTAINER_BIN:/usr/bin:/bin" bash -c "$command_string"
    exit $?
  fi
  if [[ "$command_string" = *"invalid Hermes persistence layout"* ]]; then
    command_string="${command_string//\/workspace\/dotfiles\/.hermes/$CONTAINER_DOTFILES}"
    HOME="$CONTAINER_HOME" PATH="$CONTAINER_BIN:/usr/bin:/bin" bash -c "$command_string"
    exit $?
  fi
fi
EOF
  chmod +x "$BIN/devcontainer"
  export REAL_JQ_FOR_FAKE="$REAL_JQ"
}

run_smoke() {
  run env \
    BATS_BIN="$BATS_BIN" \
    DOCKER_BIN="$DOCKER_BIN" \
    DEVCONTAINER_BIN="$DEVCONTAINER_BIN" \
    GIT_BIN="$GIT_BIN" \
    JQ_BIN="$JQ_BIN" \
    REAL_JQ_FOR_FAKE="$REAL_JQ_FOR_FAKE" \
    CALLS="$CALLS" REPO="$REPO" TEST_TMP="$TEST_TMP" \
    CONTAINER_HOME="$CONTAINER_HOME" CONTAINER_BIN="$CONTAINER_BIN" \
    CONTAINER_DOTFILES="$CONTAINER_DOTFILES" \
    FAKE_GIT_STATUS_INITIAL="${FAKE_GIT_STATUS_INITIAL:-}" \
    FAKE_GIT_STATUS_FINAL="${FAKE_GIT_STATUS_FINAL:-}" \
    FAKE_DOCKER_INFO_FAIL="${FAKE_DOCKER_INFO_FAIL:-}" \
    FAKE_DOCKER_BUILD_FAIL="${FAKE_DOCKER_BUILD_FAIL:-}" \
    FAKE_DEVCONTAINER_FAIL="${FAKE_DEVCONTAINER_FAIL:-}" \
    FAKE_MISSING_TOOL="${FAKE_MISSING_TOOL:-}" \
    bash "$REPO/scripts/smoke-devcontainer.sh"
}

@test "rejects execution inside a devcontainer" {
  if [[ -f /.dockerenv ]]; then
    run bash "$SOURCE_SMOKE"
  else
    REMOTE_CONTAINERS=true run_smoke
  fi
  [ "$status" -ne 0 ]
  [ "$status" -ne 127 ]
  [[ "$output" == *"must be run from the host"* ]]
  ! grep -q '^docker build ' "$CALLS"
}

@test "reports each missing host prerequisite before building" {
  for variable in BATS_BIN DOCKER_BIN DEVCONTAINER_BIN GIT_BIN JQ_BIN; do
    original="${!variable}"
    export "$variable=$BIN/missing-${variable}"
    run_smoke
    [ "$status" -ne 0 ]
    [ "$status" -ne 127 ]
    [[ "$output" == *"missing required host command"* ]]
    export "$variable=$original"
  done
  ! grep -q '^docker build ' "$CALLS"
}

@test "fails before building when Docker is unusable" {
  export FAKE_DOCKER_INFO_FAIL=1
  run_smoke
  [ "$status" -ne 0 ]
  [ "$status" -ne 127 ]
  [[ "$output" == *"Docker daemon is not usable"* ]]
  ! grep -q '^docker build ' "$CALLS"
}

@test "runs host tests before building the current checkout" {
  run_smoke
  [ "$status" -eq 0 ]
  grep -F "bats $REPO/tests/" "$CALLS"
  grep -F "docker build -t agents-devcontainer:pr -f $REPO/.devcontainer/Dockerfile.base $REPO" "$CALLS"
  bats_line="$(grep -n '^bats ' "$CALLS" | head -1 | cut -d: -f1)"
  build_line="$(grep -n '^docker build ' "$CALLS" | head -1 | cut -d: -f1)"
  [ "$bats_line" -lt "$build_line" ]
}

@test "derives a temporary config from the tracked dogfood config" {
  run_smoke
  [ "$status" -eq 0 ]
  grep -F "devcontainer read-configuration --workspace-folder $REPO --config $REPO/.devcontainer/devcontainer.json" "$CALLS"
  captured="$TEST_TMP/captured-config.json"
  [ "$(jq -r '.build.context' "$captured")" = "$REPO" ]
  [ "$(jq -r '.build.options | length' "$captured")" -eq 0 ]
  grep -F 'ARG BASE_IMAGE=agents-devcontainer:pr' "$TEST_TMP/captured-Dockerfile"
  grep -F 'FROM ${BASE_IMAGE}' "$TEST_TMP/captured-Dockerfile"
  [ "$(jq -r '.postCreateCommand' "$captured")" = "agents-post-create" ]
  [ "$(jq -r '.postStartCommand' "$captured")" = "agents-post-start" ]
}

@test "uses the local image config and remove-existing-container for up" {
  run_smoke
  [ "$status" -eq 0 ]
  grep -F "devcontainer up --workspace-folder $REPO --config " "$CALLS"
  grep -F -- '--remove-existing-container' "$CALLS"
  ! grep -F -- '--skip-post-create' "$CALLS"
}

@test "propagates devcontainer lifecycle failure" {
  export FAKE_DEVCONTAINER_FAIL=up
  run_smoke
  [ "$status" -eq 43 ]
}

@test "runs Bats and required tool checks inside the container" {
  run_smoke
  [ "$status" -eq 0 ]
  grep -F 'bats tests/' "$CALLS"
  for tool in codex gemini claude hermes gh yq; do
    grep -F "$tool" "$CALLS"
  done
}

@test "warns without failing when Hermes provider configuration is absent" {
  : > "$CONTAINER_DOTFILES/config.yaml"
  : > "$CONTAINER_DOTFILES/.env"
  run_smoke
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING: Hermes provider/model configuration is not configured"* ]]
}

@test "fails when the Hermes persistence layout check fails" {
  rm "$CONTAINER_HOME/.hermes/config.yaml"
  ln -s "$TEST_TMP/wrong-config.yaml" "$CONTAINER_HOME/.hermes/config.yaml"
  run_smoke
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid Hermes persistence layout"* ]]
}

@test "fails with the missing required tool name" {
  export FAKE_MISSING_TOOL=gemini
  run_smoke
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing required tool: gemini"* ]]
}

@test "removes temporary files after success and failure" {
  run_smoke
  [ "$status" -eq 0 ]
  temp_config="$(cat "$TEST_TMP/temp-config-path")"
  [ ! -e "$temp_config" ]

  export FAKE_DEVCONTAINER_FAIL=up
  run_smoke
  [ "$status" -eq 43 ]
  temp_config="$(cat "$TEST_TMP/temp-config-path")"
  [ ! -e "$temp_config" ]
}

@test "fails when smoke changes the working tree" {
  export FAKE_GIT_STATUS_FINAL=' M dotfiles/.zshrc'
  run_smoke
  [ "$status" -eq 1 ]
  [[ "$output" == *"smoke changed the working tree"* ]]
}

@test "preserves the original failure when cleanup also detects a tree change" {
  export FAKE_DOCKER_BUILD_FAIL=1
  export FAKE_GIT_STATUS_FINAL=' M dotfiles/.zshrc'
  run_smoke
  [ "$status" -eq 42 ]
}

@test "can be launched outside the repository root" {
  cd "$TEST_TMP"
  run_smoke
  [ "$status" -eq 0 ]
  grep -F "$REPO/.devcontainer/Dockerfile.base" "$CALLS"
}

@test "workflow covers every required smoke path" {
  workflow="$BATS_TEST_DIRNAME/../.github/workflows/smoke-devcontainer.yml"
  [ -f "$workflow" ]
  for path in \
    '.devcontainer/Dockerfile.base' \
    '.devcontainer/Dockerfile' \
    '.devcontainer/devcontainer.json' \
    '.devcontainer/scripts/**' \
    'dotfiles/**' \
    'scaffold.sh' \
    'scaffold/**' \
    'scripts/smoke-devcontainer.sh' \
    'tests/smoke-devcontainer.bats' \
    '.github/workflows/smoke-devcontainer.yml'; do
    grep -F "$path" "$workflow"
  done
}

@test "workflow installs prerequisites and invokes the shared smoke script" {
  workflow="$BATS_TEST_DIRNAME/../.github/workflows/smoke-devcontainer.yml"
  [ -f "$workflow" ]
  grep -F 'actions/checkout@v4' "$workflow"
  grep -F 'bats-core/bats-action@3.0.0' "$workflow"
  grep -F 'npm install -g @devcontainers/cli' "$workflow"
  grep -F 'mkdir -p "$HOME/.ssh"' "$workflow"
  grep -F 'scripts/smoke-devcontainer.sh' "$workflow"
  ! grep -Eq 'docker[[:space:]]+push|docker/login-action|packages:[[:space:]]*write' "$workflow"
}

@test "README defines the host-only devcontainer smoke gate" {
  readme="$BATS_TEST_DIRNAME/../README.md"
  grep -F 'scripts/smoke-devcontainer.sh' "$readme"
  grep -F 'host 側' "$readme"
  grep -F '`bats tests/` だけでは完了ではない' "$readme"
  grep -F -- '--remove-existing-container' "$readme"
  grep -F 'Hermes' "$readme" | grep -F 'warning'
  grep -F 'PR description' "$readme"
  for path in \
    '.devcontainer/Dockerfile.base' \
    '.devcontainer/Dockerfile' \
    '.devcontainer/devcontainer.json' \
    '.devcontainer/scripts/**' \
    'dotfiles/**' \
    'scaffold.sh' \
    'scaffold/**' \
    'scripts/smoke-devcontainer.sh' \
    'tests/smoke-devcontainer.bats' \
    '.github/workflows/smoke-devcontainer.yml'; do
    grep -F "$path" "$readme"
  done
}
