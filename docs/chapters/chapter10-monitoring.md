# 第 10 章：監視・管理基盤構築

## 本章の目的

本章では、Azure CAF Landing Zone の監視・管理基盤を構築します。Azure Monitor、アラート、ダッシュボード、Azure Automation、Application Insights などを実装し、システムの可観測性を確保します。

**所要時間**: 約 3-4 時間  
**難易度**: ⭐⭐⭐

---

## 10.1 可観測性（Observability）とは

### 10.1.1 可観測性の 3 つの柱

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

### 10.1.2 監視戦略

**監視すべき対象**:

- **インフラストラクチャ**: CPU、メモリ、ディスク、ネットワーク
- **アプリケーション**: レスポンスタイム、エラー率、スループット
- **セキュリティ**: 異常なアクセス、失敗した認証
- **コスト**: リソース使用量、予算超過

---

## 10.2 Azure Monitor の理解

### 10.2.1 Azure Monitor とは

**Azure Monitor**は、すべての Azure リソースの監視を統合するサービスです。

**機能**:

- メトリクスの収集と可視化
- ログの収集と分析（Log Analytics）
- アラートの設定
- 自動スケーリング
- ダッシュボード

### 10.2.2 データフロー

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

## 10.3 Log Analytics クエリの基礎

### 10.3.1 KQL の基本

**KQL（Kusto Query Language）**は、Log Analytics でデータをクエリする言語です。

**基本構文**:

```kql
// テーブルを指定
AzureDiagnostics

// 時間範囲をフィルタ
| where TimeGenerated > ago(1h)

// 特定の列のみ選択
| project TimeGenerated, ResourceType, OperationName

// 条件でフィルタ
| where OperationName == "SecretGet"

// 並び替え
| order by TimeGenerated desc

// 件数制限
| limit 100
```

### 10.3.2 よく使うクエリ例

```bash
# クエリ集ファイルを作成
mkdir -p docs/queries

cat << 'EOF' > docs/queries/log-analytics-queries.kql
// ----------------------------------------
// Azure Firewall - 拒否されたトラフィック
// ----------------------------------------
AzureDiagnostics
| where ResourceType == "AZUREFIREWALLS"
| where msg_s contains "Deny"
| project TimeGenerated, msg_s, Protocol = Protocol_s, SourceIP = SourceIP_s, DestinationIP = DestinationIP_s
| order by TimeGenerated desc

// ----------------------------------------
// Key Vault - シークレットアクセス
// ----------------------------------------
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where OperationName == "SecretGet"
| project TimeGenerated, CallerIPAddress, ResultType, Resource
| order by TimeGenerated desc

// ----------------------------------------
// Azure Bastion - 接続ログ
// ----------------------------------------
AzureDiagnostics
| where ResourceType == "BASTIONHOSTS"
| project TimeGenerated, Message, UserName = identity_claim_upn_s, TargetResourceId
| order by TimeGenerated desc

// ----------------------------------------
// VM - CPU使用率が80%超
// ----------------------------------------
Perf
| where ObjectName == "Processor"
| where CounterName == "% Processor Time"
| where CounterValue > 80
| summarize avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
| order by TimeGenerated desc

// ----------------------------------------
// リソース別のログ件数（上位10件）
// ----------------------------------------
AzureDiagnostics
| where TimeGenerated > ago(24h)
| summarize Count = count() by ResourceType
| top 10 by Count desc

// ----------------------------------------
// エラーログの集計
// ----------------------------------------
AzureDiagnostics
| where Level == "Error"
| where TimeGenerated > ago(24h)
| summarize Count = count() by ResourceType, OperationName
| order by Count desc

// ----------------------------------------
// 認証失敗の監視
// ----------------------------------------
SigninLogs
| where ResultType != "0"  // 0は成功
| where TimeGenerated > ago(1h)
| project TimeGenerated, UserPrincipalName, IPAddress, AppDisplayName, ResultType, ResultDescription
| order by TimeGenerated desc
EOF
```

---

## 10.4 アラートルールの作成

### 10.4.1 アクショングループの作成

**アクショングループ**は、アラート発火時の通知先を定義します。

ファイル `infrastructure/bicep/modules/monitoring/action-group.bicep` を作成し、以下の内容を記述します：

**action-group.bicep の解説：**

