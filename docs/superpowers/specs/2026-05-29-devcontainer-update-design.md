# Devcontainer Update Architecture Design

## Summary

agents-devcontainer を利用するプロジェクトが、上流の設定変更（devcontainer.json テンプレート・SDD 統合ファイル）を
安全に取り込めるようにする。git submodule + 分離設定ファイル + マージスクリプトによる設計。

## Motivation

現状の scaffold.sh は静的ファイルを一度生成して以降は更新しない。
agents-devcontainer 本体が更新されても、消費プロジェクトは以下を受け取れない：

- `devcontainer.json` の設定変更（新しいマウント、環境変数など）
- SDD 統合ファイルの更新（`.claude/agents/`, `sdd-check.yml` など）
- `project-tools.yml` のテンプレート改善

## Scope

### In scope

1. `scaffold/devcontainer.base.json` — ベース設定テンプレートの追加
2. `scaffold/merge.sh` — base + project を jq でマージし `devcontainer.json` を生成するスクリプト
3. `scaffold/sdd-update.sh` — 再生成可能な SDD ファイルを更新するスクリプト
4. `scaffold.sh` の改修 — 新規プロジェクトで submodule 追加 + `devcontainer.project.json` 生成
5. `tests/merge.bats` / `tests/sdd-update.bats` — 新規テスト

### Out of scope

- Docker イメージのビルドへの影響（Dockerfile.base は変更なし）
- ai-sdd-guide submodule 自体への変更
- 既存プロジェクトの自動移行（手動移行で対応、移行手順はドキュメント化）

## Architecture

### agents-devcontainer リポジトリへの追加

```
scaffold/
  devcontainer.base.json             ← ベース設定テンプレート（バージョン管理済み）
  devcontainer.project.json.example  ← 消費プロジェクトの起点サンプル
  merge.sh                           ← devcontainer.json 生成スクリプト
  sdd-update.sh                      ← SDD 統合ファイル更新スクリプト
```

### 消費プロジェクトの構造（導入後）

```
vendor/
  agents-devcontainer/         ← submodule（このリポジトリ）
  ai-sdd-guide/                ← 既存 submodule（変更なし）

.devcontainer/
  devcontainer.project.json    ← プロジェクト固有の差分のみ（編集対象）
  devcontainer.json            ← merge.sh が生成、コミット対象
  project-tools.yml            ← プロジェクト固有（変更なし）
  post-install.sh              ← 任意のカスタムスクリプト（既存機能、変更なし）
```

### 更新フロー（消費プロジェクト側）

```bash
# agents-devcontainer の最新を取得
git submodule update --remote vendor/agents-devcontainer

# devcontainer.json を再生成
vendor/agents-devcontainer/scaffold/merge.sh

# SDD 統合ファイルを更新（再生成可能なものだけ）
vendor/agents-devcontainer/scaffold/sdd-update.sh

# 差分確認 → コミット
git diff .devcontainer/devcontainer.json
git add .devcontainer/devcontainer.json
git commit -m "chore(devcontainer): update to agents-devcontainer vX.Y.Z"
```

## devcontainer.project.json 仕様

プロジェクト側が記述するのは**差分のみ**。ベース設定（image, workspaceMount, gh-config mount など）は書かない。

```json
{
  "name": "my-project",
  "mounts": [
    "source=my-db,target=/var/lib/postgresql/data,type=volume"
  ],
  "remoteEnv": {
    "MY_API_KEY": "${localEnv:MY_API_KEY}"
  }
}
```

`image` を `build` に置き換えることで、カスタム Dockerfile への切り替えも可能：

```json
{
  "name": "my-project",
  "build": {
    "context": "..",
    "dockerfile": "../.devcontainer/Dockerfile"
  }
}
```

## merge.sh マージルール

