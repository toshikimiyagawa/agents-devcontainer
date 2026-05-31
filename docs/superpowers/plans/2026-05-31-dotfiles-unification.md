# Dotfiles Unification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move all dotfiles from `/workspace/.devcontainer/dotfiles/` to `/workspace/dotfiles/`, remove `/opt/agents/dotfiles/` from the base image, and update `scaffold.sh` so new projects get the same structure.

**Architecture:** Single source of truth at `/workspace/dotfiles/`. `dotfiles/.gitignore` ignores everything by default; base dotfiles are force-committed once. `agents-post-create` drops the `/opt/agents` fallback and links directly from `/workspace/dotfiles/`. `Dockerfile.base` stops baking dotfiles into the image.

**Tech Stack:** bash, bats-core (tests), Docker

---

### Task 1: Move dotfiles directory and update gitignores

**Spec:** Acceptance criteria 1–4 (symlink targets, editability, git status, git add -f)

**Files:**
- Create: `dotfiles/.gitignore`
- Move: `.devcontainer/dotfiles/.zshrc` → `dotfiles/.zshrc`
- Move: `.devcontainer/dotfiles/.tmux.conf` → `dotfiles/.tmux.conf`
- Move: `.devcontainer/dotfiles/.config/` → `dotfiles/.config/`
- Move: `.devcontainer/dotfiles/.ssh/` → `dotfiles/.ssh/`
- Delete: `.devcontainer/dotfiles/` (entire directory)
- Modify: `.devcontainer/.gitignore` (remove dotfiles entries)
- Modify: `.gitignore` (add dotfiles/.fuse_hidden* to replace .devcontainer/dotfiles/.fuse_hidden*)

- [ ] **Step 1: Create `dotfiles/.gitignore`**

```bash
mkdir -p dotfiles
printf '*\n!.gitignore\n' > dotfiles/.gitignore
```

- [ ] **Step 2: Move base dotfiles**

```bash
mv .devcontainer/dotfiles/.zshrc     dotfiles/.zshrc
mv .devcontainer/dotfiles/.tmux.conf dotfiles/.tmux.conf
mv .devcontainer/dotfiles/.config    dotfiles/.config
mv .devcontainer/dotfiles/.ssh       dotfiles/.ssh
```

- [ ] **Step 3: Create state dirs in new location**

```bash
mkdir -p dotfiles/.claude dotfiles/.gemini dotfiles/.codex
```

- [ ] **Step 4: Force-commit base dotfiles**

```bash
git add dotfiles/.gitignore
git add -f dotfiles/.zshrc dotfiles/.tmux.conf dotfiles/.config
git status
# Expected: dotfiles/.gitignore, dotfiles/.zshrc, dotfiles/.tmux.conf, dotfiles/.config/ staged
# NOT staged: dotfiles/.ssh/, dotfiles/.claude/, dotfiles/.gemini/, dotfiles/.codex/
```

- [ ] **Step 5: Remove `.devcontainer/dotfiles/`**

```bash
rm -rf .devcontainer/dotfiles
git add -A
```

- [ ] **Step 6: Update `.devcontainer/.gitignore`**

Remove the dotfiles entries — they are no longer relevant. Replace the entire file:

```
# gh CLI config directory — contains OAuth tokens (hosts.yml) at runtime.
# gh is configured via GH_CONFIG_DIR=/home/ubuntu/.gh-config (named volume),
# so this dotfiles directory is not used by gh inside the container.
.config/gh/
```

- [ ] **Step 7: Update `.gitignore`**

Remove `.devcontainer/dotfiles/` references, add `dotfiles/` noise patterns:

```
# gh CLI config directory — contains OAuth tokens (hosts.yml) at runtime.
# gh is configured via GH_CONFIG_DIR=/home/ubuntu/.gh-config (named volume),
# so this dotfiles directory is not used by gh inside the container.
.devcontainer/dotfiles/.config/gh/

# OS / filesystem noise
.DS_Store
**/.DS_Store
dotfiles/.fuse_hidden*

# Editor swap files
*.swp
*.swo
```

- [ ] **Step 8: Verify git status is clean**

```bash
git status
# Expected: staged changes for moved files, no unexpected untracked files
```

- [ ] **Step 9: Commit**

```bash
git commit -m "feat(dotfiles): move dotfiles to /workspace/dotfiles with gitignore-by-default"
```

---

### Task 2: Update `agents-post-create`

**Spec:** Acceptance criteria 1–2 (symlink targets, editability)

**Files:**
- Modify: `.devcontainer/scripts/agents-post-create`

