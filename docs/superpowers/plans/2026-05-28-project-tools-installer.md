# Project Tools Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable projects using agents-devcontainer to declaratively manage project-specific tools via `.devcontainer/project-tools.yml`, automatically installed on container creation.

**Architecture:** A shell script `agents-tools-install` is baked into the base image. It reads `.devcontainer/project-tools.yml` from the workspace, parses it with `yq`, and installs apt/pip/npm packages and binary downloads. It also runs `post_install` commands from the YAML and `.devcontainer/post-install.sh` if present. The script is called from `agents-post-create` during container setup.

**Tech Stack:** Bash, yq (YAML processor), bats-core (testing)

---

## File Structure

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `.devcontainer/scripts/agents-tools-install` | Main installer: parse YAML, install tools, run post_install |
| Modify | `.devcontainer/scripts/agents-post-create` | Call `agents-tools-install` after dotfile setup |
| Modify | `.devcontainer/Dockerfile.base` | Install `yq`, copy new script |
| Modify | `scaffold.sh` | Generate sample `project-tools.yml` template |
| Create | `tests/tools-install.bats` | Tests for the installer script |
| Modify | `tests/scaffold.bats` | Tests for scaffold generating project-tools.yml |
| Modify | `.github/workflows/test.yml` | Install `yq` in CI, add paths trigger |

## YAML Schema

```yaml
# .devcontainer/project-tools.yml

apt:
  - postgresql-client
  - redis-tools

pip:
  - awscli==1.32.0
  - ruff

npm:
  - prettier
  - eslint@9

binary:
  - name: terraform
    url: "https://releases.hashicorp.com/terraform/1.8.0/terraform_1.8.0_linux_${ARCH}.zip"
  - name: buf
    url: "https://github.com/bufbuild/buf/releases/latest/download/buf-Linux-${ARCH_ALT}"

post_install:
  - name: AWS config
    run: |
      mkdir -p ~/.aws
      cp .devcontainer/config/aws/* ~/.aws/
```

Architecture variables for `url`:
- `${ARCH}` — dpkg architecture (amd64, arm64)
- `${ARCH_ALT}` — alternative naming (x86_64, aarch64)

Binary download logic:
- `.zip` → unzip, find binary by `name`, install to `/usr/local/bin/`
- `.tar.gz` / `.tgz` → extract, find binary by `name`, install to `/usr/local/bin/`
- Otherwise → download directly as binary to `/usr/local/bin/<name>`

---

### Task 1: Add yq to Dockerfile.base

**Files:**
- Modify: `.devcontainer/Dockerfile.base:43-45` (after starship install)

- [ ] **Step 1: Add yq installation to Dockerfile.base**

Add after the starship install block (line 44), before the yazi block:

```dockerfile
# Install yq (YAML processor for project-tools.yml)
RUN curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_$(dpkg --print-architecture)" \
    -o /usr/local/bin/yq && chmod 0755 /usr/local/bin/yq
```

- [ ] **Step 2: Commit**

```bash
git add .devcontainer/Dockerfile.base
git commit -m "feat(base): add yq for YAML parsing in project-tools installer"
```

---

### Task 2: Create agents-tools-install script — parsing and apt

**Files:**
- Create: `.devcontainer/scripts/agents-tools-install`
- Create: `tests/tools-install.bats`

- [ ] **Step 1: Write failing tests for basic behavior and apt parsing**

Create `tests/tools-install.bats`:

```bash
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
  cat > "$WORKSPACE/.devcontainer/project-tools.yml" << 'YAML'
pip:
  - ruff
YAML
  run bash "$SCRIPT" "$WORKSPACE"
  [ "$status" -eq 0 ]
  [ ! -f "$TMPDIR/apt-get.log" ]
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bats tests/tools-install.bats
```

Expected: FAIL — script does not exist yet.

- [ ] **Step 3: Create agents-tools-install with apt support**

Create `.devcontainer/scripts/agents-tools-install`:

