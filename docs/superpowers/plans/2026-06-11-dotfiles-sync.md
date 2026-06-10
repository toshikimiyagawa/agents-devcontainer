# Dotfiles Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let consuming projects auto-follow upstream dotfiles for files they have not overridden, with non-destructive conflict handling, plus refreshed lifecycle docs.

**Architecture:** A baked script `agents-dotfiles-sync` compares each managed base file across three points — the project copy, the upstream submodule copy, and a provenance baseline recorded in `dotfiles/.agents-dotfiles.lock` (sha256 of the last-synced upstream version). Untouched files fast-forward to upstream; overridden-and-changed files are reported, never overwritten. `agents-post-create` runs it on every rebuild; `scaffold.sh` seeds the manifest for new projects.

**Tech Stack:** Bash, `sha256sum`/`shasum`, `find`, `awk`; bats-core for tests.

---

## File Structure

| Action | Path | Responsibility |
|---|---|---|
| Create | `.devcontainer/scripts/agents-dotfiles-sync` | The sync engine (default mode + `--accept`) |
| Create | `tests/dotfiles-sync.bats` | Behavioral tests for the sync engine |
| Modify | `.devcontainer/scripts/agents-post-create` | Invoke the sync (non-fatal) before symlinking |
| Modify | `.devcontainer/Dockerfile.base` | Bake the script into `/usr/local/bin/` |
| Modify | `scaffold.sh` | Seed + force-add `dotfiles/.agents-dotfiles.lock` |
| Modify | `tests/scaffold.bats` | Fixture ships the script; assert manifest seeded |
| Modify | `README.md` | Document the dotfiles lifecycle; remove stale paths |

---

## Task 1: The sync engine `agents-dotfiles-sync`

**Files:**
- Create: `.devcontainer/scripts/agents-dotfiles-sync`
- Test: `tests/dotfiles-sync.bats`

- [ ] **Step 1: Write the failing tests**

Create `tests/dotfiles-sync.bats`:

