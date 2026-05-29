# SDD Normalization Design

## Summary

agents-devcontainer プロジェクト全体を ai-sdd-guide ベースの Spec-Driven Development に正規化する。
旧 SDD フレームワーク（OpenSpec）の残骸を削除し、agents-devcontainer 自身の開発と、
devcontainer を利用するプロジェクト向けテンプレートの両方で整合性を確保する。

## Motivation

- OpenSpec (`@fission-ai/openspec`) と ai-sdd-guide が共存しており、どちらが正かが不明瞭
- agents-devcontainer 自身が SDD を宣言しているが、`specs/` や `.sdd/state.json` が存在しない
- CI に spec gate がなく、SDD の実効性がない

## Scope

### In scope

1. OpenSpec の完全削除
2. agents-devcontainer 自身の SDD 基盤初期化（`specs/`, `.sdd/state.json`）
3. CI に sdd-check.yml を追加
4. `.devcontainer/Agents.md` の OpenSpec 記述を ai-sdd-guide に置き換え
5. README.md の OpenSpec 記述を ai-sdd-guide に置き換え

### Out of scope

- Codex CLI, Gemini CLI の変更（SDD はツール非依存）
- scaffold.sh のロジック変更（既に ai-sdd-guide 対応済み）
- ai-sdd-guide サブモジュール自体の変更

## Changes

### 1. OpenSpec の削除

#### `.devcontainer/Dockerfile.base`

- Line 40-41: `@fission-ai/openspec` を npm install から削除、コメント更新
  ```
  # Before
  # Install @google/gemini-cli, Codex CLI, and OpenSpec (spec-driven development) globally
  RUN npm install -g @google/gemini-cli @openai/codex @fission-ai/openspec

  # After
  # Install @google/gemini-cli and Codex CLI globally
  RUN npm install -g @google/gemini-cli @openai/codex
  ```

- Line 121: LABEL の description から OpenSpec を削除
  ```
  # Before
  org.opencontainers.image.description="General-purpose AI Agent devcontainer base image (Claude Code, Gemini CLI, Codex CLI, OpenSpec, uv, tmux, neovim, yazi)."

  # After
  org.opencontainers.image.description="General-purpose AI Agent devcontainer base image (Claude Code, Gemini CLI, Codex CLI, uv, tmux, neovim, yazi)."
  ```

#### `.devcontainer/dotfiles/.zshrc`

- Lines 85-88: OpenSpec エイリアスセクションを削除
  ```
  # Remove entirely:
  # ==============================================================================
  # Aliases — AI agent tooling (opt-in per project)
  # ==============================================================================
  # Initialize OpenSpec for the current workspace (writes .openspec/ + AGENTS.md).
  alias setup-openspec='openspec init --tools claude'
  ```

#### `.devcontainer/Agents.md`

- Line 92: OpenSpec の記述を ai-sdd-guide に置き換え
  ```
  # Before
  - `OpenSpec` (openspec) — Spec-Driven Development フレームワーク。プロジェクト初期化は `setup-openspec`（= `openspec init --tools claude`）を手動実行する。

  # After
  - `ai-sdd-guide` — Spec-Driven Development フレームワーク。`scaffold.sh` が git submodule として `vendor/ai-sdd-guide` に配置する。ルール: `vendor/ai-sdd-guide/rules/`、ドキュメント: `vendor/ai-sdd-guide/docs/`。
  ```

#### `README.md`

- 特徴欄の OpenSpec → ai-sdd-guide
  ```
  # Before
  - **OpenSpec**: AI コーディングアシスタント向けの Spec-Driven Development フレームワーク。

  # After
  - **ai-sdd-guide**: Spec-Driven Development (SDD) フレームワーク。scaffold.sh が自動で組み込む。
  ```

- OpenSpec セクション（lines 102-107）→ ai-sdd-guide セクション
  ```
  ### Spec-Driven Development (SDD)

  ai-sdd-guide による SDD フレームワーク。`scaffold.sh` 実行時に git submodule として自動配置される。

  - ルール: `vendor/ai-sdd-guide/rules/`
  - ドキュメント（日本語）: `vendor/ai-sdd-guide/docs/`
  - テンプレート: `vendor/ai-sdd-guide/templates/`
  ```

### 2. SDD 基盤の初期化

- `specs/.gitkeep` を作成（空ディレクトリ保持）
- `.sdd/state.json` を初期状態で作成:
  ```json
  {
    "feature": null,
    "tier": null,
    "phase": null
  }
  ```

### 3. CI に sdd-check.yml を追加

`.github/workflows/sdd-check.yml` を `vendor/ai-sdd-guide/integration/ci/sdd-check.yml` をベースに作成。
Tests ステップを `bats tests/` に置き換え:

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

### 4. `.devcontainer/Agents.md` の AI ツールセクション更新

OpenSpec の記述を削除し、ai-sdd-guide の記述に置き換える（上記参照）。

## Acceptance Criteria

1. `grep -ri openspec` がプロジェクト内でヒットしないこと
2. `specs/` ディレクトリと `.sdd/state.json` が存在すること
3. `.github/workflows/sdd-check.yml` が存在し、PR で spec gate が機能すること
4. `bats tests/` が全て通ること（既存テストが壊れていないこと）
5. `.devcontainer/Agents.md` と `README.md` が ai-sdd-guide を正として記載していること
