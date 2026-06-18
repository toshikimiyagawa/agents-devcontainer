# Hermes Config Persist Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist Hermes Agent runtime state inside devcontainers using `dotfiles/.hermes`, without sharing host `~/.hermes`.

**Architecture:** Follow the existing `.claude` / `.gemini` / `.codex` runtime-state pattern. Scaffold and dogfood devcontainer setup create `dotfiles/.hermes`; `agents-post-create` symlinks `$HOME/.hermes` to `/workspace/dotfiles/.hermes`; dotfiles sync treats `.hermes` as runtime state and excludes it.

**Tech Stack:** Bash, Dev Container JSON/JSONC, bats-core, README Markdown.

## Global Constraints

- Feature slug: `hermes-config-persist`
- Do not bind mount host `~/.hermes`.
- Do not copy/import host `~/.hermes/config.yaml`.
- Do not bake `https://vllm.solvelio.com/v1` or `qwen3.5-122b-a10b-nvfp4` as a global default.
- Do not commit Hermes provider/model/API keys.
- Preserve existing `.claude`, `.gemini`, and `.codex` persistence behavior.
- Use bats for acceptance tests.

---

## File Structure

- `.devcontainer/devcontainer.json` creates `dotfiles/.hermes` for this dogfood repo.
- `scaffold/devcontainer.base.json` creates `dotfiles/.hermes` for generated consumer devcontainers.
- `scaffold.sh` creates `dotfiles/.hermes` and includes it in static fallback `initializeCommand`.
- `.devcontainer/scripts/agents-post-create` symlinks `.hermes` with the other runtime state directories. It keeps `/workspace/dotfiles` as the production default and accepts `AGENTS_DOTFILES_PROJECT` as a test-only override.
- `.devcontainer/scripts/agents-dotfiles-sync` excludes `.hermes` from upstream-managed dotfile sync.
- `tests/agents-post-create.bats` covers symlink behavior for `.hermes` and existing state dirs.
- `tests/scaffold.bats`, `tests/devcontainer.bats`, `tests/dotfiles-sync.bats`, and `tests/hermes-install.bats` cover config generation, exclusion, and docs.
- `README.md` and `.devcontainer/Agents.md` document the persistence boundary.

## Task 1: Scaffold and devcontainer creation paths

**Files:**
- Modify: `tests/scaffold.bats`
- Modify: `tests/devcontainer.bats`
- Modify: `.devcontainer/devcontainer.json`
- Modify: `scaffold/devcontainer.base.json`
- Modify: `scaffold.sh`

**Interfaces:**
- Consumes: existing `initializeCommand` strings and scaffold test helpers.
- Produces: generated projects and dogfood config create `dotfiles/.hermes`.

- [ ] **Step 1: Add failing scaffold tests**

Add these tests near the existing `.claude` / `.gemini` / `.codex` scaffold tests:

```bash
@test "creates dotfiles/.hermes directory" {
  bash "$SCAFFOLD" "$TARGET"
  [ -d "$TARGET/dotfiles/.hermes" ]
}

@test "devcontainer.json initializeCommand creates dotfiles/.hermes" {
  init_git_target
  run env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash "$SCAFFOLD" "$TARGET"
  [ "$status" -eq 0 ]
  grep -q 'dotfiles/.hermes' "$TARGET/.devcontainer/devcontainer.json"
}
```

- [ ] **Step 2: Add failing dogfood devcontainer test**

Add this test to `tests/devcontainer.bats`:

```bash
@test "dogfood devcontainer.json initializeCommand creates dotfiles/.hermes" {
  grep -q 'dotfiles/.hermes' "$DEVCONTAINER_JSON"
}
```

- [ ] **Step 3: Run tests and verify RED**

Run:

```bash
bats tests/scaffold.bats tests/devcontainer.bats
```

Expected: the new `.hermes` tests fail.

- [ ] **Step 4: Update devcontainer initialize commands**

Add `dotfiles/.hermes` to:

- `.devcontainer/devcontainer.json` `initializeCommand`
- `scaffold/devcontainer.base.json` `initializeCommand`
- both the `mkdir -p "$DOTFILES/..."` line and static fallback `initializeCommand` in `scaffold.sh`

Use the existing `.claude` / `.gemini` / `.codex` pattern.

- [ ] **Step 5: Run tests and verify GREEN**

Run:

```bash
bats tests/scaffold.bats tests/devcontainer.bats
```

Expected: all tests in those files pass.

- [ ] **Step 6: Commit**

```bash
git add tests/scaffold.bats tests/devcontainer.bats .devcontainer/devcontainer.json scaffold/devcontainer.base.json scaffold.sh
git commit -m "feat(hermes-config-persist): create hermes state directory"
```

## Task 2: Post-create symlink behavior

**Files:**
- Create: `tests/agents-post-create.bats`
- Modify: `.devcontainer/scripts/agents-post-create`

