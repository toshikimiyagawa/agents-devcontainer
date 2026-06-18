# Spec: hermes-config-persist

- Tier: 2
- Status: frozen
- Feature slug: hermes-config-persist

## 背景 / 意図

Hermes Agent は `.devcontainer/Dockerfile.base` で `USER ubuntu` の per-user layout
(`~/.hermes`, `~/.local/bin/hermes`) に install される。しかし devcontainer runtime では
`~/.hermes` が永続化されていないため、container rebuild 後に Hermes の provider/model 設定・認証・
履歴・memory が消える可能性がある。

この repo の既存方針では `.claude`, `.gemini`, `.codex` を host と共有せず、
workspace 配下の `dotfiles/` に gitignored runtime state として永続化する。Hermes も同じ境界で扱い、
host `~/.hermes` を bind mount せずに container 専用の `dotfiles/.hermes` を永続化先にする。

Issue #44 に対応する。

## 受入条件

- [ ] AC1: `.devcontainer/devcontainer.json` の `initializeCommand` が `dotfiles/.hermes` を作成する。
- [ ] AC2: `scaffold/devcontainer.base.json` の `initializeCommand` が `dotfiles/.hermes` を作成する。
- [ ] AC3: `scaffold.sh` が新規 project に `dotfiles/.hermes` を作成する。static fallback の
  `devcontainer.json` も `dotfiles/.hermes` を作成する。
- [ ] AC4: `.devcontainer/scripts/agents-post-create` が `$HOME/.hermes` を
  `/workspace/dotfiles/.hermes` への symlink として作成する。再実行しても冪等である。
- [ ] AC5: `.devcontainer/scripts/agents-dotfiles-sync` は `.hermes` と `.hermes/*` を upstream-managed
  dotfiles sync の対象から除外する。
- [ ] AC6: `README.md` が Hermes runtime state は `dotfiles/.hermes` に永続化され、host `~/.hermes`
  とは共有しないこと、container 内で `hermes setup` または `dotfiles/.hermes/config.yaml` により
  provider/model を設定することを説明する。
- [ ] AC7: `.devcontainer/Agents.md` が `.hermes` の永続化・host 非共有・gitignore 前提を説明する。
- [ ] AC8: Tests cover AC1-7 and `bats tests/` passes.

## スコープ外

- Host `~/.hermes` を devcontainer に bind mount すること。
- Host `~/.hermes/config.yaml` を自動 copy/import すること。
- `https://vllm.solvelio.com/v1` や `qwen3.5-122b-a10b-nvfp4` を全利用者の default として bake すること。
- Hermes の provider/model/API key を repository に commit すること。
- Hermes installer や upstream Hermes Agent のコード変更。

## 制約 / 前提

- `dotfiles/.gitignore` は gitignore-by-default (`*`, `!.gitignore`) なので、`dotfiles/.hermes` の中身は
  明示的に force-add しない限り commit されない。
- `.hermes` は runtime state directory として扱い、`agents-dotfiles-sync` の upstream-managed
  dotfiles 対象には含めない。
- Existing Claude/Gemini/Codex persistence behavior must not regress.
