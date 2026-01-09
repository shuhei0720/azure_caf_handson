# 第 7 章：監視・ログ基盤構築（1 日目）

## 本章の目的

本章では、Management Subscription に監視・ログ基盤を構築します。Log Analytics Workspace、診断設定、基本的なアラートを実装し、システムの可観測性の基礎を確立します。

**所要時間**: 約 2-3 時間  
**難易度**: ⭐⭐  
**実施タイミング**: **1 日目**（Management Subscription 作成後）

---

## 7.0 事前準備：Management Subscription の選択

本章では、監視・ログリソースを **Management Subscription** にデプロイします。

作業を開始する前に、必ず適切なサブスクリプションを選択してください：

```bash
# 環境変数を読み込み
source .env

# Management Subscriptionに切り替え
az account set --subscription $SUB_MANAGEMENT_ID

# 現在のサブスクリプションを確認
az account show --query "{Name:name, SubscriptionId:id}" -o table
```

**注意**: 第 6 章で作成した Management Subscription を使用します。

---

## 7.1 可観測性（Observability）とは

### 7.1.1 可観測性の 3 つの柱

```mermaid
graph TB
    subgraph "可観測性の3つの柱"
        A[メトリクス<br/>Metrics]
        B[ログ<br/>Logs]
        C[トレース<br/>Traces]
    end

    subgraph "Azure サービス"
        D[Azure Monitor Metrics]
        E[Log Analytics]
        F[Application Insights]
    end

    A --> D
    B --> E
    C --> F

    subgraph "アクション"
        G[アラート]
        H[ダッシュボード]
        I[自動修復]
    end

    D --> G
    E --> H
    F --> I

    style A fill:#e1f5ff
    style B fill:#fff4e1
    style C fill:#e8f5e9
```

### 7.1.2 監視戦略

**監視すべき対象**:

- **インフラストラクチャ**: CPU、メモリ、ディスク、ネットワーク
- **アプリケーション**: レスポンスタイム、エラー率、スループット
- **セキュリティ**: 異常なアクセス、失敗した認証
- **コスト**: リソース使用量、予算超過

---

## 7.2 Azure Monitor の理解

### 7.2.1 Azure Monitor とは

**Azure Monitor**は、すべての Azure リソースの監視を統合するサービスです。

**機能**:

- メトリクスの収集と可視化
- ログの収集と分析（Log Analytics）
- アラートの設定
- 自動スケーリング
- ダッシュボード

### 7.2.2 データフロー

```mermaid
graph LR
    subgraph "データソース"
        A1[Azure リソース]
        A2[アプリケーション]
        A3[ゲストOS]
    end

    subgraph "Azure Monitor"
        B1[Metrics Store]
        B2[Logs Store<br/>Log Analytics]
    end

    subgraph "可視化・アクション"
        C1[Metrics Explorer]
        C2[Log Analytics クエリ]
        C3[アラート]
        C4[ダッシュボード]
        C5[Workbooks]
    end

    A1 --> B1
    A2 --> B1
    A2 --> B2
    A3 --> B2

    B1 --> C1
    B1 --> C3
    B2 --> C2
    B2 --> C3
    C1 --> C4
    C2 --> C5
```

---

## 7.3 Log Analytics Workspace の構築

```mermaid
graph TB
    subgraph "データソース"
        A[Azure リソース<br/>診断設定]
        B[仮想マシン<br/>DCR]
        C[Entra ID<br/>監査ログ]
        D[Activity Log]
    end

    subgraph "Log Analytics Workspace"
        E[データ取り込み<br/>Ingestion]
        F[Interactive層<br/>90日: $2.30/GB]
        G[Archive層<br/>640日: $0.10/GB]
    end

    subgraph "利用"
        H[KQL クエリ<br/>高速分析]
        I[Azure Monitor<br/>アラート]
        J[Workbooks<br/>可視化]
        K[コンプライアンス<br/>監査]
    end

    A --> E
    B --> E
    C --> E
    D --> E

    E --> F
    F --> G

    F --> H
    F --> I
    F --> J
    G --> K

    style F fill:#e1f5ff
    style G fill:#f0f0f0
```

**Log Analytics Workspace の役割：**

Log Analytics Workspace は、Azure 全体のログとメトリクスを集約する**中央ログストア**です。すべての監視データがここに集まり、KQL クエリで分析、アラート発火、長期保存が可能になります。

### 7.3.1 Resource Group の作成

監視リソース用の Resource Group を Bicep で作成します。

#### モジュールの作成

ディレクトリを作成：

```bash
mkdir -p infrastructure/bicep/modules/resource-group
```

ファイル `infrastructure/bicep/modules/resource-group/resource-group.bicep` を作成：

```bicep
targetScope = 'subscription'

@description('リソースグループ名')
param resourceGroupName string

@description('デプロイ先のリージョン')
param location string

@description('タグ')
param tags object = {}

// Resource Group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

output resourceGroupName string = resourceGroup.name
output resourceGroupId string = resourceGroup.id
```

#### オーケストレーションへのパラメータ追記

ファイル `infrastructure/bicep/orchestration/main.bicepparam` を開き、以下を追記：

```bicep
// =============================================================================
// Chapter 7: Monitoring
// =============================================================================

param monitoring = {
  resourceGroup: {
    name: 'rg-platform-management-prod-jpe-001'
    tags: {
      Environment: 'Production'
      ManagedBy: 'Bicep'
      Component: 'Management'
    }
  }
  // 7.3.2以降で追記予定
}
```

#### オーケストレーションへのモジュール追加

ファイル `infrastructure/bicep/orchestration/main.bicep` を開き、以下を追記：

```bicep
// =============================================================================
// パラメータ定義（既存のセクションに追加）
// =============================================================================

@description('Monitoring設定')
param monitoring object

// =============================================================================
// モジュールデプロイ（既存のセクションに追加）
// =============================================================================

// Chapter 7: Management Resource Group
module managementRG '../modules/resource-group/resource-group.bicep' = {
  name: 'deploy-management-rg'
  params: {
    resourceGroupName: monitoring.resourceGroup.name
    location: location
    tags: union(tags, monitoring.resourceGroup.tags)
  }
}
```

#### What-If 実行

```bash
# Management Subscription に切り替え（念のため確認）
az account set --subscription $SUB_MANAGEMENT_ID

# What-If実行
az deployment sub what-if \
  --name "main-deployment-$(date +%Y%m%d-%H%M%S)" \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/main.bicep \
  --parameters infrastructure/bicep/orchestration/main.bicepparam
```

#### デプロイ実行

```bash
# デプロイ実行
az deployment sub create \
  --name "main-deployment-$(date +%Y%m%d-%H%M%S)" \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/main.bicep \
  --parameters infrastructure/bicep/orchestration/main.bicepparam

echo "✅ Resource Group が orchestration 経由でデプロイされました"
```

### 7.3.2 Log Analytics Workspace の作成

すべてのログとメトリクスを集約する中央ログストアとして、Log Analytics Workspace を作成します。

#### モジュールの作成

ディレクトリを作成：

```bash
mkdir -p infrastructure/bicep/modules/monitoring
```

ファイル `infrastructure/bicep/modules/monitoring/log-analytics.bicep` を作成：

```bicep
targetScope = 'resourceGroup'

@description('Log Analytics Workspaceの名前')
param workspaceName string

@description('デプロイ先のリージョン')
param location string

@description('対話型分析期間（日数）- この期間はKQLで高速アクセス可能')
@minValue(30)
@maxValue(730)
param retentionInDays int = 90

@description('タグ')
param tags object = {}

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// 出力
output workspaceId string = logAnalyticsWorkspace.id
output workspaceName string = logAnalyticsWorkspace.name
output customerId string = logAnalyticsWorkspace.properties.customerId
```

**注意：** ワークスペース作成時は Interactive 期間（`retentionInDays`）を設定します。各テーブルの総保持期間（`totalRetentionInDays`）とアーカイブ期間の設定は、次のセクション 7.3.3 で Bicep を使用して実施します。

#### オーケストレーションへのパラメータ追記

ファイル `infrastructure/bicep/orchestration/main.bicepparam` を開き、`monitoring` セクションに追記：

```bicep
param monitoring = {
  resourceGroup: {
    name: 'rg-platform-management-prod-jpe-001'
    tags: {
      Environment: 'Production'
      ManagedBy: 'Bicep'
      Component: 'Management'
    }
  }
  // 👇 7.3.2で追記
  logAnalytics: {
    workspaceName: 'log-platform-prod-jpe-001'
    retentionInDays: 90
    tags: {
      Environment: 'Production'
      ManagedBy: 'Bicep'
      Component: 'Monitoring'
    }
  }
}
```

#### オーケストレーションへのモジュール追加

ファイル `infrastructure/bicep/orchestration/main.bicep` を開き、以下を追記：

```bicep
// Chapter 7: Log Analytics Workspace
module logAnalytics '../modules/monitoring/log-analytics.bicep' = {
  name: 'deploy-log-analytics'
  scope: resourceGroup(monitoring.resourceGroup.name)
  params: {
    workspaceName: monitoring.logAnalytics.workspaceName
    location: location
    retentionInDays: monitoring.logAnalytics.retentionInDays
    tags: union(tags, monitoring.logAnalytics.tags)
  }
  dependsOn: [
    managementRG
  ]
}
```

#### What-If 実行

```bash
# What-If実行
az deployment sub what-if \
  --name "main-deployment-$(date +%Y%m%d-%H%M%S)" \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/main.bicep \
  --parameters infrastructure/bicep/orchestration/main.bicepparam
```

#### デプロイ実行

```bash
# デプロイ実行
az deployment sub create \
  --name "main-deployment-$(date +%Y%m%d-%H%M%S)" \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/main.bicep \
  --parameters infrastructure/bicep/orchestration/main.bicepparam

# Workspace IDを取得して.envに保存
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group rg-platform-management-prod-jpe-001 \
  --workspace-name log-platform-prod-jpe-001 \
  --query id -o tsv)

grep -q "WORKSPACE_ID=" .env || echo "WORKSPACE_ID=$WORKSPACE_ID" >> .env
echo "Log Analytics Workspace ID: $WORKSPACE_ID"

echo "✅ Log Analytics Workspace が orchestration 経由でデプロイされました"
```

**Azure ポータルでの確認：**

