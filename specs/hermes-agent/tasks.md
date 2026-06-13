# Tasks: hermes-agent

順序付きの実装ステップ。各ステップのコード全文は
`docs/superpowers/plans/2026-06-13-hermes-agent.md` の同名タスクを参照（self-contained なコードはそちら）。
TDD（RED→GREEN）と頻繁な commit を守ること。

## Task 1 — 配線テスト `tests/hermes-install.bats`（RED）
- [ ] `tests/hermes-install.bats` を作成（AC1–7 を grep で検証）
- [ ] `bats tests/hermes-install.bats` で RED を確認（Dockerfile/docs 未編集なので失敗）
- [ ] commit

## Task 2 — `Dockerfile.base` に Hermes インストールを追加（GREEN 前半）
- [ ] `USER ubuntu` ブロック内（Claude Code RUN の後、`USER root` の前）に Hermes インストール RUN を追加
- [ ] LABEL の `image.description` に "Hermes Agent" を追記
- [ ] `bash -n` 相当の構文確認は不要だが、`grep` で配線が入ったことを確認
- [ ] commit

## Task 3 — ドキュメント更新（GREEN 後半）
- [ ] `README.md` 行 4 の同梱ツール列挙に "Hermes Agent" を追記
- [ ] `README.md`「特徴」の箇条書き（Codex CLI の次）に Hermes Agent の行を追加
- [ ] `.devcontainer/Agents.md`「AI・特定ツール」一覧（Codex CLI の次）に `hermes` の行を追加
- [ ] `bats tests/hermes-install.bats` で GREEN を確認
- [ ] commit

## Task 4 — 総合検証
- [ ] `bats tests/` が全て通過することを確認
- [ ] （任意・ローカル可能なら）`docker build -t agents-base:dev -f .devcontainer/Dockerfile.base .` が成功することを確認
- [ ] PR を作成（`sdd:tier-2` ラベル）し、CI `build-base-image`（amd64 build-only）の成功を待って確認

## 受け入れ基準 ↔ テスト 対応表

| AC | 検証 |
|---|---|
| 1 (公式インストーラで導入) | `hermes-install.bats: installs Hermes Agent via the official installer` |
| 2 (per-user / USER ubuntu) | `hermes-install.bats: installs Hermes per-user (inside the USER ubuntu block)` |
| 3 (`--skip-setup`) | `hermes-install.bats: skips the interactive setup wizard` |
| 4 (browser 込み) | `hermes-install.bats: keeps browser tools (no --skip-browser)` |
| 5 (LABEL) | `hermes-install.bats: image LABEL description lists Hermes Agent` |
| 6 (README) | `hermes-install.bats: README lists Hermes Agent` |
| 7 (Agents.md) | `hermes-install.bats: Agents.md lists the hermes command` |
| 8 (bats 全通過) | Task4 / `bats tests/` |
| 9 (CI ビルド成功) | Task4 / GitHub Actions `build-base-image`（PR amd64 build-only） |
