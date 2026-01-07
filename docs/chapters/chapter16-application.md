# 第 16 章：アプリケーション開発・デプロイ

> **⚠️ 4日目以降の作業**  
> Container Apps へのデプロイには Landing Zone の構築（第 15 章）が完了している必要があります。

## 本章の目的

本章では、Next.js + TypeScript + Tailwind CSS で Web アプリケーションを開発し、Azure Container Apps にデプロイします。PostgreSQL と Redis を統合し、完全な 3 層アーキテクチャを実現します。

**所要時間**: 約 4-5 時間  
**難易度**: ⭐⭐⭐⭐

---

## 16.1 アプリケーションアーキテクチャ

### 16.1.1 3 層アーキテクチャ

```mermaid
graph TB
    User[ユーザー]

    subgraph "Presentation Layer"
        NextJS[Next.js<br/>TypeScript + Tailwind CSS]
    end

    subgraph "Application Layer"
        API[API Routes<br/>Server Components]
        Cache[Redis Cache]
    end

    subgraph "Data Layer"
        PostgreSQL[PostgreSQL<br/>Flexible Server]
    end

    User -->|HTTPS| NextJS
    NextJS --> API
    API --> Cache
    API --> PostgreSQL
    Cache -.->|Cache Miss| PostgreSQL

    style Presentation Layer fill:#e1f5ff
    style Application Layer fill:#fff4e1
    style Data Layer fill:#e8f5e9
```

### 16.1.2 アプリケーション機能

本ハンズオンで構築するアプリケーション：

- **タスク管理アプリ**
  - タスクの作成・一覧・編集・削除（CRUD）
  - PostgreSQL にデータ保存
  - Redis でキャッシュ
  - Next.js 14 App Router
  - Server Actions 使用

---

## 16.2 Next.js プロジェクトの作成

### 16.2.1 プロジェクト初期化

```bash
# appディレクトリを作成
mkdir -p app
cd app

# Next.jsプロジェクトを作成
npx create-next-app@latest . \
  --typescript \
  --tailwind \
  --app \
  --src-dir \
  --import-alias "@/*" \
  --no-eslint

# 必要なパッケージをインストール
npm install pg ioredis
npm install --save-dev @types/pg

# 環境変数ファイルを作成
cat << 'EOF' > .env.local
# Database
DATABASE_URL=postgresql://psqladmin:P%40ssw0rd1234%21@psql-app1-prod-jpe-001.postgres.database.azure.com:5432/appdb?sslmode=require

# Redis
REDIS_HOST=redis-app1-prod-jpe-001.redis.cache.windows.net
REDIS_PORT=6380
REDIS_PASSWORD=your-redis-primary-key
REDIS_TLS=true

# Application
NEXT_PUBLIC_APP_NAME=CAF Task Manager
EOF

echo ".env.local" >> .gitignore
```

### 16.2.2 データベース接続モジュール

```bash
mkdir -p src/lib

cat << 'EOF' > src/lib/db.ts
import { Pool } from 'pg';

// PostgreSQL接続プール
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false, // Azure PostgreSQLでは必要
  },
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

export async function query(text: string, params?: any[]) {
  const start = Date.now();
  const res = await pool.query(text, params);
  const duration = Date.now() - start;
  console.log('Executed query', { text, duration, rows: res.rowCount });
  return res;
}

export default pool;
EOF
```

### 16.2.3 Redis クライアントモジュール

```bash
cat << 'EOF' > src/lib/redis.ts
import Redis from 'ioredis';

// Redis接続
const redis = new Redis({
  host: process.env.REDIS_HOST,
  port: parseInt(process.env.REDIS_PORT || '6380'),
  password: process.env.REDIS_PASSWORD,
  tls: process.env.REDIS_TLS === 'true' ? {} : undefined,
  retryStrategy: (times) => {
    const delay = Math.min(times * 50, 2000);
    return delay;
  },
});

redis.on('error', (err) => {
  console.error('Redis Client Error', err);
});

redis.on('connect', () => {
  console.log('Redis Client Connected');
});

export default redis;
EOF
```

