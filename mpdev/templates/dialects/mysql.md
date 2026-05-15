# MySQL 方言（适用 MySQL 5.7 / 8.0 / MariaDB）

> 本文件供 `/mpdev-init` 读取，提取 `<!-- BLOCK:* -->` 内容填充 `dba.tmpl` 占位符。

## 元数据

```yaml
db_engine: MySQL 8.0
db_engine_short: mysql
charset: utf8mb4
pk_convention: "id BIGINT AUTO_INCREMENT PRIMARY KEY"
fk_policy: "不加外键（应用层保证一致性）"
entity_paths: "**/entity/*.java (MyBatis Plus) / **/models.py (SQLAlchemy)"
migration_dir: "sql"
```

<!-- BLOCK:DB_CONFIG -->
- **主库**：MySQL 8.0+（或兼容: MariaDB 10.5+）
- **字符集**：`utf8mb4` / `utf8mb4_general_ci`（**不是** `utf8`，那是三字节阉割版）
- **存储引擎**：InnoDB（不要 MyISAM）
- **ORM**：Java 用 MyBatis Plus（Entity 驼峰，字段 snake_case 自动映射）；Python 用 SQLAlchemy 或原生 pymysql/aiomysql
- **命名**：表名 `snake_case` 单数；字段 `snake_case`；主键 `id BIGINT AUTO_INCREMENT`
- **审计字段**：`created_at` / `updated_at` / `deleted_at`（软删）
- **迁移目录**：`robot-contracts/sql/V{n}__{desc}.sql`
- **自增**：用 `AUTO_INCREMENT`（MySQL 无 SEQUENCE 对象）
<!-- /BLOCK:DB_CONFIG -->

<!-- BLOCK:DIALECT_CAVEATS -->
- ⚠️ `utf8` ≠ `utf8mb4`，前者仅 3 字节，存不下 emoji 和部分中文生僻字
- ⚠️ `TEXT` 列**不能建索引**（除非前缀索引），选 `VARCHAR(n)` 尽量估算上限
- ⚠️ `DATETIME` vs `TIMESTAMP`：前者无时区，范围 1000-9999；后者有时区转换，范围 1970-2038
- ⚠️ MySQL 的 `ENUM` 类型谨慎使用 —— 扩展枚举需 ALTER 表，不灵活；推荐 `TINYINT` + 代码 IntEnum
- ⚠️ `JSON` 类型（5.7+）可用但不能建普通索引（需虚拟列 + 索引虚拟列）
- ✅ MySQL 8.0.29+ 支持 `INSTANT` DDL：ADD COLUMN / DROP COLUMN 瞬时完成
<!-- /BLOCK:DIALECT_CAVEATS -->

<!-- BLOCK:TYPE_CHOICES -->
| 场景 | 推荐类型 | 备注 |
|------|---------|------|
| 短字符串（< 255） | `VARCHAR(n)` | 估算合理上限 |
| 长文本 | `TEXT` / `LONGTEXT` | 不能建普通索引 |
| 小整数 0-127 | `TINYINT` | 状态、布尔用 |
| 布尔 | `TINYINT(1)` | 无原生 BOOLEAN（BOOLEAN 是别名） |
| 金额 | `DECIMAL(18,2)` | 不用 FLOAT/DOUBLE |
| 时间戳 | `DATETIME(6)` | 微秒精度，无时区 |
| 全局 ID | `BIGINT UNSIGNED` | 雪花 ID / UUID 存 BINARY(16) |
| JSON 数据 | `JSON` | 8.0+，索引需虚拟列 |
<!-- /BLOCK:TYPE_CHOICES -->

<!-- BLOCK:DDL_SAFETY -->
| DDL 操作 | 锁级别 | 安全度（8.0.29+） |
|---------|--------|-------|
| ADD COLUMN NULL（无默认值） | **INSTANT**（瞬时） | ✅ 大表安全 |
| ADD COLUMN NOT NULL DEFAULT | INSTANT | ✅ 大表安全 |
| DROP COLUMN | INSTANT | ✅ 大表安全 |
| RENAME COLUMN | INSTANT（8.0.29+） | ✅ |
| ADD INDEX | in-place + no-lock | ⚠️ I/O 高，大表慢但不阻塞 |
| MODIFY COLUMN（改类型/长度） | COPY table + 写锁 | ❌ 大表危险 |
| CHANGE COLUMN（改列名） | COPY table + 写锁 | ❌ 大表危险 |
| 改主键 / 改字符集 | COPY table | ❌ 大表致命 |

