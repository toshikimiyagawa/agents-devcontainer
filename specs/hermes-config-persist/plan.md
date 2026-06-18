# Plan: hermes-config-persist

## アプローチ

Hermes Agent の runtime state を既存の `.claude` / `.gemini` / `.codex` と同じ扱いにする。
具体的には `dotfiles/.hermes` を container 専用の永続化先として作成し、
`agents-post-create` が `$HOME/.hermes` から `/workspace/dotfiles/.hermes` へ symlink する。

Host `~/.hermes` は bind mount しない。provider/model は container 内で `hermes setup` を実行するか、
`dotfiles/.hermes/config.yaml` に設定する。`dotfiles/.gitignore` の gitignore-by-default により
`.hermes` の中身は commit されない。

## 影響範囲 / 主要ファイル

- `.devcontainer/devcontainer.json` — dogfood repo の `initializeCommand` に `dotfiles/.hermes` を追加。
- `scaffold/devcontainer.base.json` — consumer project 用 base config の `initializeCommand` に `dotfiles/.hermes` を追加。
- `scaffold.sh` — 新規 project 作成時に `dotfiles/.hermes` を作成し、static fallback config にも含める。
- `.devcontainer/scripts/agents-post-create` — `.hermes` を runtime state symlink 対象に追加。
  production default は `/workspace/dotfiles` のままにし、bats では `AGENTS_DOTFILES_PROJECT` で差し替える。
- `.devcontainer/scripts/agents-dotfiles-sync` — `.hermes` を upstream-managed dotfiles sync 対象から除外。
- `tests/scaffold.bats` — scaffold が `.hermes` を作ることを検証。
- `tests/devcontainer.bats` — dogfood devcontainer config が `.hermes` を作ることを検証。
- `tests/agents-post-create.bats` — post-create symlink を検証する新規 tests。
- `tests/dotfiles-sync.bats` — `.hermes` 除外を検証。
- `tests/hermes-install.bats` — docs が Hermes persistence を説明することを検証。
- `README.md` — Hermes state persistence と host 非共有を説明。
- `.devcontainer/Agents.md` — 運用ルールに `.hermes` を追加。

## 検討した代替案とトレードオフ

- Host `~/.hermes` bind mount: host/container の設定を完全共有できるが、認証・履歴・memory・state DB も
  共有してしまう。既存の container 専用 state 方針と合わず、OS 間 permission 差分も踏みやすいため不採用。
- モデル設定だけ env/config snippet で注入: `vllm.solvelio.com` の Qwen model にはすぐ揃うが、
  Hermes の runtime state persistence は解決しないため不採用。
- `dotfiles/.hermes` symlink: 既存 `.claude` / `.gemini` / `.codex` と同じ境界で、rebuild 耐性と
  host 非共有を両立できるため採用。

## リスク / ロールバック

- リスク: `agents-post-create` が既存 `$HOME/.hermes` を削除して symlink するため、container 内にだけ存在した
  ephemeral Hermes state は初回適用時に失われる。これは rebuild で消える状態であり、今回の永続化先へ移す設計と整合する。
- リスク: `.hermes` を sync 除外し忘れると upstream-managed dotfiles として扱われる。`tests/dotfiles-sync.bats`
  で除外を固定する。
- ロールバック: `.hermes` を initialize/symlink/exclusion/docs/tests から外せば、従来の未永続化状態に戻る。
