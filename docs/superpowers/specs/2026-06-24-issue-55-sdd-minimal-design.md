# Issue #55: 最小SDDトレーサビリティ設計

## Status

- Feature: `issue-55-sdd-minimal`
- Tier: 2
- Design status: human-approved
- Source issue: https://github.com/toshikimiyagawa/agents-devcontainer/issues/55
- Canonical guide follow-up: https://github.com/toshikimiyagawa/ai-sdd-guide/issues/43

## 背景

Issue #50 / PR #54では、元Issueの重要要件がfrozen specへの変換時に
脱落・弱体化し、不完全なspecへの適合だけを根拠にreviewerとCIがPASSした。

最初の#55実装では、この問題を解決するためにJSON Schema interpreter、
process evidence、reviewer attestationまで機械検証しようとした。その結果、
27ファイル・3,443行、validator 755行、test 1,200行超まで拡大し、schema自体の
真正性やreviewer独立性を証明する再帰的な問題に陥った。

この設計は保証範囲を実用レベルへ戻し、客観的なrepository stateだけを機械で
検証する。意味・判断・過去の実行事実は独立reviewへ明示的に委ねる。

## 目的

1. Issue ACがspec/tasks/testsへ追跡されないままfreezeされることを防ぐ。
2. state、tasks、TASK IDが不整合なままverify PASSになることを防ぐ。
3. 既存のTier gate、orchestration gate、Batsを維持する。
4. localとCIが同じ小さなvalidatorを使用する。
5. 自動化できない判断を、自動化できるように装わない。

## 非目的

- reviewerの独立性をローカルファイルで認証すること。
- TDDのRED → GREEN実行履歴を暗号学的に証明すること。
- 任意JSON Schemaを解釈する汎用validatorを作ること。
- schema、validator、attestationを相互に証明すること。
- `ai-sdd-guide` submoduleを変更すること。
- PR #54のsmoke evidence実装を修正すること。

非目的への改善提案はblocking findingにせずfollow-up Issueへ分離する。

## 信頼境界

### 機械で保証する

- `.sdd/state.json`のfeature、tier、phase。
- `.sdd/tasks.json`の対象entry、canonical status、重複、blocked。
- frozen `tasks.md`内のTASK IDとtraceability参照の整合性。
- Issue AC → spec AC → task → testの参照完全性。
- 参照されたspec AC、task、test file、Bats test名の存在。
- PR Tier label、state、変更対象featureの一致。
- base ref取得失敗、JSON parse失敗、必須ファイル欠落時のfail-closed。
- 既存spec gate、orchestration gate、Batsが残っていること。

### 独立reviewerが判断する

- traceabilityへ転記したIssue ACが元GitHub Issueと一致すること。
- specがIssueの意味を弱めていないこと。
- testがACを意味的に証明していること。
- scope外化の理由とfollow-up Issueが妥当であること。
- TDD、host smoke、review報告が実際の作業と整合すること。

CI greenやtraceability fileの存在だけで、これらの判断を代替しない。

## データモデル

Tier 2 featureは、通常の`spec.md`、`plan.md`、`tasks.md`に加えて次を持つ。

```text
specs/<feature>/traceability.json
```

固定形式:

```json
{
  "source": {
    "url": "https://github.com/owner/repository/issues/55"
  },
  "criteria": [
    {
      "issue_ac": "ISSUE-AC-001",
      "text": "元Issueの受入条件",
      "disposition": "implemented",
      "spec_acs": ["AC-001"],
      "tasks": ["TASK-001"],
      "tests": [
        {
          "file": "tests/check-sdd-contract.bats",
          "name": "rejects an untracked issue criterion"
        }
      ]
    }
  ]
}
```

`disposition`は次の2値だけを許可する。

- `implemented`: `spec_acs`、`tasks`、`tests`がすべて1件以上必要。
- `follow_up`: `reason`とGitHub Issue URL形式の`follow_up`が必要で、
  implementation mappingは空にする。

このJSON形式の検証ロジックはvalidator内の固定`jq` expressionを唯一の
実行可能な正本とする。別のJSON Schemaやschema interpreterは作らない。

## Validator

単一entrypoint:

```text
scripts/check-sdd-contract.sh
```

インターフェース:

```bash
scripts/check-sdd-contract.sh --feature <slug> --mode freeze
scripts/check-sdd-contract.sh --feature <slug> --mode verify --base <commit> --expected-tier 2
```

### freeze mode

- `spec.md`、`plan.md`、`tasks.md`、`traceability.json`の存在。
- JSON root、source、criterion、test referenceの固定field/type。
- Issue AC、spec AC、task IDの形式と重複。
- traceability内のIssue ACが一意で、空のcriterionがないこと。
- implemented/follow_up条件。
- spec AC、taskの参照先存在とorphan検出。

