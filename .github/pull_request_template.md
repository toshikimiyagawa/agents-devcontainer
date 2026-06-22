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

*`.devcontainer/`・`dotfiles/`・`scaffold*`・`scripts/smoke-devcontainer.sh` 等を変更した場合のみ記入。該当なしの場合は「N/A」と記入。*

- host smoke: <!-- PASS / NOT_RUN（理由） -->

<details>
<summary>smoke 証跡（scripts/smoke-devcontainer.sh の出力末尾）</summary>

```
<!-- .sdd/smoke-evidence.txt の内容を貼り付け。devcontainer 関連変更がない場合は N/A -->
```

</details>

## CI

- [ ] required CI checks が green（または path-based skip）
