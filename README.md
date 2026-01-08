# Azure CAF ランディングゾーン 完全ハンズオン

## 概要

このリポジトリは、Microsoft Cloud Adoption Framework (CAF) に基づいた、Azure ランディングゾーンアーキテクチャの完全なハンズオン教材です。Azure 初心者が、実際の企業環境で使用される本格的なランディングゾーンを、ゼロから構築できるように設計されています。

## 学習目標

本ハンズオンを完了することで、以下のスキルと知識を習得できます：

- Microsoft CAF のランディングゾーンアーキテクチャの完全な理解
- エンタープライズグレードの Azure 環境の設計と構築
- Infrastructure as Code (IaC) を使用したインフラ管理
- CI/CD パイプラインによる自動デプロイ
- Azure のガバナンス、セキュリティ、コンプライアンスの実装
- Hub-Spoke ネットワークトポロジーの構築
- Azure Policy を使用した組織ルールの適用
- 実際のアプリケーション（Next.js）のデプロイと運用

## 前提条件

### 必要なもの

- 新規作成した Azure アカウント（無料試用版でも可）
- GitHub アカウント
- GitHub Codespaces（このリポジトリで使用）
- 学習意欲と時間（目安：40-60 時間）

### 事前知識

必須ではありませんが、以下の知識があると理解が深まります：

- クラウドコンピューティングの基本概念
- ネットワークの基礎知識
- Git/GitHub の基本操作

## ハンズオンの進め方

1. このリポジトリをフォークまたはクローン
2. GitHub Codespaces で開発環境を起動
3. [ハンズオン本編](docs/handson-main.md) に従って順番に作業
4. 各章を完了したら、Git でコミット・プッシュ
5. Azure ポータルで動作確認

## 構成内容

### ドキュメント構成

```
docs/
├── handson-main.md                    # メインハンズオン文書（全体の目次）
└── chapters/                          # 各章の詳細ハンズオン
    ├── chapter01-introduction.md      # 第1章：イントロダクションと CAF 概要
    ├── chapter02-prerequisites.md     # 第2章：前提条件と環境準備
    ├── chapter03-caf-overview.md      # 第3章：CAF ランディングゾーン詳細
    ├── chapter04-setup.md             # 第4章：Azure 環境の初期セットアップ
    ├── chapter05-management-groups.md # 第5章：Management Groups 設計・構築
    ├── chapter06-subscriptions.md     # 第6章：Subscriptions 設計・構築（1日目）
    ├── chapter07-monitoring.md        # 第7章：監視・ログ基盤構築（1日目）
    ├── chapter08-identity-subscription.md # 第8章：Identity Subscription 作成（2日目）
    ├── chapter09-iam.md               # 第9章：Identity & Access Management（IAM）設計（2日目）
    ├── chapter10-governance.md        # 第10章：ガバナンス・ポリシー実装（2日目）
    ├── chapter11-connectivity-subscription.md # 第11章：Connectivity Subscription 作成（3日目）
    ├── chapter12-security.md          # 第12章：Security 基盤構築（3日目）
    ├── chapter13-networking-hub.md    # 第13章：Hub Network 構築（4日目以降）
    ├── chapter14-landingzone-subscription.md # 第14章：Landing Zone Subscription 作成（4日目以降）
    ├── chapter15-landing-zone.md      # 第15章：Landing Zone（Spoke）構築
    ├── chapter16-application.md       # 第16章：アプリケーション開発・デプロイ
    ├── chapter17-cicd.md              # 第17章：CI/CD パイプライン構築
    └── chapter18-conclusion.md        # 第18章：まとめと次のステップ
```

### インフラストラクチャ構成