アラート発火時の通知先を定義するアクショングループを作成します。複数のメールアドレスに通知を送信できます。

```bicep
@description('アクショングループの名前')
param actionGroupName string

@description('デプロイ先のリージョン')
param location string = 'global'

@description('通知先のメールアドレス')
param emailAddresses array

@description('タグ')
param tags object = {}

// アクショングループ
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: location
  tags: tags
  properties: {
    groupShortName: substring(actionGroupName, 0, min(length(actionGroupName), 12))
    enabled: true
    emailReceivers: [for (email, i) in emailAddresses: {
      name: 'Email-${i}'
      emailAddress: email
      useCommonAlertSchema: true
    }]
  }
}

// 出力
output actionGroupId string = actionGroup.id
output actionGroupName string = actionGroup.name
EOF

# デプロイ
az deployment group create \
  --name "action-group-deployment-$(date +%Y%m%d-%H%M%S)" \
  --resource-group rg-platform-management-prod-jpe-001 \
  --template-file infrastructure/bicep/modules/monitoring/action-group.bicep \
  --parameters \
    actionGroupName=ag-platform-prod-jpe-001 \
    emailAddresses='["admin@example.com","ops@example.com"]'
```

### 10.4.2 メトリクスベースのアラート

ファイル `infrastructure/bicep/modules/monitoring/metric-alert.bicep` を作成し、以下の内容を記述します：

**metric-alert.bicep の解説：**

メトリクスベースのアラートルールを作成します。指定したメトリクスがしきい値を超えた場合に、アクショングループに通知します。

```bicep
@description('アラートルールの名前')
param alertRuleName string

@description('デプロイ先のリージョン')
param location string

@description('監視対象リソースのID')
param targetResourceId string

@description('アクショングループID')
param actionGroupId string

@description('メトリクス名')
param metricName string

@description('メトリクスの名前空間')
param metricNamespace string

@description('しきい値')
param threshold int

@description('演算子')
@allowed([
  'GreaterThan'
  'LessThan'
  'GreaterThanOrEqual'
  'LessThanOrEqual'
])
param operator string = 'GreaterThan'

@description('重要度（0=Critical, 1=Error, 2=Warning, 3=Informational）')
@allowed([
  0
  1
  2
  3
])
param severity int = 2

@description('タグ')
param tags object = {}

// メトリクスアラート
resource metricAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: alertRuleName
  location: location
  tags: tags
  properties: {
    description: '${metricName} が ${threshold} を超えました'
    severity: severity
    enabled: true
    scopes: [
      targetResourceId
    ]
    evaluationFrequency: 'PT5M'  // 5分ごと
    windowSize: 'PT15M'          // 15分間のデータ
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Metric1'
          metricName: metricName
          metricNamespace: metricNamespace
          operator: operator
          threshold: threshold
          timeAggregation: 'Average'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroupId
      }
    ]
  }
}

output alertRuleId string = metricAlert.id
EOF
```

### 10.4.3 Azure Firewall の監視アラート

```bash
# Azure FirewallのリソースIDを取得
FIREWALL_ID=$(az network firewall show \
  --name afw-hub-prod-jpe-001 \
  --resource-group rg-platform-connectivity-prod-jpe-001 \
  --query id -o tsv)

# アクショングループIDを取得
ACTION_GROUP_ID=$(az monitor action-group show \
  --name ag-platform-prod-jpe-001 \
  --resource-group rg-platform-management-prod-jpe-001 \
  --query id -o tsv)

# CPU使用率アラート
az deployment group create \
  --name "firewall-cpu-alert-$(date +%Y%m%d-%H%M%S)" \
  --resource-group rg-platform-connectivity-prod-jpe-001 \
  --template-file infrastructure/bicep/modules/monitoring/metric-alert.bicep \
  --parameters \
    alertRuleName="Firewall-CPU-High" \
    location=japaneast \
    targetResourceId="$FIREWALL_ID" \
    actionGroupId="$ACTION_GROUP_ID" \
    metricName="FirewallHealth" \
    metricNamespace="Microsoft.Network/azureFirewalls" \
    threshold=80 \
    operator=LessThan \
    severity=2
```

### 10.4.4 ログベースのアラート

ファイル `infrastructure/bicep/modules/monitoring/log-alert.bicep` を作成し、以下の内容を記述します：

