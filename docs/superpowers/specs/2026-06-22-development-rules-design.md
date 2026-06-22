# Design: development-rules — 開発ルールと PR 前検証ゲートの再設計

Issue: #50
Date: 2026-06-22

## 背景・問題

このリポジトリの開発ルールが AGENTS.md・`.devcontainer/Agents.md`・vendored SDD guide・CI workflow に分散しており、「いつ、どの環境で、何を通せば PR を作成してよいか」が一つの実行可能な契約になっていない。#49 の作業中に以下の問題が判明した：

1. unit test / Docker build が green でも dogfood devcontainer が起動するとは限らない
2. "implementation complete" と "issue complete" が混同されやすい
3. devcontainer smoke を verify phase で初めて実行すると実装後に問題が判明する
4. linked worktree での smoke が失敗する（設計上の制約、workaround 不要）
5. dogfood config の空 GIT_AUTHOR/GIT_COMMITTER forwarding（ae6cb3c で修正済み）
6. PR template が存在しない
7. frozen scope 外 blocker の停止・resume 手順が未定義

## 目的

- 誰が作業しても同じ phase・環境・コマンド・証跡を使う
- smoke 未成功の devcontainer 関連変更を merge 対象にしない
- "implementation complete" と "issue complete" を明確に区別する
- docs-only のお願いに依存しない（script・CI で可能な範囲を強制）

## アーキテクチャ概要（3層構造）

```
Layer 1: 読めるルール
  AGENTS.md                       ← 実行可能な契約（gates・DoD・matrix）
  docs/development/               ← 詳細解説（AGENTS.md からリンク）

Layer 2: 実行できる強制
  scripts/pre-pr-check.sh         ← PR 前ローカル実行の単一エントリポイント
  .github/pull_request_template.md ← smoke 証跡の記入必須化
  .github/workflows/smoke-devcontainer.yml（既存強化）

Layer 3: 状態管理
  .sdd/tasks.json                 ← status 値を拡張
  .sdd/smoke-evidence.txt         ← smoke 実行ログ（gitignore 済み）
```

**情報の流れ**:
1. agent/人間が `scripts/pre-pr-check.sh` を実行
2. smoke 証跡が `.sdd/smoke-evidence.txt` に保存される
3. PR template の記入欄に証跡を貼り付け
4. CI smoke gate が path-based で確認
5. merge

## Section 1 — AGENTS.md の構成

現行の AGENTS.md（=CLAUDE.md シンボリックリンク）に以下セクションを追加する。既存の "Hard rules" と "テスト" は保持。

追加セクション：
- `## Environment matrix` — 環境ごとの可否表 + 詳細ドキュメントへのリンク
- `## Phase gates` — 各 phase の checkable command 一覧
- `## Definition of Done` — implementation_complete / issue_complete の定義
- `## Reporting template` — 各 phase 完了時に agent が埋める項目
- `## Blocker handling` — frozen scope 外問題の停止・分離・resume 手順

`docs/development/` に配置する詳細ドキュメント：
- `environment-matrix.md` — mount 制約・linked worktree の詳述・OS 別差異
- `smoke-guide.md` — OS 別 smoke 実行手順（Colima / Docker Desktop / Linux）
- `blocker-handling.md` — blocked issue の記入テンプレート

## Section 2 — Environment matrix

| Environment | 実装 | Bats | image build | dogfood smoke |
|---|---|---|---|---|
| host（通常 clone、/Users 配下） | ✓ | ✓ | ✓ | ✓ |
| host（linked worktree） | ✓ | ✓ | ✓ | ✗（設計上不可） |
| devcontainer 内 | ✓ | ✓ | ✗ | ✗ |
| CI（ubuntu-latest） | — | ✓ | ✓ | ✓ |

**smoke の実行条件**:
- 必ず `/Users` 配下（Colima のマウント範囲内）の通常 clone から実行する
- linked worktree での smoke はサポート外。これは制限ではなく設計上の正しい検証モデル：smoke は消費プロジェクト（通常 clone）の体験をシミュレートするため

## Section 3 — Phase gates

### design preflight
- [ ] `specs/<feature>/` に `spec.md` が存在する
- [ ] environment matrix で実装環境を確認した
- [ ] 必要な host prerequisites（Docker runtime・devcontainer CLI・bats-core など）をリストアップした

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