**Interfaces:**
- Consumes: `agents-post-create` script, `$HOME`, and `/workspace/dotfiles`.
- Produces: `$HOME/.hermes` symlink to `${AGENTS_DOTFILES_PROJECT:-/workspace/dotfiles}/.hermes`.

- [ ] **Step 1: Create failing test file**

Create `tests/agents-post-create.bats`:

```bash
#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../.devcontainer/scripts/agents-post-create"

setup() {
  TMPDIR="$(mktemp -d)"
  export HOME="$TMPDIR/home"
  export AGENTS_DOTFILES_PROJECT="$TMPDIR/workspace/dotfiles"
  mkdir -p "$HOME" "$TMPDIR/bin" "$AGENTS_DOTFILES_PROJECT"
  export PATH="$TMPDIR/bin:$PATH"
  cat > "$TMPDIR/bin/agents-dotfiles-sync" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$TMPDIR/bin/agents-dotfiles-sync"
  cat > "$TMPDIR/bin/git" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$TMPDIR/bin/git"
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "links Hermes state directory from project dotfiles" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -d "$AGENTS_DOTFILES_PROJECT/.hermes" ]
  [ -L "$HOME/.hermes" ]
  [ "$(readlink "$HOME/.hermes")" = "$AGENTS_DOTFILES_PROJECT/.hermes" ]
}

@test "keeps existing Claude Gemini Codex links working" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.claude")" = "$AGENTS_DOTFILES_PROJECT/.claude" ]
  [ "$(readlink "$HOME/.gemini")" = "$AGENTS_DOTFILES_PROJECT/.gemini" ]
  [ "$(readlink "$HOME/.codex")" = "$AGENTS_DOTFILES_PROJECT/.codex" ]
}
```

- [ ] **Step 2: Run test and verify RED**

Run:

```bash
bats tests/agents-post-create.bats
```

Expected: the Hermes symlink test fails because `.hermes` is not linked yet.

- [ ] **Step 3: Add a test override and update post-create runtime state loop**

Change the project assignment in `.devcontainer/scripts/agents-post-create`:

```bash
PROJECT="/workspace/dotfiles"
```

to:

```bash
PROJECT="${AGENTS_DOTFILES_PROJECT:-/workspace/dotfiles}"
```

Then change this loop:

```bash
for name in .claude .gemini .codex; do
```

to:

```bash
for name in .claude .gemini .codex .hermes; do
```

Also update the nearby section comment so it mentions `.hermes`.

- [ ] **Step 4: Run test and verify GREEN**

Run:

```bash
bats tests/agents-post-create.bats
bash -n .devcontainer/scripts/agents-post-create
```

Expected: tests pass and shell syntax is valid.

- [ ] **Step 5: Commit**

```bash
git add tests/agents-post-create.bats .devcontainer/scripts/agents-post-create
git commit -m "feat(hermes-config-persist): link hermes runtime state"
```

## Task 3: Dotfiles sync exclusion

**Files:**
- Modify: `tests/dotfiles-sync.bats`
- Modify: `.devcontainer/scripts/agents-dotfiles-sync`

**Interfaces:**
- Consumes: `is_excluded()` in `agents-dotfiles-sync`.
- Produces: `.hermes` and `.hermes/*` never copied into project dotfiles from upstream.

- [ ] **Step 1: Extend failing exclusion test**

In `tests/dotfiles-sync.bats`, update the runtime exclusion test:

```bash
@test "excludes .claude .gemini .codex .hermes .ssh .zsh_history .gitignore" {
  mkdir -p "$UPSTREAM_DIR/.claude" "$UPSTREAM_DIR/.gemini" "$UPSTREAM_DIR/.codex" "$UPSTREAM_DIR/.hermes" "$UPSTREAM_DIR/.ssh"
  echo x > "$UPSTREAM_DIR/.claude/state"
  echo x > "$UPSTREAM_DIR/.gemini/state"
  echo x > "$UPSTREAM_DIR/.codex/state"
  echo x > "$UPSTREAM_DIR/.hermes/config.yaml"
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
  [ ! -e "$PROJECT_DIR/.hermes/config.yaml" ]
  [ ! -e "$PROJECT_DIR/.ssh/id" ]
  [ ! -e "$PROJECT_DIR/.zsh_history" ]
  [ ! -e "$PROJECT_DIR/.gitignore" ]
  ! grep -q '.claude' "$MANIFEST"
  ! grep -q '.hermes' "$MANIFEST"
  ! grep -q '.gitignore' "$MANIFEST"
}
```

- [ ] **Step 2: Run test and verify RED**

Run:

```bash
bats tests/dotfiles-sync.bats
```

Expected: the exclusion test fails because `.hermes/config.yaml` is copied.

- [ ] **Step 3: Update exclusion list**

