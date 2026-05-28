#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../.devcontainer/scripts/agents-tools-install"

setup() {
  TMPDIR="$(mktemp -d)"
  export WORKSPACE="$TMPDIR/workspace"
  mkdir -p "$WORKSPACE/.devcontainer"

  # Create mock bin directory
  MOCK_BIN="$TMPDIR/mock-bin"
  mkdir -p "$MOCK_BIN"

  # Mock sudo: just run the command without sudo
  cat > "$MOCK_BIN/sudo" << 'MOCK'
#!/bin/bash
"$@"
MOCK
  chmod +x "$MOCK_BIN/sudo"

  # Mock apt-get: log calls
  cat > "$MOCK_BIN/apt-get" << MOCK
#!/bin/bash
echo "\$*" >> "$TMPDIR/apt-get.log"
MOCK
  chmod +x "$MOCK_BIN/apt-get"

  # Ensure yq is available (skip tests if not installed)
  if ! command -v yq &>/dev/null; then
    skip "yq is not installed"
  fi

  export PATH="$MOCK_BIN:$PATH"
}

teardown() {
  rm -rf "$TMPDIR"
}

# --- no config file -----------------------------------------------------------

@test "exits 0 when project-tools.yml does not exist" {
  run bash "$SCRIPT" "$WORKSPACE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no project-tools.yml found"* ]]
}

# --- apt packages -------------------------------------------------------------

@test "installs apt packages" {
  cat > "$WORKSPACE/.devcontainer/project-tools.yml" << 'YAML'
apt:
  - postgresql-client
  - redis-tools
YAML
  run bash "$SCRIPT" "$WORKSPACE"
  [ "$status" -eq 0 ]
  grep -q "update" "$TMPDIR/apt-get.log"
  grep -q "install -y --no-install-recommends postgresql-client redis-tools" "$TMPDIR/apt-get.log"
}

@test "skips apt when section is empty" {
  # Mock pip since the YAML has pip packages
  cat > "$MOCK_BIN/pip" << MOCK
#!/bin/bash
echo "\$*" >> "$TMPDIR/pip.log"
MOCK
  chmod +x "$MOCK_BIN/pip"

  cat > "$WORKSPACE/.devcontainer/project-tools.yml" << 'YAML'
pip:
  - ruff
YAML
  run bash "$SCRIPT" "$WORKSPACE"
  [ "$status" -eq 0 ]
  [ ! -f "$TMPDIR/apt-get.log" ]
}

# --- pip packages -------------------------------------------------------------

@test "installs pip packages" {
  # Mock pip
  cat > "$MOCK_BIN/pip" << MOCK
#!/bin/bash
echo "\$*" >> "$TMPDIR/pip.log"
MOCK
  chmod +x "$MOCK_BIN/pip"

  cat > "$WORKSPACE/.devcontainer/project-tools.yml" << 'YAML'
pip:
  - awscli==1.32.0
  - ruff
YAML
  run bash "$SCRIPT" "$WORKSPACE"
  [ "$status" -eq 0 ]
  grep -q "install awscli==1.32.0 ruff" "$TMPDIR/pip.log"
}

@test "skips pip when section is empty" {
  cat > "$MOCK_BIN/pip" << MOCK
#!/bin/bash
echo "\$*" >> "$TMPDIR/pip.log"
MOCK
  chmod +x "$MOCK_BIN/pip"

  cat > "$WORKSPACE/.devcontainer/project-tools.yml" << 'YAML'
apt:
  - curl
YAML
  run bash "$SCRIPT" "$WORKSPACE"
  [ "$status" -eq 0 ]
  [ ! -f "$TMPDIR/pip.log" ]
}

# --- npm packages -------------------------------------------------------------

@test "installs npm packages" {
  # Mock npm
  cat > "$MOCK_BIN/npm" << MOCK
#!/bin/bash
echo "\$*" >> "$TMPDIR/npm.log"
MOCK
  chmod +x "$MOCK_BIN/npm"

  cat > "$WORKSPACE/.devcontainer/project-tools.yml" << 'YAML'
npm:
  - prettier
  - eslint@9
YAML
  run bash "$SCRIPT" "$WORKSPACE"
  [ "$status" -eq 0 ]
  grep -q "install -g prettier eslint@9" "$TMPDIR/npm.log"
}

@test "skips npm when section is empty" {
  cat > "$MOCK_BIN/npm" << MOCK
#!/bin/bash
echo "\$*" >> "$TMPDIR/npm.log"
MOCK
  chmod +x "$MOCK_BIN/npm"

  cat > "$WORKSPACE/.devcontainer/project-tools.yml" << 'YAML'
apt:
  - curl
YAML
  run bash "$SCRIPT" "$WORKSPACE"
  [ "$status" -eq 0 ]
  [ ! -f "$TMPDIR/npm.log" ]
}
