# development-rules Implementation Plan

> **SUPERSEDED (2026-06-23):** PR #54 のレビューで、この初版計画が定義した
> `implementation_complete` / `issue_complete` status・存在確認のみの smoke 証跡は撤回された。
> 正本は `specs/development-rules/` の re-frozen 版（canonical phase+status・証跡内容検証・
> fail-closed gate）。本ファイルは設計履歴として残す。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 開発ルール・phase gates・DoD を AGENTS.md に集約し、`scripts/pre-pr-check.sh` と PR template で PR 前検証を自動化する。

**Architecture:** 3 層構造（Layer 1: AGENTS.md + docs/development/、Layer 2: pre-pr-check.sh + PR template + CI、Layer 3: .sdd/tasks.json status + .sdd/smoke-evidence.txt）。TDD: tests/pre-pr-check.bats を先に書き RED を確認してから scripts/pre-pr-check.sh を実装する。

**Tech Stack:** bash, bats-core, jq, GitHub Actions

---

## File structure

### 新規作成
- `scripts/pre-pr-check.sh` — PR 前ローカル実行の単一エントリポイント
- `tests/pre-pr-check.bats` — pre-pr-check.sh の Bats テスト
- `docs/development/environment-matrix.md` — 環境ごとの可否の詳細解説
- `docs/development/smoke-guide.md` — OS 別 smoke 実行手順
- `docs/development/blocker-handling.md` — blocked issue テンプレート
- `.github/pull_request_template.md` — PR 記入必須テンプレート
- `specs/development-rules/spec.md` — frozen spec
- `specs/development-rules/plan.md` — plan サマリ
- `specs/development-rules/tasks.md` — タスクチェックリスト

### 修正
- `AGENTS.md` — 5 セクション追加（environment matrix / phase gates / DoD / reporting template / blocker handling）
- `.gitignore` — `.sdd/smoke-evidence.txt` を追加
- `.github/workflows/smoke-devcontainer.yml` — smoke 結果を artifact として保存

---

### Task 1: tests/pre-pr-check.bats を書く（RED）

**Files:**
- Create: `tests/pre-pr-check.bats`

- [ ] `tests/pre-pr-check.bats` を作成する：

```bash
#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../scripts/pre-pr-check.sh"

setup() {
  REPO="$(mktemp -d)"
  BIN="$(mktemp -d)"
  mkdir -p "$REPO/.devcontainer/scripts" "$REPO/scripts" "$REPO/tests" "$REPO/.sdd"

  # bash -n チェック用の正常スクリプト
  printf '#!/usr/bin/env bash\necho ok\n' > "$REPO/.devcontainer/scripts/good-script"
  printf '#!/usr/bin/env bash\necho ok\n' > "$REPO/scripts/good.sh"

  export REPO BIN
  export REPO_ROOT="$REPO"
  export GIT_BIN="$BIN/git"
  export BATS_BIN="$BIN/bats"
  JQ_BIN="$(command -v jq)"
  export JQ_BIN

  _make_git "feature-branch" ""
  _make_bats 0
}

teardown() {
  rm -rf "$REPO" "$BIN"
}

_make_git() {
  local branch="$1" changed="$2"
  cat > "$BIN/git" <<SH
#!/usr/bin/env bash
for arg in "\$@"; do
  case "\$arg" in
    --abbrev-ref) printf '%s\n' "$branch"; exit 0 ;;
    --name-only)  printf '%s\n' "$changed"; exit 0 ;;
  esac
done
SH
  chmod +x "$BIN/git"
}

_make_bats() {
  local code="$1"
  printf '#!/usr/bin/env bash\nexit %s\n' "$code" > "$BIN/bats"
  chmod +x "$BIN/bats"
}

@test "exits 1 when on main branch" {
  _make_git "main" ""
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "main branch" ]]
}

@test "exits 1 when bats tests fail" {
  _make_bats 1
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "bats" ]]
}

@test "exits 1 when a script has a syntax error" {
  printf '#!/usr/bin/env bash\nif\n' > "$REPO/.devcontainer/scripts/bad-script"
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "syntax error" ]]
}

@test "exits 0 when no devcontainer changes and no tasks.json" {
  _make_git "feature-branch" "README.md"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "exits 1 when devcontainer change detected but no smoke evidence" {
  _make_git "feature-branch" ".devcontainer/scripts/new-script"
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "smoke-evidence.txt" ]]
}

@test "exits 0 when devcontainer change detected and smoke evidence present" {
  _make_git "feature-branch" ".devcontainer/scripts/new-script"
  printf 'smoke passed\n' > "$REPO/.sdd/smoke-evidence.txt"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "exits 1 when tasks.json has blocked tasks" {
  printf '[{"id":"foo","status":"blocked","blocked_reason":"test"}]\n' \
    > "$REPO/.sdd/tasks.json"
  _make_git "feature-branch" "README.md"
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "blocked" ]]
}

@test "exits 0 when tasks.json has no blocked tasks" {
  printf '[{"id":"foo","status":"implementation_complete"}]\n' \
    > "$REPO/.sdd/tasks.json"
  _make_git "feature-branch" "README.md"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}
```

