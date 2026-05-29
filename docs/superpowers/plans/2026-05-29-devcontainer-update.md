# Devcontainer Update Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** agents-devcontainer の設定変更を消費プロジェクトが `git submodule update` + `merge.sh` で安全に取り込めるようにする。

**Architecture:** `scaffold/devcontainer.base.json`（ベース設定テンプレート）と `.devcontainer/devcontainer.project.json`（プロジェクト差分）を `merge.sh` が jq でマージして `devcontainer.json` を生成する。`scaffold.sh` は agents-devcontainer を git submodule として追加し、セットアップ時に `merge.sh` を呼び出す。`sdd-update.sh` は SDD 統合ファイルのうち再生成可能なもの（`.claude/agents/`, `sdd-check.yml`）を上書き更新する。

**Tech Stack:** Bash, jq (JSON merge), bats-core (tests), git submodule

---

## File Map

| ファイル | アクション | 説明 |
|---|---|---|
| `scaffold/devcontainer.base.json` | 新規作成 | ベース設定テンプレート（valid JSON） |
| `scaffold/devcontainer.project.json.example` | 新規作成 | プロジェクト用サンプル |
| `scaffold/merge.sh` | 新規作成 | base + project → devcontainer.json を生成 |
| `scaffold/sdd-update.sh` | 新規作成 | SDD 統合ファイル更新スクリプト |
| `scaffold.sh` | 変更 | agents-devcontainer submodule 追加、project.json 生成に変更 |
| `tests/merge.bats` | 新規作成 | merge.sh のテスト |
| `tests/sdd-update.bats` | 新規作成 | sdd-update.sh のテスト |
| `tests/scaffold.bats` | 変更 | ADC fixture 追加、新挙動に合わせてテスト更新 |
| `specs/devcontainer-update/spec.md` | 新規作成 | SDD spec gate 用 |
| `.sdd/state.json` | 変更 | feature/tier/phase を記録 |

---

## Task 1: SDD アーティファクト作成

**Files:**
- Create: `specs/devcontainer-update/spec.md`
- Modify: `.sdd/state.json`

- [ ] **Step 1: `.sdd/state.json` を更新**

```json
{
  "feature": "devcontainer-update",
  "tier": 2,
  "phase": "implement"
}
```

- [ ] **Step 2: `specs/devcontainer-update/spec.md` を作成**

```markdown
# Spec: devcontainer-update

## Intent

agents-devcontainer の設定変更（devcontainer.json テンプレート・SDD統合ファイル）を
消費プロジェクトが git submodule update で安全に取り込めるようにする。

## Acceptance Criteria

1. 消費プロジェクトで `git submodule update --remote vendor/agents-devcontainer && vendor/agents-devcontainer/scaffold/merge.sh` を実行すると `devcontainer.json` が最新の base に基づいて再生成される
2. `devcontainer.project.json` の内容がマージルール通りに反映される（name, image/build, mounts 結合, remoteEnv マージ, postCreateCommand 上書き）
3. `sdd-update.sh` が `.claude/agents/` と `sdd-check.yml` のみを更新し、`CLAUDE.md` 等の保護対象は変更しない
4. `scaffold.sh` で新規プロジェクトをセットアップすると `devcontainer.project.json` が生成され、`merge.sh` で `devcontainer.json` が生成される
5. `bats tests/` が全て通る
```

- [ ] **Step 3: コミット**

```bash
git add .sdd/state.json specs/devcontainer-update/spec.md
git commit -m "feat(devcontainer-update): initialize SDD artifacts"
```

---

## Task 2: ベース設定ファイルの追加

**Files:**
- Create: `scaffold/devcontainer.base.json`
- Create: `scaffold/devcontainer.project.json.example`

- [ ] **Step 1: `scaffold/` ディレクトリを作成して `devcontainer.base.json` を追加**

```bash
mkdir -p scaffold
```

`scaffold/devcontainer.base.json`:
```json
{
  "image": "ghcr.io/toshikimiyagawa/agents-devcontainer:latest",
  "workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind,consistency=cached",
  "workspaceFolder": "/workspace",
  "initializeCommand": "mkdir -p \"${localWorkspaceFolder}/.devcontainer/dotfiles/.claude\" \"${localWorkspaceFolder}/.devcontainer/dotfiles/.gemini\"",
  "mounts": [
    "source=devcontainer-gh-${devcontainerId},target=/home/ubuntu/.gh-config,type=volume"
  ],
  "remoteEnv": {
    "GH_CONFIG_DIR": "/home/ubuntu/.gh-config",
    "GIT_AUTHOR_NAME": "${localEnv:GIT_AUTHOR_NAME}",
    "GIT_AUTHOR_EMAIL": "${localEnv:GIT_AUTHOR_EMAIL}",
    "GIT_COMMITTER_NAME": "${localEnv:GIT_AUTHOR_NAME}",
    "GIT_COMMITTER_EMAIL": "${localEnv:GIT_AUTHOR_EMAIL}"
  },
  "containerUser": "ubuntu",
  "remoteUser": "ubuntu",
  "postCreateCommand": "agents-post-create",
  "postStartCommand": "agents-post-start"
}
```

