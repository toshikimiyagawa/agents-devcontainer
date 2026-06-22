# Plan: development-rules

## アプローチ

3層構造で開発ルールを確立する:
- Layer 1（読めるルール）: AGENTS.md に5セクション追加 + docs/development/ に詳細解説
- Layer 2（実行できる強制）: scripts/pre-pr-check.sh + PR template + CI evidence artifact
- Layer 3（状態管理）: .gitignore に .sdd/smoke-evidence.txt 追加

TDD: tests/pre-pr-check.bats を先に書いて RED を確認してから scripts/pre-pr-check.sh を実装する。

## 影響範囲 / 主要ファイル

- `AGENTS.md` — 5セクション追加
- `scripts/pre-pr-check.sh` — 新規作成（PR前チェック）
- `tests/pre-pr-check.bats` — 新規作成（TDD RED→GREEN）
- `docs/development/` — 3ファイル新規作成
- `.github/pull_request_template.md` — 新規作成
- `.gitignore` — .sdd/smoke-evidence.txt 追加
- `.github/workflows/smoke-devcontainer.yml` — evidence artifact 追加

## リスク / ロールバック

- リスク: PR template 追加でオープン中の PR に影響しない（新規 PR のみ適用）
- リスク: .gitignore に .sdd/smoke-evidence.txt を追加しても既存の .sdd/ エントリには影響しない
- ロールバック: 各ファイルを revert すれば元の状態に戻る
