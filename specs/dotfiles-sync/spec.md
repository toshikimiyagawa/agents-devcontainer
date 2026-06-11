# Spec: dotfiles-sync

## Intent

消費プロジェクトが「自分で上書きしていない」ベース dotfile について、upstream
(`vendor/agents-devcontainer/dotfiles/*`) の更新を rebuild 時に自動で追従できるようにする。
上書き済みのファイルは決して破壊せず、コンフリクト時は非破壊でスキップ＋警告する。
あわせて dotfiles ライフサイクルのドキュメント（README）を最新化する。

判定は provenance マニフェスト `dotfiles/.agents-dotfiles.lock`（最後に同期した upstream 版の
sha256 を記録）と現プロジェクトファイルのハッシュ比較で行う。管理対象は upstream `dotfiles/`
配下の regular file から `.claude/` `.gemini/` `.codex/` `.ssh/` `.zsh_history` `.gitignore`
を除外した集合（ファイル単位、ハードコードしない）。

issue #25 に対応する。

## Acceptance Criteria

1. `agents-dotfiles-sync` が実行可能スクリプトとして `.devcontainer/scripts/` に存在し、
   `Dockerfile.base` でイメージの `/usr/local/bin/agents-dotfiles-sync` に焼き込まれる。
2. 管理ファイルが manifest baseline と一致（未上書き）かつ upstream が更新されている場合、
   sync はプロジェクトファイルを upstream 版で上書きし、manifest のハッシュを更新する。
3. 管理ファイルが上書き済み（baseline と相違）かつ upstream も変更されている場合、sync は
   プロジェクトファイルを変更せず、`<relpath>.agents-upstream` サイドカーを出力し、コンフリクト
   一覧に当該パスを報告する（exit 0）。
4. 管理ファイルが上書き済みでも upstream が未変更なら、sync は何も変更しない。
5. プロジェクトに存在しない upstream の新規ファイルは、sync がコピーして manifest に記録する。
6. `agents-dotfiles-sync --accept <path>` は `<path>` の manifest baseline を現 upstream ハッシュ
   へ進め、プロジェクトファイルは変更しない。その後の sync で当該パスのコンフリクト警告が出ない。
7. `UPSTREAM_DIR` が存在しない場合、sync は何も変更せず exit 0 する。
8. 管理対象集合は upstream から導出され、`.claude/` `.gemini/` `.codex/` `.ssh/`
   `.zsh_history` `.gitignore` を除外する。
9. `agents-post-create` が `agents-dotfiles-sync` を（非致命で）呼び出す。
10. `scaffold.sh` が `dotfiles/.agents-dotfiles.lock` を upstream ハッシュで seed し、`git add -f`
    で force-commit する。
11. README が source of truth・初回コピーのタイミング・`agents-post-create` の挙動・submodule
    bump 後の更新手順・上書きが保護される仕組みを記載し、stale な `.devcontainer/dotfiles/` と
    `/opt/agents/dotfiles/` への参照が残っていない。
12. `bats tests/` が全て通る。新規 `tests/dotfiles-sync.bats` が criteria 2〜8 を検証する。

## Out of Scope

- 既存テストフレームワーク（bats）以外の導入。
- `.claude/` `.gemini/` `.codex/` 等ランタイム状態ディレクトリの同期。
- upstream で削除されたファイルのプロジェクトからの自動削除（スキップ＋警告のみ）。
