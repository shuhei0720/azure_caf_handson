# 第 2 章：前提条件と環境準備

## 本章の目的

本章では、ハンズオンを進めるために必要な環境を準備します。Azure アカウントの作成から、GitHub Codespaces のセットアップ、必要なツールのインストールまでを行います。

**所要時間**: 約 1-2 時間  
**難易度**: ⭐

---

## 2.1 必要なアカウント

### 2.1.1 Azure アカウントの作成

#### 新規アカウントの作成

本ハンズオンでは、**新規の Azure アカウント（テナント）** を作成することを強く推奨します。理由は以下の通りです：

- クリーンな環境で学習できる
- 既存の環境に影響を与えない
- Management Groups の階層を最初から作れる
- 削除も容易

#### アカウント作成手順

1. [Azure 無料アカウントページ](https://azure.microsoft.com/free/)にアクセス

2. 「無料で始める」をクリック

3. Microsoft アカウントでサインイン

   - 既存の Microsoft アカウントを使用
   - または新規作成

4. 電話番号による本人確認

5. クレジットカード情報の入力

   - 本人確認のため必要
   - 無料枠を超えない限り課金されない

6. 契約に同意してサインアップ

#### 無料枠について

新規アカウントには以下の特典があります：

- **$200 分のクレジット**（最初の 30 日間）
- **12 ヶ月間無料のサービス**
  - 一部のサービスが無料枠内で利用可能
- **常に無料のサービス**
  - 一部のサービスは永続的に無料

詳細: [Azure 無料アカウントの FAQ](https://azure.microsoft.com/free/free-account-faq/)

#### 重要な注意事項

本ハンズオンで構築するリソースは、無料枠を超える可能性が高いです：

- Azure Firewall: 約$1.25/時間 = 約$900/月
- Azure Bastion: 約$0.19/時間 = 約$140/月
- VPN Gateway: 約$0.04-0.35/時間 = 約$30-260/月

**対策**：

- 使わない時はリソースを削除する
- Azure Firewall、Bastion は後の章で作成するので、それまでコストは抑えられる
- 各章の最後に「リソース削除手順」を記載

### 2.1.2 GitHub アカウント

#### アカウント作成

既に GitHub アカウントをお持ちの場合はスキップしてください。

1. [GitHub](https://github.com/)にアクセス
2. 「Sign up」をクリック
3. ユーザー名、メールアドレス、パスワードを入力
4. 認証を完了

#### リポジトリのフォーク

本ハンズオンのリポジトリを自分のアカウントにフォークします。

1. [https://github.com/shuhei0720/azure_caf_handson](https://github.com/shuhei0720/azure_caf_handson)にアクセス

2. 画面右上の「Fork」ボタンをクリック

3. 自分のアカウントにフォークされたことを確認

または、新規リポジトリを作成してこのリポジトリの内容をコピーすることもできます。

---

## 2.2 GitHub Codespaces のセットアップ

### 2.2.1 Codespaces とは

GitHub Codespaces は、ブラウザ上で動作する完全な VS Code 開発環境です。

利点：

- ローカル PC に何もインストール不要
- どこからでもアクセス可能
- 環境が統一される
- 強力なマシンスペックを利用できる

料金：

- 個人アカウント: 月 60 時間無料
- それ以降: $0.18/時間程度

### 2.2.2 Codespaces の起動

1. フォークしたリポジトリのページで、「Code」ボタンをクリック

2. 「Codespaces」タブを選択

3. 「Create codespace on main」をクリック

4. 数分待つと、ブラウザ上で VS Code が起動します

### 2.2.3 devcontainer 設定

Codespaces の環境は、リポジトリに含まれる`.devcontainer/devcontainer.json`で定義済みです。

このファイルにより、Codespaces 起動時に以下が自動的に設定されます：

- Azure CLI
- Bicep CLI
- Node.js (LTS 版)
- Git
- VS Code 拡張機能（Bicep、Azure CLI、ESLint など）

このファイルを作成したら、Codespaces を再起動するか、新しい Codespace を作成します。

---

## 2.3 必要なツールのインストール確認

Codespaces 環境では、以下のツールが自動的にインストールされます。確認しましょう。

### 2.3.1 Azure CLI

Azure CLI は、コマンドラインから Azure リソースを管理するツールです。

#### バージョン確認

ターミナルを開いて以下を実行：

```bash
az --version
```

出力例：

```
azure-cli                         2.56.0

core                              2.56.0
telemetry                         1.1.0
...
```

#### ログイン

```bash
az login --use-device-code
```

表示された URL にアクセスし、コードを入力してログインします。

ログイン成功後、サブスクリプション一覧が表示されます。

#### デフォルトサブスクリプションの設定

後で作成するサブスクリプションをデフォルトに設定します（今はスキップして、サブスクリプション作成後に実施）。

```bash
az account set --subscription "サブスクリプション名またはID"
```

### 2.3.2 Bicep CLI

Bicep は Azure Resource Manager (ARM) テンプレートを簡潔に書くための DSL です。

#### バージョン確認

```bash
az bicep version
```

出力例：

```
Bicep CLI version 0.24.24
```

#### Bicep のアップグレード（必要に応じて）

```bash
az bicep upgrade
```

### 2.3.3 PowerShell（オプション）

Linux ベースの codespaces では、bash をデフォルトで使用しますが、PowerShell も利用可能です。

```bash
pwsh --version
```

PowerShell を使用する場合は、Az PowerShell モジュールをインストール：

```powershell
pwsh
Install-Module -Name Az -Repository PSGallery -Force -AllowClobber
```

本ハンズオンでは、主に bash と Azure CLI を使用します。

### 2.3.4 Git

Git は既にインストールされています。

```bash
git --version
```

#### Git 設定

```bash
git config --global user.name "あなたの名前"
git config --global user.email "あなたのメールアドレス"
```

#### GitHub との連携確認

Codespaces では、GitHub との認証が自動的に設定されています。

```bash
git remote -v
```

リポジトリの URL が表示されることを確認します。

### 2.3.5 Node.js と npm

アプリケーション開発に必要です。

```bash
node --version
npm --version
```

---

## 2.4 VS Code 拡張機能

Codespaces には、以下の拡張機能がインストールされます（`.devcontainer/devcontainer.json`で指定）：

### インストールされる拡張機能

1. **Azure Bicep**

   - Bicep 言語のサポート
   - シンタックスハイライト、補完

2. **Azure CLI Tools**

   - Azure CLI コマンドの補完

3. **Azure Resources**

   - Azure リソースをサイドバーで表示

4. **Azure Account**

   - Azure アカウント管理

5. **ESLint**

   - JavaScript の静的解析

6. **Prettier**

   - コードフォーマッター

7. **GitHub Copilot** (オプション)
   - AI コード補完

拡張機能は自動的にインストールされますが、手動で確認する場合は：

1. 左サイドバーの拡張機能アイコンをクリック
2. インストール済みの拡張機能を確認

---

## 2.5 プロジェクト構造の理解

### 2.5.1 ディレクトリ構成

本ハンズオンのプロジェクト構造は以下の通りです：

```
azure_caf_handson/
├── .devcontainer/              # Codespaces設定
│   └── devcontainer.json
├── .github/                    # GitHub設定
│   └── workflows/              # GitHub Actions ワークフロー
│       ├── deploy-infra.yml    # インフラデプロイ
│       ├── deploy-policies.yml # ポリシーデプロイ
│       └── deploy-app.yml      # アプリデプロイ
├── docs/                       # ドキュメント
│   ├── handson-main.md         # メインドキュメント
│   ├── chapters/               # 各章の詳細
│   │   ├── chapter01-introduction.md
│   │   ├── chapter02-prerequisites.md
│   │   └── ...
│   └── diagrams/               # 図表（Mermaid等）
├── infrastructure/             # Infrastructure as Code
│   ├── bicep/                  # Bicepテンプレート
│   │   ├── main.bicep          # メインエントリポイント
│   │   ├── parameters/         # パラメータファイル
│   │   │   ├── dev.parameters.json
│   │   │   └── prod.parameters.json
│   │   └── modules/            # 再利用可能モジュール
│   │       ├── management-groups/
│   │       ├── networking/
│   │       ├── security/
│   │       ├── monitoring/
│   │       └── landing-zone/
│   └── policies/               # Azure Policy定義
│       ├── definitions/        # ポリシー定義
│       ├── initiatives/        # イニシアチブ（ポリシーセット）
│       └── assignments/        # ポリシー割り当て
├── app/                        # Next.jsアプリケーション
│   ├── src/
│   ├── public/
│   ├── package.json
│   ├── tsconfig.json
│   ├── tailwind.config.js
│   └── Dockerfile
├── .gitignore                  # Git除外ファイル
├── README.md                   # プロジェクトREADME
└── LICENSE
```

### 2.5.2 各ディレクトリの役割

#### infrastructure/bicep/

すべての Azure インフラをコードで定義します。

- **main.bicep**: デプロイのエントリポイント
- **modules/**: 再利用可能なモジュール（VNet、Firewall 等）
- **parameters/**: 環境ごとのパラメータ

#### infrastructure/policies/

Azure Policy の定義、イニシアチブ、割り当てを管理します。

#### .github/workflows/

CI/CD パイプラインの定義です。GitHub Actions で自動デプロイします。

#### app/

実際のアプリケーションコードです。Next.js + TypeScript + Tailwind CSS を使用します。

---

## 2.6 .gitignore の設定

機密情報やビルド成果物を Git にコミットしないように、`.gitignore`ファイルがリポジトリに設定済みです。

### 重要: 機密情報の取り扱い

以下の情報は**絶対に Git にコミットしないでください**：

- パスワード
- API キー
- サービスプリンシパルの認証情報
- 証明書
- 接続文字列

これらは：

- Azure Key Vault に保存
- GitHub Secrets に保存
- 環境変数で渡す

---

## 2.7 Azure 環境の確認

### 2.7.1 テナント情報の確認

ログインしたアカウントのテナント情報を確認します。

```bash
az account show --output table
```

出力例：

```
Name                          SubscriptionId                        TenantId                              State
----------------------------  ------------------------------------  ------------------------------------  -------
Azure subscription 1          xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy  Enabled
```

---

## 2.10 初回の Git コミット・プッシュ

環境設定が完了したら、変更を Git にコミット・プッシュします。

### 2.10.1 現在の状態確認

```bash
git status
```

### 2.10.2 変更をステージング

```bash
git add .
```

### 2.10.3 コミット

```bash
git commit -m "Initial setup: devcontainer and gitignore"
```

### 2.10.4 プッシュ

```bash
git push origin main
```

Codespaces では、GitHub との認証が自動的に行われるため、パスワード入力は不要です。

### 2.10.5 GitHub で確認

ブラウザで GitHub リポジトリを開き、コミットが反映されていることを確認します。

---

## 2.10 章のまとめ

本章で行ったこと：

1. ✅ Azure アカウントの作成
2. ✅ GitHub アカウントの準備
3. ✅ リポジトリのフォーク
4. ✅ GitHub Codespaces の起動
5. ✅ 開発環境のセットアップ（devcontainer）
6. ✅ 必要なツールのインストール確認
   - Azure CLI
   - Bicep CLI
   - Git
   - Node.js
7. ✅ プロジェクト構造の理解
8. ✅ .gitignore の確認
9. ✅ Azure 環境の確認
10. ✅ 初回の Git コミット・プッシュ

### チェックリスト

以下がすべて完了していることを確認してください：

- [ ] Azure アカウントにログインできる
- [ ] `az login`が成功する
- [ ] GitHub Codespaces が起動している
- [ ] `az --version`でバージョンが表示される
- [ ] `az bicep version`でバージョンが表示される
- [ ] テナント ID とサブスクリプション ID を確認した
- [ ] 初回の Git コミット・プッシュが完了した

---

## トラブルシューティング

### Q1: Azure CLI でログインできない

**症状**: `az login`でエラーが出る

**解決策**:

```bash
# デバイスコード認証を使用
az login --use-device-code

# 表示されたURLとコードでブラウザから認証
```

### Q2: Bicep CLI がインストールされていない

**症状**: `az bicep version`でエラー

**解決策**:

```bash
# Bicepのインストール
az bicep install

# バージョン確認
az bicep version
```

### Q3: GitHub にプッシュできない

**症状**: `git push`で認証エラー

**解決策**:
Codespaces では通常自動的に認証されますが、問題がある場合：

```bash
# GitHubの認証状態を確認
gh auth status

# 必要に応じて再認証
gh auth login
```

### Q4: Codespaces が起動しない

**症状**: Codespaces の作成に失敗

**解決策**:

- ブラウザのキャッシュをクリア
- 別のブラウザで試す
- GitHub のステータスページで障害がないか確認
- 少し時間を置いて再試行

---

## 次のステップ

環境準備が完了したら、次は CAF ランディングゾーンの詳細を学びます。

👉 [第 3 章：CAF ランディングゾーン詳細](chapter03-caf-overview.md)

---

## 参考リンク

- [Azure CLI ドキュメント](https://docs.microsoft.com/cli/azure/)
- [Bicep ドキュメント](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)
- [GitHub Codespaces ドキュメント](https://docs.github.com/codespaces)
- [Azure サービスプリンシパル](https://docs.microsoft.com/azure/active-directory/develop/app-objects-and-service-principals)
- [GitHub Secrets](https://docs.github.com/actions/security-guides/encrypted-secrets)

---

**最終更新**: 2026 年 1 月 7 日
