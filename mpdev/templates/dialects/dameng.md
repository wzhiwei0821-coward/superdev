# 达梦 DM 方言（适用 DM7 / DM8）

> 本文件供 `/mpdev-init` 读取。达梦高度兼容 Oracle 语法，许多规则借鉴 Oracle。

## 元数据

```yaml
db_engine: 达梦 DM8
db_engine_short: dameng
charset: UTF-8  # 建库时决定，也可 GB18030
pk_convention: "ID BIGINT IDENTITY(1,1) PRIMARY KEY (或 SEQUENCE)"
fk_policy: "按业务判断；达梦外键性能尚可"
entity_paths: "**/entity/*.java (MyBatis, 使用 DM JDBC)"
migration_dir: "sql"
```

<!-- BLOCK:DB_CONFIG -->
- **主库**：达梦 DM8（武汉达梦）
- **字符集**：建库时设定 `UTF-8` 或 `GB18030`，**后期无法修改**
- **Oracle 兼容**：达梦设计目标是兼容 Oracle 语法（DUAL 表、SEQUENCE、ROWNUM、PL/SQL）
- **ORM**：Java 通过达梦 JDBC 驱动（`dm.jdbc.driver.DmDriver`），MyBatis 适配需注意 SQL 方言
- **命名**：表名和字段**默认大写**（Oracle 风格）；若要小写需用双引号 `"my_table"`
- **主键**：`IDENTITY(1,1)` 或 `CREATE SEQUENCE seq_xxx; INSERT ... seq_xxx.NEXTVAL`
- **审计字段**：`CREATED_AT` / `UPDATED_AT` / `DELETED_AT`（注意大小写）
- **迁移目录**：`sql/V{n}__{desc}.sql`
<!-- /BLOCK:DB_CONFIG -->

<!-- BLOCK:DIALECT_CAVEATS -->
- ⚠️ **标识符默认大写**：`CREATE TABLE user_info` 实际存储为 `USER_INFO`；查询 `SELECT * FROM user_info` 也行（不区分大小写），但 JDBC 返回列名是大写
- ⚠️ `VARCHAR2(n)` 和 `VARCHAR(n)` 都可用，建议统一 `VARCHAR2`（Oracle 风格）
- ⚠️ `NUMBER(p, s)` 替代 `DECIMAL` —— 更符合达梦风格
- ⚠️ 时间类型 `DATE` 含时分秒（和 Oracle 一致，不是 MySQL 的纯日期）
- ⚠️ 字符串不要用 `''` 表示 NULL —— 达梦/Oracle 里 `'' = NULL`（与 MySQL 不同）
- ⚠️ 分页语法：`SELECT ... WHERE ROWNUM <= 20`（Oracle 风格）或 `LIMIT N OFFSET M`（达梦 8 也支持）
- ✅ 支持 PL/SQL 存储过程、SEQUENCE、触发器
- 🌟 达梦特色：列存储表、国密加密（SM2/SM3/SM4）、透明加密
<!-- /BLOCK:DIALECT_CAVEATS -->

<!-- BLOCK:TYPE_CHOICES -->
| 场景 | 推荐类型 | 备注 |
|------|---------|------|
| 短字符串 | `VARCHAR2(n)` | Oracle 风格；VARCHAR 是别名 |
| 长文本 | `CLOB` | 避免用于索引、排序、WHERE LIKE |
| 小整数 | `TINYINT` 或 `NUMBER(3)` | |
| 布尔 | `BIT` 或 `NUMBER(1)` | 达梦有 BIT 类型 |
| 金额 | `NUMBER(18,2)` | |
| 时间戳 | `TIMESTAMP` 或 `DATETIME` | DATE 含时分秒 |
| 全局 ID | `BIGINT IDENTITY(1,1)` | 或 SEQUENCE |
| JSON 数据 | `CLOB` + 应用层解析 | 达梦 8 有 JSON 类型但功能弱 |
| 二进制 | `BLOB` / `VARBINARY(n)` | |
<!-- /BLOCK:TYPE_CHOICES -->

