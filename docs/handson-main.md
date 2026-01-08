# Azure CAF ランディングゾーン 完全ハンズオン

## 目次

本ハンズオンは、Microsoft Cloud Adoption Framework (CAF) に基づいた、エンタープライズグレードの Azure ランディングゾーンを、ゼロから構築するための実践的な教材です。

各章は独立したハンズオン形式になっており、順番に進めることで、完全なランディングゾーンアーキテクチャを構築できます。

---

## ハンズオン全体の流れ

### Phase 1: 基礎理解と準備（所要時間：3-5 時間）

#### [第 1 章：イントロダクションと CAF 概要](chapters/chapter01-introduction.md)

- Cloud Adoption Framework とは
- ランディングゾーンの必要性
- 本ハンズオンで構築するアーキテクチャの全体像
- エンタープライズスケールアーキテクチャの設計原則

#### [第 2 章：前提条件と環境準備](chapters/chapter02-prerequisites.md)

- Azure アカウントの作成
- GitHub Codespaces のセットアップ
- 必要なツールのインストール
  - Azure CLI
  - Bicep CLI
  - PowerShell Az Module
  - Git 設定
- プロジェクト構造の理解

#### [第 3 章：CAF ランディングゾーン詳細](chapters/chapter03-caf-overview.md)

- ランディングゾーンの 8 つの設計領域
  1. Azure 課金と Active Directory テナント
  2. ID とアクセス管理
  3. リソース編成
  4. ネットワークトポロジと接続
  5. セキュリティ
  6. 管理
  7. ガバナンス
  8. プラットフォームの自動化と DevOps
- Management Group 階層の詳細設計
- Subscription 構成の設計
- 命名規則とタギング戦略

#### [第 4 章：Azure 環境の初期セットアップ](chapters/chapter04-setup.md)

- Azure ポータルへのサインイン
- テナント情報の確認
- 初期 Subscription の作成
- サービスプリンシパルの作成（CI/CD 用）
- GitHub Secrets の設定
- 初回の Git コミット・プッシュ

---

### Phase 2: プラットフォーム基盤の構築（1 日目：第 6-7 章）

#### [第 5 章：Management Groups 設計・構築](chapters/chapter05-management-groups.md)

- Management Groups アーキテクチャの設計
  - Root Management Group
  - Platform Management Group
  - Landing Zones Management Group
  - Sandbox / Decommissioned
- Bicep での Management Groups 作成
- Management Groups 階層の可視化
- Azure Portal での確認

#### [第 6 章：Subscriptions 設計・構築（1 日目）](chapters/chapter06-subscriptions.md)

- Subscription 戦略の設計
- Management Subscription の作成（1 日目）
- Subscriptions と Management Groups の関連付け
- Subscription 間の権限設計
- **注意**: 他の Subscription は翌日以降に作成（24 時間の制限あり）

#### [第 7 章：監視・ログ基盤構築（1 日目）](chapters/chapter07-monitoring.md)

- Log Analytics Workspace の構築
- Azure Monitor の設定
  - 診断設定の一括適用
  - メトリクスとログの収集
- アラートの設定
  - アクショングループの作成
  - アラートルールの作成
- Workbook の作成（ダッシュボード）
- Application Insights の設定
- Azure Automation アカウントの構築
  - 自動化 Runbook の作成
- Update Management の設定

---

### Phase 2: Identity & ガバナンス（2 日目：第 8-10 章）

#### [第 8 章：Identity Subscription 作成（2 日目）](chapters/chapter08-identity-subscription.md)

- Identity Subscription の作成（24 時間後）
- Management Groups への割り当て
- サブスクリプション設定

#### [第 9 章：Identity & Access Management（IAM）設計（2 日目）](chapters/chapter09-iam.md)

- Azure AD（Entra ID）の設計
- ユーザーとグループの作成
- Azure RBAC の設計と実装
  - カスタムロールの作成
  - ロール割り当ての実装
- 管理グループレベルでの権限設定
- Privileged Identity Management (PIM) の設定
- 条件付きアクセスの設定
- Multi-Factor Authentication (MFA) の有効化

#### [第 10 章：ガバナンス・ポリシー実装（2 日目）](chapters/chapter10-governance.md)

- Azure Policy の設計思想
- 組み込みポリシーの理解
- カスタムポリシーの作成
  - ポリシー定義の作成
  - ポリシーイニシアチブの作成
- ポリシーの割り当て
  - Management Group レベルでの割り当て
  - 除外設定
- 主要なポリシーの実装
  - 許可されるリージョンの制限
  - リソースタグの強制
  - SKU の制限
  - 診断設定の強制
  - ネットワークセキュリティの強制
  - 暗号化の強制
