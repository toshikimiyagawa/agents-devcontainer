# Spec: hermes-superpowers-bootstrap

- Tier: 2
- Status: frozen
- Feature slug: hermes-superpowers-bootstrap

## 背景 / 意図

Hermes Agent は devcontainer base image に install 済みで、`$HOME/.hermes` は
container 専用の `dotfiles/.hermes` に永続化される。これにより provider/model 設定や
Hermes runtime state は rebuild 後も残る。

Issue #46 では、devcontainer 起動時点で Hermes Agent に `obra/superpowers` skill pack が
導入済みになることを求めている。対象はこの repo の dogfood devcontainer だけでなく、
`scaffold.sh` で生成される consumer project の devcontainer も含む。

## 受入条件

- [ ] AC1: `.devcontainer/scripts/agents-post-create` は `$HOME/.hermes` を project dotfiles へ
  symlink した後、`hermes skills install --yes skills-sh/obra/superpowers` を実行する。
- [ ] AC2: `hermes` command が存在しない場合、`agents-post-create` は warning/skip log を出し、
  exit 0 で継続する。
- [ ] AC3: install 成功時、`$HOME/.hermes/.agents-superpowers-installed` marker を作成する。
- [ ] AC4: marker が存在する再実行では `hermes skills install` を再実行しない。
- [ ] AC5: install が失敗した場合、`agents-post-create` は warning を出し、marker を作成せず、
  exit 0 で継続する。
- [ ] AC6: `README.md` は Hermes superpowers が devcontainer setup で bootstrapped され、
  state は container 専用の `dotfiles/.hermes` に保存されることを説明する。
- [ ] AC7: `.devcontainer/Agents.md` は Hermes superpowers bootstrap の運用ルール
  （postCreate、idempotent、failure non-fatal、host `~/.hermes` 非共有）を説明する。
- [ ] AC8: Tests cover AC1-7 without real network access, and `bats tests/` passes.

## スコープ外

- Host `~/.hermes` を devcontainer に bind mount すること。
- Host `~/.hermes/skills` を container に import/copy すること。
- Hermes provider/model/API key を repository に commit すること。
- `skills-sh/obra/superpowers` 以外の Hermes skill pack を自動導入すること。
- Docker image build 時に Hermes skills を install すること。

## 制約 / 前提

- `agents-post-create` は dogfood devcontainer と scaffold 先 consumer project の両方で使われる共通 script。
- `agents-post-create` は devcontainer 起動を壊さないため、network/registry 依存の処理を fatal にしない。
- `dotfiles/.hermes` は gitignore-by-default の runtime state。中身は明示的に force-add しない限り commit しない。
- Existing Claude/Gemini/Codex/Hermes state persistence behavior must not regress.
