# 数据管道 测试 flavor

> 适用 ETL（Airflow / Prefect / Dagster）、批处理（Spark / Hadoop）、流处理（Flink / Kafka Streams）、数据集成（Kafka 消费者 / DataX / SeaTunnel）等数据工程场景。

## 元数据

```yaml
project_type: 数据管道（ETL / 批 / 流）
project_type_short: data-pipeline
identification_signals:
  - "存在 dags/ 目录（Airflow）或 flows/（Prefect）"
  - "requirements.txt 含 apache-airflow / prefect / dagster / pyspark / pandas"
  - "存在 .py 文件含 SparkSession / DataFrame.read / kafka.KafkaConsumer"
  - "存在 schema/ avro/ parquet/ 等数据格式定义"
  - "存在 dbt project（dbt_project.yml）"
default_test_dir: "tests/ 含 test_dag.py / test_transform.py / data/ 测试数据集"
```

<!-- BLOCK:PROJECT_TYPE_SCOPE -->
- **项目定位**：数据管道 / ETL / 数据仓库构建 / 实时计算
- **主要交付**：数据源接入、清洗转换、计算逻辑、目标存储写入
- **测试焦点**：**数据正确性**（schema + value）/ **幂等性**（重跑无副作用）/ **大数据量**（千万级稳定）/ **流批一致性** / **数据漂移检测** / **DAG 依赖正确性** / **错误数据处理**（脏数据不让管道崩）
- **不做**：上游数据源可靠性（信任）、下游消费方业务逻辑、底层引擎调优（Spark/Flink 参数优化属运维）
<!-- /BLOCK:PROJECT_TYPE_SCOPE -->

<!-- BLOCK:TEST_LEVELS -->
| 级别 | 工具 | 占比 | 关注 |
|------|------|------|------|
| **单元测试** | pytest + 内存数据 | **50%** | 单个 transform 函数（输入 DataFrame → 输出 DataFrame）|
| **DAG 结构测试** | airflow.utils.testing / 自定义 | **15%** | DAG 无环、task 依赖正确、参数化模板可渲染 |
| **小数据集成测试** | pytest + 小样本（KB-MB）| **20%** | 端到端跑通整个 pipeline，验证输出 |
| **大数据回归测试** | 历史数据快照 / 抽样数据集 | **10%** | 在 GB 级数据上跑，对比指标 |
| **数据质量监控** | Great Expectations / Soda / dbt tests | **5%** | 生产环境跑：null 率、范围、唯一性、引用完整性 |

**数据管道独特点**：**数据质量检查 = 持续测试**——不是开发期一次性，而是每次跑都要检查。
<!-- /BLOCK:TEST_LEVELS -->

<!-- BLOCK:KEY_RISK_AREAS -->
| 风险域 | 关注点 | 必测场景 |
|--------|--------|---------|
| **幂等性** | 同一批次重跑不产生重复数据 | DAG 重跑同一个 logical_date，目标表不重复（用 INSERT OVERWRITE 或 idempotent key）|
| **schema 漂移** | 上游字段加/删/改类型 | 字段缺失 → 用默认值；字段加了 → 自动适配或报警 |
| **脏数据** | null / 类型不匹配 / 极端值 | null 率 > 阈值 → 报警；类型转换失败 → 进入死信表 |
| **大数据量** | 内存爆 / Spark OOM / 倾斜 | 千万级数据 partition 均匀 / shuffle 不爆 |
| **流批一致性** | 同逻辑流处理和批处理结果一致 | Lambda 架构下 batch + stream 写到同一表，结果一致 |
| **时间窗口** | watermark / late data 处理 | 5 分钟窗口聚合，迟到 30 秒数据是否纳入 |
| **依赖任务失败** | 上游 task 失败下游不该跑 | A fail → B/C 不应启动；A 重试成功后 B/C 跑 |
| **数据回填** | backfill 历史日期 | 跑 30 天前的 logical_date，结果与当时跑一致 |
| **金额 / 关键指标** | 累加/聚合计算精度 | DECIMAL 不丢精度；SUM / COUNT 与对账一致 |
| **数据时效** | SLA（每天 8 点前出表） | 数据延迟 > 阈值 → 触发告警 |
<!-- /BLOCK:KEY_RISK_AREAS -->

<!-- BLOCK:AUTOMATION_STACK -->
**Airflow 生态**：

| 类型 | 工具 |
|------|------|
| DAG 测试 | `airflow.models.DagBag().import_errors`（DAG 解析）+ 自定义 task 单元 |
| 单元 | `pytest` + `pytest-mock` |
| 集成 | `airflow standalone` 或 `astro dev` 起本地 Airflow |
| 数据校验 | `Great Expectations` / `pandera` |