```bash
#!/usr/bin/env bash
# Installs project-specific tools declared in .devcontainer/project-tools.yml.
# Called by agents-post-create during container setup.
# Safe to re-run (idempotent).
set -euo pipefail

WORKSPACE="${1:-/workspace}"
TOOLS_FILE="$WORKSPACE/.devcontainer/project-tools.yml"

log() { printf '[agents-tools-install] %s\n' "$*"; }

if [[ ! -f "$TOOLS_FILE" ]]; then
  log "no project-tools.yml found — skipping"
  exit 0
fi

log "reading $TOOLS_FILE"

# --- apt packages -------------------------------------------------------------
apt_packages=$(yq -r '.apt // [] | .[]' "$TOOLS_FILE" 2>/dev/null || true)
if [[ -n "$apt_packages" ]]; then
  log "installing apt packages: $apt_packages"
  # shellcheck disable=SC2086
  sudo apt-get update && sudo apt-get install -y --no-install-recommends $apt_packages
  sudo rm -rf /var/lib/apt/lists/*
  log "apt packages installed"
fi
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bats tests/tools-install.bats
```

Expected: all 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add .devcontainer/scripts/agents-tools-install tests/tools-install.bats
git commit -m "feat(tools-install): add script with apt package support"
```

---

### Task 3: Add pip and npm support to agents-tools-install

**Files:**
- Modify: `.devcontainer/scripts/agents-tools-install`
- Modify: `tests/tools-install.bats`

- [ ] **Step 1: Write failing tests for pip and npm**

Append to `tests/tools-install.bats`:

```bash
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
```

- [ ] **Step 2: Run tests to verify new tests fail**

```bash
bats tests/tools-install.bats
```

Expected: new pip/npm tests FAIL, existing tests still PASS.

- [ ] **Step 3: Add pip and npm support to agents-tools-install**

Append to `.devcontainer/scripts/agents-tools-install`, after the apt section:

```bash
# --- pip packages -------------------------------------------------------------
pip_packages=$(yq -r '.pip // [] | .[]' "$TOOLS_FILE" 2>/dev/null || true)
if [[ -n "$pip_packages" ]]; then
  log "installing pip packages: $pip_packages"
  # shellcheck disable=SC2086
  pip install $pip_packages
  log "pip packages installed"
fi

# --- npm packages -------------------------------------------------------------
npm_packages=$(yq -r '.npm // [] | .[]' "$TOOLS_FILE" 2>/dev/null || true)
if [[ -n "$npm_packages" ]]; then
  log "installing npm packages: $npm_packages"
  # shellcheck disable=SC2086
  sudo npm install -g $npm_packages
  log "npm packages installed"
fi
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bats tests/tools-install.bats
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add .devcontainer/scripts/agents-tools-install tests/tools-install.bats
git commit -m "feat(tools-install): add pip and npm package support"
```

---

### Task 4: Add binary download support

**Files:**
- Modify: `.devcontainer/scripts/agents-tools-install`
- Modify: `tests/tools-install.bats`

- [ ] **Step 1: Write failing tests for binary downloads**

Append to `tests/tools-install.bats`:

```bash
# --- binary downloads ---------------------------------------------------------

