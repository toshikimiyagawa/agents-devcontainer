## 変更内容

<!-- 変更の概要を記述 -->

## SDD

- Tier: <!-- sdd:tier-0 / sdd:tier-1 / sdd:tier-2 -->
- spec: <!-- specs/<feature>/spec.md または N/A -->
- sdd-reviewer: <!-- PASS / FAIL / N/A -->

## テスト結果

- [ ] `bats tests/` 全通過
- [ ] `bash -n` 全スクリプト

## Devcontainer 関連変更

*`scripts/devcontainer-paths.txt` のパターンに一致する変更がある場合のみ記入。該当なしは「N/A」。*
*host smoke が green になるまで完了扱いにしない。検証済み証跡がない場合は draft に留めること。*

- host smoke: <!-- PASS / NOT_RUN（理由） -->

<details>
<summary>smoke 証跡（.sdd/smoke-evidence.txt の内容。SMOKE_RESULT=pass と COMMIT==HEAD が必須）</summary>

```
<!-- .sdd/smoke-evidence.txt の内容を貼り付け。devcontainer 関連変更がない場合は N/A -->
```

</details>

## CI

- [ ] required CI checks が green（または path-based skip）
