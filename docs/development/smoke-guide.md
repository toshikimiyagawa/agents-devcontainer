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

# 3. 変更を commit してから smoke を実行する
#    証跡は HEAD commit を記録するため、未コミット変更があると pre-pr-check が落ちる。
git status --porcelain   # 空であること
scripts/smoke-devcontainer.sh
```

`scripts/smoke-devcontainer.sh` は **成功時のみ** `.sdd/smoke-evidence.txt` を生成し、
HEAD commit SHA・実行環境・成功マーカー（`SMOKE_RESULT=pass`）を記録する。`tee` で
ログを流し込まない（失敗を隠さないため）。

## macOS + Docker Desktop

```bash
# Docker Desktop が起動していることを確認
docker info

# 以降は Colima と同じ（commit 済みの状態で実行）
scripts/smoke-devcontainer.sh
```

## Linux

```bash
# Docker daemon が起動していることを確認
docker info

scripts/smoke-devcontainer.sh
```

## smoke 証跡の確認と PR への添付

```bash
# 証跡が保存されたことを確認（成功マーカーと HEAD 一致）
cat .sdd/smoke-evidence.txt

# pre-pr-check.sh が証跡の内容（SMOKE_RESULT=pass + COMMIT==HEAD）を検証する
scripts/pre-pr-check.sh
```

PR template の「smoke 証跡」欄に `.sdd/smoke-evidence.txt` の内容を貼り付ける。
`.sdd/smoke-evidence.txt` 自体は `.gitignore` に含まれているためコミットしない。
新しい commit を積んだら証跡は stale になるため、smoke を再実行すること。
