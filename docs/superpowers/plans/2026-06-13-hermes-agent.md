# Hermes Agent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preinstall NousResearch Hermes Agent into the devcontainer base image alongside Claude Code / Gemini CLI / Codex CLI, with a per-user layout and browser tools included.

**Architecture:** Add a single `RUN curl ... install.sh | bash -s -- --skip-setup` inside the existing `USER ubuntu` block of `.devcontainer/Dockerfile.base`, mirroring the Claude Code per-user install pattern. Update the image LABEL and docs. Verify the wiring with a grep-based bats test; rely on the CI `build-base-image` job as the integration test that the image actually builds.

**Tech Stack:** Docker (Ubuntu base), bash installer, bats-core tests, GitHub Actions.

---

### Task 1: Wiring test (RED)

**Files:**
- Create: `tests/hermes-install.bats`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bats

DOCKERFILE="$BATS_TEST_DIRNAME/../.devcontainer/Dockerfile.base"
README="$BATS_TEST_DIRNAME/../README.md"
AGENTS="$BATS_TEST_DIRNAME/../.devcontainer/Agents.md"

@test "installs Hermes Agent via the official installer" {
  grep -q "hermes-agent.nousresearch.com/install.sh" "$DOCKERFILE"
}

@test "installs Hermes per-user (inside the USER ubuntu block)" {
  # Print the current USER context (1 = ubuntu) on the installer line.
  run awk '
    /^USER ubuntu/ { u = 1 }
    /^USER root/   { u = 0 }
    /hermes-agent\.nousresearch\.com\/install\.sh/ { print u }
  ' "$DOCKERFILE"
  [ "$output" = "1" ]
}

@test "skips the interactive setup wizard" {
  grep -Eq "install\.sh \| bash -s -- .*--skip-setup" "$DOCKERFILE"
}

@test "keeps browser tools (no --skip-browser)" {
  run grep -- "--skip-browser" "$DOCKERFILE"
  [ "$status" -ne 0 ]
  run grep -- "--no-playwright" "$DOCKERFILE"
  [ "$status" -ne 0 ]
}

@test "image LABEL description lists Hermes Agent" {
  grep -q "Hermes Agent" "$DOCKERFILE"
}

@test "README lists Hermes Agent" {
  grep -q "Hermes Agent" "$README"
}

