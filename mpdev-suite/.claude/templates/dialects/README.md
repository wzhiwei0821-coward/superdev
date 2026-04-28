# Dialects 方言库维护指南

> 数据库方言文件的**规范 + 扩展指南**。给未来添加新数据库支持的维护者阅读。

## 目录

- [1. 体系概览](#1-体系概览)
- [2. dialect 文件结构规范](#2-dialect-文件结构规范)
- [3. 添加新 dialect（step-by-step）](#3-添加新-dialect)
- [4. 现有 dialect 覆盖清单](#4-现有-dialect-覆盖清单)
- [5. 合并流程示意](#5-合并流程示意)
- [6. 待支持的数据库（欢迎贡献）](#6-待支持的数据库)

---

## 1. 体系概览

**双层模板**：

```
dba.tmpl（骨架）                dialects/{db}.md（差异）
  ├── 角色 / 工作方法              ├── yaml 元数据（7 字段）
  ├── 7 步设计顺序                 └── 9 个 <!-- BLOCK:XXX --> 段
  ├── 9 节输出格式
  └── {{占位符}}（17 个）
                ↓
           /mpdev-init 合并
                ↓
         agents/dba.md（实例）
```

**好处**：加新 DB 只写一份 dialect 文件，不动骨架 + 其他 DB。

---

## 2. dialect 文件结构规范

### 2.1 必须包含的 yaml 元数据（7 字段）

文件顶部的 markdown 代码块（` ```yaml ... ``` `），这 7 个字段全部必需：

| 字段 | 说明 | 示例 |
|---|---|---|
| `db_engine` | DB 完整名称 + 版本 | `MySQL 8.0` / `达梦 DM8` |
| `db_engine_short` | 简称（用于元数据标记）| `mysql` / `dameng` |
| `charset` | 字符集 | `utf8mb4` / `UTF8` |
| `pk_convention` | 主键规范 | `id BIGINT AUTO_INCREMENT PRIMARY KEY` |
| `fk_policy` | 外键策略描述 | `不加外键（应用层保证）` |
| `entity_paths` | Entity/Model 文件路径模式 | `**/entity/*.java (MyBatis Plus)` |
| `migration_dir` | SQL 迁移目录 | `sql` / `robot-contracts/sql` |

### 2.2 必须包含的 9 个 BLOCK

每个 BLOCK 用 `<!-- BLOCK:XXX -->` ... `<!-- /BLOCK:XXX -->` 包裹。**名称和数量固定**：

| BLOCK 名 | 内容要求 | 对应 dba.tmpl 占位符 |
|---|---|---|
| `DB_CONFIG` | DB 基础信息（版本/字符集/ORM/命名/审计字段/迁移目录） | `{{DB_CONFIG_BLOCK}}` |
| `DIALECT_CAVEATS` | 方言陷阱和特色能力（⚠️ / ✅ / 🌟 三类）| `{{DIALECT_CAVEATS_BLOCK}}` |
| `TYPE_CHOICES` | 数据类型选型表（场景 → 推荐类型）| `{{TYPE_CHOICES_BLOCK}}` |
| `DDL_SAFETY` | DDL 操作的锁级别表（ADD/DROP/MODIFY 各类）| `{{DDL_SAFETY_BLOCK}}` |
| `BIG_TABLE_TOOLS` | 大表 DDL 工具（pt-osc / pg_repack / DEXP 等）| `{{BIG_TABLE_TOOLS_BLOCK}}` |
| `INDEX_TYPES` | 支持的索引类型清单 | `{{INDEX_TYPES_BLOCK}}` |
| `BATCH_UPDATE` | 批量回填 SQL 模板（方言特定语法）| `{{BATCH_UPDATE_BLOCK}}` |
| `AUDIT_FIELDS_SQL` | 审计字段 DDL 模板（含 trigger 等辅助语法）| `{{AUDIT_FIELDS_SQL_BLOCK}}` |
| `DIALECT_CONSTRAINTS` | 方言特定约束（编号 6-10，通用 1-5 在 dba.tmpl 里）| `{{DIALECT_CONSTRAINTS_BLOCK}}` |

### 2.3 约束编号规范

`DIALECT_CONSTRAINTS` 的约束编号**从 6 开始**。dba.tmpl 已定义通用约束 1-5：

1. 不连真实 DB
2. 不写业务代码
3. 默认不加索引
4. 回滚必写
5. 为 contract-designer 服务

方言特定约束从 6 开始编号（MySQL 的 INSTANT DDL / PG 的 CONCURRENTLY 等）。

---

## 3. 添加新 dialect

### Step 1：复制现有 dialect 作为骨架

选择语法最接近的现有 dialect 作为起点：

| 新 DB | 参考骨架 |
|---|---|
| Oracle | `dameng.md`（达梦是 Oracle 的中国版）|
| OceanBase（MySQL 兼容模式） | `mysql.md` |
| OceanBase（Oracle 兼容模式） | `dameng.md` |
| TiDB | `mysql.md`（MySQL 协议 + 部分差异）|
| openGauss / GaussDB | `postgresql.md`（PG 分支）|
| SQL Server | 新写（语法独特）|

```bash
cp .claude/templates/dialects/mysql.md .claude/templates/dialects/{new_db}.md
```

### Step 2：修改 yaml 元数据

改 `db_engine` / `db_engine_short` / `charset` / `pk_convention` / `fk_policy` / `entity_paths` / `migration_dir`。

### Step 3：逐个 BLOCK 改写

**按 9 个 BLOCK 顺序**，对照新 DB 的文档改写内容。重点关注差异：

- **类型**（VARCHAR2 / NUMBER / DATE 等）
- **自增/序列**（AUTO_INCREMENT / SEQUENCE / IDENTITY / SERIAL）
- **DDL 锁行为**（instant / concurrent / copy）
- **索引类型**（B-Tree 之外有什么独有）
- **updated_at 自动更新**（原生 ON UPDATE / Trigger）
- **批量 SQL 方言**（ROWNUM / LIMIT / CTE + UPDATE FROM）

### Step 4：在 mpdev-init.md 的 Step 7.5.2 表格加一行

```markdown
| `{新 DB 关键词}` | `.claude/templates/dialects/{new_db}.md` |
```

关键词用于识别匹配。多个别名用 `/` 分隔。

### Step 5：静态验证

```bash
# 确认 9 个 BLOCK 都在
grep -c "<!-- BLOCK:" .claude/templates/dialects/{new_db}.md
# 应输出 18（9 个开始 + 9 个结束）

# 确认 7 个 yaml 字段都在
sed -n '/^```yaml$/,/^```$/p' .claude/templates/dialects/{new_db}.md \
  | grep -c '^[a-z_]*:'
# 应输出 >= 7
```

### Step 6：实跑验证（可选）

找一个使用该 DB 的示例项目，跑 `/mpdev-init`，检查生成的 `agents/dba.md` 合理。

---

## 4. 现有 dialect 覆盖清单

| dialect 文件 | 覆盖的 DB | 兼容性 |
|---|---|---|
| `mysql.md` | MySQL 5.7/8.0、MariaDB 10.5+、TiDB（MySQL 协议部分）、OceanBase MySQL 模式 | 95% / 80% |
| `postgresql.md` | PostgreSQL 12+、openGauss、GaussDB（华为）、PolarDB-PG、RDS PG | 95% |
| `dameng.md` | 达梦 DM7 / DM8、Oracle（80% 兼容，语法相近）| 100% / 80% |
| `kingbase.md` | KingbaseES V7/V8（PG 模式）、KingbaseES（Oracle 模式，简化）| 90% |

## 5. 合并流程示意

**输入**：
- `dba.tmpl` 有占位符 `{{DB_ENGINE}}` 和 `{{DB_CONFIG_BLOCK}}`
- `dialects/mysql.md` 含元数据 `db_engine: MySQL 8.0` 和 `<!-- BLOCK:DB_CONFIG -->` 段

**合并规则**：

```
dba.tmpl:                        合并后 agents/dba.md:
────────────                     ─────────────────────────
# 角色                           # 角色

你是 {{PROJECT_NAME}} ...        你是 mpdevops 项目的数据库架构师...
你基于 {{DB_ENGINE}} ...          你基于 MySQL 8.0 ...

# 平台数据库概览                 # 平台数据库概览

{{DB_CONFIG_BLOCK}}              - **主库**: MySQL 8.0+（或兼容: MariaDB...）
                                 - **字符集**: `utf8mb4` ...
                                 - **存储引擎**: InnoDB ...
                                 ...
```

**/mpdev-init 的合并动作**：
1. 读 `dba.tmpl` 全文
2. 读选定 dialect 文件
3. 解析 dialect 的 yaml 和所有 BLOCK 段
4. 对 dba.tmpl 逐个 `{{XXX}}` 占位符做字符串替换
5. 写入 `.claude/agents/dba.md`

---

## 6. 待支持的数据库

欢迎贡献 dialect 文件。优先级建议：

| 优先级 | DB | 理由 |
|---|---|---|
| 🔥 高 | **Oracle** | 许多大企业核心系统；达梦虽接近但语法有差 |
| 🔥 高 | **OceanBase（独立 dialect）** | 阿里/蚂蚁系大量使用；MySQL 兼容度不满 100% |
| 🌡️ 中 | **TiDB（独立）** | 云原生场景，DDL 行为和 MySQL 有差（online DDL 永远异步） |
| 🌡️ 中 | **SQL Server** | 国企/传统行业仍有使用 |
| ❄️ 低 | **MongoDB**（需大改骨架）| 非关系型，骨架假设不适用 |

**贡献流程**：参考 §3 创建新 dialect → PR 或直接提交到仓库 → 在本文件 §4 更新覆盖清单。

---

## 附录：快速检查清单（写新 dialect 时自查）

- [ ] yaml 元数据 7 字段齐全
- [ ] 9 个 BLOCK 全部存在且开闭成对
- [ ] `DIALECT_CONSTRAINTS` 编号从 6 开始
- [ ] `AUDIT_FIELDS_SQL` 给出完整可运行的 DDL
- [ ] `BATCH_UPDATE` 用该 DB 的方言语法（不是 MySQL 习惯）
- [ ] `DDL_SAFETY` 表说明"instant/concurrent/copy"或对应概念
- [ ] `TYPE_CHOICES` 表反映该 DB 的类型体系（不是照搬别人）
- [ ] `mpdev-init.md` Step 7.5.2 识别表加了一行
- [ ] 本文件 §4 覆盖清单更新
