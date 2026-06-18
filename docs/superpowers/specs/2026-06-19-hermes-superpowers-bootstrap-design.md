# Hermes Superpowers Bootstrap Design

対応 issue: https://github.com/toshikimiyagawa/agents-devcontainer/issues/46

## 背景

Hermes Agent は devcontainer base image に per-user layout で install される。PR #45 で
`$HOME/.hermes` は `/workspace/dotfiles/.hermes` への symlink になり、container 専用の
Hermes runtime state が rebuild 後も残るようになった。

次の要望は、devcontainer 起動時点で Hermes Agent に `obra/superpowers` skill pack が入っている状態にすること。
参考記事では Hermes の導入コマンドとして以下が示されている。

```bash
hermes skills install --yes skills-sh/obra/superpowers
```

## 設計

`Dockerfile.base` ではなく `.devcontainer/scripts/agents-post-create` で bootstrap する。
理由は、Docker build 時点の `~/.hermes` は runtime で `dotfiles/.hermes` に置き換えられるため、
image に焼いた skill state が見えなくなる可能性があるから。

`agents-post-create` は `.hermes` symlink 作成後に Hermes superpowers install を試みる。
`hermes` command が存在しない環境では何もしない。install が成功したら
`$HOME/.hermes/.agents-superpowers-installed` を marker として作成し、再実行時は install を skip する。
install 失敗は network/registry 側の一時障害として扱い、warning を出して postCreate 全体は継続する。

この共通 script に入れることで、この repo の dogfood devcontainer だけでなく、
`scaffold.sh` で作られる consumer project の devcontainer も同じ挙動になる。

## 選択肢

### 採用: postCreate で idempotent install

- `.hermes` symlink 後に実行するので永続化先が正しい。
- `--yes` により non-interactive。
- marker で再実行を抑制できる。
- failure を warning にでき、devcontainer 起動失敗を避けられる。

### 不採用: Docker image に焼き込む

初回起動は速いが、runtime の `~/.hermes` が project dotfiles へ置き換わるため、skill state の保存先がずれる。
Hermes state 永続化設計と整合しない。

### 不採用: docs のみ

壊れにくいが、devcontainer 起動時に superpowers 入りにはならない。
今回の要望に対して不足。

## テスト方針

実ネットワークには依存しない。`tests/agents-post-create.bats` で fake `hermes` を PATH に置き、
以下を検証する。

- 初回実行で `hermes skills install --yes skills-sh/obra/superpowers` が呼ばれる。
- 成功時に marker が作成される。
- marker がある再実行では install が呼ばれない。
- fake `hermes` が失敗しても `agents-post-create` は exit 0 で warning を出す。
- `hermes` command が存在しない場合も exit 0 で skip する。

README と `.devcontainer/Agents.md` には、Hermes superpowers が container 専用の
`dotfiles/.hermes` に bootstrapped され、host `~/.hermes` とは共有されないことを追記する。

## スコープ外

- Host `~/.hermes` の bind mount。
- Host 側に入っている Hermes skills の import/copy。
- Hermes provider/model/API key の repository commit。
- `skills-sh/obra/superpowers` 以外の skill pack の自動導入。
- Docker build 時点での skill install。
