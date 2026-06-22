# Rules Inventory — 重複・矛盾・欠落の棚卸し

Issue #50 ISS-2 に対応。開発ルールが複数箇所に分散していたため、再設計前の状態と
本 feature での解消方針を記録する。canonical な正本は `AGENTS.md`（本リポジトリ）。

## ルールが書かれている場所（再設計前）

| 場所 | 内容 | 役割（是正後） |
|---|---|---|
| `AGENTS.md`（= `CLAUDE.md` symlink） | SDD phase・hard rules・テスト | **canonical 正本** |
| `.devcontainer/Agents.md` | devcontainer 仕様・ツール・マウント | devcontainer 実装の詳細（ルールの正本ではない） |
| `README.md` | 利用者向け概要・smoke gate 説明 | 概要 + AGENTS.md/docs へのリンク |
| `vendor/ai-sdd-guide/rules/*` | 汎用 SDD ルール（vendored） | 上流ルール。repo 固有は AGENTS.md が優先 |
| CI workflows (`.github/workflows/*`) | spec gate・bats・smoke の強制 | 自動強制（pre-merge gate） |
| issue 本文 | feature ごとの要件 | feature spec の入力 |

## 重複

- **smoke 対象 path list** が workflow `paths:`・README・テストの 3 箇所にハードコードされていた。
  → 解消: `scripts/devcontainer-paths.txt` を単一 source of truth とし、`pre-pr-check.sh`・
  workflow・README・テストはそこへ収束。drift は `tests/pre-pr-check.bats` が検出（AC14）。
- **テスト実行方法**が AGENTS.md と README に重複記載。
  → 解消: AGENTS.md を正本とし README は参照に限定。

## 矛盾

- `pre-pr-check.sh` の devcontainer 判定が `.devcontainer/*`（広い）で、workflow `paths:` は
  特定ファイル列挙（狭い）だった。同じ「devcontainer 関連変更」の定義が 2 つあった。
  → 解消: 単一 path list に統一。
- 「実装完了 = issue 完了」と誤読されうる DoD（旧 spec が schema 外 status を定義）。
  → 解消: canonical schema の `phase`+`status` で表現し、両者を明確に分離（AGENTS.md DoD）。

## 欠落

- host smoke 未成功時の PR/draft/merge policy が明文化されていなかった。
  → 解消: AGENTS.md「smoke / draft / merge policy」。
- smoke 証跡の中身（HEAD 一致・成功マーカー）を検証する仕組みがなく、存在確認のみだった。
  → 解消: `smoke-devcontainer.sh` が検証可能な証跡を生成、`pre-pr-check.sh` が内容検証。
- frozen scope 外 blocker の停止・issue 分離・resume 手順が未定義だった。
  → 解消: AGENTS.md「Blocker handling」+ `docs/development/blocker-handling.md`。
- Issue AC → spec AC → task → test のトレーサビリティがなく、要件が spec 化で脱落した
  （PR #54 で表面化）。
  → 解消: spec.md にトレース表を必須化。汎用の機械検査 CI は #55 が担う。

## 役割の優先順位

1. `AGENTS.md` — repo 固有ルールの正本。矛盾時はここが優先。
2. `docs/development/` — AGENTS.md の詳細解説。
3. `vendor/ai-sdd-guide/` — 汎用 SDD ルール。repo 固有規定が上書きする。
4. `README.md` / `.devcontainer/Agents.md` — 概要・実装詳細。ルールの正本ではない。
