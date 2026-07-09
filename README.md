# AI Agent Dev Container

汎用的な AI Agent 開発のための Dev Container ベースイメージ。
Claude Code, Gemini CLI, Codex CLI, Hermes Agent などのエージェントツールがプリインストールされており、すぐに開発を開始できる。

## 特徴

- **マルチプラットフォーム対応**: macOS (Colima), Windows (WSL2), Linux で動作。
- **マルチアーキテクチャ対応**: Intel (x86_64) および Apple Silicon / ARM Windows (arm64) をサポート。
- **最新のエージェントツール**:
  - **Claude Code**: Anthropic によるターミナルベースの AI エージェント。
  - **Gemini CLI**: Google によるコードベース対応の AI エージェント。
  - **Codex CLI**: OpenAI によるターミナルベースの AI エージェント。
  - **Hermes Agent**: NousResearch による自己改善型の自律 AI エージェント（永続メモリ・スキル学習・ブラウザ自動化）。本体 `~/.hermes/hermes-agent` は container image 側に残し、設定や skills などの状態だけを container 専用の `dotfiles/.hermes/` に永続化する。`skills/` は Hermes の検証に通すため `~/.hermes/skills` を実体 directory とし、`dotfiles/.hermes/skills` から復元・同期する。`postCreate` で `skills-sh/obra/superpowers` を non-interactive に bootstrap する。初回利用時に `hermes setup` でプロバイダを設定する。
  - **ai-sdd-guide**: Spec-Driven Development (SDD) フレームワーク。プロジェクトに個別に導入する。
- **モダンな開発ツール**: uv (Python), Neovim, Tmux, Lazygit, Yazi 等を同梱。
- **ゼロフリクション認証**: `gh auth login` 一度でトークンが named volume に永続化。rebuild 後も再認証不要。

## GHCR package 管理（このリポジトリのメンテナ向け）

`main` に push すると GitHub Actions が `ghcr.io/toshikimiyagawa/agents-devcontainer` をビルドして publish します。
現在の package は public として利用可能です。

package を削除して作り直した場合、初回 push 後に以下を手動で行う必要があります：

