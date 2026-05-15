# AI Agent Dev Container

汎用的な AI Agent 開発のための Dev Container 環境。
Claude Code や Gemini CLI などのエージェントツールがプリインストールされており、すぐに開発を開始できる。

## 特徴

- **マルチプラットフォーム対応**: macOS (Colima), Windows (WSL2), Linux で動作。
- **マルチアーキテクチャ対応**: Intel (x86_64) および Apple Silicon / ARM Windows (arm64) をサポート。
- **最新のエージェントツール**:
  - **Claude Code**: Anthropic によるターミナルベースの AI エージェント。
  - **Gemini CLI**: Google によるコードベース対応の AI エージェント。
  - **OpenSpec**: AI コーディングアシスタント向けの Spec-Driven Development フレームワーク。
- **モダンな開発ツール**: uv (Python), mise (Runtime manager), Neovim, Tmux, Lazygit, Yazi 等を同梱。

## セットアップ手順

### 1. 依存ツールのインストール

#### macOS
```bash
brew install colima docker docker-buildx
colima start --cpu 4 --memory 8
```

#### Windows (WSL2)
Ubuntu 等の WSL2 ディストリビューション内で Docker Engine をインストールしてください。

### 2. ホストの git identity を環境変数にセット（推奨）

コミットに正しい名前・メールが付くよう、ホスト側の `~/.zshrc` または `~/.bashrc` に追加してください。

```bash
export GIT_AUTHOR_NAME="Your Name"
export GIT_AUTHOR_EMAIL="you@example.com"
```

未設定でも、コンテナ初回起動後に `gh auth login` を済ませれば GitHub アカウント情報から自動取得します。

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

ログアウトしたい場合（volume を削除）:

```bash
docker volume rm devcontainer-gh-<devcontainerId>
```

## ツールセット

### AI エージェント
- `claude` (Claude Code)
- `gemini` (Gemini CLI)
- `openspec` (OpenSpec — Spec-Driven Development)

### 開発ユーティリティ
- `uv`: Python の高速なパッケージ管理・ランタイム管理。
- `mise`: Node.js, Go, Rust 等の複数言語ランタイム管理。
- `neovim`, `tmux`, `lazygit`, `yazi`: 快適なターミナル開発環境。

## カスタマイズ

`.devcontainer/dotfiles` 内の設定ファイルを編集することで、シェルやエディタの好みを反映できます。
詳細な仕様については [Agents.md](./Agents.md) を参照してください。