**Spark 生态**：

| 类型 | 工具 |
|------|------|
| 单元（PySpark）| `pytest` + `pyspark.sql.SparkSession.builder.master('local[*]')` 起 mini Spark |
| 数据对比 | `chispa`（PySpark 断言库）/ `pandas.testing.assert_frame_equal` |
| 性能 | Spark UI / `pyspark.sql.functions.broadcast`（join 测试）|

**Kafka / 流处理**：

| 类型 | 工具 |
|------|------|
| 集成 | `Testcontainers Kafka` / `kafka-python` + 嵌入式 Kafka |
| Flink | `MiniCluster` 单元测试 |
| Schema | Confluent Schema Registry 兼容性检查 |

**通用**：
- 数据质量：`Great Expectations` / `Soda` / `dbt tests` / `pandera`
- 数据 fixture：`pytest-postgresql` / `pytest-clickhouse` / Parquet 小文件
- DAG 可视化：Airflow UI / Dagster UI
<!-- /BLOCK:AUTOMATION_STACK -->

<!-- BLOCK:CI_INTEGRATION -->
**Airflow + GitLab CI**：

```yaml
test:dag-syntax:
  stage: test
  image: apache/airflow:2.7.0
  script:
    - python -c "from airflow.models import DagBag; assert DagBag().import_errors == {}"

test:unit:
  stage: test
  image: python:3.10
  script:
    - pip install -r requirements.txt
    - pytest tests/unit -v --cov=dags

test:integration:
  stage: test
  services:
    - postgres:14         # Airflow metadata
    - apache/airflow:2.7.0
  script:
    - airflow standalone &
    - sleep 30
    - pytest tests/integration

test:data-quality:
  stage: test
  script:
    - pip install great_expectations
    - great_expectations checkpoint run my_checkpoint

test:large-data-regression:
  stage: nightly
  tags: [big-data]    # 专用 runner（更多 RAM）
  script:
    - pytest tests/regression --data-set=production-sample-1B-rows
```

**关键约束**：
- DAG 解析必须 0 错误（CI 必检）
- 单元测试用本地 mini Spark（master='local[*]'）
- 大数据回归走 nightly + 自托管大内存 runner
- 数据质量检查每次 PR 跑（用小样本）
<!-- /BLOCK:CI_INTEGRATION -->

<!-- BLOCK:METRICS -->
| 指标 | 阈值 | 工具 |
|------|------|------|
| 单元覆盖率（Line）| ≥ **75%** | pytest-cov |
| DAG 解析成功率 | **100%** | DagBag |
| 数据正确性 | 0 critical 数据质量违规 | Great Expectations |
| null 率（关键字段）| ≤ **0.1%** | DQ 监控 |
| 唯一性约束 | **100%**（user_id, order_id 等）| dbt tests / GE |
| 引用完整性 | 外键关联 95%+ 命中 | DQ 监控 |
| 数据延迟（SLA）| < **业务约定**（如 8 点前出昨日表） | Airflow SLA + 告警 |
| 重跑幂等性 | 同 logical_date 重跑结果一致 | 对比脚本 |
| 大数据稳定性 | 千万级数据 OOM 0 次 | Spark UI 历史 |
| 流批一致性差异 | < **0.1%** | 周期性对账 |
<!-- /BLOCK:METRICS -->

<!-- BLOCK:NON_FUNCTIONAL -->
**性能 / 大数据**：

```python
# 用 pyspark 跑 1000 万行数据
import pyspark.sql.functions as F

def test_aggregation_handles_10m_rows(spark):
    df = spark.range(10_000_000).withColumn("user_id", F.col("id") % 1000)
    result = df.groupBy("user_id").count()
    result_count = result.count()  # action 触发计算
    assert result_count == 1000, f"应有 1000 个 user_id，实际 {result_count}"
```

**幂等性测试**：

```python
def test_etl_idempotent_on_rerun(target_table):
    """跑两次同 logical_date，目标表行数不应翻倍"""
    run_etl(logical_date='2026-04-28')
    count_1 = target_table.count()

    run_etl(logical_date='2026-04-28')  # 重跑
    count_2 = target_table.count()

    assert count_2 == count_1, f"重跑产生重复！{count_1} → {count_2}"
```

**数据漂移监控**（Great Expectations 示例）：

```python
import great_expectations as gx

context = gx.get_context()
suite = context.suites.get("daily_orders_quality")

# 期望
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToNotBeNull(column="order_id")
)
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToBeUnique(column="order_id")
)
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToBeBetween(
        column="amount", min_value=0, max_value=1_000_000
    )
)
```