- [ ] RED を確認する：

```bash
bats tests/pre-pr-check.bats
```

期待: `scripts/pre-pr-check.sh: No such file or directory` 等でテストが全て失敗する。

- [ ] コミット：

```bash
git add tests/pre-pr-check.bats
git commit -m "test(development-rules): add RED tests for pre-pr-check.sh"
```

---

### Task 2: scripts/pre-pr-check.sh を実装する（GREEN）

**Files:**
- Create: `scripts/pre-pr-check.sh`

- [ ] `scripts/pre-pr-check.sh` を作成する：

```bash
#!/usr/bin/env bash
set -euo pipefail

BATS_BIN="${BATS_BIN:-bats}"
GIT_BIN="${GIT_BIN:-git}"
JQ_BIN="${JQ_BIN:-jq}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

fail() { printf '[pre-pr-check] ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '[pre-pr-check] %s\n' "$*"; }

# 1. feature branch 上にいることを確認
branch="$("$GIT_BIN" -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
if [ "$branch" = "main" ]; then
  fail "On main branch. Create a feature branch first."
fi
info "branch: $branch ✓"

# 2. bats tests/
if ! "$BATS_BIN" "$REPO_ROOT/tests/"; then
  fail "bats tests/ failed."
fi
info "bats tests/ ✓"

# 3. bash -n で全スクリプトの構文確認
bash_n_failed=0
for f in "$REPO_ROOT/.devcontainer/scripts/"* "$REPO_ROOT/scripts/"*.sh; do
  [ -f "$f" ] || continue
  if ! bash -n "$f" 2>/dev/null; then
    printf '[pre-pr-check] ERROR: syntax error in %s\n' "$f" >&2
    bash_n_failed=1
  fi
done
[ "$bash_n_failed" -eq 0 ] || fail "bash -n check found syntax errors."
info "bash -n ✓"

# 4. devcontainer 関連パス変更 → smoke 証跡が必要
# smoke-devcontainer.yml の paths: と同期を保つこと
changed="$("$GIT_BIN" -C "$REPO_ROOT" diff --name-only "origin/main...HEAD" 2>/dev/null || \
           "$GIT_BIN" -C "$REPO_ROOT" diff --name-only "HEAD" 2>/dev/null || true)"

needs_smoke=0
while IFS= read -r file; do
  [ -z "$file" ] && continue
  case "$file" in
    .devcontainer/*|dotfiles/*|scaffold.sh|scaffold/*|\
    scripts/smoke-devcontainer.sh|tests/smoke-devcontainer.bats|\
    .github/workflows/smoke-devcontainer.yml)
      needs_smoke=1
      break
      ;;
  esac
done <<< "$changed"

if [ "$needs_smoke" -eq 1 ]; then
  evidence="$REPO_ROOT/.sdd/smoke-evidence.txt"
  if [ ! -f "$evidence" ]; then
    fail "devcontainer-related changes detected but .sdd/smoke-evidence.txt not found.
Run: mkdir -p .sdd && scripts/smoke-devcontainer.sh 2>&1 | tee .sdd/smoke-evidence.txt"
  fi
  info "smoke evidence ✓"
else
  info "no devcontainer-related changes, smoke not required"
fi

# 5. .sdd/tasks.json に blocked タスクがないことを確認
tasks_json="$REPO_ROOT/.sdd/tasks.json"
if [ -f "$tasks_json" ]; then
  blocked_count="$("$JQ_BIN" '[.[] | select(.status=="blocked")] | length' "$tasks_json")"
  if [ "$blocked_count" -gt 0 ]; then
    fail "$blocked_count blocked task(s) in .sdd/tasks.json. Resolve before creating a PR."
  fi
  info "tasks.json ✓"
fi

info "All pre-PR checks passed. You may now create a PR."
```