```bash
#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../.devcontainer/scripts/agents-dotfiles-sync"

setup() {
  TMPDIR="$(mktemp -d)"
  export UPSTREAM_DIR="$TMPDIR/upstream"
  export PROJECT_DIR="$TMPDIR/project"
  mkdir -p "$UPSTREAM_DIR/.config" "$PROJECT_DIR"
  MANIFEST="$PROJECT_DIR/.agents-dotfiles.lock"
}

teardown() {
  rm -rf "$TMPDIR"
}

# seed a project that exactly mirrors upstream (records baselines, no changes)
seed() {
  run env UPSTREAM_DIR="$UPSTREAM_DIR" PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# --- AC7: no upstream ---------------------------------------------------------
@test "exits 0 and changes nothing when UPSTREAM_DIR is missing" {
  rm -rf "$UPSTREAM_DIR"
  run env UPSTREAM_DIR="$UPSTREAM_DIR" PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skip (no upstream"* ]]
  [ ! -f "$MANIFEST" ]
}

# --- AC5: new upstream file adopted ------------------------------------------
@test "copies a new upstream file and records it in the manifest" {
  echo 'v1' > "$UPSTREAM_DIR/.zshrc"
  run env UPSTREAM_DIR="$UPSTREAM_DIR" PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.zshrc" ]
  run cat "$PROJECT_DIR/.zshrc"
  [ "$output" = "v1" ]
  grep -q '^.zshrc ' "$MANIFEST"
}

# --- seeding: project already mirrors upstream -------------------------------
@test "records baseline without changing a file that already matches upstream" {
  echo 'v1' > "$UPSTREAM_DIR/.zshrc"
  echo 'v1' > "$PROJECT_DIR/.zshrc"
  seed
  grep -q '^.zshrc ' "$MANIFEST"
  run cat "$PROJECT_DIR/.zshrc"
  [ "$output" = "v1" ]
}

# --- AC2: untouched + upstream advanced -> auto-update -----------------------
@test "fast-forwards an untouched file when upstream advances" {
  echo 'v1' > "$UPSTREAM_DIR/.zshrc"
  echo 'v1' > "$PROJECT_DIR/.zshrc"
  seed
  echo 'v2' > "$UPSTREAM_DIR/.zshrc"
  run env UPSTREAM_DIR="$UPSTREAM_DIR" PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  run cat "$PROJECT_DIR/.zshrc"
  [ "$output" = "v2" ]
  # manifest now records the new upstream hash
  newhash="$(sha256sum "$UPSTREAM_DIR/.zshrc" 2>/dev/null | awk '{print $1}' || shasum -a 256 "$UPSTREAM_DIR/.zshrc" | awk '{print $1}')"
  grep -q "^.zshrc $newhash$" "$MANIFEST"
}

# --- AC4: overridden + upstream unchanged -> no change -----------------------
@test "leaves an overridden file alone when upstream is unchanged" {
  echo 'v1' > "$UPSTREAM_DIR/.zshrc"
  echo 'v1' > "$PROJECT_DIR/.zshrc"
  seed
  echo 'mine' > "$PROJECT_DIR/.zshrc"
  run env UPSTREAM_DIR="$UPSTREAM_DIR" PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  run cat "$PROJECT_DIR/.zshrc"
  [ "$output" = "mine" ]
}

# --- AC3: overridden + upstream changed -> conflict (non-destructive) --------
@test "reports a conflict and writes a sidecar when both sides changed" {
  echo 'v1' > "$UPSTREAM_DIR/.zshrc"
  echo 'v1' > "$PROJECT_DIR/.zshrc"
  seed
  echo 'mine' > "$PROJECT_DIR/.zshrc"
  echo 'v2'   > "$UPSTREAM_DIR/.zshrc"
  run env UPSTREAM_DIR="$UPSTREAM_DIR" PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  run cat "$PROJECT_DIR/.zshrc"
  [ "$output" = "mine" ]                       # untouched
  [ -f "$PROJECT_DIR/.zshrc.agents-upstream" ]
  run cat "$PROJECT_DIR/.zshrc.agents-upstream"
  [ "$output" = "v2" ]
  run env UPSTREAM_DIR="$UPSTREAM_DIR" PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPT"
  [[ "$output" == *"need manual review"* ]]
}

# --- AC6: --accept advances baseline, keeps override -------------------------
@test "--accept stops the conflict warning and keeps the local override" {
  echo 'v1' > "$UPSTREAM_DIR/.zshrc"
  echo 'v1' > "$PROJECT_DIR/.zshrc"
  seed
  echo 'mine' > "$PROJECT_DIR/.zshrc"
  echo 'v2'   > "$UPSTREAM_DIR/.zshrc"
  run env UPSTREAM_DIR="$UPSTREAM_DIR" PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPT"   # creates conflict
  run env UPSTREAM_DIR="$UPSTREAM_DIR" PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPT" --accept .zshrc
  [ "$status" -eq 0 ]
  run cat "$PROJECT_DIR/.zshrc"
  [ "$output" = "mine" ]                        # override preserved
  [ ! -f "$PROJECT_DIR/.zshrc.agents-upstream" ] # sidecar cleared
  run env UPSTREAM_DIR="$UPSTREAM_DIR" PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPT"
  [[ "$output" != *"need manual review"* ]]      # no more warning
}

# --- AC8: runtime/personal entries excluded ----------------------------------
@test "excludes .claude .gemini .codex .ssh .zsh_history .gitignore" {
  mkdir -p "$UPSTREAM_DIR/.claude" "$UPSTREAM_DIR/.gemini" "$UPSTREAM_DIR/.codex" "$UPSTREAM_DIR/.ssh"
  echo x > "$UPSTREAM_DIR/.claude/state"
  echo x > "$UPSTREAM_DIR/.gemini/state"
  echo x > "$UPSTREAM_DIR/.codex/state"
  echo x > "$UPSTREAM_DIR/.ssh/id"
  echo x > "$UPSTREAM_DIR/.zsh_history"
  printf '*\n!.gitignore\n' > "$UPSTREAM_DIR/.gitignore"
  echo 'v1' > "$UPSTREAM_DIR/.zshrc"
  run env UPSTREAM_DIR="$UPSTREAM_DIR" PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.zshrc" ]
  [ ! -e "$PROJECT_DIR/.claude/state" ]
  [ ! -e "$PROJECT_DIR/.gemini/state" ]
  [ ! -e "$PROJECT_DIR/.codex/state" ]
  [ ! -e "$PROJECT_DIR/.ssh/id" ]
  [ ! -e "$PROJECT_DIR/.zsh_history" ]
  [ ! -e "$PROJECT_DIR/.gitignore" ]
  ! grep -q '.claude' "$MANIFEST"
  ! grep -q '.gitignore' "$MANIFEST"
}

# --- nested .config file handled per-file ------------------------------------
@test "tracks nested .config files per-file" {
  echo 'a' > "$UPSTREAM_DIR/.config/starship.toml"
  run env UPSTREAM_DIR="$UPSTREAM_DIR" PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.config/starship.toml" ]
  grep -q '^.config/starship.toml ' "$MANIFEST"
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bats tests/dotfiles-sync.bats`
Expected: all fail (script does not exist yet / not executable).