---

## 16.3 データベーススキーマの作成

### 16.3.1 マイグレーションスクリプト

```bash
mkdir -p database/migrations

cat << 'EOF' > database/migrations/001_create_tasks_table.sql
-- Tasks table
CREATE TABLE IF NOT EXISTS tasks (
  id SERIAL PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  status VARCHAR(50) DEFAULT 'pending',
  priority VARCHAR(50) DEFAULT 'medium',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for status
CREATE INDEX idx_tasks_status ON tasks(status);

-- Index for created_at
CREATE INDEX idx_tasks_created_at ON tasks(created_at DESC);

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_tasks_updated_at
  BEFORE UPDATE ON tasks
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Sample data
INSERT INTO tasks (title, description, status, priority) VALUES
  ('Setup Azure Landing Zone', 'Complete CAF Landing Zone setup', 'completed', 'high'),
  ('Deploy Application', 'Deploy Next.js app to Container Apps', 'in-progress', 'high'),
  ('Configure Monitoring', 'Setup alerts and dashboards', 'pending', 'medium');
EOF

# マイグレーション実行スクリプト
cat << 'EOF' > database/migrate.sh
#!/bin/bash
set -e

echo "Running database migrations..."

# PostgreSQL接続情報（環境変数から取得）
PGHOST="${DATABASE_HOST:-psql-app1-prod-jpe-001.postgres.database.azure.com}"
PGPORT="${DATABASE_PORT:-5432}"
PGDATABASE="${DATABASE_NAME:-appdb}"
PGUSER="${DATABASE_USER:-psqladmin}"
PGPASSWORD="${DATABASE_PASSWORD}"

export PGPASSWORD

# マイグレーションファイルを実行
for file in database/migrations/*.sql; do
  echo "Applying migration: $file"
  psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -f "$file"
done

echo "Migrations completed successfully!"
EOF

chmod +x database/migrate.sh
```

---

## 16.4 API ルートの実装

### 16.4.1 Task API（GET）

```bash
mkdir -p src/app/api/tasks

cat << 'EOF' > src/app/api/tasks/route.ts
import { NextResponse } from 'next/server';
import { query } from '@/lib/db';
import redis from '@/lib/redis';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    // Redisキャッシュをチェック
    const cacheKey = 'tasks:all';
    const cached = await redis.get(cacheKey);

    if (cached) {
      console.log('Cache hit for tasks');
      return NextResponse.json(JSON.parse(cached));
    }

    // キャッシュミス - DBから取得
    console.log('Cache miss for tasks - fetching from DB');
    const result = await query(
      'SELECT * FROM tasks ORDER BY created_at DESC'
    );

    // キャッシュに保存（60秒）
    await redis.setex(cacheKey, 60, JSON.stringify(result.rows));

    return NextResponse.json(result.rows);
  } catch (error) {
    console.error('Error fetching tasks:', error);
    return NextResponse.json(
      { error: 'Failed to fetch tasks' },
      { status: 500 }
    );
  }
}

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { title, description, status, priority } = body;

    // バリデーション
    if (!title) {
      return NextResponse.json(
        { error: 'Title is required' },
        { status: 400 }
      );
    }

    // DBに挿入
    const result = await query(
      'INSERT INTO tasks (title, description, status, priority) VALUES ($1, $2, $3, $4) RETURNING *',
      [title, description, status || 'pending', priority || 'medium']
    );

    // キャッシュを無効化
    await redis.del('tasks:all');

    return NextResponse.json(result.rows[0], { status: 201 });
  } catch (error) {
    console.error('Error creating task:', error);
    return NextResponse.json(
      { error: 'Failed to create task' },
      { status: 500 }
    );
  }
}
EOF
```

### 16.4.2 Task API（PUT/DELETE）