- [ ] `chmod +x scripts/pre-pr-check.sh` を実行する

- [ ] GREEN を確認する：

```bash
bats tests/pre-pr-check.bats
```

期待: 8 tests, 0 failures

- [ ] 構文確認：

```bash
bash -n scripts/pre-pr-check.sh
```

期待: 出力なし（exit 0）

- [ ] コミット：

```bash
git add scripts/pre-pr-check.sh
git commit -m "feat(development-rules): add scripts/pre-pr-check.sh"
```

---

### Task 3: .gitignore と smoke-devcontainer.yml を更新する

**Files:**
- Modify: `.gitignore`
- Modify: `.github/workflows/smoke-devcontainer.yml`

- [ ] `.gitignore` に以下を追記する（既存の末尾に追加）：

```
# smoke 証跡（ローカル実行、コミット不要）
.sdd/smoke-evidence.txt
```

- [ ] `.github/workflows/smoke-devcontainer.yml` の `Run full devcontainer smoke` ステップを以下に置き換える：

現在:
```yaml
      - name: Run full devcontainer smoke
        run: scripts/smoke-devcontainer.sh
```

置き換え後:
```yaml
      - name: Run full devcontainer smoke
        run: |
          set -euo pipefail
          mkdir -p .sdd
          scripts/smoke-devcontainer.sh 2>&1 | tee .sdd/smoke-evidence.txt

      - name: Upload smoke evidence
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: smoke-evidence
          path: .sdd/smoke-evidence.txt
          if-no-files-found: ignore
```

- [ ] 構文確認（`bats tests/` に smoke-devcontainer の unit test は存在するが、YAML 変更は手動確認）：

```bash
bash -n scripts/smoke-devcontainer.sh
```

期待: exit 0

- [ ] コミット：

```bash
git add .gitignore .github/workflows/smoke-devcontainer.yml
git commit -m "feat(development-rules): save smoke output as artifact and gitignore evidence"
```

---

### Task 4: docs/development/ の3ファイルを作成する

**Files:**
- Create: `docs/development/environment-matrix.md`
- Create: `docs/development/smoke-guide.md`
- Create: `docs/development/blocker-handling.md`

- [ ] `mkdir -p docs/development` を実行する

- [ ] `docs/development/environment-matrix.md` を作成する：

```markdown
# Environment Matrix

このリポジトリでの作業環境と、各環境で可能な操作の一覧。

## 可否表

| Environment | 実装 | Bats | image build | dogfood smoke |
|---|---|---|---|---|
| host（通常 clone、/Users 配下） | ✓ | ✓ | ✓ | ✓ |
| host（linked worktree） | ✓ | ✓ | ✓ | ✗ |
| devcontainer 内 | ✓ | ✓ | ✗ | ✗ |
| CI（ubuntu-latest） | — | ✓ | ✓ | ✓ |

## なぜ linked worktree で smoke が動かないか

linked worktree の `.git` はファイル（ポインタ）であり、共通 git dir が workspace 外を指す。
devcontainer runtime は workspace に `.git` ディレクトリがあることを前提とするため、
linked worktree での起動に失敗する。

また macOS + Colima 環境では、linked worktree を `/private/tmp` や `/tmp` に
作成すると Colima のマウント範囲外になり bind mount に失敗する。

**これは回避すべき制約ではなく、正しい検証モデルを示す設計上の境界**:
smoke は消費プロジェクト（通常 clone）の体験をシミュレートするため、
通常 clone で実行することが最も実態に即した検証になる。

## smoke の正しい実行環境

- `/Users` 配下に通常 clone を用意する（Colima のデフォルトマウント範囲内）
- clone は既存 repo からローカル clone でよい（push 済みの branch が対象）
- Docker Desktop を使う場合も `/Users` 配下を推奨（制限が少ないが一貫性のため）
- CI（ubuntu-latest）は常に通常 clone で動作するため制約なし

## devcontainer 内での制限

devcontainer 内では Docker daemon にアクセスできないため、
image build と dogfood smoke は実行不可。
Bats テストと実装作業は devcontainer 内でも可能。
```

- [ ] `docs/development/smoke-guide.md` を作成する：

