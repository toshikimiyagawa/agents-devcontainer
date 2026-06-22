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