### verify mode

freeze条件に加えて次を確認する。

- state feature/tier/phaseが対象Tier 2 featureの`verify`を示す。
- tasks.jsonに対象featureがちょうど1件ある。
- 対象entryがcanonical field/valueを使い、phase `verify`、status
  `completed`である。
- repository全体にblocked taskがない。
- frozen `tasks.md`のTASK IDがtraceabilityと一致する。checkboxは計画手順で
  あり、実行状態として解釈しない。
- test fileがrepository内の通常fileとして存在する。
- Bats test名がexact declarationとしてちょうど1件存在する。
- base ref、変更spec feature、requested feature、state featureが一致する。
- expected Tierとstate Tierが一致する。

dependency、artifact、Git、parse failureはwarningへ落とさずexit 1にする。
CLI usage errorはexit 2にする。

## CI統合

既存`.github/workflows/sdd-check.yml`を置換しない。

- 既存spec gateを残す。
- 既存blocked task gateを残す。
- 既存implement handoff gateを残す。
- 既存Bats実行を残す。
- Tier 2の場合だけvalidator呼び出しを追加する。

Tier 0/1の既存挙動は変更しない。新しいtraceability contractは新規または
更新されるTier 2 featureへ適用する。legacy migrationを理由に既存gateを
skip、warning化、削除しない。

## Reviewer contract

repository-local `sdd-reviewer`は次を実施する。

1. GitHub Issueとtraceability criteriaを意味的に比較する。
2. traceability criteriaとspec ACを比較する。
3. 各testが対応ACを実際に証明するか読む。
4. state、tasks、TASK ID、reviewed HEADを確認する。
5. scope外項目の理由とfollow-up Issueを確認する。
6. command、test件数、commit SHAを報告する。

validatorがgreenでも1〜3を省略しない。reviewerはこの設計の信頼境界内で
PASS/FAILを返す。追加の保証モデルは別Issueとして提案する。

## Test strategy

`tests/check-sdd-contract.bats`で次だけを固定する。

- valid freeze / verify contract。
- malformedまたはmulti-value JSON。
- Issue AC欠落・重複。
- implemented mapping不足。
- follow-up理由・URL不足。
- 存在しないspec AC、task、test。
- state feature/tier/phase不一致。
- tasks entry欠落・重複・blocked・非canonical value。
- traceabilityが存在しないTASK IDを参照する状態。
- base ref取得失敗。
- changed feature、requested feature、state feature不一致。
- expected Tier不一致。
- 既存workflow gateが残っていること。

testは実behaviorを呼び出す。文書全体の単語grepや任意schema mutation testは
作らない。

## Size budget

- validator: 250行以内。
- validator Bats: 400行以内。
- production scriptはvalidator 1ファイルだけ。
- traceability用JSON Schema、process evidence、attestation、Bats wrapperは作らない。
- validatorが250行を超える設計変更は実装せずhumanへ戻す。

## Phase flow

1. DesignでGitHub Issue ACをtraceabilityへ転記する。
2. Humanが元Issueとの一致を確認する。
3. plan/tasks/test名を確定してtraceabilityを完成する。
4. Human approval後にfreezeする。
5. Implementationでは`specs/`を変更しない。
6. Verifyでvalidator、全Bats、独立reviewerを実行する。
7. CI greenとmergeableを確認する。

### Human-approved state ownership correction

`tasks.md`はfreeze後に変更できないため、そのcheckboxをmutableな実行状態として
検証しない。計画内容とTASK IDの正本はfrozen `tasks.md`、進捗と完了状態の正本は
`.sdd/tasks.json`とする。implementation agentはspec fileのcheckboxを更新しない。

## Migration and branch policy

- 過剰実装branch `feat/issue-55-sdd-traceability`は変更せず参考用に残す。
- この設計は`origin/main`から作成した`feat/issue-55-sdd-minimal`で実装する。
- 過剰実装branchからcodeをcopyしない。必要なbehaviorだけをtest-firstで書く。
- 既存featureを一括migrationしない。
- `ai-sdd-guide`側の一般化はIssue #43で扱う。

## Completion criteria

- Issue #55の各ACがtraceabilityに存在する。
- 全traceability mappingがvalidatorを通る。
- validator focused testsと既存全Batsがgreen。
- shell syntax checkがgreen。
- 既存CI gateが保持される。
- 独立reviewerが、この文書で定義した保証範囲内でPASSする。
- validatorとtestsがsize budget内に収まる。