1. **イメージを Public に変更**: [github.com → Packages → agents-devcontainer → Package settings](https://github.com/users/toshikimiyagawa/packages/container/agents-devcontainer/settings) で Visibility を **Public** に変更する（デフォルトは Private）。
2. **リポジトリとリンク**: 同ページで `agents-devcontainer` リポジトリにリンクする（以降の workflow push が `GITHUB_TOKEN` だけで動く）。

これが完了するまでは dogfood `Dockerfile` の `FROM ghcr.io/...` pull が失敗します。

## 導入方法の選び方

- 新規プロジェクト、または `.devcontainer` をこのリポジトリの方式で管理してよい場合は、
  下の scaffold を使う。
- 既存devcontainer を持つリポジトリを汚したくない場合は、
  [External injection for existing devcontainers](docs/external-injection.md) を使う。
  VS Code は `dev.containers.defaultFeatures`、CLI は `adc up` が入口。

## 新プロジェクトへの導入

### 方法 A: scaffold スクリプト（推奨）

```bash
# プロジェクトディレクトリで実行
curl -fsSL https://raw.githubusercontent.com/toshikimiyagawa/agents-devcontainer/main/scaffold.sh | bash

# 公開済み tag に固定する場合
AGENTS_DEVCONTAINER_TAG=<published-tag> bash scaffold.sh
```

スクリプトは以下を行います:
- `vendor/agents-devcontainer` を submodule として追加（git リポジトリの場合）
- `.devcontainer/` の生成（既に存在する場合はスキップ）
- `devcontainer.project.json` の生成（プロジェクト固有の設定用）
- `project-tools.yml` の生成（プロジェクト固有ツール追加用）
- `merge.sh` で `devcontainer.json` を生成

`.devcontainer` が既にあるリポジトリでも実行可能です。

### 方法 B: Dockerfile が必要な場合

apt / pip / npm / binary の追加だけなら、scaffold が生成する
`.devcontainer/project-tools.yml` を使う。`agents-post-create` が
`agents-tools-install` を呼び出し、container 作成時に自動で処理する。

base image 自体を拡張する必要がある場合だけ、`.devcontainer/devcontainer.json` で
`image` の代わりに `build` を使用する:

```dockerfile
# .devcontainer/Dockerfile
FROM ghcr.io/toshikimiyagawa/agents-devcontainer:latest
RUN sudo apt-get update && sudo apt-get install -y postgresql-client
```

## devcontainer 設定の更新

agents-devcontainer 本体が更新された際に、消費プロジェクトの設定を取り込む方法。

### devcontainer.json の更新

```bash
# agents-devcontainer の最新を取得
git submodule update --remote vendor/agents-devcontainer

# devcontainer.json を再生成
vendor/agents-devcontainer/scaffold/merge.sh

# 差分確認 → コミット
git diff .devcontainer/devcontainer.json
git add .devcontainer/devcontainer.json
git commit -m "chore(devcontainer): update to latest agents-devcontainer"
```

### プロジェクト固有の設定

`.devcontainer/devcontainer.project.json` にプロジェクトの差分のみを記述します。
このファイルは `merge.sh` によって `devcontainer.json` にマージされます。

```json
{
  "name": "my-project",
  "mounts": [
    "source=my-db,target=/var/lib/postgresql/data,type=volume"
  ],
  "remoteEnv": {
    "MY_API_KEY": "${localEnv:MY_API_KEY}"
  }
}
```

マージルール：
- `mounts`: base の配列 + project の配列（結合）
- `remoteEnv`: キー単位のマージ（project の値が優先）
- `image` / `build`: project が優先
- `postCreateCommand` / `postStartCommand`: project が優先（なければ base の `agents-post-create` / `agents-post-start`）

### プロジェクト固有ツールの追加

scaffold は `.devcontainer/project-tools.yml` も生成する。
`agents-post-create` は container 作成時に `agents-tools-install` を実行し、この YAML を読む。

対応している主な項目:

- `apt`
- `pip`（`uv tool install` 経由）
- `npm`
- `binary`
- `post_install`

より複雑な処理が必要な場合は `.devcontainer/post-install.sh` を executable にして配置する。

### SDD 統合ファイルの更新

SDD ファイルの更新は ai-sdd-guide submodule を直接更新して `integration/update.sh` を実行します:

```bash
git submodule update --remote vendor/ai-sdd-guide
vendor/ai-sdd-guide/integration/update.sh
```

`.claude/agents/` と `.github/workflows/sdd-check.yml` を上書き更新します。
`CLAUDE.md`, `AGENTS.md`, `.claude/settings.json` は保護対象で上書きしません（diff のみ表示）。

### 既存プロジェクトからの移行手順

agents-devcontainer を submodule として使っていない既存プロジェクトの移行手順：

1. submodule を追加: `git submodule add https://github.com/toshikimiyagawa/agents-devcontainer.git vendor/agents-devcontainer`
2. project.json を作成: `echo '{"name":"my-project"}' > .devcontainer/devcontainer.project.json`
3. 既存の `.devcontainer/devcontainer.json` と `vendor/agents-devcontainer/scaffold/devcontainer.base.json` を diff し、プロジェクト固有の設定を確認する
4. 確認した差分を `.devcontainer/devcontainer.project.json` に記述する
5. `vendor/agents-devcontainer/scaffold/merge.sh` を実行して `devcontainer.json` を再生成・確認
6. コミット

## このリポジトリ自体の起動（dogfood）

### 1. 依存ツールのインストール

#### macOS
```bash
brew install colima docker docker-buildx
colima start --cpu 4 --memory 8
```

#### Windows (WSL2)
Ubuntu 等の WSL2 ディストリビューション内で Docker Engine をインストールしてください。

### 2. コンテナの git identity を設定

dogfood 設定は、空値による Git config の上書きを避けるため、ホストの
`GIT_AUTHOR_NAME` / `GIT_AUTHOR_EMAIL` を自動転送しません。コンテナ内で
`gh auth login` を済ませると、次回起動時に GitHub アカウント情報から取得します。

GitHub の name / email を取得できない場合は起動時に警告します。必要な値を
コンテナ内で明示的に設定してください。

```bash
sudo git config --system user.name "Your Name"
sudo git config --system user.email "you@example.com"
```

### 3. コンテナの起動

VS Code の **Dev Containers: Reopen in Container** を実行するか、`devcontainer` CLI を使用します。

```bash
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . zsh
```

### PR 前の devcontainer smoke

devcontainer 関連の変更では、最終確認を devcontainer の外にある host 側から実行する。
実装や単体テストは devcontainer 内で進めてよいが、`bats tests/` だけでは完了ではない。

host に `bats`、利用可能な Docker daemon、`devcontainer` CLI、`git`、`jq` があり、
`~/.ssh` directory が存在することを確認してから実行する。

```bash
scripts/smoke-devcontainer.sh
```

この script は host Bats、現在 checkout の local base image build、dogfood
devcontainer の新規作成、lifecycle command、container 内 Bats、主要 tool、Hermes
永続化 layout を順に検証する。`--remove-existing-container` を使うため、現在の
dogfood container を置き換える可能性がある。

Hermes の command と永続化 layout は必須である。clean rebuild では host の provider/model
設定を import しないため、Hermes 未設定は明示的な warning として扱い、smoke 自体は失敗させない。

次の path を変更した場合は、この smoke を実行する。

- `.devcontainer/Dockerfile.base`
- `.devcontainer/Dockerfile`
- `.devcontainer/devcontainer.json`
- `.devcontainer/scripts/**`
- `dotfiles/**`
- `scaffold.sh`
- `scaffold/**`
- `scripts/smoke-devcontainer.sh`
- `tests/smoke-devcontainer.bats`
- `.github/workflows/smoke-devcontainer.yml`

外部注入経路だけの変更、つまり `features/agents/**`、`bin/adc`、
`docs/external-injection.md`、`tests/feature-agents.bats`、
`tests/adc-up.bats`、`tests/external-injection-docs.bats` の変更では、
上記の smoke 対象 path を同時に変更しない限り full devcontainer smoke は不要。
その場合は対象 Bats と通常 CI で、Feature metadata、`adc up --dry-run` の引数生成、
docs の制約記載、対象リポジトリを汚さないことを確認する。

host smoke を実行できなかった場合は、理由を PR description に記載する。その時点では未完了であり、
作成者による host smoke または GitHub Actions の full smoke が成功するまで merge しない。

### 4. GitHub 認証（初回のみ）

コンテナ内で以下を実行します。トークンは named volume に保存されるため、**rebuild 後も再認証は不要**です。

```bash
gh auth login -p https -h github.com -s repo,read:org -w
```

ログアウト・トークン削除:

```bash
docker volume rm devcontainer-gh-<devcontainerId>
```

## AI エージェントツールの有効化（opt-in）

`devcontainer up` の自動化には含めていない（プロジェクトに副作用を持つため）。使うプロジェクトでだけ手動で有効化する。

### Spec-Driven Development (SDD)

ai-sdd-guide による SDD フレームワーク。agents-devcontainer とは独立して導入する。

```bash
git submodule add https://github.com/toshikimiyagawa/ai-sdd-guide.git vendor/ai-sdd-guide
vendor/ai-sdd-guide/integration/update.sh
```

> **Note:** `git submodule update --init` で `vendor/agents-devcontainer` を取得する際、`--recursive` は不要です。
> `vendor/agents-devcontainer` 内部に ai-sdd-guide が含まれていますが、消費プロジェクトには影響しません。

- ルール: `vendor/ai-sdd-guide/rules/`
- ドキュメント（日本語）: `vendor/ai-sdd-guide/docs/`
- テンプレート: `vendor/ai-sdd-guide/templates/`

### Superpowers (Claude Code plugin)

Claude Code を起動してから、プロンプトで以下のスラッシュコマンドを実行する：

```
/plugin install superpowers@claude-plugins-official
```

別マーケットプレース版を使う場合：

```
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

プラグイン状態は `~/.claude/`（= `dotfiles/.claude/` への symlink、gitignore 済み）に保存されるため、rebuild 後も保持される。

## dotfiles のライフサイクル

### source of truth

ベース dotfiles の正本は `vendor/agents-devcontainer/dotfiles/*`（submodule）。
`scaffold.sh` がプロジェクト直下の `dotfiles/` へ**初回コピー**し force-commit する。
コンテナ内では `agents-post-create` が `~/<name>` → `/workspace/dotfiles/<name>` を symlink する。

追従対象（ファイル単位）:

| ファイル | 説明 |
|---|---|
| `.zshrc` | シェル設定 |
| `.tmux.conf` | tmux 設定 |
| `.config/*` | starship / nvim / lazygit / yazi / git などのツール設定 |

`.claude/` `.gemini/` `.codex/` `.hermes/` `.ssh/` `.zsh_history` はランタイム/個人用のため追従対象外（gitignore 済み）。

Hermes Agent の container 内 state は `~/.hermes` 全体ではなく、`config.yaml`, `.env`, `skills/`, `memories/` を `dotfiles/.hermes/` に保存する。Hermes 本体の `~/.hermes/hermes-agent` は container image 側に残す。host `~/.hermes` とは共有しない。`config.yaml`, `.env`, `memories/` は `dotfiles/.hermes/` への symlink、`skills/` は Hermes の realpath 検証に通すため `~/.hermes/skills` を実体 directory として `dotfiles/.hermes/skills` から復元・install 成功後に同期する。provider/model は container 内で `hermes setup` を実行するか、`dotfiles/.hermes/config.yaml` に設定する。`agents-post-create` は `hermes skills install --yes skills-sh/obra/superpowers` を一度だけ実行し、成功後は `dotfiles/.hermes/.agents-superpowers-installed` marker で再実行を抑制する。install 失敗は warning として扱い、devcontainer setup は継続する。

### upstream 更新の取り込み

`vendor/agents-devcontainer` を bump した後、次回 rebuild 時に `agents-dotfiles-sync` が自動実行され、
**自分で編集していない**ベースファイルだけを upstream の最新版へ更新する（`dotfiles/` の `git diff` として現れるので確認のうえ commit する）。

```bash
git submodule update --remote vendor/agents-devcontainer   # --recursive は使わない
# 次回 rebuild 時に未編集ファイルが自動追従される
```

判定は `dotfiles/.agents-dotfiles.lock`（最後に同期した upstream 版の sha256）を基準に行う。

### 上書き（override）

`dotfiles/` 内のファイルを編集すると baseline から乖離し、以降そのファイルは自動更新の対象外になる（あなたの版が保護される）。

### コンフリクト

あなたが編集したファイルが upstream でも変更された場合、sync はそのファイルを**変更せず**警告し、
`dotfiles/<file>.agents-upstream`（gitignore 済み）に upstream 版を出力する。差分確認:

```bash
diff dotfiles/.zshrc dotfiles/.zshrc.agents-upstream
```

upstream の変更を確認したうえで自分の版を維持したい場合（警告を止める。ファイルは変更しない）:

```bash
agents-dotfiles-sync --accept .zshrc
```

詳細な仕様については [.devcontainer/Agents.md](.devcontainer/Agents.md) を参照してください。