1. [Azure ポータル](https://portal.azure.com) にサインイン
2. **リソースグループ** > **rg-platform-management-prod-jpe-001** を選択
3. **log-platform-prod-jpe-001** をクリック
4. **概要** タブで以下を確認：
   - **場所**: Japan East
   - **価格レベル**: 従量課金制 (PerGB2018)
   - **ワークスペース ID**: `WORKSPACE_ID` と一致するか確認
5. **設定** > **使用量と推定コスト** を選択：
   - **データ保持**: 90 日（Interactive 期間）が設定されていることを確認
   - 日次データ取り込み量とコスト試算を確認

### 7.3.3 テーブルレベルの保持期間設定

Log Analytics Workspace のテーブルごとに保持期間を設定します。これにより、Interactive 期間（高速アクセス）と Archive 期間（低コスト長期保存）を制御できます。

ファイル `infrastructure/bicep/modules/monitoring/log-analytics-table-retention.bicep` を作成：

```bicep
@description('Log Analytics Workspace名')
param workspaceName string

@description('テーブル名の配列')
param tableNames array

@description('対話型分析期間（日数）')
@minValue(30)
@maxValue(730)
param retentionInDays int = 90

@description('総保持期間（日数）- アーカイブを含む')
@minValue(30)
@maxValue(2556)
param totalRetentionInDays int = 730

// 既存のLog Analytics Workspace
resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: workspaceName
}

// 複数テーブルの保持期間設定
resource tableRetention 'Microsoft.OperationalInsights/workspaces/tables@2022-10-01' = [for tableName in tableNames: {
  parent: workspace
  name: tableName
  properties: {
    retentionInDays: retentionInDays
    totalRetentionInDays: totalRetentionInDays
    plan: 'Analytics'
  }
}]

output configuredTables array = [for (tableName, i) in tableNames: {
  name: tableRetention[i].name
  retentionInDays: tableRetention[i].properties.retentionInDays
  totalRetentionInDays: tableRetention[i].properties.totalRetentionInDays
}]
```

#### オーケストレーションへのパラメータ追記

ファイル `infrastructure/bicep/orchestration/main.bicepparam` を開き、`monitoring` セクションに追記：

```bicep
param monitoring = {
  resourceGroup: {
    name: 'rg-platform-management-prod-jpe-001'
    tags: {
      Environment: 'Production'
      ManagedBy: 'Bicep'
      Component: 'Management'
    }
  }
  logAnalytics: {
    workspaceName: 'log-platform-prod-jpe-001'
    retentionInDays: 90
    tags: {
      Environment: 'Production'
      ManagedBy: 'Bicep'
      Component: 'Monitoring'
    }
  }
  // 👇 7.3.3で追記（テーブル名は以下のスクリプトで自動生成）
  tableRetention: {
    enabled: true  // 初回デプロイ時はtrue、設定完了後にfalseに変更
    retentionInDays: 90
    totalRetentionInDays: 730
    tableNames: [
      // ここにテーブル名が自動追記されます
    ]
  }
}
```

**テーブル名の自動取得と main.bicepparam への追加：**

Workspace に存在するすべてのテーブルを自動取得し、`orchestration/main.bicepparam` に追記します：

```bash
# Log Analytics Workspaceのすべてのテーブルを取得
TABLES=$(az monitor log-analytics workspace table list \
  --resource-group rg-platform-management-prod-jpe-001 \
  --workspace-name log-platform-prod-jpe-001 \
  --query "[].name" -o tsv)

echo "取得されたテーブル数: $(echo "$TABLES" | wc -l)"

# テーブル名配列を一時ファイルに生成
TEMP_FILE=$(mktemp)
echo "    tableNames: [" > $TEMP_FILE
for TABLE in $TABLES; do
  echo "      '$TABLE'" >> $TEMP_FILE
done
echo "    ]" >> $TEMP_FILE

# main.bicepparamの既存のtableNames配列を置換
sed -i '/tableNames: \[/,/^[[:space:]]*\]/c\' infrastructure/bicep/orchestration/main.bicepparam
sed -i '/tableRetention: {/r '$TEMP_FILE infrastructure/bicep/orchestration/main.bicepparam
rm $TEMP_FILE

echo "orchestration/main.bicepparamにテーブル名が追加されました"
grep -A 50 'tableNames:' infrastructure/bicep/orchestration/main.bicepparam | head -n 55
```

#### オーケストレーションへのモジュール追加

ファイル `infrastructure/bicep/orchestration/main.bicep` を開き、以下を追記：

```bicep
// Chapter 7: Log Analytics Table Retention
module tableRetention '../modules/monitoring/log-analytics-table-retention.bicep' = if (monitoring.tableRetention.enabled) {
  name: 'deploy-table-retention'
  scope: resourceGroup(monitoring.resourceGroup.name)
  params: {
    workspaceName: monitoring.logAnalytics.workspaceName
    tableNames: monitoring.tableRetention.tableNames
    retentionInDays: monitoring.tableRetention.retentionInDays
    totalRetentionInDays: monitoring.tableRetention.totalRetentionInDays
  }
  dependsOn: [
    logAnalytics
  ]
}
```

**What-If による事前確認：**

```bash
# What-If実行（orchestration経由）
az deployment sub what-if \
  --name "main-deployment-$(date +%Y%m%d-%H%M%S)" \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/main.bicep \
  --parameters infrastructure/bicep/orchestration/main.bicepparam
```

**デプロイ実行：**

```bash
# デプロイ実行（orchestration経由）
az deployment sub create \
  --name "main-deployment-$(date +%Y%m%d-%H%M%S)" \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/main.bicep \
  --parameters infrastructure/bicep/orchestration/main.bicepparam

echo "✅ すべてのテーブルに保持期間が orchestration 経由で設定されました"
```

> **💡 重要: enabled フラグの管理**
>
> テーブル保持期間設定は、Log Analytics のテーブルリソースに `schema` などの読み取り専用プロパティがあるため、Bicep で毎回デプロイすると What-If で 630 個のテーブル変更が警告として表示されます。
>
> **対応方法:**
>
> 1. **初回デプロイ時**: `tableRetention.enabled: true` に設定してデプロイ実行
> 2. **設定完了後**: 手動で `tableRetention.enabled: false` に変更
> 3. **以降のデプロイ**: `enabled: false` のままにしておく（What-If 警告が表示されなくなる）
>
> テーブル保持期間を変更したい場合のみ、再度 `enabled: true` にしてデプロイしてください。

**初回設定後の対応:**

テーブル保持期間は初回のみ設定すればよいため、設定完了後は `main.bicepparam` で無効化します：

```bicep
tableRetention: {
  enabled: false  // false にすることでWhat-If警告を回避
  retentionInDays: 90
  totalRetentionInDays: 730
  tableNames: [
    // テーブル名リスト（保持）
  ]
}
```

以降のデプロイでは、このモジュールはスキップされ、What-If で 630 個の変更が表示されなくなります。

**Azure ポータルでの確認：**

1. [Azure ポータル](https://portal.azure.com) で **log-platform-prod-jpe-001** を開く
2. **設定** > **テーブル** を選択
3. 各テーブルの保持期間設定を確認：
   - **Table**: テーブル名（例：AzureActivity, AzureDiagnostics, SigninLogs など）
   - **Retention (days)**: **90 日**（Interactive 期間）
   - **Total retention (days)**: **730 日**（総保持期間）
   - **Archive (days)**: **640 日**（= 730 - 90、アーカイブ期間）
4. 主要なテーブルで確認（クリックして詳細表示）：
   - **AzureActivity**: Activity Log のテーブル
   - **AzureDiagnostics**: 診断設定のテーブル
   - **SigninLogs**: Entra ID サインインログ
   - **AuditLogs**: Entra ID 監査ログ
5. **使用量と推定コスト** > **データ保持** タブで全体のコスト試算を確認：
   - Interactive 層（90 日）のコスト
   - Archive 層（640 日）のコスト
   - 合計コストとアーカイブによる節約額

**重要な注意事項：**

- **テーブルリストの更新**: 新しいテーブルが追加された場合、パラメーターファイルの `tableNames` 配列を更新してデプロイを再実行してください
- **カスタムテーブル**: Log Analytics にカスタムテーブルがある場合は、パラメーターファイルに追加してください
- **システムテーブル**: 一部のシステムテーブルは保持期間設定がサポートされない場合があります（デプロイ時にエラーが表示されます）
- **一括設定**: すべてのテーブルに同じ保持期間（Interactive: 90 日、Total: 730 日）が設定されます

**主要なテーブルの例：**

- `AzureActivity`: Activity Log
- `AzureDiagnostics`: 診断設定
- `SigninLogs`: Entra ID サインイン
- `AuditLogs`: Entra ID 監査
- `Heartbeat`: VM Insights ハートビート
- `Perf`: VM Insights パフォーマンス
- `InsightsMetrics`: VM Insights メトリクス
- `Syslog`: Linux Syslog
- `Event`: Windows Event
- その他、Workspace 内のすべてのテーブル

### 7.3.4 ログ保存期間とアーカイブ戦略

Log Analytics Workspace のデータ保存には 2 つの階層があります。

```mermaid
graph TB
    subgraph "Log Analytics Workspace データ保存階層"
        A[データ取り込み] -->|日次| B[Interactive Analytics 層]
        B -->|90日経過後| C[Archive 層]
        C -->|730日経過後| D[自動削除]

        B -->|"高速 KQL クエリ<br/>$2.30/GB/月"| E[日常的な分析<br/>・セキュリティ調査<br/>・トラブルシューティング<br/>・パフォーマンス分析]
        C -->|"低速クエリ<br/>$0.10/GB/月<br/>(95%削減)"| F[長期保存<br/>・コンプライアンス<br/>・監査証跡<br/>・トレンド分析]

        style B fill:#4CAF50,stroke:#2E7D32,stroke-width:3px,color:#fff
        style C fill:#2196F3,stroke:#1565C0,stroke-width:3px,color:#fff
        style D fill:#757575,stroke:#424242,stroke-width:2px,color:#fff
        style E fill:#E8F5E9,stroke:#2E7D32,stroke-width:2px
        style F fill:#E3F2FD,stroke:#1565C0,stroke-width:2px
    end
```

**データ保存タイムライン：**

```
日数: 0 ─────────────────── 90 ────────────────────────────────────── 730
      │                      │                                          │
      │  Interactive 層      │           Archive 層                     │
      │  (高速アクセス)      │        (低コスト保存)                   │ 削除
      │  $2.30/GB/月         │         $0.10/GB/月                     │
      └──────────────────────┴──────────────────────────────────────────┘
                             90日間                    640日間
                      (retentionInDays)    (totalRetentionInDays - retentionInDays)
```

#### Interactive Analytics 層（対話型分析）

- **期間**: 90 日（`retentionInDays`）
- **特徴**: KQL クエリで高速アクセス可能
- **コスト**: 約 $2.30/GB/月
- **用途**: 日常的なセキュリティ調査、トラブルシューティング、パフォーマンス分析

#### Archive 層（アーカイブ）

- **期間**: 91 日目〜730 日目（`totalRetentionInDays - retentionInDays`）
- **特徴**: 低コストの長期保存、クエリは遅い
- **コスト**: 約 $0.10/GB/月（約 95%削減）
- **用途**: コンプライアンス、監査証跡、長期トレンド分析

#### CAF ベストプラクティスに基づく推奨設定

| 要件レベル | Interactive | Total Retention | 用途                         |
| ---------- | ----------- | --------------- | ---------------------------- |
| **標準**   | 90 日       | 730 日（2 年）  | 一般的な企業、GDPR/SOC2 対応 |
| **金融**   | 90 日       | 2555 日（7 年） | 金融機関、厳格な監査要件     |
| **医療**   | 90 日       | 1825 日（5 年） | 医療機関、HIPAA 対応         |

**今回の実装:**

```yaml
retentionInDays: 90日 # Interactive期間
totalRetentionInDays: 730日 # 総保持期間（アーカイブ含む）
```

#### コスト比較の視覚化

**コスト試算例（1 日 10GB のログ取り込みの場合）:**

```mermaid
graph LR
    subgraph "アーカイブ活用（推奨）"
        A1[Interactive 90日<br/>$2,070/月] --> Total1["合計<br/>$2,710/月"]
        A2[Archive 640日<br/>$640/月] --> Total1
        style A1 fill:#4CAF50,stroke:#2E7D32,stroke-width:2px,color:#fff
        style A2 fill:#2196F3,stroke:#1565C0,stroke-width:2px,color:#fff
        style Total1 fill:#66BB6A,stroke:#2E7D32,stroke-width:3px,color:#fff
    end

    subgraph "アーカイブなし（非推奨）"
        B1[Interactive 730日<br/>$16,790/月] --> Total2["合計<br/>$16,790/月"]
        style B1 fill:#F44336,stroke:#C62828,stroke-width:2px,color:#fff
        style Total2 fill:#EF5350,stroke:#C62828,stroke-width:3px,color:#fff
    end

    Total1 -.->|"84% 削減<br/>$14,080/月 節約"| Total2
```

**詳細計算：**

| 項目               | アーカイブ活用                   | アーカイブなし                     | 差額          |
| ------------------ | -------------------------------- | ---------------------------------- | ------------- |
| **Interactive 層** | 10GB × 90 日 × $2.30 = $2,070/月 | 10GB × 730 日 × $2.30 = $16,790/月 | -$14,720      |
| **Archive 層**     | 10GB × 640 日 × $0.10 = $640/月  | $0/月                              | +$640         |
| **合計コスト**     | **$2,710/月**                    | **$16,790/月**                     | **-$14,080**  |
| **年間コスト**     | **$32,520**                      | **$201,480**                       | **-$168,960** |
| **削減率**         | -                                | -                                  | **84%**       |

**節約効果の要約：**

- **月額削減**: $14,080（約 84%）
- **年額削減**: $168,960（約 200 万円/年）
- **2 年間**: 約 400 万円の削減

#### Azure ポータルでの確認

1. Log Analytics Workspace に移動
2. **設定** > **使用量と推定コスト** を選択
3. **データ保持** タブで、Workspace 全体の保持期間を確認
4. **設定** > **テーブル** で各テーブルの保持期間を確認：
   - **Table**: テーブル名（AzureActivity, AzureDiagnostics など）
   - **Retention (days)**: 対話型分析期間（90 日）
   - **Total retention (days)**: 総保持期間（730 日）
   - **Archive (days)**: アーカイブ期間（640 日 = 730 - 90）

---

## 7.4 Data Collection Rules (DCR) の構築

```mermaid
graph LR
    subgraph "仮想マシン"
        VM1[Windows VM]
        VM2[Linux VM]
        A1[Azure Monitor<br/>Agent]
        A2[Azure Monitor<br/>Agent]

        VM1 --> A1
        VM2 --> A2
    end

    subgraph "Data Collection Rules"
        DCR1[DCR:<br/>VM Insights]
        DCR2[DCR:<br/>OS Logs]
    end

    subgraph "収集データ"
        D1[パフォーマンス<br/>メトリクス]
        D2[プロセス情報]
        D3[Windows<br/>Event Logs]
        D4[Linux<br/>Syslog]
    end

    subgraph "Log Analytics"
        LA[Log Analytics<br/>Workspace]
    end

    A1 -->|VM Insights| DCR1
    A2 -->|VM Insights| DCR1
    A1 -->|OS Logs| DCR2
    A2 -->|OS Logs| DCR2

    DCR1 --> D1
    DCR1 --> D2
    DCR2 --> D3
    DCR2 --> D4

    D1 --> LA
    D2 --> LA
    D3 --> LA
    D4 --> LA

    style DCR1 fill:#ffe6cc
    style DCR2 fill:#ffe6cc
    style LA fill:#e1f5ff
```

**Data Collection Rule (DCR) の役割：**

DCR は、Azure Monitor Agent が**どのデータを収集するか**を定義します。VM Insights 用と OS ログ用の 2 つの DCR を作成し、後の章で Azure Policy を使って全 VM に自動適用します。

### 7.4.1 DCR for VM Insights

VM Insights 用の DCR を作成します。これにより、VM のパフォーマンスメトリクスとプロセス情報を収集できます。

#### モジュールの作成

ファイル `infrastructure/bicep/modules/monitoring/dcr-vm-insights.bicep` を作成：

```bicep
targetScope = 'resourceGroup'

@description('DCRの名前')
param dcrName string

@description('デプロイ先のリージョン')
param location string

@description('Log Analytics Workspace ID')
param workspaceId string

@description('タグ')
param tags object = {}

// Data Collection Rule for VM Insights
resource dcrVMInsights 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: dcrName
  location: location
  tags: tags
  kind: 'Linux'
  properties: {
    description: 'Data Collection Rule for VM Insights (Performance and Processes)'
    dataSources: {
      performanceCounters: [
        {
          name: 'VMInsightsPerfCounters'
          streams: [
            'Microsoft-InsightsMetrics'
          ]
          samplingFrequencyInSeconds: 60
          counterSpecifiers: [
            '\\VmInsights\\DetailedMetrics'
          ]
        }
      ]
      extensions: [
        {
          name: 'DependencyAgentDataSource'
          streams: [
            'Microsoft-ServiceMap'
          ]
          extensionName: 'DependencyAgent'
          extensionSettings: {}
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          name: 'VMInsightsPerf-Logs-Dest'
          workspaceResourceId: workspaceId
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-InsightsMetrics'
        ]
        destinations: [
          'VMInsightsPerf-Logs-Dest'
        ]
      }
      {
        streams: [
          'Microsoft-ServiceMap'
        ]
        destinations: [
          'VMInsightsPerf-Logs-Dest'
        ]
      }
    ]
  }
}

output dcrId string = dcrVMInsights.id
output dcrName string = dcrVMInsights.name
```

#### オーケストレーションへのパラメータ追記

ファイル `infrastructure/bicep/orchestration/main.bicepparam` を開き、`monitoring` セクションに追記：

```bicep
param monitoring = {
  resourceGroup: {
    name: 'rg-platform-management-prod-jpe-001'
    tags: {
      Environment: 'Production'
      ManagedBy: 'Bicep'
      Component: 'Management'
    }
  }
  logAnalytics: {
    workspaceName: 'log-platform-prod-jpe-001'
    retentionInDays: 90
    tags: {
      Environment: 'Production'
      ManagedBy: 'Bicep'
      Component: 'Monitoring'
    }
  }
  tableRetention: {
    retentionInDays: 90
    totalRetentionInDays: 730
    tableNames: [
      // 7.3.3のスクリプトで自動追記済み
    ]
  }
  // 👇 7.4.1で追記
  dataCollectionRules: {
    vmInsights: {
      name: 'dcr-vm-insights-prod-jpe-001'
      tags: {
        Environment: 'Production'
        ManagedBy: 'Bicep'
        Component: 'Monitoring'
      }
    }
    osLogs: {
      name: 'dcr-os-logs-prod-jpe-001'
      tags: {
        Environment: 'Production'
        ManagedBy: 'Bicep'
        Component: 'Monitoring'
      }
    }
  }
}
```

#### オーケストレーションへのモジュール追加

ファイル `infrastructure/bicep/orchestration/main.bicep` を開き、以下を追記：

```bicep
// Chapter 7: DCR for VM Insights
module dcrVMInsights '../modules/monitoring/dcr-vm-insights.bicep' = {
  name: 'deploy-dcr-vm-insights'
  scope: resourceGroup(monitoring.resourceGroup.name)
  params: {
    dcrName: monitoring.dataCollectionRules.vmInsights.name
    location: location
    workspaceId: logAnalytics.outputs.workspaceId
    tags: union(tags, monitoring.dataCollectionRules.vmInsights.tags)
  }
  dependsOn: [
    managementRG
  ]
}

// Chapter 7: DCR Outputs
output dcrVMInsightsId string = dcrVMInsights.outputs.dcrId
```

#### What-If による事前確認

```bash
# What-If実行
az deployment sub what-if \
  --name "main-deployment-$(date +%Y%m%d-%H%M%S)" \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/main.bicep \
  --parameters infrastructure/bicep/orchestration/main.bicepparam
```

#### デプロイ実行

```bash
# デプロイ実行
az deployment sub create \
  --name "main-deployment-$(date +%Y%m%d-%H%M%S)" \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/main.bicep \
  --parameters infrastructure/bicep/orchestration/main.bicepparam

echo "✅ DCR for VM Insights が orchestration 経由でデプロイされました"
```

#### DCR ID の取得と保存

```bash
# リソースから直接DCR IDを取得
DCR_VM_INSIGHTS_ID=$(az resource show \
  --name dcr-vm-insights-prod-jpe-001 \
  --resource-group rg-platform-management-prod-jpe-001 \
  --resource-type "Microsoft.Insights/dataCollectionRules" \
  --query id -o tsv)

grep -q "DCR_VM_INSIGHTS_ID=" .env || echo "DCR_VM_INSIGHTS_ID=$DCR_VM_INSIGHTS_ID" >> .env
echo "VM Insights DCR ID: $DCR_VM_INSIGHTS_ID"
```

### 7.4.2 DCR for Windows Event Logs and Syslog

Windows Event ログと Linux Syslog を収集する DCR を作成します。

#### モジュールの作成

ファイル `infrastructure/bicep/modules/monitoring/dcr-os-logs.bicep` を作成：

```bicep
targetScope = 'resourceGroup'

@description('DCRの名前')
param dcrName string

@description('デプロイ先のリージョン')
param location string

@description('Log Analytics Workspace ID')
param workspaceId string

@description('タグ')
param tags object = {}

// Data Collection Rule for OS Logs (Windows Events + Syslog)
resource dcrOSLogs 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: dcrName
  location: location
  tags: tags
  properties: {
    description: 'Data Collection Rule for Windows Event Logs and Linux Syslog'
    dataSources: {
      windowsEventLogs: [
        {
          name: 'WindowsEventLogsDataSource'
          streams: [
            'Microsoft-Event'
          ]
          xPathQueries: [
            'System!*[System[(Level=1 or Level=2 or Level=3 or Level=4 or Level=0)]]'
            'Application!*[System[(Level=1 or Level=2 or Level=3 or Level=4 or Level=0)]]'
            // セキュリティログ: 監査の成功 (Audit Success)
            'Security!*[System[(band(Keywords,9007199254740992))]]'
            // セキュリティログ: 監査の失敗 (Audit Failure)
            'Security!*[System[(band(Keywords,4503599627370496))]]'
          ]
        }
      ]
      syslog: [
        {
          name: 'SyslogDataSource'
          streams: [
            'Microsoft-Syslog'
          ]
          facilityNames: [
            'auth'
            'authpriv'
            'cron'
            'daemon'
            'kern'
            'syslog'
            'user'
          ]
          logLevels: [
            'Alert'
            'Critical'
            'Debug'
            'Emergency'
            'Error'
            'Info'
            'Notice'
            'Warning'
          ]
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          name: 'OSLogs-Dest'
          workspaceResourceId: workspaceId
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-Event'
        ]
        destinations: [
          'OSLogs-Dest'
        ]
      }
      {
        streams: [
          'Microsoft-Syslog'
        ]
        destinations: [
          'OSLogs-Dest'
        ]
      }
    ]
  }
}

output dcrId string = dcrOSLogs.id
output dcrName string = dcrOSLogs.name
```

#### オーケストレーションへのモジュール追加

ファイル `infrastructure/bicep/orchestration/main.bicep` を開き、以下を追記：

```bicep
// Chapter 7: DCR for OS Logs
module dcrOSLogs '../modules/monitoring/dcr-os-logs.bicep' = {
  name: 'deploy-dcr-os-logs'
  scope: resourceGroup(monitoring.resourceGroup.name)
  params: {
    dcrName: monitoring.dataCollectionRules.osLogs.name
    location: location
    workspaceId: logAnalytics.outputs.workspaceId
    tags: union(tags, monitoring.dataCollectionRules.osLogs.tags)
  }
  dependsOn: [
    managementRG
  ]
}

// Chapter 7: DCR Outputs
output dcrOSLogsId string = dcrOSLogs.outputs.dcrId
```

#### What-If による事前確認

```bash
# What-If実行
az deployment sub what-if \
  --name "main-deployment-$(date +%Y%m%d-%H%M%S)" \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/main.bicep \
  --parameters infrastructure/bicep/orchestration/main.bicepparam
```

#### デプロイ実行

```bash
# デプロイ実行
az deployment sub create \
  --name "main-deployment-$(date +%Y%m%d-%H%M%S)" \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/main.bicep \
  --parameters infrastructure/bicep/orchestration/main.bicepparam

echo "✅ DCR for OS Logs が orchestration 経由でデプロイされました"
```

#### DCR ID の取得と保存

```bash
# リソースから直接DCR IDを取得
DCR_OS_LOGS_ID=$(az resource show \
  --name dcr-os-logs-prod-jpe-001 \
  --resource-group rg-platform-management-prod-jpe-001 \
  --resource-type "Microsoft.Insights/dataCollectionRules" \
  --query id -o tsv)

grep -q "DCR_OS_LOGS_ID=" .env || echo "DCR_OS_LOGS_ID=$DCR_OS_LOGS_ID" >> .env
echo "OS Logs DCR ID: $DCR_OS_LOGS_ID"
```

### 7.4.3 DCR の役割と今後の活用

作成した DCR は、後の章で **Azure Policy** と組み合わせることで、環境全体の VM に自動的に適用されます。

**組み込みポリシー例：**

- `Configure Windows machines to run Azure Monitor Agent and associate them to a Data Collection Rule`
- `Configure Linux machines to run Azure Monitor Agent and associate them to a Data Collection Rule`

これにより、新しく作成される VM にも自動的に Azure Monitor Agent がインストールされ、ログ収集が開始されます。

### 7.4.3 Azure Portal での確認

デプロイ後、Azure Portal で以下を確認します:

1. **Data Collection Rules の確認**

   - Azure Portal → Monitor → Data Collection Rules
   - `dcr-vm-insights-prod-jpe-001` と `dcr-os-logs-prod-jpe-001` が存在することを確認

2. **DCR の詳細確認**

   - DCR を開く → Resources → 後の章で VM を作成後、ここに VM が自動的に関連付けられることを確認
   - Data sources で Performance Counters や Syslog が設定されていることを確認

3. **Log Analytics への接続確認**
   - DCR を開く → Destinations → Log Analytics Workspace が正しく設定されていることを確認

---

## 7.5 Entra ID の監査ログ収集

```mermaid
graph LR
    subgraph "Entra ID (Azure AD)"
        A[ユーザー<br/>サインイン]
        B[管理者操作<br/>監査ログ]
        C[サービス<br/>プリンシパル]
        D[マネージドID]
    end

    subgraph "診断設定 (Tenant Level)"
        E[診断設定:<br/>Entra ID Logs]
    end

    subgraph "ログカテゴリ"
        F[SignInLogs]
        G[AuditLogs]
        H[NonInteractive<br/>SignIn]
        I[Service Principal<br/>SignIn]
    end

    subgraph "Log Analytics"
        J[Log Analytics<br/>Workspace]
    end

    A --> E
    B --> E
    C --> E
    D --> E

    E --> F
    E --> G
    E --> H
    E --> I

    F --> J
    G --> J
    H --> J
    I --> J

    style E fill:#ffe6cc
    style J fill:#e1f5ff
```

**Entra ID ログ収集の重要性：**

Entra ID（旧 Azure AD）のログは、**誰が**「いつ」「どこから」Azure にアクセスしたかを記録します。セキュリティ侵害の検知、不正アクセスの調査、コンプライアンス対応に不可欠です。

Entra ID（Azure Active Directory）のサインインログと監査ログを Log Analytics Workspace に送信します。ユーザーの認証履歴やディレクトリ変更を一元的に監視できます。

### 7.5.1 Entra ID 診断設定の特徴

Entra ID の診断設定は **テナントレベル** のリソースであり、通常の Bicep デプロイでは設定できません。Azure CLI の `az monitor diagnostic-settings` コマンドを使用します。

**収集されるログカテゴリ：**

- **AuditLogs**: ディレクトリの変更（ユーザー追加、グループ変更等）
- **SignInLogs**: 対話型サインイン
- **NonInteractiveUserSignInLogs**: 非対話型サインイン
- **ServicePrincipalSignInLogs**: サービスプリンシパルのサインイン
- **ManagedIdentitySignInLogs**: マネージド ID のサインイン
- **ProvisioningLogs**: プロビジョニングログ

### 7.5.2 診断設定の適用

```bash
# Entra ID の診断設定を作成（REST API経由）
az rest --method PUT \
  --uri "https://management.azure.com/providers/Microsoft.AADIAM/diagnosticSettings/entra-id-to-log-analytics?api-version=2017-04-01" \
  --body "{
    \"properties\": {
      \"workspaceId\": \"$WORKSPACE_ID\",
      \"logs\": [
        {\"category\": \"AuditLogs\", \"enabled\": true},
        {\"category\": \"SignInLogs\", \"enabled\": true},
        {\"category\": \"NonInteractiveUserSignInLogs\", \"enabled\": true},
        {\"category\": \"ServicePrincipalSignInLogs\", \"enabled\": true},
        {\"category\": \"ManagedIdentitySignInLogs\", \"enabled\": true},
        {\"category\": \"ProvisioningLogs\", \"enabled\": true},
        {\"category\": \"ADFSSignInLogs\", \"enabled\": true},
        {\"category\": \"RiskyUsers\", \"enabled\": true},
        {\"category\": \"UserRiskEvents\", \"enabled\": true},
        {\"category\": \"NetworkAccessTrafficLogs\", \"enabled\": true},
        {\"category\": \"RiskyServicePrincipals\", \"enabled\": true},
        {\"category\": \"ServicePrincipalRiskEvents\", \"enabled\": true},
        {\"category\": \"EnrichedOffice365AuditLogs\", \"enabled\": true},
        {\"category\": \"MicrosoftGraphActivityLogs\", \"enabled\": true},
        {\"category\": \"RemoteNetworkHealthLogs\", \"enabled\": true},
        {\"category\": \"NetworkAccessAlerts\", \"enabled\": true},
        {\"category\": \"NetworkAccessConnectionEvents\", \"enabled\": true},
        {\"category\": \"MicrosoftServicePrincipalSignInLogs\", \"enabled\": true},
        {\"category\": \"AzureADGraphActivityLogs\", \"enabled\": true},
        {\"category\": \"NetworkAccessGenerativeAIInsights\", \"enabled\": true}
      ]
    }
  }"

echo "✅ Entra ID のログが Log Analytics に送信されるようになりました"
```

**注意事項：**

- Entra ID P1/P2 ライセンスが必要な場合があります（SignInLogs 等）
- 診断設定の確認：Azure Portal → Entra ID → Diagnostic settings

### 7.5.3 KQL クエリ例

```kql
// 最近のサインインログ（成功のみ）
SigninLogs
| where TimeGenerated > ago(1h)
| where ResultType == 0  // 0 = 成功
| project TimeGenerated, UserPrincipalName, IPAddress, AppDisplayName, Location
| order by TimeGenerated desc

// サインイン失敗の監視
SigninLogs
| where TimeGenerated > ago(1h)
| where ResultType != 0  // 失敗
| summarize FailureCount = count() by UserPrincipalName, ResultType, ResultDescription
| order by FailureCount desc

// 監査ログ - ユーザー作成イベント
AuditLogs
| where TimeGenerated > ago(24h)
| where OperationName == "Add user"
| project TimeGenerated, Identity, TargetResources
| order by TimeGenerated desc
```

### 7.5.4 Azure Portal での確認

デプロイ後、Azure Portal で以下を確認します:

1. **Entra ID 診断設定の確認**

   - Azure Portal → Entra ID → Diagnostic settings
   - `entra-id-to-log-analytics` が存在し、有効になっていることを確認

2. **ログカテゴリの確認**

   - Diagnostic settings で AuditLogs, SignInLogs など全カテゴリが有効であることを確認

3. **Log Analytics でログ確認**
   - Azure Portal → Log Analytics workspaces → Logs
   - `SigninLogs | take 10` を実行してサインインログが収集されていることを確認

---

## 7.6 サブスクリプションのアクティビティログ収集

```mermaid
graph TB
    subgraph "Subscriptions"
        S1[Management<br/>Subscription]
        S2[Connectivity<br/>Subscription]
        S3[Sandbox<br/>Subscription]
    end

    subgraph "Activity Log"
        A1[リソース作成]
        A2[リソース削除]
        A3[RBAC変更]
        A4[Policy適用]
    end

    subgraph "診断設定"
        D[Diagnostic Settings<br/>Subscription Level]
    end

    subgraph "Log Analytics"
        LA[Log Analytics<br/>Workspace]
    end

    S1 --> A1
    S1 --> A2
    S2 --> A3
    S3 --> A4

    A1 --> D
    A2 --> D
    A3 --> D
    A4 --> D

    D --> LA

    style D fill:#ffe6cc
    style LA fill:#e1f5ff
```

**Activity Log（アクティビティログ）とは：**

Azure の**管理操作の履歴**を記録します。「誰が」「いつ」「どのリソースを作成/変更/削除したか」が記録され、セキュリティ監査やトラブルシューティングに活用できます。

作成したサブスクリプションのアクティビティログ（管理操作の履歴）を Log Analytics Workspace に送信します。

### 7.6.1 診断設定 Bicep モジュール

ファイル `infrastructure/bicep/modules/monitoring/subscription-diagnostic-settings.bicep` を作成します：

**subscription-diagnostic-settings.bicep の解説：**

サブスクリプションレベルの診断設定を作成します。`targetScope: 'subscription'` を指定することで、サブスクリプション全体のアクティビティログを Log Analytics に送信できます。

```bicep
targetScope = 'subscription'

@description('Log Analytics Workspace ID')
param workspaceId string

@description('診断設定の名前')
param diagnosticSettingName string = 'send-to-log-analytics'

// サブスクリプションの診断設定
resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagnosticSettingName
  properties: {
    workspaceId: workspaceId
    logs: [
      { category: 'Administrative', enabled: true }
      { category: 'Security', enabled: true }
      { category: 'ServiceHealth', enabled: true }
      { category: 'Alert', enabled: true }
      { category: 'Recommendation', enabled: true }
      { category: 'Policy', enabled: true }
      { category: 'Autoscale', enabled: true }
      { category: 'ResourceHealth', enabled: true }
    ]
  }
}
```

### 7.6.2 オーケストレーションへのモジュール追加

`infrastructure/bicep/orchestration/main.bicep` にサブスクリプション診断設定モジュールを追加します：

```bicep
// Chapter 7: Subscription Diagnostic Settings
module subscriptionDiagnostics '../modules/monitoring/subscription-diagnostic-settings.bicep' = {
  name: 'deploy-subscription-diagnostics'
  scope: subscription()
  params: {
    workspaceId: logAnalytics.outputs.workspaceId
    diagnosticSettingName: 'send-to-log-analytics'
  }
}
```

### 7.6.3 What-If による事前確認

```bash
# Management Subscription で実行
az account set --subscription $SUB_MANAGEMENT_ID

# 事前確認
az deployment sub what-if \
  --name "main-deployment-$(date +%Y%m%d-%H%M%S)" \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/main.bicep \
  --parameters infrastructure/bicep/orchestration/main.bicepparam
```

### 7.6.4 デプロイ実行

```bash
# デプロイ実行
az deployment sub create \
  --name "main-deployment-$(date +%Y%m%d-%H%M%S)" \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/main.bicep \
  --parameters infrastructure/bicep/orchestration/main.bicepparam

echo "✅ サブスクリプション診断設定が orchestration 経由でデプロイされました"
```

### 7.6.5 Azure Portal での確認

デプロイ後、Azure Portal で以下を確認します:

1. **サブスクリプション診断設定の確認**

   - Azure Portal → Subscriptions → Management Subscription
   - Diagnostic settings で `send-to-log-analytics` が存在することを確認

2. **ログカテゴリの確認**

   - Administrative, Security, Policy など全カテゴリが有効であることを確認

3. **Activity Log の確認**
   - Azure Portal → Monitor → Activity Log
   - 最近のサブスクリプション操作が表示されることを確認

### 7.6.6 Activity Log のクエリ例

Log Analytics で Activity Log を検索する KQL クエリ例：

```kql
// 過去24時間のすべてのActivity Log
AzureActivity
| where TimeGenerated > ago(24h)
| project TimeGenerated, Caller, OperationNameValue, ResourceGroup, Resource, ActivityStatusValue
| order by TimeGenerated desc

// リソースの作成・削除操作のみ
AzureActivity
| where OperationNameValue has_any ("Microsoft.Resources/subscriptions/resourceGroups/write",
                                     "Microsoft.Resources/subscriptions/resourceGroups/delete")
| project TimeGenerated, Caller, OperationNameValue, ResourceGroup, ActivityStatusValue
| order by TimeGenerated desc

// RBAC変更（ロール割り当て）
AzureActivity
| where OperationNameValue startswith "Microsoft.Authorization/roleAssignments/"
| project TimeGenerated, Caller, OperationNameValue, Properties
| order by TimeGenerated desc

// 失敗した操作のみ
AzureActivity
| where ActivityStatusValue == "Failed"
| project TimeGenerated, Caller, OperationNameValue, ResourceGroup, Resource, ActivitySubstatusValue
| order by TimeGenerated desc

// 特定のユーザーの操作履歴
AzureActivity
| where Caller contains "user@example.com"
| project TimeGenerated, OperationNameValue, ResourceGroup, Resource, ActivityStatusValue
| order by TimeGenerated desc

// Resource Group削除操作の詳細
AzureActivity
| where OperationNameValue == "Microsoft.Resources/subscriptions/resourceGroups/delete"
| extend DeletedResourceGroup = tostring(parse_json(Properties).resource)
| project TimeGenerated, Caller, DeletedResourceGroup, ActivityStatusValue, SubscriptionId
```

**Activity Log の活用：**

- **セキュリティ監査**: 誰が機密リソースを削除したか
- **変更追跡**: RBAC 変更の履歴
- **トラブルシューティング**: 失敗した操作の原因調査
- **コンプライアンス**: 管理操作の証跡保存

---

## 7.7 既存リソースの診断設定

すでに作成した Log Analytics Workspace と DCR に対して診断設定を適用し、これらのリソース自体の操作ログも収集します。

```mermaid
graph LR
    subgraph "監視対象リソース"
        A[Log Analytics<br/>Workspace]
        B[DCR: VM Insights]
        C[DCR: OS Logs]
    end

    subgraph "診断設定"
        D[診断設定:<br/>Audit ログ]
        E[診断設定:<br/>メトリクス]
    end

    subgraph "収集先"
        F[Log Analytics<br/>Workspace]
    end

    A -->|操作ログ| D
    B -->|変更履歴| D
    C -->|変更履歴| D

    A -->|パフォーマンス| E
    B -->|メトリクス| E
    C -->|メトリクス| E

    D --> F
    E --> F

    style F fill:#e1f5ff
```

**診断設定の重要性：**

監視基盤自体（Log Analytics や DCR）の操作ログを収集することで、「誰が」「いつ」「どのような変更を行ったか」を追跡できます。セキュリティ監査やコンプライアンス対応に不可欠です。

**今後のリソース作成における診断設定のルール：**

本章では既存の監視リソース（Log Analytics、DCR）に診断設定を適用しましたが、**今後作成するすべてのリソースにも診断設定を適用します**。

診断設定が利用可能なリソース：

- Azure Firewall
- Key Vault
- Azure Bastion
- Storage Account
- Virtual Network Gateway
- Application Gateway
- その他の Azure サービス

**実装方針：**

- リソース作成と診断設定を**同じ Bicep ファイル内**で定義
- すべてのログとメトリクスを Log Analytics Workspace に送信
- リソース作成時に診断設定も自動的にデプロイ

例：`infrastructure/bicep/modules/networking/firewall.bicep` では、Azure Firewall リソースと診断設定の両方を定義します。

---

### 7.7.1 診断設定モジュールの作成

#### Log Analytics Workspace 診断設定

ファイル `infrastructure/bicep/modules/monitoring/log-analytics-diagnostics.bicep` を作成します：

**log-analytics-diagnostics.bicep の解説：**

Log Analytics Workspace 自体の操作ログ（allLogs）とメトリクスを収集します。ワークスペースへの変更履歴を追跡できます。

```bicep
@description('Log Analytics Workspace名')
param workspaceName string

@description('診断設定の送信先 Workspace ID')
param destinationWorkspaceId string

@description('診断設定の名前')
param diagnosticSettingName string = 'send-to-log-analytics'

// 既存のLog Analytics Workspace
resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: workspaceName
}

// 診断設定
resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagnosticSettingName
  scope: workspace
  properties: {
    workspaceId: destinationWorkspaceId
    logs: [
      { categoryGroup: 'allLogs', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { categoryGroup: 'audit', enabled: false, retentionPolicy: { enabled: false, days: 0 } }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
    ]
  }
}

output diagnosticSettingId string = diagnosticSetting.id
```

#### DCR 診断設定

ファイル `infrastructure/bicep/modules/monitoring/dcr-diagnostics.bicep` を作成します：

**dcr-diagnostics.bicep の解説：**

Data Collection Rule (DCR) 自体の操作ログとメトリクスを収集します。DCR の変更や使用状況を追跡できます。

```bicep
@description('Data Collection Rule名')
param dcrName string

@description('診断設定の送信先 Workspace ID')
param destinationWorkspaceId string

@description('診断設定の名前')
param diagnosticSettingName string = 'send-to-log-analytics'

// 既存のDCR
resource dcr 'Microsoft.Insights/dataCollectionRules@2022-06-01' existing = {
  name: dcrName
}

// 診断設定
resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagnosticSettingName
  scope: dcr
  properties: {
    workspaceId: destinationWorkspaceId
    logs: [
      { categoryGroup: 'allLogs', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
    ]
  }
}

output diagnosticSettingId string = diagnosticSetting.id
```

### 7.7.2 オーケストレーションへのモジュール追加

`infrastructure/bicep/orchestration/main.bicep` に診断設定モジュールを追加します：

```bicep
// Chapter 7: Log Analytics Diagnostics
module logAnalyticsDiagnostics '../modules/monitoring/log-analytics-diagnostics.bicep' = {
  name: 'deploy-log-analytics-diagnostics'
  scope: resourceGroup(monitoring.resourceGroup.name)
  params: {
    workspaceName: monitoring.logAnalytics.workspaceName
    destinationWorkspaceId: logAnalytics.outputs.workspaceId
    diagnosticSettingName: 'send-to-log-analytics'
  }
}

// Chapter 7: DCR VM Insights Diagnostics
module dcrVmInsightsDiagnostics '../modules/monitoring/dcr-diagnostics.bicep' = {
  name: 'deploy-dcr-vm-insights-diagnostics'
  scope: resourceGroup(monitoring.resourceGroup.name)
  params: {
    dcrName: monitoring.dataCollectionRules.vmInsights.name
    destinationWorkspaceId: logAnalytics.outputs.workspaceId
    diagnosticSettingName: 'send-to-log-analytics'
  }
}

// Chapter 7: DCR OS Logs Diagnostics
module dcrOsLogsDiagnostics '../modules/monitoring/dcr-diagnostics.bicep' = {
  name: 'deploy-dcr-os-logs-diagnostics'
  scope: resourceGroup(monitoring.resourceGroup.name)
  params: {
    dcrName: monitoring.dataCollectionRules.osLogs.name
    destinationWorkspaceId: logAnalytics.outputs.workspaceId
    diagnosticSettingName: 'send-to-log-analytics'
  }
}
```

### 7.7.3 What-If による事前確認

```bash
# Management Subscription で実行
az account set --subscription $SUB_MANAGEMENT_ID

# 事前確認
az deployment sub what-if \
  --name "main-deployment-$(date +%Y%m%d-%H%M%S)" \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/main.bicep \
  --parameters infrastructure/bicep/orchestration/main.bicepparam
```

### 7.7.4 デプロイ実行

```bash
# デプロイ実行
az deployment sub create \
  --name "main-deployment-$(date +%Y%m%d-%H%M%S)" \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/main.bicep \
  --parameters infrastructure/bicep/orchestration/main.bicepparam

echo "✅ Log Analytics Workspace の診断設定が orchestration 経由でデプロイされました"
```

**今後のリソース作成ルール：**

今後、新しいリソースを作成する際は、診断設定が利用可能なリソース（Azure Firewall、Key Vault、Bastion、Storage Account 等）については、リソース作成と同じ Bicep ファイル内で診断設定も一緒に定義します。

### 7.7.5 Azure Portal での確認

デプロイ後、Azure Portal で以下を確認します:

1. **Log Analytics Workspace 診断設定の確認**

   - Azure Portal → Log Analytics workspace → Diagnostic settings
   - `send-to-log-analytics` が存在することを確認
   - allLogs が有効になっていることを確認

2. **DCR 診断設定の確認**

   - Azure Portal → Monitor → Data Collection Rules → dcr-vm-insights-prod-jpe-001
   - Diagnostic settings → `send-to-log-analytics` が存在することを確認
   - Azure Portal → Monitor → Data Collection Rules → dcr-os-logs-prod-jpe-001
   - Diagnostic settings → `send-to-log-analytics` が存在することを確認

3. **監視基盤のログ確認**
   - Log Analytics → Logs → `AzureDiagnostics | where ResourceType == "OPERATIONALINSIGHTS/WORKSPACES" or ResourceType == "MICROSOFT.INSIGHTS/DATACOLLECTIONRULES" | take 20`
   - 監視リソース自体のログが収集されていることを確認

### 7.7.6 診断設定ログのクエリ例

今後作成する Azure Firewall などのリソースの診断設定ログを検索する KQL クエリ例：

```kql
// Azure Firewall - すべてのログ（第13章で作成後に使用可能）
AzureDiagnostics
| where ResourceType == "AZUREFIREWALLS"
| project TimeGenerated, Category, msg_s, Resource
| order by TimeGenerated desc

// Azure Firewall - 許可されたアプリケーションルール
AzureDiagnostics
| where ResourceType == "AZUREFIREWALLS"
| where Category == "AzureFirewallApplicationRule"
| where msg_s contains "Allow"
| project TimeGenerated, msg_s
| order by TimeGenerated desc

// Azure Firewall - ブロックされたネットワークトラフィック
AzureDiagnostics
| where ResourceType == "AZUREFIREWALLS"
| where Category == "AzureFirewallNetworkRule"
| where msg_s contains "Deny"
| extend SourceIP = extract(@"Source: ([0-9\.]+)", 1, msg_s)
| extend DestinationIP = extract(@"Destination: ([0-9\.]+)", 1, msg_s)
| extend DestinationPort = extract(@"DestPort: ([0-9]+)", 1, msg_s)
| project TimeGenerated, SourceIP, DestinationIP, DestinationPort, msg_s
| order by TimeGenerated desc

// Azure Firewall - 脅威インテリジェンスアラート
AzureDiagnostics
| where ResourceType == "AZUREFIREWALLS"
| where Category == "AzureFirewallThreatIntelLog"
| project TimeGenerated, msg_s, Resource
| order by TimeGenerated desc

// Key Vault - シークレットアクセス（第12章で作成後に使用可能）
AzureDiagnostics
| where ResourceType == "VAULTS"
| where OperationName == "SecretGet"
| project TimeGenerated, CallerIPAddress, identity_claim_http_schemas_xmlsoap_org_ws_2005_05_identity_claims_upn_s,
          Resource, ResultSignature
| order by TimeGenerated desc

// Key Vault - 失敗したアクセス試行
AzureDiagnostics
| where ResourceType == "VAULTS"
| where ResultSignature != "OK"
| project TimeGenerated, CallerIPAddress, OperationName, ResultSignature, Resource
| order by TimeGenerated desc

// すべてのリソースの診断設定概要
AzureDiagnostics
| summarize count() by ResourceType, Category
| order by count_ desc
```

**診断設定ログの活用シーン：**

- **セキュリティ分析**: Firewall でブロックされた不審なトラフィック
- **コンプライアンス**: Key Vault のシークレットアクセス履歴
- **トラブルシューティング**: 接続失敗の原因調査
- **キャパシティプランニング**: リソース使用状況の傾向分析

**注意：** 上記の Azure Firewall と Key Vault のクエリは、それぞれ第 13 章（Networking Hub）と第 12 章（Security）でリソース作成後に実行可能になります。

---

## 7.8 Azure Policy 用ユーザー割り当てマネージド ID

Azure Policy の DeployIfNotExists や Modify 効果を使用する際、ポリシーが自動的にリソースを作成・変更するためには、適切な権限を持つマネージド ID が必要です。

```mermaid
graph TB
    subgraph "Management Subscription"
        MI[マネージドID:<br/>id-policy-assignment]
    end

    subgraph "Azure Policy"
        P1[Policy: Defender<br/>for Cloud]
        P2[Policy: Diagnostic<br/>Settings]
    end

    subgraph "Target Subscriptions"
        SUB1[Connectivity<br/>Subscription]
        SUB2[Sandbox<br/>Subscription]
        SUB3[Application<br/>Subscription]
    end

    P1 -->|DeployIfNotExists| MI
    P2 -->|Modify| MI

    MI -->|Owner権限で<br/>リソース作成/変更| SUB1
    MI -->|Owner権限で<br/>リソース作成/変更| SUB2
    MI -->|Owner権限で<br/>リソース作成/変更| SUB3

    style MI fill:#ffe6cc
    style SUB1 fill:#e1f5ff
    style SUB2 fill:#e1f5ff
    style SUB3 fill:#e1f5ff
```

CAF のベストプラクティスに従い、ポリシー実行用のマネージド ID は **Management Subscription** に配置します。これにより、複数のサブスクリプションにまたがるポリシー割り当てを一元管理できます。

```bash
# ディレクトリ作成
mkdir -p infrastructure/bicep/modules/identity
```

### 7.8.1 マネージド ID Bicep モジュール

ファイル `infrastructure/bicep/modules/identity/managed-identity.bicep` を作成します：

```bicep
@description('マネージドIDの名前')
param identityName string

@description('デプロイ先のリージョン')
param location string

@description('タグ')
param tags object = {}

// ユーザー割り当てマネージドID
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: tags
}

output identityId string = managedIdentity.id
output principalId string = managedIdentity.properties.principalId
output clientId string = managedIdentity.properties.clientId
```

### 7.8.2 オーケストレーションへのモジュール追加

`infrastructure/bicep/orchestration/main.bicep` にマネージド ID モジュールを追加します：

```bicep
// Chapter 7: Policy Managed Identity
module policyIdentity '../modules/identity/managed-identity.bicep' = {
  name: 'deploy-policy-identity'
  scope: resourceGroup(monitoring.resourceGroup.name)
  params: {
    identityName: 'id-policy-assignment-prod-jpe-001'
    location: location
    tags: union(tags, {
      Purpose: 'Policy Assignment'
    })
  }
}

// Chapter 7: Policy Identity Outputs
output policyIdentityId string = policyIdentity.outputs.identityId
output policyIdentityPrincipalId string = policyIdentity.outputs.principalId
```

### 7.8.3 What-If による事前確認

```bash
# 事前確認
az deployment sub what-if \
  --name "main-deployment-$(date +%Y%m%d-%H%M%S)" \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/main.bicep \
  --parameters infrastructure/bicep/orchestration/main.bicepparam
```

### 7.8.4 デプロイ実行

```bash
# Management Subscription で実行
az account set --subscription $SUB_MANAGEMENT_ID

# デプロイ実行
DEPLOYMENT_NAME="main-deployment-$(date +%Y%m%d-%H%M%S)"
az deployment sub create \
  --name $DEPLOYMENT_NAME \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/main.bicep \
  --parameters infrastructure/bicep/orchestration/main.bicepparam

# デプロイ結果から出力を取得して表示
echo "=== デプロイ出力を取得中 ==="
DEPLOYMENT_OUTPUT=$(az deployment sub show \
  --name $DEPLOYMENT_NAME \
  --query 'properties.outputs' -o json)

echo "出力内容: $DEPLOYMENT_OUTPUT"

# 環境変数に保存
POLICY_IDENTITY_ID=$(echo $DEPLOYMENT_OUTPUT | jq -r '.policyIdentityId.value')
POLICY_IDENTITY_PRINCIPAL_ID=$(echo $DEPLOYMENT_OUTPUT | jq -r '.policyIdentityPrincipalId.value')

# .envファイルに保存（重複防止）
grep -q "POLICY_IDENTITY_ID=" .env || echo "POLICY_IDENTITY_ID=$POLICY_IDENTITY_ID" >> .env
grep -q "POLICY_IDENTITY_PRINCIPAL_ID=" .env || echo "POLICY_IDENTITY_PRINCIPAL_ID=$POLICY_IDENTITY_PRINCIPAL_ID" >> .env

echo "Policy用マネージドID: $POLICY_IDENTITY_ID"
echo "Principal ID: $POLICY_IDENTITY_PRINCIPAL_ID"
```

### 7.8.5 マネージド ID への権限付与

Azure Policy の DeployIfNotExists/Modify 効果（特に Defender for Cloud の適用）には **Owner** 権限が必要です。**中間ルート管理グループ** (contoso) に対して Owner ロールを付与します。これにより、その下位のすべての管理グループとサブスクリプションに対してポリシーを実行できます。

ファイル `infrastructure/bicep/modules/identity/role-assignment-owner.bicep` を作成します：

```bicep
targetScope = 'managementGroup'

@description('マネージドIDのPrincipal ID')
param principalId string

@description('ロール定義ID（Owner）')
param roleDefinitionId string = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' // Owner

// Owner権限の付与
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(managementGroup().id, principalId, roleDefinitionId)
  properties: {
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = roleAssignment.id
```

#### tenant.bicep へのロール割り当て追加

ロール割り当ては管理グループスコープで行うため、`tenant.bicep` から呼び出します。

ファイル `infrastructure/bicep/orchestration/tenant.bicep` に以下を追記：

```bicep
// =============================================================================
// Chapter 7: Policy Identity (追記)
// =============================================================================

@description('Policy Identity Principal ID')
param policyIdentityPrincipalId string = ''

// =============================================================================
// Chapter 7: Role Assignment (追記)
// =============================================================================

// Policy Identity Owner Role Assignment (中間ルート管理グループに割り当て)
module policyIdentityOwnerRole '../modules/identity/role-assignment-owner.bicep' = if (!empty(policyIdentityPrincipalId)) {
  name: 'deploy-policy-identity-owner'
  scope: managementGroup(companyPrefix)
  params: {
    principalId: policyIdentityPrincipalId
  }
}

output policyIdentityRoleAssignmentId string = policyIdentityOwnerRole.?outputs.?roleAssignmentId ?? ''
```

ファイル `infrastructure/bicep/orchestration/tenant.bicepparam` に以下を追記：

```bicep
// =============================================================================
// Chapter 7: Policy Identity Principal ID
// =============================================================================

// 7.8.4で.envに保存した値を以下に設定：
// source .env && echo $POLICY_IDENTITY_PRINCIPAL_ID
param policyIdentityPrincipalId = 'YOUR_POLICY_IDENTITY_PRINCIPAL_ID_HERE'
```

#### デプロイ手順

7.8.4 で.env に保存した値を確認して、tenant.bicepparam に設定します：

```bash
# .envを読み込み
source .env

# Principal IDを確認（この値をtenant.bicepparamに設定）
echo $POLICY_IDENTITY_PRINCIPAL_ID
```

上記コマンドで出力された値を`tenant.bicepparam`の`policyIdentityPrincipalId`に設定してください。

What-If で事前確認：

```bash
# What-If実行
az deployment tenant what-if \
  --name "tenant-deployment-$(date +%Y%m%d-%H%M%S)" \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/tenant.bicep \
  --parameters infrastructure/bicep/orchestration/tenant.bicepparam
```

デプロイ実行：

```bash
# デプロイ実行
az deployment tenant create \
  --name "tenant-deployment-$(date +%Y%m%d-%H%M%S)" \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/tenant.bicep \
  --parameters infrastructure/bicep/orchestration/tenant.bicepparam

echo "✅ マネージドIDにOwner権限を付与しました"
```

### 7.8.6 Azure Portal での確認

デプロイ後、Azure Portal で以下を確認します:

1. **マネージド ID の確認**

   - Azure Portal → Resource groups → rg-platform-management-prod-jpe-001
   - `id-policy-assignment-prod-jpe-001` が存在することを確認

2. **Principal ID の確認**

   - Managed Identity を開く → Properties → Object (principal) ID をコピー
   - `.env` ファイルの `POLICY_IDENTITY_PRINCIPAL_ID` と一致することを確認

3. **ロール割り当ての確認**
   - Subscriptions → Management Subscription → Access control (IAM) → Role assignments
   - マネージド ID に Owner ロールが付与されていることを確認

---

## 7.9 Key Vault の構築

### 7.9.1 Key Vault とは

**Azure Key Vault** は、シークレット、暗号化キー、証明書を安全に保管・管理するサービスです。Automation の GitHub Personal Access Token を Key Vault に保管します。

**CAF ベストプラクティス**: 機密情報は Key Vault で一元管理し、アプリケーションやサービスから安全にアクセスします。

#### Key Vault Bicep モジュールの作成

```bash
mkdir -p infrastructure/bicep/modules/security
```

ファイル `infrastructure/bicep/modules/security/key-vault.bicep` を作成：

```bicep
targetScope = 'resourceGroup'

@description('Key Vaultの名前（グローバルで一意）')
@minLength(3)
@maxLength(24)
param keyVaultName string

@description('デプロイ先のリージョン')
param location string

@description('テナントID')
param tenantId string = subscription().tenantId

@description('Soft Delete保持期間（日数）')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90

@description('タグ')
param tags object = {}

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: true
    enableRbacAuthorization: true  // RBAC使用
    publicNetworkAccess: 'Enabled'
  }
}

// 出力
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
```

### 7.9.2 Key Vault ロール割り当てモジュールの作成

**CAF ベストプラクティス**: リソース定義とロール割り当ては分離して管理します。これにより、再利用性が向上し、権限管理が明確になります。

ファイル `infrastructure/bicep/modules/security/key-vault-role-assignment.bicep` を作成：

```bicep
targetScope = 'resourceGroup'

@description('Key VaultのリソースID')
param keyVaultId string

@description('ロールを割り当てるプリンシパルのオブジェクトID')
param principalId string

@description('プリンシパルのタイプ')
@allowed([
  'User'
  'ServicePrincipal'
  'Group'
])
param principalType string = 'User'

@description('ロール定義ID（Key Vault Secrets Officer）')
param roleDefinitionId string = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'

// 既存のKey Vaultを参照
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: split(keyVaultId, '/')[8]
}

// Key Vault Secrets Officer ロールの割り当て
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, principalId, roleDefinitionId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: principalType
  }
}

// 出力
output roleAssignmentId string = roleAssignment.id
```

### 7.9.3 パラメータファイルの設定

#### 自分のオブジェクト ID を取得

```bash
# 自分のオブジェクトIDを取得
MY_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
echo "My Object ID: $MY_OBJECT_ID"
```

#### main.bicepparam の編集

`infrastructure/bicep/orchestration/main.bicepparam` を開き、`monitoring` セクションに以下を追加：

```bicep
param monitoring = {
  resourceGroup: {
    name: 'rg-platform-management-prod-jpe-001'
    tags: {
      Environment: 'Production'
      ManagedBy: 'Bicep'
      Component: 'Monitoring'
    }
  }
  logAnalytics: {
    // ... 既存のLog Analytics設定 ...
  }
  // 👇 Key Vault設定を追加
  keyVault: {
    name: 'kv-mgmt-prod-jpe-001'  // ⚠️ グローバルで一意な名前に変更
    administratorObjectId: 'YOUR_OBJECT_ID'  // 👆上記で取得したオブジェクトIDに置き換え
    softDeleteRetentionInDays: 90
  }
}
```

**⚠️ 重要**:

- Key Vault 名はグローバルで一意である必要があります
- `administratorObjectId` には必ず自分のオブジェクト ID を設定してください

### 7.9.4 オーケストレーションファイルの編集

#### Key Vault モジュールの追加

`infrastructure/bicep/orchestration/main.bicep` を開き、以下を追加：

```bicep
// Chapter 7: Key Vault
module keyVault '../modules/security/key-vault.bicep' = {
  name: 'deploy-key-vault'
  scope: resourceGroup(monitoring.resourceGroup.name)
  params: {
    keyVaultName: monitoring.keyVault.name
    location: location
    softDeleteRetentionInDays: monitoring.keyVault.softDeleteRetentionInDays
    tags: union(tags, {
      Purpose: 'Secrets Management'
    })
  }
}
```

#### ロール割り当てモジュールの追加

同じファイルに続けて、ロール割り当てモジュールを追加：

```bicep
// Chapter 7: Key Vault Role Assignment
module keyVaultRoleAssignment '../modules/security/key-vault-role-assignment.bicep' = {
  name: 'deploy-key-vault-role-assignment'
  scope: resourceGroup(monitoring.resourceGroup.name)
  params: {
    keyVaultId: keyVault.outputs.keyVaultId
    principalId: monitoring.keyVault.administratorObjectId
    principalType: 'User'
  }
}
```

**ポイント**: `keyVault.outputs.keyVaultId` を参照しているため、暗黙的な依存関係により Key Vault が先にデプロイされます。

同じファイルに続けて、出力を追加：

```bicep
// Chapter 7: Key Vault Outputs
output keyVaultId string = keyVault.outputs.keyVaultId
output keyVaultName string = keyVault.outputs.keyVaultName
```

### 7.9.5 What-If による事前確認

```bash
# Management Subscription に切り替え
az account set --subscription $SUB_MANAGEMENT_ID

# What-If で事前確認
az deployment sub what-if \
  --name "main-deployment-$(date +%Y%m%d-%H%M%S)" \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/main.bicep \
  --parameters infrastructure/bicep/orchestration/main.bicepparam
```

### 7.9.6 デプロイ実行

```bash
# デプロイ実行
DEPLOYMENT_NAME="main-deployment-$(date +%Y%m%d-%H%M%S)"

az deployment sub create \
  --name "$DEPLOYMENT_NAME" \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/main.bicep \
  --parameters infrastructure/bicep/orchestration/main.bicepparam

echo "✅ Key Vaultをデプロイしました"

# Key Vault名を取得
KEY_VAULT_NAME=$(az deployment sub show \
  --name "$DEPLOYMENT_NAME" \
  --query 'properties.outputs.keyVaultName.value' \
  --output tsv)

echo "Key Vault Name: $KEY_VAULT_NAME"
```

**デプロイされるリソース**:

- Key Vault（RBAC 認証、Soft Delete、Purge Protection 有効）
- Key Vault Secrets Officer ロール割り当て（自分のユーザーに付与）

**権限の説明**:

- **Key Vault Secrets Officer**: シークレットの読み書きが可能
- Automation Account には後でシークレット読み取り権限を付与

---

## 7.10 Azure Automation の構築

```mermaid
graph LR
    subgraph "スケジュール"
        S[毎日 20:00<br/>JST]
    end

    subgraph "Automation Account"
        R[Runbook:<br/>Stop-SandboxVMs]
        MI[System-assigned<br/>Managed Identity]
    end

    subgraph "Sandbox Subscription"
        VM1[VM: sandbox-vm-001]
        VM2[VM: sandbox-vm-002]
        VM3[VM: sandbox-vm-003]
    end

    S -->|トリガー| R
    R -->|認証| MI
    MI -->|Contributor権限| VM1
    MI -->|Contributor権限| VM2
    MI -->|Contributor権限| VM3

    VM1 -->|シャットダウン| D[Deallocated]
    VM2 -->|シャットダウン| D
    VM3 -->|シャットダウン| D

    style R fill:#ffe6cc
    style D fill:#ffcccc
```

### 7.10.1 Azure Automation とは

**Azure Automation** は、定期的なタスクを自動化するサービスです。本章では、コスト最適化のために **Sandbox Subscription のすべての VM を毎晩 20:00 に自動停止** する仕組みを構築します。

**シナリオ：**

- 開発・テスト用の Sandbox 環境では、VM を夜間に稼働させる必要がない
- 毎日夜 8 時に自動停止することで、約 50% のコスト削減が可能
- 翌朝、必要に応じて手動で起動する運用

**主な機能：**

- **Runbook**: PowerShell スクリプトで VM 停止処理を実装
- **Schedule**: 毎日 20:00 (JST) に自動実行
- **Managed Identity**: Sandbox Subscription への権限付与

### 7.10.2 Automation Account モジュールの作成

Automation Account を Management Subscription に作成します。集中管理の観点から、監視・運用ツールは Management Subscription に配置します。

```bash
mkdir -p infrastructure/bicep/modules/automation
```

ファイル `infrastructure/bicep/modules/automation/automation-account.bicep` を作成します：

```bicep
@description('Automation Accountの名前')
param automationAccountName string

@description('デプロイ先のリージョン')
param location string

@description('タグ')
param tags object = {}

// Automation Account
resource automationAccount 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: automationAccountName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Basic'
    }
    encryption: {
      keySource: 'Microsoft.Automation'
    }
    publicNetworkAccess: true
  }
}

// 出力
output automationAccountId string = automationAccount.id
output automationAccountName string = automationAccount.name
output principalId string = automationAccount.identity.principalId
```

### 7.10.3 オーケストレーションへのモジュール追加

`infrastructure/bicep/orchestration/main.bicep` に Automation Account モジュールを追加します：

```bicep
// Chapter 7: Automation Account
module automationAccount '../modules/automation/automation-account.bicep' = {
  name: 'deploy-automation-account'
  scope: resourceGroup(monitoring.resourceGroup.name)
  params: {
    automationAccountName: 'aa-platform-prod-jpe-001'
    location: location
    tags: union(tags, {
      Purpose: 'Automation and Runbooks'
    })
  }
}

// Chapter 7: Automation Account Outputs
output automationAccountId string = automationAccount.outputs.automationAccountId
output automationPrincipalId string = automationAccount.outputs.principalId
```

### 7.10.4 What-If による事前確認

```bash
# Management Subscription にデプロイ
az account set --subscription $SUB_MANAGEMENT_ID

# 事前確認
az deployment sub what-if \
  --name "main-deployment-$(date +%Y%m%d-%H%M%S)" \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/main.bicep \
  --parameters infrastructure/bicep/orchestration/main.bicepparam
```

### 7.10.5 デプロイ実行

```bash
# Management Subscription で実行
az account set --subscription $SUB_MANAGEMENT_ID

# デプロイ実行
DEPLOYMENT_NAME="main-deployment-$(date +%Y%m%d-%H%M%S)"
az deployment sub create \
  --name $DEPLOYMENT_NAME \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/main.bicep \
  --parameters infrastructure/bicep/orchestration/main.bicepparam

# デプロイ結果から出力を取得
echo "=== デプロイ出力を取得中 ==="
DEPLOYMENT_OUTPUT=$(az deployment sub show \
  --name $DEPLOYMENT_NAME \
  --query 'properties.outputs' -o json)

# Principal ID を環境変数に保存（重複防止）
AUTOMATION_PRINCIPAL_ID=$(echo $DEPLOYMENT_OUTPUT | jq -r '.automationPrincipalId.value')
grep -q "AUTOMATION_PRINCIPAL_ID=" .env || echo "AUTOMATION_PRINCIPAL_ID=$AUTOMATION_PRINCIPAL_ID" >> .env
echo "Automation Account Principal ID: $AUTOMATION_PRINCIPAL_ID"
```

### 7.10.5 デプロイ実行

### 7.10.6 Sandbox 管理グループへの権限付与

Automation Account の Managed Identity に対して、**Sandbox 管理グループ**に **Virtual Machine Contributor** 権限を付与します。これにより、Runbook が Sandbox 配下のすべての VM を停止できるようになります。

#### role-assignment-vm-contributor モジュールの作成

ファイル `infrastructure/bicep/modules/identity/role-assignment-vm-contributor.bicep` を作成：

```bicep
targetScope = 'managementGroup'

@description('マネージドIDのPrincipal ID')
param principalId string

@description('ロール定義ID（Virtual Machine Contributor）')
param roleDefinitionId string = '9980e02c-c2be-4d73-94e8-173b1dc7cf3c' // Virtual Machine Contributor

// Virtual Machine Contributor権限の付与
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(managementGroup().id, principalId, roleDefinitionId)
  properties: {
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = roleAssignment.id
```

#### tenant.bicep へのロール割り当て追加

ファイル `infrastructure/bicep/orchestration/tenant.bicep` に以下を追記：

```bicep
// =============================================================================
// Chapter 7: Automation Identity (追記)
// =============================================================================

@description('Automation Account Principal ID')
param automationPrincipalId string = ''

// Automation Account VM Contributor Role Assignment (Sandbox管理グループに割り当て)
module automationVMContributorRole '../modules/identity/role-assignment-vm-contributor.bicep' = if (!empty(automationPrincipalId)) {
  name: 'deploy-automation-vm-contributor'
  scope: managementGroup('${companyPrefix}-sandbox')
  params: {
    principalId: automationPrincipalId
  }
}

output automationRoleAssignmentId string = automationVMContributorRole.?outputs.?roleAssignmentId ?? ''
```

ファイル `infrastructure/bicep/orchestration/tenant.bicepparam` に以下を追記：

```bicep
// =============================================================================
// Chapter 7: Automation Account Principal ID
// =============================================================================

// 7.9.5で.envに保存した値を以下に設定：
// source .env && echo $AUTOMATION_PRINCIPAL_ID
param automationPrincipalId = 'YOUR_AUTOMATION_PRINCIPAL_ID_HERE'
```

#### デプロイ手順

7.9.5 で.env に保存した値を確認して、tenant.bicepparam に設定します：

```bash
# .envを読み込み
source .env

# Principal IDを確認（この値をtenant.bicepparamに設定）
echo $AUTOMATION_PRINCIPAL_ID
```

上記コマンドで出力された値を`tenant.bicepparam`の`automationPrincipalId`に設定してください。

What-If で事前確認：

```bash
# What-If実行
az deployment tenant what-if \
  --name "tenant-deployment-$(date +%Y%m%d-%H%M%S)" \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/tenant.bicep \
  --parameters infrastructure/bicep/orchestration/tenant.bicepparam
```

デプロイ実行：

```bash
# デプロイ実行
az deployment tenant create \
  --name "tenant-deployment-$(date +%Y%m%d-%H%M%S)" \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/tenant.bicep \
  --parameters infrastructure/bicep/orchestration/tenant.bicepparam

echo "✅ Automation AccountにSandbox管理グループのVirtual Machine Contributor権限を付与しました"
```

**権限の範囲：**

- **Virtual Machine Contributor**: VM の起動・停止のみ可能（最小権限）
- **Scope**: Sandbox 管理グループ（配下の全サブスクリプションに適用）
- **用途**: 夜間の自動シャットダウン

### 7.10.7 Runbook モジュールの作成

Runbook リソースを Bicep で管理します。スクリプト内容は GitHub で管理し、Source Control 統合で自動同期します。

**CAF ベストプラクティス**: Runbook リソース（インフラ）は Bicep で管理し、スクリプト内容（コード）は GitHub で管理することで、完全な Infrastructure as Code を実現します。

まず、Runbook の PowerShell スクリプトを GitHub リポジトリに配置します：

```bash
mkdir -p infrastructure/automation/runbooks
```

ファイル `infrastructure/automation/runbooks/Stop-SandboxVMs.ps1` を作成：

```powershell
<#
.SYNOPSIS
    Sandbox Subscription のすべての VM を停止します

.DESCRIPTION
    コスト最適化のため、毎晩 20:00 に Sandbox 環境のすべての VM を自動停止します。
    VM は翌朝、必要に応じて手動で起動します。

.NOTES
    実行には Sandbox Subscription の Contributor 権限が必要です
    System-assigned Managed Identity を使用して認証します
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = $env:SANDBOX_SUBSCRIPTION_ID
)

# エラーハンドリング
$ErrorActionPreference = "Stop"

try {
    Write-Output "========================================="
    Write-Output "Sandbox VM 自動停止スクリプト開始"
    Write-Output "実行時刻: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output "========================================="

    # Azure 接続（Managed Identity を使用）
    Write-Output "Azure に接続中..."
    Connect-AzAccount -Identity | Out-Null
    Write-Output "✓ Azure 接続成功"

    # Sandbox Subscription に切り替え
    if ($SubscriptionId) {
        Write-Output "Sandbox Subscription に切り替え中: $SubscriptionId"
        Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
        Write-Output "✓ Subscription 切り替え成功"
    }

    # 現在実行中の VM を取得
    Write-Output "`nSandbox Subscription の実行中 VM を検索中..."
    $runningVMs = Get-AzVM -Status | Where-Object {
        $_.PowerState -eq "VM running"
    }

    if ($runningVMs.Count -eq 0) {
        Write-Output "✓ 実行中の VM は見つかりませんでした"
        Write-Output "========================================="
        Write-Output "処理完了"
        Write-Output "========================================="
        exit 0
    }

    Write-Output "✓ 実行中の VM を $($runningVMs.Count) 台発見しました"
    Write-Output ""

    # 各 VM を停止
    $stoppedCount = 0
    $failedCount = 0

    foreach ($vm in $runningVMs) {
        try {
            Write-Output "VM 停止中: $($vm.Name) (Resource Group: $($vm.ResourceGroupName))"

            Stop-AzVM `
                -ResourceGroupName $vm.ResourceGroupName `
                -Name $vm.Name `
                -Force `
                -NoWait | Out-Null

            Write-Output "  ✓ 停止要求送信完了: $($vm.Name)"
            $stoppedCount++
        }
        catch {
            Write-Output "  ✗ エラー: $($vm.Name) - $($_.Exception.Message)"
            $failedCount++
        }
    }

    Write-Output ""
    Write-Output "========================================="
    Write-Output "処理完了"
    Write-Output "  停止要求送信: $stoppedCount 台"
    Write-Output "  エラー: $failedCount 台"
    Write-Output "  推定コスト削減: 約 $(($stoppedCount * 12) * 0.5) 時間分の VM コスト"
    Write-Output "========================================="
}
catch {
    Write-Error "スクリプト実行エラー: $($_.Exception.Message)"
    throw
}
```

スクリプトをコミット：

```bash
git add infrastructure/automation/runbooks/Stop-SandboxVMs.ps1
git commit -m "追加: Sandbox VM自動停止Runbook"
git push
```

次に、Runbook リソースの Bicep モジュールを作成します。

ファイル `infrastructure/bicep/modules/automation/runbook.bicep` を作成：

```bicep
@description('Automation Account名')
param automationAccountName string

@description('Runbook名')
param runbookName string

@description('Runbookの説明')
param description string = ''

@description('Runbookのタイプ')
@allowed([
  'PowerShell'
  'PowerShell72'
  'Python3'
])
param runbookType string = 'PowerShell72'

@description('デプロイ先のリージョン')
param location string

@description('タグ')
param tags object = {}

// Runbook リソース
resource automationAccount 'Microsoft.Automation/automationAccounts@2023-11-01' existing = {
  name: automationAccountName
}

resource runbook 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = {
  parent: automationAccount
  name: runbookName
  location: location
  tags: tags
  properties: {
    runbookType: runbookType
    logProgress: true
    logVerbose: false
    description: description
    publishContentLink: {
      uri: 'https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/quickstarts/microsoft.automation/101-automation/scripts/AzureAutomationTutorial.ps1'
      version: '1.0.0.0'
    }
  }
}

// 出力
output runbookName string = runbook.name
output runbookId string = runbook.id
```

**注意**: `publishContentLink` はダミーの URL です。実際の Runbook スクリプトは Source Control 統合で GitHub から自動同期されます。

### 7.10.8 Source Control モジュールの作成

**CAF ベストプラクティス**: Source Control 統合も Bicep で管理することで、GitHub 連携設定を Infrastructure as Code として管理できます。

ファイル `infrastructure/bicep/modules/automation/source-control.bicep` を作成：

```bicep
@description('Automation Account名')
param automationAccountName string

@description('Source Control名')
param sourceControlName string

@description('GitHubリポジトリURL')
param repositoryUrl string

@description('ブランチ名')
param branch string = 'main'

@description('Runbookフォルダパス')
param folderPath string = '/infrastructure/automation/runbooks'

@description('自動同期を有効化')
param autoSync bool = true

@description('同期時に自動公開')
param publishRunbook bool = true

@description('説明')
param description string = 'GitHub Source Control Integration'

// Source Control 統合
resource automationAccount 'Microsoft.Automation/automationAccounts@2023-11-01' existing = {
  name: automationAccountName
}

resource sourceControl 'Microsoft.Automation/automationAccounts/sourceControls@2023-11-01' = {
  parent: automationAccount
  name: sourceControlName
  properties: {
    repoUrl: repositoryUrl
    branch: branch
    folderPath: folderPath
    autoSync: autoSync
    publishRunbook: publishRunbook
    sourceType: 'GitHub'
    description: description
  }
}

// 出力
output sourceControlName string = sourceControl.name
output sourceControlId string = sourceControl.id
```

**注意**: Source Control には GitHub Personal Access Token が必要ですが、Bicep では機密情報として設定できないため、デプロイ後に AZ CLI で設定します。

### 7.10.9 オーケストレーションへの統合

`infrastructure/bicep/orchestration/main.bicep` の Automation Account セクションを更新します：

```bicep
// Chapter 7: Automation Account
module automationAccount '../modules/automation/automation-account.bicep' = {
  name: 'deploy-automation-account'
  scope: resourceGroup(monitoring.resourceGroup.name)
  params: {
    automationAccountName: 'aa-platform-prod-jpe-001'
    location: location
    tags: union(tags, {
      Purpose: 'Automation and Runbooks'
    })
  }
}

// Chapter 7: Runbook
module runbook '../modules/automation/runbook.bicep' = {
  name: 'deploy-runbook-stop-sandbox-vms'
  scope: resourceGroup(monitoring.resourceGroup.name)
  params: {
    automationAccountName: automationAccount.outputs.automationAccountName
    runbookName: 'Stop-SandboxVMs'
    description: 'Sandbox Subscriptionのすべての VM を停止します'
    runbookType: 'PowerShell72'
    location: location
    tags: tags
  }
  dependsOn: [
    automationAccount
  ]
}

// Chapter 7: Source Control Integration
module sourceControl '../modules/automation/source-control.bicep' = {
  name: 'deploy-source-control-github'
  scope: resourceGroup(monitoring.resourceGroup.name)
  params: {
    automationAccountName: automationAccount.outputs.automationAccountName
    sourceControlName: 'GitHubRunbooks'
    repositoryUrl: 'https://github.com/<YOUR_GITHUB_USERNAME>/azure_caf_handson.git'
    branch: 'main'
    folderPath: '/infrastructure/automation/runbooks'
    autoSync: true
    publishRunbook: true
    description: 'Runbook source control integration with GitHub'
  }
  dependsOn: [
    runbook
  ]
}

// Chapter 7: Automation Account Outputs
output automationAccountId string = automationAccount.outputs.automationAccountId
output automationPrincipalId string = automationAccount.outputs.principalId
output runbookName string = runbook.outputs.runbookName
```

**重要**: `repositoryUrl` を各自の GitHub リポジトリ URL に変更してください。

`infrastructure/bicep/orchestration/tenant.bicepparam` に Runbook 関連のパラメータを追加します（既に追加済みの場合はスキップ）：

```bicep
// Chapter 7: Automation Identity Principal ID
param automationPrincipalId = '' // デプロイ後に設定
```

### 7.10.10 GitHub Personal Access Token の Key Vault 保管

**CAF ベストプラクティス**: GitHub Personal Access Token のような機密情報は Key Vault に保管し、Automation Account から安全にアクセスします。

#### Personal Access Token の生成

1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token (classic)
3. Note: "Azure Automation Runbook Integration"
4. Expiration: 90 days（推奨）
5. Scopes: `repo` (Full control of private repositories) を選択
6. Generate token をクリックしてトークンをコピー

#### Key Vault へのシークレット保存

```bash
# トークンを入力（画面に表示されません）
read -sp "GitHub Personal Access Token: " GITHUB_TOKEN
echo

# Key Vaultにシークレットとして保存
az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name "github-pat" \
  --value "$GITHUB_TOKEN"

echo "✅ GitHub Personal Access TokenをKey Vaultに保存しました"
```

#### Key Vault からトークンを取得して Source Control に設定

```bash
# Key Vaultからトークンを取得
GITHUB_TOKEN=$(az keyvault secret show \
  --vault-name $KEY_VAULT_NAME \
  --name "github-pat" \
  --query 'value' \
  --output tsv)

# Source Control にトークンを設定
az automation source-control update \
  --resource-group rg-platform-management-prod-jpe-001 \
  --automation-account-name aa-platform-prod-jpe-001 \
  --name "GitHubRunbooks" \
  --access-token $GITHUB_TOKEN

echo "✅ Source ControlにGitHub認証を設定しました"
```

#### 初回同期の実行

```bash
# 手動で同期を実行（GitHub から Runbook を取得）
az automation source-control sync-job create \
  --resource-group rg-platform-management-prod-jpe-001 \
  --automation-account-name aa-platform-prod-jpe-001 \
  --source-control-name "GitHubRunbooks"

echo "✅ GitHubからRunbookを同期しました"
```

**動作確認**：

1. Azure Portal → Automation Account → Runbooks
2. `Stop-SandboxVMs` が表示されていることを確認
3. 内容が GitHub のスクリプトと一致していることを確認

以降、GitHub リポジトリの Runbook を更新すると、自動的に Azure Automation に同期されます。

**セキュリティのポイント**：

- GitHub Personal Access Token は Key Vault で安全に管理
- Automation Account は Managed Identity で Key Vault にアクセス
- トークンは環境変数から即座に削除（unset）

### 7.10.11 スケジュールの作成

毎日夜 8 時（20:00 JST）に Runbook を実行するスケジュールを作成します。

```bash
# Management Subscription で実行
az account set --subscription $SUB_MANAGEMENT_ID

# 毎日 20:00 のスケジュールを作成
az automation schedule create \
  --resource-group rg-platform-management-prod-jpe-001 \
  --automation-account-name aa-platform-prod-jpe-001 \
  --name "Daily-Evening-Shutdown" \
  --frequency "Day" \
  --interval 1 \
  --start-time "2026-01-09T20:00:00+09:00" \
  --time-zone "Tokyo Standard Time" \
  --description "Sandbox VM を毎晩 20:00 に自動停止"

# Runbook とスケジュールをリンク
az automation job-schedule create \
  --resource-group rg-platform-management-prod-jpe-001 \
  --automation-account-name aa-platform-prod-jpe-001 \
  --runbook-name "Stop-SandboxVMs" \
  --schedule-name "Daily-Evening-Shutdown" \
  --parameters "{\"SubscriptionId\":\"$SUB_SANDBOX_ID\"}"

echo "スケジュール設定が完了しました"
echo "次回実行予定: 2026-01-09 20:00 (JST)"
```

**スケジュールの詳細：**

- **頻度**: 毎日
- **実行時刻**: 20:00 (JST)
- **対象**: Sandbox Subscription のすべての VM
- **コスト削減**: 約 12 時間/日 × VM 台数 分のコスト削減

### 7.10.12 Azure Portal での確認

デプロイ後、Azure Portal で以下を確認します:

1. **Automation Account の確認**

   - Azure Portal → Automation Accounts → `aa-platform-prod-jpe-001`
   - Identity → System assigned が **On** になっていることを確認
   - Principal ID が環境変数 `$AUTOMATION_PRINCIPAL_ID` と一致することを確認

2. **Runbook の確認**

   - Automation Account → Runbooks → `Stop-SandboxVMs`
   - State が **Published** であることを確認
   - Edit → Test pane でテスト実行可能

3. **スケジュールの確認**

   - Automation Account → Schedules → `Daily-Evening-Shutdown`
   - Frequency: **Day**, Start time: **20:00 JST**
   - Next run time が翌日 20:00 に設定されていることを確認

4. **ロールアサインメントの確認**

   - Azure Portal → Subscriptions → Sandbox Subscription
   - Access control (IAM) → Role assignments
   - Automation Account の Managed Identity に **Contributor** が付与されていることを確認

5. **テスト実行（任意）**

   ```bash
   # 手動でテスト実行
   az automation runbook start \
     --resource-group rg-platform-management-prod-jpe-001 \
     --automation-account-name aa-platform-prod-jpe-001 \
     --name "Stop-SandboxVMs" \
     --parameters "{\"SubscriptionId\":\"$SUB_SANDBOX_ID\"}"

   # ジョブの状態を確認
   az automation job list \
     --resource-group rg-platform-management-prod-jpe-001 \
     --automation-account-name aa-platform-prod-jpe-001 \
     --output table
   ```

**期待される動作：**

- 毎晩 20:00 に自動実行
- Sandbox Subscription の実行中 VM をすべて停止
- ジョブ履歴で実行結果を確認可能
- 約 50% のコスト削減（12 時間分の VM 停止）

---

## 7.11 コスト管理

### 7.10.1 リソース別のコスト

| リソース             | 概算月額コスト（東日本）                |
| -------------------- | --------------------------------------- |
| Log Analytics        | データ量により変動（約 ¥300/GB）        |
| Application Insights | データ量により変動（約 ¥300/GB）        |
| Automation Account   | 実行時間により変動（500 分/月まで無料） |
| アラート             | アラート数により変動                    |

### 7.10.2 コスト削減のヒント

- Log Analytics の保持期間を適切に設定
- 不要なログの収集を停止
- Application Insights のサンプリング率を調整
- Automation Runbook の実行頻度を最適化

---

## 7.12 Git へのコミット

```bash
git add .
git commit -m "Day 1: Monitoring and log foundation

- Created Log Analytics Workspace in Management Subscription
- Configured comprehensive Log Analytics queries (KQL)
- Configured Entra ID audit and sign-in logs to Log Analytics
- Created action groups for alert notifications
- Created metric-based and log-based alerts
- Deployed Azure Automation Account with sample runbooks
- Configured diagnostic settings for existing resources (Log Analytics, DCR)
- Documented monitoring best practices"

git push origin main
```

---

## 7.13 章のまとめ

本章で構築したもの：

1. ✅ Log Analytics 基盤

   - Management Subscription に Log Analytics Workspace を構築
   - **VM Insights 用 Data Collection Rule (DCR)**
   - **Windows Event Logs と Syslog 収集用 DCR**
   - **Entra ID 監査ログとサインインログの収集**
   - 後続の章でポリシーによる自動適用の準備完了

2. ✅ Log Analytics クエリ

   - KQL クエリの基礎
   - よく使うクエリ集の作成

3. ✅ アラートルール

   - アクショングループ（メール通知）
   - メトリクスベースアラート（Firewall CPU）
   - ログベースアラート（Key Vault 失敗）

4. ✅ Azure Automation

   - Automation Account
   - VM 自動起動 Runbook
   - スケジュール設定

### 重要なポイント

- **可観測性の確保**: メトリクス、ログ、トレースの 3 つの柱
- **DCR による統一的なログ収集**: VM Insights と OS ログを自動収集
- **ポリシーとの連携準備**: 後の章で組み込みポリシーを使って VM 全体に自動適用
- **プロアクティブな監視**: 問題が起きる前にアラート
- **自動化**: 定期的なタスクは Automation
- **コストの最適化**: ログの保持期間とサンプリング率

### 1 日目の作業完了

Management Subscription の作成と監視・ログ基盤の構築が完了しました。これで、後続のリソースを監視する準備が整いました。

**24 時間後に 2 日目の作業（Identity Subscription 作成とガバナンス）に進んでください。**

---

## 次のステップ

1 日目の作業が完了しました。次は 2 日目の作業として、Identity Subscription の作成に進みます。

👉 [第 8 章：Identity Subscription 作成（2 日目）](chapter08-identity-subscription.md)

---

**最終更新**: 2026 年 1 月 7 日
