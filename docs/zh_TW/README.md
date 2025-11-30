# pg_stat_insights - PostgreSQL 效能監控擴充套件

> **進階 PostgreSQL 查詢效能監控、SQL 最佳化和資料庫分析擴充套件**
> 
> 監控慢查詢 • 追蹤快取效率 • 分析 WAL 產生 • 最佳化資料庫效能 • 即時指標 • Grafana 儀表板

## 語言支援 / Language Support / 多言語対応

**[繁體中文](#pg_stat_insights-postgresql-性能監控擴展)** (目前) | **[简体中文](../zh_CN/README.md)** | **[日本語](../ja_JP/README.md)** | **[English](../index.md)**

<div align="center">

**追蹤 52 個指標，42 個檢視 - 即時監控 PostgreSQL 查詢效能、複寫和索引**

*適用於 PostgreSQL 16、17、18 的生產就緒擴充套件 - pg_stat_statements 的增強型替代品*

[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16%20|%2017%20|%2018-blue.svg)](https://www.postgresql.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/pgelephant/pg_stat_insights/blob/main/LICENSE)
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)]()
[![Tests](https://img.shields.io/badge/tests-31%2F31%20passing-brightgreen.svg)]()
[![Metrics](https://img.shields.io/badge/metrics-52_columns-brightgreen.svg)]()
[![Documentation](https://img.shields.io/badge/docs-github.io-blue.svg)](https://pgelephant.github.io/pg_stat_insights/)
[![Version](https://img.shields.io/badge/version-3.0-blue.svg)]()

![52 欄指標，42 個檢視](https://img.shields.io/badge/52_欄-42_檢視-success?style=for-the-badge)

</div>

---

## 概述

**簡化 PostgreSQL 查詢效能監控**

`pg_stat_insights` 是一個進階的 PostgreSQL 擴充套件，用於**資料庫效能監控**、**查詢最佳化**、**複寫健康**和**索引分析**。追蹤和分析 **52 個綜合指標**，透過 **42 個預建檢視**識別慢查詢、最佳化快取效能、監控複寫健康（實體和邏輯）、偵測瓶頸、分析索引使用、識別缺失索引、追蹤索引膨脹，並即時除錯資料庫問題，包括時間序列桶分析。

**適用於：**
- 監控 PostgreSQL 效能的資料庫管理員
- 追蹤查詢效能和資源使用的 DevOps 團隊
- 最佳化 SQL 查詢和資料庫操作的開發人員
- 實施資料庫監控和警報的 SRE
- 分析索引效率和膨脹的效能工程師

**主要特性：**
- **52 個指標欄** - 執行時間、快取命中、WAL 產生、JIT 統計、緩衝區 I/O
- **42 個預建檢視** - 立即存取最慢查詢、快取未命中、I/O 密集型操作、全面的複寫監控（實體和邏輯）和瓶頸偵測、訂閱追蹤、發布管理、健康診斷、完整的索引監控和時間序列桶分析
- **11 個參數** - 微調追蹤、直方圖和統計收集
- **直接替換** pg_stat_statements，具有增強的指標
- **PostgreSQL 16-18** - 與 PostgreSQL 16、17 和 18 完全相容
- **回應時間追蹤** - 按執行時間對查詢進行分類（小於 1ms 到大於 10s）
- **複寫監控** - 17 個專門檢視用於實體和邏輯複寫健康、延遲追蹤和診斷
- **索引監控** - 11 個綜合檢視用於索引使用、膨脹、效率、維護、缺失索引和警報
- **快取分析** - 識別緩衝區快取低效率和最佳化機會
- **WAL 監控** - 追蹤每個查詢的預寫日誌產生
- **時間序列資料** - 查詢、索引和複寫的歷史效能趨勢和桶分析
- **Prometheus/Grafana 就緒** - 包含預建的儀表板和警報規則
- **31 個迴歸測試** - 所有功能的全面測試覆蓋

---

## 快速開始 - 3 步安裝

**在 5 分鐘內監控 PostgreSQL 查詢效能：**

```sql
-- 步驟 1：在 PostgreSQL 設定中啟用擴充套件
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_insights';
-- 需要重新啟動 PostgreSQL 伺服器

-- 步驟 2：在您的資料庫中建立擴充套件
CREATE EXTENSION pg_stat_insights;

-- 步驟 3：立即檢視最慢的查詢
SELECT 
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    rows
FROM pg_stat_insights_top_by_time 
LIMIT 10;
```

**結果：**立即了解查詢效能、執行時間、快取效率以及 PostgreSQL 資料庫中的資源使用情況。

---

## 文件

**完整文件可在以下位置取得：**

### [pgelephant.github.io/pg_stat_insights](https://pgelephant.github.io/pg_stat_insights/)

**快速連結：**

- [入門指南](https://pgelephant.github.io/pg_stat_insights/getting-started/) - 安裝和設定
- [設定](https://pgelephant.github.io/pg_stat_insights/configuration/) - 所有 11 個參數
- [檢視參考](https://pgelephant.github.io/pg_stat_insights/views/) - 所有 42 個檢視
- [指標指南](https://pgelephant.github.io/pg_stat_insights/metrics/) - 所有 52 欄
- [使用範例](https://pgelephant.github.io/pg_stat_insights/usage/) - 50+ SQL 查詢
- [Prometheus & Grafana](https://pgelephant.github.io/pg_stat_insights/prometheus-grafana/) - 監控整合
- [故障排除](https://pgelephant.github.io/pg_stat_insights/troubleshooting/) - 常見問題

---

## 安裝

```bash
# 建構和安裝
cd pg_stat_insights
make
sudo make install

# 設定
echo "shared_preload_libraries = 'pg_stat_insights'" | \
  sudo tee -a /etc/postgresql/*/main/postgresql.conf

# 重新啟動 PostgreSQL
sudo systemctl restart postgresql

# 建立擴充套件
psql -d your_database -c "CREATE EXTENSION pg_stat_insights;"
```

**詳細說明：** [安裝指南](https://pgelephant.github.io/pg_stat_insights/install/)

---

## 檢視

所有 42 個預建檢視按類別組織：

### 查詢效能檢視（10 個檢視）

| 檢視 | 用途 |
|------|---------|
| `pg_stat_insights` | 主統計檢視（52 欄）|
| `pg_stat_insights_top_by_time` | 按總時間排序的最慢查詢 |
| `pg_stat_insights_top_by_calls` | 最頻繁呼叫的查詢 |
| `pg_stat_insights_top_by_io` | 最高 I/O 消耗者 |
| `pg_stat_insights_top_cache_misses` | 快取效能差的查詢 |
| `pg_stat_insights_slow_queries` | 平均時間 > 100ms 的查詢 |
| `pg_stat_insights_errors` | 有錯誤的查詢 |
| `pg_stat_insights_plan_errors` | 計畫估算問題 |
| `pg_stat_insights_histogram_summary` | 回應時間分布 |
| `pg_stat_insights_by_bucket` | 時間序列彙總 |

### 複寫監控檢視（17 個檢視）

包括實體複寫、邏輯複寫、訂閱、發布、複寫來源和綜合儀表板檢視。

### 索引監控檢視（11 個檢視）

包括索引使用、膨脹偵測、效率指標、維護建議、缺失索引、警報和大小趨勢檢視。

### 時間序列桶檢視（4 個新檢視）

| 檢視 | 用途 |
|------|---------|
| `pg_stat_insights_index_by_bucket` | 按小時桶的索引使用統計 |
| `pg_stat_insights_index_size_by_bucket` | 按天桶的索引大小趨勢 |
| `pg_stat_insights_replication_by_bucket` | 按小時桶的複寫統計 |
| `pg_stat_insights_replication_lag_by_bucket` | 按小時桶的複寫延遲趨勢 |

**完整參考：** [檢視文件](https://pgelephant.github.io/pg_stat_insights/views/)

---

## 為什麼選擇 pg_stat_insights？

**解決常見的 PostgreSQL 效能問題：**

- **尋找慢查詢** - 識別消耗過多執行時間和資源的查詢
- **最佳化快取使用** - 偵測緩衝區快取未命中並提高 shared_buffers 效率
- **減少 WAL 負擔** - 監控每種查詢類型的預寫日誌產生
- **追蹤查詢模式** - 分析執行頻率、回應時間和資源消耗
- **即時監控** - 與 Grafana 整合，實現即時儀表板和警報
- **PostgreSQL 最佳實務** - 遵循 PostgreSQL 編碼標準和慣例建構

## 與其他擴充套件的比較

| 特性 | pg_stat_statements | pg_stat_monitor | **pg_stat_insights** |
|---------|:------------------:|:---------------:|:--------------------:|
| **指標欄** | 44 | 58 | **52** |
| **預建檢視** | 2 | 5 | **42** |
| **設定選項** | 5 | 12 | **11** |
| **快取分析** | 基礎 | 基礎 | **增強比率** |
| **回應時間分類** | 否 | 否 | **是（<1ms 到 >10s）** |
| **時間序列追蹤** | 否 | 否 | **是（基於桶）** |
| **TAP 測試覆蓋率** | 標準 | 有限 | **150 個測試，100% 覆蓋率** |
| **文件** | 基礎 | 中等 | **GitHub Pages 上 30+ 頁** |
| **Prometheus 整合** | 手動 | 手動 | **預建查詢和儀表板** |

**檢視詳細比較：** [功能比較](https://pgelephant.github.io/pg_stat_insights/comparison/)

---

## PostgreSQL 效能測試

**全面的 TAP 測試套件，確保品質：**
- **16 個測試檔案**涵蓋所有擴充套件功能
- **150 個測試案例**，100% 程式碼覆蓋率
- 測試所有 52 個指標欄、42 個檢視、11 個參數
- 自訂 StatsInsightManager.pm 框架
- 無需外部 Perl 相依性
- 與 PostgreSQL 18 測試基礎設施相容

**執行 PostgreSQL 擴充套件測試：**
```bash
./run_all_tests.sh
```

**持續整合：** GitHub Actions 工作流程，在每次提交時自動進行 PostgreSQL 測試

**了解更多：** [測試指南](https://pgelephant.github.io/pg_stat_insights/testing/)

---

## 使用 Prometheus & Grafana 進行資料庫監控

**即時 PostgreSQL 指標視覺化：**

將 pg_stat_insights 資料轉換為可操作的儀表板和警報，用於 PostgreSQL 資料庫監控：

- **Prometheus 整合** - 5 個為 postgres_exporter 預設定的查詢
- **Grafana 儀表板** - 8 個用於查詢效能視覺化的即用型面板
- **警報規則** - 11 個用於資料庫健康監控的生產就緒警報
- **查詢速率追蹤** - 監控每秒查詢數（QPS）和輸送量
- **快取效能** - 即時緩衝區快取命中率監控
- **回應時間 SLA** - 追蹤 P95/P99 查詢延遲，實現服務層級目標
- **WAL 產生警報** - 監控預寫日誌增長和磁碟使用情況

**完整的 Prometheus/Grafana 指南：** [監控整合](https://pgelephant.github.io/pg_stat_insights/prometheus-grafana/)

---

## 授權

MIT 授權 - 版權所有 (c) 2024-2025, pgElephant, Inc.

詳見 [LICENSE](../../LICENSE)。

---

## 連結

- [完整文件](https://pgelephant.github.io/pg_stat_insights/)
- [互動式演示](https://www.pgelephant.com/pg-stat-insights) - 線上體驗 pg_stat_insights
- [部落格文章](https://www.pgelephant.com/blog/pg-stat-insights) - 完整指南和最佳實務
- [GitHub 儲存庫](https://github.com/pgelephant/pg_stat_insights)
- [回報問題](https://github.com/pgelephant/pg_stat_insights/issues)
- [討論](https://github.com/pgelephant/pg_stat_insights/discussions)

---

<div align="center">

**由 [pgElephant, Inc.](https://pgelephant.com) 建構**

*讓 PostgreSQL 監控變得更好，一次一個指標*

</div>

