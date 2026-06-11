#!/usr/bin/env bats

MERGE="$BATS_TEST_DIRNAME/../scaffold/merge.sh"

setup() {
  TMPDIR="$(mktemp -d)"
  mkdir -p "$TMPDIR/.devcontainer"

  cat > "$TMPDIR/base.json" <<'JSON'
{
  "image": "ghcr.io/toshikimiyagawa/agents-devcontainer:latest",
  "workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind,consistency=cached",
  "workspaceFolder": "/workspace",
  "initializeCommand": "mkdir -p foo",
  "mounts": [
    "source=devcontainer-gh-${devcontainerId},target=/home/ubuntu/.gh-config,type=volume"
  ],
  "remoteEnv": {
    "GH_CONFIG_DIR": "/home/ubuntu/.gh-config",
    "GIT_AUTHOR_NAME": "${localEnv:GIT_AUTHOR_NAME}"
  },
  "containerUser": "ubuntu",
  "remoteUser": "ubuntu",
  "postCreateCommand": "agents-post-create",
  "postStartCommand": "agents-post-start"
}
JSON

  export BASE_JSON="$TMPDIR/base.json"
  export OUTPUT_FILE="$TMPDIR/.devcontainer/devcontainer.json"
}

teardown() {
  rm -rf "$TMPDIR"
}

run_merge() {
  export PROJ_JSON_FILE="$TMPDIR/.devcontainer/devcontainer.project.json"
  run bash "$MERGE" "$TMPDIR"
}

# --- basic merge ---------------------------------------------------------------

@test "merge: output is valid JSON" {
  echo '{"name":"myapp"}' > "$TMPDIR/.devcontainer/devcontainer.project.json"
  run_merge
  [ "$status" -eq 0 ]
  run jq empty "$OUTPUT_FILE"
  [ "$status" -eq 0 ]
}

@test "merge: name from project.json" {
  echo '{"name":"myapp"}' > "$TMPDIR/.devcontainer/devcontainer.project.json"
  run_merge
  run jq -r '.name' "$OUTPUT_FILE"
  [ "$output" = "myapp" ]
}

@test "merge: name defaults to directory basename when project.json has no name" {
  echo '{}' > "$TMPDIR/.devcontainer/devcontainer.project.json"
  run_merge
  run jq -r '.name' "$OUTPUT_FILE"
  [ "$output" = "$(basename "$TMPDIR")" ]
}

@test "merge: name defaults to directory basename when project.json absent" {
  run_merge
  run jq -r '.name' "$OUTPUT_FILE"
  [ "$output" = "$(basename "$TMPDIR")" ]
}

# --- image/build ---------------------------------------------------------------

@test "merge: base image is preserved when project has no image override" {
  echo '{"name":"myapp"}' > "$TMPDIR/.devcontainer/devcontainer.project.json"
  run_merge
  run jq -r '.image' "$OUTPUT_FILE"
  [ "$output" = "ghcr.io/toshikimiyagawa/agents-devcontainer:latest" ]
}

@test "merge: project image overrides base image" {
  echo '{"name":"myapp","image":"ghcr.io/toshikimiyagawa/agents-devcontainer:v1.2.3"}' \
    > "$TMPDIR/.devcontainer/devcontainer.project.json"
  run_merge
  run jq -r '.image' "$OUTPUT_FILE"
  [ "$output" = "ghcr.io/toshikimiyagawa/agents-devcontainer:v1.2.3" ]
}

@test "merge: build key replaces image key" {
  cat > "$TMPDIR/.devcontainer/devcontainer.project.json" <<'JSON'
{
  "name": "myapp",
  "build": {
    "context": "..",
    "dockerfile": "../.devcontainer/Dockerfile"
  }
}
JSON
  run_merge
  run jq 'has("image")' "$OUTPUT_FILE"
  [ "$output" = "false" ]
  run jq -r '.build.dockerfile' "$OUTPUT_FILE"
  [ "$output" = "../.devcontainer/Dockerfile" ]
}

# --- mounts --------------------------------------------------------------------

@test "merge: mounts are concatenated (base + project)" {
  cat > "$TMPDIR/.devcontainer/devcontainer.project.json" <<'JSON'
{
  "name": "myapp",
  "mounts": [
    "source=my-db,target=/var/lib/postgresql/data,type=volume"
  ]
}
JSON
  run_merge
  run jq -r '.mounts | length' "$OUTPUT_FILE"
  [ "$output" = "2" ]
  run jq -r '.mounts[0]' "$OUTPUT_FILE"
  [[ "$output" == *"devcontainer-gh"* ]]
  run jq -r '.mounts[1]' "$OUTPUT_FILE"
  [ "$output" = "source=my-db,target=/var/lib/postgresql/data,type=volume" ]
}

