# Hermes Superpowers Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bootstrap `skills-sh/obra/superpowers` into Hermes Agent during devcontainer postCreate, with state persisted in `dotfiles/.hermes`.

**Architecture:** Add an idempotent helper to `.devcontainer/scripts/agents-post-create` after the `.hermes` symlink is created. The helper checks for `hermes`, installs `skills-sh/obra/superpowers` with `--yes`, writes a marker on success, and treats missing `hermes` or install failure as non-fatal. Tests use fake `hermes` commands and never contact the real skills registry.

**Tech Stack:** Bash, devcontainer postCreateCommand, Hermes CLI, bats-core.

## Global Constraints

- Do not bind mount or import host `~/.hermes`.
- Do not commit Hermes provider/model/API key or `dotfiles/.hermes` contents.
- Run skill install only from `agents-post-create`, after `$HOME/.hermes` points at project dotfiles.
- Use `hermes skills install --yes skills-sh/obra/superpowers`.
- Missing `hermes` and install failure must not fail `postCreateCommand`.
- Existing Claude/Gemini/Codex/Hermes persistence behavior must not regress.

---

### Task 1: postCreate bootstrap wiring

**Files:**
- Modify: `tests/agents-post-create.bats`
- Modify: `.devcontainer/scripts/agents-post-create`

**Interfaces:**
- Consumes: `$HOME/.hermes` symlink created by the existing project-state loop.
- Produces: `$HOME/.hermes/.agents-superpowers-installed` marker after successful install.
- Command invoked: `hermes skills install --yes skills-sh/obra/superpowers`

- [ ] **Step 1: Add fake-Hermes tests**

Append these tests to `tests/agents-post-create.bats`:

```bash
@test "installs Hermes superpowers after linking Hermes state" {
  cat > "$TMPDIR/bin/hermes" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$HERMES_CALL_LOG"
test -L "$HOME/.hermes"
test "$(readlink "$HOME/.hermes")" = "$AGENTS_DOTFILES_PROJECT/.hermes"
exit 0
SH
  chmod +x "$TMPDIR/bin/hermes"
  export HERMES_CALL_LOG="$TMPDIR/hermes-calls.log"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  run cat "$HERMES_CALL_LOG"
  [ "$output" = "skills install --yes skills-sh/obra/superpowers" ]
  [ -f "$AGENTS_DOTFILES_PROJECT/.hermes/.agents-superpowers-installed" ]
}

@test "skips Hermes superpowers install when marker exists" {
  mkdir -p "$AGENTS_DOTFILES_PROJECT/.hermes"
  touch "$AGENTS_DOTFILES_PROJECT/.hermes/.agents-superpowers-installed"
  cat > "$TMPDIR/bin/hermes" <<'SH'
#!/usr/bin/env bash
echo "unexpected hermes call" >&2
exit 99
SH
  chmod +x "$TMPDIR/bin/hermes"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hermes superpowers already bootstrapped"* ]]
}

@test "keeps postCreate successful when Hermes superpowers install fails" {
  cat > "$TMPDIR/bin/hermes" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$HERMES_CALL_LOG"
exit 42
SH
  chmod +x "$TMPDIR/bin/hermes"
  export HERMES_CALL_LOG="$TMPDIR/hermes-calls.log"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  run cat "$HERMES_CALL_LOG"
  [ "$output" = "skills install --yes skills-sh/obra/superpowers" ]
  [ ! -f "$AGENTS_DOTFILES_PROJECT/.hermes/.agents-superpowers-installed" ]
  [[ "$output" == *"warn: Hermes superpowers bootstrap failed"* ]]
}

@test "skips Hermes superpowers bootstrap when hermes command is unavailable" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skip Hermes superpowers bootstrap (hermes command not found)"* ]]
  [ ! -f "$AGENTS_DOTFILES_PROJECT/.hermes/.agents-superpowers-installed" ]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
bats tests/agents-post-create.bats
```

Expected: new tests fail because `agents-post-create` does not call `hermes skills install` yet.

- [ ] **Step 3: Add bootstrap helper**

In `.devcontainer/scripts/agents-post-create`, add this block immediately after the project-state loop that links `.claude .gemini .codex .hermes` and before the `.zsh_history` section:

```bash
# --- 2a. Hermes Superpowers ---------------------------------------------------
bootstrap_hermes_superpowers() {
  local marker="$HOME/.hermes/.agents-superpowers-installed"

  if [[ -f "$marker" ]]; then
    log "Hermes superpowers already bootstrapped"
    return 0
  fi

  if ! command -v hermes >/dev/null 2>&1; then
    log "skip Hermes superpowers bootstrap (hermes command not found)"
    return 0
  fi

  if hermes skills install --yes skills-sh/obra/superpowers; then
    touch "$marker"
    log "bootstrapped Hermes superpowers"
  else
    log "warn: Hermes superpowers bootstrap failed (non-fatal)"
  fi
}

bootstrap_hermes_superpowers
```

- [ ] **Step 4: Run focused tests**

Run:

```bash
bats tests/agents-post-create.bats
```

Expected: all tests in `tests/agents-post-create.bats` pass.

- [ ] **Step 5: Commit task 1**