```markdown
# Host Smoke Guide

`scripts/smoke-devcontainer.sh` をホストから実行する手順。

## Prerequisites

以下が host にインストールされていること:

```bash
# bats-core
brew install bats-core        # macOS
# または
npm install -g bats           # cross-platform

# devcontainer CLI
npm install -g @devcontainers/cli

# jq
brew install jq               # macOS
apt-get install -y jq         # Ubuntu/Debian

# Docker（Colima or Docker Desktop）
brew install colima docker    # macOS + Colima
```

## macOS + Colima

```bash
# 1. Colima が起動していることを確認
colima status

# 2. /Users 配下の通常 clone に移動（linked worktree は不可）
cd /Users/<you>/path/to/agents-devcontainer   # または git clone で用意

# 3. smoke 実行 + 証跡保存
mkdir -p .sdd
scripts/smoke-devcontainer.sh 2>&1 | tee .sdd/smoke-evidence.txt
```

## macOS + Docker Desktop

```bash
# Docker Desktop が起動していることを確認
docker info

# 以降は Colima と同じ
mkdir -p .sdd
scripts/smoke-devcontainer.sh 2>&1 | tee .sdd/smoke-evidence.txt
```

## Linux

```bash
# Docker daemon が起動していることを確認
docker info

mkdir -p .sdd
scripts/smoke-devcontainer.sh 2>&1 | tee .sdd/smoke-evidence.txt
```

## smoke 証跡の確認と PR への添付

```bash
# 証跡が保存されたことを確認
ls -la .sdd/smoke-evidence.txt

# pre-pr-check.sh でも確認できる
scripts/pre-pr-check.sh
```

PR template の「smoke 証跡」欄に `.sdd/smoke-evidence.txt` の末尾数十行を貼り付ける。
`.sdd/smoke-evidence.txt` 自体は `.gitignore` に含まれているためコミットしない。
```

- [ ] `docs/development/blocker-handling.md` を作成する：

```markdown
# Blocker Handling

frozen `tasks.md` の範囲外の問題が発生した場合の手順。

## 停止条件

以下の場合は即座に作業を停止する:
- frozen `tasks.md` にないファイルを変更しなければならない
- frozen spec の acceptance criterion を達成できない実装上の問題が判明した
- verify 時に SDD reviewer が scope 外の問題を指摘した

## 停止手順

1. 作業を停止する（scope 外の修正を行ってはいけない）
2. `.sdd/tasks.json` の当該 feature を `blocked` に設定する：

```json
{
  "id": "<feature-slug>",
  "status": "blocked",
  "blocked_reason": "<何が・なぜ・どのファイルで詰まっているかを記入>"
}
```

3. follow-up issue を作成する（下記テンプレート参照）
4. kanban 状態と `blocked_reason` を human に報告して待機する

## follow-up issue テンプレート

```
タイトル: fix(<feature>): <問題の概要>

## 背景
<元 issue #N の作業中に発見>

## 再現手順
```
<コマンド>
```

出力:
```
<実際の出力>
```

## 影響する acceptance criterion
- AC<N>: <該当する acceptance criterion のテキスト>

## 元 issue の resume 条件
この issue が close されたら #<元issue番号> の作業を再開できる。
```

## resume 条件

以下のいずれかが満たされた場合のみ作業を再開する:
- follow-up issue が close された
- human が「resume してよい」と明示的に指示した

どちらもない状態で自己判断して resume してはいけない。

## scope creep を吸収しない原則

SDD reviewer が verify 時に scope 外の問題を指摘しても、
`spec.md` や `tasks.md` を変更してその問題を吸収してはいけない。

frozen spec の範囲で実装を完了し、scope 外の問題は follow-up issue に分離する。
元 issue は frozen spec の範囲で close する。
```

- [ ] コミット：

```bash
git add docs/development/
git commit -m "docs(development-rules): add environment-matrix, smoke-guide, blocker-handling"
```

---

### Task 5: AGENTS.md に5セクションを追加する

**Files:**
- Modify: `AGENTS.md`

- [ ] `AGENTS.md` の末尾（`テストは \`tests/\` 以下に配置する。...` の行の後）に以下を追記する：

