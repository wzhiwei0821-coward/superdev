# 人大金仓 KingbaseES 方言（适用 V7 / V8 / V9）

> 本文件供 `/mpdev-init` 读取。KingbaseES 基于 PostgreSQL 内核，**双兼容模式**：PG 模式 / Oracle 模式。

## 元数据

```yaml
db_engine: 人大金仓 KingbaseES V8
db_engine_short: kingbase
charset: UTF8  # 建库时决定
compat_mode: "PG 模式 | Oracle 模式（需建库时选择，切换成本高）"
pk_convention: "id BIGINT GENERATED ... AS IDENTITY (PG 模式) / NUMBER IDENTITY (Oracle 模式)"
fk_policy: "继承 PG，建议加（成本低）"
entity_paths: "**/entity/*.java (MyBatis) / **/models.py (SQLAlchemy)"
migration_dir: "sql"
```

<!-- BLOCK:DB_CONFIG -->
- **主库**：人大金仓 KingbaseES V8（北京人大金仓信息技术股份有限公司）
- **内核基础**：PostgreSQL 9.2+ 分叉演进（V8 接近 PG 12-14 能力）
- **兼容模式**（建库时二选一，切换成本极高）：
  - **PG 模式**：语法/类型/函数 与 PostgreSQL 基本一致（推荐新项目）
  - **Oracle 模式**：支持 VARCHAR2/NUMBER/SEQUENCE/PL/SQL（用于 Oracle 迁移）
- **字符集**：`UTF8` 或 `GBK`，建库时固定
- **ORM**：Java 用 KingbaseES JDBC 驱动（`com.kingbase8.Driver`），配合 MyBatis；Python 用 `ksycopg2`（fork 自 psycopg2）
- **命名**：PG 模式下 `snake_case`；Oracle 模式下默认大写
- **主键**：PG 模式用 `IDENTITY` / `BIGSERIAL`；Oracle 模式用 `NUMBER IDENTITY` 或 SEQUENCE
- **审计字段**：`created_at` / `updated_at` / `deleted_at`
- **迁移目录**：`sql/V{n}__{desc}.sql`
- **系统表前缀**：`sys_`（对应 PG 的 `pg_`）
<!-- /BLOCK:DB_CONFIG -->

<!-- BLOCK:DIALECT_CAVEATS -->
- ⚠️ **兼容模式决定一切**：建库时选 PG 还是 Oracle 模式，后续语法规则完全不同
- ⚠️ 系统表/视图以 `sys_` 开头（非 PG 原生的 `pg_`）：`sys_database`、`sys_class`、`sys_attribute`
- ⚠️ JDBC 驱动：`com.kingbase8.Driver`，URL `jdbc:kingbase8://host:port/db`
- ✅ 继承 PG 能力：CONCURRENTLY、JSONB、GIN/GiST、部分索引、CTE
- ✅ 支持 SEQUENCE（两种模式都有）
- 🌟 金仓独有：KingbaseES FlySync（主备同步）、加密插件（国密算法 SM2/3/4）、审计插件
- 🌟 配套工具：KStudio（图形客户端）、ksql（CLI，类似 psql）、sys_tools（类似 PG tools）
<!-- /BLOCK:DIALECT_CAVEATS -->

<!-- BLOCK:TYPE_CHOICES -->
| 场景 | PG 模式 | Oracle 模式 |
|------|---------|-------------|
| 短字符串 | `VARCHAR(n)` | `VARCHAR2(n)` |
| 长文本 | `TEXT` | `CLOB` |
| 布尔 | `BOOLEAN` | `NUMBER(1)` |
| 金额 | `NUMERIC(18,2)` | `NUMBER(18,2)` |
| 时间戳 | `TIMESTAMPTZ` | `TIMESTAMP` / `DATE` |
| 全局 ID | `BIGINT ... AS IDENTITY` / `BIGSERIAL` | `NUMBER IDENTITY` / SEQUENCE |
| JSON | `JSONB`（强推荐） | `CLOB` + 解析 |
| 数组 | `INT[]` / `TEXT[]` | 不支持 |
| UUID | `UUID` | `VARCHAR2(36)` |
<!-- /BLOCK:TYPE_CHOICES -->