@test "downloads and installs binary (direct download)" {
  # Mock curl to create a fake binary
  cat > "$MOCK_BIN/curl" << MOCK
#!/bin/bash
if [[ "\$*" == *"-o"* ]]; then
  # Extract output path from -o flag
  output=\$(echo "\$*" | grep -oP '(?<=-o )\S+')
  echo '#!/bin/bash' > "\$output"
  echo 'echo mock-binary' >> "\$output"
  chmod +x "\$output"
fi
echo "\$*" >> "$TMPDIR/curl.log"
MOCK
  chmod +x "$MOCK_BIN/curl"

  cat > "$MOCK_BIN/install" << MOCK
#!/bin/bash
echo "\$*" >> "$TMPDIR/install.log"
# Actually copy the file for verification
cp "\$2" "\$3" 2>/dev/null || /usr/bin/install "\$@"
MOCK
  chmod +x "$MOCK_BIN/install"

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
  cat > "$MOCK_BIN/curl" << MOCK
#!/bin/bash
if [[ "\$*" == *"-o"* ]]; then
  output=\$(echo "\$*" | grep -oP '(?<=-o )\S+')
  echo '#!/bin/bash' > "\$output"
  chmod +x "\$output"
fi
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
  ! grep -q '${ARCH}' "$TMPDIR/curl.log"
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
```

- [ ] **Step 2: Run tests to verify new tests fail**

```bash
bats tests/tools-install.bats
```

- [ ] **Step 3: Add binary download support to agents-tools-install**

Append to `.devcontainer/scripts/agents-tools-install`, after the npm section:

```bash
# --- binary downloads ---------------------------------------------------------
binary_count=$(yq -r '.binary // [] | length' "$TOOLS_FILE" 2>/dev/null || echo 0)
if [[ "$binary_count" -gt 0 ]]; then
  ARCH=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
  case "$ARCH" in
    amd64) ARCH_ALT=x86_64 ;;
    arm64) ARCH_ALT=aarch64 ;;
    *)     ARCH_ALT="$ARCH" ;;
  esac
  export ARCH ARCH_ALT

  for i in $(seq 0 $((binary_count - 1))); do
    name=$(yq -r ".binary[$i].name" "$TOOLS_FILE")
    url_template=$(yq -r ".binary[$i].url" "$TOOLS_FILE")
    # Substitute architecture variables
    url=$(echo "$url_template" | sed "s/\${ARCH_ALT}/$ARCH_ALT/g; s/\${ARCH}/$ARCH/g")

    log "downloading binary: $name from $url"
    tmpfile=$(mktemp)

    curl -fsSL "$url" -o "$tmpfile"

    if [[ "$url" == *.zip ]]; then
      tmpdir=$(mktemp -d)
      unzip -q "$tmpfile" -d "$tmpdir"
      found=$(find "$tmpdir" -name "$name" -type f | head -1)
      if [[ -n "$found" ]]; then
        sudo install -m 0755 "$found" "/usr/local/bin/$name"
      else
        log "error: binary '$name' not found in zip archive"
      fi
      rm -rf "$tmpdir"
    elif [[ "$url" == *.tar.gz || "$url" == *.tgz ]]; then
      tmpdir=$(mktemp -d)
      tar xzf "$tmpfile" -C "$tmpdir"
      found=$(find "$tmpdir" -name "$name" -type f | head -1)
      if [[ -n "$found" ]]; then
        sudo install -m 0755 "$found" "/usr/local/bin/$name"
      else
        log "error: binary '$name' not found in tar archive"
      fi
      rm -rf "$tmpdir"
    else
      sudo install -m 0755 "$tmpfile" "/usr/local/bin/$name"
    fi

    rm -f "$tmpfile"
    log "installed $name"
  done
fi
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bats tests/tools-install.bats
```

- [ ] **Step 5: Commit**

```bash
git add .devcontainer/scripts/agents-tools-install tests/tools-install.bats
git commit -m "feat(tools-install): add binary download support with arch substitution"
```

---

### Task 5: Add post_install and post-install.sh support

**Files:**
- Modify: `.devcontainer/scripts/agents-tools-install`
- Modify: `tests/tools-install.bats`

- [ ] **Step 1: Write failing tests for post_install and post-install.sh**

Append to `tests/tools-install.bats`:

```bash
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
```

- [ ] **Step 2: Run tests to verify new tests fail**

```bash
bats tests/tools-install.bats
```

- [ ] **Step 3: Add post_install and post-install.sh support**

Append to `.devcontainer/scripts/agents-tools-install`, after the binary section:

```bash
# --- post_install commands ----------------------------------------------------
post_count=$(yq -r '.post_install // [] | length' "$TOOLS_FILE" 2>/dev/null || echo 0)
if [[ "$post_count" -gt 0 ]]; then
  for i in $(seq 0 $((post_count - 1))); do
    name=$(yq -r ".post_install[$i].name" "$TOOLS_FILE")
    run_cmd=$(yq -r ".post_install[$i].run" "$TOOLS_FILE")
    log "running post_install: $name"
    (cd "$WORKSPACE" && eval "$run_cmd")
    log "completed post_install: $name"
  done
fi

# --- post-install.sh ----------------------------------------------------------
POST_INSTALL_SH="$WORKSPACE/.devcontainer/post-install.sh"
if [[ -x "$POST_INSTALL_SH" ]]; then
  log "running post-install.sh"
  (cd "$WORKSPACE" && "$POST_INSTALL_SH")
  log "completed post-install.sh"
fi

log "done"
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bats tests/tools-install.bats
```

- [ ] **Step 5: Commit**

```bash
git add .devcontainer/scripts/agents-tools-install tests/tools-install.bats
git commit -m "feat(tools-install): add post_install commands and post-install.sh support"
```

---

### Task 6: Integrate into agents-post-create and Dockerfile.base

**Files:**
- Modify: `.devcontainer/scripts/agents-post-create:73` (before `log "done"`)
- Modify: `.devcontainer/Dockerfile.base:95-97` (COPY and chmod section)

- [ ] **Step 1: Add agents-tools-install call to agents-post-create**

Add before the final `log "done"` line in agents-post-create (before line 73):

```bash
# --- 5. Project-specific tools ------------------------------------------------
if command -v agents-tools-install &>/dev/null; then
  agents-tools-install /workspace