- Blueprints の作成と割り当て
- Cost Management の設定
  - 予算アラートの設定
  - コスト分析の設定
- Azure Resource Graph を使用したクエリ

---

### Phase 3: ネットワークとセキュリティ（3 日目：第 11-12 章）

#### [第 11 章：Connectivity Subscription 作成（3 日目）](chapters/chapter11-connectivity-subscription.md)

- Connectivity Subscription の作成（48 時間後）
- Management Groups への割り当て
- サブスクリプション設定

#### [第 12 章：Security 基盤構築（3 日目）](chapters/chapter12-security.md)

- Microsoft Defender for Cloud の有効化
  - すべてのサブスクリプションでの有効化
  - セキュリティポリシーの設定
- Azure Sentinel の構築（SIEM/SOAR）
- Key Vault の構築
  - 暗号化キーの管理
  - シークレット管理
  - 証明書管理
- セキュリティベースラインの設定
- Azure DDoS Protection Standard の有効化

---

### Phase 4: Hub Network 構築（4 日目以降：第 13-14 章）

#### [第 13 章：Hub Network 構築（4 日目以降）](chapters/chapter13-networking-hub.md)

- Hub-Spoke ネットワークトポロジーの設計
- Hub VNet の作成
  - アドレス空間の設計
  - サブネット設計（GatewaySubnet, AzureFirewallSubnet, etc.）
- Azure Firewall の構築
  - Firewall Policy の設定
  - ルールコレクションの作成
- Azure Bastion の構築
- VPN Gateway または ExpressRoute Gateway の構築
- Network Security Groups (NSG) の設計
- Route Table の設定
- Azure DNS Private Zone の設定

#### [第 14 章：Landing Zone Subscription 作成（4 日目以降）](chapters/chapter14-landingzone-subscription.md)

- Landing Zone Subscription の作成（72 時間後）
- Management Groups への割り当て
- サブスクリプション設定

---

### Phase 5: アプリケーション実装（4 日目以降：第 15-18 章）

#### [第 15 章：Landing Zone（Spoke）構築](chapters/chapter15-landing-zone.md)

- Spoke VNet の設計
  - アドレス空間の割り当て
  - サブネット設計
- Spoke VNet の作成（Bicep）
- Hub-Spoke Peering の構築
- NSG と RouteTable の適用
- Private Endpoint の設計
- Spoke 固有のリソース作成
  - Azure Container Registry (ACR)
  - Azure Container Apps
  - Azure Database for PostgreSQL
  - Azure Storage Account
  - Azure Cache for Redis
- Private Link の構築
- DNS 設定の統合

#### [第 16 章：アプリケーション開発・デプロイ](chapters/chapter16-application.md)

- Next.js アプリケーションの構築
  - プロジェクト作成
  - TypeScript 設定
  - Tailwind CSS 設定
- アプリケーションの設計
  - フロントエンド構成
  - API ルート設計
  - データベース接続
- Azure Container Apps へのデプロイ準備
  - Dockerfile の作成
  - Docker Compose でのローカルテスト
- CI/CD パイプラインの作成（アプリ用）
  - ビルドワークフロー
  - デプロイワークフロー
  - 環境変数の管理
- 本番デプロイ
- カスタムドメインの設定
- SSL 証明書の設定
- Application Gateway の構築（オプション）
- CDN の構築（Azure Front Door）

#### [第 17 章：CI/CD パイプライン構築](chapters/chapter17-cicd.md)

- GitHub Actions の基礎
- Infrastructure as Code のワークフロー設計
- Bicep デプロイワークフローの作成
  - Pull Request 時のバリデーション
  - main ブランチへのマージ時のデプロイ
- ポリシーデプロイワークフローの作成
- 環境ごとの分離（dev/staging/production）
- シークレット管理のベストプラクティス
- ロールバック戦略
- デプロイの承認フロー

#### [第 18 章：まとめと次のステップ](chapters/chapter18-conclusion.md)

- 構築したアーキテクチャの振り返り
- 運用フェーズへの移行
  - 監視とアラートの確認
  - インシデント対応プロセス
  - 変更管理プロセス
- スケーリング戦略
  - 新しい Landing Zone の追加
  - グローバル展開
- コスト最適化
  - リソースの見直し
  - Reserved Instances と Savings Plans
- セキュリティの継続的改善
- さらなる学習リソース
- コミュニティとサポート
- クリーンアップ手順（リソースの削除）
  - Management Group レベルでの割り当て
  - 除外設定
- 主要なポリシーの実装
  - 許可されるリージョンの制限
  - リソースタグの強制
  - SKU の制限
  - 診断設定の強制
  - ネットワークセキュリティの強制
  - 暗号化の強制
