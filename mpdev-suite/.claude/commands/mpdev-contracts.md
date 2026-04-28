---
name: mpdev-contracts
description: 契约仓库提取 — 从各模块 CLAUDE.md 交叉比对生成 robot-contracts（mpdev 生命周期阶段 0b）
allowed-tools: Read, Grep, Glob, Bash, TodoWrite, Write, Edit, AskUserQuestion
---

# /mpdev-contracts — 契约仓库提取

mpdev 套件**生命周期阶段 0b**。把"从多模块 CLAUDE.md 提取共享接口规范"这件事变成 mpdev 体系内的标准入口。

**底层工作流**：调用 `contract-extraction` skill（位于 `~/.claude/skills/contract-extraction/SKILL.md`，约 508 行）。本命令**不复制 skill 内容**——skill 是单一事实源，命令只做包装。

**定位**：

| mpdev 命令 | 阶段 | 前置 | 产出 |
|----------|------|------|------|
| `/mpdev-understand` | 0a | （新项目） | 各模块 `CLAUDE.md` |
| **`/mpdev-contracts`** | 0b | 各模块 `CLAUDE.md` 已就绪 | `robot-contracts/`（schemas + openapi + sql + events + flows + scripts） |
| `/mpdev-init` | 1 | `CLAUDE.md` + `robot-contracts/` 都已就绪 | `.claude/agents/` |
| `/mpdev` ... | 2+ | 同上 | 日常开发 |

**前置条件**（命令运行时会自检）：

- 各模块的 `CLAUDE.md` 已经存在且含**接口区块**（REST API / MQ 事件 / 数据库表 / 消息体字段映射 / 与其他模块的关系）
- 如果 CLAUDE.md 缺失或不完整 → 提示用户先跑 `/mpdev-understand`

**何时用**：

- 跨模块项目首次建立共享接口规范
- 模块接口发生大变更，需要重新提取契约（覆盖现有 contracts）
- Spring Cloud / 多服务项目要把分散的接口规范统一管理

**何时不用**：

- 单模块项目（无跨模块协作）
- 接口规范已用其他工具维护（如 Swagger Hub、Backstage）且不希望被覆盖

**Spring Cloud 项目特殊产出**（任一模块 CLAUDE.md 含 `spring-cloud-starter-*` / `Feign 远程调用` / `Gateway 路由` / `spring.application.name` 时自动触发）：

- `openapi/{service-name}.yaml` — 每个微服务独立一份（按 `spring.application.name` 而非目录名，便于 Feign 索引）
- `services/SERVICE_REGISTRY.md` — service-name ↔ 模块映射 + Feign 调用关系图
- `services/gateway-routes.yaml` — Gateway 路由契约（`lb://{service-name}`）
- Step 5 比对会额外验证 Feign 客户端的 service-name 是否在所有模块中可解析

---

## 用户输入

$ARGUMENTS

### 支持参数

| 参数 | 含义 | 示例 |
|------|------|------|
| 空 | 自动发现兄弟目录/二级目录的 CLAUDE.md | `/mpdev-contracts` |
| `output=<路径>` | 指定契约仓库目录（默认当前目录） | `/mpdev-contracts output=../robot-contracts` |
| `modules=<路径列表>` | 手动指定模块（不自动发现） | `/mpdev-contracts modules=../svc-a,../svc-b` |
| `force` | 覆盖现有 contracts（默认询问） | `/mpdev-contracts force` |
| `dry-run` | 只输出比对报告，不生成文件 | `/mpdev-contracts dry-run` |

---

## Step 1: 加载工作流 + 前置自检

```
1. 读 ~/.claude/skills/contract-extraction/SKILL.md 作为工作流指南
   未找到 → 提示安装并终止

2. 自动发现模块（沿用 skill Step 2 的兄弟目录扫描）
   计 N = 发现的有 CLAUDE.md 的模块数

3. 前置质量检查:
   - N == 0 → 终止，提示"未发现任何 CLAUDE.md，请先 /mpdev-understand"
   - N == 1 → 警告"只发现 1 个模块，提取契约意义有限"，询问是否继续
   - 任一 CLAUDE.md 缺少"接口区块"（REST API / MQ / DB 任一）→ 警告并列出缺失模块
```

## Step 2: 解析用户参数

```
output_dir = $ARGUMENTS.output 或 当前目录
explicit_modules = $ARGUMENTS.modules 或 自动发现
force = bool
dry_run = bool
```

## Step 3: 执行 skill 流程

按 contract-extraction skill 的 8 步执行：

