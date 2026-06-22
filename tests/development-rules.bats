#!/usr/bin/env bats
# development-rules feature: rule/doc 内容を grep で検証する（ISS-15: doc AC も test 化）。

AGENTS="$BATS_TEST_DIRNAME/../AGENTS.md"
DOCS="$BATS_TEST_DIRNAME/../docs/development"

@test "AGENTS.md declares itself the canonical rule source (AC1)" {
  grep -qF 'canonical' "$AGENTS"
  grep -qF '正本' "$AGENTS"
}

@test "AGENTS.md DoD uses canonical phase+status, not new status enums (AC5/AC16)" {
  # 区別は記載される
  grep -qF '実装完了' "$AGENTS"
  grep -qF 'issue 完了' "$AGENTS"
  grep -qF 'phase' "$AGENTS"
  # schema 違反の status 値を導入していない
  ! grep -qF 'implementation_complete' "$AGENTS"
  ! grep -qF 'issue_complete' "$AGENTS"
}

@test "AGENTS.md states the smoke not-done / draft policy (AC6/ISS-7/ISS-8)" {
  grep -qF 'host full smoke' "$AGENTS"
  grep -qF '完了扱いにしない' "$AGENTS"
  grep -qF 'draft' "$AGENTS"
}

@test "AGENTS.md keeps phase gates and blocker handling (AC4/AC8)" {
  grep -qF 'Phase gates' "$AGENTS"
  grep -qF 'scripts/pre-pr-check.sh' "$AGENTS"
  grep -qF 'Blocker handling' "$AGENTS"
}

@test "rules-inventory.md lists duplication/contradiction/gaps (AC2)" {
  inv="$DOCS/rules-inventory.md"
  [ -f "$inv" ]
  grep -qF '重複' "$inv"
  grep -qF '矛盾' "$inv"
  grep -qF '欠落' "$inv"
}

@test "environment-matrix.md explains linked worktree smoke constraint (AC9)" {
  em="$DOCS/environment-matrix.md"
  [ -f "$em" ]
  grep -qF 'linked worktree' "$em"
  grep -qF '/Users' "$em"
}

@test "smoke-guide.md documents evidence saving (AC9)" {
  sg="$DOCS/smoke-guide.md"
  [ -f "$sg" ]
  grep -qF 'smoke-evidence.txt' "$sg"
}

@test "blocker-handling.md includes blocked_reason and follow-up issue template (AC9)" {
  bh="$DOCS/blocker-handling.md"
  [ -f "$bh" ]
  grep -qF 'blocked_reason' "$bh"
  grep -qF 'follow-up issue' "$bh"
}