In `.devcontainer/scripts/agents-dotfiles-sync`, change:

```bash
.claude|.gemini|.codex|.ssh) return 0 ;;
.claude/*|.gemini/*|.codex/*|.ssh/*) return 0 ;;
```

to include `.hermes`:

```bash
.claude|.gemini|.codex|.hermes|.ssh) return 0 ;;
.claude/*|.gemini/*|.codex/*|.hermes/*|.ssh/*) return 0 ;;
```

- [ ] **Step 4: Run test and verify GREEN**

Run:

```bash
bats tests/dotfiles-sync.bats
bash -n .devcontainer/scripts/agents-dotfiles-sync
```

Expected: tests pass and shell syntax is valid.

- [ ] **Step 5: Commit**

```bash
git add tests/dotfiles-sync.bats .devcontainer/scripts/agents-dotfiles-sync
git commit -m "fix(hermes-config-persist): exclude hermes from dotfile sync"
```

## Task 4: Documentation

**Files:**
- Modify: `tests/hermes-install.bats`
- Modify: `README.md`
- Modify: `.devcontainer/Agents.md`

**Interfaces:**
- Consumes: README and devcontainer operator docs.
- Produces: documented `.hermes` persistence boundary.

- [ ] **Step 1: Add failing docs tests**

Add these tests to `tests/hermes-install.bats`:

```bash
@test "README documents Hermes state persistence" {
  grep -q "dotfiles/.hermes" "$README"
  grep -q "host.*~/.hermes.*共有しない" "$README"
}

@test "Agents.md documents Hermes state persistence" {
  grep -q "dotfiles/.hermes" "$AGENTS"
  grep -q "host.*~/.hermes.*共有しない" "$AGENTS"
}
```

- [ ] **Step 2: Run test and verify RED**

Run:

```bash
bats tests/hermes-install.bats
```

Expected: new docs tests fail.

- [ ] **Step 3: Update README**

Update the Hermes bullet to mention that runtime state is persisted under `dotfiles/.hermes`.

In the dotfiles lifecycle section, change the runtime-state sentence so it includes `.hermes/`, for example:

```markdown
`.claude/` `.gemini/` `.codex/` `.hermes/` `.ssh/` `.zsh_history` はランタイム/個人用のため追従対象外（gitignore 済み）。
```

Add a short paragraph:

```markdown
Hermes Agent の container 内 state は `~/.hermes`（= `dotfiles/.hermes/` への symlink）に保存される。host `~/.hermes` とは共有しない。provider/model は container 内で `hermes setup` を実行するか、`dotfiles/.hermes/config.yaml` に設定する。
```

- [ ] **Step 4: Update Agents.md**

Update `.devcontainer/Agents.md` mount/state and runtime-state sections to include `.hermes`, and explicitly state:

```markdown
`~/.hermes` は host `~/.hermes` と共有しない。`dotfiles/.hermes/` を symlink し、container 専用の Hermes 認証・履歴・memory・provider/model 設定を保持する（中身は gitignore 済み）。
```

- [ ] **Step 5: Run test and verify GREEN**

Run:

```bash
bats tests/hermes-install.bats
```

Expected: tests pass.

- [ ] **Step 6: Commit**

```bash
git add tests/hermes-install.bats README.md .devcontainer/Agents.md
git commit -m "docs(hermes-config-persist): document hermes state persistence"
```

## Task 5: Final verification

**Files:**
- Verify all changed files.

**Interfaces:**
- Consumes: completed Tasks 1-4.
- Produces: passing acceptance test suite.

- [ ] **Step 1: Run full bats suite**

Run:

```bash
bats tests/
```

Expected: all tests pass.

- [ ] **Step 2: Run shell syntax checks**

Run:

```bash
for f in .devcontainer/scripts/*; do bash -n "$f"; done
```

Expected: no output and exit 0.

- [ ] **Step 3: Inspect git diff**

Run:

```bash
git diff --stat
git diff -- .devcontainer/devcontainer.json scaffold/devcontainer.base.json scaffold.sh .devcontainer/scripts/agents-post-create .devcontainer/scripts/agents-dotfiles-sync README.md .devcontainer/Agents.md tests
```

Expected: changes are limited to Hermes persistence and tests/docs.

- [ ] **Step 4: Commit any remaining verification-only fixes**

If verification required additional fixes:

```bash
git add <changed-files>
git commit -m "fix(hermes-config-persist): complete persistence verification"
```

If no fixes were needed, do not create an empty commit.

## Plan Self-Review

- Spec coverage: AC1-3 covered by Task 1; AC4 by Task 2; AC5 by Task 3; AC6-7 by Task 4; AC8 by Tasks 1-5.
- Placeholder scan: no TBD/TODO/fill-in placeholders.
- Type/signature consistency: all paths and test names match the existing bash/bats layout.
