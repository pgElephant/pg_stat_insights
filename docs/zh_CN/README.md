# pg_stat_insights - PostgreSQL 性能监控扩展

> **先进的 PostgreSQL 查询性能监控、SQL 优化和数据库分析扩展**
> 
> 监控慢查询 • 跟踪缓存效率 • 分析 WAL 生成 • 优化数据库性能 • 实时指标 • Grafana 仪表板

## 语言支持 / Language Support / 多言語対応

**[简体中文](#概述)** (当前) | **[繁體中文](../zh_TW/README.md)** | **[日本語](../ja_JP/README.md)** | **[English](../../README.md)**

<div align="center">

**跟踪 52 个指标，11 个视图 - 实时监控 PostgreSQL 查询性能**

*适用于 PostgreSQL 16、17、18 的生产就绪扩展 - pg_stat_statements 的增强型替代品*

[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16%20|%2017%20|%2018-blue.svg)](https://www.postgresql.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](../../LICENSE)
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)]()
[![Metrics](https://img.shields.io/badge/metrics-52_columns-brightgreen.svg)]()
[![Documentation](https://img.shields.io/badge/docs-github.io-blue.svg)](https://pgelephant.github.io/pg_stat_insights/)

![52 列指标，11 个视图](https://img.shields.io/badge/52_列-11_视图-success?style=for-the-badge)

</div>

---

## 概述

**简化 PostgreSQL 查询性能监控**

`pg_stat_insights` 是一个先进的 PostgreSQL 扩展，用于**数据库性能监控**、**查询优化**和 **SQL 分析**。跟踪和分析 **52 个综合指标**，通过 **11 个预构建视图**识别慢查询、优化缓存性能并实时监控数据库健康状况。

**适用于：**
- 监控 PostgreSQL 性能的数据库管理员
- 跟踪查询性能和资源使用的 DevOps 团队
- 优化 SQL 查询和数据库操作的开发人员
- 实施数据库监控和告警的 SRE

**主要特性：**
- **52 个指标列** - 执行时间、缓存命中、WAL 生成、JIT 统计、缓冲区 I/O
- **11 个预构建视图** - 即时访问最慢查询、缓存未命中、I/O 密集型操作
- **11 个参数** - 微调跟踪、直方图和统计收集
- **直接替换** pg_stat_statements，具有增强的指标
- **PostgreSQL 16-18** - 与最新 PostgreSQL 版本完全兼容
- **响应时间跟踪** - 按执行时间对查询进行分类（<1ms 到 >10s）
- **缓存分析** - 识别缓冲区缓存低效率和优化机会
- **WAL 监控** - 跟踪每个查询的预写日志生成
- **时间序列数据** - 历史性能趋势和桶分析
- **Prometheus/Grafana 就绪** - 包含预构建的仪表板和告警规则

---

## 快速开始 - 3 步安装

**在 5 分钟内监控 PostgreSQL 查询性能：**

```sql
-- 步骤 1：在 PostgreSQL 配置中启用扩展
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_insights';
-- 需要重启 PostgreSQL 服务器

-- 步骤 2：在您的数据库中创建扩展
CREATE EXTENSION pg_stat_insights;

-- 步骤 3：立即查看最慢的查询
SELECT 
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    rows
FROM pg_stat_insights_top_by_time 
LIMIT 10;
```

**结果：**立即了解查询性能、执行时间、缓存效率以及 PostgreSQL 数据库中的资源使用情况。

---

## 文档

**完整文档可在以下位置获得：**

### [pgelephant.github.io/pg_stat_insights](https://pgelephant.github.io/pg_stat_insights/)

**快速链接：**

- [入门指南](https://pgelephant.github.io/pg_stat_insights/getting-started/) - 安装和设置
- [配置](https://pgelephant.github.io/pg_stat_insights/configuration/) - 所有 11 个参数
- [视图参考](https://pgelephant.github.io/pg_stat_insights/views/) - 所有 11 个视图
- [指标指南](https://pgelephant.github.io/pg_stat_insights/metrics/) - 所有 52 列
- [使用示例](https://pgelephant.github.io/pg_stat_insights/usage/) - 50+ SQL 查询
- [Prometheus & Grafana](https://pgelephant.github.io/pg_stat_insights/prometheus-grafana/) - 监控集成
- [故障排除](https://pgelephant.github.io/pg_stat_insights/troubleshooting/) - 常见问题

---

## 安装

```bash
# 构建和安装
cd pg_stat_insights
make
sudo make install

# 配置
echo "shared_preload_libraries = 'pg_stat_insights'" | \
  sudo tee -a /etc/postgresql/*/main/postgresql.conf

# 重启 PostgreSQL
sudo systemctl restart postgresql

# 创建扩展
psql -d your_database -c "CREATE EXTENSION pg_stat_insights;"
```

**详细说明：** [安装指南](https://pgelephant.github.io/pg_stat_insights/install/)

---

## 视图

所有 11 个预构建视图：

| 视图 | 用途 |
|------|---------|
| `pg_stat_insights` | 主统计视图（52 列）|
| `pg_stat_insights_top_by_time` | 按总时间排序的最慢查询 |
| `pg_stat_insights_top_by_calls` | 最频繁调用的查询 |
| `pg_stat_insights_top_by_io` | 最高 I/O 消耗者 |
| `pg_stat_insights_top_cache_misses` | 缓存性能差的查询 |
| `pg_stat_insights_slow_queries` | 平均时间 > 100ms 的查询 |
| `pg_stat_insights_errors` | 有错误的查询 |
| `pg_stat_insights_plan_errors` | 计划估算问题 |
| `pg_stat_insights_histogram_summary` | 响应时间分布 |
| `pg_stat_insights_by_bucket` | 时间序列聚合 |
| `pg_stat_insights_replication` | 复制监控 |

**完整参考：** [视图文档](https://pgelephant.github.io/pg_stat_insights/views/)

---

## 为什么选择 pg_stat_insights？

**解决常见的 PostgreSQL 性能问题：**

- **查找慢查询** - 识别消耗过多执行时间和资源的查询
- **优化缓存使用** - 检测缓冲区缓存未命中并提高 shared_buffers 效率
- **减少 WAL 开销** - 监控每种查询类型的预写日志生成
- **跟踪查询模式** - 分析执行频率、响应时间和资源消耗
- **实时监控** - 与 Grafana 集成，实现实时仪表板和告警
- **PostgreSQL 最佳实践** - 遵循 PostgreSQL 编码标准和约定构建

## 与其他扩展的比较

| 特性 | pg_stat_statements | pg_stat_monitor | **pg_stat_insights** |
|---------|:------------------:|:---------------:|:--------------------:|
| **指标列** | 44 | 58 | **52** |
| **预构建视图** | 2 | 5 | **11** |
| **配置选项** | 5 | 12 | **11** |
| **缓存分析** | 基础 | 基础 | **增强比率** |
| **响应时间分类** | 否 | 否 | **是（<1ms 到 >10s）** |
| **时间序列跟踪** | 否 | 否 | **是（基于桶）** |
| **TAP 测试覆盖** | 标准 | 有限 | **150 个测试，100% 覆盖** |
| **文档** | 基础 | 中等 | **GitHub Pages 上 30+ 页** |
| **Prometheus 集成** | 手动 | 手动 | **预构建查询和仪表板** |

**查看详细比较：** [功能比较](https://pgelephant.github.io/pg_stat_insights/comparison/)

---

## PostgreSQL 性能测试

**全面的 TAP 测试套件，确保质量：**
- **16 个测试文件**涵盖所有扩展功能
- **150 个测试用例**，100% 代码覆盖率
- 测试所有 52 个指标列、11 个视图、11 个参数
- 自定义 StatsInsightManager.pm 框架
- 无需外部 Perl 依赖
- 与 PostgreSQL 18 测试基础设施兼容

**运行 PostgreSQL 扩展测试：**
```bash
./run_all_tests.sh
```

**持续集成：** GitHub Actions 工作流，在每次提交时自动进行 PostgreSQL 测试

**了解更多：** [测试指南](https://pgelephant.github.io/pg_stat_insights/testing/)

---

## 使用 Prometheus & Grafana 进行数据库监控

**实时 PostgreSQL 指标可视化：**

将 pg_stat_insights 数据转换为可操作的仪表板和告警，用于 PostgreSQL 数据库监控：

- **Prometheus 集成** - 5 个为 postgres_exporter 预配置的查询
- **Grafana 仪表板** - 8 个用于查询性能可视化的即用型面板
- **告警规则** - 11 个用于数据库健康监控的生产就绪告警
- **查询速率跟踪** - 监控每秒查询数（QPS）和吞吐量
- **缓存性能** - 实时缓冲区缓存命中率监控
- **响应时间 SLA** - 跟踪 P95/P99 查询延迟，实现服务级别目标
- **WAL 生成告警** - 监控预写日志增长和磁盘使用情况

**完整的 Prometheus/Grafana 指南：** [监控集成](https://pgelephant.github.io/pg_stat_insights/prometheus-grafana/)

---

## 许可证

MIT 许可证 - 版权所有 (c) 2024-2025, pgElephant, Inc.

详见 [LICENSE](../../LICENSE)。

---

## 链接

- [完整文档](https://pgelephant.github.io/pg_stat_insights/)
- [交互式演示](https://www.pgelephant.com/pg-stat-insights) - 在线体验 pg_stat_insights
- [博客文章](https://www.pgelephant.com/blog/pg-stat-insights) - 完整指南和最佳实践
- [GitHub 仓库](https://github.com/pgelephant/pg_stat_insights)
- [报告问题](https://github.com/pgelephant/pg_stat_insights/issues)
- [讨论](https://github.com/pgelephant/pg_stat_insights/discussions)

---

<div align="center">

**由 [pgElephant, Inc.](https://pgelephant.com) 构建**

*让 PostgreSQL 监控变得更好，一次一个指标*

</div>