```
Step 1: 初始化目录
        mkdir openapi/ schemas/ sql/ events/ flows/ scripts/
        services/  ← 仅 Spring Cloud 项目命中时填充
Step 2: 自动发现所有模块（前置已完成）
Step 3: 选择性读取 CLAUDE.md 接口区块（REST API / MQ / DB / Feign / Gateway）
Step 4: MQ 事件层比对（同 topic 发布者-消费者字段一致性）
Step 5: REST API 层比对（**含 Spring Cloud Feign**：客户端 vs 下游 service-name + 方法签名）
Step 6: 数据库层比对（SQL 列 vs Entity 字段）

⏸️ 第一暂停：Steps 4-6 比对结果合并呈现，等用户**逐条确认**不一致项

Step 7: 用户确认后生成全部契约文件
   ▸ 7.0 git checkpoint（生成前先 commit 一次空提交方便回退）
   ▸ 7.1 schemas/*.json — JSON Schema Draft 07，含公共字段 traceId + timestamp
   ▸ 7.2 openapi/*.yaml — **单体: 一份 backend.yaml；Spring Cloud: 每个 service-name 独立一份**
   ▸ 7.3 sql/V*.sql — 按建表依赖顺序重编号 + 幂等（INSERT IGNORE / ON DUPLICATE KEY UPDATE）
   ▸ 7.4 events/EVENT_CATALOG.md — 事件总表
   ▸ 7.5 flows/DATAFLOW.md — 端到端数据流（核心 + 异常 + 取消/回滚）
   ▸ 7.6 scripts/validate_contracts.py — Schema 格式校验
   ▸ 7.7 契约仓库自身 CLAUDE.md — 含维护规则 + 表总表
   ▸ 7.8 [Cloud] services/SERVICE_REGISTRY.md + gateway-routes.yaml — 仅 Spring Cloud
Step 8: 输出一致性报告

⏸️ 第二暂停：一致性报告呈现，等用户审核
```

**关键约束**（继承自 skill）：

- **两个暂停点**：Step 6 后（确认比对）+ Step 8 后（审核报告）
- 不一致项**必须用户确认**才生成最终契约（避免错误固化）
- 命名规范统一（snake_case for MQ fields, camelCase for Java entity fields）
- 生成的 SQL 必须**幂等**（INSERT IGNORE / IF NOT EXISTS）
- 生成校验脚本 `scripts/validate_contracts.py` 用于后续 `/mpdev-check`
- Step 7 前 git checkpoint 让用户可以一行 `git checkout .` 回退

**dry-run 模式**：跳过 Step 7 的文件生成，仅展示 Step 6 的比对报告（不进入第一暂停后的生成阶段）。

## Step 4: 📄 文档归档

```
timestamp = 当前时间 YYYYMMDD-HHMM
file_id = "{timestamp}-contracts"

Bash("mkdir -p .claude/mpdev-runs/setup")
Write(".claude/mpdev-runs/setup/{file_id}.md", ...)
```

**归档模板**：

```markdown
---
stage: contracts
generated_at: {timestamp}
output_dir: {output_dir}
modules_scanned: N
skill: contract-extraction
mode: full | dry-run
---

# 契约提取记录

## 用户输入
> {$ARGUMENTS 原文}

## 扫描范围
- 模块数：N
- 来源目录：{自动发现 / 手动指定}

## 三层比对结果

### MQ 事件层
- 发布者-消费者匹配：N 对一致 / M 对不一致
- 不一致明细（用户已确认）：...

### REST API 层
- 路径冲突：N 处
- 参数不一致：M 处

### 数据库层
- 表结构冲突：N 处
- 字段类型不一致：M 处

## 生成的契约文件
- openapi/*.yaml: N 个
- schemas/*.json: N 个
- sql/V*.sql: N 个
- events/EVENT_CATALOG.md
- flows/DATAFLOW.md
- scripts/validate_contracts.py
- {output_dir}/CLAUDE.md（契约仓库自身的元数据）

## 一致性报告
{skill Step 8 的输出}

## 下一步建议

- ✅ 契约仓库已生成
- ➡️ 建议下一步：`/mpdev-init` 生成 mpdev agent 定义
- 或：`/mpdev-check` 验证契约与代码的一致性

## 关联文件
- {output_dir}/openapi/...
- {output_dir}/schemas/...
- {output_dir}/sql/...
```

## Step 5: 与下游命令的衔接提示

```
if 是否首次创建（之前无 robot-contracts/）:
  → "建议下一步: /mpdev-init 初始化 mpdev 编排框架"
else:
  → "建议下一步: /mpdev-check 验证契约与现有代码的一致性"

如果检测到代码已经存在但 contracts 是新生成的:
  → 强烈建议跑 /mpdev-check 找漂移点
```

---

## 容错规则

| 情况 | 处理 |
|------|------|
| skill 文件未找到 | 提示安装 `contract-extraction` skill 并终止 |
| 0 个模块 | 终止，提示先 `/mpdev-understand` |
| 1 个模块 | 警告并询问是否继续（可能不需要 contracts） |
| CLAUDE.md 缺接口区块 | 警告并列出，让用户选：[继续（接口少不准）/ 终止补 CLAUDE.md / 排除该模块] |
| 已存在 robot-contracts/ 且未指定 force | 询问：[覆盖 / 仅 dry-run 看差异 / 取消] |
| 比对发现严重不一致（>20%）| 强制进入 dry-run，不自动生成；让用户先修 CLAUDE.md |
| 命名规范冲突（同一字段 snake vs camel）| 询问采用哪种规范，写入契约 CLAUDE.md 的"命名约定"段 |

## 约束

1. **不复制 skill 内容** — skill 是单一事实源
2. **不一致项必须用户确认** — 不能静默选边
3. **SQL 必须幂等** — 生成的 V*.sql 用 `INSERT IGNORE` / `IF NOT EXISTS`
4. **生成校验脚本** — `scripts/validate_contracts.py` 是 `/mpdev-check` 的依赖
5. **覆盖前必备份** — force 模式也要备份现有 robot-contracts/ 到 `.bak.{timestamp}/`
6. **不自动跳到 init** — 完成后展示建议，让用户审查契约后再决定
7. **必写归档文档** — 即使是 dry-run 也写一份归档到 `mpdev-runs/setup/`
8. **命名约定写入契约自身 CLAUDE.md** — 让 `/mpdev-init` 之后能读到统一规范