- [ ] **Step 1: Read the current script**

Open `.devcontainer/scripts/agents-post-create` and note lines 1–78.

- [ ] **Step 2: Rewrite the script**

Replace the entire file content:

```bash
#!/usr/bin/env bash
# Runs once on container create (postCreateCommand).
# Materializes dotfiles into $HOME from /workspace/dotfiles/.
# Safe to re-run.
set -euo pipefail

PROJECT="/workspace/dotfiles"

log() { printf '[agents-post-create] %s\n' "$*"; }

# --- 1. Symlinked dotfiles ----------------------------------------------------
link_one() {
  local name="$1"
  if [[ ! -e "$PROJECT/$name" ]]; then
    log "skip $name (no source)"
    return 0
  fi
  rm -rf "$HOME/$name"
  ln -sfn "$PROJECT/$name" "$HOME/$name"
  log "linked $name -> $PROJECT/$name"
}

link_one ".zshrc"
link_one ".tmux.conf"
link_one ".config"

# --- 2. Project-only state dirs (.claude, .gemini, .codex) ----------------------------
# Runtime state: only in the project (gitignored), never baked into the image.
for name in .claude .gemini .codex; do
  mkdir -p "$PROJECT/$name"
  rm -rf "$HOME/$name"
  ln -s "$PROJECT/$name" "$HOME/$name"
  log "linked $name -> $PROJECT/$name"
done

# --- 2b. .zsh_history ---------------------------------------------------------
# Persist shell history across rebuilds in the workspace (gitignored).
touch "$PROJECT/.zsh_history"
rm -f "$HOME/.zsh_history"
ln -sf "$PROJECT/.zsh_history" "$HOME/.zsh_history"
log "linked .zsh_history -> $PROJECT/.zsh_history"

# --- 3. SSH (copy, not symlink — OpenSSH requires strict permissions) ---------
if [[ -d "$PROJECT/.ssh" ]] && compgen -G "$PROJECT/.ssh/*" >/dev/null 2>&1; then
  rm -rf "$HOME/.ssh"
  cp -r "$PROJECT/.ssh" "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  find "$HOME/.ssh" -maxdepth 1 -type f -exec chmod 600 {} +
  log "copied .ssh from project"
else
  log "skip .ssh (no keys in project dotfiles)"
fi

# --- 4. tmux plugin manager + plugins -----------------------------------------
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  log "cloned TPM"
fi
"$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null 2>&1 \
  || log "warn: tpm install_plugins failed (non-fatal)"

# --- 5. Project-specific tools ------------------------------------------------
if command -v agents-tools-install &>/dev/null; then
  agents-tools-install /workspace
fi

log "done"
```

- [ ] **Step 3: Commit**

```bash
git add .devcontainer/scripts/agents-post-create
git commit -m "feat(agents-post-create): remove /opt/agents fallback, use /workspace/dotfiles only"
```

---

### Task 3: Update `devcontainer.json`

**Spec:** Acceptance criteria 1 (container initializes correctly)

**Files:**
- Modify: `.devcontainer/devcontainer.json`

- [ ] **Step 1: Update `initializeCommand`**

In `.devcontainer/devcontainer.json`, change the `initializeCommand` value from:

```
"mkdir -p \"${localWorkspaceFolder}/.devcontainer/dotfiles/.claude\" \"${localWorkspaceFolder}/.devcontainer/dotfiles/.gemini\" \"${localWorkspaceFolder}/.devcontainer/dotfiles/.codex\""
```

to:

```
"mkdir -p \"${localWorkspaceFolder}/dotfiles/.claude\" \"${localWorkspaceFolder}/dotfiles/.gemini\" \"${localWorkspaceFolder}/dotfiles/.codex\""
```

- [ ] **Step 2: Commit**

```bash
git add .devcontainer/devcontainer.json
git commit -m "feat(devcontainer): update initializeCommand for new dotfiles path"
```

---

### Task 4: Update `Dockerfile.base`

**Spec:** Acceptance criteria 5 (`/opt/agents/dotfiles/` does not exist in built image)

**Files:**
- Modify: `.devcontainer/Dockerfile.base`

- [ ] **Step 1: Remove `/opt/agents/dotfiles/` block**

In `.devcontainer/Dockerfile.base`, remove the entire bake block (find and delete these lines):