- [ ] **Step 3: Write the script**

Create `.devcontainer/scripts/agents-dotfiles-sync`:

```bash
#!/usr/bin/env bash
# Sync base dotfiles from the agents-devcontainer submodule into the project's
# dotfiles/, following upstream for files the project has NOT overridden.
#
# Override detection uses a provenance manifest (dotfiles/.agents-dotfiles.lock)
# recording the sha256 of the upstream version last synced (the baseline). A
# project file equal to its baseline is "not overridden" and fast-forwards to
# upstream; an overridden file whose upstream also changed is a conflict that is
# reported (non-destructive), never overwritten.
#
# Usage:
#   agents-dotfiles-sync                 # sync (default)
#   agents-dotfiles-sync --accept PATH…  # keep local override, accept upstream baseline
#
# Env (overridable for tests):
#   UPSTREAM_DIR  default /workspace/vendor/agents-devcontainer/dotfiles
#   PROJECT_DIR   default /workspace/dotfiles
set -euo pipefail

UPSTREAM_DIR="${UPSTREAM_DIR:-/workspace/vendor/agents-devcontainer/dotfiles}"
PROJECT_DIR="${PROJECT_DIR:-/workspace/dotfiles}"
UPSTREAM_DIR="${UPSTREAM_DIR%/}"
PROJECT_DIR="${PROJECT_DIR%/}"
MANIFEST="$PROJECT_DIR/.agents-dotfiles.lock"

log() { printf '[agents-dotfiles-sync] %s\n' "$*"; }

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

manifest_get() {
  [[ -f "$MANIFEST" ]] || return 0
  awk -v p="$1" '$1==p {print $2; exit}' "$MANIFEST"
}

manifest_set() {
  local p="$1" h="$2" tmp
  tmp="$(mktemp)"
  if [[ -f "$MANIFEST" ]]; then
    awk -v p="$p" '$1!=p' "$MANIFEST" > "$tmp"
  fi
  printf '%s %s\n' "$p" "$h" >> "$tmp"
  LC_ALL=C sort "$tmp" -o "$tmp"
  mv "$tmp" "$MANIFEST"
}

is_excluded() {
  case "$1" in
    .gitignore|.zsh_history) return 0 ;;
    .claude|.gemini|.codex|.ssh) return 0 ;;
    .claude/*|.gemini/*|.codex/*|.ssh/*) return 0 ;;
  esac
  return 1
}

# --- --accept mode ------------------------------------------------------------
if [[ "${1:-}" == "--accept" ]]; then
  shift
  for rel in "$@"; do
    up_file="$UPSTREAM_DIR/$rel"
    if [[ -f "$up_file" ]]; then
      manifest_set "$rel" "$(hash_file "$up_file")"
      rm -f "$PROJECT_DIR/$rel.agents-upstream"
      log "accepted upstream baseline for $rel (local override kept)"
    else
      log "skip --accept $rel (no upstream file)"
    fi
  done
  exit 0
fi

# --- sync mode ----------------------------------------------------------------
if [[ ! -d "$UPSTREAM_DIR" ]]; then
  log "skip (no upstream at $UPSTREAM_DIR)"
  exit 0
fi
mkdir -p "$PROJECT_DIR"

conflicts=()

while IFS= read -r -d '' up_file; do
  rel="${up_file#"$UPSTREAM_DIR"/}"
  is_excluded "$rel" && continue

  up_hash="$(hash_file "$up_file")"
  base_hash="$(manifest_get "$rel")"
  proj_file="$PROJECT_DIR/$rel"
  sidecar="$proj_file.agents-upstream"

  if [[ -f "$proj_file" ]]; then
    proj_hash="$(hash_file "$proj_file")"
  else
    proj_hash=""
  fi

  # project file missing
  if [[ -z "$proj_hash" ]]; then
    if [[ -z "$base_hash" ]]; then
      mkdir -p "$(dirname "$proj_file")"
      cp "$up_file" "$proj_file"
      manifest_set "$rel" "$up_hash"
      log "added $rel (new upstream file)"
    else
      log "skip $rel (missing locally; in manifest)"
    fi
    continue
  fi

  # no baseline recorded yet
  if [[ -z "$base_hash" ]]; then
    if [[ "$proj_hash" == "$up_hash" ]]; then
      manifest_set "$rel" "$up_hash"
      rm -f "$sidecar"
    else
      cp "$up_file" "$sidecar"
      conflicts+=("$rel")
    fi
    continue
  fi

  # baseline known
  if [[ "$proj_hash" == "$base_hash" ]]; then
    # not overridden
    if [[ "$up_hash" != "$base_hash" ]]; then
      cp "$up_file" "$proj_file"
      manifest_set "$rel" "$up_hash"
      log "updated $rel (upstream advanced)"
    fi
    rm -f "$sidecar"
  else
    # overridden
    if [[ "$up_hash" == "$base_hash" ]]; then
      rm -f "$sidecar"                  # upstream unchanged → keep override
    elif [[ "$proj_hash" == "$up_hash" ]]; then
      manifest_set "$rel" "$up_hash"    # already reconciled
      rm -f "$sidecar"
      log "reconciled $rel (now matches upstream)"
    else
      cp "$up_file" "$sidecar"
      conflicts+=("$rel")
    fi
  fi
done < <(find "$UPSTREAM_DIR" -type f -print0)

if [[ ${#conflicts[@]} -gt 0 ]]; then
  log "----------------------------------------------------------------"
  log "${#conflicts[@]} file(s) need manual review (local override + upstream change):"
  for c in "${conflicts[@]}"; do
    log "  - $c  (diff: diff \"$PROJECT_DIR/$c\" \"$PROJECT_DIR/$c.agents-upstream\")"
  done
  log "Keep your version and silence the warning with:"
  log "  agents-dotfiles-sync --accept ${conflicts[*]}"
  log "----------------------------------------------------------------"
fi

exit 0
```

