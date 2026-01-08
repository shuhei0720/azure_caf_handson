# 第 14 章：Landing Zone Subscription 作成（4 日目以降）

## 本章の目的

本章では、**4 日目以降の作業として Landing Zone Subscription を作成**します。Landing Zone Subscription は、アプリケーションワークロードを配置するための本番環境用サブスクリプションです。

**所要時間**: 約 30 分〜1 時間  
**難易度**: ⭐  
**実施タイミング**: **4 日目以降**（Connectivity Subscription 作成から 24 時間後）  
**注意**: このサブスクリプションにデプロイするリソースは費用が発生します

---

## 14.0 前提条件

### 14.0.1 3 日目までの作業完了確認

以下が完了していることを確認してください：

- Connectivity Subscription の作成
- Hub Network の構築（Hub VNet、Azure Firewall、Bastion）
- Security 基盤の構築
- .env ファイルに BILLING_SCOPE、SUB_MANAGEMENT_ID、SUB_IDENTITY_ID、SUB_CONNECTIVITY_ID が保存されている

### 14.0.2 24 時間待機の確認

> **⚠️ 重要：個人契約アカウントの制約事項**
>
> 個人契約の Azure アカウント（Pay-As-You-Go、Free Trial など）では、**24 時間に 1 つのサブスクリプションしか作成できません**。
>
> 3 日目に Connectivity Subscription を作成してから、**最低 24 時間**待機してください。待機せずにデプロイすると、エラーが発生します。

### 14.0.3 環境変数の読み込み

```bash
# .envファイルから環境変数を読み込み
source .env

# BILLING_SCOPEが設定されていることを確認
echo "Billing Scope: $BILLING_SCOPE"

# 既存のSubscription IDsを確認
echo "Management Subscription ID: $SUB_MANAGEMENT_ID"
echo "Identity Subscription ID: $SUB_IDENTITY_ID"
echo "Connectivity Subscription ID: $SUB_CONNECTIVITY_ID"
```

---

## 14.1 Landing Zone Subscription とは

### 14.1.1 Landing Zone Subscription の役割

**Landing Zone Subscription** は、アプリケーションワークロードを配置するための専用サブスクリプションです：

- **Spoke VNet**: Hub VNet とピアリングされたアプリケーション用ネットワーク
- **Container Apps / AKS**: コンテナワークロード
- **App Service / Functions**: サーバーレスアプリケーション
- **データベース**: SQL Database、Cosmos DB など
- **ストレージ**: Storage Account、Blob など

本ハンズオンでは、**Corp（内部アプリケーション）向けの Landing Zone** を 1 つ作成します。

### 14.1.2 CAF における Landing Zone Subscription の位置づけ

```mermaid
graph TB
    subgraph "Platform Subscriptions"
        MgmtSub[Management<br/>監視・ログ・自動化]
        IdSub[Identity<br/>ID管理]
        ConnSub[Connectivity<br/>Hub Network]
    end

    subgraph "Landing Zone Subscriptions"
        CorpProdSub[Corp Production<br/>本番内部アプリ<br/>✅4日目以降に作成]
    end

    ConnSub -->|VNet Peering| CorpProdSub
    MgmtSub -->|Monitoring| CorpProdSub

    style CorpProdSub fill:#e8f5e9
```

---

## 14.2 Landing Zone Subscription の作成

### 14.2.1 Orchestration への統合

**Chapter 6 で作成した orchestration (`tenant.bicep`)は既に Subscription モジュールを含んでいます。** Chapter 14 では`tenant.bicepparam`に Landing Zone Subscription の設定を追記するだけです。

**orchestration/tenant.bicepparam を開き**、`subscriptions`セクションを以下のように更新：