- [ ] **Step 2: `scaffold/devcontainer.project.json.example` を追加**

```json
{
  "name": "my-project",

  "mounts": [],

  "remoteEnv": {}
}
```

- [ ] **Step 3: base.json が valid JSON であることを確認**

```bash
jq empty scaffold/devcontainer.base.json
```

Expected: 終了コード 0、出力なし

- [ ] **Step 4: コミット**

```bash
git add scaffold/devcontainer.base.json scaffold/devcontainer.project.json.example
git commit -m "feat(devcontainer-update): add base config template and example"
```

---

## Task 3: merge.sh のテストと実装

**Files:**
- Create: `tests/merge.bats`
- Create: `scaffold/merge.sh`

### Step 1: テストを書く（RED）

- [ ] **`tests/merge.bats` を作成（失敗する状態で）**

```bash
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

# --- error handling ------------------------------------------------------------

@test "merge: fails when base.json not found" {
  export BASE_JSON="$TMPDIR/nonexistent.json"
  echo '{"name":"myapp"}' > "$TMPDIR/.devcontainer/devcontainer.project.json"
  run_merge
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: テストが失敗することを確認**

```bash
bats tests/merge.bats
```

Expected: `No such file or directory` または全テスト失敗

### Step 3: merge.sh を実装する（GREEN）

- [ ] **`scaffold/merge.sh` を作成**

```bash
#!/usr/bin/env bash
set -euo pipefail

PROJECT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
BASE="${BASE_JSON:-$PROJECT/vendor/agents-devcontainer/scaffold/devcontainer.base.json}"
PROJ_JSON_PATH="${PROJ_JSON_FILE:-$PROJECT/.devcontainer/devcontainer.project.json}"
OUTPUT="${OUTPUT_FILE:-$PROJECT/.devcontainer/devcontainer.json}"

log() { printf '[merge.sh] %s\n' "$*"; }

if [[ ! -f "$BASE" ]]; then
  log "error: base config not found: $BASE" >&2
  exit 1
fi

PROJ_CONTENT='{}'
if [[ -f "$PROJ_JSON_PATH" ]]; then
  PROJ_CONTENT=$(cat "$PROJ_JSON_PATH")
fi

NAME=$(printf '%s' "$PROJ_CONTENT" | jq -r '.name // empty' 2>/dev/null || true)
[[ -z "$NAME" ]] && NAME=$(basename "$PROJECT")

