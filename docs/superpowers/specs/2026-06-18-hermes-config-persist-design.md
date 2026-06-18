# Hermes Config Persistence Design

対応 spec: `specs/hermes-config-persist/`

## 背景

Issue #44。Hermes Agent は base image に per-user install されているが、runtime config は
devcontainer 側で永続化されていない。ホストでは `/Users/toshiki/.hermes/config.yaml` が
Solvelio vLLM endpoint (`https://vllm.solvelio.com/v1`) と
`qwen3.5-122b-a10b-nvfp4` を使うよう設定済みだが、devcontainer は host `~/.hermes` を
mount しておらず、`agents-post-create` も `.hermes` を `$HOME` に symlink しない。

そのため container 内の `hermes` は rebuild 後に未設定または別設定になり得る。

## 採用方針

`dotfiles/.hermes` を devcontainer 専用の Hermes state directory として作成し、
`agents-post-create` で `$HOME/.hermes -> /workspace/dotfiles/.hermes` に symlink する。

この repo の既存設計は `.claude`, `.gemini`, `.codex` を host と共有せず、
workspace 配下の gitignored runtime state として永続化している。Hermes も同じ境界にそろえる。

## 代替案

- Host `~/.hermes` bind mount: host/container の設定を完全共有できるが、認証・履歴・memory・state DB
  まで共有する。OS 間の permission 差分も踏みやすいため不採用。
- モデル設定だけ env/config snippet で注入: Solvelio vLLM model には揃えやすいが、Hermes の runtime
  state persistence という根本課題は残るため不採用。

## 振る舞い

- New project scaffold は `dotfiles/.hermes` を作成する。
- Dogfood devcontainer の `initializeCommand` も `dotfiles/.hermes` を作成する。
- `agents-post-create` は `.claude`, `.gemini`, `.codex`, `.hermes` を symlink 対象にする。
- `agents-dotfiles-sync` は `.hermes` を upstream-managed dotfiles の同期対象から除外する。
- `dotfiles/.gitignore` の gitignore-by-default model により `dotfiles/.hermes` の中身は commit されない。
- README と `.devcontainer/Agents.md` は Hermes state が `dotfiles/.hermes` に永続化されること、
  host `~/.hermes` とは共有しないこと、モデル設定は container 内で `hermes setup` または
  `dotfiles/.hermes/config.yaml` に入れることを説明する。

## テスト方針

- `tests/scaffold.bats` で scaffold が `dotfiles/.hermes` を作成し、generated
  `devcontainer.json` の `initializeCommand` に `dotfiles/.hermes` が含まれることを検証する。
- `tests/devcontainer.bats` または既存 script test で dogfood `.devcontainer/devcontainer.json` に
  `dotfiles/.hermes` が含まれることを検証する。
- `tests/agents-post-create.bats` を追加し、`agents-post-create` が `.hermes` を
  `$HOME/.hermes -> /workspace/dotfiles/.hermes` に symlink することを検証する。
- `tests/dotfiles-sync.bats` の除外集合テストに `.hermes` を追加する。
- `tests/hermes-install.bats` で docs に Hermes persistence の説明があることを検証する。

## スコープ外

- Host `~/.hermes` の自動 import / copy。
- API key や token を repository に commit する仕組み。
- Solvelio vLLM endpoint を全利用者の default として bake すること。
- Hermes installer や model picker の変更。
