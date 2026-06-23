---
id: RUL-001
title: 最小SDDトレーサビリティゲート
status: planned
feature: issue-55-sdd-minimal
updated: 2026-06-24
---

# RUL-001: 最小SDDトレーサビリティゲート

## 概要

元Issueからfrozen specへの要件脱落と、state/tasks不整合のままのverify PASSを
防ぐrepo固有ルール。

## 仕様

- Tier 2 featureはIssue AC、spec AC、task、testを固定JSONで追跡する。
- freeze/verifyで小さなrepo固有validatorを実行する。
- 既存spec/orchestration/test gateへ追加し、置換しない。
- Issueの意味とtestの妥当性は独立reviewerが確認する。
- reviewer/TDD履歴の認証や汎用schema interpreterは対象外とする。