| フィールド | 戦略 |
|---|---|
| `name` | project 優先。なければ `basename $PWD` |
| `image` | project 優先。project に `build` があれば `image` は除去 |
| `build` | project 優先 |
| `mounts` | 配列結合（base の配列 + project の配列） |
| `remoteEnv` | 深いマージ（project が base を上書き、追加も可） |
| `postCreateCommand` | project 優先。なければ base（`agents-post-create`） |
| `postStartCommand` | project 優先。なければ base（`agents-post-start`） |
| その他スカラー | project 優先、なければ base |

`postCreateCommand` を上書きする場合は `agents-post-create` を先頭に含める：

```json
{
  "postCreateCommand": "agents-post-create && my-extra-setup"
}
```

## sdd-update.sh の対象ファイル分類

### 再生成可能（上書き対象）

プロジェクトが通常カスタマイズしないファイル。コマンド実行時に無条件で最新版に上書きする。

- `.claude/agents/` — エージェント定義一式
- `.github/workflows/sdd-check.yml` — CI spec gate

### 保護対象（差分表示のみ）

プロジェクトが独自に変更するファイル。上書きせず、変更点を diff で表示して人間が判断する。

- `CLAUDE.md`
- `AGENTS.md`
- `.claude/settings.json`

## scaffold.sh の変更

### 新規プロジェクト

挙動の変化：

| 項目 | 変更前 | 変更後 |
|---|---|---|
| `devcontainer.json` | 静的ファイルを生成 | 生成しない（merge.sh が担う） |
| `devcontainer.project.json` | なし | 最小構成で生成 |
| `vendor/agents-devcontainer` | なし | submodule として追加 |
| merge.sh の実行 | なし | scaffold 直後に自動実行して `devcontainer.json` を生成 |

環境変数 `AGENTS_DEVCONTAINER_TAG` は引き続き `devcontainer.base.json` の `image` タグを制御する。

### 既存プロジェクトへの適用

`.devcontainer/` が既に存在するプロジェクトでも scaffold.sh を実行可能（現行と同じ挙動）。
その場合は devcontainer セクションをスキップし、submodule 追加と SDD セットアップのみ行う。

既存 `devcontainer.json` からの **手動移行手順**（ドキュメント化）：

1. `vendor/agents-devcontainer` submodule を追加
2. 既存 `devcontainer.json` と `scaffold/devcontainer.base.json` を diff
3. 差分（プロジェクト固有の設定）を `devcontainer.project.json` に切り出す
4. `merge.sh` を実行して `devcontainer.json` を再生成・確認
5. コミット

## テスト戦略

```
tests/
  scaffold.bats      ← 既存（新規プロジェクト生成の挙動を更新）
  merge.bats         ← 新規: merge.sh のマージロジック
  sdd-update.bats    ← 新規: sdd-update.sh の上書き・保護ロジック
```

### merge.bats の主なテストケース

- 基本マージ（name, 追加 mount, 追加 env）
- `postCreateCommand` の project 上書き
- `project.json` が空のとき（base のみになる）
- `build` キーで `image` を置き換え（Dockerfile 拡張ケース）
- `mounts` の配列結合（base + project）

### sdd-update.bats の主なテストケース

- agents/ が最新に上書きされる
- CLAUDE.md は上書きされない（diff のみ）
- 初回実行時に agents/ が存在しなくても動く

## Acceptance Criteria

1. 消費プロジェクトで `git submodule update --remote vendor/agents-devcontainer && vendor/agents-devcontainer/scaffold/merge.sh` を実行すると `devcontainer.json` が最新の base に基づいて再生成される
2. `devcontainer.project.json` の内容がマージルール通りに反映される
3. `sdd-update.sh` が `.claude/agents/` と `sdd-check.yml` のみを更新し、`CLAUDE.md` 等の保護対象は変更しない
4. `scaffold.sh` で新規プロジェクトをセットアップすると `devcontainer.project.json` が生成され、`merge.sh` で `devcontainer.json` が生成される
5. `bats tests/` が全て通る