- Blueprints の作成と割り当て
- Cost Management の設定
  - 予算アラートの設定
  - コスト分析の設定
- Azure Resource Graph を使用したクエリ

#### [第 12 章：CI/CD パイプライン構築](chapters/chapter12-cicd.md)

- GitHub Actions の基礎
- Infrastructure as Code のワークフロー設計
- Bicep デプロイワークフローの作成
  - Pull Request 時のバリデーション
  - main ブランチへのマージ時のデプロイ
- ポリシーデプロイワークフローの作成
- 環境ごとの分離（dev/staging/production）
- シークレット管理のベストプラクティス
- ロールバック戦略
- デプロイの承認フロー

---

### Phase 4: Landing Zone と Application（所要時間：12-18 時間）

#### [第 13 章：Landing Zone（Spoke）構築](chapters/chapter13-landing-zone.md)

- Spoke VNet の設計
  - アドレス空間の割り当て
  - サブネット設計
- Spoke VNet の作成（Bicep）
- Hub-Spoke Peering の構築
- NSG と RouteTable の適用
- Private Endpoint の設計
- Spoke 固有のリソース作成
  - Azure Container Registry (ACR)
  - Azure App Service / Azure Container Apps
  - Azure Database (PostgreSQL/MySQL)
  - Azure Storage Account
  - Azure Cache for Redis
- Private Link の構築
- DNS 設定の統合

#### [第 14 章：アプリケーション開発・デプロイ](chapters/chapter14-application.md)

- Next.js アプリケーションの構築
  - プロジェクト作成
  - TypeScript 設定
  - Tailwind CSS 設定
- アプリケーションの設計
  - フロントエンド構成
  - API ルート設計
  - データベース接続
- Azure Container Apps へのデプロイ準備
  - Dockerfile の作成
  - Docker Compose でのローカルテスト
- CI/CD パイプラインの作成（アプリ用）
  - ビルドワークフロー
  - デプロイワークフロー
  - 環境変数の管理
- 本番デプロイ
- カスタムドメインの設定
- SSL 証明書の設定
- Application Gateway の構築（オプション）
- CDN の構築（Azure Front Door）

#### [第 15 章：まとめと次のステップ](chapters/chapter15-conclusion.md)

- 構築したアーキテクチャの振り返り
- 運用フェーズへの移行
  - 監視とアラートの確認
  - インシデント対応プロセス
  - 変更管理プロセス
- スケーリング戦略
  - 新しい Landing Zone の追加
  - グローバル展開
- コスト最適化
  - リソースの見直し
  - Reserved Instances と Savings Plans
- セキュリティの継続的改善
- さらなる学習リソース
- コミュニティとサポート
- クリーンアップ手順（リソースの削除）

---

## 章別の推奨所要時間

| 章       | タイトル                       | 推定時間       | 難易度   | 実施日  |
| -------- | ------------------------------ | -------------- | -------- | ------- |
| 1        | イントロダクションと CAF 概要  | 1 時間         | ⭐       | -       |
| 2        | 前提条件と環境準備             | 1-2 時間       | ⭐       | -       |
| 3        | CAF ランディングゾーン詳細     | 1-2 時間       | ⭐⭐     | -       |
| 4        | Azure 環境の初期セットアップ   | 1-2 時間       | ⭐⭐     | -       |
| 5        | Management Groups 設計・構築   | 2-3 時間       | ⭐⭐     | 1 日目  |
| 6        | Subscriptions 設計・構築       | 1-2 時間       | ⭐⭐     | 1 日目  |
| 7        | 監視・ログ基盤構築             | 3-4 時間       | ⭐⭐⭐   | 1 日目  |
| 8        | Identity Subscription 作成     | 30 分          | ⭐       | 2 日目  |
| 9        | IAM 設計                       | 3-4 時間       | ⭐⭐⭐   | 2 日目  |
| 10       | ガバナンス・ポリシー実装       | 4-6 時間       | ⭐⭐⭐⭐ | 2 日目  |
| 11       | Connectivity Subscription 作成 | 30 分          | ⭐       | 3 日目  |
| 12       | Security 基盤構築              | 3-4 時間       | ⭐⭐⭐   | 3 日目  |
| 13       | Hub Network 構築               | 4-6 時間       | ⭐⭐⭐   | 4 日目  |
| 14       | Landing Zone Subscription 作成 | 30 分          | ⭐       | 4 日目  |
| 15       | Landing Zone（Spoke）構築      | 4-6 時間       | ⭐⭐⭐⭐ | 4 日目+ |
| 16       | アプリケーション開発・デプロイ | 8-12 時間      | ⭐⭐⭐⭐ | 4 日目+ |
| 17       | CI/CD パイプライン構築         | 4-6 時間       | ⭐⭐⭐⭐ | 4 日目+ |
| 18       | まとめと次のステップ           | 1-2 時間       | ⭐       | -       |
| **合計** |                                | **47-72 時間** |          |         |

