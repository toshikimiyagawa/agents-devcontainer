# Agents

このプロジェクトの Dev Container 環境を維持・拡張するためのガイドライン。

## 基本原則

- **マルチプラットフォーム・マルチアーキテクチャ対応**:
  - macOS (Intel/Apple Silicon), Windows (x86/ARM via WSL2) で動作すること。
  - `Dockerfile` 内でバイナリをダウンロードする際は、必ず `$(dpkg --print-architecture)` を使用してアーキテクチャ（amd64/arm64等）を判別し、適切なリンクを選択すること。
- **パッケージ管理**:
  - 特別な事情が無い限りできるだけ `apt` もしくは `snap` を利用すること。
  - 最新版が必要なツール（yazi等）や、プロジェクト固有のランタイム管理（uv, mise）は例外として直接インストールを許容する。

## 環境構成

- **ベースイメージ**: Ubuntu 24.04 LTS (Noble) またはそれ以降（現在は 26.04 を想定）。
- **ユーザー**: `ubuntu` (UID 1000) を使用。
  - ホストとのパーミッション不整合を避けるため、root ではなく `ubuntu` ユーザーで実行すること。
  - 必要に応じて `sudo` がパスワードなしで利用可能。
- **マウント**:
  - `/workspace`: プロジェクトルートをバインドマウント。
  - `~/.gitconfig`, `~/.git-credentials`: **バインドマウントしない**。git 設定はコンテナ内の `/etc/gitconfig`（system レベル）で管理する（`postStartCommand` で書き込み）。ホストの gitconfig に含まれる OS 固有のパスがコンテナ内で壊れる問題を回避するため。
  - `~/.gh-config`: named volume（`devcontainer-gh-<devcontainerId>`）でマウント。`GH_CONFIG_DIR=/home/ubuntu/.gh-config` で gh CLI がここを参照する。rebuild 後もトークンが維持され、初回のみ `gh auth login` を実行すればよい。
  - `~/.claude` は **ホストと共有しない**。`.devcontainer/dotfiles/.claude/` を symlink して、コンテナ専用の認証・履歴をワークスペース配下に隔離する（中身は gitignore 済み）。
  - `initializeCommand` で `dotfiles/.claude`, `dotfiles/.gemini` ディレクトリの存在を保証すること。

## セットアップ自動化 (`postCreateCommand`)

- **Dotfiles**:
  - `.devcontainer/dotfiles/` 内の `.zshrc`, `.tmux.conf`, `.config`, `.claude` を `$HOME` にシンボリックリンクすること。
  - `.ssh` はパーミッションの制約（OpenSSH）があるため、コピーして `600/700` に設定すること。
- **ツール設定**:
  - `tmux`: TPM (Tmux Plugin Manager) をクローンし、プラグインを自動インストールすること。
  - `Python`: `uv sync` を使用して依存関係を解決すること。
- **Git**:
  - `postStartCommand` で `scripts/post-start.sh` を実行し、`/etc/gitconfig` に safe.directory、credential helper、ユーザー identity を設定すること。
  - git identity は `remoteEnv` 経由でホストの `GIT_AUTHOR_NAME` / `GIT_AUTHOR_EMAIL` を転送する。未設定の場合は `gh api user` でフォールバック。

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
- **Polyglot Runtime Manager**: `mise`

### 特定ツール
- **AI**:
  - `Claude Code` (claude)
  - `Gemini CLI` (gemini)
  - `OpenSpec` (openspec) — Spec-Driven Development フレームワーク。プロジェクト初期化は `openspec init --tools claude` を手動実行する。