@test "Agents.md lists the hermes command" {
  grep -qi "hermes" "$AGENTS"
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats tests/hermes-install.bats`
Expected: FAIL (Dockerfile.base / README / Agents.md not yet edited).

- [ ] **Step 3: Commit**

```bash
git add tests/hermes-install.bats
git commit -m "test(hermes-agent): add wiring test for Hermes install (RED)"
```

---

### Task 2: Add Hermes install to Dockerfile.base (GREEN, part 1)

**Files:**
- Modify: `.devcontainer/Dockerfile.base` (USER ubuntu block ~lines 93-96; LABEL ~lines 114-116)

- [ ] **Step 1: Add the install RUN inside the `USER ubuntu` block**

Current block:

```dockerfile
USER ubuntu
RUN curl -fsSL https://claude.ai/install.sh | bash \
    && mkdir -p /home/ubuntu/.gh-config
USER root
```

Change to (insert a new RUN before `USER root`):

```dockerfile
USER ubuntu
RUN curl -fsSL https://claude.ai/install.sh | bash \
    && mkdir -p /home/ubuntu/.gh-config

# Install Hermes Agent (NousResearch) as the dev user. Per-user layout: code
# under ~/.hermes, the `hermes` command symlinked into ~/.local/bin — same as
# Claude Code, so it survives the start-time updateRemoteUserUID chown of $HOME.
# --skip-setup: no interactive provider wizard at build time (run `hermes setup`
# at runtime). Browser tools are included: the installer runs
# `npx playwright install --with-deps chromium`, using ubuntu's passwordless
# sudo for the apt system libraries.
RUN curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup
USER root
```

- [ ] **Step 2: Add "Hermes Agent" to the image LABEL description**

Current:

```dockerfile
LABEL org.opencontainers.image.source="https://github.com/toshikimiyagawa/agents-devcontainer" \
      org.opencontainers.image.description="General-purpose AI Agent devcontainer base image (Claude Code, Gemini CLI, Codex CLI, uv, tmux, neovim, yazi)." \
      org.opencontainers.image.licenses="MIT"
```

Change the description to:

```dockerfile
      org.opencontainers.image.description="General-purpose AI Agent devcontainer base image (Claude Code, Gemini CLI, Codex CLI, Hermes Agent, uv, tmux, neovim, yazi)." \
```

- [ ] **Step 3: Verify the wiring landed**

Run: `grep -n "hermes-agent.nousresearch.com\|Hermes Agent" .devcontainer/Dockerfile.base`
Expected: the install RUN line and the LABEL description line.

- [ ] **Step 4: Commit**

```bash
git add .devcontainer/Dockerfile.base
git commit -m "feat(hermes-agent): install Hermes Agent in the base image (per-user, browser included)"
```

---

### Task 3: Documentation (GREEN, part 2)

**Files:**
- Modify: `README.md` (line 4; the 特徴 bullet list after the Codex CLI line ~13)
- Modify: `.devcontainer/Agents.md` (AI・特定ツール list after the Codex CLI line ~91)

- [ ] **Step 1: README line 4 — add Hermes Agent to the inline list**

Current:

```
Claude Code, Gemini CLI, Codex CLI などのエージェントツールがプリインストールされており、すぐに開発を開始できる。
```

Change to:

```
Claude Code, Gemini CLI, Codex CLI, Hermes Agent などのエージェントツールがプリインストールされており、すぐに開発を開始できる。
```

- [ ] **Step 2: README 特徴 bullet — add a Hermes Agent bullet after Codex CLI**

Current:

```
  - **Codex CLI**: OpenAI によるターミナルベースの AI エージェント。
  - **ai-sdd-guide**: Spec-Driven Development (SDD) フレームワーク。プロジェクトに個別に導入する。
```

Change to (insert the Hermes line between them):

```
  - **Codex CLI**: OpenAI によるターミナルベースの AI エージェント。
  - **Hermes Agent**: NousResearch による自己改善型の自律 AI エージェント（永続メモリ・スキル学習・ブラウザ自動化）。初回利用時に `hermes setup` でプロバイダを設定する。
  - **ai-sdd-guide**: Spec-Driven Development (SDD) フレームワーク。プロジェクトに個別に導入する。
```

- [ ] **Step 3: `.devcontainer/Agents.md` — add a hermes entry after Codex CLI**

Current:

```
- `Codex CLI` (codex) — OpenAI によるターミナルベースの AI エージェント。
- `ai-sdd-guide` — Spec-Driven Development フレームワーク。`scaffold.sh` が git submodule として `vendor/ai-sdd-guide` に配置する。ルール: `vendor/ai-sdd-guide/rules/`、ドキュメント: `vendor/ai-sdd-guide/docs/`。
```

Change to (insert the Hermes line between them):

```
- `Codex CLI` (codex) — OpenAI によるターミナルベースの AI エージェント。
- `Hermes Agent` (hermes) — NousResearch による自己改善型の自律 AI エージェント。`USER ubuntu` で per-user インストール（コードは `~/.hermes`、コマンドは `~/.local/bin/hermes`、Claude Code と同じレイアウト）。ブラウザ自動化（Playwright/Chromium）込み。初回利用時に `hermes setup` でプロバイダを設定する。
- `ai-sdd-guide` — Spec-Driven Development フレームワーク。`scaffold.sh` が git submodule として `vendor/ai-sdd-guide` に配置する。ルール: `vendor/ai-sdd-guide/rules/`、ドキュメント: `vendor/ai-sdd-guide/docs/`。
```

- [ ] **Step 4: Run the wiring test — verify GREEN**

Run: `bats tests/hermes-install.bats`
Expected: all 7 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add README.md .devcontainer/Agents.md
git commit -m "docs(hermes-agent): list Hermes Agent in README and Agents.md"
```

---

### Task 4: Full verification + PR

- [ ] **Step 1: Run the full bats suite**

Run: `bats tests/`
Expected: all tests PASS (existing + new hermes-install.bats).

- [ ] **Step 2 (optional, if Docker available locally): build the base image**

Run: `docker build -t agents-base:dev -f .devcontainer/Dockerfile.base .`
Expected: build succeeds; near the end the log shows the Hermes installer running
(`Installing browser engine (Playwright Chromium)...`, then `hermes` command linked).

- [ ] **Step 3: Open the PR with the Tier label**

```bash
git push -u origin feat/hermes-agent
gh pr create --title "feat(hermes-agent): add Hermes Agent to the base image" \
  --body "$(cat <<'EOF'
## Summary
- Preinstall NousResearch Hermes Agent in Dockerfile.base (per-user ~/.local/bin, browser tools included, --skip-setup).
- Update README / Agents.md / image LABEL.
- Add tests/hermes-install.bats wiring test.

See specs/hermes-agent/ for the frozen spec.

## Test plan
- [ ] `bats tests/` passes
- [ ] CI `build-base-image` (amd64 build-only) succeeds
EOF
)"
gh pr edit --add-label "sdd:tier-2"
```

- [ ] **Step 4: Wait for CI and confirm green**

Run: `gh pr checks --watch`
Expected: `build-base-image` and `sdd-check` pass; PR is mergeable.

---

## Notes / risks (for the implementer)

- **Browser install needs sudo:** works because the `ubuntu` user has passwordless sudo
  (`/etc/sudoers.d/ubuntu`). The installer detects `sudo -n true` and runs
  `npx playwright install --with-deps chromium`.
- **No interactive wizard at build:** the installer probes `/dev/tty`; in Docker build it
  cannot open it and auto-skips. `--skip-setup` makes the intent explicit.
- **Node not duplicated:** installer reuses the existing Node (NodeSource `setup_20.x`,
  ≥20.19 satisfies `node_satisfies_build`), so it does not add its own Node 22 / PATH symlinks.
- **Image size / build time grow** due to Chromium + node_modules — expected and accepted.
