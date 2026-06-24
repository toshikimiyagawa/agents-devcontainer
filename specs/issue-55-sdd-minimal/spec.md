# Spec: Issue #55 Minimal SDD Traceability

- Feature: `issue-55-sdd-minimal`
- Tier: 2
- Status: frozen
- Source issue: https://github.com/toshikimiyagawa/agents-devcontainer/issues/55
- Design: [2026-06-24-issue-55-sdd-minimal-design.md](../../docs/superpowers/specs/2026-06-24-issue-55-sdd-minimal-design.md)

## Intent

Issueからfrozen specへの要件脱落と、SDD状態が不整合なままのverify PASSを、
小さなrepo固有validator、既存CI gate、独立reviewの組み合わせで防ぐ。

客観的なrepository stateだけを機械検証し、Issueの意味、testの妥当性、
TDD実施事実は独立reviewerが判断する。

## Acceptance criteria

- [ ] AC-001: Tier 2 featureは固定形式の`traceability.json`を持ち、source
  Issue URLと、一意な`ISSUE-AC-NNN`、要件本文、dispositionを記録する。
- [ ] AC-002: 各Issue ACはちょうど1回現れ、`implemented`または`follow_up`
  のどちらかへ分類される。未追跡、重複、未知field/valueはvalidatorが拒否する。
- [ ] AC-003: `implemented` criterionは1件以上の`AC-NNN`、`TASK-NNN`、
  repository-relativeなBats file/nameを持つ。他のdisposition用fieldを持たない。
- [ ] AC-004: `follow_up` criterionは非空の理由とHTTPS GitHub Issue URLを
  持ち、spec/task/test mappingを持たない。
- [ ] AC-005: freeze validationはspec ACとtask IDの存在、参照完全性、重複、
  orphanを確認し、artifact/dependency/parse failureをexit 1にする。
- [ ] AC-006: verify validationはstate feature/tier/phaseが対象Tier 2 featureの
  `verify`を示すことを確認する。
- [ ] AC-007: verify validationはtasks.jsonのcanonical field/value、対象entry
  1件、phase `verify`、status `completed`、repository全体のblocked task 0件、
  frozen tasks.mdのTASK IDとtraceability参照の整合を確認する。checkboxは実行
  状態に使用しない。
- [ ] AC-008: verify validationは参照test fileがrepository内の通常fileとして
  存在し、exact Bats test declarationがちょうど1件あることを確認する。
- [ ] AC-009: PR validationはbase ref、changed spec feature、requested feature、
  state feature、PR Tier labelの不一致をfail closedで拒否する。
- [ ] AC-010: 既存SDD workflowのspec gate、blocked task gate、implement handoff
  gate、全Batsを保持し、Tier 2 validatorを追加で呼ぶ。Tier 0/1挙動を変更しない。
- [ ] AC-011: repository-local sdd-reviewerはGitHub Issueとtraceability、spec、
  testの意味を比較し、scope外理由、state/tasks、command、件数、reviewed SHAを
  確認する。validator greenだけでPASSしない。
- [ ] AC-012: AGENTS.mdとhuman-facing docsはfreeze/verify command、固定ID、
  fail-closed条件、独立reviewの責務、非目的を説明する。
- [ ] AC-013: validator Batsはvalid freeze/verify、malformed JSON、mapping不足、
  follow-up不足、参照欠落、state/tasks不整合、base/Tier/feature不一致、
  PR #54型fixtureを実behaviorで検証する。
- [ ] AC-014: 各実装behaviorはproduction変更前にfocused BatsをREDで確認し、
  変更後にGREENを確認する。実装reportへcommand/resultを記録し、独立reviewerが
  実施内容を確認する。
- [ ] AC-015: validatorは250行以内、validator Batsは400行以内で、汎用JSON
  Schema interpreter、process evidence、attestation、専用Bats wrapperを追加しない。
- [ ] AC-016: `vendor/ai-sdd-guide`とPR #54実装fileを変更せず、canonical改善は
  `toshikimiyagawa/ai-sdd-guide#43`で追跡する。

## Source Issue AC mapping

この表はspec review用であり、freeze時の機械可読な正本は
`traceability.json`とする。

| Source AC | 内容 | Spec AC |
|---|---|---|
| ISSUE-AC-001 | Issue AC → spec AC → task → test形式 | AC-001, AC-002, AC-003 |
| ISSUE-AC-002 | 未対応Issue ACをfreeze/verify PASSにしない | AC-002, AC-005 |
| ISSUE-AC-003 | scope外化に理由とfollow-up Issueを要求 | AC-004 |
| ISSUE-AC-004 | state/tasks/tasks.md整合性 | AC-006, AC-007 |
| ISSUE-AC-005 | tasks.json canonical schema | AC-007 |
| ISSUE-AC-006 | reviewerが元Issueとの差分を確認 | AC-011 |
| ISSUE-AC-007 | gateのnegative-test checklist | AC-012, AC-013 |
| ISSUE-AC-008 | PR #54型の回帰fixture | AC-013 |
| ISSUE-AC-009 | RED前・GREEN後の確認 | AC-014 |
| ISSUE-AC-010 | human docsとagent instructions | AC-012 |

## Required process checks

AC-011とAC-014は人間判断を含む。testはreviewer instructionとreporting contractが
存在することを固定し、実際の意味・実施事実は独立reviewerが確認する。ローカル
artifactでreviewer独立性や過去実行を認証したとは主張しない。

`tasks.md`はfreezeされた計画であり、実装進捗のmutable stateではない。TASK IDと
計画内容はtasks.md、phase/status/blocked_reasonは`.sdd/tasks.json`を正本とする。

## Constraints

- Bash 3.2、Git、jq、Batsだけを使用する。
- validatorとCIはnetwork accessを必要としない。
- traceability JSON Schemaを別途作成しない。
- 既存CI gateを置換・skip・warning化しない。
- implementation中に`specs/`を変更しない。
- 一つのbranch/PRで一つのfeatureだけを扱う。

## Out of scope

- reviewer identity、TDD履歴、host実行履歴の改ざん耐性。
- PR #54のsmoke evidence/Git fallback修正。
- `ai-sdd-guide`の変更。
- 既存featureの一括migration。
