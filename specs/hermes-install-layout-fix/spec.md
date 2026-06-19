# Spec: hermes-install-layout-fix

- Tier: 1
- Status: frozen
- Feature slug: hermes-install-layout-fix

## 背景 / 意図

Hermes Agent installer は per-user layout で `~/.hermes/hermes-agent` に本体を置き、
`~/.local/bin/hermes` wrapper は `/home/ubuntu/.hermes/hermes-agent/venv/bin/hermes` を直接実行する。

既存の `agents-post-create` は `~/.hermes` 全体を `dotfiles/.hermes` への symlink に置き換えるため、
image build 時に install された `~/.hermes/hermes-agent` が隠れて `hermes` command が起動不能になる。

Hermes 本体 install directory は container image の `$HOME/.hermes` に残し、user state だけを
`dotfiles/.hermes` に永続化する。

## 受入条件

- [ ] AC1: `agents-post-create` は `$HOME/.hermes` 全体を symlink に置き換えない。
- [ ] AC2: 既存の `$HOME/.hermes/hermes-agent` は `agents-post-create` 後も残る。
- [ ] AC3: Hermes user state subpaths は `dotfiles/.hermes` に永続化される。対象は `config.yaml`, `.env`, `skills`, `memories`。
- [ ] AC4: Hermes superpowers marker は `dotfiles/.hermes/.agents-superpowers-installed` に保存される。
- [ ] AC5: superpowers bootstrap は Hermes 本体が残った状態で実行され、再実行時は marker で skip する。
- [ ] AC6: README と `.devcontainer/Agents.md` は `~/.hermes` 全体 symlink ではなく、Hermes 本体を残して state subpaths を永続化することを説明する。
- [ ] AC7: Tests cover AC1-6 and `bats tests/` passes.

## スコープ外

- Host `~/.hermes` を bind mount/import/copy すること。
- Hermes installer の layout を変更すること。
- Hermes 本体 `hermes-agent` を `dotfiles/.hermes` に移動すること。
