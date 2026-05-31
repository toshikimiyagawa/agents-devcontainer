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
  # Mock uv since the YAML has pip packages
  cat > "$MOCK_BIN/uv" << MOCK
#!/bin/bash
echo "\$*" >> "$TMPDIR/uv.log"
MOCK
  chmod +x "$MOCK_BIN/uv"

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
  # Mock uv
  cat > "$MOCK_BIN/uv" << MOCK
#!/bin/bash
echo "\$*" >> "$TMPDIR/uv.log"
MOCK
  chmod +x "$MOCK_BIN/uv"

  cat > "$WORKSPACE/.devcontainer/project-tools.yml" << 'YAML'
pip:
  - awscli==1.32.0
  - ruff
YAML
  run bash "$SCRIPT" "$WORKSPACE"
  [ "$status" -eq 0 ]
  grep -q "tool install awscli==1.32.0" "$TMPDIR/uv.log"
  grep -q "tool install ruff" "$TMPDIR/uv.log"
}

@test "skips pip when section is empty" {
  cat > "$MOCK_BIN/uv" << MOCK
#!/bin/bash
echo "\$*" >> "$TMPDIR/uv.log"
MOCK
  chmod +x "$MOCK_BIN/uv"

  cat > "$WORKSPACE/.devcontainer/project-tools.yml" << 'YAML'
apt:
  - curl
YAML
  run bash "$SCRIPT" "$WORKSPACE"
  [ "$status" -eq 0 ]
  [ ! -f "$TMPDIR/uv.log" ]
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

# --- binary downloads ---------------------------------------------------------

@test "downloads and installs binary (direct download)" {
  cat > "$MOCK_BIN/install" << MOCK
#!/bin/bash
echo "\$*" >> "$TMPDIR/install.log"
MOCK
  chmod +x "$MOCK_BIN/install"

  cat > "$MOCK_BIN/curl" << MOCK
#!/bin/bash
for arg in "\$@"; do
  if [[ "\$prev" == "-o" ]]; then
    echo '#!/bin/bash' > "\$arg"
    echo 'echo mock-binary' >> "\$arg"
    chmod +x "\$arg"
  fi
  prev="\$arg"
done
echo "\$*" >> "$TMPDIR/curl.log"
MOCK
  chmod +x "$MOCK_BIN/curl"

  cat > "$WORKSPACE/.devcontainer/project-tools.yml" << 'YAML'
binary:
  - name: mytool
    url: "https://example.com/mytool-linux"
YAML
  run bash "$SCRIPT" "$WORKSPACE"
  [ "$status" -eq 0 ]
  grep -q "example.com/mytool-linux" "$TMPDIR/curl.log"
}

@test "substitutes ARCH variables in binary URL" {
  cat > "$MOCK_BIN/install" << MOCK
#!/bin/bash
echo "\$*" >> "$TMPDIR/install.log"
MOCK
  chmod +x "$MOCK_BIN/install"

  cat > "$MOCK_BIN/curl" << MOCK
#!/bin/bash
for arg in "\$@"; do
  if [[ "\$prev" == "-o" ]]; then
    echo '#!/bin/bash' > "\$arg"
    chmod +x "\$arg"
  fi
  prev="\$arg"
done
echo "\$*" >> "$TMPDIR/curl.log"
MOCK
  chmod +x "$MOCK_BIN/curl"

  cat > "$WORKSPACE/.devcontainer/project-tools.yml" << 'YAML'
binary:
  - name: mytool
    url: "https://example.com/mytool-${ARCH}-${ARCH_ALT}"
YAML
  run bash "$SCRIPT" "$WORKSPACE"
  [ "$status" -eq 0 ]
  # Verify architecture substitution happened (no literal ${ARCH} in URL)
  ! grep -q '\${ARCH}' "$TMPDIR/curl.log"
}

@test "skips binary when section is empty" {
  cat > "$WORKSPACE/.devcontainer/project-tools.yml" << 'YAML'
apt:
  - curl
YAML
  run bash "$SCRIPT" "$WORKSPACE"
  [ "$status" -eq 0 ]
  [ ! -f "$TMPDIR/curl.log" ]
}

# --- post_install commands ----------------------------------------------------

@test "runs post_install commands from YAML" {
  cat > "$WORKSPACE/.devcontainer/project-tools.yml" << YAML
post_install:
  - name: create marker
    run: |
      touch $TMPDIR/post-install-marker
YAML
  run bash "$SCRIPT" "$WORKSPACE"
  [ "$status" -eq 0 ]
  [ -f "$TMPDIR/post-install-marker" ]
}

@test "runs multiple post_install commands in order" {
  cat > "$WORKSPACE/.devcontainer/project-tools.yml" << YAML
post_install:
  - name: step one
    run: |
      echo "first" > $TMPDIR/order.log
  - name: step two
    run: |
      echo "second" >> $TMPDIR/order.log
YAML
  run bash "$SCRIPT" "$WORKSPACE"
  [ "$status" -eq 0 ]
  run cat "$TMPDIR/order.log"
  [ "${lines[0]}" = "first" ]
  [ "${lines[1]}" = "second" ]
}

@test "skips post_install when section is empty" {
  cat > "$WORKSPACE/.devcontainer/project-tools.yml" << 'YAML'
apt:
  - curl
YAML
  run bash "$SCRIPT" "$WORKSPACE"
  [ "$status" -eq 0 ]
  [[ "$output" != *"running post_install"* ]]
}

# --- post-install.sh ----------------------------------------------------------

@test "runs post-install.sh when present" {
  cat > "$WORKSPACE/.devcontainer/project-tools.yml" << 'YAML'
apt: []
YAML
  cat > "$WORKSPACE/.devcontainer/post-install.sh" << SCRIPT
#!/bin/bash
touch $TMPDIR/post-install-sh-marker
SCRIPT
  chmod +x "$WORKSPACE/.devcontainer/post-install.sh"

  run bash "$SCRIPT" "$WORKSPACE"
  [ "$status" -eq 0 ]
  [ -f "$TMPDIR/post-install-sh-marker" ]
}

@test "skips post-install.sh when not present" {
  cat > "$WORKSPACE/.devcontainer/project-tools.yml" << 'YAML'
apt: []
YAML
  run bash "$SCRIPT" "$WORKSPACE"
  [ "$status" -eq 0 ]
  [[ "$output" != *"running post-install.sh"* ]]
}

@test "skips post-install.sh when not executable" {
  cat > "$WORKSPACE/.devcontainer/project-tools.yml" << 'YAML'
apt: []
YAML
  cat > "$WORKSPACE/.devcontainer/post-install.sh" << SCRIPT
#!/bin/bash
touch $TMPDIR/should-not-exist
SCRIPT
  # Not chmod +x — should be skipped

  run bash "$SCRIPT" "$WORKSPACE"
  [ "$status" -eq 0 ]
  [ ! -f "$TMPDIR/should-not-exist" ]
  [[ "$output" != *"running post-install.sh"* ]]
}