jq -n \
  --argjson base "$(cat "$BASE")" \
  --argjson proj "$PROJ_CONTENT" \
  --arg name "$NAME" \
  '
    ($base) as $b |
    ($proj) as $p |

    $b
    | .name = $name
    | (if ($p | has("build")) then del(.image) | .build = $p.build
       elif ($p | has("image")) then .image = $p.image
       else . end)
    | .mounts = (($b.mounts // []) + ($p.mounts // []))
    | .remoteEnv = (($b.remoteEnv // {}) + ($p.remoteEnv // {}))
    | if ($p | has("postCreateCommand")) then .postCreateCommand = $p.postCreateCommand else . end
    | if ($p | has("postStartCommand")) then .postStartCommand = $p.postStartCommand else . end
    | . + ($p | del(.name, .image, .build, .mounts, .remoteEnv, .postCreateCommand, .postStartCommand))
  ' > "$OUTPUT"

log "generated $OUTPUT"
```

- [ ] **実行権限を付与**

```bash
chmod +x scaffold/merge.sh
```

- [ ] **Step 4: テストを実行して全件パスを確認**

```bash
bats tests/merge.bats
```

Expected: 全テスト PASS

- [ ] **Step 5: コミット**

```bash
git add scaffold/merge.sh tests/merge.bats
git commit -m "feat(devcontainer-update): add merge.sh with tests"
```

---

## Task 4: sdd-update.sh のテストと実装

**Files:**
- Create: `tests/sdd-update.bats`
- Create: `scaffold/sdd-update.sh`

### Step 1: テストを書く（RED）

- [ ] **`tests/sdd-update.bats` を作成**

```bash
#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../scaffold/sdd-update.sh"

setup() {
  TMPDIR="$(mktemp -d)"
  mkdir -p "$TMPDIR/vendor/ai-sdd-guide/integration/agents"
  mkdir -p "$TMPDIR/vendor/ai-sdd-guide/integration/ci"

  # Seed integration sources
  echo "# sdd-reviewer v2" > "$TMPDIR/vendor/ai-sdd-guide/integration/agents/sdd-reviewer.md"
  echo "name: sdd-check-v2" > "$TMPDIR/vendor/ai-sdd-guide/integration/ci/sdd-check.yml"
  echo "# CLAUDE.md upstream" > "$TMPDIR/vendor/ai-sdd-guide/integration/CLAUDE.md.example"
  echo "# AGENTS.md upstream" > "$TMPDIR/vendor/ai-sdd-guide/integration/AGENTS.md.example"
  echo '{"upstream":true}' > "$TMPDIR/vendor/ai-sdd-guide/integration/settings.json.example"
}

teardown() {
  rm -rf "$TMPDIR"
}

# --- managed files (overwrite) ------------------------------------------------

@test "sdd-update: .claude/agents/ is updated from integration" {
  mkdir -p "$TMPDIR/.claude/agents"
  echo "# old" > "$TMPDIR/.claude/agents/sdd-reviewer.md"

  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  run cat "$TMPDIR/.claude/agents/sdd-reviewer.md"
  [ "$output" = "# sdd-reviewer v2" ]
}

@test "sdd-update: .claude/agents/ is created when absent" {
  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  [ -f "$TMPDIR/.claude/agents/sdd-reviewer.md" ]
}

@test "sdd-update: sdd-check.yml is updated" {
  mkdir -p "$TMPDIR/.github/workflows"
  echo "old-content" > "$TMPDIR/.github/workflows/sdd-check.yml"

  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  run cat "$TMPDIR/.github/workflows/sdd-check.yml"
  [ "$output" = "name: sdd-check-v2" ]
}

@test "sdd-update: .github/workflows/ is created when absent" {
  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  [ -f "$TMPDIR/.github/workflows/sdd-check.yml" ]
}

# --- protected files (no overwrite) -------------------------------------------

@test "sdd-update: CLAUDE.md is not overwritten when it exists" {
  echo "# my custom CLAUDE.md" > "$TMPDIR/CLAUDE.md"

  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  run cat "$TMPDIR/CLAUDE.md"
  [ "$output" = "# my custom CLAUDE.md" ]
}

@test "sdd-update: AGENTS.md is not overwritten when it exists" {
  echo "# my custom AGENTS.md" > "$TMPDIR/AGENTS.md"

  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  run cat "$TMPDIR/AGENTS.md"
  [ "$output" = "# my custom AGENTS.md" ]
}

@test "sdd-update: .claude/settings.json is not overwritten when it exists" {
  mkdir -p "$TMPDIR/.claude"
  echo '{"custom":true}' > "$TMPDIR/.claude/settings.json"

  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  run cat "$TMPDIR/.claude/settings.json"
  [ "$output" = '{"custom":true}' ]
}

@test "sdd-update: CLAUDE.md is created when absent" {
  run bash "$SCRIPT" "$TMPDIR"
  [ "$status" -eq 0 ]
  [ -f "$TMPDIR/CLAUDE.md" ]
  run cat "$TMPDIR/CLAUDE.md"
  [ "$output" = "# CLAUDE.md upstream" ]
}

# --- error handling -----------------------------------------------------------

@test "sdd-update: fails when vendor/ai-sdd-guide/integration not found" {
  run bash "$SCRIPT" "$TMPDIR/nonexistent"
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: テストが失敗することを確認**

```bash
bats tests/sdd-update.bats
```

Expected: 全テスト失敗（スクリプト未作成）

### Step 3: sdd-update.sh を実装する（GREEN）

- [ ] **`scaffold/sdd-update.sh` を作成**

```bash
#!/usr/bin/env bash
set -euo pipefail

PROJECT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
INTEGRATION="$PROJECT/vendor/ai-sdd-guide/integration"

log() { printf '[sdd-update.sh] %s\n' "$*"; }

if [[ ! -d "$INTEGRATION" ]]; then
  log "error: vendor/ai-sdd-guide/integration not found. Run scaffold.sh first." >&2
  exit 1
fi

# --- Regenerate (overwrite) managed files ---

if [[ -d "$INTEGRATION/agents" ]]; then
  mkdir -p "$PROJECT/.claude"
  rm -rf "$PROJECT/.claude/agents"
  cp -r "$INTEGRATION/agents" "$PROJECT/.claude/agents"
  log "updated .claude/agents/"
fi

if [[ -f "$INTEGRATION/ci/sdd-check.yml" ]]; then
  mkdir -p "$PROJECT/.github/workflows"
  cp "$INTEGRATION/ci/sdd-check.yml" "$PROJECT/.github/workflows/sdd-check.yml"
  log "updated .github/workflows/sdd-check.yml"
fi

# --- Protected files: create if absent, show diff if changed ---

protected=(
  "CLAUDE.md:$INTEGRATION/CLAUDE.md.example"
  "AGENTS.md:$INTEGRATION/AGENTS.md.example"
  ".claude/settings.json:$INTEGRATION/settings.json.example"
)

for entry in "${protected[@]}"; do
  rel="${entry%%:*}"
  src="${entry#*:}"
  dest="$PROJECT/$rel"

  if [[ ! -f "$src" ]]; then
    continue
  fi

  if [[ ! -f "$dest" ]]; then
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    log "created $rel (was absent)"
  elif ! diff -q "$src" "$dest" >/dev/null 2>&1; then
    log "diff (protected — review manually): $rel"
    diff "$dest" "$src" || true
  fi
done

log "done"
```

- [ ] **実行権限を付与**

```bash
chmod +x scaffold/sdd-update.sh
```

- [ ] **Step 4: テストを実行して全件パスを確認**

```bash
bats tests/sdd-update.bats
```

Expected: 全テスト PASS

- [ ] **Step 5: コミット**

```bash
git add scaffold/sdd-update.sh tests/sdd-update.bats
git commit -m "feat(devcontainer-update): add sdd-update.sh with tests"
```

---

## Task 5: scaffold.sh の改修と scaffold.bats の更新

**Files:**
- Modify: `scaffold.sh`
- Modify: `tests/scaffold.bats`

### 改修内容の概要

- `AGENTS_DEVCONTAINER_URL` 変数を追加（テスト用に上書き可能にする）
- git リポジトリの場合に `vendor/agents-devcontainer` submodule を追加する
- devcontainer セクション: `devcontainer.json` の直接生成から `devcontainer.project.json` の生成に変更
- git リポジトリかつ submodule が存在する場合に `merge.sh` を呼び出して `devcontainer.json` を生成
- git なしの場合はフォールバックとして `devcontainer.json` を静的生成

- [ ] **Step 1: scaffold.sh を以下の内容に置き換える**

```bash
#!/usr/bin/env bash
# Scaffold a minimal .devcontainer/ that consumes the agents-devcontainer base image,
# and optionally set up ai-sdd-guide (Spec-Driven Development) via git submodule.
#
# Usage:
#   bash scaffold.sh [TARGET_DIR]       # defaults to current directory
#
# To pin a specific version:
#   AGENTS_DEVCONTAINER_TAG=v0.1.0 bash scaffold.sh ~/code/myproject
#
# To skip SDD setup:
#   AGENTS_DEVCONTAINER_SDD=0 bash scaffold.sh ~/code/myproject
#
# Remote usage:
#   curl -fsSL https://raw.githubusercontent.com/toshikimiyagawa/agents-devcontainer/main/scaffold.sh | bash
set -euo pipefail

TARGET="${1:-$PWD}"
TAG="${AGENTS_DEVCONTAINER_TAG:-latest}"
DC="$TARGET/.devcontainer"
SDD="${AGENTS_DEVCONTAINER_SDD:-1}"
SDD_URL="${AGENTS_SDD_GUIDE_URL:-https://github.com/toshikimiyagawa/ai-sdd-guide.git}"
SDD_DIR="$TARGET/vendor/ai-sdd-guide"
ADC_URL="${AGENTS_DEVCONTAINER_URL:-https://github.com/toshikimiyagawa/agents-devcontainer.git}"
ADC_DIR="$TARGET/vendor/agents-devcontainer"

# --- agents-devcontainer submodule (git only) ---------------------------------

if git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [[ -e "$ADC_DIR" ]]; then
    echo "SKIP: $ADC_DIR already exists. Skipping agents-devcontainer submodule add." >&2
  else
    git -C "$TARGET" submodule add "$ADC_URL" vendor/agents-devcontainer
    echo "Added agents-devcontainer submodule at vendor/agents-devcontainer"
  fi
fi

# --- devcontainer setup -------------------------------------------------------

if [[ -e "$DC" ]]; then
  echo "SKIP: $DC already exists. Skipping devcontainer setup." >&2
else
  mkdir -p "$DC/dotfiles/.claude" "$DC/dotfiles/.gemini"

  # Generate devcontainer.project.json (project-specific overrides)
  if [[ "$TAG" != "latest" ]]; then
    cat > "$DC/devcontainer.project.json" <<JSON
{
  "name": "$(basename "$TARGET")",
  "image": "ghcr.io/toshikimiyagawa/agents-devcontainer:${TAG}"
}
JSON
  else
    cat > "$DC/devcontainer.project.json" <<JSON
{
  "name": "$(basename "$TARGET")"
}
JSON
  fi

  # Generate devcontainer.json: via merge.sh if submodule is present, else static fallback
  if [[ -x "$ADC_DIR/scaffold/merge.sh" ]]; then
    "$ADC_DIR/scaffold/merge.sh" "$TARGET"
  else
    cat > "$DC/devcontainer.json" <<JSON
{
  "name": "$(basename "$TARGET")",

  "image": "ghcr.io/toshikimiyagawa/agents-devcontainer:${TAG}",

  "workspaceMount": "source=\${localWorkspaceFolder},target=/workspace,type=bind,consistency=cached",
  "workspaceFolder": "/workspace",

  "initializeCommand": "mkdir -p \"\${localWorkspaceFolder}/.devcontainer/dotfiles/.claude\" \"\${localWorkspaceFolder}/.devcontainer/dotfiles/.gemini\"",

  "mounts": [
    "source=devcontainer-gh-\${devcontainerId},target=/home/ubuntu/.gh-config,type=volume"
  ],

  "remoteEnv": {
    "GH_CONFIG_DIR": "/home/ubuntu/.gh-config",
    "GIT_AUTHOR_NAME":     "\${localEnv:GIT_AUTHOR_NAME}",
    "GIT_AUTHOR_EMAIL":    "\${localEnv:GIT_AUTHOR_EMAIL}",
    "GIT_COMMITTER_NAME":  "\${localEnv:GIT_AUTHOR_NAME}",
    "GIT_COMMITTER_EMAIL": "\${localEnv:GIT_AUTHOR_EMAIL}"
  },

  "containerUser": "ubuntu",
  "remoteUser":    "ubuntu",

  "postCreateCommand": "agents-post-create",
  "postStartCommand":  "agents-post-start"
}
JSON
  fi

  cat > "$DC/.gitignore" <<'GITIGNORE'
# Per-project agent state — keep local, never commit.
dotfiles/.claude/
dotfiles/.gemini/
dotfiles/.config/gh/
dotfiles/.ssh/
dotfiles/.zsh_history
GITIGNORE

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

  echo "Scaffolded $DC"
fi

# --- SDD (ai-sdd-guide) setup -------------------------------------------------

if [[ "$SDD" == "0" ]]; then
  echo "SKIP: SDD setup disabled (AGENTS_DEVCONTAINER_SDD=0)." >&2
elif ! git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "SKIP: $TARGET is not a git repository. SDD setup requires git." >&2
  echo "      Run 'git init' first, then re-run this script to set up SDD." >&2
else
  # Submodule
  if [[ -e "$SDD_DIR" ]]; then
    echo "SKIP: $SDD_DIR already exists. Skipping submodule add." >&2
  else
    git -C "$TARGET" submodule add "$SDD_URL" vendor/ai-sdd-guide
    echo "Added ai-sdd-guide submodule at vendor/ai-sdd-guide"
  fi

  # Integration files (copy only if not already present)
  INTEGRATION="$SDD_DIR/integration"
  if [[ -d "$INTEGRATION" ]]; then
    if [[ ! -f "$TARGET/CLAUDE.md" ]] && [[ -f "$INTEGRATION/CLAUDE.md.example" ]]; then
      cp "$INTEGRATION/CLAUDE.md.example" "$TARGET/CLAUDE.md"
      echo "Copied CLAUDE.md"
    fi

    if [[ ! -f "$TARGET/AGENTS.md" ]] && [[ -f "$INTEGRATION/AGENTS.md.example" ]]; then
      cp "$INTEGRATION/AGENTS.md.example" "$TARGET/AGENTS.md"
      echo "Copied AGENTS.md"
    fi

    if [[ ! -f "$TARGET/.claude/settings.json" ]] && [[ -f "$INTEGRATION/settings.json.example" ]]; then
      mkdir -p "$TARGET/.claude"
      cp "$INTEGRATION/settings.json.example" "$TARGET/.claude/settings.json"
      echo "Copied .claude/settings.json"
    fi

    if [[ ! -d "$TARGET/.claude/agents" ]] && [[ -d "$INTEGRATION/agents" ]]; then
      mkdir -p "$TARGET/.claude"
      cp -r "$INTEGRATION/agents" "$TARGET/.claude/agents"
      echo "Copied .claude/agents/"
    fi

    if [[ ! -f "$TARGET/.github/workflows/sdd-check.yml" ]] && [[ -f "$INTEGRATION/ci/sdd-check.yml" ]]; then
      mkdir -p "$TARGET/.github/workflows"
      cp "$INTEGRATION/ci/sdd-check.yml" "$TARGET/.github/workflows/sdd-check.yml"
      echo "Copied .github/workflows/sdd-check.yml"
    fi
  fi

  echo ""
  echo "SDD (ai-sdd-guide) setup complete."
fi

echo ""
echo "Next steps:"
echo "  1. Open $TARGET in VS Code -> 'Dev Containers: Reopen in Container'"
echo "     OR: devcontainer up --workspace-folder $TARGET"
echo "  2. Inside the container, run: gh auth login -p https -h github.com -s repo,read:org -w"
echo "     (token persists across rebuilds via the named volume)"
echo ""
echo "To update devcontainer config from agents-devcontainer:"
echo "  git submodule update --remote vendor/agents-devcontainer"
echo "  vendor/agents-devcontainer/scaffold/merge.sh"
echo ""
echo "To override dotfiles, drop files into $DC/dotfiles/ (e.g., .zshrc, .tmux.conf, .config/)."
echo "To extend .zshrc rather than replace it: source /opt/agents/dotfiles/.zshrc at the top."
echo "To add extra tools: replace 'image' with 'build' and add a Dockerfile FROM the base image."
```

- [ ] **Step 2: `tests/scaffold.bats` を更新する**

以下の変更を加える：
1. `setup()` に agents-devcontainer ベアリポジトリフィクスチャを追加
2. git を使うテストに `AGENTS_DEVCONTAINER_URL="$ADC_BARE"` を追加
3. "generates devcontainer.json" テストを更新（project.json も確認）
4. "devcontainer.json is valid JSON"、"image tag" 等のテストに `init_git_target` を追加
5. 新テスト "adds agents-devcontainer submodule" を追加
6. 新テスト "generates devcontainer.project.json" を追加

```bash
#!/usr/bin/env bats

SCAFFOLD="$BATS_TEST_DIRNAME/../scaffold.sh"

setup() {
  TMPDIR="$(mktemp -d)"
  TARGET="$TMPDIR/myproject"
  mkdir -p "$TARGET"

  export GIT_CONFIG_COUNT=1
  export GIT_CONFIG_KEY_0=protocol.file.allow
  export GIT_CONFIG_VALUE_0=always

  # --- ai-sdd-guide fixture ---
  SDD_BARE="$TMPDIR/ai-sdd-guide.git"
  git init --bare "$SDD_BARE" >/dev/null 2>&1

  SDD_WORK="$TMPDIR/sdd-work"
  git clone "$SDD_BARE" "$SDD_WORK" >/dev/null 2>&1
  mkdir -p "$SDD_WORK/integration/agents" "$SDD_WORK/integration/ci"
  echo "# CLAUDE.md example" > "$SDD_WORK/integration/CLAUDE.md.example"
  echo "# AGENTS.md example" > "$SDD_WORK/integration/AGENTS.md.example"
  echo '{"hooks":{}}' > "$SDD_WORK/integration/settings.json.example"
  echo "# sdd-reviewer" > "$SDD_WORK/integration/agents/sdd-reviewer.md"
  echo "name: sdd-check" > "$SDD_WORK/integration/ci/sdd-check.yml"
  (cd "$SDD_WORK" && git add -A && git -c user.name=test -c user.email=test@test.com commit -m "init" >/dev/null 2>&1)
  (cd "$SDD_WORK" && git push >/dev/null 2>&1)

  # --- agents-devcontainer fixture ---
  ADC_BARE="$TMPDIR/agents-devcontainer.git"
  git init --bare "$ADC_BARE" >/dev/null 2>&1

  ADC_WORK="$TMPDIR/adc-work"
  git clone "$ADC_BARE" "$ADC_WORK" >/dev/null 2>&1
  mkdir -p "$ADC_WORK/scaffold"
  cp "$BATS_TEST_DIRNAME/../scaffold/devcontainer.base.json" "$ADC_WORK/scaffold/"
  cp "$BATS_TEST_DIRNAME/../scaffold/merge.sh"               "$ADC_WORK/scaffold/"
  cp "$BATS_TEST_DIRNAME/../scaffold/sdd-update.sh"          "$ADC_WORK/scaffold/"
  (cd "$ADC_WORK" && git add -A && git -c user.name=test -c user.email=test@test.com commit -m "init" >/dev/null 2>&1)
  (cd "$ADC_WORK" && git push >/dev/null 2>&1)
}

teardown() {
  rm -rf "$TMPDIR"
}

init_git_target() {
  (cd "$TARGET" && git init >/dev/null 2>&1 && git -c user.name=test -c user.email=test@test.com commit --allow-empty -m "init" >/dev/null 2>&1)
}

# --- devcontainer file generation ----------------------------------------------

@test "generates devcontainer.json" {
  init_git_target
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  [ -f "$TARGET/.devcontainer/devcontainer.json" ]
}

@test "generates devcontainer.project.json" {
  init_git_target
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  [ -f "$TARGET/.devcontainer/devcontainer.project.json" ]
}

@test "generates .gitignore" {
  bash "$SCAFFOLD" "$TARGET"
  [ -f "$TARGET/.devcontainer/.gitignore" ]
}

@test "creates dotfiles/.claude directory" {
  bash "$SCAFFOLD" "$TARGET"
  [ -d "$TARGET/.devcontainer/dotfiles/.claude" ]
}

@test "creates dotfiles/.gemini directory" {
  bash "$SCAFFOLD" "$TARGET"
  [ -d "$TARGET/.devcontainer/dotfiles/.gemini" ]
}

# --- devcontainer.json content -------------------------------------------------

@test "devcontainer.json is valid JSON" {
  init_git_target
  env AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  run jq empty "$TARGET/.devcontainer/devcontainer.json"
  [ "$status" -eq 0 ]
}

@test "image tag defaults to latest" {
  init_git_target
  env AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  run jq -r '.image' "$TARGET/.devcontainer/devcontainer.json"
  [ "$output" = "ghcr.io/toshikimiyagawa/agents-devcontainer:latest" ]
}

@test "AGENTS_DEVCONTAINER_TAG overrides image tag" {
  init_git_target
  env AGENTS_DEVCONTAINER_TAG=v1.2.3 AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  run jq -r '.image' "$TARGET/.devcontainer/devcontainer.json"
  [ "$output" = "ghcr.io/toshikimiyagawa/agents-devcontainer:v1.2.3" ]
}

@test "name is set to project directory name" {
  init_git_target
  env AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  run jq -r '.name' "$TARGET/.devcontainer/devcontainer.json"
  [ "$output" = "myproject" ]
}

@test "MISE_TRUSTED_CONFIG_PATHS is not present" {
  init_git_target
  env AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  run grep "MISE_TRUSTED_CONFIG_PATHS" "$TARGET/.devcontainer/devcontainer.json"
  [ "$status" -ne 0 ]
}

@test "postCreateCommand is agents-post-create" {
  init_git_target
  env AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  run jq -r '.postCreateCommand' "$TARGET/.devcontainer/devcontainer.json"
  [ "$output" = "agents-post-create" ]
}

@test "postStartCommand is agents-post-start" {
  init_git_target
  env AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  run jq -r '.postStartCommand' "$TARGET/.devcontainer/devcontainer.json"
  [ "$output" = "agents-post-start" ]
}

# --- .gitignore content --------------------------------------------------------

@test ".gitignore includes dotfiles/.claude/" {
  bash "$SCAFFOLD" "$TARGET"
  grep -q "dotfiles/.claude/" "$TARGET/.devcontainer/.gitignore"
}

@test ".gitignore includes dotfiles/.gemini/" {
  bash "$SCAFFOLD" "$TARGET"
  grep -q "dotfiles/.gemini/" "$TARGET/.devcontainer/.gitignore"
}

@test ".gitignore includes dotfiles/.zsh_history" {
  bash "$SCAFFOLD" "$TARGET"
  grep -q "dotfiles/.zsh_history" "$TARGET/.devcontainer/.gitignore"
}

# --- devcontainer skip when already exists -------------------------------------

@test "skips devcontainer setup when .devcontainer already exists" {
  mkdir -p "$TARGET/.devcontainer"
  init_git_target
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  [ ! -f "$TARGET/.devcontainer/devcontainer.json" ]
}

# --- agents-devcontainer submodule --------------------------------------------

@test "adds agents-devcontainer submodule in git repo" {
  init_git_target
  AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ -d "$TARGET/vendor/agents-devcontainer" ]
  [ -f "$TARGET/vendor/agents-devcontainer/scaffold/merge.sh" ]
}

@test "skips agents-devcontainer submodule when already exists" {
  init_git_target
  mkdir -p "$TARGET/vendor/agents-devcontainer"
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  [ -d "$TARGET/vendor/agents-devcontainer" ]
}

@test "does not add agents-devcontainer submodule when not a git repo" {
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  [ ! -d "$TARGET/vendor/agents-devcontainer" ]
}

# --- SDD integration ----------------------------------------------------------

@test "adds ai-sdd-guide submodule" {
  init_git_target
  AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ -d "$TARGET/vendor/ai-sdd-guide" ]
  [ -f "$TARGET/vendor/ai-sdd-guide/integration/CLAUDE.md.example" ]
}

@test "copies CLAUDE.md from integration" {
  init_git_target
  AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ -f "$TARGET/CLAUDE.md" ]
}

@test "copies AGENTS.md from integration" {
  init_git_target
  AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ -f "$TARGET/AGENTS.md" ]
}

@test "copies .claude/settings.json from integration" {
  init_git_target
  AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ -f "$TARGET/.claude/settings.json" ]
}

@test "copies .claude/agents/ from integration" {
  init_git_target
  AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ -d "$TARGET/.claude/agents" ]
  [ -f "$TARGET/.claude/agents/sdd-reviewer.md" ]
}

@test "copies .github/workflows/sdd-check.yml from integration" {
  init_git_target
  AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ -f "$TARGET/.github/workflows/sdd-check.yml" ]
}

# --- SDD opt-out ---------------------------------------------------------------

@test "AGENTS_DEVCONTAINER_SDD=0 skips SDD setup" {
  init_git_target
  AGENTS_DEVCONTAINER_SDD=0 AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ ! -d "$TARGET/vendor/ai-sdd-guide" ]
  [ ! -f "$TARGET/CLAUDE.md" ]
}

# --- SDD skip existing files ---------------------------------------------------

@test "does not overwrite existing CLAUDE.md" {
  init_git_target
  echo "custom" > "$TARGET/CLAUDE.md"
  AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  run cat "$TARGET/CLAUDE.md"
  [ "$output" = "custom" ]
}

@test "does not overwrite existing AGENTS.md" {
  init_git_target
  echo "custom" > "$TARGET/AGENTS.md"
  AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  run cat "$TARGET/AGENTS.md"
  [ "$output" = "custom" ]
}

@test "does not overwrite existing .claude/settings.json" {
  init_git_target
  mkdir -p "$TARGET/.claude"
  echo '{"custom":true}' > "$TARGET/.claude/settings.json"
  AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  run cat "$TARGET/.claude/settings.json"
  [ "$output" = '{"custom":true}' ]
}

@test "skips submodule add when vendor/ai-sdd-guide already exists" {
  init_git_target
  mkdir -p "$TARGET/vendor/ai-sdd-guide"
  AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ -d "$TARGET/vendor/ai-sdd-guide" ]
}

# --- SDD requires git repo ----------------------------------------------------

@test "skips SDD setup when target is not a git repo" {
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  [ -f "$TARGET/.devcontainer/devcontainer.json" ]
  [ ! -d "$TARGET/vendor/ai-sdd-guide" ]
}

# --- project-tools.yml --------------------------------------------------------

@test "generates project-tools.yml" {
  bash "$SCAFFOLD" "$TARGET"
  [ -f "$TARGET/.devcontainer/project-tools.yml" ]
}

@test "project-tools.yml has comment header" {
  bash "$SCAFFOLD" "$TARGET"
  head -1 "$TARGET/.devcontainer/project-tools.yml" | grep -q "^#"
}

@test "skips project-tools.yml when .devcontainer already exists" {
  mkdir -p "$TARGET/.devcontainer"
  init_git_target
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  [ ! -f "$TARGET/.devcontainer/project-tools.yml" ]
}
```

- [ ] **Step 3: 全テストを実行して全件パスを確認**

```bash
bats tests/
```

Expected: 全テスト PASS。失敗があれば、エラーメッセージを確認して scaffold.sh を修正する。

- [ ] **Step 4: コミット**

```bash
git add scaffold.sh tests/scaffold.bats
git commit -m "feat(devcontainer-update): update scaffold.sh and tests for submodule + merge flow"
```

---

## Task 6: README.md の更新

**Files:**
- Modify: `README.md`

- [ ] **Step 1: README の「新プロジェクトへの導入」セクションを更新**

現在の「方法 A: scaffold スクリプト（推奨）」の説明に、以下を追記する：

```markdown
スクリプトは以下を行います:
- `.devcontainer/` の生成（既に存在する場合はスキップ）
- `devcontainer.project.json` の生成（プロジェクト固有の設定用）
- `vendor/agents-devcontainer` を submodule として追加（git リポジトリの場合）
- `merge.sh` で `devcontainer.json` を生成
- `ai-sdd-guide` を `vendor/ai-sdd-guide` に submodule として追加
- integration ファイル（`CLAUDE.md`, `AGENTS.md`, `.claude/settings.json`, `.claude/agents/`, `.github/workflows/sdd-check.yml`）のコピー（既存ファイルは上書きしない）
```

- [ ] **Step 2: 「devcontainer の更新」セクションを新規追加**

「新プロジェクトへの導入」セクションの後に追加：

```markdown
## devcontainer 設定の更新

agents-devcontainer 本体が更新された際に、消費プロジェクトの設定を取り込む方法。

### devcontainer.json の更新

```bash
# agents-devcontainer の最新を取得
git submodule update --remote vendor/agents-devcontainer

# devcontainer.json を再生成
vendor/agents-devcontainer/scaffold/merge.sh

# 差分確認 → コミット
git diff .devcontainer/devcontainer.json
git add .devcontainer/devcontainer.json
git commit -m "chore(devcontainer): update to latest agents-devcontainer"
```

### プロジェクト固有の設定

`.devcontainer/devcontainer.project.json` にプロジェクトの差分のみを記述します。
この ファイルは `merge.sh` によって `devcontainer.json` にマージされます。

```json
{
  "name": "my-project",
  "mounts": [
    "source=my-db,target=/var/lib/postgresql/data,type=volume"
  ],
  "remoteEnv": {
    "MY_API_KEY": "${localEnv:MY_API_KEY}"
  }
}
```

マージルール：
- `mounts`: base の配列 + project の配列（結合）
- `remoteEnv`: 深いマージ（project の値が優先）
- `image` / `build`: project が優先
- `postCreateCommand` / `postStartCommand`: project が優先（なければ base の `agents-post-create` / `agents-post-start`）

### SDD 統合ファイルの更新

```bash
vendor/agents-devcontainer/scaffold/sdd-update.sh
```

`.claude/agents/` と `.github/workflows/sdd-check.yml` を上書き更新します。
`CLAUDE.md`, `AGENTS.md`, `.claude/settings.json` は保護対象で上書きしません（diff のみ表示）。

### 既存プロジェクトからの移行手順

agents-devcontainer を submodule として使っていない既存プロジェクトの移行手順：

1. submodule を追加: `git submodule add https://github.com/toshikimiyagawa/agents-devcontainer.git vendor/agents-devcontainer`
2. project.json を作成: `echo '{"name":"'"$(basename "$PWD")"'"}' > .devcontainer/devcontainer.project.json`
3. 既存の `.devcontainer/devcontainer.json` と `vendor/agents-devcontainer/scaffold/devcontainer.base.json` を diff し、プロジェクト固有の設定を `devcontainer.project.json` に追記
4. `vendor/agents-devcontainer/scaffold/merge.sh` を実行して `devcontainer.json` を再生成・確認
5. コミット
```

- [ ] **Step 3: コミット**

```bash
git add README.md
git commit -m "docs(devcontainer-update): document update workflow and migration guide"
```

---

## 完了チェックリスト

- [ ] `bats tests/` が全件 PASS
- [ ] `jq empty scaffold/devcontainer.base.json` が PASS
- [ ] acceptance criteria 1–5 が満たされている
- [ ] `specs/devcontainer-update/spec.md` が存在する
- [ ] `.sdd/state.json` に feature/tier/phase が記録されている
