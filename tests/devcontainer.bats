#!/usr/bin/env bats
# Assertions on the committed dogfood .devcontainer/devcontainer.json.
# This file is JSONC (has // comments), so assert with grep rather than jq.

DEVCONTAINER_JSON="$BATS_TEST_DIRNAME/../.devcontainer/devcontainer.json"
BASE_JSON="$BATS_TEST_DIRNAME/../scaffold/devcontainer.base.json"

@test "dogfood devcontainer.json sets CLAUDE_CONFIG_DIR to /home/ubuntu/.claude" {
  grep -Eq '"CLAUDE_CONFIG_DIR"[[:space:]]*:[[:space:]]*"/home/ubuntu/\.claude"' "$DEVCONTAINER_JSON"
}

@test "dogfood devcontainer.json initializeCommand creates dotfiles/.hermes" {
  grep -q 'dotfiles/.hermes' "$DEVCONTAINER_JSON"
}

@test "dogfood and consumer configs do not forward git identity" {
  for key in GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL; do
    run grep -q "\"$key\"" "$DEVCONTAINER_JSON"
    [ "$status" -ne 0 ]
    run grep -q "\"$key\"" "$BASE_JSON"
    [ "$status" -ne 0 ]
  done
}

@test "command-local git identity works with identity environment variables unset" {
  repo="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$repo"

  env -u GIT_AUTHOR_NAME -u GIT_AUTHOR_EMAIL \
    -u GIT_COMMITTER_NAME -u GIT_COMMITTER_EMAIL \
    git -C "$repo" init --quiet
  touch "$repo/file"
  git -C "$repo" add file

  run env -u GIT_AUTHOR_NAME -u GIT_AUTHOR_EMAIL \
    -u GIT_COMMITTER_NAME -u GIT_COMMITTER_EMAIL \
    git -C "$repo" -c user.name=Test -c user.email=test@example.com \
    commit --quiet -m test
  [ "$status" -eq 0 ]
}

@test "documentation does not claim host git identity is forwarded" {
  run grep -q 'git identity は `remoteEnv` 経由' "$BATS_TEST_DIRNAME/../.devcontainer/Agents.md"
  [ "$status" -ne 0 ]
  run grep -q 'ホストの git identity を環境変数にセット' "$BATS_TEST_DIRNAME/../README.md"
  [ "$status" -ne 0 ]
}

@test "base image installs bats for in-container smoke tests" {
  run awk '
    /apt-get install -y --no-install-recommends/ { in_install = 1 }
    in_install && /^[[:space:]]*bats([[:space:]\\]|$)/ { found = 1 }
    in_install && /rm -rf \/var\/lib\/apt\/lists/ { in_install = 0 }
    END { exit(found ? 0 : 1) }
  ' "$BATS_TEST_DIRNAME/../.devcontainer/Dockerfile.base"
  [ "$status" -eq 0 ]
}