<!-- BLOCK:DDL_SAFETY -->
| DDL 操作 | 锁级别 | 安全度 |
|---------|--------|-------|
| ADD COLUMN NULL | ACCESS EXCLUSIVE（极短） | ✅ 毫秒级 |
| ADD COLUMN NOT NULL DEFAULT | ACCESS EXCLUSIVE（类似 PG 11+ fast add） | ✅ 安全 |
| DROP COLUMN | ACCESS EXCLUSIVE（极短） | ✅ 安全 |
| ALTER COLUMN TYPE（兼容） | SHARE | ⚠️ 大表慢 |
| **CREATE INDEX CONCURRENTLY** | SHARE UPDATE EXCLUSIVE | ✅ 不阻塞读写 |
| CREATE INDEX（普通） | SHARE | ⚠️ 阻塞写 |

**黄金法则**（同 PG）：生产环境建索引必用 `CONCURRENTLY`。
<!-- /BLOCK:DDL_SAFETY -->

<!-- BLOCK:BIG_TABLE_TOOLS -->
- 表规模 > 1000w 行：
  - **sys_repack**：金仓的 pg_repack 版本，在线重组表
  - **逻辑复制**：金仓支持 PG 风格的逻辑复制，可用于零停机迁移
  - **FlySync**：金仓专有双活/同步工具，跨库迁移场景
- 本项目推荐: `sys_repack -d db -t table --jobs 4`
- 索引建议: `CREATE INDEX CONCURRENTLY idx_name ON t(col);`
<!-- /BLOCK:BIG_TABLE_TOOLS -->

<!-- BLOCK:INDEX_TYPES -->
继承 PG 全部索引类型：

- **B-Tree**（默认）
- **GIN**：jsonb / 数组 / 全文
- **GiST**：几何、范围类型
- **BRIN**：超大表有序列
- **Hash** / **SP-GiST**
- **部分索引**：`WHERE` 子句
- **覆盖索引**：`INCLUDE` 子句
- **表达式索引**

Oracle 模式下还支持：
- **位图索引**（Oracle 风格）
- **函数索引**
<!-- /BLOCK:INDEX_TYPES -->

<!-- BLOCK:BATCH_UPDATE -->
```sql
-- KingbaseES 批量回填（PG 模式，推荐写法）
BEGIN;
WITH batch AS (
  SELECT id FROM tab
  WHERE col IS NULL
  ORDER BY id
  LIMIT 10000
  FOR UPDATE SKIP LOCKED
)
UPDATE tab SET col = 'new_value'
FROM batch
WHERE tab.id = batch.id;
COMMIT;
```

**Oracle 模式可用 PL/SQL 块**：

```sql
BEGIN
  UPDATE tab SET col = 1
  WHERE col IS NULL AND ROWNUM <= 10000;
  COMMIT;
END;
/
```

**大表优化**：定期 `VACUUM ANALYZE tab;`，避免 bloat。
<!-- /BLOCK:BATCH_UPDATE -->

<!-- BLOCK:AUDIT_FIELDS_SQL -->
```sql
-- KingbaseES 审计字段（PG 模式）
created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
deleted_at TIMESTAMPTZ NULL
```

**updated_at 自动更新 Trigger**（PG 模式）：

```sql
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tab_updated_at
  BEFORE UPDATE ON tab
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

**Oracle 模式请参考达梦方言的 Trigger 写法。**

**软删**：配合部分索引提升性能：
```sql
CREATE INDEX idx_tab_active ON tab(id) WHERE deleted_at IS NULL;
```
<!-- /BLOCK:AUDIT_FIELDS_SQL -->

<!-- BLOCK:DIALECT_CONSTRAINTS -->
6. **明确兼容模式** — 项目启动时确定 PG 或 Oracle 模式，不要混用两种语法
7. **索引必用 CONCURRENTLY** — 继承 PG 规范
8. **用 JSONB 不用 CLOB 存 JSON** — PG 模式强制；Oracle 模式才用 CLOB
9. **系统表查询用 sys_* 前缀** — 如 `SELECT * FROM sys_class`，不要用 `pg_class`
10. **国密加密可选启用** — 对敏感字段（身份证/银行卡）用 SM4 加密
11. **JDBC 驱动版本匹配** — 确保驱动版本和数据库版本对齐（V8 数据库用 V8 驱动）
<!-- /BLOCK:DIALECT_CONSTRAINTS -->
