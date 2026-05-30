# Decouple SDD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `agents-devcontainer` の `scaffold.sh` から ai-sdd-guide の配布責務を外し、devcontainer 管理専用にする。

**Architecture:** ai-sdd-guide に `integration/update.sh` を追加して SDD ファイル更新のエントリポイントを移す。`scaffold.sh` の SDD セクション（ai-sdd-guide submodule 追加・integration ファイルコピー）を削除する。`sdd-update.sh` と対応テストを削除する。agents-devcontainer 自身の開発では `vendor/ai-sdd-guide` submodule を引き続き保持する。

**Tech Stack:** Bash, bats-core, git submodule

---

## File Map

| ファイル | アクション | 説明 |
|---|---|---|
| `vendor/ai-sdd-guide/integration/update.sh` | 新規作成（別リポジトリ） | managed/protected ロジックを ai-sdd-guide 側に移動 |
| `scaffold.sh` | 変更 | SDD セクション削除（lines 11–12, 21–23, 139–189） |
| `scaffold/sdd-update.sh` | 削除 | 責務が update.sh に移動したため不要 |
| `tests/scaffold.bats` | 変更 | SDD fixture・SDD テスト削除、AGENTS_SDD_GUIDE_URL 除去 |
| `tests/sdd-update.bats` | 削除 | sdd-update.sh 削除に伴い削除 |
| `README.md` | 変更 | SDD 自動セットアップ記述を削除、独立管理の案内を追加 |

---

## Task 1: ai-sdd-guide に `integration/update.sh` を追加

**Files:**
- Create: `vendor/ai-sdd-guide/integration/update.sh`（ai-sdd-guide リポジトリ内）

このタスクは `vendor/ai-sdd-guide/` サブモジュール内で作業する。完了後に agents-devcontainer の submodule ref を更新する。

- [ ] **Step 1: update.sh を作成**

```bash
cat > vendor/ai-sdd-guide/integration/update.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

INTEGRATION="$(cd "$(dirname "$0")" && pwd)"
PROJECT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

log() { printf '[update.sh] %s\n' "$*"; }

# --- Managed: always overwrite ---

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

# --- Protected: create if absent, diff if changed ---

protected=(
  "CLAUDE.md:$INTEGRATION/CLAUDE.md.example"
  "AGENTS.md:$INTEGRATION/AGENTS.md.example"
  ".claude/settings.json:$INTEGRATION/settings.json.example"
)

for entry in "${protected[@]}"; do
  rel="${entry%%:*}"
  src="${entry#*:}"
  dest="$PROJECT/$rel"

  if [[ ! -f "$src" ]]; then continue; fi

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
EOF
chmod +x vendor/ai-sdd-guide/integration/update.sh
```

- [ ] **Step 2: 動作確認**

```bash
# 一時ディレクトリで動作テスト
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/project"
vendor/ai-sdd-guide/integration/update.sh "$TMPDIR/project"
ls "$TMPDIR/project/.claude/agents/"
ls "$TMPDIR/project/.github/workflows/"
rm -rf "$TMPDIR"
```

Expected: `sdd-reviewer.md` と `sdd-check.yml` が生成されていること、エラーなし

- [ ] **Step 3: ai-sdd-guide リポジトリにコミット・push**

```bash
cd vendor/ai-sdd-guide
git add integration/update.sh
git -c user.name="$(git config user.name)" -c user.email="$(git config user.email)" \
  commit -m "feat(integration): add update.sh for consuming project SDD file sync"
git push origin HEAD
cd ../..
```

- [ ] **Step 4: agents-devcontainer の submodule reference を更新**

```bash
git add vendor/ai-sdd-guide
git commit -m "chore(decouple-sdd): update ai-sdd-guide submodule ref (add integration/update.sh)"
```

---

## Task 2: scaffold.sh の SDD セクション削除 + scaffold.bats の SDD テスト削除

**Files:**
- Modify: `scaffold.sh`
- Modify: `tests/scaffold.bats`

scaffold.sh と scaffold.bats は密結合しているので同一タスクで変更し、テストが通ることを確認してからコミットする。