### pre-PR gate（`scripts/pre-pr-check.sh` で一括実行）
```bash
scripts/pre-pr-check.sh
```
内部で実行するチェック：
1. feature branch 上にいることを確認（main への直接 push 防止）
2. `bats tests/` — 全通過
3. `bash -n` 全スクリプト
4. devcontainer 関連パス変更がある場合: `.sdd/smoke-evidence.txt` が存在することを確認（なければ `scripts/smoke-devcontainer.sh` の実行を促して exit 1）。関連パスは `.github/workflows/smoke-devcontainer.yml` の `paths:` リストを single source of truth とし、`pre-pr-check.sh` はそこから読むか同じリストを参照する
5. `.sdd/tasks.json` が存在する場合: status が `implementation_complete` 以上かつ `blocked` タスクがないことを確認

### pre-merge gate（CI、自動）
- `sdd-check`: spec gate + orchestration check（既存）
- `test`: `bats tests/`（既存）
- `smoke-devcontainer`: path-based smoke（既存、今回 evidence artifact upload 追加）

## Section 4 — tasks.json status 拡張・reporting template

### tasks.json status 値（拡張）

既存: `pending` / `in_progress` / `completed` / `blocked`

追加:
- `implementation_complete` — `tasks.md` の全タスク完了 + `bats tests/` green。smoke / SDD review / PR はまだ未実施
- `issue_complete` — verify gate 通過 + CI green + PR merged

CI は `blocked` タスクがあれば block する（既存動作）。`implementation_complete` / `issue_complete` は CI で強制せず、`pre-pr-check.sh` と reporting template で運用上の区別を担保する。

### agent 報告テンプレート

各 phase 完了時に agent はこのテンプレートを使用する（AGENTS.md に定義）：

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

## Section 5 — Blocker handling

### 停止条件
frozen `tasks.md` の範囲外の問題で作業が進められない場合：
1. 即座に停止する
2. `.sdd/tasks.json` の当該 feature を `blocked` に設定
3. `blocked_reason` に「何が・なぜ・どのファイルで」を記入

### follow-up issue に必須の内容
```
- 再現手順（コマンド + 出力）
- 影響する spec の acceptance criterion
- 元 issue の resume 条件（「#XX が close されたら再開可能」）
```

### resume 条件
- follow-up issue が close された、または
- human が明示的に「resume してよい」と指示した場合のみ

### scope creep を吸収しない原則
SDD reviewer が verify 時に scope 外の問題を指摘しても、spec を変更して吸収してはいけない。必ず follow-up issue を作成し、元 issue は frozen spec の範囲で close する。

## 受け入れ基準

- [ ] AGENTS.md に environment matrix / phase gates / DoD / reporting template / blocker handling が追記されている
- [ ] `docs/development/environment-matrix.md` が存在し、mount 制約と linked worktree 制約を説明している
- [ ] `docs/development/smoke-guide.md` が存在し、OS 別実行手順を説明している
- [ ] `docs/development/blocker-handling.md` が存在し、blocked issue テンプレートを含む
- [ ] `scripts/pre-pr-check.sh` が存在し、branch・bats・bash-n・smoke 証跡・tasks.json を確認する
- [ ] `scripts/pre-pr-check.sh` が devcontainer 関連パス変更を自動検出し、smoke 証跡がなければ exit 1 する
- [ ] `.github/pull_request_template.md` が存在し、smoke 証跡・SDD tier・CI 結果の記入欄を含む
- [ ] `.sdd/smoke-evidence.txt` が `.gitignore` に追加されている
- [ ] `implementation_complete` / `issue_complete` の定義が AGENTS.md の "Definition of Done" セクションに記載されている
- [ ] `bats tests/` が全通過する
- [ ] `scripts/pre-pr-check.sh` 自身に対する Bats テストが存在する
- [ ] `bash -n scripts/pre-pr-check.sh` が通過する

## 非目標

- vendored SDD guide 全体の一般論を書き換えること
- downstream repository を同時に統一すること
- smoke を通すためにチェックを skip / warning 化すること
- CI や SDD hook を無効化すること
- linked worktree での smoke 対応（設計上不要）