```bash
cat << 'EOF' > src/app/api/tasks/[id]/route.ts
import { NextResponse } from 'next/server';
import { query } from '@/lib/db';
import redis from '@/lib/redis';

export async function GET(
  request: Request,
  { params }: { params: { id: string } }
) {
  try {
    const { id } = params;

    const result = await query(
      'SELECT * FROM tasks WHERE id = $1',
      [id]
    );

    if (result.rows.length === 0) {
      return NextResponse.json(
        { error: 'Task not found' },
        { status: 404 }
      );
    }

    return NextResponse.json(result.rows[0]);
  } catch (error) {
    console.error('Error fetching task:', error);
    return NextResponse.json(
      { error: 'Failed to fetch task' },
      { status: 500 }
    );
  }
}

export async function PUT(
  request: Request,
  { params }: { params: { id: string } }
) {
  try {
    const { id } = params;
    const body = await request.json();
    const { title, description, status, priority } = body;

    const result = await query(
      'UPDATE tasks SET title = $1, description = $2, status = $3, priority = $4 WHERE id = $5 RETURNING *',
      [title, description, status, priority, id]
    );

    if (result.rows.length === 0) {
      return NextResponse.json(
        { error: 'Task not found' },
        { status: 404 }
      );
    }

    // キャッシュを無効化
    await redis.del('tasks:all');

    return NextResponse.json(result.rows[0]);
  } catch (error) {
    console.error('Error updating task:', error);
    return NextResponse.json(
      { error: 'Failed to update task' },
      { status: 500 }
    );
  }
}

export async function DELETE(
  request: Request,
  { params }: { params: { id: string } }
) {
  try {
    const { id } = params;

    const result = await query(
      'DELETE FROM tasks WHERE id = $1 RETURNING *',
      [id]
    );

    if (result.rows.length === 0) {
      return NextResponse.json(
        { error: 'Task not found' },
        { status: 404 }
      );
    }

    // キャッシュを無効化
    await redis.del('tasks:all');

    return NextResponse.json({ message: 'Task deleted successfully' });
  } catch (error) {
    console.error('Error deleting task:', error);
    return NextResponse.json(
      { error: 'Failed to delete task' },
      { status: 500 }
    );
  }
}
EOF
```

---

## 16.5 フロントエンドの実装

### 16.5.1 ホームページ

```bash
cat << 'EOF' > src/app/page.tsx
import Link from 'next/link';

export default function Home() {
  return (
    <main className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      <div className="container mx-auto px-4 py-16">
        <div className="text-center">
          <h1 className="text-5xl font-bold text-gray-900 mb-6">
            🚀 CAF Task Manager
          </h1>
          <p className="text-xl text-gray-700 mb-12 max-w-2xl mx-auto">
            Azure Cloud Adoption Framework Landing Zone上で動作する
            タスク管理アプリケーション
          </p>

          <div className="grid md:grid-cols-3 gap-8 mb-12">
            <div className="bg-white p-6 rounded-lg shadow-lg">
              <div className="text-4xl mb-4">🏗️</div>
              <h3 className="text-lg font-bold mb-2">Hub-Spoke Architecture</h3>
              <p className="text-gray-600">
                Azure Firewall、Bastionを含む完全なHub-Spoke構成
              </p>
            </div>

            <div className="bg-white p-6 rounded-lg shadow-lg">
              <div className="text-4xl mb-4">🔒</div>
              <h3 className="text-lg font-bold mb-2">Zero Trust Security</h3>
              <p className="text-gray-600">
                Private Endpoint、NSG、Firewallルールによる多層防御
              </p>
            </div>

            <div className="bg-white p-6 rounded-lg shadow-lg">
              <div className="text-4xl mb-4">📊</div>
              <h3 className="text-lg font-bold mb-2">Observability</h3>
              <p className="text-gray-600">
                Log Analytics、Application Insightsによる完全な可観測性
              </p>
            </div>
          </div>

          <Link
            href="/tasks"
            className="inline-block bg-indigo-600 text-white px-8 py-4 rounded-lg text-lg font-semibold hover:bg-indigo-700 transition"
          >
            タスク管理を開始
          </Link>
        </div>
      </div>
    </main>
  );
}
EOF
```