```dockerfile
# --- Bake default dotfiles ----------------------------------------------------
# Curated subset: .zshrc, .tmux.conf, .config (minus gh/).
# Project-state dirs (.claude, .gemini, .ssh) are intentionally NOT baked.
# Per-project overrides go in /workspace/.devcontainer/dotfiles/ and take
# precedence via agents-post-create's layered symlink logic.
COPY .devcontainer/dotfiles/.zshrc     /opt/agents/dotfiles/.zshrc
COPY .devcontainer/dotfiles/.tmux.conf /opt/agents/dotfiles/.tmux.conf
COPY .devcontainer/dotfiles/.config    /opt/agents/dotfiles/.config
RUN rm -rf /opt/agents/dotfiles/.config/gh \
 && chown -R root:root /opt/agents \
 && find /opt/agents -type d -exec chmod 0755 {} + \
 && find /opt/agents -type f -exec chmod 0644 {} +
```

Keep the `COPY` lines for the three runtime scripts — those stay baked.

- [ ] **Step 2: Commit**

```bash
git add .devcontainer/Dockerfile.base
git commit -m "feat(dockerfile): remove /opt/agents/dotfiles baking"
```

---

### Task 5: Update `scaffold.sh` and `scaffold/devcontainer.base.json`

**Spec:** Acceptance criterion 6 (scaffold creates correct structure for new projects)

**Files:**
- Modify: `scaffold.sh`
- Modify: `scaffold/devcontainer.base.json`

- [ ] **Step 1: Update `scaffold/devcontainer.base.json` `initializeCommand`**

In `scaffold/devcontainer.base.json`, change the `initializeCommand` value from:

```
"mkdir -p \"${localWorkspaceFolder}/.devcontainer/dotfiles/.claude\" \"${localWorkspaceFolder}/.devcontainer/dotfiles/.gemini\" \"${localWorkspaceFolder}/.devcontainer/dotfiles/.codex\""
```

to:

```
"mkdir -p \"${localWorkspaceFolder}/dotfiles/.claude\" \"${localWorkspaceFolder}/dotfiles/.gemini\" \"${localWorkspaceFolder}/dotfiles/.codex\""
```

- [ ] **Step 2: Update `scaffold.sh` — replace devcontainer setup section**

Find the block that creates `.devcontainer/dotfiles/` and `.devcontainer/.gitignore`. Replace:

```bash
  mkdir -p "$DC/dotfiles/.claude" "$DC/dotfiles/.gemini" "$DC/dotfiles/.codex"
```

with:

```bash
  # dotfiles at project root
  DOTFILES="$TARGET/dotfiles"
  mkdir -p "$DOTFILES/.claude" "$DOTFILES/.gemini" "$DOTFILES/.codex" "$DOTFILES/.ssh"
  printf '*\n!.gitignore\n' > "$DOTFILES/.gitignore"

  # Copy base dotfiles from vendor and force-commit
  if [[ -d "$ADC_DIR/dotfiles" ]]; then
    cp "$ADC_DIR/dotfiles/.zshrc"     "$DOTFILES/.zshrc"
    cp "$ADC_DIR/dotfiles/.tmux.conf" "$DOTFILES/.tmux.conf"
    cp -r "$ADC_DIR/dotfiles/.config" "$DOTFILES/.config"
    git -C "$TARGET" add "$DOTFILES/.gitignore"
    git -C "$TARGET" add -f "$DOTFILES/.zshrc" "$DOTFILES/.tmux.conf" "$DOTFILES/.config"
  else
    git -C "$TARGET" add "$DOTFILES/.gitignore"
  fi
```

- [ ] **Step 3: Update `.devcontainer/.gitignore` generation in `scaffold.sh`**

Find the heredoc that writes `.devcontainer/.gitignore` and remove all `dotfiles/` entries:

```bash
  cat > "$DC/.gitignore" <<'GITIGNORE'
# gh CLI config directory — contains OAuth tokens at runtime.
.config/gh/
GITIGNORE
```

- [ ] **Step 4: Update help text in `scaffold.sh`**

Find and update the line:
```bash
echo "To override dotfiles, drop files into $DC/dotfiles/ (e.g., .zshrc, .tmux.conf, .config/)."
echo "To extend .zshrc rather than replace it: source /opt/agents/dotfiles/.zshrc at the top."
```

Replace with:
```bash
echo "Dotfiles: base files (.zshrc, .tmux.conf, .config/) are committed in dotfiles/."
echo "  Personal overrides (SSH keys, local settings) go in dotfiles/ and are gitignored."
echo "  To commit a personal override: git add -f dotfiles/<file>"
```

- [ ] **Step 5: Commit**

```bash
git add scaffold.sh scaffold/devcontainer.base.json
git commit -m "feat(scaffold): generate dotfiles/ at project root with base files force-committed"
```

