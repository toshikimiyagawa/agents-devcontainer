# Plan: hermes-superpowers-bootstrap

詳細な TDD 手順とコード全文は `docs/superpowers/plans/2026-06-19-hermes-superpowers-bootstrap.md` を参照。

## アプローチ

`.devcontainer/scripts/agents-post-create` の `.hermes` symlink 作成後に Hermes superpowers bootstrap を追加する。
`hermes` が存在する場合だけ `hermes skills install --yes skills-sh/obra/superpowers` を実行し、
成功時に `$HOME/.hermes/.agents-superpowers-installed` を marker として作成する。

再実行時は marker で skip する。install 失敗や `hermes` 不在は warning/skip log を出して継続し、
postCreate 全体を失敗させない。

## 変更対象

| 種別 | ファイル | 内容 |
|---|---|---|
| Modify | `.devcontainer/scripts/agents-post-create` | Hermes superpowers bootstrap helper を追加 |
| Modify | `tests/agents-post-create.bats` | fake `hermes` で install/idempotence/failure/skip を検証 |
| Modify | `tests/hermes-install.bats` | docs が superpowers bootstrap を説明することを検証 |
| Modify | `README.md` | Hermes superpowers bootstrap を説明 |
| Modify | `.devcontainer/Agents.md` | 運用ルールを説明 |

## 代替案

- Docker image build で install: runtime の `~/.hermes` が `dotfiles/.hermes` に置き換わるため不採用。
- docs のみ: 起動時に superpowers 入りにならないため不採用。

## リスク

- `hermes skills install` は network/registry に依存する。失敗は warning にして devcontainer 起動を継続する。
- marker だけでは skill directory が後から手動削除されたケースを検出しない。初期 bootstrap の冪等性を優先し、
  手動削除後の再導入は marker 削除で対応する。
