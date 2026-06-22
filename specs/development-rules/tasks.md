# Tasks: development-rules

実装計画の詳細は `docs/superpowers/plans/2026-06-22-development-rules.md` を参照。
TDD（負例を先に RED 化 → 実装で GREEN）と頻繁な commit を守ること。

PR #54 レビュー是正版。Issue #50 トレース表は spec.md を正本とする。

## T-smoke-ev — smoke 証跡を成功時のみ atomic 生成（AC11）
- [ ] `tests/smoke-devcontainer.bats` に「成功時のみ証跡生成・SHA/環境/marker 記録・失敗時は非生成」の RED を追加
- [ ] `scripts/smoke-devcontainer.sh` を成功時のみ atomic 書き込みに修正
- [ ] GREEN 確認 → commit

## T-pathlist — devcontainer 関連 path list の単一 source of truth（AC14, TECH-5）
- [ ] path list の単一定義（`scripts/devcontainer-paths.sh` 等）を作る
- [ ] `tests/pre-pr-check.bats` に script と workflow の drift 検出 test を RED 追加
- [ ] `scripts/pre-pr-check.sh` と `smoke-devcontainer.yml` を同じリスト参照に修正
- [ ] GREEN 確認 → commit

## T-prepr — pre-pr-check.sh fail-closed + 証跡内容検証 + schema 検証（AC12, AC13, AC15）
- [ ] 負例 RED を `tests/pre-pr-check.bats` に追加: base ref 取得失敗 fail-closed / detached HEAD /
  dirty・staged・unstaged / empty・forged・stale・wrong-HEAD evidence / malformed state JSON /
  current feature 欠落・未完了・blocked
- [ ] `scripts/pre-pr-check.sh` を全経路 fail-closed・証跡内容検証・schema 検証に修正
- [ ] `bash -n` + GREEN 確認 → commit

## T-tests — 全負例 RED→GREEN の確認（AC17, ISS-15）
- [ ] T-smoke-ev / T-prepr / T-pathlist の負例が修正前 RED・修正後 GREEN であることを確認

## T-gitid — dogfood 空 GIT_AUTHOR 非 forwarding 固定（AC16, TECH-1）
- [ ] `tests/devcontainer.bats` に dogfood config が空 GIT_AUTHOR/COMMITTER を forwarding しない RED/固定 test を追加
- [ ] GREEN 確認 → commit

## T-agents — AGENTS.md 是正（AC1, AC4, AC5, AC6, AC7, AC8）
- [ ] canonical 正本宣言・smoke policy・DoD を phase+status へ修正・reporting template・blocker handling
- [ ] `tests/development-rules.bats` に doc 内容 grep test を追加
- [ ] GREEN 確認 → commit

## T-docs — docs/development/ 是正・追加（AC2, AC9）
- [ ] `docs/development/rules-inventory.md` を新規作成（重複・矛盾・欠落の一覧）
- [ ] environment-matrix / smoke-guide / blocker-handling を証跡仕様に整合
- [ ] `tests/development-rules.bats` で内容を検証
- [ ] commit

## T-prtmpl — PR template 是正（AC10）
- [ ] 検証済み smoke 証跡・spec path・sdd-reviewer 結果欄に整合
- [ ] commit

## T-state — SDD 状態整合（AC18）
- [ ] `.sdd/tasks.json` に development-rules を schema-valid で追加
- [ ] `.sdd/state.json` を development-rules の実 phase に向ける
- [ ] この tasks.md の完了状態を実態に一致させる
- [ ] commit

## T-verify — 総合検証（AC19, ISS-16, ISS-17）
- [ ] `bats tests/` 全通過
- [ ] `for f in .devcontainer/scripts/*; do bash -n "$f"; done` + `bash -n scripts/*.sh`
- [ ] host smoke 再実行（成功証跡を再生成）
- [ ] 独立 sdd-reviewer を Issue #50 起点で実行し PASS

## T-publish — 公開（ISS-18）
- [ ] PR #54 を更新（または再作成）し required CI green を確認

## 受け入れ基準 ↔ test 対応

spec.md の「Issue AC → spec AC → task → test トレース表」を参照。全 behavioral AC は
`tests/pre-pr-check.bats` / `tests/smoke-devcontainer.bats` / `tests/devcontainer.bats` /
`tests/development-rules.bats` の test に対応する（ISS-15）。