### 16.5.2 タスク一覧ページ

```bash
mkdir -p src/app/tasks

cat << 'EOF' > src/app/tasks/page.tsx
'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';

interface Task {
  id: number;
  title: string;
  description: string;
  status: string;
  priority: string;
  created_at: string;
}

export default function TasksPage() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [loading, setLoading] = useState(true);
  const [newTask, setNewTask] = useState({ title: '', description: '', status: 'pending', priority: 'medium' });

  useEffect(() => {
    fetchTasks();
  }, []);

  const fetchTasks = async () => {
    try {
      const res = await fetch('/api/tasks');
      const data = await res.json();
      setTasks(data);
    } catch (error) {
      console.error('Error fetching tasks:', error);
    } finally {
      setLoading(false);
    }
  };

  const createTask = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await fetch('/api/tasks', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newTask),
      });
      setNewTask({ title: '', description: '', status: 'pending', priority: 'medium' });
      fetchTasks();
    } catch (error) {
      console.error('Error creating task:', error);
    }
  };

  const deleteTask = async (id: number) => {
    if (!confirm('本当に削除しますか？')) return;
    try {
      await fetch(`/api/tasks/${id}`, { method: 'DELETE' });
      fetchTasks();
    } catch (error) {
      console.error('Error deleting task:', error);
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'completed': return 'bg-green-100 text-green-800';
      case 'in-progress': return 'bg-blue-100 text-blue-800';
      case 'pending': return 'bg-yellow-100 text-yellow-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  };

  const getPriorityColor = (priority: string) => {
    switch (priority) {
      case 'high': return 'bg-red-100 text-red-800';
      case 'medium': return 'bg-orange-100 text-orange-800';
      case 'low': return 'bg-green-100 text-green-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="container mx-auto px-4 py-8">
        <div className="mb-8">
          <Link href="/" className="text-indigo-600 hover:text-indigo-800">
            ← ホームに戻る
          </Link>
          <h1 className="text-3xl font-bold text-gray-900 mt-4">タスク管理</h1>
        </div>

        {/* 新規タスク作成フォーム */}
        <div className="bg-white p-6 rounded-lg shadow mb-8">
          <h2 className="text-xl font-bold mb-4">新規タスク作成</h2>
          <form onSubmit={createTask} className="space-y-4">
            <div>
              <input
                type="text"
                placeholder="タスク名"
                className="w-full px-4 py-2 border rounded-lg"
                value={newTask.title}
                onChange={(e) => setNewTask({ ...newTask, title: e.target.value })}
                required
              />
            </div>
            <div>
              <textarea
                placeholder="説明"
                className="w-full px-4 py-2 border rounded-lg"
                value={newTask.description}
                onChange={(e) => setNewTask({ ...newTask, description: e.target.value })}
                rows={3}
              />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <select
                className="px-4 py-2 border rounded-lg"
                value={newTask.status}
                onChange={(e) => setNewTask({ ...newTask, status: e.target.value })}
              >
                <option value="pending">保留中</option>
                <option value="in-progress">進行中</option>
                <option value="completed">完了</option>
              </select>
              <select
                className="px-4 py-2 border rounded-lg"
                value={newTask.priority}
                onChange={(e) => setNewTask({ ...newTask, priority: e.target.value })}
              >
                <option value="low">低</option>
                <option value="medium">中</option>
                <option value="high">高</option>
              </select>
            </div>
            <button
              type="submit"
              className="w-full bg-indigo-600 text-white px-6 py-2 rounded-lg hover:bg-indigo-700"
            >
              作成
            </button>
          </form>
        </div>

        {/* タスク一覧 */}
        {loading ? (
          <div className="text-center py-12">読み込み中...</div>
        ) : (
          <div className="space-y-4">
            {tasks.map((task) => (
              <div key={task.id} className="bg-white p-6 rounded-lg shadow">
                <div className="flex justify-between items-start mb-2">
                  <h3 className="text-lg font-bold">{task.title}</h3>
                  <button
                    onClick={() => deleteTask(task.id)}
                    className="text-red-600 hover:text-red-800"
                  >
                    削除
                  </button>
                </div>
                <p className="text-gray-600 mb-4">{task.description}</p>
                <div className="flex gap-2">
                  <span className={`px-3 py-1 rounded-full text-sm ${getStatusColor(task.status)}`}>
                    {task.status}
                  </span>
                  <span className={`px-3 py-1 rounded-full text-sm ${getPriorityColor(task.priority)}`}>
                    {task.priority}
                  </span>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
EOF
```