**安全**：
- 敏感字段脱敏（手机号 → 中间 4 位 \*\*\*\*）
- 数据访问审计日志
- 跨地域 / 跨权限的数据合规（GDPR / 个保法）
<!-- /BLOCK:NON_FUNCTIONAL -->

<!-- BLOCK:SAMPLE_CASES -->
**典型用例**（订单 ETL：MySQL → Hive）：

```markdown
| TC-ID | 标题 | 设计技术 | 优先级 | 期望 |
|-------|------|---------|--------|------|
| TC-001 | 单天数据完整 ETL | 等价类(有效) | P0 | 源表 N 行 → 目标表 N 行（1:1）|
| TC-002 | 重跑同一天 logical_date | 幂等 | P0 | 目标表行数不变（INSERT OVERWRITE）|
| TC-003 | 源数据含 null | 错误推测 | P0 | null 字段填默认值 / 进死信表 |
| TC-004 | 源数据 schema 加新字段 | 兼容性 | P1 | ETL 不崩；新字段忽略或自动适配 |
| TC-005 | 上游 task A 失败 | 状态转换 | P0 | 下游 task B/C 不启动 |
| TC-006 | 千万级数据量 | 性能 | P0 | 不 OOM，10 分钟内完成（业务定）|
| TC-007 | 金额聚合精度 | 边界值 | P0 | DECIMAL(18,2) 不丢精度，SUM 对账一致 |
| TC-008 | backfill 7 天前 | 场景法 | P1 | 跑出来结果与当时跑一致 |
| TC-009 | Kafka 消费者重复消息 | 幂等 | P0 | 同 messageId 不写两次 |
| TC-010 | 流处理 5min 窗口聚合 | 状态转换 | P1 | watermark 触发后输出，late data 进 side output |
```

**pytest + PySpark 单元测试**：

```python
import pytest
from pyspark.sql import SparkSession
from chispa import assert_df_equality

@pytest.fixture(scope='session')
def spark():
    return SparkSession.builder.master('local[*]').getOrCreate()

def test_clean_orders_removes_invalid_amounts(spark):
    from dags.transforms import clean_orders

    input_df = spark.createDataFrame([
        ('o1', 100.0), ('o2', -10.0), ('o3', None), ('o4', 200.0)
    ], ['order_id', 'amount'])

    expected = spark.createDataFrame([
        ('o1', 100.0), ('o4', 200.0)
    ], ['order_id', 'amount'])

    result = clean_orders(input_df)
    assert_df_equality(result, expected)
```

**Airflow DAG 单元测试**：

```python
from airflow.models import DagBag

def test_dag_no_import_errors():
    dag_bag = DagBag(dag_folder='dags/', include_examples=False)
    assert not dag_bag.import_errors, f"DAG 解析错误: {dag_bag.import_errors}"

def test_orders_etl_dag_structure():
    dag_bag = DagBag(dag_folder='dags/')
    dag = dag_bag.get_dag('orders_etl')
    assert dag is not None
    assert {t.task_id for t in dag.tasks} == {'extract', 'transform', 'load', 'dq_check'}
    # 验证依赖
    assert 'extract' in [t.task_id for t in dag.get_task('transform').upstream_list]
```

**Great Expectations 数据质量**：

```python
def test_daily_orders_dq():
    import great_expectations as gx
    context = gx.get_context()
    result = context.run_checkpoint(checkpoint_name="daily_orders_quality")
    assert result.success, f"DQ 失败: {result.run_results}"
```
<!-- /BLOCK:SAMPLE_CASES -->

<!-- BLOCK:DIALECT_CONSTRAINTS -->
8. **幂等性 P0** — 每个 ETL 必有"重跑同 logical_date 行数不变"测试
9. **DAG 解析 0 错误** — CI 必检，import_errors 非空 fail
10. **数据质量是持续测试** — 不只是开发期，每次跑都要 DQ 检查
11. **大数据测试用样本** — CI 默认用 MB 级数据；GB 级回归走 nightly
12. **金额 / 计数精度** — 涉及金额必用 DECIMAL；聚合结果必有对账测试
13. **schema 兼容性** — 上游加字段时 ETL 不能崩；用 Avro/Protobuf 时跑兼容性检查
14. **死信表机制** — 脏数据进入死信表，不让管道整体失败
15. **backfill 演练** — 每季度演练 30 天回填，确认数据一致性
<!-- /BLOCK:DIALECT_CONSTRAINTS -->