```
infrastructure/
├── bicep/                    # Bicep IaCテンプレート
│   ├── orchestration/       # オーケストレーション（統合デプロイ）
│   │   ├── main.bicep       # サブスクリプションスコープ統合
│   │   ├── main.bicepparam  # 統合パラメータファイル
│   │   ├── tenant.bicep     # テナントスコープ（Management Groups）
│   │   └── tenant.bicepparam # Management Groupsパラメータ
│   ├── modules/             # 再利用可能なモジュール
│   │   ├── management-groups/
│   │   ├── networking/
│   │   ├── security/
│   │   ├── monitoring/
│   │   └── resource-group/
│   └── parameters/          # 個別パラメータファイル（参考用）
└── policies/                # Azure Policyの定義
    ├── definitions/
    ├── initiatives/
    └── assignments/
```

### アプリケーション

```
app/                         # サンプルNext.jsアプリケーション
├── src/
├── public/
└── package.json
```

## アーキテクチャ概要

本ハンズオンで構築するランディングゾーンアーキテクチャ：

```
Root Management Group
├── Platform
│   ├── Management (監視・ログ)
│   ├── Connectivity (Hub Network)
│   └── Identity (ID管理)
├── Landing Zones
│   ├── Corp (内部アプリケーション用)
│   └── Online (インターネット向けアプリ用)
├── Sandbox (検証環境)
└── Decommissioned (廃止予定)
```

詳細なアーキテクチャ図は各章で提示します。

## 学習の流れ

### Phase 1: 基礎理解（第 1-4 章）

- CAF とランディングゾーンの概念理解
- Azure 環境の準備
- 開発環境のセットアップ

### Phase 2: プラットフォーム基盤（1 日目：第 5-7 章）

- Management Groups の階層構造作成
- Subscription 作成（Management）
- 監視・ログ基盤の実装

### Phase 3: Identity & ガバナンス（2 日目：第 8-10 章）

- Identity Subscription 作成
- IAM 設計と実装
- Azure Policy とガバナンス

### Phase 4: ネットワークとセキュリティ（3 日目：第 11-12 章）

- Connectivity Subscription 作成
- セキュリティ基盤の実装

### Phase 5: Hub Network 構築（4 日目以降：第 13-14 章）

- Hub VNet と Azure Firewall
- Landing Zone Subscription 作成

### Phase 6: アプリケーション実装（4 日目以降：第 15-18 章）

- Landing Zone（Spoke）の構築
- Next.js アプリケーションの開発
- CI/CD パイプラインの構築
- まとめと次のステップ

## 重要な注意事項

### コスト管理

本ハンズオンで作成するリソースには、Azure の利用料金が発生します：

- **推定月額コスト**: $50-150（使用状況により変動）
- **途中で学習を中断する場合**: リソースグループを削除してコスト削減が可能
- **再開時**: Bicep orchestration により 1 コマンドで復元可能
- 詳細は [第 4 章 4.8.5](docs/chapters/chapter04-setup.md#485-コスト削減のための一時削除と復帰) を参照

**コスト削減のポイント**：

- ✅ 学習を中断する際は Resource Group を削除（Management Groups と Subscription は無料なので残す）
- ✅ `orchestration/main.bicep` で冪等性のある再デプロイが可能
- ✅ 不要なリソースは速やかに削除してください

### セキュリティ

- **機密情報（パスワード、キー、トークンなど）は絶対に Git にコミットしないこと**
- `.gitignore` ファイルを適切に設定
- Azure Key Vault を使用した機密情報管理を実践

### トラブルシューティング

各章にトラブルシューティングセクションがあります。問題が発生した場合は、該当箇所を参照してください。

## サポート

質問や問題が発生した場合：

1. 各章の「よくある質問」セクションを確認
2. GitHub の Issues で質問
3. Azure の公式ドキュメントを参照

## ライセンス

このプロジェクトは MIT ライセンスの下で公開されています。

## 貢献

改善提案やバグ報告は、Pull Request または Issues でお願いします。

## はじめましょう

準備ができたら、[ハンズオン本編](docs/handson-main.md)から開始してください。

---

**最終更新**: 2026 年 1 月 7 日
