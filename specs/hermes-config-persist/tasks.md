# Tasks: hermes-config-persist

`docs/superpowers/plans/2026-06-18-hermes-config-persist.md` の同名タスクを参照。
実装は frozen spec に記載された範囲に限定する。TDD（RED→GREEN）と頻繁な commit を守ること。

## 実装タスク（順序付き）

- [ ] Task 1: scaffold と dogfood devcontainer の `initializeCommand` が `dotfiles/.hermes` を作るようにする。対応AC: AC1, AC2, AC3
- [ ] Task 2: `.devcontainer/scripts/agents-post-create` が production default `/workspace/dotfiles` を維持しつつ、`AGENTS_DOTFILES_PROJECT` test override を使って `$HOME/.hermes` を project dotfiles の `.hermes` に symlink する。対応AC: AC4
- [ ] Task 3: `.devcontainer/scripts/agents-dotfiles-sync` が `.hermes` と `.hermes/*` を除外する。対応AC: AC5
- [ ] Task 4: README と `.devcontainer/Agents.md` に Hermes state persistence と host 非共有を記載する。対応AC: AC6, AC7
- [ ] Task 5: `bats tests/` と shell syntax check を実行し、差分が scope 内であることを確認する。対応AC: AC8

## テスト（受入条件との対応・必須）

- [ ] AC1 → `tests/devcontainer.bats: dogfood devcontainer.json initializeCommand creates dotfiles/.hermes`
- [ ] AC2 → `tests/scaffold.bats: devcontainer.json initializeCommand creates dotfiles/.hermes`
- [ ] AC3 → `tests/scaffold.bats: creates dotfiles/.hermes directory`
- [ ] AC4 → `tests/agents-post-create.bats: links Hermes state directory from project dotfiles`
- [ ] AC4 regression → `tests/agents-post-create.bats: keeps existing Claude Gemini Codex links working`
- [ ] AC5 → `tests/dotfiles-sync.bats: excludes .claude .gemini .codex .hermes .ssh .zsh_history .gitignore`
- [ ] AC6 → `tests/hermes-install.bats: README documents Hermes state persistence`
- [ ] AC7 → `tests/hermes-install.bats: Agents.md documents Hermes state persistence`
- [ ] AC8 → `bats tests/`
- [ ] AC8 → `for f in .devcontainer/scripts/*; do bash -n "$f"; done`

## 完了の定義

- [ ] 全AC対応テストが green
- [ ] `bats tests/` が green
- [ ] `.devcontainer/scripts/*` の `bash -n` が green
- [ ] CI green
- [ ] sdd-reviewer 合格
