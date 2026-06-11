# Plan: dotfiles-sync

詳細な TDD 手順とコード全文は `docs/superpowers/plans/2026-06-11-dotfiles-sync.md` を参照。
本ファイルは SDD 契約としての approach / affected files / tradeoffs を記す。

## Approach

baked スクリプト `agents-dotfiles-sync` が、管理対象のベースファイルごとに3点を比較する:

- `proj` = プロジェクトの `dotfiles/<rel>` の sha256
- `up` = upstream `vendor/agents-devcontainer/dotfiles/<rel>` の sha256
- `base` = provenance マニフェスト `dotfiles/.agents-dotfiles.lock` に記録された「最後に同期した upstream 版」の sha256

`proj == base`（未上書き）かつ `up != base` なら upstream へ fast-forward しマニフェスト更新。
`proj != base`（上書き済み）かつ `up != base` かつ `proj != up` はコンフリクト → ファイルは触らず
サイドカー `<rel>.agents-upstream` を出力し警告（exit 0）。`--accept <rel>` で baseline を現 upstream
へ進め、上書きを保持したまま警告を止める。

管理対象集合は upstream `dotfiles/` 配下の regular file から
`.gitignore` `.zsh_history` `.claude/` `.gemini/` `.codex/` `.ssh/` を除外して動的に導出する。

`agents-post-create` が rebuild ごとに（非致命で）呼び出し、`scaffold.sh` が新規プロジェクトの
マニフェストを seed する。

## Affected files

| Action | Path | 役割 |
|---|---|---|
| Create | `.devcontainer/scripts/agents-dotfiles-sync` | sync エンジン（default + `--accept`）|
| Create | `tests/dotfiles-sync.bats` | sync の振る舞いテスト |
| Modify | `.devcontainer/scripts/agents-post-create` | symlink 前に sync を非致命で呼ぶ |
| Modify | `.devcontainer/Dockerfile.base` | スクリプトを `/usr/local/bin/` へ bake |
| Modify | `scaffold.sh` | `dotfiles/.agents-dotfiles.lock` を seed し force-add |
| Modify | `tests/scaffold.bats` | fixture にスクリプトを同梱、seed をテスト |
| Modify | `README.md` | dotfiles ライフサイクルを記載、stale パス削除 |

## Tradeoffs / alternatives

- **provenance マニフェスト（採用）** vs submodule 履歴からの git 3-way: 後者は追加ファイル不要だが、
  旧/新 submodule commit の解決が必要で脆く、bats での再現が難しい。自己完結でテスト容易なマニフェストを採用。
- **rebuild 時に自動適用（採用）**: 手作業ゼロ。未上書きファイルのみ書き換えるため、生じる差分は
  upstream の改善そのもの。commit 済みファイルへ差分が出る点は許容（ユーザー選択）。
- **コンフリクトは非破壊スキップ＋警告（採用）**: 3-way マージマーカーはファイル破損リスクがあるため不採用。
- ハッシュは `sha256sum`、無ければ `shasum -a 256` にフォールバック（macOS 開発 / Linux CI 両対応）。

## Out of scope

- ランタイム状態ディレクトリ（`.claude/` 等）の同期。
- upstream で削除されたファイルのプロジェクトからの自動削除（スキップ＋警告のみ）。
- bats 以外のテストフレームワーク導入。