- [ ] **Step 4: Make it executable**

Run: `chmod +x .devcontainer/scripts/agents-dotfiles-sync`

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bats tests/dotfiles-sync.bats`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add .devcontainer/scripts/agents-dotfiles-sync tests/dotfiles-sync.bats
git commit -m "feat(dotfiles-sync): add provenance-based dotfiles sync engine"
```

---

## Task 2: Invoke the sync from `agents-post-create`

**Files:**
- Modify: `.devcontainer/scripts/agents-post-create` (after `log()` def, before section 1)

- [ ] **Step 1: Add the invocation**

Insert immediately after the `log() { ... }` definition (line ~9), before `# --- 1. Symlinked dotfiles`:

```bash
# --- 0. Sync base dotfiles from upstream (non-fatal) --------------------------
if command -v agents-dotfiles-sync >/dev/null 2>&1; then
  agents-dotfiles-sync || log "warn: agents-dotfiles-sync failed (non-fatal)"
fi

```

- [ ] **Step 2: Syntax-check**

Run: `bash -n .devcontainer/scripts/agents-post-create`
Expected: no output, exit 0.

- [ ] **Step 3: Commit**

```bash
git add .devcontainer/scripts/agents-post-create
git commit -m "feat(agents-post-create): run agents-dotfiles-sync before symlinking"
```

---

## Task 3: Bake the script into `Dockerfile.base`

**Files:**
- Modify: `.devcontainer/Dockerfile.base` (the "Bake runtime scripts" block)

- [ ] **Step 1: Add COPY + chmod**

Add a `COPY` line after the `agents-tools-install` COPY, and extend the `chmod` line:

```dockerfile
COPY .devcontainer/scripts/agents-post-create /usr/local/bin/agents-post-create
COPY .devcontainer/scripts/agents-post-start  /usr/local/bin/agents-post-start
COPY .devcontainer/scripts/agents-tools-install /usr/local/bin/agents-tools-install
COPY .devcontainer/scripts/agents-dotfiles-sync /usr/local/bin/agents-dotfiles-sync
RUN chmod 0755 /usr/local/bin/agents-post-create /usr/local/bin/agents-post-start /usr/local/bin/agents-tools-install /usr/local/bin/agents-dotfiles-sync
```

