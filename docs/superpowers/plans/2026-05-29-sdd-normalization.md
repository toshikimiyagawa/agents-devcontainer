# SDD Normalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove OpenSpec references and normalize the project to use ai-sdd-guide as the sole SDD framework, including SDD infrastructure for agents-devcontainer itself.

**Architecture:** Delete OpenSpec from Docker image, shell config, and documentation. Add `specs/`, `.sdd/state.json`, and `sdd-check.yml` CI workflow. Update all docs to reference ai-sdd-guide.

**Tech Stack:** Dockerfile, shell (zsh), GitHub Actions YAML, Markdown

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `.devcontainer/Dockerfile.base` | Remove `@fission-ai/openspec` from npm install, update comment and LABEL |
| Modify | `.devcontainer/dotfiles/.zshrc` | Remove `setup-openspec` alias section |
| Modify | `.devcontainer/Agents.md` | Replace OpenSpec description with ai-sdd-guide |
| Modify | `README.md` | Replace OpenSpec references with ai-sdd-guide |
| Create | `specs/.gitkeep` | Preserve empty specs directory |
| Create | `.sdd/state.json` | SDD state tracking for the project |
| Create | `.github/workflows/sdd-check.yml` | Spec gate + tests for PRs |

---

### Task 1: Remove OpenSpec from Dockerfile.base

**Files:**
- Modify: `.devcontainer/Dockerfile.base:40-41` (npm install line)
- Modify: `.devcontainer/Dockerfile.base:121` (LABEL)

- [ ] **Step 1: Remove `@fission-ai/openspec` from npm install**

Change line 40-41 from:
```dockerfile
# Install @google/gemini-cli, Codex CLI, and OpenSpec (spec-driven development) globally
RUN npm install -g @google/gemini-cli @openai/codex @fission-ai/openspec
```
to:
```dockerfile
# Install @google/gemini-cli and Codex CLI globally
RUN npm install -g @google/gemini-cli @openai/codex
```

- [ ] **Step 2: Remove OpenSpec from LABEL**

Change line 121 from:
```dockerfile
      org.opencontainers.image.description="General-purpose AI Agent devcontainer base image (Claude Code, Gemini CLI, Codex CLI, OpenSpec, uv, tmux, neovim, yazi)." \
```
to:
```dockerfile
      org.opencontainers.image.description="General-purpose AI Agent devcontainer base image (Claude Code, Gemini CLI, Codex CLI, uv, tmux, neovim, yazi)." \
```

- [ ] **Step 3: Verify no OpenSpec references remain in Dockerfile.base**

Run: `grep -i openspec .devcontainer/Dockerfile.base`
Expected: no output

- [ ] **Step 4: Commit**

```bash
git add .devcontainer/Dockerfile.base
git commit -m "refactor(docker): remove OpenSpec from base image"
```

---

### Task 2: Remove OpenSpec alias from .zshrc

**Files:**
- Modify: `.devcontainer/dotfiles/.zshrc:84-88`

- [ ] **Step 1: Delete the OpenSpec alias section**

Remove these lines (84-88):
```zsh
# ==============================================================================
# Aliases — AI agent tooling (opt-in per project)
# ==============================================================================
# Initialize OpenSpec for the current workspace (writes .openspec/ + AGENTS.md).
alias setup-openspec='openspec init --tools claude'
```

- [ ] **Step 2: Verify no OpenSpec references remain in .zshrc**

Run: `grep -i openspec .devcontainer/dotfiles/.zshrc`
Expected: no output

- [ ] **Step 3: Commit**

```bash
git add .devcontainer/dotfiles/.zshrc
git commit -m "refactor(dotfiles): remove OpenSpec alias from .zshrc"
```

---

### Task 3: Update .devcontainer/Agents.md

**Files:**
- Modify: `.devcontainer/Agents.md:92`

- [ ] **Step 1: Replace OpenSpec entry with ai-sdd-guide**

Change line 92 from:
```markdown
- `OpenSpec` (openspec) — Spec-Driven Development フレームワーク。プロジェクト初期化は `setup-openspec`（= `openspec init --tools claude`）を手動実行する。
```
to:
```markdown
- `ai-sdd-guide` — Spec-Driven Development フレームワーク。`scaffold.sh` が git submodule として `vendor/ai-sdd-guide` に配置する。ルール: `vendor/ai-sdd-guide/rules/`、ドキュメント: `vendor/ai-sdd-guide/docs/`。
```

- [ ] **Step 2: Verify no OpenSpec references remain in Agents.md**

Run: `grep -i openspec .devcontainer/Agents.md`
Expected: no output

- [ ] **Step 3: Commit**

