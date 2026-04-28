---
name: mpdev-check
description: 契约漂移检测 — 检查 robot-contracts 与实际代码之间的一致性
allowed-tools: Read, Grep, Glob, Bash
---

# /mpdev-check — 契约漂移检测器

检测契约仓库（robot-contracts）与各模块实际代码之间的不一致。
用于 `/mpdev` 执行前或手动修改代码/契约后的一致性验证。

## 检测流程

### 准备：识别项目结构

1. 找到契约仓库：`Glob("**/robot-contracts/schemas") 或 Glob("**/contracts/schemas")`
2. 找到各模块：`Glob("**/CLAUDE.md")` → 排除 .claude/ node_modules/ .git/
3. 如果找不到契约仓库 → 输出 "未找到契约仓库，跳过检测" 并结束

### L1：MQ 消息字段一致性

对契约仓库 `schemas/` 下的每个 `.json` 文件：

```
1. 读 schema JSON，提取 properties 下所有字段名 → schema_fields
2. 从 schema 文件名推断 queue 名（如 alarm_data_queue.json → alarm_data_queue）
3. 在所有模块中 grep 该 queue 名，找到:
   - 生产者: grep "queue.*=.*{queue_name}\|routing_key.*{queue_name}\|publish.*{queue_name}" → 找到后读该方法，提取实际 publish 的 dict 字段 → producer_fields
   - 消费者: grep "@RabbitListener.*{queue_name}\|channel.*{queue_name}" → 找到后读该方法，提取实际解析的字段 → consumer_fields
4. 比对:
   - schema 有但 producer 没发: ⚠️ "schema 定义了 {field} 但生产者未发送"
   - producer 发了但 schema 没有: ⚠️ "生产者发送 {field} 但 schema 未定义"
   - schema 有但 consumer 没解析: ℹ️ "schema 定义了 {field} 但消费者未解析"（低优先级，可能是 optional）
   - producer 发了但 consumer 没解析: ⚠️ "生产者发送 {field} 但消费者未解析"
```

### L2：SQL 迁移 vs Entity 一致性

```
1. 读契约仓库 sql/ 下所有 V*.sql 文件
2. 提取 ALTER TABLE ... ADD COLUMN / CREATE TABLE 的表名+列名
3. 对每个表+列:
   - Java: grep "private.*{camelCase(column)}" 或 "@TableField.*{column}" → 找 Entity 是否有
   - Python: grep "{column}" 在 model/entity 文件中
4. 报告:
   - SQL 有但 Entity 没有: ⚠️ "SQL 迁移新增 {table}.{column} 但 Java Entity 未更新"
   - Entity 有但 SQL 没有: ⚠️ "Entity 有 {field} 但无对应 SQL 迁移"（可能是手动加的）
```

### L3：OpenAPI vs Controller 一致性

```
1. 读契约仓库 openapi/*.yaml 的 paths
2. 对每个 path+method:
   - grep Controller 中对应的 @RequestMapping/@PostMapping/@GetMapping
   - 比对: path 是否存在、参数是否匹配
3. 报告:
   - OpenAPI 有但 Controller 没有: ⚠️ "OpenAPI 定义了 {method} {path} 但无对应 Controller"
   - Controller 有但 OpenAPI 没有: ℹ️ "Controller {path} 未在 OpenAPI 中定义"（低优先级）
```

## 输出格式

```markdown
# 契约漂移检测报告

## 检测范围
- 契约仓库: {path}
- 检测模块: {module_list}
- 检测时间: {timestamp}

## 检测结果

### L1: MQ 消息字段一致性
- 检测 queue 数: N
- ✅ 一致: N | ⚠️ 不一致: N

{如有不一致，逐条列出:}
| Queue | 字段 | 问题 | 建议 |
|-------|------|------|------|
| alarm_data_queue | silent | schema 有但消费者未解析 | 在 AlarmDataListener 中添加解析 |

### L2: SQL 迁移 vs Entity
- 检测迁移数: N
- ✅ 一致: N | ⚠️ 不一致: N

{如有不一致，逐条列出}

### L3: OpenAPI vs Controller
- 检测 API 数: N
- ✅ 一致: N | ⚠️ 不一致: N

{如有不一致，逐条列出}

## 总结

{无漂移: "✅ 契约与代码一致，可安全执行 /mpdev"}
{有漂移: "⚠️ 检测到 N 处不一致，建议先修复再执行 /mpdev。不一致项在 /mpdev 运行时可能导致 integration-checker 报错。"}
```

## 约束

1. **只读不写** — 不修改任何文件
2. 检测范围以契约仓库为基准（有契约才检测，无契约不报）
3. ⚠️ 级别才需要关注，ℹ️ 级别仅供参考
4. 如果某个模块没有相关代码（如算法模块不消费 MQ），跳过不报
