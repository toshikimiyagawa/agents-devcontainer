#!/usr/bin/env bats

FEATURE_DIR="$BATS_TEST_DIRNAME/../features/agents"
FEATURE_JSON="$FEATURE_DIR/devcontainer-feature.json"
INSTALL_SH="$FEATURE_DIR/install.sh"

@test "feature metadata is valid JSON with required identity" {
  jq empty "$FEATURE_JSON"
  [ "$(jq -r '.id' "$FEATURE_JSON")" = "agents" ]
  [ "$(jq -r '.version' "$FEATURE_JSON")" = "1.0.0" ]
  [ "$(jq -r '.name' "$FEATURE_JSON")" = "Agents Devcontainer Tooling" ]
}

@test "feature metadata declares lifecycle commands" {
  [ "$(jq -r '.postCreateCommand' "$FEATURE_JSON")" = "agents-feature-post-create" ]
  [ "$(jq -r '.postStartCommand' "$FEATURE_JSON")" = "agents-feature-post-start" ]
}

@test "feature metadata keeps agent state outside target repository" {
  [ "$(jq -r '.containerEnv.AGENTS_STATE_HOME' "$FEATURE_JSON")" = "/usr/local/share/agents-devcontainer/state" ]
  [ "$(jq -r '.containerEnv.GH_CONFIG_DIR' "$FEATURE_JSON")" = "/usr/local/share/agents-devcontainer/state/gh" ]
  run jq -e '.mounts // [] | any(test("target=/usr/local/share/agents-devcontainer/state"))' "$FEATURE_JSON"
  [ "$status" -eq 0 ]
}

@test "feature install script declares Debian Ubuntu support boundary" {
  [ -x "$INSTALL_SH" ]
  grep -F 'ID_LIKE' "$INSTALL_SH" >/dev/null
  grep -F 'debian' "$INSTALL_SH" >/dev/null
  grep -F 'Ubuntu' "$INSTALL_SH" >/dev/null
  grep -F 'Unsupported OS' "$INSTALL_SH" >/dev/null
}

@test "feature install script installs runtime entrypoints" {
  grep -F 'agents-feature-post-create' "$INSTALL_SH" >/dev/null
  grep -F 'agents-feature-post-start' "$INSTALL_SH" >/dev/null
  grep -F 'install -m 0755' "$INSTALL_SH" >/dev/null
}