**log-alert.bicep の解説：**

KQLクエリベースのアラートルールを作成します。Log Analytics Workspaceのログデータを分析し、特定の条件（例：アクセス失敗が5回以上）でアラートを発火します。

```bicep
@description('アラートルールの名前')
param alertRuleName string

@description('デプロイ先のリージョン')
param location string

@description('Log Analytics Workspace ID')
param workspaceId string

@description('アクショングループID')
param actionGroupId string

@description('クエリ')
param query string

@description('しきい値')
param threshold int

@description('重要度')
@allowed([
  0
  1
  2
  3
])
param severity int = 2

@description('タグ')
param tags object = {}

// ログアラート
resource logAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: alertRuleName
  location: location
  tags: tags
  properties: {
    displayName: alertRuleName
    description: 'ログベースのアラート'
    severity: severity
    enabled: true
    evaluationFrequency: 'PT5M'
    scopes: [
      workspaceId
    ]
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          query: query
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: threshold
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroupId
      ]
    }
  }
}

output logAlertId string = logAlert.id
EOF

# Key Vaultのアクセス失敗を監視するアラート
LOG_WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group rg-platform-management-prod-jpe-001 \
  --workspace-name log-platform-prod-jpe-001 \
  --query id -o tsv)

cat << 'EOF' > /tmp/kv-alert-query.txt
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where ResultType != "Success"
| summarize Count = count()
EOF

QUERY=$(cat /tmp/kv-alert-query.txt | tr '\n' ' ')

az deployment group create \
  --name "kv-access-failed-alert-$(date +%Y%m%d-%H%M%S)" \
  --resource-group rg-platform-management-prod-jpe-001 \
  --template-file infrastructure/bicep/modules/monitoring/log-alert.bicep \
  --parameters \
    alertRuleName="KeyVault-Access-Failed" \
    location=japaneast \
    workspaceId="$LOG_WORKSPACE_ID" \
    actionGroupId="$ACTION_GROUP_ID" \
    query="$QUERY" \
    threshold=5 \
    severity=1
```

---

## 10.5 ダッシュボードの作成

### 10.5.1 Azure ポータルでのダッシュボード作成

1. Azure ポータルで「Dashboard」をクリック
2. 「+ New dashboard」→「Blank dashboard」
3. 「Add tile」でタイルを追加：
   - Metrics chart（Firewall のスループット）
   - Resource health（すべてのリソース）
   - Markdown（説明）
4. 「Done customizing」→「Save」

### 10.5.2 Bicep でのダッシュボード作成

ファイル `infrastructure/bicep/modules/monitoring/dashboard.bicep` を作成し、以下の内容を記述します：

**dashboard.bicep の解説：**

Azure PortalダッシュボードをBicepで作成します。Markdownパーツを含むダッシュボードを定義し、CAF Landing Zoneの主要なメトリクスを監視できるようにします。

```bicep
@description('ダッシュボードの名前')
param dashboardName string

@description('デプロイ先のリージョン')
param location string

@description('タグ')
param tags object = {}

// ダッシュボード
resource dashboard 'Microsoft.Portal/dashboards@2020-09-01-preview' = {
  name: dashboardName
  location: location
  tags: union(tags, {
    'hidden-title': 'CAF Landing Zone Dashboard'
  })
  properties: {
    lenses: [
      {
        order: 0
        parts: [
          {
            position: {
              x: 0
              y: 0
              colSpan: 6
              rowSpan: 4
            }
            metadata: {
              inputs: []
              type: 'Extension/HubsExtension/PartType/MarkdownPart'
              settings: {
                content: {
                  settings: {
                    content: '# CAF Landing Zone Dashboard\n\nこのダッシュボードでは、Landing Zoneの主要なメトリクスを監視します。\n\n- Azure Firewall\n- Azure Bastion\n- Key Vault\n- Log Analytics'
                  }
                }
              }
            }
          }
        ]
      }
    ]
  }
}

output dashboardId string = dashboard.id
EOF
```

---

## 10.6 Azure Automation の構築

### 10.6.1 Azure Automation とは

**Azure Automation**は、定期的なタスクを自動化するサービスです。

**ユースケース**:

- VM の定期的な起動・停止
- 古いスナップショットの削除
- コンプライアンスレポートの生成
- パッチ管理

### 10.6.2 Automation Account の作成

ファイル `infrastructure/bicep/modules/automation/automation-account.bicep` を作成し、以下の内容を記述します：

**automation-account.bicep の解説：**

Azure Automation Accountを作成し、System-assigned Managed Identityを有効化します。定期的なタスク（VMの起動・停止等）を自動化するための基盤として機能します。

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

// マネージドIDの有効化
resource managedIdentity 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: automationAccountName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: automationAccount.properties
}

// 出力
output automationAccountId string = automationAccount.id
output automationAccountName string = automationAccount.name
output principalId string = managedIdentity.identity.principalId
EOF

# デプロイ
az deployment group create \
  --name "automation-account-deployment-$(date +%Y%m%d-%H%M%S)" \
  --resource-group rg-platform-management-prod-jpe-001 \
  --template-file infrastructure/bicep/modules/automation/automation-account.bicep \
  --parameters \
    automationAccountName=aa-platform-prod-jpe-001 \
    location=japaneast
```

### 10.6.3 Runbook の例（VM の自動起動・停止）

```bash
cat << 'EOF' > infrastructure/automation/runbooks/Start-AzureVMs.ps1
<#
.SYNOPSIS
    指定されたタグを持つVMを起動します

.DESCRIPTION
    AutoStart=trueタグを持つすべてのVMを起動します

.NOTES
    実行にはマネージドIDが必要です
#>

# Azure接続
Connect-AzAccount -Identity

# AutoStart=trueのVMを取得
$vms = Get-AzVM -Status | Where-Object {$_.Tags["AutoStart"] -eq "true" -and $_.PowerState -eq "VM deallocated"}

foreach ($vm in $vms) {
    Write-Output "Starting VM: $($vm.Name)"
    Start-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -NoWait
}

Write-Output "Complete: Started $($vms.Count) VMs"
EOF

# Runbookをインポート
az automation runbook create \
  --resource-group rg-platform-management-prod-jpe-001 \
  --automation-account-name aa-platform-prod-jpe-001 \
  --name "Start-AzureVMs" \
  --type PowerShell \
  --location japaneast

az automation runbook replace-content \
  --resource-group rg-platform-management-prod-jpe-001 \
  --automation-account-name aa-platform-prod-jpe-001 \
  --name "Start-AzureVMs" \
  --content @infrastructure/automation/runbooks/Start-AzureVMs.ps1

az automation runbook publish \
  --resource-group rg-platform-management-prod-jpe-001 \
  --automation-account-name aa-platform-prod-jpe-001 \
  --name "Start-AzureVMs"
```

### 10.6.4 スケジュールの作成

```bash
# 平日の朝8時にVMを起動するスケジュール
az automation schedule create \
  --resource-group rg-platform-management-prod-jpe-001 \
  --automation-account-name aa-platform-prod-jpe-001 \
  --name "Weekday-Morning-Start" \
  --frequency "Week" \
  --interval 1 \
  --start-time "2026-01-08T08:00:00+09:00" \
  --time-zone "Tokyo Standard Time" \
  --week-days Monday Tuesday Wednesday Thursday Friday

# Runbookとスケジュールをリンク
az automation job-schedule create \
  --resource-group rg-platform-management-prod-jpe-001 \
  --automation-account-name aa-platform-prod-jpe-001 \
  --runbook-name "Start-AzureVMs" \
  --schedule-name "Weekday-Morning-Start"
```

---

## 10.7 Application Insights の構築

### 10.7.1 Application Insights とは

**Application Insights**は、アプリケーションのパフォーマンスとユーザー行動を監視する APM サービスです。

**機能**:

- レスポンスタイム監視
- 失敗したリクエストの追跡
- 依存関係の可視化
- ユーザー行動の分析

### 10.7.2 Application Insights Bicep モジュール

ファイル `infrastructure/bicep/modules/monitoring/application-insights.bicep` を作成し、以下の内容を記述します：

**application-insights.bicep の解説：**

Application Insightsを作成し、Log Analytics Workspaceと統合します。アプリケーションのパフォーマンスとユーザー行動を監視するAPMサービスです。

```bicep
@description('Application Insightsの名前')
param appInsightsName string