- [ ] **Step 2: Commit**

```bash
git add .devcontainer/Dockerfile.base
git commit -m "feat(dotfiles-sync): bake agents-dotfiles-sync into the base image"
```

---

## Task 4: Seed the manifest in `scaffold.sh` + tests

**Files:**
- Modify: `scaffold.sh` (the dotfiles copy block, ~lines 44-54)
- Modify: `tests/scaffold.bats` (fixture + new test)

- [ ] **Step 1: Update the scaffold.bats fixture to ship the script**

In `tests/scaffold.bats` `setup()`, after the existing dotfiles fixture lines (after `touch "$ADC_WORK/dotfiles/.config/.keep"`), add:

```bash
  # Ship the sync script so the submodule checkout has it (used to seed the manifest)
  mkdir -p "$ADC_WORK/.devcontainer/scripts"
  cp "$BATS_TEST_DIRNAME/../.devcontainer/scripts/agents-dotfiles-sync" "$ADC_WORK/.devcontainer/scripts/"
  chmod +x "$ADC_WORK/.devcontainer/scripts/agents-dotfiles-sync"
```

- [ ] **Step 2: Add the failing test**

Append to `tests/scaffold.bats`:

```bash
# --- dotfiles provenance manifest ---------------------------------------------

@test "seeds and commits dotfiles/.agents-dotfiles.lock" {
  init_git_target
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  [ -f "$TARGET/dotfiles/.agents-dotfiles.lock" ]
  git -C "$TARGET" ls-files dotfiles/.agents-dotfiles.lock | grep -q ".agents-dotfiles.lock"
  grep -q '^.zshrc ' "$TARGET/dotfiles/.agents-dotfiles.lock"
  grep -q '^.tmux.conf ' "$TARGET/dotfiles/.agents-dotfiles.lock"
}
```

- [ ] **Step 3: Run to verify the new test fails**

Run: `bats tests/scaffold.bats -f "seeds and commits"`
Expected: FAIL (lock file not created yet).

- [ ] **Step 4: Update scaffold.sh**

Replace the `if [[ -d "$ADC_DIR/dotfiles" ]]` true-branch (lines 45-50) with:

```bash
    if [[ -d "$ADC_DIR/dotfiles" ]]; then
      cp "$ADC_DIR/dotfiles/.zshrc"     "$DOTFILES/.zshrc"
      cp "$ADC_DIR/dotfiles/.tmux.conf" "$DOTFILES/.tmux.conf"
      cp -r "$ADC_DIR/dotfiles/.config" "$DOTFILES/.config"
      # Seed the provenance manifest so future syncs know the upstream baseline
      if [[ -x "$ADC_DIR/.devcontainer/scripts/agents-dotfiles-sync" ]]; then
        UPSTREAM_DIR="$ADC_DIR/dotfiles" PROJECT_DIR="$DOTFILES" \
          bash "$ADC_DIR/.devcontainer/scripts/agents-dotfiles-sync" >/dev/null 2>&1 || true
      fi
      git -C "$TARGET" add "$DOTFILES/.gitignore"
      git -C "$TARGET" add -f "$DOTFILES/.zshrc" "$DOTFILES/.tmux.conf" "$DOTFILES/.config"
      [[ -f "$DOTFILES/.agents-dotfiles.lock" ]] && \
        git -C "$TARGET" add -f "$DOTFILES/.agents-dotfiles.lock"
    else
```

- [ ] **Step 5: Run the full scaffold suite**

Run: `bats tests/scaffold.bats`
Expected: all PASS (including the new test and the existing `.zshrc`/`.tmux.conf` committed tests).

- [ ] **Step 6: Commit**

```bash
git add scaffold.sh tests/scaffold.bats
git commit -m "feat(scaffold): seed dotfiles provenance manifest for new projects"
```

---

## Task 5: Refresh the README dotfiles docs

**Files:**
- Modify: `README.md` (line 204 fix; rewrite the "dotfiles のカスタマイズ" section lines 206-224)

- [ ] **Step 1: Confirm the stale references**

Run: `grep -rn "/opt/agents/dotfiles\|.devcontainer/dotfiles" README.md`
Expected: matches at line 204 (`.devcontainer/dotfiles/.claude/`), 208 (`.devcontainer/dotfiles/`), 219 (`/opt/agents/dotfiles/.zshrc`).

