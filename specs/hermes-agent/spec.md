# Spec: hermes-agent

## Intent

ベースイメージ（`Dockerfile.base` → `ghcr.io/toshikimiyagawa/agents-devcontainer`）に
NousResearch の **Hermes Agent**（自己改善型の自律 AI エージェント。永続メモリ・スキル学習・
40+ ツール・マルチプラットフォーム）をプリインストールする。既存の Claude Code / Gemini CLI /
Codex CLI と並ぶ第4のエージェントとして同梱し、ドキュメントを最新化する。

インストールは公式インストーラ `https://hermes-agent.nousresearch.com/install.sh` を用いる。
レイアウトは Claude Code と同じ **per-user**（`USER ubuntu` で実行 → コードは `~/.hermes`、
コマンドは `~/.local/bin/hermes`）とし、start-time の UID remap でも生き残るようにする。
ブラウザ自動化ツール（Playwright/Chromium）を **含める**。ビルド時の対話セットアップは
行わず（`--skip-setup`）、プロバイダ設定はランタイムで `hermes setup` に委ねる。

既存ツール（Claude Code / Gemini CLI / Codex CLI / Node / uv 等）の構成は変更しない。

## Acceptance Criteria

1. `.devcontainer/Dockerfile.base` が公式インストーラ
   `https://hermes-agent.nousresearch.com/install.sh` を実行して Hermes Agent を導入する。
2. インストール RUN は `USER ubuntu` ブロック内で実行され（`USER root` に戻る前）、per-user
   レイアウト（`~/.local/bin/hermes`）になる。root 用の `--install-dir` / FHS 上書きは行わない。
3. インストーラに `--skip-setup` を付与し、ビルド時に対話プロバイダ設定ウィザードを起動しない。
4. ブラウザツールを含める（`--skip-browser` / `--no-playwright` を付けない）。
5. イメージの `LABEL org.opencontainers.image.description` に "Hermes Agent" を含める。
6. `README.md` の同梱エージェント説明に Hermes Agent を含める。
7. `.devcontainer/Agents.md` の「AI・特定ツール」一覧に `hermes` コマンドを含める。
8. 新規 `tests/hermes-install.bats` が AC1–7 の配線（Dockerfile.base と docs の内容）を検証し、
   `bats tests/` が全て通過する。
9. CI `build-base-image`（PR で `Dockerfile.base` 変更時に走る linux/amd64 ビルド検証ジョブ）が
   成功する。すなわち Hermes 込みでイメージが実際にビルドできる。

## Out of Scope

- Hermes のプロバイダ/モデル/API キーの事前構成（ランタイムで `hermes setup`）。
- 既存 Node を Node 22 へ bump すること（現行 Node 20 が `>=20.19` を満たし、インストーラが
  既存 Node を再利用するため不要）。
- Hermes Desktop / メッセージングゲートウェイ（Telegram/Discord 等）の同梱・検証。
- 既存エージェント（Claude Code / Gemini CLI / Codex CLI）や dotfiles・scaffold の変更。
- bats 以外のテストフレームワークの導入や、コンテナを実起動する E2E テスト（CI ビルドで代替）。