@description('デプロイ先のリージョン')
param location string

@description('Log Analytics Workspace ID')
param workspaceId string

@description('タグ')
param tags object = {}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspaceId
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// 出力
output appInsightsId string = appInsights.id
output appInsightsName string = appInsights.name
output instrumentationKey string = appInsights.properties.InstrumentationKey
output connectionString string = appInsights.properties.ConnectionString
EOF

# デプロイ
az deployment group create \
  --name "app-insights-deployment-$(date +%Y%m%d-%H%M%S)" \
  --resource-group rg-platform-management-prod-jpe-001 \
  --template-file infrastructure/bicep/modules/monitoring/application-insights.bicep \
  --parameters \
    appInsightsName=appi-platform-prod-jpe-001 \
    location=japaneast \
    workspaceId="$LOG_WORKSPACE_ID"
```

---

## 10.8 Azure Portal での確認

### 10.8.1 Azure Monitor の確認

1. Azure ポータルで「Monitor」を検索
2. 「Metrics」でリソースのメトリクスをグラフ化
3. 「Logs」で Log Analytics クエリを実行
4. 「Alerts」でアラートルールを確認

### 10.8.2 アラートのテスト

```bash
# Key Vaultに意図的に失敗したアクセスを実行（アラート発火テスト）
az keyvault secret show \
  --vault-name kv-hub-prod-jpe-001 \
  --name NonExistentSecret 2>/dev/null || echo "Expected error"

# 5-10分後にメールが届くことを確認
```

---

## 10.9 Workbooks の作成

### 10.9.1 Workbooks とは

**Workbooks**は、Azure Monitor データをインタラクティブなレポートとしてカスタマイズできるツールです。

### 10.9.2 Workbook の作成（ポータル）

1. Azure ポータルで「Monitor」→「Workbooks」
2. 「+ New」で新しい Workbook を作成
3. 「+ Add」→「Add query」で KQL クエリを追加
4. 可視化方法を選択（Table, Chart, Grid 等）
5. 「Save」で保存

---

## 10.10 コスト管理

### 10.10.1 リソース別のコスト

| リソース             | 概算月額コスト（東日本）                |
| -------------------- | --------------------------------------- |
| Log Analytics        | データ量により変動（約 ¥300/GB）        |
| Application Insights | データ量により変動（約 ¥300/GB）        |
| Automation Account   | 実行時間により変動（500 分/月まで無料） |
| アラート             | アラート数により変動                    |

### 10.10.2 コスト削減のヒント

- Log Analytics の保持期間を適切に設定
- 不要なログの収集を停止
- Application Insights のサンプリング率を調整
- Automation Runbook の実行頻度を最適化

---

## 10.11 Git へのコミット

```bash
git add .
git commit -m "Chapter 10: Monitoring and management foundation

- Created comprehensive Log Analytics queries (KQL)
- Configured action groups for alert notifications
- Created metric-based alerts (CPU, health)
- Created log-based alerts (access failures)
- Deployed Azure Automation Account with sample runbooks
- Created Application Insights for app monitoring
- Documented dashboard creation process
- Created monitoring Bicep modules"

git push origin main
```

---

## 10.12 章のまとめ

本章で構築したもの：

1. ✅ Log Analytics クエリ集

   - Firewall、Key Vault、Bastion のログ分析
   - CPU 使用率、エラーログの監視

2. ✅ アラートルール

   - アクショングループ（メール通知）
   - メトリクスベースアラート（Firewall CPU）
   - ログベースアラート（Key Vault 失敗）

3. ✅ Azure Automation

   - Automation Account
   - VM 自動起動 Runbook
   - スケジュール設定

4. ✅ Application Insights
   - アプリケーション監視基盤
   - Log Analytics と統合

### 重要なポイント

- **可観測性の確保**: メトリクス、ログ、トレースの 3 つの柱
- **プロアクティブな監視**: 問題が起きる前にアラート
- **自動化**: 定期的なタスクは Automation
- **コストの最適化**: ログの保持期間とサンプリング率

---

## 次のステップ

監視・管理基盤が構築できたら、次はガバナンス・ポリシーの実装に進みます。

👉 [第 11 章：ガバナンス・ポリシー実装](chapter11-governance.md)

---

**最終更新**: 2026 年 1 月 7 日
