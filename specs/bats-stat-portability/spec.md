# Spec: bats-stat-portability

## Intent

`tests/agents-post-start.bats` の権限検証テストが macOS 専用の `stat -f '%A'` を使っており、
Linux CI（GNU coreutils）では `stat -f` がファイルシステム情報照会と解釈され `%A` が無効で失敗する。
このため `test` / `sdd` ジョブ（`bats tests/`）が main 上で恒常的に赤になっている（PR #36 で混入）。

GNU/BSD 双方で動く移植性ヘルパに置き換え、CI を緑に戻す。テストの意図（`~/.ssh` が 700、
鍵ファイルが 600）と振る舞いは変えない。

Tier 1（局所的なバグ修正、テストのみ）。

## Acceptance Criteria

1. `tests/agents-post-start.bats` が `stat -f '%A'`（macOS 専用）を直接使わず、GNU `stat -c '%a'` を
   優先し BSD `stat -f '%A'` にフォールバックする移植性ヘルパ経由で権限を読む。
2. 「sets 700 on ~/.ssh and 600 on key files」テストが Linux（GNU coreutils）と macOS（BSD stat）の
   双方で PASS する。
3. `bats tests/` が全て通過する（Linux CI 上で `test` / `sdd` ジョブが緑）。
4. テストの検証内容（期待値 700 / 600、対象パス、他テストの挙動）は変更しない。

## Out of Scope

- `agents-post-start` スクリプト本体や `.ssh` 同期ロジックの変更。
- 他テストファイルのリファクタや stat 以外の移植性問題の修正。