---

## ハンズオンの進め方のコツ

### 1. 焦らず、じっくり理解しながら進める

このハンズオンは非常に網羅的です。一度に全てを理解しようとせず、各章を確実に進めましょう。

### 2. 実際に手を動かす

読むだけでなく、必ず自分の手でコードを書き、実行してください。トラブルシューティングの経験も重要な学びです。

### 3. Azure ポータルで確認する

コマンドやコードでリソースを作成したら、必ず Azure ポータルで視覚的に確認しましょう。リソースの関係性や設定値を理解できます。

### 4. 定期的にコミット・プッシュ

各セクションを完了したら、Git でコミット・プッシュする習慣をつけましょう。バージョン管理の練習にもなります。

### 5. メモを取る

学んだことや、つまずいた点をメモしておくと、後で役立ちます。

### 6. コストに注意

リソースを作成すると料金が発生します。不要なリソースは速やかに削除しましょう。

### 7. 公式ドキュメントも併読

各章では関連する公式ドキュメントへのリンクを掲載しています。より深い理解のために併読をお勧めします。

---

## よくある質問（FAQ）

### Q1: Azure 無料アカウントで実施できますか？

A: 可能ですが、無料枠（$200 クレジット）を超える可能性があります。特に Azure Firewall、Azure Bastion、VPN Gateway などは費用が高いです。学習目的であれば、不要な時はリソースを停止または削除することをお勧めします。

### Q2: どのくらいの期間で完了できますか？

A: 個人差がありますが、**最低 4 日間必要**です（Azure Subscription の作成制限のため）。各日の作業時間は 2-6 時間程度。週末を使って 1-2 週間で完了できます。

**推奨スケジュール：**

- **1 日目**: 第 5-7 章（Management Groups、Subscription 作成、監視基盤）
- **2 日目**: 第 8-10 章（Identity Subscription、IAM、ガバナンス）
- **3 日目**: 第 11-12 章（Connectivity Subscription、セキュリティ）
- **4 日目以降**: 第 13-18 章（Hub Network、Landing Zone、アプリケーション、CI/CD）

### Q3: 途中で止めて、後から再開できますか？

A: はい、可能です。Git でコミットしておけば、いつでも再開できます。ただし、Azure リソースは料金が発生するため、長期間中断する場合はリソースを削除することをお勧めします。

### Q4: エラーが出て進めません

A: 各章の「トラブルシューティング」セクションを確認してください。それでも解決しない場合は、GitHub の Issues で質問してください。

### Q5: 本番環境に適用できますか？

A: 本ハンズオンは学習目的で設計されていますが、原則は本番環境にも適用できます。ただし、本番環境に適用する際は、セキュリティ要件、コンプライアンス、組織のポリシーなどを十分に考慮してください。

### Q6: 他の IaC ツール（Terraform 等）は使えますか？

A: 本ハンズオンは Bicep を使用していますが、概念は同じです。Terraform に慣れている方は、Terraform で実装することも可能です。

---

## 参考リンク

### Microsoft 公式ドキュメント

- [Cloud Adoption Framework](https://docs.microsoft.com/azure/cloud-adoption-framework/)
- [Azure Landing Zones](https://docs.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)
- [Enterprise-Scale Architecture](https://docs.microsoft.com/azure/cloud-adoption-framework/ready/enterprise-scale/)
- [Azure Bicep Documentation](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure Policy Documentation](https://docs.microsoft.com/azure/governance/policy/)

### 追加リソース

- [Azure Architecture Center](https://docs.microsoft.com/azure/architecture/)
- [Azure Quickstart Templates](https://github.com/Azure/azure-quickstart-templates)
- [Azure Verified Modules](https://aka.ms/avm)

---

## 免責事項

- 本ハンズオンで作成したリソースによる課金については、各自の責任で管理してください
- 本ハンズオンの内容は執筆時点（2026 年 1 月）のものです。Azure のサービスは常に進化しているため、最新の情報は公式ドキュメントを参照してください
- 本ハンズオンは教育目的であり、特定の構成を推奨するものではありません

---

## さあ、始めましょう！

準備ができたら、[第 1 章：イントロダクションと CAF 概要](chapters/chapter01-introduction.md)から開始してください。

---

**最終更新**: 2026 年 1 月 7 日