```markdown

## Environment matrix

| Environment | 実装 | Bats | image build | dogfood smoke |
|---|---|---|---|---|
| host（通常 clone、/Users 配下） | ✓ | ✓ | ✓ | ✓ |
| host（linked worktree） | ✓ | ✓ | ✓ | ✗ |
| devcontainer 内 | ✓ | ✓ | ✗ | ✗ |
| CI（ubuntu-latest） | — | ✓ | ✓ | ✓ |

smoke は必ず `/Users` 配下の**通常 clone** から実行すること。linked worktree での smoke は
設計上サポートしない（smoke は消費プロジェクト = 通常 clone の体験をシミュレートするため）。

詳細: `docs/development/environment-matrix.md`

## Phase gates

### design preflight
- [ ] `specs/<feature>/spec.md` が存在する
- [ ] environment matrix で実装環境を確認した

### implementation gate
```bash
bats tests/
for f in .devcontainer/scripts/*; do bash -n "$f"; done
bash -n scripts/*.sh
```

### verify gate
```bash
bats tests/                  # clean state で全通過
git status --porcelain        # 空であること（未コミット変更なし）
# + sdd-reviewer subagent を実行し PASS
```

### pre-PR gate
```bash
scripts/pre-pr-check.sh
```

### pre-merge gate（CI 自動）
- `sdd-check`: spec gate + orchestration check
- `test`: `bats tests/`
- `smoke-devcontainer`: devcontainer 関連パス変更時に実行

## Definition of Done

| status | 意味 |
|---|---|
| `implementation_complete` | `tasks.md` 全タスク完了 + `bats tests/` green。smoke / SDD review / PR は未実施 |
| `issue_complete` | verify gate 通過 + CI green + PR merged |

「実装が終わった」と「issue が完了した」は別物。`.sdd/tasks.json` の `status` フィールドに設定する。

## Reporting template

各 phase 完了時に以下のテンプレートを使用する:

```
## Phase report: <phase名>
- spec: specs/<feature>/spec.md
- current status: <implementation_complete | issue_complete | blocked>
- changed files: <リスト>
- bats tests/: PASS / FAIL (<N> tests)
- bash -n: PASS / FAIL
- host smoke: PASS / FAIL / NOT_RUN（理由）
- sdd-reviewer: PASS / FAIL / NOT_RUN
- PR URL: <url or N/A>
- CI: <green | pending | N/A>
- 未実施項目: <リスト or なし>
```

## Blocker handling

frozen `tasks.md` の範囲外の問題で作業が止まった場合:
1. 即座に停止する
2. `.sdd/tasks.json` の当該 feature を `blocked` に設定し `blocked_reason` に詳細を記入
3. follow-up issue を作成（再現手順・影響 AC・元 issue の resume 条件を含める）
4. resume は follow-up issue close または human の明示指示のみ

scope creep を spec 変更で吸収してはいけない。必ず follow-up issue を作成する。

詳細: `docs/development/blocker-handling.md`
```

- [ ] AGENTS.md が実体ファイルであることを確認してから編集する（CLAUDE.md が AGENTS.md へのシンボリックリンク）：

```bash
ls -la AGENTS.md CLAUDE.md
# 期待: AGENTS.md が通常ファイル、CLAUDE.md -> AGENTS.md がシンボリックリンク
```

AGENTS.md を直接編集すること（シンボリックリンクを壊してはいけない）。

- [ ] コミット：

```bash
git add AGENTS.md
git commit -m "docs(development-rules): add phase gates, DoD, reporting template to AGENTS.md"
```

---

### Task 6: PR template を作成する

**Files:**
- Create: `.github/pull_request_template.md`

- [ ] `.github/pull_request_template.md` を作成する：

```markdown
## 変更内容

<!-- 変更の概要を記述 -->

## SDD

- Tier: <!-- sdd:tier-0 / sdd:tier-1 / sdd:tier-2 -->
- spec: <!-- specs/<feature>/spec.md または N/A -->
- sdd-reviewer: <!-- PASS / FAIL / N/A -->

## テスト結果

- [ ] `bats tests/` 全通過
- [ ] `bash -n` 全スクリプト

## Devcontainer 関連変更

*`.devcontainer/`・`dotfiles/`・`scaffold*`・`scripts/smoke-devcontainer.sh` 等を変更した場合のみ記入。該当なしの場合は「N/A」と記入。*

- host smoke: <!-- PASS / NOT_RUN（理由） -->

<details>
<summary>smoke 証跡（scripts/smoke-devcontainer.sh の出力末尾）</summary>

```
<!-- .sdd/smoke-evidence.txt の内容を貼り付け。devcontainer 関連変更がない場合は N/A -->
```

</details>

## CI

- [ ] required CI checks が green（または path-based skip）
```

- [ ] コミット：

```bash
git add .github/pull_request_template.md
git commit -m "feat(development-rules): add PR template with smoke evidence requirement"
```

---

### Task 7: specs/development-rules/ の SDD artifacts を作成する

**Files:**
- Create: `specs/development-rules/spec.md`
- Create: `specs/development-rules/plan.md`
- Create: `specs/development-rules/tasks.md`

- [ ] `mkdir -p specs/development-rules` を実行する

- [ ] `specs/development-rules/spec.md` を作成する：

```markdown
# Spec: development-rules

- Tier: 2
- Status: frozen
- Feature slug: development-rules

## 背景 / 意図

このリポジトリの開発ルールが AGENTS.md・Agents.md・vendored SDD guide・CI に分散しており、
「いつ、どの環境で、何を通せば PR を作成してよいか」が一つの実行可能な契約になっていない。
issue #49 の作業中に判明した問題を一般化し、agent・人間問わず同じ phase・コマンド・証跡で
作業できるようにする。issue #50 に対応する。

## 受入条件

- [ ] AC1: AGENTS.md に environment matrix セクションがあり、host/worktree/devcontainer/CI の
  可否表と、smoke は /Users 配下の通常 clone から実行する旨が記載されている。
- [ ] AC2: AGENTS.md に phase gates セクションがあり、design preflight / implementation gate /
  verify gate / pre-PR gate / pre-merge gate の checkable command が記載されている。
- [ ] AC3: AGENTS.md に Definition of Done セクションがあり、`implementation_complete` と
  `issue_complete` の定義が明記されている。
- [ ] AC4: AGENTS.md に reporting template セクションがあり、各 phase 完了時に agent が
  埋める項目一覧が定義されている。
- [ ] AC5: AGENTS.md に blocker handling セクションがあり、停止手順・follow-up issue 作成・
  resume 条件が定義されている。
- [ ] AC6: `docs/development/environment-matrix.md` が存在し、linked worktree で smoke が
  動かない理由と正しい実行環境を説明している。
- [ ] AC7: `docs/development/smoke-guide.md` が存在し、OS 別 smoke 実行手順と証跡保存手順を
  説明している。
- [ ] AC8: `docs/development/blocker-handling.md` が存在し、blocked_reason テンプレートと
  follow-up issue テンプレートを含む。
- [ ] AC9: `scripts/pre-pr-check.sh` が存在し、branch / bats / bash-n / smoke 証跡 / tasks.json
  を確認し、問題があれば exit 1 する。
- [ ] AC10: devcontainer 関連パスの変更が検出され、`.sdd/smoke-evidence.txt` が存在しない場合、
  `scripts/pre-pr-check.sh` が exit 1 し、smoke-devcontainer.sh の実行を促すメッセージを出す。
- [ ] AC11: `.github/pull_request_template.md` が存在し、smoke 証跡・SDD tier・CI 結果の
  記入欄を含む。
- [ ] AC12: `.sdd/smoke-evidence.txt` が `.gitignore` に追加されている。
- [ ] AC13: `tests/pre-pr-check.bats` が存在し、AC9-10 の動作を検証する。
- [ ] AC14: `bats tests/` が全通過する。
- [ ] AC15: `bash -n scripts/pre-pr-check.sh` が通過する。

## スコープ外

- vendored SDD guide の一般論を書き換えること
- downstream repository を同時に統一すること
- linked worktree での smoke 対応
- CI や SDD hook を無効化すること
```

- [ ] `specs/development-rules/plan.md` を作成する：

```markdown
# Plan: development-rules

## アプローチ

3層構造で開発ルールを確立する:
- Layer 1（読めるルール）: AGENTS.md に5セクション追加 + docs/development/ に詳細解説
- Layer 2（実行できる強制）: scripts/pre-pr-check.sh + PR template + CI evidence artifact
- Layer 3（状態管理）: .gitignore に .sdd/smoke-evidence.txt 追加

TDD: tests/pre-pr-check.bats を先に書いて RED を確認してから scripts/pre-pr-check.sh を実装する。

## 影響範囲 / 主要ファイル

- `AGENTS.md` — 5セクション追加
- `scripts/pre-pr-check.sh` — 新規作成（PR前チェック）
- `tests/pre-pr-check.bats` — 新規作成（TDD RED→GREEN）
- `docs/development/` — 3ファイル新規作成
- `.github/pull_request_template.md` — 新規作成
- `.gitignore` — .sdd/smoke-evidence.txt 追加
- `.github/workflows/smoke-devcontainer.yml` — evidence artifact 追加

## リスク / ロールバック

- リスク: PR template 追加でオープン中の PR に影響しない（新規 PR のみ適用）
- リスク: .gitignore に .sdd/smoke-evidence.txt を追加しても既存の .sdd/ エントリには影響しない
- ロールバック: 各ファイルを revert すれば元の状態に戻る
```

- [ ] `specs/development-rules/tasks.md` を作成する（本 plan の tasks を転写）：

```markdown
# Tasks: development-rules

実装計画の詳細は `docs/superpowers/plans/2026-06-22-development-rules.md` を参照。
TDD（RED→GREEN）と頻繁な commit を守ること。

## Task 1 — tests/pre-pr-check.bats（RED）
- [ ] `tests/pre-pr-check.bats` を作成する
- [ ] `bats tests/pre-pr-check.bats` で RED を確認する
- [ ] commit

## Task 2 — scripts/pre-pr-check.sh（GREEN）
- [ ] `scripts/pre-pr-check.sh` を実装する、`chmod +x`
- [ ] `bats tests/pre-pr-check.bats` で GREEN を確認する
- [ ] `bash -n scripts/pre-pr-check.sh` を確認する
- [ ] commit

## Task 3 — .gitignore + smoke-devcontainer.yml
- [ ] `.gitignore` に `.sdd/smoke-evidence.txt` を追加する
- [ ] `smoke-devcontainer.yml` に evidence artifact upload ステップを追加する
- [ ] commit

## Task 4 — docs/development/（3ファイル）
- [ ] `docs/development/environment-matrix.md` を作成する
- [ ] `docs/development/smoke-guide.md` を作成する
- [ ] `docs/development/blocker-handling.md` を作成する
- [ ] commit

## Task 5 — AGENTS.md（5セクション）
- [ ] environment matrix / phase gates / Definition of Done / reporting template / blocker handling を追記する
- [ ] commit

## Task 6 — PR template
- [ ] `.github/pull_request_template.md` を作成する
- [ ] commit

## Task 7 — specs/development-rules/ artifacts
- [ ] `specs/development-rules/spec.md` を作成する
- [ ] `specs/development-rules/plan.md` を作成する
- [ ] `specs/development-rules/tasks.md` を作成する（この file）
- [ ] commit

## Task 8 — 総合検証
- [ ] `bats tests/` 全通過
- [ ] `for f in .devcontainer/scripts/*; do bash -n "$f"; done`
- [ ] `bash -n scripts/*.sh`

## 受け入れ基準 ↔ テスト 対応表

| AC | 検証 |
|---|---|
| 1-5 (AGENTS.md セクション) | Task5 / 目視確認 |
| 6-8 (docs/development/) | Task4 / 目視確認 |
| 9 (pre-pr-check.sh 基本動作) | `pre-pr-check.bats: exits 0 when no devcontainer changes...` |
| 10 (smoke 証跡チェック) | `pre-pr-check.bats: exits 1 when devcontainer change detected but no smoke evidence` |
| 11 (PR template) | Task6 / 目視確認 |
| 12 (.gitignore) | Task3 / `grep smoke-evidence .gitignore` |
| 13 (bats テスト存在) | Task1 |
| 14 (bats tests/ 全通過) | Task8 |
| 15 (bash -n) | Task2 + Task8 |
```

- [ ] コミット：

```bash
git add specs/development-rules/
git commit -m "docs(development-rules): add SDD spec artifacts"
```

---

### Task 8: 総合検証

- [ ] `bats tests/` が全通過することを確認する：

```bash
bats tests/
```

期待: 全テスト PASS（failure 0）

- [ ] 全スクリプトの構文確認：

```bash
for f in .devcontainer/scripts/*; do bash -n "$f"; done
bash -n scripts/*.sh
```

期待: エラーなし

- [ ] AGENTS.md がシンボリックリンクのまま（実体ファイルに置き換えていない）：

```bash
ls -la AGENTS.md CLAUDE.md
```

期待: 一方が他方へのシンボリックリンクである

- [ ] PR template 存在確認：

```bash
ls -la .github/pull_request_template.md
```

- [ ] smoke-evidence が gitignore されている：

```bash
grep smoke-evidence .gitignore
```

期待: `.sdd/smoke-evidence.txt` の行が存在する