---

### Task 6: Update `tests/scaffold.bats`

**Spec:** Acceptance criterion 7 (all scaffold tests pass)

**Files:**
- Modify: `tests/scaffold.bats`

- [ ] **Step 1: Update fixture setup to include dotfiles in ADC_WORK**

In the `setup()` function, add dotfiles to the fixture after the `scaffold/` files are copied:

```bash
  mkdir -p "$ADC_WORK/dotfiles/.config"
  echo '# zshrc' > "$ADC_WORK/dotfiles/.zshrc"
  echo '# tmux' > "$ADC_WORK/dotfiles/.tmux.conf"
  touch "$ADC_WORK/dotfiles/.config/.keep"
  (cd "$ADC_WORK" && git add -A && git -c user.name=test -c user.email=test@test.com commit -m "add dotfiles" >/dev/null 2>&1)
  (cd "$ADC_WORK" && git push >/dev/null 2>&1)
```

- [ ] **Step 2: Update existing dotfiles directory tests**

Find and update these tests:

```bash
@test "creates dotfiles/.claude directory" {
  bash "$SCAFFOLD" "$TARGET"
  [ -d "$TARGET/dotfiles/.claude" ]
}

@test "creates dotfiles/.gemini directory" {
  bash "$SCAFFOLD" "$TARGET"
  [ -d "$TARGET/dotfiles/.gemini" ]
}

@test "creates dotfiles/.codex directory" {
  bash "$SCAFFOLD" "$TARGET"
  [ -d "$TARGET/dotfiles/.codex" ]
}
```

- [ ] **Step 3: Add new tests for dotfiles structure**

Add after the directory tests:

```bash
@test "creates dotfiles/.gitignore" {
  bash "$SCAFFOLD" "$TARGET"
  [ -f "$TARGET/dotfiles/.gitignore" ]
}

@test "dotfiles/.gitignore ignores all by default" {
  bash "$SCAFFOLD" "$TARGET"
  grep -q '^\*$' "$TARGET/dotfiles/.gitignore"
}

@test "dotfiles/.zshrc is committed" {
  init_git_target
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  git -C "$TARGET" ls-files dotfiles/.zshrc | grep -q "dotfiles/.zshrc"
}

@test "dotfiles/.tmux.conf is committed" {
  init_git_target
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  git -C "$TARGET" ls-files dotfiles/.tmux.conf | grep -q "dotfiles/.tmux.conf"
}
```

- [ ] **Step 4: Update `.gitignore` content tests**

Find and update tests that check for `dotfiles/.claude/` etc. in `.devcontainer/.gitignore`:

```bash
@test ".devcontainer/.gitignore does not include dotfiles entries" {
  bash "$SCAFFOLD" "$TARGET"
  ! grep -q "dotfiles/" "$TARGET/.devcontainer/.gitignore"
}
```

- [ ] **Step 5: Update `initializeCommand` test if it exists**

Find any test checking `initializeCommand` content and update the expected path from `.devcontainer/dotfiles/` to `dotfiles/`:

```bash
@test "devcontainer.json initializeCommand uses new dotfiles path" {
  init_git_target
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  grep -q 'dotfiles/.claude' "$TARGET/.devcontainer/devcontainer.json"
  ! grep -q '.devcontainer/dotfiles' "$TARGET/.devcontainer/devcontainer.json"
}
```

- [ ] **Step 6: Run all tests and verify they pass**

```bash
bats tests/scaffold.bats
# Expected: all tests PASS, no failures
```

- [ ] **Step 7: Commit**

```bash
git add tests/scaffold.bats
git commit -m "test(scaffold): update bats tests for new dotfiles/ structure"
```

---

### Task 7: Final verification

- [ ] **Step 1: Run full test suite**

```bash
bats tests/
# Expected: all tests pass
```

- [ ] **Step 2: Verify git status of dotfiles/**

```bash
git ls-files dotfiles/
# Expected: dotfiles/.gitignore, dotfiles/.zshrc, dotfiles/.tmux.conf, dotfiles/.config/...
git status dotfiles/
# Expected: clean (no untracked state dirs)
```

- [ ] **Step 3: Verify /opt/agents is gone from Dockerfile.base**

```bash
grep -n "opt/agents" .devcontainer/Dockerfile.base
# Expected: no output (zero matches)
```

- [ ] **Step 4: Push branch and open PR**

```bash
git push origin <branch-name>
gh pr create --title "feat: unify dotfiles under /workspace/dotfiles" \
  --body "Closes #17"
```
