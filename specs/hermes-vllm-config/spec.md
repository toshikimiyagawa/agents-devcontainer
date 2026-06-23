# Spec: hermes-vllm-config

## Intent

devcontainer イメージ内に Hermes Agent のプロバイダ設定を焼き込み、
vLLM インスタンス（`https://vllm.solvelio.com/v1`）上で動作中の
**qwen3.6-35b-a3b** をデフォルトモデルとして利用可能にする。

これにより、コンテナ起動直後に `hermes setup` の対話なしで
Hermes Agent が利用可能になる。

## Acceptance Criteria

1. `.devcontainer/scripts/hermes-init.sh` がイメージビルド時に
   `ubuntu` ユーザーの `~/.hermes/config.yaml` を生成し、
   `model.default` を `qwen3.6-35b-a3b`、
   `model.provider` を `custom`（OpenAI互換エンドポイント）、
   `model.base_url` を `https://vllm.solvelio.com/v1` に設定する。

2. `.devcontainer/Dockerfile.base` が公式インストーラ実行の直後に
   `hermes-init.sh` をコピー＆実行する。

3. `tests/hermes-config.bats` が AC1-2 を検証し、`bats tests/` が
   全て通過する。

## Out of Scope

- 既存エージェント（Claude Code / Gemini CLI / Codex CLI）の設定変更。
- vLLM インスタンスの構築・運用。
- API キーや認証情報の管理（vLLM は LAN 内公開を想定し認証不要）。