**检查 DDL 算法**：`ALTER TABLE t ADD COLUMN c INT, ALGORITHM=INSTANT;` —— 若支持则立即完成，否则报错。
<!-- /BLOCK:DDL_SAFETY -->

<!-- BLOCK:BIG_TABLE_TOOLS -->
- 表规模 > 100w 行且 DDL 非 INSTANT → 必须用非阻塞工具
- **pt-online-schema-change**（Percona Toolkit）：触发器方式，对主从复制友好
- **gh-ost**（GitHub）：binlog 方式，对主从更轻量
- 本项目推荐: `pt-osc --alter "ADD COLUMN xxx" D=db,t=table --execute`
<!-- /BLOCK:BIG_TABLE_TOOLS -->

<!-- BLOCK:INDEX_TYPES -->
- **B-Tree**：默认索引类型，适合等值和范围查询
- **HASH**（MEMORY 引擎或 InnoDB Adaptive Hash）：等值极快，不支持范围
- **FULLTEXT**：全文检索（支持中文需要 ngram 分词器）
- **SPATIAL**：GIS 场景
- **函数索引**（8.0.13+）：`CREATE INDEX idx ON t((LOWER(name)));`
- **前缀索引**：`CREATE INDEX idx ON t(long_col(32));` —— 大字段节省空间
- **不支持**：部分索引、GIN、GiST、BRIN
<!-- /BLOCK:INDEX_TYPES -->

<!-- BLOCK:BATCH_UPDATE -->
```sql
-- MySQL 批量回填：主键区间 + LIMIT 控制单批
-- 在应用层用脚本循环调用，每批 sleep 0.1s

UPDATE tab
SET col = 'new_value'
WHERE id BETWEEN :start_id AND :end_id
  AND col IS NULL
ORDER BY id
LIMIT 10000;
```

```python
# 示例 Python 回填脚本
last_id = 0
batch_size = 10000
while True:
    cursor.execute(
      "UPDATE tab SET col=1 WHERE id > %s AND col IS NULL ORDER BY id LIMIT %s",
      (last_id, batch_size)
    )
    if cursor.rowcount == 0:
        break
    last_id = cursor.execute("SELECT MAX(id) FROM tab WHERE id > %s LIMIT %s", (last_id, batch_size)).fetchone()[0]
    time.sleep(0.1)
```
<!-- /BLOCK:BATCH_UPDATE -->

<!-- BLOCK:AUDIT_FIELDS_SQL -->
```sql
-- MySQL 审计字段标准模板
created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP        COMMENT '创建时间',
updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP               COMMENT '更新时间',
deleted_at DATETIME NULL     DEFAULT NULL                     COMMENT '软删时间（NULL=未删除）'
```

**软删查询规范**：所有业务查询加 `WHERE deleted_at IS NULL`；MyBatis Plus 用 `@TableLogic` 注解自动处理。
<!-- /BLOCK:AUDIT_FIELDS_SQL -->

<!-- BLOCK:DIALECT_CONSTRAINTS -->
6. **INSTANT DDL 优先** — 能用 INSTANT 的绝不用 COPY；能用 ADD NULL 的不用 MODIFY
7. **字符集强制 utf8mb4** — `utf8` 是历史包袱，所有新表必须 utf8mb4
8. **不用 MySQL ENUM** — 状态/类型字段用 TINYINT + 代码 IntEnum
9. **JSON 索引走虚拟列** — `ADD COLUMN c INT AS (JSON_EXTRACT(data, '$.x'))` + `ADD INDEX (c)`
10. **大表 DDL 必用 pt-osc/gh-ost** — > 100w 行且不是 INSTANT 的操作
<!-- /BLOCK:DIALECT_CONSTRAINTS -->