- [ ] **Step 2: Fix line 204**

Replace:
```
プラグイン状態は `~/.claude/`（= `.devcontainer/dotfiles/.claude/` への symlink、gitignore 済み）に保存されるため、rebuild 後も保持される。
```
with:
```
プラグイン状態は `~/.claude/`（= `dotfiles/.claude/` への symlink、gitignore 済み）に保存されるため、rebuild 後も保持される。
```

- [ ] **Step 3: Replace the "dotfiles のカスタマイズ" section**

Replace lines 206-224 (from `## dotfiles のカスタマイズ` through the `詳細な仕様については ...` line) with:

````markdown
## dotfiles のライフサイクル

### source of truth

ベース dotfiles の正本は `vendor/agents-devcontainer/dotfiles/*`（submodule）。
`scaffold.sh` がプロジェクト直下の `dotfiles/` へ**初回コピー**し force-commit する。
コンテナ内では `agents-post-create` が `~/<name>` → `/workspace/dotfiles/<name>` を symlink する。

追従対象（ファイル単位）:

| ファイル | 説明 |
|---|---|
| `.zshrc` | シェル設定 |
| `.tmux.conf` | tmux 設定 |
| `.config/*` | starship / nvim / lazygit / yazi / git などのツール設定 |

`.claude/` `.gemini/` `.codex/` `.ssh/` `.zsh_history` はランタイム/個人用のため追従対象外（gitignore 済み）。

### upstream 更新の取り込み

`vendor/agents-devcontainer` を bump した後、次回 rebuild 時に `agents-dotfiles-sync` が自動実行され、
**自分で編集していない**ベースファイルだけを upstream の最新版へ更新する（`dotfiles/` の `git diff` として現れるので確認のうえ commit する）。

```bash
git submodule update --remote vendor/agents-devcontainer   # --recursive は使わない
# 次回 rebuild 時に未編集ファイルが自動追従される
```

判定は `dotfiles/.agents-dotfiles.lock`（最後に同期した upstream 版の sha256）を基準に行う。

### 上書き（override）

`dotfiles/` 内のファイルを編集すると baseline から乖離し、以降そのファイルは自動更新の対象外になる（あなたの版が保護される）。

### コンフリクト

あなたが編集したファイルが upstream でも変更された場合、sync はそのファイルを**変更せず**警告し、
`dotfiles/<file>.agents-upstream`（gitignore 済み）に upstream 版を出力する。差分確認:

```bash
diff dotfiles/.zshrc dotfiles/.zshrc.agents-upstream
```

upstream の変更を確認したうえで自分の版を維持したい場合（警告を止める。ファイルは変更しない）:

```bash
agents-dotfiles-sync --accept .zshrc
```

詳細な仕様については [.devcontainer/Agents.md](.devcontainer/Agents.md) を参照してください。
````

- [ ] **Step 4: Verify no stale references remain**

Run: `grep -rn "/opt/agents/dotfiles\|.devcontainer/dotfiles" README.md`
Expected: no matches.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs(dotfiles): document dotfiles lifecycle and remove stale paths"
```

---

## Task 6: Full verification

- [ ] **Step 1: Run the whole test suite**

Run: `bats tests/`
Expected: all PASS (dotfiles-sync.bats, scaffold.bats, merge.bats, update.bats, tools-install.bats).

- [ ] **Step 2: Shell syntax check all scripts**

Run: `for f in .devcontainer/scripts/*; do bash -n "$f"; done && echo OK`
Expected: `OK`.

---

## Self-Review notes

- **Spec coverage:** AC1→Task3; AC2→Task1 "fast-forwards"; AC3→Task1 "reports a conflict"; AC4→Task1 "leaves an overridden file alone"; AC5→Task1 "copies a new upstream file"; AC6→Task1 "--accept"; AC7→Task1 "exits 0 ... missing"; AC8→Task1 "excludes ..."; AC9→Task2; AC10→Task4; AC11→Task5; AC12→Tasks1,4,6.
- **Hashing portability:** script and tests use `sha256sum` with a `shasum -a 256` fallback so `bats tests/` runs on macOS (dev) and Linux (CI).
- **Non-fatal:** the sync always `exit 0`; `agents-post-create` additionally guards with `|| log`.