Run:

```bash
git add .devcontainer/scripts/agents-post-create tests/agents-post-create.bats
git commit -m "feat(hermes-superpowers-bootstrap): install superpowers during postCreate"
```

---

### Task 2: docs and docs tests

**Files:**
- Modify: `tests/hermes-install.bats`
- Modify: `README.md`
- Modify: `.devcontainer/Agents.md`

**Interfaces:**
- Consumes: marker path `$HOME/.hermes/.agents-superpowers-installed`
- Produces: user-facing docs that explain postCreate bootstrap and container-only persistence.

- [ ] **Step 1: Add docs tests**

Append these tests to `tests/hermes-install.bats`:

```bash
@test "README documents Hermes superpowers bootstrap" {
  grep -q "skills-sh/obra/superpowers" "$README"
  grep -q "dotfiles/.hermes" "$README"
  grep -q "postCreate" "$README"
}

@test "Agents.md documents Hermes superpowers bootstrap" {
  grep -q "skills-sh/obra/superpowers" "$AGENTS"
  grep -q "dotfiles/.hermes" "$AGENTS"
  grep -q "non-fatal" "$AGENTS"
}
```

- [ ] **Step 2: Run docs tests to verify they fail**

Run:

```bash
bats tests/hermes-install.bats
```

Expected: new docs tests fail because README and Agents.md do not yet mention Hermes superpowers bootstrap.

- [ ] **Step 3: Update README**

In `README.md`, update the Hermes Agent bullet near the tool list to mention superpowers:

```markdown
- **Hermes Agent**: NousResearch による自己改善型の自律 AI エージェント（永続メモリ・スキル学習・ブラウザ自動化）。状態は container 専用の `dotfiles/.hermes/` に永続化し、`postCreate` で `skills-sh/obra/superpowers` を non-interactive に bootstrap する。初回利用時に `hermes setup` でプロバイダを設定する。
```

Also extend the Hermes paragraph in the dotfiles lifecycle section:

```markdown
Hermes Agent の container 内 state は `~/.hermes`（= `dotfiles/.hermes/` への symlink）に保存される。host `~/.hermes` とは共有しない。provider/model は container 内で `hermes setup` を実行するか、`dotfiles/.hermes/config.yaml` に設定する。`agents-post-create` は `hermes skills install --yes skills-sh/obra/superpowers` を一度だけ実行し、成功後は `dotfiles/.hermes/.agents-superpowers-installed` marker で再実行を抑制する。install 失敗は warning として扱い、devcontainer setup は継続する。
```

- [ ] **Step 4: Update Agents.md**

In `.devcontainer/Agents.md`, update the Hermes Agent bullet in the AI tool list:

```markdown
- `Hermes Agent` (hermes) — NousResearch による自己改善型の自律 AI エージェント。`USER ubuntu` で per-user インストール（コードは `~/.hermes`、コマンドは `~/.local/bin/hermes`、Claude Code と同じレイアウト）。ブラウザ自動化（Playwright/Chromium）込み。runtime state は `~/.hermes`（symlink 先 = `dotfiles/.hermes/`）に永続化し、host `~/.hermes` とは共有しない。`postCreate` で `skills-sh/obra/superpowers` を bootstrap する。初回利用時に `hermes setup` でプロバイダを設定する。
```

Add a short operational bullet near the dotfiles/runtime-state rules:

```markdown
- Hermes superpowers bootstrap は `.hermes` symlink 作成後に `agents-post-create` で実行する。`hermes skills install --yes skills-sh/obra/superpowers` が成功したら `dotfiles/.hermes/.agents-superpowers-installed` を marker とし、再実行時は skip する。network/registry failure は non-fatal warning として扱う。
```

- [ ] **Step 5: Run docs tests**

Run:

```bash
bats tests/hermes-install.bats
```

Expected: all tests in `tests/hermes-install.bats` pass.

- [ ] **Step 6: Commit task 2**

Run:

```bash
git add README.md .devcontainer/Agents.md tests/hermes-install.bats
git commit -m "docs(hermes-superpowers-bootstrap): document Hermes skill bootstrap"
```

---

### Task 3: full verification

**Files:**
- No code edits expected.

**Interfaces:**
- Consumes: completed Tasks 1-2.
- Produces: evidence that scripts parse and the full bats suite passes.

- [ ] **Step 1: Validate shell scripts**

Run:

```bash
for f in .devcontainer/scripts/*; do bash -n "$f"; done
```

Expected: no output and exit 0.

- [ ] **Step 2: Run full test suite**

Run:

```bash
bats tests/
```

Expected: all tests pass.

- [ ] **Step 3: Commit verification metadata if needed**

If no files changed during verification, do not create a commit. If tests generated tracked changes unexpectedly, inspect them and do not commit generated noise.

## Self-Review

- Spec coverage: AC1-5 are covered by Task 1; AC6-7 by Task 2; AC8 by Task 3.
- Placeholder scan: no placeholder red flags remain.
- Interface consistency: marker path is consistently `$HOME/.hermes/.agents-superpowers-installed`; install command is consistently `hermes skills install --yes skills-sh/obra/superpowers`.