```bicep
param subscriptions = {
  management: {
    aliasName: 'sub-platform-management-prod'
    displayName: 'sub-platform-management-prod'
    workload: 'Production'
  }
  identity: {
    aliasName: 'sub-platform-identity-prod'
    displayName: 'sub-platform-identity-prod'
    workload: 'Production'
  }
  connectivity: {
    aliasName: 'sub-platform-connectivity-prod'
    displayName: 'sub-platform-connectivity-prod'
    workload: 'Production'
  }
  landingZoneCorp: {  // 👈 Chapter 14で追記
    aliasName: 'sub-landingzone-corp-prod'
    displayName: 'sub-landingzone-corp-prod'
    workload: 'Production'
  }
}
```

**orchestration/tenant.bicep を開き**、Landing Zone Subscription モジュールを追記：

```bicep
// Landing Zone Corp Subscription作成
module landingZoneCorpSubscription '../modules/subscriptions/subscription.bicep' = if (contains(subscriptions, 'landingZoneCorp')) {
  name: 'deploy-subscription-landingzone-corp'
  params: {
    subscriptionAliasName: subscriptions.landingZoneCorp.aliasName
    subscriptionDisplayName: subscriptions.landingZoneCorp.displayName
    billingScope: billingScope
    workload: subscriptions.landingZoneCorp.workload
  }
}

// Landing Zone Corp SubscriptionをManagement Groupに紐づけ
module landingZoneCorpSubscriptionAssociation '../modules/management-groups/subscription-association.bicep' = if (contains(subscriptions, 'landingZoneCorp')) {
  name: 'deploy-mg-assoc-landingzone-corp'
  params: {
    managementGroupId: '${companyPrefix}-landingzones-corp'
    subscriptionId: landingZoneCorpSubscription.?outputs.?subscriptionId ?? ''
  }
  dependsOn: [
    managementGroups
  ]
}

// =============================================================================
// 出力（Chapter 14で追加）
// =============================================================================

output landingZoneCorpSubscription object = {
  subscriptionId: landingZoneCorpSubscription.?outputs.?subscriptionId ?? ''
  subscriptionName: landingZoneCorpSubscription.?outputs.?subscriptionName ?? ''
}
```

### 14.2.2 What-If 実行

**orchestration 経由**でデプロイします：

```bash
# デプロイ名を変数に保存
DEPLOYMENT_NAME="tenant-deployment-$(date +%Y%m%d-%H%M%S)"

echo "Creating Landing Zone Corp Subscription via Orchestration..."

# What-If実行
az deployment tenant what-if \
  --name "$DEPLOYMENT_NAME" \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/tenant.bicep \
  --parameters infrastructure/bicep/orchestration/tenant.bicepparam
```

### 14.2.3 デプロイ実行（10-15 分）

```bash
# デプロイ実行
az deployment tenant create \
  --name "$DEPLOYMENT_NAME" \
  --location japaneast \
  --template-file infrastructure/bicep/orchestration/tenant.bicep \
  --parameters infrastructure/bicep/orchestration/tenant.bicepparam

echo "Deployment name: $DEPLOYMENT_NAME"
```

**デプロイには 10〜15 分程度かかります。**

### 14.2.4 Subscription ID の取得と記録

```bash
# デプロイ結果から Subscription ID を取得
SUB_LANDINGZONE_CORP_ID=$(az deployment tenant show \
  --name "$DEPLOYMENT_NAME" \
  --query "properties.outputs.landingZoneCorpSubscription.value.subscriptionId" -o tsv)

echo "Landing Zone Corp Subscription ID: $SUB_LANDINGZONE_CORP_ID"

# .envファイルに追記（重複防止）
grep -q "SUB_LANDINGZONE_CORP_ID=" .env || echo "SUB_LANDINGZONE_CORP_ID=$SUB_LANDINGZONE_CORP_ID" >> .env

# 確認
cat .env
```

**代替方法**: デプロイから時間が経過している場合：

```bash
SUB_LANDINGZONE_CORP_ID=$(az account list --query "[?name=='sub-landingzone-corp-prod'].id" -o tsv)
echo "Landing Zone Corp Subscription ID: $SUB_LANDINGZONE_CORP_ID"
grep -q "SUB_LANDINGZONE_CORP_ID=" .env || echo "SUB_LANDINGZONE_CORP_ID=$SUB_LANDINGZONE_CORP_ID" >> .env
```

