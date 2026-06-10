# Tasks: dotfiles-sync

順序付きの実装ステップ。各ステップのコード全文は
`docs/superpowers/plans/2026-06-11-dotfiles-sync.md` の同名タスクを参照（self-contained なコードはそちら）。
TDD（RED→GREEN）と頻繁な commit を守ること。

## Task 1 — sync エンジン `agents-dotfiles-sync`
- [ ] `tests/dotfiles-sync.bats` を作成（全ケース）
- [ ] `bats tests/dotfiles-sync.bats` で RED を確認
- [ ] `.devcontainer/scripts/agents-dotfiles-sync` を実装、`chmod +x`
- [ ] `bats tests/dotfiles-sync.bats` で GREEN を確認
- [ ] commit

## Task 2 — `agents-post-create` 連携
- [ ] `log()` 定義直後・section 1 の前に section 0（`command -v agents-dotfiles-sync` で非致命呼び出し）を追加
- [ ] `bash -n .devcontainer/scripts/agents-post-create`
- [ ] commit

## Task 3 — `Dockerfile.base` へ bake
- [ ] `agents-dotfiles-sync` の `COPY` 追加＋`chmod 0755` 行に追記
- [ ] commit

## Task 4 — `scaffold.sh` で manifest seed
- [ ] `tests/scaffold.bats` の fixture にスクリプトを同梱
- [ ] manifest seed のテストを追加 → RED 確認
- [ ] `scaffold.sh` の dotfiles コピー分岐に seed＋`git add -f .agents-dotfiles.lock` を追加
- [ ] `bats tests/scaffold.bats` で GREEN を確認
- [ ] commit

## Task 5 — README ライフサイクル文書
- [ ] line 204 の `.devcontainer/dotfiles/.claude/` → `dotfiles/.claude/`
- [ ] 「dotfiles のカスタマイズ」節を「dotfiles のライフサイクル」節へ全面刷新
- [ ] `grep -rn "/opt/agents/dotfiles\|.devcontainer/dotfiles" README.md` が空であることを確認
- [ ] commit

## Task 6 — 総合検証
- [ ] `bats tests/` 全通過
- [ ] `for f in .devcontainer/scripts/*; do bash -n "$f"; done`

## 受け入れ基準 ↔ テスト 対応表

| AC | 検証 |
|---|---|
| 1 (スクリプト存在＋bake) | Task3 / `bash -n` / Dockerfile.base レビュー |
| 2 (未上書き＋upstream更新→自動更新) | `dotfiles-sync.bats: fast-forwards an untouched file...` |
| 3 (上書き＋upstream変更→非破壊コンフリクト) | `...reports a conflict and writes a sidecar...` |
| 4 (上書き＋upstream据置→無変更) | `...leaves an overridden file alone...` |
| 5 (新規upstreamファイル→コピー＋記録) | `...copies a new upstream file...` |
| 6 (`--accept`) | `--accept stops the conflict warning...` |
| 7 (upstream無し→exit0無変更) | `exits 0 and changes nothing when UPSTREAM_DIR is missing` |
| 8 (除外集合) | `excludes .claude .gemini .codex .ssh .zsh_history .gitignore` |
| 9 (post-create 連携) | Task2 / `bash -n` |
| 10 (scaffold seed) | `scaffold.bats: seeds and commits dotfiles/.agents-dotfiles.lock` |
| 11 (README) | Task5 / `grep` 確認 |
| 12 (`bats tests/` 全通過) | Task6 |
