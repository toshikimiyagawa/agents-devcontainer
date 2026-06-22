# Plan: development-rules

## アプローチ

3層構造で開発ルールを確立し、**Issue #50 の全 AC を spec → task → test までトレース**する。
PR #54 レビューで指摘された「証跡が存在確認のみ」「fail-open」「schema 違反 status」
「SDD 状態不整合」「Issue 要件の脱落」を是正する。

- Layer 1（読めるルール）: AGENTS.md を canonical 正本に整理 + docs/development/（rules-inventory
  含む）。DoD は canonical schema の phase+status で表現。
- Layer 2（実行できる強制）: pre-pr-check.sh を**全経路 fail-closed**化し、smoke 証跡の**内容**を
  検証。smoke-devcontainer.sh は**成功時のみ atomic** に SHA・環境・成功マーカーを記録。
  devcontainer 関連 path list を**単一 source of truth** 化。
- Layer 3（状態管理）: .sdd/tasks.json に development-rules を schema-valid で追加、state.json を
  向ける、tasks.md 完了状態を実態に一致。

TDD: 負例テストを先に RED 化してから実装を GREEN にする。

## 影響範囲 / 主要ファイル

- `specs/development-rules/{spec,plan,tasks}.md` — Issue #50 トレース表付きに是正
- `AGENTS.md` — canonical 宣言・smoke policy・DoD を phase+status へ修正
- `docs/development/rules-inventory.md` — 新規（重複・矛盾・欠落の一覧）
- `docs/development/{environment-matrix,smoke-guide,blocker-handling}.md` — 既存、証跡仕様に整合
- `scripts/smoke-devcontainer.sh` — 成功時のみ証跡を atomic 生成（SHA・環境・marker）
- `scripts/pre-pr-check.sh` — fail-closed + 証跡内容検証 + path-list 単一参照 + schema 検証
- `scripts/devcontainer-paths.sh`（or 同等）— devcontainer 関連 path list の単一 source of truth
- `.github/workflows/smoke-devcontainer.yml` — 同じ path list を参照
- `.github/pull_request_template.md` — 検証済み証跡前提に整合
- `tests/pre-pr-check.bats` — 負例群を追加
- `tests/development-rules.bats` — doc/ルール内容を grep 検証（新規、ISS-15 対応）
- `tests/devcontainer.bats` — dogfood 空 GIT_AUTHOR 非 forwarding を固定
- `.sdd/tasks.json`, `.sdd/state.json` — development-rules を整合

## 検討した代替案とトレードオフ

- 新 status enum 追加: DoD を直接表現できるが canonical schema/kanban と非互換。phase+status で
  既存値のみで表現できるため不採用。
- 証跡を存在確認のみ: 実装が軽いが docs-only と同等で ISS-7/10 を満たさない。内容検証必須。
- enforcement CI も #54 に含める: #55 と重複し PR 肥大化。#50 自身の AC（drift 検出等）は #54、
  汎用 enforcement は #55 に分離。

## リスク / ロールバック

- リスク: 証跡内容検証を厳格化すると正当な smoke でも HEAD 不一致で落ちうる。pre-pr-check 実行前に
  commit を確定させる運用を docs に明記。
- リスク: path-list 単一化で workflow の paths: 構文と script の参照形式が乖離。drift test で固定。
- ロールバック: 各ファイルを revert すれば従来状態へ戻る。