fi
```

- [ ] **Step 2: Add COPY for agents-tools-install in Dockerfile.base**

In `.devcontainer/Dockerfile.base`, after the existing COPY lines for scripts (line 96), add:

```dockerfile
COPY .devcontainer/scripts/agents-tools-install /usr/local/bin/agents-tools-install
```

And update the chmod line (line 97) to include the new script:

```dockerfile
RUN chmod 0755 /usr/local/bin/agents-post-create /usr/local/bin/agents-post-start /usr/local/bin/agents-tools-install
```

- [ ] **Step 3: Commit**

```bash
git add .devcontainer/scripts/agents-post-create .devcontainer/Dockerfile.base
git commit -m "feat(base): integrate agents-tools-install into container lifecycle"
```

---

### Task 7: Update scaffold.sh to generate project-tools.yml template

**Files:**
- Modify: `scaffold.sh:30-72` (devcontainer setup block)
- Modify: `tests/scaffold.bats`

- [ ] **Step 1: Write failing tests for project-tools.yml generation**

Append to `tests/scaffold.bats`:

```bash
# --- project-tools.yml --------------------------------------------------------

@test "generates project-tools.yml" {
  bash "$SCAFFOLD" "$TARGET"
  [ -f "$TARGET/.devcontainer/project-tools.yml" ]
}

@test "project-tools.yml is valid YAML (has comment header)" {
  bash "$SCAFFOLD" "$TARGET"
  head -1 "$TARGET/.devcontainer/project-tools.yml" | grep -q "^#"
}

@test "skips project-tools.yml when .devcontainer already exists" {
  mkdir -p "$TARGET/.devcontainer"
  init_git_target
  run env AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  [ ! -f "$TARGET/.devcontainer/project-tools.yml" ]
}
```

- [ ] **Step 2: Run tests to verify new tests fail**

```bash
bats tests/scaffold.bats
```

- [ ] **Step 3: Add project-tools.yml generation to scaffold.sh**

In `scaffold.sh`, inside the devcontainer setup block (after the `.gitignore` generation, before `echo "Scaffolded $DC"`), add:

```bash
  cat > "$DC/project-tools.yml" << 'TOOLS'
# Project-specific tools — installed automatically on devcontainer creation.
# Uncomment or add entries as needed. Versions are optional (omit for latest).
#
# apt:
#   - postgresql-client
#   - redis-tools
#
# pip:
#   - awscli==1.32.0
#   - ruff
#
# npm:
#   - prettier
#   - eslint@9
#
# binary:
#   - name: terraform
#     url: "https://releases.hashicorp.com/terraform/1.8.0/terraform_1.8.0_linux_${ARCH}.zip"
#   # Available variables: ${ARCH} (amd64|arm64), ${ARCH_ALT} (x86_64|aarch64)
#
# post_install:
#   - name: setup config
#     run: |
#       mkdir -p ~/.config/mytool
#       cp .devcontainer/config/mytool.toml ~/.config/mytool/
#
# For complex setup, you can also create .devcontainer/post-install.sh (must be executable).
TOOLS
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bats tests/scaffold.bats
```

- [ ] **Step 5: Commit**

```bash
git add scaffold.sh tests/scaffold.bats
git commit -m "feat(scaffold): generate project-tools.yml template"
```

---

### Task 8: Update CI workflow and final cleanup

**Files:**
- Modify: `.github/workflows/test.yml`

- [ ] **Step 1: Update test.yml to install yq and add paths trigger**

Update `.github/workflows/test.yml`:

```yaml
name: test

on:
  push:
    branches: [main]
    paths:
      - 'scaffold.sh'
      - 'tests/**'
      - '.devcontainer/scripts/**'
      - '.github/workflows/test.yml'
  pull_request:
    paths:
      - 'scaffold.sh'
      - 'tests/**'
      - '.devcontainer/scripts/**'
      - '.github/workflows/test.yml'

jobs:
  bats:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install bats-core
        uses: bats-core/bats-action@3.0.0

      - name: Install yq
        run: |
          sudo curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
            -o /usr/local/bin/yq && sudo chmod +x /usr/local/bin/yq

      - name: Run tests
        run: bats tests/
```

- [ ] **Step 2: Run all tests locally to verify everything passes**

```bash
bats tests/
```

Expected: all tests in both `scaffold.bats` and `tools-install.bats` PASS.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/test.yml
git commit -m "ci: add yq install and .devcontainer/scripts paths trigger"
```