<!-- BLOCK:DDL_SAFETY -->
| DDL 操作 | 锁级别 | 安全度 |
|---------|--------|-------|
| ADD COLUMN（默认 NULL） | 短时排他锁 | ✅ 小表秒级 |
| ADD COLUMN DEFAULT | 表级锁 + 数据填充 | ⚠️ 大表慢 |
| DROP COLUMN | 排他锁 + 重组（物理删除） | ⚠️ 大表慢；可先 `SET UNUSED` 再异步清理 |
| MODIFY COLUMN（改类型） | 排他锁 + 检查数据 | ❌ 大表危险 |
| RENAME COLUMN | 快速（元数据） | ✅ |
| ADD INDEX | 表级锁 | ⚠️ 大表建议夜间 |
| CREATE INDEX ONLINE | ONLINE 关键字 | ⚠️ 部分支持，建议确认版本 |

**达梦 DDL 必测**：建议先在预发环境用同量级数据测试 DDL 耗时。
<!-- /BLOCK:DDL_SAFETY -->

<!-- BLOCK:BIG_TABLE_TOOLS -->
- 表规模 > 100w 行的 DDL → 建议申请维护窗口
- **DEXP / DIMP**（达梦备份恢复工具）：类似 Oracle exp/imp，做全表重建时用
- **DISQL**：达梦命令行工具，执行大批量 SQL
- **HUGE 表**：超大表可转为列存 HUGE 表，OLAP 场景快数倍
- 本项目推荐: 使用达梦 `Manager` 图形工具执行 ALTER，观察进度；或 `disql user/pass@host -e "@migration.sql"` 批量执行
<!-- /BLOCK:BIG_TABLE_TOOLS -->

<!-- BLOCK:INDEX_TYPES -->
- **B-Tree**：默认索引，等值+范围
- **位图索引**（BITMAP）：低基数字段（性别、状态），OLAP 场景
- **函数索引**：`CREATE INDEX idx ON t(LOWER(name));`
- **全文索引**：`CTXSYS` 上下文索引（类似 Oracle Text）
- **列存索引**：HUGE 表专用，列式压缩
- **聚集索引**：达梦 8 支持，主键默认为聚集索引
- **不支持**：PG 的部分索引、GIN、GiST、BRIN
<!-- /BLOCK:INDEX_TYPES -->

<!-- BLOCK:BATCH_UPDATE -->
```sql
-- 达梦批量回填：用 ROWNUM 限制单批
-- 注意达梦分页 ROWNUM 用法

UPDATE tab SET col = 'new_value'
WHERE id BETWEEN :start_id AND :end_id
  AND col IS NULL
  AND ROWNUM <= 10000;
COMMIT;
```

**PL/SQL 块方式**（推荐用于复杂回填）：

```sql
BEGIN
  FOR r IN (SELECT id FROM tab WHERE col IS NULL ROWNUM <= 10000) LOOP
    UPDATE tab SET col = 1 WHERE id = r.id;
  END LOOP;
  COMMIT;
END;
/
```
<!-- /BLOCK:BATCH_UPDATE -->

<!-- BLOCK:AUDIT_FIELDS_SQL -->
```sql
-- 达梦审计字段（Oracle 风格）
CREATED_AT TIMESTAMP DEFAULT SYSDATE NOT NULL,
UPDATED_AT TIMESTAMP DEFAULT SYSDATE NOT NULL,
DELETED_AT TIMESTAMP NULL
```

**UPDATED_AT 自动更新需 Trigger**（达梦不支持 MySQL `ON UPDATE` 语法）：

```sql
CREATE OR REPLACE TRIGGER TRG_TAB_UPDATED
  BEFORE UPDATE ON TAB
  FOR EACH ROW
BEGIN
  :NEW.UPDATED_AT := SYSDATE;
END;
/
```

**软删规范**：查询加 `WHERE DELETED_AT IS NULL`（注意大写）。
<!-- /BLOCK:AUDIT_FIELDS_SQL -->

<!-- BLOCK:DIALECT_CONSTRAINTS -->
6. **优先 Oracle 风格** — VARCHAR2 / NUMBER / DATE / SEQUENCE，方便未来潜在 Oracle 切换
7. **大表 DDL 要维护窗口** — 达梦无 MySQL 的 INSTANT、无 PG 的 CONCURRENTLY，大表只能审慎
8. **字符集建库定死** — UTF-8 vs GB18030 建库时选，后期换要重建库
9. **标识符建议大写** — 符合达梦/Oracle 规范，避免查询时大小写混乱
10. **慎用 CLOB** — 不能索引、不能排序、WHERE LIKE 慢
11. **PL/SQL 存储过程**可用但慎用 — 业务逻辑放应用层，仅在批量数据处理时用存储过程
<!-- /BLOCK:DIALECT_CONSTRAINTS -->
