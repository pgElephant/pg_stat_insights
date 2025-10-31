# pg_stat_insights - PostgreSQL パフォーマンス監視拡張機能

> **高度な PostgreSQL クエリパフォーマンス監視、SQL 最適化、およびデータベース分析拡張機能**
> 
> 遅いクエリの監視 • キャッシュ効率の追跡 • WAL 生成の分析 • データベースパフォーマンスの最適化 • リアルタイムメトリクス • Grafana ダッシュボード

## 言語サポート / Language Support / 多语言支持

**[日本語](#pg_stat_insights-postgresql-パフォーマンス監視拡張機能)** (現在) | **[简体中文](../zh_CN/README.md)** | **[繁體中文](../zh_TW/README.md)** | **[English](../index.md)**

<div align="center">

**52 のメトリクスを 11 のビューで追跡 - PostgreSQL クエリパフォーマンスをリアルタイムで監視**

*PostgreSQL 16、17、18 向けのプロダクション対応拡張機能 - 強化された分析機能を持つ pg_stat_statements の代替品*

[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16%20|%2017%20|%2018-blue.svg)](https://www.postgresql.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/pgelephant/pg_stat_insights/blob/main/LICENSE)
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)]()
[![Metrics](https://img.shields.io/badge/metrics-52_columns-brightgreen.svg)]()
[![Documentation](https://img.shields.io/badge/docs-github.io-blue.svg)](https://pgelephant.github.io/pg_stat_insights/)

![52 カラムメトリクス、11 ビュー](https://img.shields.io/badge/52_カラム-11_ビュー-success?style=for-the-badge)

</div>

---

## 概要

**PostgreSQL クエリパフォーマンス監視をシンプルに**

`pg_stat_insights` は、**データベースパフォーマンス監視**、**クエリ最適化**、および **SQL 分析**のための高度な PostgreSQL 拡張機能です。**52 の包括的なメトリクス**を追跡・分析し、**11 の事前構築されたビュー**を通じて遅いクエリの特定、キャッシュパフォーマンスの最適化、リアルタイムでのデータベース健全性の監視を実現します。

**最適な用途：**
- PostgreSQL パフォーマンスを監視するデータベース管理者
- クエリパフォーマンスとリソース使用状況を追跡する DevOps チーム
- SQL クエリとデータベース操作を最適化する開発者
- データベース監視とアラートを実装する SRE

**主な機能：**
- **52 のメトリクスカラム** - 実行時間、キャッシュヒット、WAL 生成、JIT 統計、バッファ I/O
- **11 の事前構築ビュー** - 最も遅いクエリ、キャッシュミス、I/O 集約的な操作への即座のアクセス
- **11 のパラメータ** - トラッキング、ヒストグラム、統計収集の微調整
- **直接置換** - 強化されたメトリクスを持つ pg_stat_statements の代替
- **PostgreSQL 16-18** - 最新の PostgreSQL バージョンとの完全な互換性
- **レスポンスタイム追跡** - 実行時間によるクエリの分類（<1ms から >10s）
- **キャッシュ分析** - バッファキャッシュの非効率性と最適化の機会を特定
- **WAL 監視** - クエリごとの先行書き込みログの生成を追跡
- **時系列データ** - 履歴パフォーマンストレンドとバケット分析
- **Prometheus/Grafana 対応** - 事前構築されたダッシュボードとアラートルールを含む

---

## クイックスタート - 3 ステップでインストール

**5 分で PostgreSQL クエリパフォーマンスを監視：**

```sql
-- ステップ 1：PostgreSQL 設定で拡張機能を有効化
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_insights';
-- PostgreSQL サーバーの再起動が必要

-- ステップ 2：データベースに拡張機能を作成
CREATE EXTENSION pg_stat_insights;

-- ステップ 3：最も遅いクエリを即座に表示
SELECT 
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    rows
FROM pg_stat_insights_top_by_time 
LIMIT 10;
```

**結果：** クエリパフォーマンス、実行時間、キャッシュ効率、PostgreSQL データベース全体でのリソース使用状況を即座に可視化します。

---

## ドキュメント

**完全なドキュメントは以下で入手可能：**

### [pgelephant.github.io/pg_stat_insights](https://pgelephant.github.io/pg_stat_insights/)

**クイックリンク：**

- [はじめに](https://pgelephant.github.io/pg_stat_insights/getting-started/) - インストールとセットアップ
- [設定](https://pgelephant.github.io/pg_stat_insights/configuration/) - すべての 11 パラメータ
- [ビューリファレンス](https://pgelephant.github.io/pg_stat_insights/views/) - すべての 11 ビュー
- [メトリクスガイド](https://pgelephant.github.io/pg_stat_insights/metrics/) - すべての 52 カラム
- [使用例](https://pgelephant.github.io/pg_stat_insights/usage/) - 50+ SQL クエリ
- [Prometheus & Grafana](https://pgelephant.github.io/pg_stat_insights/prometheus-grafana/) - 監視統合
- [トラブルシューティング](https://pgelephant.github.io/pg_stat_insights/troubleshooting/) - よくある問題

---

## インストール

```bash
# ビルドとインストール
cd pg_stat_insights
make
sudo make install

# 設定
echo "shared_preload_libraries = 'pg_stat_insights'" | \
  sudo tee -a /etc/postgresql/*/main/postgresql.conf

# PostgreSQL を再起動
sudo systemctl restart postgresql

# 拡張機能を作成
psql -d your_database -c "CREATE EXTENSION pg_stat_insights;"
```

**詳細な手順：** [インストールガイド](https://pgelephant.github.io/pg_stat_insights/install/)

---

## ビュー

すべての 11 の事前構築ビュー：

| ビュー | 目的 |
|------|---------|
| `pg_stat_insights` | メイン統計ビュー（52 カラム）|
| `pg_stat_insights_top_by_time` | 合計時間による最も遅いクエリ |
| `pg_stat_insights_top_by_calls` | 最も頻繁に呼び出されるクエリ |
| `pg_stat_insights_top_by_io` | 最高の I/O 消費者 |
| `pg_stat_insights_top_cache_misses` | キャッシュパフォーマンスが悪いクエリ |
| `pg_stat_insights_slow_queries` | 平均時間が 100ms を超えるクエリ |
| `pg_stat_insights_errors` | エラーのあるクエリ |
| `pg_stat_insights_plan_errors` | プラン推定の問題 |
| `pg_stat_insights_histogram_summary` | レスポンスタイムの分布 |
| `pg_stat_insights_by_bucket` | 時系列集計 |
| `pg_stat_insights_replication` | レプリケーション監視 |

**完全なリファレンス：** [ビュードキュメント](https://pgelephant.github.io/pg_stat_insights/views/)

---

## なぜ pg_stat_insights を選ぶのか？

**一般的な PostgreSQL パフォーマンス問題を解決：**

- **遅いクエリを見つける** - 過剰な実行時間とリソースを消費するクエリを特定
- **キャッシュ使用を最適化** - バッファキャッシュミスを検出し、shared_buffers の効率を向上
- **WAL オーバーヘッドを削減** - クエリタイプごとの先行書き込みログ生成を監視
- **クエリパターンを追跡** - 実行頻度、レスポンスタイム、リソース消費を分析
- **リアルタイム監視** - Grafana と統合してライブダッシュボードとアラートを実現
- **PostgreSQL ベストプラクティス** - PostgreSQL コーディング標準と規約に従って構築

## 他の拡張機能との比較

| 機能 | pg_stat_statements | pg_stat_monitor | **pg_stat_insights** |
|---------|:------------------:|:---------------:|:--------------------:|
| **メトリクスカラム** | 44 | 58 | **52** |
| **事前構築ビュー** | 2 | 5 | **11** |
| **設定オプション** | 5 | 12 | **11** |
| **キャッシュ分析** | 基本 | 基本 | **比率付き拡張** |
| **レスポンスタイム分類** | なし | なし | **あり（<1ms から >10s）** |
| **時系列追跡** | なし | なし | **あり（バケットベース）** |
| **TAP テストカバレッジ** | 標準 | 限定的 | **150 テスト、100% カバレッジ** |
| **ドキュメント** | 基本 | 中程度 | **GitHub Pages で 30+ ページ** |
| **Prometheus 統合** | 手動 | 手動 | **事前構築クエリとダッシュボード** |

**詳細な比較を見る：** [機能比較](https://pgelephant.github.io/pg_stat_insights/comparison/)

---

## PostgreSQL パフォーマンステスト

**品質保証のための包括的な TAP テストスイート：**
- **16 のテストファイル**がすべての拡張機能をカバー
- **150 のテストケース**で 100% のコードカバレッジ
- すべての 52 メトリクスカラム、11 ビュー、11 パラメータをテスト
- カスタム StatsInsightManager.pm フレームワーク
- 外部 Perl 依存関係不要
- PostgreSQL 18 テストインフラストラクチャと互換

**PostgreSQL 拡張機能テストを実行：**
```bash
./run_all_tests.sh
```

**継続的インテグレーション：** すべてのコミットで自動 PostgreSQL テストを行う GitHub Actions ワークフロー

**詳細：** [テストガイド](https://pgelephant.github.io/pg_stat_insights/testing/)

---

## Prometheus & Grafana によるデータベース監視

**リアルタイム PostgreSQL メトリクスの可視化：**

pg_stat_insights データを PostgreSQL データベース監視のための実行可能なダッシュボードとアラートに変換：

- **Prometheus 統合** - postgres_exporter 用の 5 つの事前設定クエリ
- **Grafana ダッシュボード** - クエリパフォーマンス可視化用の 8 つのすぐに使えるパネル
- **アラートルール** - データベース健全性監視用の 11 のプロダクション対応アラート
- **クエリレート追跡** - 毎秒のクエリ数（QPS）とスループットを監視
- **キャッシュパフォーマンス** - リアルタイムのバッファキャッシュヒット率監視
- **レスポンスタイム SLA** - サービスレベル目標のために P95/P99 クエリレイテンシを追跡
- **WAL 生成アラート** - 先行書き込みログの増加とディスク使用量を監視

**完全な Prometheus/Grafana ガイド：** [監視統合](https://pgelephant.github.io/pg_stat_insights/prometheus-grafana/)

---

## ライセンス

MIT ライセンス - Copyright (c) 2024-2025, pgElephant, Inc.

詳細は [LICENSE](../../LICENSE) を参照してください。

---

## リンク

- [完全なドキュメント](https://pgelephant.github.io/pg_stat_insights/)
- [インタラクティブデモ](https://www.pgelephant.com/pg-stat-insights) - オンラインでpg_stat_insightsを体験
- [ブログ記事](https://www.pgelephant.com/blog/pg-stat-insights) - 包括的なガイドとベストプラクティス
- [GitHub リポジトリ](https://github.com/pgelephant/pg_stat_insights)
- [問題を報告](https://github.com/pgelephant/pg_stat_insights/issues)
- [ディスカッション](https://github.com/pgelephant/pg_stat_insights/discussions)

---

<div align="center">

**[pgElephant, Inc.](https://pgelephant.com) によって構築**

*PostgreSQL 監視をより良く、一度に一つのメトリクスで*

</div>