```bash
git add .devcontainer/Agents.md
git commit -m "docs(agents): replace OpenSpec with ai-sdd-guide"
```

---

### Task 4: Update README.md

**Files:**
- Modify: `README.md:14` (feature list)
- Modify: `README.md:102-108` (OpenSpec section)

- [ ] **Step 1: Replace OpenSpec in feature list**

Change line 14 from:
```markdown
  - **OpenSpec**: AI コーディングアシスタント向けの Spec-Driven Development フレームワーク。
```
to:
```markdown
  - **ai-sdd-guide**: Spec-Driven Development (SDD) フレームワーク。scaffold.sh が自動で組み込む。
```

- [ ] **Step 2: Replace OpenSpec section with SDD section**

Change lines 102-108 from:
```markdown
### OpenSpec

Spec-Driven Development フレームワーク。コンテナ内で1回実行すれば `.openspec/` と Claude Code 用スラッシュコマンドが入る。

```bash
setup-openspec   # = openspec init --tools claude
```
```

to:
```markdown
### Spec-Driven Development (SDD)

ai-sdd-guide による SDD フレームワーク。`scaffold.sh` 実行時に git submodule として自動配置される。

- ルール: `vendor/ai-sdd-guide/rules/`
- ドキュメント（日本語）: `vendor/ai-sdd-guide/docs/`
- テンプレート: `vendor/ai-sdd-guide/templates/`
```

- [ ] **Step 3: Verify no OpenSpec references remain in README.md**

Run: `grep -i openspec README.md`
Expected: no output

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs(readme): replace OpenSpec with ai-sdd-guide"
```

---

### Task 5: Initialize SDD infrastructure

**Files:**
- Create: `specs/.gitkeep`
- Create: `.sdd/state.json`

- [ ] **Step 1: Create specs directory with .gitkeep**

```bash
mkdir -p specs
touch specs/.gitkeep
```

- [ ] **Step 2: Create .sdd/state.json**

Create `.sdd/state.json` with initial state:
```json
{
  "feature": null,
  "tier": null,
  "phase": null
}
```

- [ ] **Step 3: Commit**

```bash
git add specs/.gitkeep .sdd/state.json
git commit -m "feat(sdd): initialize specs/ and .sdd/state.json"
```

---

### Task 6: Add sdd-check.yml CI workflow

**Files:**
- Create: `.github/workflows/sdd-check.yml`

- [ ] **Step 1: Create sdd-check.yml**

Create `.github/workflows/sdd-check.yml`:
```yaml
name: SDD Check
on:
  pull_request:

jobs:
  sdd:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Spec gate
        run: |
          base="${{ github.event.pull_request.base.sha }}"
          changed="$(git diff --name-only "$base"...HEAD)"
          src="$(echo "$changed" | grep -vE '^(docs/|specs/|\.sdd/|vendor/|\.claude/|\.github/|\.devcontainer/|\.[^/]+$|.*\.md$)' || true)"

          labels='${{ toJSON(github.event.pull_request.labels.*.name) }}'
          if echo "$labels" | grep -q 'sdd:tier-0'; then
            echo "Tier 0 — spec gate skipped."; exit 0
          fi
          if [ -z "$src" ]; then
            echo "No source changes — spec gate skipped."; exit 0
          fi
          if ! ls specs/*/spec.md >/dev/null 2>&1; then
            echo "::error::Source changed but no specs/<feature>/spec.md found. Add a spec or label the PR 'sdd:tier-0'."
            exit 1
          fi
          echo "Spec present."

      - name: Install bats-core
        uses: bats-core/bats-action@3.0.0

      - name: Install yq
        run: sudo snap install yq

      - name: Tests
        run: bats tests/
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/sdd-check.yml
git commit -m "ci(sdd): add spec gate and test workflow for PRs"
```

---

### Task 7: Final verification

- [ ] **Step 1: Verify no OpenSpec references remain in the project**

Run: `grep -ri openspec --include='*.md' --include='*.sh' --include='*.yml' --include='*.zshrc' --include='Dockerfile*' .`
Expected: no output (vendor/ may contain references but that's the submodule, not this project)

- [ ] **Step 2: Verify SDD infrastructure exists**

```bash
test -f specs/.gitkeep && echo "specs/ OK"
test -f .sdd/state.json && echo ".sdd/state.json OK"
test -f .github/workflows/sdd-check.yml && echo "sdd-check.yml OK"
```
Expected: all three OK

- [ ] **Step 3: Run tests**

Run: `bats tests/`
Expected: all tests pass

- [ ] **Step 4: Verify with grep that ai-sdd-guide is referenced in docs**

```bash
grep -l 'ai-sdd-guide' README.md .devcontainer/Agents.md
```
Expected: both files listed
