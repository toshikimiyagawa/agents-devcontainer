# Spec: development-rules

- Tier: 2
- Status: draft (re-freeze pending human approval — supersedes the degraded frozen spec flagged in PR #54 review)
- Feature slug: development-rules

## 背景 / 意図

このリポジトリの開発ルールが AGENTS.md・`.devcontainer/Agents.md`・vendored SDD guide・CI に分散しており、
「いつ、どの環境で、何を通せば PR を作成してよいか」が一つの実行可能な契約になっていない。
issue #49 の作業中に判明した問題を一般化し、agent・人間問わず同じ phase・コマンド・証跡で
作業できるようにする。issue #50 に対応する。

本 spec は PR #54 のレビューで指摘された「Issue #50 の要件が frozen spec 化の段階で脱落・弱体化した」
問題を是正した版である。Issue #50 の各受入条件に安定 ID を付与し、spec AC → task → test まで
トレース可能にする。**Issue #50 の AC は一つも #55 へ逃がさない**。#55 は「このような劣化を将来
防ぐ汎用 enforcement / CI」だけを担う。

## Issue #50 受入条件の安定 ID

本 spec をこのトレーサビリティの正本とする（後段のトレース表を参照）。

- ISS-1: specs/development-rules/ artifacts が human-approved / frozen
- ISS-2: 現行ルールの重複・矛盾・欠落が一覧化されている
- ISS-3: canonical な repo 開発ルールの正本が一つ定義されている
- ISS-4: environment matrix がある
- ISS-5: design/implementation/verify/pre-PR/pre-merge gate が checkable command とともに定義
- ISS-6: implementation complete と issue complete の違いが明記されている
- ISS-7: devcontainer 関連変更は host full smoke green まで完了扱いにしない
- ISS-8: smoke 未成功時の PR/draft/merge policy が明記されている
- ISS-9: PR template または同等の publish gate が追加されている
- ISS-10: 可能な gate は script/CI で自動化され、docs-only のお願いに依存しない
- ISS-11: Git identity 空文字問題が修正済み、または再現手順付き個別 issue で追跡されている
- ISS-12: worktree/clone/Colima mount 制約がルールと自動チェックに反映されている
- ISS-13: relevant-path list の drift を検出できる
- ISS-14: frozen scope 外 blocker の停止・issue 分離・resume 手順が定義されている
- ISS-15: 全 acceptance criterion に対応する test がある
- ISS-16: bats tests/、repo 固有 pre-PR check、host devcontainer smoke が green である
- ISS-17: sdd-reviewer が PASS である
- ISS-18: feature branch から PR が作成され、required CI が green / mergeable である
- TECH-1: dogfood config の空 GIT_AUTHOR/GIT_COMMITTER forwarding
- TECH-2: smoke は linked worktree 対応か通常 clone 必須か
- TECH-3: clean rebuild 直後の container 内 bats tests/
- TECH-4: tool/Hermes checks の test double と実 logic の差
- TECH-5: docs/CI/script の relevant-path list を単一 source of truth にする
- TECH-6: #49 の blocked 状態を解除する条件

## 受入条件

各 AC は behavioral なら test に、doc 内容なら grep test に対応させる（ISS-15）。

- [ ] AC1: AGENTS.md が canonical 開発ルールの正本として宣言され、README / `.devcontainer/Agents.md`
  は AGENTS.md へのリンクに限定され、矛盾する重複ルールを持たない。[ISS-3]
- [ ] AC2: `docs/development/rules-inventory.md` が存在し、現行ルールの重複・矛盾・欠落を一覧化し、
  本 spec での解消方針を記す。[ISS-2]
- [ ] AC3: AGENTS.md に environment matrix があり、host(通常 clone)/host(linked worktree)/
  devcontainer/CI の可否と、smoke は `/Users` 配下の通常 clone から実行する旨を記す。[ISS-4, TECH-2]
- [ ] AC4: AGENTS.md に phase gates があり、design preflight / implementation / verify / pre-PR /
  pre-merge の各 gate が checkable command とともに定義される。[ISS-5]
- [ ] AC5: AGENTS.md の Definition of Done が「実装完了」と「issue 完了」を区別し、canonical
  `tasks.schema.json` の既存値のみで表現する（実装完了 = `phase:implement` + `status:completed`、
  issue 完了 = `phase:done` + `status:completed`）。新しい status enum を導入しない。[ISS-6]
- [ ] AC6: AGENTS.md に smoke 未成功時の PR/draft/merge policy が明記される。devcontainer 関連変更は
  host full smoke green まで完了扱いにせず、検証済み証跡のない PR を ready にしない。smoke を
  skip / warning 化しない。[ISS-7, ISS-8]
- [ ] AC7: AGENTS.md に reporting template があり、各 phase 完了時に agent が埋める項目を定義する。
- [ ] AC8: AGENTS.md に blocker handling があり、停止手順・follow-up issue 作成・resume 条件を
  定義する。[ISS-14]
- [ ] AC9: `docs/development/{environment-matrix,smoke-guide,blocker-handling}.md` が存在し、
  それぞれ linked worktree で smoke が動かない理由と正しい実行環境 / OS 別 smoke 手順と証跡保存 /
  blocked_reason・follow-up issue テンプレートを説明する。[ISS-4, ISS-12, ISS-14]
- [ ] AC10: `.github/pull_request_template.md` が存在し、検証済み smoke 証跡・SDD tier・spec path・
  sdd-reviewer 結果・CI 結果の記入欄を含む。[ISS-9]
- [ ] AC11: `scripts/smoke-devcontainer.sh` は smoke 成功時のみ `.sdd/smoke-evidence.txt` を
  atomic に生成し、HEAD commit SHA・実行環境・成功マーカーを記録する。smoke 失敗時は証跡を
  生成しない（pipeline で失敗を隠さない）。[ISS-7, ISS-10]
- [ ] AC12: `scripts/pre-pr-check.sh` は全経路 fail-closed である。base ref 取得失敗・git error・
  detached HEAD・dirty/staged/unstaged worktree を検出して非ゼロ終了し、狭い diff へ無警告
  fallback しない。[ISS-10, ISS-12]
- [ ] AC13: `scripts/pre-pr-check.sh` は smoke 証跡の内容を検証する。記録された commit SHA が
  現在の HEAD と一致し成功マーカーがある場合のみ通過し、empty/forged/stale/wrong-HEAD 証跡を
  拒否する。[ISS-7, ISS-10]
- [ ] AC14: devcontainer 関連 path list が単一 source of truth として定義され、
  `scripts/pre-pr-check.sh` と `.github/workflows/smoke-devcontainer.yml` が同じリストを参照する。
  両者の drift を検出する test がある。[ISS-13, TECH-5]
- [ ] AC15: `scripts/pre-pr-check.sh` は `.sdd/tasks.json` を検証する。current feature が存在し
  canonical schema 準拠で blocked でないことを確認し、malformed JSON は fail-closed とする。[ISS-10]
- [ ] AC16: dogfood `.devcontainer/devcontainer.json` が空の GIT_AUTHOR/GIT_COMMITTER を
  container に forwarding しないことを test が固定する。[ISS-11, TECH-1]
- [ ] AC17: `tests/` が全 behavioral AC を負例込みで検証する。最低限: empty/forged/stale/wrong-HEAD
  evidence、smoke 失敗が隠れないこと、base ref 取得失敗の fail-closed、detached HEAD、
  dirty/staged worktree、malformed state JSON、current feature の欠落/未完了/blocked、
  path-list drift。各負例は本修正前に RED、修正後に GREEN になる。[ISS-15]
- [ ] AC18: `.sdd/tasks.json` に `development-rules` が canonical schema-valid で存在し、
  `.sdd/state.json` が `development-rules` の実 phase を指し、`specs/development-rules/tasks.md` の
  完了状態が実態と一致する。[ISS-1, ISS-17 の証跡整合]
- [ ] AC19: `bats tests/` 全通過、`scripts/pre-pr-check.sh` 通過、host devcontainer smoke green。[ISS-16]

## Issue AC → spec AC → task → test トレース表

| Issue #50 AC | spec AC | task | test / 検証 |
|---|---|---|---|
| ISS-1 | AC18 + process | T-state, freeze | sdd-reviewer + state 整合 test |
| ISS-2 | AC2 | T-docs | `development-rules.bats: rules-inventory` |
| ISS-3 | AC1 | T-agents | `development-rules.bats: AGENTS.md canonical` |
| ISS-4 | AC3, AC9 | T-agents, T-docs | `development-rules.bats: env matrix` |
| ISS-5 | AC4 | T-agents | `development-rules.bats: phase gates` |
| ISS-6 | AC5 | T-agents | `development-rules.bats: DoD phase+status` |
| ISS-7 | AC6, AC11, AC13 | T-smoke-ev, T-prepr | `pre-pr-check.bats: stale/wrong-HEAD/forged` |
| ISS-8 | AC6, AC10 | T-agents, T-prtmpl | `development-rules.bats: smoke policy` |
| ISS-9 | AC10 | T-prtmpl | `development-rules.bats: PR template` |
| ISS-10 | AC11, AC12, AC13 | T-smoke-ev, T-prepr | `pre-pr-check.bats: fail-closed/content` |
| ISS-11 | AC16 | T-gitid | `devcontainer.bats: no empty GIT_AUTHOR` |
| ISS-12 | AC3, AC9, AC12 | T-agents, T-prepr | `pre-pr-check.bats: detached/dirty` |
| ISS-13 | AC14 | T-pathlist | `pre-pr-check.bats: path-list drift` |
| ISS-14 | AC8, AC9 | T-agents, T-docs | `development-rules.bats: blocker handling` |
| ISS-15 | AC17 | T-prepr, T-tests | negative test 群 RED→GREEN |
| ISS-16 | AC19 + verify | T-verify | bats / pre-pr-check / host smoke |
| ISS-17 | process (verify) | T-verify | 独立 sdd-reviewer PASS |
| ISS-18 | process (publish) | T-publish | PR + CI green |
| TECH-1 | AC16 | T-gitid | `devcontainer.bats: no empty GIT_AUTHOR` |
| TECH-2 | AC3 | T-agents, T-docs | env matrix / environment-matrix.md |
| TECH-3 | — (#49/#53 で対応済み) | — | smoke が clean rebuild で container bats 実行 |
| TECH-4 | — (#49/#53 で対応済み) | — | smoke が実 logic / Hermes symlink 先を検証 |
| TECH-5 | AC14 | T-pathlist | path-list drift test |
| TECH-6 | — (#49 は #53 で merge 済み、blocked 解除済み) | — | N/A |

## scope外 / follow-up

以下は #55「Issue 要件の spec 縮退と形骸化した SDD レビューを防止する」が**汎用 enforcement** として
所有する。本 spec はそれらを強制する CI/tooling を作らず、#54 では具体的 gate 実体・ルール・自身の
test を提供する。

- Issue→spec AC トレースを機械検査し未対応で freeze を禁止する CI → #55
- `tasks.json` を canonical schema で検証する汎用 CI → #55
- `state.json`/`tasks.json`/`tasks.md` 整合性の汎用 CI → #55
- reviewer 手順への「元 Issue 差分レビュー」追加（標準ルール化） → #55
- gate 実装向け汎用 negative-test checklist → #55
- PR #54 の劣化を再現する fixture test → #55

理由: いずれも単一 feature の deliverable ではなく、全 feature に適用する process/CI 強制であり、
#55 が明示的に受入条件として列挙している。Issue #50 自身の AC（path-list drift 検出 = AC14、
mount 制約の自動チェック = AC12 等）は #54 に残し #55 へ逃がさない。

## 制約 / 前提

- `tasks.schema.json` の status enum は `pending/in_progress/completed/blocked` のみ。新値を追加しない。
- `.sdd/smoke-evidence.txt` は `.gitignore` 済みで commit しない。
- 既存の Claude/Gemini/Codex/Hermes persistence・既存 bats・既存 CI を壊さない。
- AGENTS.md は CLAUDE.md からの symlink 実体。symlink を壊さない。

## 非目標

- vendored SDD guide の一般論を書き換えること
- downstream repository を同時に統一すること
- linked worktree での smoke 対応（設計上不要）
- smoke を通すためにチェックを skip / warning 化すること
- CI や SDD hook を無効化すること