- [ ] **Step 1: scaffold.sh を編集**

現在の `scaffold.sh` の先頭（lines 1–25）を以下に置き換える:

```bash
#!/usr/bin/env bash
# Scaffold a minimal .devcontainer/ that consumes the agents-devcontainer base image.
#
# Usage:
#   bash scaffold.sh [TARGET_DIR]       # defaults to current directory
#
# To pin a specific version:
#   AGENTS_DEVCONTAINER_TAG=v0.1.0 bash scaffold.sh ~/code/myproject
#
# Remote usage:
#   curl -fsSL https://raw.githubusercontent.com/toshikimiyagawa/agents-devcontainer/main/scaffold.sh | bash
set -euo pipefail

TARGET="${1:-$PWD}"
TAG="${AGENTS_DEVCONTAINER_TAG:-latest}"
DC="$TARGET/.devcontainer"
ADC_URL="${AGENTS_DEVCONTAINER_URL:-https://github.com/toshikimiyagawa/agents-devcontainer.git}"
ADC_DIR="$TARGET/vendor/agents-devcontainer"
```

次に `# --- SDD (ai-sdd-guide) setup ---` から `fi` までの行（lines 139–189）を削除する。削除後、`echo ""` で始まる "Next steps:" セクション（現 line 191）がファイル末尾の処理になる。

- [ ] **Step 2: tests/scaffold.bats の setup() を更新**

`setup()` 関数（lines 5–41）を以下に置き換える（SDD fixture を削除、sdd-update.sh のコピーを削除）:

```bash
setup() {
  TMPDIR="$(mktemp -d)"
  TARGET="$TMPDIR/myproject"
  mkdir -p "$TARGET"

  export GIT_CONFIG_COUNT=1
  export GIT_CONFIG_KEY_0=protocol.file.allow
  export GIT_CONFIG_VALUE_0=always

  # --- agents-devcontainer fixture ---
  ADC_BARE="$TMPDIR/agents-devcontainer.git"
  git init --bare "$ADC_BARE" >/dev/null 2>&1

  ADC_WORK="$TMPDIR/adc-work"
  git clone "$ADC_BARE" "$ADC_WORK" >/dev/null 2>&1
  mkdir -p "$ADC_WORK/scaffold"
  cp "$BATS_TEST_DIRNAME/../scaffold/devcontainer.base.json" "$ADC_WORK/scaffold/"
  cp "$BATS_TEST_DIRNAME/../scaffold/merge.sh"               "$ADC_WORK/scaffold/"
  (cd "$ADC_WORK" && git add -A && git -c user.name=test -c user.email=test@test.com commit -m "init" >/dev/null 2>&1)
  (cd "$ADC_WORK" && git push >/dev/null 2>&1)
}
```

- [ ] **Step 3: tests/scaffold.bats の全テストから `AGENTS_SDD_GUIDE_URL="$SDD_BARE"` を削除**

以下の各テストの `env` 行から `AGENTS_SDD_GUIDE_URL="$SDD_BARE"` を除去する（`replace_all` で一括置換可能）:

変更前パターン: `AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash`
変更後パターン: `AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash`

変更前パターン: `env AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash`
変更後パターン: `env AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash`

変更前パターン: `AGENTS_DEVCONTAINER_TAG=v1.2.3 AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash`
変更後パターン: `AGENTS_DEVCONTAINER_TAG=v1.2.3 AGENTS_DEVCONTAINER_URL="$ADC_BARE" bash`

変更前パターン: `AGENTS_DEVCONTAINER_SDD=0 AGENTS_DEVCONTAINER_URL="$ADC_BARE" AGENTS_SDD_GUIDE_URL="$SDD_BARE" bash`
→ このテスト自体を削除するので対応不要

- [ ] **Step 4: tests/scaffold.bats の SDD テストセクションを削除**

以下の行範囲をファイルから削除する（コメント行を含む）:

```
# --- SDD integration ----------------------------------------------------------

@test "adds ai-sdd-guide submodule" { ... }
@test "copies CLAUDE.md from integration" { ... }
@test "copies AGENTS.md from integration" { ... }
@test "copies .claude/settings.json from integration" { ... }
@test "copies .claude/agents/ from integration" { ... }
@test "copies .github/workflows/sdd-check.yml from integration" { ... }

# --- SDD opt-out ---------------------------------------------------------------

@test "AGENTS_DEVCONTAINER_SDD=0 skips SDD setup" { ... }

# --- SDD skip existing files ---------------------------------------------------

@test "does not overwrite existing CLAUDE.md" { ... }
@test "does not overwrite existing AGENTS.md" { ... }
@test "does not overwrite existing .claude/settings.json" { ... }
@test "skips submodule add when vendor/ai-sdd-guide already exists" { ... }

# --- SDD requires git repo ----------------------------------------------------

@test "skips SDD setup when target is not a git repo" { ... }
```

- [ ] **Step 5: テストが通ることを確認**

```bash
bats tests/scaffold.bats
```

Expected: 全件 PASS（SDD テストが削除されているため件数が減っていること、残りのテストが全て通ること）

- [ ] **Step 6: コミット**

```bash
git add scaffold.sh tests/scaffold.bats
git commit -m "feat(decouple-sdd): remove SDD setup from scaffold.sh and scaffold.bats"
```

---

## Task 3: `scaffold/sdd-update.sh` と `tests/sdd-update.bats` を削除

**Files:**
- Delete: `scaffold/sdd-update.sh`
- Delete: `tests/sdd-update.bats`

- [ ] **Step 1: ファイルを削除**

```bash
git rm scaffold/sdd-update.sh
git rm tests/sdd-update.bats
```

- [ ] **Step 2: 全テストが通ることを確認**

```bash
bats tests/
```

Expected: 全件 PASS

- [ ] **Step 3: コミット**

```bash
git commit -m "feat(decouple-sdd): delete sdd-update.sh and sdd-update.bats"
```

---

## Task 4: README.md の更新

**Files:**
- Modify: `README.md`

- [ ] **Step 1: 特徴欄の SDD 記述を更新**

以下を変更する:

変更前:
```markdown
  - **ai-sdd-guide**: Spec-Driven Development (SDD) フレームワーク。scaffold.sh が自動で組み込む。
- **モダンな開発ツール**: uv (Python), Neovim, Tmux, Lazygit, Yazi 等を同梱。
- **SDD (Spec-Driven Development) 統合**: scaffold 時に [ai-sdd-guide](https://github.com/toshikimiyagawa/ai-sdd-guide) を submodule として自動導入。
```

変更後:
```markdown
  - **ai-sdd-guide**: Spec-Driven Development (SDD) フレームワーク。プロジェクトに個別に導入する。
- **モダンな開発ツール**: uv (Python), Neovim, Tmux, Lazygit, Yazi 等を同梱。
```

- [ ] **Step 2: scaffold 使用例の SDD 記述を削除**

変更前:
```markdown
```bash
# プロジェクトディレクトリで実行（git リポジトリ内で実行すると SDD も自動セットアップ）
curl -fsSL https://raw.githubusercontent.com/toshikimiyagawa/agents-devcontainer/main/scaffold.sh | bash

# バージョンを固定する場合
AGENTS_DEVCONTAINER_TAG=v0.1.0 bash scaffold.sh

# SDD セットアップをスキップする場合
AGENTS_DEVCONTAINER_SDD=0 bash scaffold.sh
```

スクリプトは以下を行います:
- `vendor/agents-devcontainer` を submodule として追加（git リポジトリの場合）
- `.devcontainer/` の生成（既に存在する場合はスキップ）
- `devcontainer.project.json` の生成（プロジェクト固有の設定用）
- `merge.sh` で `devcontainer.json` を生成
- `ai-sdd-guide` を `vendor/ai-sdd-guide` に submodule として追加
- integration ファイル（`CLAUDE.md`, `AGENTS.md`, `.claude/settings.json`, `.claude/agents/`, `.github/workflows/sdd-check.yml`）のコピー（既存ファイルは上書きしない）

`.devcontainer` が既にあるリポジトリでも実行可能で、SDD セットアップのみ行われます。
```

