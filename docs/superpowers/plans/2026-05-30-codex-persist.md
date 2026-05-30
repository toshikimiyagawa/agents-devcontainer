# Codex CLI Config Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist `~/.codex/` (OpenAI Codex CLI) across devcontainer rebuilds using the same dotfiles symlink pattern as `.claude` and `.gemini`.

**Architecture:** Create a tracked-but-empty `.devcontainer/dotfiles/.codex/` directory as the symlink target; `agents-post-create` links `~/.codex` to it on container create; scaffold.sh propagates the same pattern to new projects.

**Tech Stack:** bash, bats-core (tests), devcontainer JSON

---

## Files changed

| File | Action |
|---|---|
| `.devcontainer/dotfiles/.codex/.gitignore` | Create — tracks dir, ignores contents |
| `.devcontainer/.gitignore` | Modify — add `dotfiles/.codex/` |
| `.devcontainer/devcontainer.json` | Modify — add `.codex` to `initializeCommand` |
| `.devcontainer/scripts/agents-post-create` | Modify — add `.codex` to for loop |
| `scaffold.sh` | Modify — add `.codex` in 3 places |
| `scaffold/devcontainer.base.json` | Modify — add `.codex` to `initializeCommand` |
| `tests/scaffold.bats` | Modify — add 2 test cases |

---

### Task 1: Write failing tests (TDD — RED)

**Files:**
- Modify: `tests/scaffold.bats`

- [ ] **Step 1: Add 2 test cases after the existing `.gemini` tests**

Open `tests/scaffold.bats`. Find the block near line 61–63:
```bash
@test "creates dotfiles/.gemini directory" {
  bash "$SCAFFOLD" "$TARGET"
  [ -d "$TARGET/.devcontainer/dotfiles/.gemini" ]
}
```

Insert immediately after it:
```bash
@test "creates dotfiles/.codex directory" {
  bash "$SCAFFOLD" "$TARGET"
  [ -d "$TARGET/.devcontainer/dotfiles/.codex" ]
}
```

Find the block near line 124–126:
```bash
@test ".gitignore includes dotfiles/.gemini/" {
  bash "$SCAFFOLD" "$TARGET"
  grep -q "dotfiles/.gemini/" "$TARGET/.devcontainer/.gitignore"
}
```

Insert immediately after it:
```bash
@test ".gitignore includes dotfiles/.codex/" {
  bash "$SCAFFOLD" "$TARGET"
  grep -q "dotfiles/.codex/" "$TARGET/.devcontainer/.gitignore"
}
```

- [ ] **Step 2: Run new tests to confirm they FAIL**

```bash
bats tests/scaffold.bats --filter "codex"
```

Expected output: 2 failures with `[ -d ... ]` or `grep -q ...` errors.

---

### Task 2: Implement the changes (TDD — GREEN)

**Files:**
- Create: `.devcontainer/dotfiles/.codex/.gitignore`
- Modify: `.devcontainer/.gitignore`
- Modify: `.devcontainer/devcontainer.json`
- Modify: `.devcontainer/scripts/agents-post-create`
- Modify: `scaffold.sh`
- Modify: `scaffold/devcontainer.base.json`

- [ ] **Step 1: Create `.devcontainer/dotfiles/.codex/.gitignore`**

Create the file with this exact content (same pattern as `.claude` and `.gemini`):
```
# Codex CLI runtime state — credentials, session logs, caches.
# Keep this directory tracked so the symlink target exists on first launch,
# but don't commit anything inside it.
*
!.gitignore
```

- [ ] **Step 2: Add `dotfiles/.codex/` to `.devcontainer/.gitignore`**

Current content ends with:
```
dotfiles/.zsh_history
```

Change to:
```
dotfiles/.claude/
dotfiles/.gemini/
dotfiles/.codex/
dotfiles/.config/gh/
dotfiles/.ssh/
dotfiles/.zsh_history
```

- [ ] **Step 3: Update `initializeCommand` in `.devcontainer/devcontainer.json`**

Find:
```json
"initializeCommand": "mkdir -p \"${localWorkspaceFolder}/.devcontainer/dotfiles/.claude\" \"${localWorkspaceFolder}/.devcontainer/dotfiles/.gemini\"",
```

Replace with:
```json
"initializeCommand": "mkdir -p \"${localWorkspaceFolder}/.devcontainer/dotfiles/.claude\" \"${localWorkspaceFolder}/.devcontainer/dotfiles/.gemini\" \"${localWorkspaceFolder}/.devcontainer/dotfiles/.codex\"",
```

- [ ] **Step 4: Add `.codex` to the for loop in `agents-post-create`**

Find (line ~39):
```bash
for name in .claude .gemini; do
```

Replace with:
```bash
for name in .claude .gemini .codex; do
```

- [ ] **Step 5: Update `scaffold.sh` — mkdir line**

Find (line ~36):
```bash
mkdir -p "$DC/dotfiles/.claude" "$DC/dotfiles/.gemini"
```

Replace with:
```bash
mkdir -p "$DC/dotfiles/.claude" "$DC/dotfiles/.gemini" "$DC/dotfiles/.codex"
```

- [ ] **Step 6: Update `scaffold.sh` — initializeCommand string**

Find (line ~67):
```bash
"initializeCommand": "mkdir -p \"${localWorkspaceFolder}/.devcontainer/dotfiles/.claude\" \"${localWorkspaceFolder}/.devcontainer/dotfiles/.gemini\"",
```

Replace with:
```bash
"initializeCommand": "mkdir -p \"${localWorkspaceFolder}/.devcontainer/dotfiles/.claude\" \"${localWorkspaceFolder}/.devcontainer/dotfiles/.gemini\" \"${localWorkspaceFolder}/.devcontainer/dotfiles/.codex\"",
```

- [ ] **Step 7: Update `scaffold.sh` — .gitignore content block**

Find (lines ~92–93):
```bash
dotfiles/.claude/
dotfiles/.gemini/
```

Replace with:
```bash
dotfiles/.claude/
dotfiles/.gemini/
dotfiles/.codex/
```

- [ ] **Step 8: Update `scaffold/devcontainer.base.json` — initializeCommand**

Find:
```json
"initializeCommand": "mkdir -p \"${localWorkspaceFolder}/.devcontainer/dotfiles/.claude\" \"${localWorkspaceFolder}/.devcontainer/dotfiles/.gemini\"",
```

Replace with:
```json
"initializeCommand": "mkdir -p \"${localWorkspaceFolder}/.devcontainer/dotfiles/.claude\" \"${localWorkspaceFolder}/.devcontainer/dotfiles/.gemini\" \"${localWorkspaceFolder}/.devcontainer/dotfiles/.codex\"",
```

---

### Task 3: Verify and commit

**Files:** none (run and commit)

- [ ] **Step 1: Run the new tests — expect PASS**

```bash
bats tests/scaffold.bats --filter "codex"
```

Expected:
```
 ✓ creates dotfiles/.codex directory
 ✓ .gitignore includes dotfiles/.codex/
2 tests, 0 failures
```

- [ ] **Step 2: Run the full test suite — expect no regressions**

```bash
bats tests/
```

Expected: all tests pass, 0 failures.

- [ ] **Step 3: Commit**

```bash
git add \
  .devcontainer/dotfiles/.codex/.gitignore \
  .devcontainer/.gitignore \
  .devcontainer/devcontainer.json \
  .devcontainer/scripts/agents-post-create \
  scaffold.sh \
  scaffold/devcontainer.base.json \
  tests/scaffold.bats
git commit -m "feat(codex-persist): persist ~/.codex across devcontainer rebuilds"
```