@test "merge: empty project mounts does not duplicate base mounts" {
  echo '{"name":"myapp","mounts":[]}' > "$TMPDIR/.devcontainer/devcontainer.project.json"
  run_merge
  run jq -r '.mounts | length' "$OUTPUT_FILE"
  [ "$output" = "1" ]
}

# --- remoteEnv -----------------------------------------------------------------

@test "merge: project remoteEnv is added to base remoteEnv" {
  cat > "$TMPDIR/.devcontainer/devcontainer.project.json" <<'JSON'
{
  "name": "myapp",
  "remoteEnv": {
    "MY_API_KEY": "${localEnv:MY_API_KEY}"
  }
}
JSON
  run_merge
  run jq -r '.remoteEnv.GH_CONFIG_DIR' "$OUTPUT_FILE"
  [ "$output" = "/home/ubuntu/.gh-config" ]
  run jq -r '.remoteEnv.MY_API_KEY' "$OUTPUT_FILE"
  [ "$output" = '${localEnv:MY_API_KEY}' ]
}

@test "merge: project remoteEnv overrides base remoteEnv key" {
  cat > "$TMPDIR/.devcontainer/devcontainer.project.json" <<'JSON'
{
  "name": "myapp",
  "remoteEnv": {
    "GIT_AUTHOR_NAME": "Custom Name"
  }
}
JSON
  run_merge
  run jq -r '.remoteEnv.GIT_AUTHOR_NAME' "$OUTPUT_FILE"
  [ "$output" = "Custom Name" ]
}

# --- lifecycle commands --------------------------------------------------------

@test "merge: postCreateCommand defaults to agents-post-create" {
  echo '{"name":"myapp"}' > "$TMPDIR/.devcontainer/devcontainer.project.json"
  run_merge
  run jq -r '.postCreateCommand' "$OUTPUT_FILE"
  [ "$output" = "agents-post-create" ]
}

@test "merge: project postCreateCommand overrides base" {
  echo '{"name":"myapp","postCreateCommand":"agents-post-create && my-setup"}' \
    > "$TMPDIR/.devcontainer/devcontainer.project.json"
  run_merge
  run jq -r '.postCreateCommand' "$OUTPUT_FILE"
  [ "$output" = "agents-post-create && my-setup" ]
}

@test "merge: postStartCommand defaults to agents-post-start" {
  echo '{"name":"myapp"}' > "$TMPDIR/.devcontainer/devcontainer.project.json"
  run_merge
  run jq -r '.postStartCommand' "$OUTPUT_FILE"
  [ "$output" = "agents-post-start" ]
}

# --- extra scalar fields -------------------------------------------------------

@test "merge: extra project fields are added to output" {
  cat > "$TMPDIR/.devcontainer/devcontainer.project.json" <<'JSON'
{
  "name": "myapp",
  "forwardPorts": [3000, 5432]
}
JSON
  run_merge
  run jq -r '.forwardPorts | length' "$OUTPUT_FILE"
  [ "$output" = "2" ]
}

# --- base.json content ---------------------------------------------------------

BASE_JSON_FILE="$BATS_TEST_DIRNAME/../scaffold/devcontainer.base.json"

@test "base.json does not forward GIT_AUTHOR_NAME" {
  run jq -e '.remoteEnv | has("GIT_AUTHOR_NAME")' "$BASE_JSON_FILE"
  [ "$output" = "false" ]
}

@test "base.json does not forward GIT_AUTHOR_EMAIL" {
  run jq -e '.remoteEnv | has("GIT_AUTHOR_EMAIL")' "$BASE_JSON_FILE"
  [ "$output" = "false" ]
}

@test "base.json does not forward GIT_COMMITTER_NAME" {
  run jq -e '.remoteEnv | has("GIT_COMMITTER_NAME")' "$BASE_JSON_FILE"
  [ "$output" = "false" ]
}

@test "base.json does not forward GIT_COMMITTER_EMAIL" {
  run jq -e '.remoteEnv | has("GIT_COMMITTER_EMAIL")' "$BASE_JSON_FILE"
  [ "$output" = "false" ]
}

# --- error handling ------------------------------------------------------------

@test "merge: fails when base.json not found" {
  export BASE_JSON="$TMPDIR/nonexistent.json"
  echo '{"name":"myapp"}' > "$TMPDIR/.devcontainer/devcontainer.project.json"
  run_merge
  [ "$status" -ne 0 ]
}