---

## 16.6 Dockerfile の作成

### 16.6.1 Multi-stage Dockerfile

```bash
cat << 'EOF' > Dockerfile
# Stage 1: Dependencies
FROM node:20-alpine AS deps
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

# Stage 2: Builder
FROM node:20-alpine AS builder
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build
RUN npm run build

# Stage 3: Runner
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV production

# Add non-root user
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000

CMD ["node", "server.js"]
EOF

# .dockerignoreを作成
cat << 'EOF' > .dockerignore
node_modules
.next
.git
.gitignore
README.md
.env.local
.DS_Store
EOF
```

### 16.6.2 next.config.js の設定

```bash
cat << 'EOF' > next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  experimental: {
    serverActions: {
      allowedOrigins: ['*']
    }
  }
}

module.exports = nextConfig
EOF
```

---

## 16.7 Azure Container Apps へのデプロイ

### 16.7.1 コンテナイメージのビルドとプッシュ

```bash
# ACRにログイン
az acr login --name acrcafapp1prodjpe001

# イメージをビルド
docker build -t acrcafapp1prodjpe001.azurecr.io/task-manager:v1.0.0 .

# イメージをプッシュ
docker push acrcafapp1prodjpe001.azurecr.io/task-manager:v1.0.0
```

### 16.7.2 Container App Bicep モジュール

```bash
cat << 'EOF' > infrastructure/bicep/modules/compute/container-app.bicep
@description('Container Appの名前')
param appName string

@description('デプロイ先のリージョン')
param location string

@description('Container Apps Environment ID')
param environmentId string

@description('コンテナイメージ')
param containerImage string

@description('Container Registry')
param registryServer string

@description('環境変数')
param environmentVariables array = []

@description('タグ')
param tags object = {}

// Container App
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: appName
  location: location
  tags: tags
  properties: {
    environmentId: environmentId
    configuration: {
      ingress: {
        external: true
        targetPort: 3000
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: registryServer
          identity: 'system'
        }
      ]
    }
    template: {
      containers: [
        {
          name: appName
          image: containerImage
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: environmentVariables
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

output appId string = containerApp.id
output appName string = containerApp.name
output appUrl string = containerApp.properties.configuration.ingress.fqdn
EOF
```

### 16.7.3 Container App のデプロイ

```bash
# Redis Primary Keyを取得
REDIS_PASSWORD=$(az redis list-keys \
  --name redis-app1-prod-jpe-001 \
  --resource-group rg-landingzone-app1-prod-jpe-001 \
  --query primaryKey -o tsv)

# Container Apps EnvironmentのIDを取得
CAE_ID=$(az containerapp env show \
  --name cae-app1-prod-jpe-001 \
  --resource-group rg-landingzone-app1-prod-jpe-001 \
  --query id -o tsv)

# デプロイ
az deployment group create \
  --name "container-app-deployment-$(date +%Y%m%d-%H%M%S)" \
  --resource-group rg-landingzone-app1-prod-jpe-001 \
  --template-file infrastructure/bicep/modules/compute/container-app.bicep \
  --parameters \
    appName=ca-taskmanager-prod-jpe-001 \
    location=japaneast \
    environmentId="$CAE_ID" \
    containerImage=acrcafapp1prodjpe001.azurecr.io/task-manager:v1.0.0 \
    registryServer=acrcafapp1prodjpe001.azurecr.io \
    environmentVariables="[
      {\"name\":\"DATABASE_URL\",\"value\":\"postgresql://psqladmin:P%40ssw0rd1234%21@psql-app1-prod-jpe-001.postgres.database.azure.com:5432/appdb?sslmode=require\"},
      {\"name\":\"REDIS_HOST\",\"value\":\"redis-app1-prod-jpe-001.redis.cache.windows.net\"},
      {\"name\":\"REDIS_PORT\",\"value\":\"6380\"},
      {\"name\":\"REDIS_PASSWORD\",\"value\":\"$REDIS_PASSWORD\"},
      {\"name\":\"REDIS_TLS\",\"value\":\"true\"}
    ]"
```