変更後:
```markdown
```bash
# プロジェクトディレクトリで実行
curl -fsSL https://raw.githubusercontent.com/toshikimiyagawa/agents-devcontainer/main/scaffold.sh | bash

# バージョンを固定する場合
AGENTS_DEVCONTAINER_TAG=v0.1.0 bash scaffold.sh
```

スクリプトは以下を行います:
- `vendor/agents-devcontainer` を submodule として追加（git リポジトリの場合）
- `.devcontainer/` の生成（既に存在する場合はスキップ）
- `devcontainer.project.json` の生成（プロジェクト固有の設定用）
- `merge.sh` で `devcontainer.json` を生成

`.devcontainer` が既にあるリポジトリでも実行可能です。
```

- [ ] **Step 3: "SDD 統合ファイルの更新" セクションを更新**

変更前:
```markdown
### SDD 統合ファイルの更新

```bash
vendor/agents-devcontainer/scaffold/sdd-update.sh
```

`.claude/agents/` と `.github/workflows/sdd-check.yml` を上書き更新します。
`CLAUDE.md`, `AGENTS.md`, `.claude/settings.json` は保護対象で上書きしません（diff のみ表示）。
```

変更後:
```markdown
### SDD 統合ファイルの更新

SDD ファイルの更新は ai-sdd-guide submodule を直接更新してから `integration/update.sh` を実行します:

```bash
git submodule update --remote vendor/ai-sdd-guide
vendor/ai-sdd-guide/integration/update.sh
```

`.claude/agents/` と `.github/workflows/sdd-check.yml` を上書き更新します。
`CLAUDE.md`, `AGENTS.md`, `.claude/settings.json` は保護対象で上書きしません（diff のみ表示）。
```

- [ ] **Step 4: "Spec-Driven Development (SDD)" セクションを更新**

変更前:
```markdown
### Spec-Driven Development (SDD)

ai-sdd-guide による SDD フレームワーク。`scaffold.sh` 実行時に git submodule として自動配置される。

- ルール: `vendor/ai-sdd-guide/rules/`
- ドキュメント（日本語）: `vendor/ai-sdd-guide/docs/`
- テンプレート: `vendor/ai-sdd-guide/templates/`
```

変更後:
```markdown
### Spec-Driven Development (SDD)

ai-sdd-guide による SDD フレームワーク。agents-devcontainer とは独立して導入する。

```bash
git submodule add https://github.com/toshikimiyagawa/ai-sdd-guide.git vendor/ai-sdd-guide
vendor/ai-sdd-guide/integration/update.sh
```

> **Note:** `git submodule update --init` で agents-devcontainer を取得する際、`--recursive` は不要です。
> agents-devcontainer の内部に ai-sdd-guide が含まれていますが、消費プロジェクトへの影響はありません。

- ルール: `vendor/ai-sdd-guide/rules/`
- ドキュメント（日本語）: `vendor/ai-sdd-guide/docs/`
- テンプレート: `vendor/ai-sdd-guide/templates/`
```

- [ ] **Step 5: 既存プロジェクトからの移行手順の ai-sdd-guide 部分を削除**

"既存プロジェクトからの移行手順" の numbered list から ai-sdd-guide に関する記述があれば削除する（devcontainer 部分のみ残す）。

- [ ] **Step 6: コミット**

```bash
git add README.md
git commit -m "docs(decouple-sdd): update README to reflect SDD independence from scaffold"
```

---

## 完了チェックリスト

- [ ] `bats tests/` が全件 PASS（sdd-update.bats 削除後なので件数が減っていること）
- [ ] `grep -ri "ai-sdd-guide" scaffold.sh` がヒットしないこと
- [ ] `vendor/ai-sdd-guide/integration/update.sh` が存在し実行可能なこと
- [ ] `scaffold/sdd-update.sh` が存在しないこと
- [ ] `tests/sdd-update.bats` が存在しないこと
- [ ] `specs/decouple-sdd/spec.md` の AC 1–6 が全て満たされていること
