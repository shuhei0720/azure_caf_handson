# 第 4 章：Azure 環境の初期セットアップ

## 本章の目的

本章では、Azure 環境を実際にセットアップします。Azure ポータルへのアクセス、初期 Subscription の確認、サービスプリンシパルの作成、そして最初の Bicep ファイルの作成とデプロイを行います。

**所要時間**: 約 1-2 時間  
**難易度**: ⭐⭐

---

## 4.1 Azure ポータルへのアクセス

### 4.1.1 ポータルへのサインイン

1. [Azure ポータル](https://portal.azure.com)にアクセス

2. 作成した Microsoft アカウントでサインイン

3. MFA が設定されている場合は、認証を完了

4. Azure ポータルのホーム画面が表示されます

### 4.1.2 ポータルの基本操作

#### ダッシュボード

ホーム画面では、よく使うリソースやサービスにアクセスできます。

#### 検索バー

画面上部の検索バーから、任意のサービスやリソースを検索できます。

試しに「Management groups」と検索してみましょう。

#### Cloud Shell

画面上部の Cloud Shell アイコン（`>_`）をクリックすると、ブラウザ内で Bash または PowerShell を実行できます。

初回起動時は、ストレージアカウントの作成を求められます（無料枠内で作成可能）。

---

## 4.2 テナントとサブスクリプションの確認

### 4.2.1 テナント情報の確認

#### ポータルで確認

1. 画面右上のアカウントアイコンをクリック
2. 「ディレクトリの切り替え」を選択
3. 現在のテナント（ディレクトリ）を確認

#### CLI で確認

GitHub Codespaces のターミナルで実行：

```bash
# Azure CLIにログイン（まだの場合）
az login --use-device-code

# テナント情報を表示
az account show --output table
```

出力例：

```
Name                 CloudName    SubscriptionId                        TenantId                              State
-------------------  -----------  ------------------------------------  ------------------------------------  -------
Azure subscription 1 AzureCloud   12345678-1234-1234-1234-123456789abc  87654321-4321-4321-4321-987654321dcb  Enabled
```

以下の情報をメモします：

- **SubscriptionId**: サブスクリプション ID
- **TenantId**: テナント ID

### 4.2.2 サブスクリプションの確認

```bash
# すべてのサブスクリプションを表示
az account list --output table
```

新規アカウントの場合、通常 1 つのサブスクリプションのみが存在します。

#### デフォルトサブスクリプションの設定

複数のサブスクリプションがある場合は、デフォルトを設定：

```bash
az account set --subscription "サブスクリプション名またはID"
```

確認：

```bash
az account show --query name -o tsv
```

---

## 4.3 Management Groups の権限確認

### 4.3.1 Management Groups とは（復習）

Management Groups は、複数のサブスクリプションをグループ化し、ポリシーを階層的に適用する仕組みです。

### 4.3.2 ルート Management Group へのアクセス権付与

Management Groups を作成・管理するには、ルート Management Group に対する権限が必要です。

#### ポータルでの権限付与

1. Azure ポータルで「Management groups」を検索

2. 初回アクセス時、Management Groups が有効化されます

3. 画面右上の「設定」（歯車アイコン）をクリック

4. 「Permissions」タブを選択

5. 「Elevate access to manage all Azure subscriptions and management groups」をチェック

6. 「Save」をクリック

これで、あなたのアカウントにルートスコープの「User Access Administrator」ロールが付与されます。

#### CLI での確認

```bash
# 自分のロール割り当てを確認
az role assignment list \
  --assignee $(az account show --query user.name -o tsv) \
  --scope / \
  --output table
```

「User Access Administrator」または「Owner」ロールが表示されれば OK です。

---

## 4.4 プロジェクトの初期化

### 4.4.1 .gitignore ファイルの作成

第 2 章で説明した.gitignore ファイルを作成します（まだの場合）。

```bash
# プロジェクトルートに移動
cd /workspaces/azure_caf_handson

# .gitignoreファイルを作成
cat << 'EOF' > .gitignore
# Azure
*.publishsettings
azureProfile.json

# Bicep
bicepconfig.json

# Node
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.pnpm-debug.log*

# Next.js
.next/
out/
build
dist
.cache

# Environment variables
.env
.env.local
.env.*.local

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Logs
logs
*.log

# Temporary files
tmp/
temp/
*.tmp

# Secrets
secrets/
*.secret
*.key
*.pem
*.pfx

# Terraform
.terraform/
*.tfstate
*.tfstate.backup
.terraform.lock.hcl

# Local config
local.settings.json
EOF

# 確認
cat .gitignore
```

### 4.4.2 環境変数ファイルの準備

機密情報を環境変数で管理します。

```bash
# .envファイルを作成（このファイルはGitにコミットしません）
cat << EOF > .env
# Azure環境情報
AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)
AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
AZURE_LOCATION=japaneast

# 命名規則
ENVIRONMENT=dev
COMPANY_PREFIX=contoso
EOF

# 確認
cat .env

# 環境変数を読み込む
source .env

# 確認
echo "Tenant ID: $AZURE_TENANT_ID"
echo "Subscription ID: $AZURE_SUBSCRIPTION_ID"
```

---

## 4.5 最初の Bicep ファイルの作成

### 4.5.1 Bicep の基本構造

Bicep ファイルは、Azure リソースを宣言的に定義します。

基本的な構文：

```bicep
// パラメータ（入力値）
param location string = 'japaneast'
param resourceName string

// 変数（計算値）
var storageAccountName = 'st${resourceName}${uniqueString(resourceGroup().id)}'

// リソース定義
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

// 出力値
output storageAccountId string = storageAccount.id
```

### 4.5.2 テスト用のリソースグループ作成

まず、簡単なリソースグループを作成して Bicep の動作を確認します。

#### test-rg.bicep ファイルの作成

```bash
# テスト用ディレクトリを作成
mkdir -p infrastructure/bicep/test

# Bicepファイルを作成
cat << 'EOF' > infrastructure/bicep/test/test-rg.bicep
// テスト用リソースグループ作成
targetScope = 'subscription'

@description('リソースグループ名')
param resourceGroupName string = 'rg-caf-handson-test'

@description('デプロイ先のリージョン')
param location string = 'japaneast'

@description('タグ')
param tags object = {
  Environment: 'Test'
  Project: 'CAF-Handson'
  ManagedBy: 'Bicep'
  CreatedDate: utcNow('yyyy-MM-dd')
}

// リソースグループの作成
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// 出力
output resourceGroupId string = resourceGroup.id
output resourceGroupName string = resourceGroup.name
EOF

# ファイルの確認
cat infrastructure/bicep/test/test-rg.bicep
```

### 4.5.3 Bicep ファイルの検証

デプロイ前に、構文エラーをチェックします。

```bash
# Bicepファイルのビルド（ARM JSONに変換）
az bicep build --file infrastructure/bicep/test/test-rg.bicep

# 生成されたARMテンプレートを確認（オプション）
cat infrastructure/bicep/test/test-rg.json
```

エラーがなければ、test-rg.json ファイルが生成されます。

### 4.5.4 What-If 実行（プレビュー）

実際にデプロイする前に、何が作成されるか確認します。

```bash
# What-If実行
az deployment sub what-if \
  --location japaneast \
  --template-file infrastructure/bicep/test/test-rg.bicep \
  --parameters resourceGroupName=rg-caf-handson-test
```

出力例：

```
Resource and property changes are indicated with these symbols:
  + Create

The deployment will update the following scope:

Scope: /subscriptions/12345678-1234-1234-1234-123456789abc

  + Microsoft.Resources/resourceGroups/rg-caf-handson-test
    location: "japaneast"
    tags:
      Environment: "Test"
      Project: "CAF-Handson"
      ManagedBy: "Bicep"
```

### 4.5.5 デプロイの実行

```bash
# サブスクリプションレベルでデプロイ
az deployment sub create \
  --name "test-rg-deployment-$(date +%Y%m%d-%H%M%S)" \
  --location japaneast \
  --template-file infrastructure/bicep/test/test-rg.bicep \
  --parameters resourceGroupName=rg-caf-handson-test
```

デプロイには数秒かかります。

出力例：

```json
{
  "id": "/subscriptions/.../providers/Microsoft.Resources/deployments/test-rg-deployment-20260107-120000",
  "name": "test-rg-deployment-20260107-120000",
  "properties": {
    "correlationId": "...",
    "outputs": {
      "resourceGroupId": {
        "type": "String",
        "value": "/subscriptions/.../resourceGroups/rg-caf-handson-test"
      },
      "resourceGroupName": {
        "type": "String",
        "value": "rg-caf-handson-test"
      }
    },
    "provisioningState": "Succeeded",
    ...
  }
}
```

### 4.5.6 Azure ポータルで確認

1. Azure ポータルを開く
2. 「Resource groups」を検索
3. 「rg-caf-handson-test」が作成されていることを確認
4. リソースグループをクリックして詳細を表示
5. 「Tags」タブでタグが正しく設定されていることを確認

### 4.5.7 リソースの削除

テストが完了したら、リソースグループを削除します。

```bash
# リソースグループの削除
az group delete \
  --name rg-caf-handson-test \
  --yes \
  --no-wait

# 削除状況の確認
az group show --name rg-caf-handson-test --query properties.provisioningState -o tsv
```

削除には数分かかります。「Deleting」→「NotFound」となれば完了です。

---

## 4.6 Bicep モジュールの構造設計

本格的なインフラ構築の前に、Bicep プロジェクトの構造を設計します。

### 4.6.1 ディレクトリ構造

```
infrastructure/
└── bicep/
    ├── main.bicep                 # メインエントリポイント
    ├── parameters/                # パラメータファイル
    │   ├── common.parameters.json
    │   ├── dev.parameters.json
    │   └── prod.parameters.json
    └── modules/                   # 再利用可能モジュール
        ├── management-groups/     # Management Groups
        │   └── main.bicep
        ├── networking/            # ネットワーク
        │   ├── hub-vnet.bicep
        │   ├── spoke-vnet.bicep
        │   ├── firewall.bicep
        │   └── bastion.bicep
        ├── security/              # セキュリティ
        │   ├── key-vault.bicep
        │   └── nsg.bicep
        ├── monitoring/            # 監視
        │   ├── log-analytics.bicep
        │   └── alerts.bicep
        └── landing-zone/          # Landing Zone
            └── main.bicep
```

### 4.6.2 共通パラメータファイルの作成

```bash
# パラメータディレクトリを作成
mkdir -p infrastructure/bicep/parameters

# 共通パラメータファイルを作成
cat << 'EOF' > infrastructure/bicep/parameters/common.parameters.json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "companyPrefix": {
      "value": "contoso"
    },
    "location": {
      "value": "japaneast"
    },
    "tags": {
      "value": {
        "ManagedBy": "Bicep",
        "Project": "CAF-Landing-Zone",
        "CostCenter": "IT-001"
      }
    }
  }
}
EOF

# 確認
cat infrastructure/bicep/parameters/common.parameters.json
```

---

## 4.7 命名規則の定義

### 4.7.1 命名規則の設計

一貫した命名規則は、リソース管理の基本です。

#### パターン

```
{resource-type}-{workload}-{environment}-{region}-{instance}
```

#### 例

```
rg-platform-prod-jpe-001        # Resource Group
vnet-hub-prod-jpe-001           # Virtual Network
afw-hub-prod-jpe-001            # Azure Firewall
law-platform-prod-jpe-001       # Log Analytics Workspace
kv-app1-prod-jpe-001            # Key Vault
```

### 4.7.2 命名規則モジュールの作成

Bicep で命名規則を実装します。

```bash
# 共通モジュールディレクトリを作成
mkdir -p infrastructure/bicep/modules/common

# 命名規則モジュールを作成
cat << 'EOF' > infrastructure/bicep/modules/common/naming.bicep
// 命名規則モジュール

@description('リソースタイプ（例: rg, vnet, afw）')
param resourceType string

@description('ワークロード名（例: platform, hub, app1）')
param workload string

@description('環境（dev, staging, prod）')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environment string

@description('リージョンの短縮形（例: jpe, jps）')
param regionShort string = 'jpe'

@description('インスタンス番号')
param instance string = '001'

// リソース名を生成
var resourceName = '${resourceType}-${workload}-${environment}-${regionShort}-${instance}'

// 出力
output name string = resourceName
EOF

# 確認
cat infrastructure/bicep/modules/common/naming.bicep
```

### 4.7.3 命名規則のテスト

```bash
# テスト用Bicepファイルを作成
cat << 'EOF' > infrastructure/bicep/test/test-naming.bicep
targetScope = 'subscription'

// 命名規則モジュールを使用
module rgNaming '../modules/common/naming.bicep' = {
  name: 'rgNaming'
  params: {
    resourceType: 'rg'
    workload: 'platform'
    environment: 'prod'
    regionShort: 'jpe'
    instance: '001'
  }
}

// リソースグループを作成
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgNaming.outputs.name
  location: 'japaneast'
}

output resourceGroupName string = resourceGroup.name
EOF

# What-Ifで確認
az deployment sub what-if \
  --location japaneast \
  --template-file infrastructure/bicep/test/test-naming.bicep
```

出力に「rg-platform-prod-jpe-001」という名前のリソースグループが表示されれば OK です。

---

## 4.8 Git へのコミット

### 4.8.1 変更の確認

```bash
# 変更されたファイルを確認
git status
```

### 4.8.2 ステージングとコミット

```bash
# すべての変更をステージング
git add .

# コミット
git commit -m "Chapter 4: Initial Azure setup and first Bicep templates

- Created .gitignore
- Created .env for environment variables
- Created test Bicep templates for resource group
- Created naming convention module
- Created common parameters file
- Tested Bicep deployment"
```

### 4.8.3 プッシュ

```bash
# リモートリポジトリにプッシュ
git push origin main
```

### 4.8.4 GitHub で確認

ブラウザで GitHub リポジトリを開き、変更が反映されていることを確認します。

---

## 4.9 Azure ポータルでのデプロイ履歴確認

### 4.9.1 サブスクリプションレベルのデプロイ確認

1. Azure ポータルを開く
2. 「Subscriptions」を検索
3. 自分のサブスクリプションをクリック
4. 左メニューの「Deployments」をクリック
5. これまでのデプロイ履歴が表示される

各デプロイをクリックすると：

- 入力パラメータ
- 出力値
- デプロイされたリソース
- エラー（あれば）

を確認できます。

---

## 4.10 トラブルシューティング

### Q1: Bicep のビルドに失敗する

**症状**: `az bicep build`でエラー

**解決策**:

```bash
# Bicepのバージョン確認
az bicep version

# 最新版にアップグレード
az bicep upgrade

# Bicepファイルの構文チェック
az bicep lint --file infrastructure/bicep/test/test-rg.bicep
```

### Q2: デプロイに失敗する

**症状**: `az deployment sub create`でエラー

**解決策**:

```bash
# 詳細なエラーメッセージを表示
az deployment sub create \
  --name test \
  --location japaneast \
  --template-file infrastructure/bicep/test/test-rg.bicep \
  --verbose

# デプロイ操作の詳細を確認
az deployment operation sub list \
  --name test \
  --query "[?properties.provisioningState=='Failed']"
```

よくあるエラー：

- **権限不足**: サブスクリプションの Contributor ロールがあるか確認
- **クォータ超過**: サブスクリプションの制限を確認
- **リージョン未対応**: 指定したリージョンでサービスが利用可能か確認

### Q3: Management Groups にアクセスできない

**症状**: Management Groups のページでエラー

**解決策**:

```bash
# 権限の昇格（ポータルの設定で実施）
# Azureポータル > Management groups > 設定 > Elevate access

# または、Azure ADの「Global Administrator」ロールを持つユーザーに依頼
```

### Q4: リソースグループが削除できない

**症状**: `az group delete`で削除できない

**解決策**:

```bash
# リソースグループ内のリソースを確認
az resource list --resource-group rg-caf-handson-test --output table

# リソースが残っている場合は、先に削除
az resource delete --ids <resource-id>

# または、ポータルから手動で削除
```

### Q5: Git のプッシュに失敗する

**症状**: `git push`でエラー

**解決策**:

```bash
# リモートリポジトリの状態を確認
git remote -v

# 最新の状態を取得
git pull origin main --rebase

# 再度プッシュ
git push origin main
```

---

## 4.11 章のまとめ

本章で行ったこと：

1. ✅ Azure ポータルへのアクセス
2. ✅ テナントとサブスクリプションの確認
3. ✅ Management Groups の権限設定
4. ✅ .gitignore ファイルの作成
5. ✅ 環境変数ファイルの準備
6. ✅ 最初の Bicep ファイルの作成
7. ✅ Bicep のビルドと検証
8. ✅ What-If 実行（デプロイプレビュー）
9. ✅ 実際のデプロイ
10. ✅ Azure ポータルでの確認
11. ✅ 命名規則モジュールの作成
12. ✅ 共通パラメータファイルの作成
13. ✅ Git へのコミット・プッシュ

### 学んだ重要な概念

- **Bicep の基本構文**: パラメータ、リソース、出力
- **targetScope**: サブスクリプションレベルのデプロイ
- **What-If**: デプロイ前のプレビュー
- **命名規則**: 一貫したリソース命名
- **モジュール化**: 再利用可能な Bicep モジュール

### 次章への準備

これで、Azure でのデプロイの基本が理解できました。次章からは、本格的なランディングゾーンの構築に入ります。

---

## チェックリスト

以下を確認してください：

- [ ] Azure ポータルにアクセスできる
- [ ] テナント ID とサブスクリプション ID を控えた
- [ ] Management Groups へのアクセス権がある
- [ ] .gitignore ファイルが作成されている
- [ ] Bicep ファイルのビルドが成功する
- [ ] テスト用リソースグループをデプロイできた
- [ ] Azure ポータルでリソースを確認できた
- [ ] テスト用リソースグループを削除した
- [ ] 命名規則モジュールが動作する
- [ ] Git にコミット・プッシュできた

---

## 次のステップ

環境のセットアップが完了したら、次は Management Groups の設計と構築に進みます。

👉 [第 5 章：Management Groups 設計・構築](chapter05-management-groups.md)

---

## 参考リンク

- [Bicep ドキュメント](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)
- [Bicep モジュール](https://docs.microsoft.com/azure/azure-resource-manager/bicep/modules)
- [Azure CLI リファレンス](https://docs.microsoft.com/cli/azure/)
- [命名規則ベストプラクティス](https://docs.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)
- [What-If デプロイ](https://docs.microsoft.com/azure/azure-resource-manager/templates/deploy-what-if)

---

**最終更新**: 2026 年 1 月 7 日
