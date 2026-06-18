# Agents

このプロジェクトの Dev Container 環境を維持・拡張するためのガイドライン。

## 基本原則

- **マルチプラットフォーム・マルチアーキテクチャ対応**:
  - macOS (Intel/Apple Silicon), Windows (x86/ARM via WSL2) で動作すること。
  - `Dockerfile.base` 内でバイナリをダウンロードする際は、必ず `$(dpkg --print-architecture)` を使用してアーキテクチャ（amd64/arm64等）を判別し、適切なリンクを選択すること。
- **パッケージ管理**:
  - 特別な事情が無い限りできるだけ `apt` もしくは `snap` を利用すること。
  - 最新版が必要なツール（yazi等）や、プロジェクト固有のランタイム管理（uv等）は例外として直接インストールを許容する。

## アーキテクチャ概要

このリポジトリはベースイメージ（`ghcr.io/toshikimiyagawa/agents-devcontainer`）を提供するソースリポジトリ。

```
Dockerfile.base  →  ghcr.io/...  ←  他プロジェクトの devcontainer.json が "image" で参照
Dockerfile       →  FROM ghcr.io/...  (このリポジトリ自身の dogfood 用)
```

- **ツールの追加・変更**: `Dockerfile.base` を編集 → main に push → CI がイメージをビルドして publish
- **消費プロジェクト側**: `devcontainer.json` の `image` タグを更新するだけで最新のツールが手に入る
- **新プロジェクトのセットアップ**: `scaffold.sh` を実行すると `.devcontainer/` が自動生成される

## 環境構成

- **ベースイメージ**: Ubuntu 24.04 LTS (Noble) またはそれ以降（現在は 26.04 を想定）。
- **ユーザー**: `ubuntu` (UID 1000) を使用。
  - ホストとのパーミッション不整合を避けるため、root ではなく `ubuntu` ユーザーで実行すること。
  - 必要に応じて `sudo` がパスワードなしで利用可能。
- **マウント**:
  - `/workspace`: プロジェクトルートをバインドマウント。
  - `~/.gitconfig`, `~/.git-credentials`: **バインドマウントしない**。git 設定はコンテナ内の `/etc/gitconfig`（system レベル）で管理する（`agents-post-start` で書き込み）。ホストの gitconfig に含まれる OS 固有のパスがコンテナ内で壊れる問題を回避するため。
  - `~/.gh-config`: named volume（`devcontainer-gh-<devcontainerId>`）でマウント。`GH_CONFIG_DIR=/home/ubuntu/.gh-config` で gh CLI がここを参照する。rebuild 後もトークンが維持され、初回のみ `gh auth login` を実行すればよい。
  - `~/.claude` は **ホストと共有しない**。`dotfiles/.claude/` を symlink して、コンテナ専用の認証・履歴をワークスペース配下に隔離する（中身は gitignore 済み）。
  - `~/.hermes` は host `~/.hermes` と共有しない。`dotfiles/.hermes/` を symlink し、container 専用の Hermes 認証・履歴・memory・provider/model 設定を保持する（中身は gitignore 済み）。
  - `initializeCommand` で `dotfiles/.claude`, `dotfiles/.gemini`, `dotfiles/.codex`, `dotfiles/.hermes` ディレクトリの存在を保証すること。
  - Hermes superpowers bootstrap は `.hermes` symlink 作成後に `agents-post-create` で実行する。`hermes skills install --yes skills-sh/obra/superpowers` が成功したら `dotfiles/.hermes/.agents-superpowers-installed` を marker とし、再実行時は skip する。network/registry failure は non-fatal warning として扱う。

## dotfiles の仕組み（レイヤー構造）

`agents-post-create` が2層の dotfiles を `$HOME` にシンボリックリンクする:

| 優先度 | ソース | 説明 |
|---|---|---|
| 高 | `/workspace/.devcontainer/dotfiles/` | プロジェクト固有の上書き |
| 低 | `/opt/agents/dotfiles/` | イメージに焼き込まれたデフォルト |

**上書きの単位はファイル/ディレクトリ単位（マージではない）**。例えば `.config/` を上書きする場合、プロジェクト側は `.config/` 全体を提供する必要がある。

`.zshrc` を全置換せずに拡張したい場合:

```zsh
# プロジェクトの .zshrc
source /opt/agents/dotfiles/.zshrc
# ここにプロジェクト固有の設定を追記
export MY_API_KEY=...
```

**バックアップとして焼き込まれないもの**（プロジェクト固有の状態）:
- `.claude/`, `.gemini/`, `.codex/`, `.hermes/` — AI エージェントの認証・履歴・設定（gitignore 済み）
- `.ssh/` — SSH 秘密鍵（gitignore 済み）
- `.config/gh/` — gh CLI のトークン（named volume で管理）

## セットアップ自動化

- **`agents-post-create`** (`postCreateCommand`): dotfiles シンボリックリンク、Hermes superpowers bootstrap、SSH コピー、TPM インストール。コンテナ初回作成時に実行。
- **`agents-post-start`** (`postStartCommand`): `/etc/gitconfig` に safe.directory、credential helper（`!/usr/bin/gh auth git-credential`）、git identity を設定。コンテナ起動のたびに実行（冪等）。

git identity は `remoteEnv` 経由でホストの `GIT_AUTHOR_NAME` / `GIT_AUTHOR_EMAIL` を転送する。未設定の場合は `gh api user` でフォールバック。

## 主要ツールスタック

### システム・ユーティリティ (apt)
- **Shell**: `zsh` (+ `starship` prompt)
- **Terminal Multiplexer**: `tmux`
- **Editor**: `neovim`
- **Version Control**: `git`, `lazygit`
- **Search**: `ripgrep` (rg), `fd-find` (fd)
- **Network**: `curl`, `netcat-openbsd`
- **File Management**: `unzip`, `less`, `yazi` (binary install)
- **Processing**: `jq`, `make`, `gcc`, `libc6-dev`
- **Environment**: `ca-certificates`, `tzdata`

### ランタイム・パッケージ管理
- **Python**: `uv` (依存関係管理・Python バージョン管理)

### AI・特定ツール
- `Claude Code` (claude)
- `Gemini CLI` (gemini)
- `Codex CLI` (codex) — OpenAI によるターミナルベースの AI エージェント。
- `Hermes Agent` (hermes) — NousResearch による自己改善型の自律 AI エージェント。`USER ubuntu` で per-user インストール（コードは `~/.hermes`、コマンドは `~/.local/bin/hermes`、Claude Code と同じレイアウト）。ブラウザ自動化（Playwright/Chromium）込み。runtime state は `~/.hermes`（symlink 先 = `dotfiles/.hermes/`）に永続化し、host `~/.hermes` とは共有しない。`postCreate` で `skills-sh/obra/superpowers` を bootstrap する。初回利用時に `hermes setup` でプロバイダを設定する。
- `ai-sdd-guide` — Spec-Driven Development フレームワーク。`scaffold.sh` が git submodule として `vendor/ai-sdd-guide` に配置する。ルール: `vendor/ai-sdd-guide/rules/`、ドキュメント: `vendor/ai-sdd-guide/docs/`。
- `Superpowers` — Claude Code plugin。`devcontainer up` には組み込まず、Claude 内で `/plugin install superpowers@claude-plugins-official` を実行して opt-in する。状態は `~/.claude/`（symlink 先 = `dotfiles/.claude/`）に永続化。
- `GitHub CLI` (gh) — git 認証に使用。
