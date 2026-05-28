# AI Agent Dev Container

汎用的な AI Agent 開発のための Dev Container ベースイメージ。
Claude Code, Gemini CLI, Codex CLI などのエージェントツールがプリインストールされており、すぐに開発を開始できる。

## 特徴

- **マルチプラットフォーム対応**: macOS (Colima), Windows (WSL2), Linux で動作。
- **マルチアーキテクチャ対応**: Intel (x86_64) および Apple Silicon / ARM Windows (arm64) をサポート。
- **最新のエージェントツール**:
  - **Claude Code**: Anthropic によるターミナルベースの AI エージェント。
  - **Gemini CLI**: Google によるコードベース対応の AI エージェント。
  - **Codex CLI**: OpenAI によるターミナルベースの AI エージェント。
  - **OpenSpec**: AI コーディングアシスタント向けの Spec-Driven Development フレームワーク。
- **モダンな開発ツール**: uv (Python), Neovim, Tmux, Lazygit, Yazi 等を同梱。
- **ゼロフリクション認証**: `gh auth login` 一度でトークンが named volume に永続化。rebuild 後も再認証不要。

## 初回セットアップ（このリポジトリのメンテナ向け）

`main` に push すると GitHub Actions が `ghcr.io/toshikimiyagawa/agents-devcontainer` をビルドして publish します。
**ただし初回 push 後に以下を手動で行う必要があります：**

1. **イメージを Public に変更**: [github.com → Packages → agents-devcontainer → Package settings](https://github.com/users/toshikimiyagawa/packages/container/agents-devcontainer/settings) で Visibility を **Public** に変更する（デフォルトは Private）。
2. **リポジトリとリンク**: 同ページで `agents-devcontainer` リポジトリにリンクする（以降の workflow push が `GITHUB_TOKEN` だけで動く）。

これが完了するまでは dogfood `Dockerfile` の `FROM ghcr.io/...` pull が失敗します。

## 新プロジェクトへの導入

### 方法 A: scaffold スクリプト（推奨）

```bash
# プロジェクトディレクトリで実行
curl -fsSL https://raw.githubusercontent.com/toshikimiyagawa/agents-devcontainer/main/scaffold.sh | bash

# バージョンを固定する場合
AGENTS_DEVCONTAINER_TAG=v0.1.0 bash scaffold.sh
```

生成される `.devcontainer/devcontainer.json` はそのまま VS Code / devcontainer CLI で使用可能。

### 方法 B: 手動（ツールを追加したい場合）

`.devcontainer/devcontainer.json` を作成し、`image` の代わりに `build` を使用:

```dockerfile
# .devcontainer/Dockerfile
FROM ghcr.io/toshikimiyagawa/agents-devcontainer:latest
RUN sudo apt-get update && sudo apt-get install -y postgresql-client
```

## このリポジトリ自体の起動（dogfood）

### 1. 依存ツールのインストール

#### macOS
```bash
brew install colima docker docker-buildx
colima start --cpu 4 --memory 8
```

#### Windows (WSL2)
Ubuntu 等の WSL2 ディストリビューション内で Docker Engine をインストールしてください。

### 2. ホストの git identity を環境変数にセット（推奨）

```bash
# ~/.zshrc または ~/.bashrc に追加
export GIT_AUTHOR_NAME="Your Name"
export GIT_AUTHOR_EMAIL="you@example.com"
```

未設定でも、コンテナ内で `gh auth login` を済ませれば GitHub アカウント情報から自動取得します。

### 3. コンテナの起動

VS Code の **Dev Containers: Reopen in Container** を実行するか、`devcontainer` CLI を使用します。

```bash
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . zsh
```

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

### OpenSpec

Spec-Driven Development フレームワーク。コンテナ内で1回実行すれば `.openspec/` と Claude Code 用スラッシュコマンドが入る。

```bash
setup-openspec   # = openspec init --tools claude
```

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

プラグイン状態は `~/.claude/`（= `.devcontainer/dotfiles/.claude/` への symlink、gitignore 済み）に保存されるため、rebuild 後も保持される。

## dotfiles のカスタマイズ

`.devcontainer/dotfiles/` 内にファイルを置くと、イメージに焼き込まれたデフォルトを上書きできます。

| ファイル | 説明 |
|---|---|
| `.zshrc` | シェル設定 |
| `.tmux.conf` | tmux 設定 |
| `.config/` | starship 等のツール設定（ディレクトリ単位で上書き） |

`.zshrc` を全置換せずに拡張する場合:

```zsh
source /opt/agents/dotfiles/.zshrc
# プロジェクト固有の設定
export MY_VAR=...
```

詳細な仕様については [.devcontainer/Agents.md](.devcontainer/Agents.md) を参照してください。