### 14.2.5 Azure ポータルでの確認

1. [Azure ポータル](https://portal.azure.com)にアクセス
2. 検索バーで「Subscriptions」を検索
3. **sub-landingzone-corp-prod** が表示されることを確認
4. 「Management groups」を開き、**contoso-landingzones-corp** 配下に表示されることを確認

CLI で確認：

```bash
# Subscription確認
az account show --subscription $SUB_LANDINGZONE_CORP_ID --output table

# Management Group紐づけ確認
az account management-group subscription show \
  --name contoso-landingzones-corp \
  --subscription $SUB_LANDINGZONE_CORP_ID
```

**✅ orchestration により、Subscription 作成と MG 紐づけが自動で完了しています！**

---

## 14.3 orchestration 統合のメリット（再確認）

**従来の方式**（個別デプロイ）:

- ❌ 各 Chapter で Subscription 作成と MG 紐づけを別々に実行
- ❌ orchestration ファイルに含まれず、復元時に手動実行が必要
- ❌ 冪等性が保証されない

**orchestration 統合後**:

- ✅ **1 コマンドで全て作成**: Subscription 作成と MG 紐づけが自動
- ✅ **冪等性**: 何度実行しても同じ結果
- ✅ **復元が容易**: 全削除後も`tenant.bicep`を実行するだけ
- ✅ **一元管理**: `tenant.bicepparam`でパラメータ管理

---

## 14.4 Git へのコミット

4. **sub-landingzone-corp-prod** が表示されていることを確認

---

## 14.4 Git へのコミット

```bash
# 変更の確認
git status

# ステージングとコミット
git add .

git commit -m "Day 4+: Create Landing Zone Corp Subscription

- Created sub-landingzone-corp-prod subscription
- Associated with contoso-landingzones-corp management group
- Saved SUB_LANDINGZONE_CORP_ID to .env"

# プッシュ
git push origin main
```

---

## 14.5 章のまとめ

本章で行ったこと：

1. ✅ 3 日目の作業から 24 時間待機
2. ✅ Landing Zone Corp Subscription の作成
3. ✅ Landing Zone Subscription と Management Group の関連付け
4. ✅ Subscription ID の記録
5. ✅ Git へのコミット・プッシュ

### 重要なポイント

- **24 時間待機が必須**: 個人アカウントでは 1 日 1 サブスクリプションのみ作成可能
- **アプリケーション配置**: この Subscription に Spoke VNet、Container Apps などを配置
- **CAF ベストプラクティス**: ワークロードは専用サブスクリプションで分離

### 4 日目以降の次のステップ

Landing Zone Subscription の作成が完了したら、次は Spoke VNet の構築に進みます。

---

## チェックリスト

- [ ] 3 日目の作業から 24 時間以上経過したことを確認した
- [ ] BILLING_SCOPE を .env から読み込んだ
- [ ] Landing Zone Corp Subscription を作成した
- [ ] Landing Zone Subscription を Management Group に関連付けた
- [ ] SUB_LANDINGZONE_CORP_ID を .env に保存した
- [ ] Git にコミット・プッシュした

---

## 次のステップ

Landing Zone Subscription の準備が完了したら、次は Spoke VNet（Landing Zone Network）の構築に進みます。

👉 [第 15 章：Landing Zone（Spoke）構築](chapter15-landing-zone.md)

**注意**: 次の章では、Spoke VNet、VNet Peering、アプリケーションサブネットなどを構築します。

---

## 参考リンク

- [Azure サブスクリプション](https://docs.microsoft.com/azure/cost-management-billing/manage/create-subscription)
- [CAF Landing Zone](https://docs.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)
- [Hub-Spoke ネットワークトポロジ](https://docs.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)

---

**最終更新**: 2026 年 1 月 7 日