---

## 16.8 GitHub Actions での自動デプロイ

### 16.8.1 アプリデプロイワークフロー

```bash
cat << 'EOF' > .github/workflows/deploy-app.yml
name: Deploy Application

on:
  push:
    branches: [main]
    paths:
      - 'app/**'
      - '.github/workflows/deploy-app.yml'
  workflow_dispatch:

permissions:
  contents: read
  id-token: write

jobs:
  build-and-deploy:
    name: Build and Deploy App
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: ACR Login
        run: az acr login --name acrcafapp1prodjpe001

      - name: Build and Push Docker Image
        run: |
          cd app
          IMAGE_TAG="v$(date +%Y%m%d-%H%M%S)"
          docker build -t acrcafapp1prodjpe001.azurecr.io/task-manager:$IMAGE_TAG .
          docker push acrcafapp1prodjpe001.azurecr.io/task-manager:$IMAGE_TAG
          echo "IMAGE_TAG=$IMAGE_TAG" >> $GITHUB_ENV

      - name: Update Container App
        run: |
          az containerapp update \
            --name ca-taskmanager-prod-jpe-001 \
            --resource-group rg-landingzone-app1-prod-jpe-001 \
            --image acrcafapp1prodjpe001.azurecr.io/task-manager:${{ env.IMAGE_TAG }}

      - name: Get App URL
        run: |
          APP_URL=$(az containerapp show \
            --name ca-taskmanager-prod-jpe-001 \
            --resource-group rg-landingzone-app1-prod-jpe-001 \
            --query properties.configuration.ingress.fqdn -o tsv)
          echo "✅ Application deployed successfully!"
          echo "🌐 URL: https://$APP_URL"
EOF
```

---

## 16.9 Azure Portal での確認

1. Azure ポータルで「Container Apps」を開く
2. 「ca-taskmanager-prod-jpe-001」をクリック
3. 「Application Url」でアプリケーションにアクセス
4. タスクの作成・削除をテスト

---

## 16.10 Git へのコミット

```bash
git add .
git commit -m "Chapter 14: Application development and deployment

- Created Next.js 14 app with TypeScript and Tailwind CSS
- Implemented Task Manager with CRUD operations
- Integrated PostgreSQL and Redis
- Created Dockerfile with multi-stage build
- Deployed to Azure Container Apps
- Created GitHub Actions workflow for auto-deployment
- Completed full 3-tier architecture"

git push origin main
```

---

## 16.11 章のまとめ

本章で構築したもの：

1. ✅ Next.js アプリケーション

   - TypeScript + Tailwind CSS
   - App Router
   - Server Actions

2. ✅ PostgreSQL 統合

   - Connection Pool
   - CRUD 操作

3. ✅ Redis Cache

   - キャッシュ戦略
   - キャッシュ無効化

4. ✅ Docker 化

   - Multi-stage build
   - 最小イメージサイズ

5. ✅ Container Apps デプロイ
   - VNet 統合
   - Auto-scaling
   - CI/CD 自動化

---

## 次のステップ

アプリケーションのデプロイが完了しました。次は CI/CD パイプラインを構築します。

👉 [第 17 章：CI/CD パイプライン構築](chapter17-cicd.md)

---

**最終更新**: 2026 年 1 月 7 日
