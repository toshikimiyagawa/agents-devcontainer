# Spec: development-rules

- Tier: 2
- Status: frozen
- Feature slug: development-rules

## 背景 / 意図

このリポジトリの開発ルールが AGENTS.md・`.devcontainer/Agents.md`・vendored SDD guide・CI に分散しており、
「いつ、どの環境で、何を通せば PR を作成してよいか」が一つの実行可能な契約になっていない。
issue #49 の作業中に判明した問題を一般化し、agent・人間問わず同じ phase・コマンド・証跡で
作業できるようにする。issue #50 に対応する。

## 受入条件

- [ ] AC1: AGENTS.md に environment matrix セクションがあり、host/worktree/devcontainer/CI の
  可否表と、smoke は /Users 配下の通常 clone から実行する旨が記載されている。
- [ ] AC2: AGENTS.md に phase gates セクションがあり、design preflight / implementation gate /
  verify gate / pre-PR gate / pre-merge gate の checkable command が記載されている。
- [ ] AC3: AGENTS.md に Definition of Done セクションがあり、`implementation_complete` と
  `issue_complete` の定義が明記されている。
- [ ] AC4: AGENTS.md に reporting template セクションがあり、各 phase 完了時に agent が
  埋める項目一覧が定義されている。
- [ ] AC5: AGENTS.md に blocker handling セクションがあり、停止手順・follow-up issue 作成・
  resume 条件が定義されている。
- [ ] AC6: `docs/development/environment-matrix.md` が存在し、linked worktree で smoke が
  動かない理由と正しい実行環境を説明している。
- [ ] AC7: `docs/development/smoke-guide.md` が存在し、OS 別 smoke 実行手順と証跡保存手順を
  説明している。
- [ ] AC8: `docs/development/blocker-handling.md` が存在し、blocked_reason テンプレートと
  follow-up issue テンプレートを含む。
- [ ] AC9: `scripts/pre-pr-check.sh` が存在し、branch / bats / bash-n / smoke 証跡 / tasks.json
  を確認し、問題があれば exit 1 する。
- [ ] AC10: devcontainer 関連パスの変更が検出され、`.sdd/smoke-evidence.txt` が存在しない場合、
  `scripts/pre-pr-check.sh` が exit 1 し、smoke-devcontainer.sh の実行を促すメッセージを出す。
- [ ] AC11: `.github/pull_request_template.md` が存在し、smoke 証跡・SDD tier・CI 結果の
  記入欄を含む。
- [ ] AC12: `.sdd/smoke-evidence.txt` が `.gitignore` に追加されている。
- [ ] AC13: `tests/pre-pr-check.bats` が存在し、AC9-10 の動作を検証する。
- [ ] AC14: `bats tests/` が全通過する。
- [ ] AC15: `bash -n scripts/pre-pr-check.sh` が通過する。

## スコープ外

- vendored SDD guide の一般論を書き換えること
- downstream repository を同時に統一すること
- linked worktree での smoke 対応
- CI や SDD hook を無効化すること
