# probe-db — DB 连接探针

被 fix/understand 调用，连项目数据库做查询。3 种用途：
- `query-dict`：扫字典表（understand 用）
- `reproduce`：按 bug 描述拼定向 SELECT（fix 用）
- `verify-fix`：与 reproduce 阶段保存的查询对比（fix 用）

## 输入（调用方提供）

| 变量 | 必填 | 含义 |
|------|------|------|
| `module` | 是 | 模块名（state.yml 定位 DB 连接） |
| `intent` | 是 | `query-dict` / `reproduce` / `verify-fix` |
| `query_hint` | 否 | bug 描述里的表名/列名/错误关键词 |
| `batch_id` | 否 | 复现 trace 归档 ID（fix 批量场景） |

## 步骤

### 1. 加载环境元数据

```
Read .claude/.mpdev-env-state.yml
找 middleware[].type=mysql 节 → host / port
找 modules[name={module}].directory → 模块根目录（备用）
若 state.yml 不存在 → 返回 status=skipped, error="no state.yml, run /mpdev-env start first"
```

### 2. 加载或收集凭据

```
Read .claude/.mpdev-runtime-creds.yml （文件可能不存在）
查 modules.{module}.db 节
若节缺失:
  AskUserQuestion 第 1 步（决策）:
    "{module} 需要 DB 凭据才能查询，是否现在填写？"
    选项: [填写凭据 / 跳过此次（本次不连 DB）]
    
  若用户选"跳过此次" → 立即返回 status=skipped, error="credentials collection declined by user"
  
  若用户选"填写凭据" → AskUserQuestion 第 2 步（收集）:
    - username [模块 {module} 的 MySQL 用户名]
    - password [密码（不会展示在报告里）]
    - database [数据库名，缺省自动取 state.yml 中的 mysql 默认]
  
  收集后校验：若 username 或 password 为空字符串/仅空白 → 视为放弃 → status=skipped, error="incomplete credentials"
  
  通过校验后写回 creds.yml（保留其他节不动）
```

### 3. 选择 SQL 客户端（按优先级）

```
策略 A: 优先 mcp__mysql__execute_query
  - 若 MCP 配的 host:port:db 与目标一致 → 用 MCP
  - 不一致 → 跳到策略 B
  
策略 B: 降级到 Bash mysql CLI
  Bash("which mysql") → 有 → 用 Bash 调
  
策略 C: 都不可用
  返回 status=skipped, error="no mysql client available; install mysql CLI or configure MCP"
```

### 4. 按 intent 执行查询

#### intent=query-dict

```
1. SHOW TABLES → 拿表名列表
2. 匹配字典模式（任一即视为字典表）:
   - 以 dict_ 开头 或 _dict 结尾
   - 以 type_ 开头 或 _type 结尾
   - 以 enum_ 开头 或 _enum 结尾
   - 含 status / state / role / category / level / priority
3. 对每个匹配表:
   SELECT COUNT(*) FROM {table};
   若 count <= 100 → SELECT * FROM {table};
   若 count > 100 → SELECT * FROM {table} LIMIT 100;（注 totalRows={count}）
4. 写 .claude-notes/{module}/dict-snapshots.md:
   每表一节，含 markdown 表格 + （若截断）totalRows 注释
```

#### intent=reproduce

```
1. 解析 query_hint:
   - 包含 SQL 关键字（SELECT/FROM/WHERE/JOIN）→ 直接当作 SQL（移除危险动词：DROP/DELETE/UPDATE/TRUNCATE 后才执行）
   - 同时含表名（与 schema 中已知表名匹配）和列名 → 拼 SELECT * FROM {table} WHERE {col}=...（带条件）
   - 仅含表名（无列名/无条件）→ 拼 SELECT * FROM {table} LIMIT 10（小范围采样）
   - 仅含错误关键词（非 SQL 语法，非已知表名）→ 返回 status=skipped, error="cannot infer query from hint"
2. 执行查询 → 拿结果
3. 存档到 .claude-notes/repro/{batch_id|"single"}/db-{timestamp}.sql:
   含查询语句 + 结果（前 50 行）
```

#### intent=verify-fix

```
1. 读 .claude-notes/repro/{batch_id|"single"}/db-{timestamp}.sql 中的查询语句
2. 重跑同一查询
3. 对比两次结果 → repro_confirmed:
   - 行数不变 + 关键列值不变 → false（bug 仍存在）
   - 行数变化 / 错误数据消失 → true（修复生效）
```

### 5. 返回结果

```yaml
status: ok | no-creds | conn-failed | query-failed | skipped
evidence:
  - table: dict_task_type   # 仅 query-dict
    rows_sample: [...]
    total_rows: 8
notes_path: .claude-notes/{module}/dict-snapshots.md  # 仅 query-dict
repro_path: .claude-notes/repro/.../db-....sql        # 仅 reproduce
repro_confirmed: true | false                         # 仅 verify-fix
error: "..."                                          # 仅失败
```

## 错误处理

| 失败 | status | 说明 |
|------|--------|------|
| state.yml 不存在 | skipped | "no state.yml" |
| 用户拒填凭据 | skipped | "credentials collection declined by user" |
| 凭据字段为空 | skipped | "incomplete credentials" |
| 凭据收集后仍连不上 | conn-failed | 重试 1 次后返回 |
| SQL 语法错误 | query-failed | 返回 mysql 报错首行 |
| query_hint 无法推断 | skipped | "cannot infer query" |
| 10s 超时 | conn-failed | "timeout" |

## 安全约束

- 凭据**只**写 `.claude/.mpdev-runtime-creds.yml`
- **不**在返回的 YAML 中包含密码字段
- **不**对 query_hint 中的危险 SQL 关键字（DROP/DELETE/UPDATE/TRUNCATE/ALTER/INSERT）执行——遇到直接 status=skipped, error="dangerous SQL refused"
