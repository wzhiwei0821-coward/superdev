# MPDev — 多模块 AI 协同开发方案

> 版本 1.0 | 2026-04-16 | 通用多模块项目 AI 协同开发框架

---

## 0. 本项目实例

本文件是 MPDev 框架的**通用方案说明**。框架核心（`commands/` + `templates/` + 本文档）与项目解耦；`agents/` 由 `/mpdev-init` 扫描本仓库 CLAUDE.md 后自动生成。

当前仓库的实例信息：

| 字段 | 值 |
|------|----|
| **项目实例名** | `mpdevops` |
| **业务背景** | 机器人巡检平台（6 模块跨栈） |
| **技术栈** | Java + Vue + Python×3 + 算法服务 |
| **Agent 来源** | `.claude/agents/` 由 `/mpdev-init` 按本项目 CLAUDE.md 生成 |
| **复用到其他项目** | 拷 `commands/` + `templates/` + 本文档 → 跑 `/mpdev-init` → 修改本节 |

---

## 1. 方案概述

### 1.1 解决什么问题

跨模块项目（**多语言 + 多协议**）的协同开发痛点：模块间通过 MQ / HTTP / WebSocket / IPC 等多种协议交互，字段命名规范各不相同（Java camelCase / Python snake_case / MQ snake_case），跨语言重复定义同一概念，历史遗留拼写不一致，手工开发极易出现跨模块字段不对齐、遗漏硬编码白名单等问题。

**以本仓库的 mpdevops 实例为例**：6 模块跨栈，一个典型需求（如"增加夜间巡检任务类型"）需要同时改动 Java 后端、Python 调度、Python 分析管道、Vue 前端、契约仓库，以及可能涉及算法服务。MPDev 把这种工作流抽象成可复用的多 agent 编排框架。

### 1.2 MPDev 是什么

MPDev（Multi-module Platform Development）是一套 **AI 多 Agent 协同开发框架**。开发者用自然语言描述需求，系统自动编排 12 个 AI Agent（含条件触发的 DBA + 项目类型自适应的 Tester），以"契约先行 → 并行实现 → 三级质量门禁 + 三阶段测试嵌入"的流程完成跨模块开发。

### 1.3 核心理念

| 理念 | 说明 |
|------|------|
| **契约先行** | 在写任何业务代码前，先更新**契约仓库**中的 Schema/OpenAPI/SQL/事件目录，所有 impl Agent 以契约为实现依据（mpdevops 实例的契约仓库目录叫 `robot-contracts/`，其他项目可自定义）|
| **代码驱动** | Architect 的每个结论必须有 grep/read 验证的代码证据，不接受"应该可以"式猜测 |
| **三级质量门禁** | 自测 → 审查+联测 → 验收，每级关注不同维度，层层收窄缺陷 |
| **失败可降级** | 关键路径（Architect/Contract）失败终止流程；非关键路径（Impl/Review）失败可跳过，汇总标注完成度 |

### 1.4 平台架构

```
┌─────────┐   REST    ┌─────────┐  MQ+HTTP  ┌──────────┐   IPC    ┌───────────┐  HTTP   ┌──────────┐
│ Vue 前端 │ ───────→ │Java 后端│ ────────→ │Python 调度│ ───────→ │Python 分析│ ──────→ │Python 算法│
│ 4 子应用 │ ←─ws──── │8094     │ ←──MQ──── │8888+ROS  │ ←─IPC─── │asyncio    │ ←─HTTP── │8087      │
└─────────┘          └─────────┘           └──────────┘          └───────────┘         └──────────┘
                           ↕                     ↕                     ↕
                     MySQL / Redis（共享）
```

| 模块 | 目录 | 技术栈 |
|------|------|--------|
| Java 后端 | mr_ult_java_2.1 | Spring Boot 2.3.12, MyBatis-Plus, 8 Maven 模块, 169 Controller |
| Vue 前端 | mr_ult_vue_2.1 | 4 子应用 (H5/Pad/Web/LargeScreen), Vue 2+3 混合 |
| 调度系统 | mr_ult_dispatch_2.1 | Python + ROS Noetic, 7 进程, Flask |
| 分析管道 | mr_ult_analystic_2.1 | Python asyncio, 4 阶段 pipeline |
| 算法系统 | mr_ult_algor_2.1 | Flask + Gunicorn, 14 算法 (YOLOv5/OCR) |
| 契约仓库 | robot-contracts | OpenAPI + JSON Schema + SQL migration |

---

## 2. 角色定义

MPDev 共有 **12 个 AI Agent 角色**，分为 5 类：

### 2.1 架构类（3 个）

#### Architect — 平台架构师

| 属性 | 描述 |
|------|------|
| **职责** | 基于实际代码分析评估需求可行性，产出 Technical Blueprint 指导所有后续 Agent |
| **工作方式** | 读契约仓库 → grep 各模块关键字 → read 关键文件 → 分析跨模块数据流 → 评估风险 |
| **关键产出** | Technical Blueprint（5 段结构化文档） |
| **特殊规则** | 每个结论必须有代码证据（file:line）；"无需改动"必须给出可验证的代码证据；新增枚举值时执行 5 步必查项（硬编码白名单 → switch/case → 条件列表 → 前端声音/UI → isExist 方法） |
| **失败影响** | 🔴 **流程终止**（后续所有 Agent 无法工作） |

**Blueprint 五段结构：**

| 段落 | 内容 | 消费者 |
|------|------|--------|
| §1 可行性评估 | 结论 + 代码依据 + 工作量估算 | 用户确认 |
| §2 架构影响 | 新增依赖/通信变更/DB 变更/性能/兼容性 | Contract-Designer |
| §3 模块实现蓝图 | 每个模块的改动文件、方法、行号 | 各 Impl Agent（按 §3.x 分段注入） |
| §4 跨模块协作 | 数据流 + 字段契约表(含 breaking 标注) + 时序图 | Contract-Designer / Integration-Checker |
| §5 风险与缓解 | 每条风险指定负责模块 + 实现方式 | 各 Impl Agent（作为必做 checklist） |

#### DBA — 数据库架构师（条件触发）

| 属性 | 描述 |
|------|------|
| **职责** | 在 Architect 后、Contract-Designer 前，深入设计数据层：表结构、索引、迁移安全、一致性、容量 |
| **触发条件** | Blueprint §2 标注 DB 变更，或需求含"新增表/字段/索引/现有字段修改" |
| **工作方式** | 读 Blueprint → Glob Entity → Grep 历史 SQL 迁移 → 按 7 步设计顺序产出 DBA Design Doc |
| **关键产出** | DBA Design Doc（9 节：数据变更清单、DDL 草稿、迁移策略、索引决策、数据一致性、历史回填、容量性能、风险缓解、交付清单） |
| **特殊规则** | 不连真实 DB（只读代码推断）；instant DDL 优先；默认不加索引；每个 DDL 必有回滚脚本 |
| **失败影响** | 🟡 **可选步骤**：需用户决定修蓝图、接受妥协还是终止；不强制终止流程 |

**DBA Design Doc 9 节结构**：

| 节 | 内容 | 消费者 |
|---|------|-------|
| §1 数据变更清单 | 表/操作/字段/类型/索引/回填 | Contract-Designer |
| §2 DDL 草稿 | 完整 SQL + 回滚 | Contract-Designer（直接作为 V*.sql 内容）|
| §3 迁移策略 | 表规模/DDL 类型/锁影响/执行方式 | 用户 + 运维 |
| §4 索引决策 | 查询/是否加/理由 | Contract-Designer（若加索引作独立 V*.sql）|
| §5 数据一致性 | 写入方/读取方/一致性级别/事务边界 | 各 Impl Agent |
| §6 历史数据回填 | 表/字段/回填值/脚本 | 各 Impl Agent / 运维 |
| §7 容量与性能 | 增速/3年预估/查询风险 | 用户决策 |
| §8 风险与缓解 | 风险/可能性/影响/缓解 | 用户 |
| §9 交付清单 | SQL 文件 / 回滚 / Entity 变更负责方 | Contract-Designer + Impl Agents |

---

#### Contract-Designer — 契约仓库维护者

| 属性 | 描述 |
|------|------|
| **职责** | 先于所有 Impl Agent 更新契约仓库，确保跨模块接口一致 |
| **工作方式** | 读 Blueprint §2+§4 → 更新 SQL/Schema/OpenAPI/事件目录 → 运行校验脚本 |
| **关键产出** | contract_changes（Part 1 文件变更 + Part 2 结构化字段摘要） |
| **特殊规则** | SQL 必须幂等（INSERT IGNORE）；MQ 新字段 optional+snake_case；所有输出字段必须存在，无变更输出 `[]` |
| **失败影响** | 🔴 **流程终止**（Impl 无契约可遵循） |

**产出的 Part 2 结构化摘要**直接被 Impl Agent 消费：

| 字段 | 说明 | 消费者 |
|------|------|--------|
| new_fields | 新增 MQ/DB 字段，含类型、位置、是否 required | 全部 Impl Agent |
| new_enum_values | 新增枚举值，含值、名称、位置 | 全部 Impl Agent |
| api_changes | HTTP API 变更 | 对应 Impl Agent |

---

### 2.5 测试类（1 个）

#### Tester — 测试工程师（项目类型自适应）

| 属性 | 描述 |
|------|------|
| **职责** | 基于契约和实现代码，**系统性**完成测试设计/执行/报告全流程；遵循 ISTQB 5 阶段 + IEEE 829 文档标准 |
| **触发模式** | **3 个模式**对应 `/mpdev` 三个嵌入点：A=test-architect（Step 7）/ B=test-executor（Step 9）/ C=test-reporter（Step 12）|
| **工作方式** | 模式 A：读 Blueprint + contract → 设计用例（必用 3+ 种黑盒技术：等价类/边界值/决策表/状态机/场景/错误推测）；模式 B：生成自动化代码 + 跑测试 + 登记缺陷；模式 C：汇总数据 + 准出建议 |
| **关键产出** | 5 份 IEEE 829 标准文档 + 自动化测试代码 |
| **特殊规则** | P0 用例 100% 自动化；缺陷必须可复现；测试代码不污染业务代码（独立 test/ 目录）；缺陷状态机 open→in-progress→resolved→closed |
| **失败影响** | 🟡 **可选嵌入**：tester.md 缺失时跳过（带警告）；P0 缺陷可触发流程暂停由用户决定 |

**项目类型自适应**（双层模板，类似 DBA）：

- **骨架**：`templates/tester.tmpl`（通用 ISTQB + IEEE 829 + 6 种用例设计技术）
- **方言**：`templates/test-flavors/{type}.md`（按项目类型注入 8 个 BLOCK：测试级别 / 风险点 / 自动化栈 / CI / 度量 / 非功能 / 用例样板 / 特定约束）
- **当前支持**：`http-api`（Spring Boot/Express/FastAPI 等），未来扩展 web-frontend / microservices / data-pipeline / algo-service / robot-iot / mobile-app

**Tester Doc 5 节标准产出**（IEEE 829 模板）：

| 节 | 路径 | IEEE 829 模板 | 产出模式 |
|---|------|--------------|---------|
| 测试计划 | `02.5-test-plan.md` | Test Plan | A |
| 测试用例规格 | `02.7-test-cases.md` | Test Case Specification | A |
| 测试日志 | `03.5-test-log.md` | Test Log | B |
| 缺陷登记 | `03.6-test-incidents.md` | Test Incident Report | B |
| 测试总结 | `05.5-test-summary.md` | Test Summary Report | C |

**与 /mpdev-fix 衔接**：tester 登记的缺陷可通过 `/mpdev-test bug export` 导出为 markdown 清单，直接喂给 `/mpdev-fix --batch` 形成"测试 → 修复 → 回归"闭环。

---

### 2.2 实现类（5 个）

> **本节描述以 mpdevops 实例化的 5 个 impl agent 为例**（dispatch / analytics / java / vue / algor）。MPDev 套件层面的通用模板只有 3 个：`templates/impl-java.tmpl` / `impl-python.tmpl` / `impl-vue.tmpl`。`/mpdev-init` 扫描各项目 CLAUDE.md 后实例化为具体 agent —— 数量与名字随项目而定（mpdevops 是 5 个）。下方的 ROS / Flask / asyncio / 4 子应用 / PyTorch 等技术栈描述是 mpdevops 项目特有，不是 MPDev 框架要求。

每个 impl agent 负责各自模块的代码实现和单元自测，共享相同的工作范式：

**通用工作流：**
```
读 Blueprint → 读目标代码 → 实现变更 → 写测试 → 运行测试
→ 风险缓解 checklist → 变量使用自查 → [模块特有检查] → 自修复(≤3轮)
```

#### Java-Impl — Java 后端开发者

| 属性 | 描述 |
|------|------|
| **模块** | mr_ult_java_2.1 |
| **技术栈** | Java 1.8, Spring Boot 2.3.12, MyBatis-Plus 3.4.0 |
| **测试** | JUnit 5 + Mockito, `mvn test -pl {module}` |
| **特殊产出** | `api_changes_summary`（Controller/MQ/WebSocket 变更描述，供 Vue-Impl 消费） |
| **关键规范** | Controller 返回 AjaxResult；MQ MANUAL ack；Entity camelCase / DB snake_case；fastjson(业务) vs Jackson(MQ) 不混用 |

#### Dispatch-Impl — 调度系统开发者

| 属性 | 描述 |
|------|------|
| **模块** | mr_ult_dispatch_2.1 |
| **技术栈** | Python 3.x + ROS Noetic, Flask, 7 进程架构 |
| **测试** | pytest + mock（ROS 必须 mock） |
| **特有检查** | **启动恢复检查**：如设置了 Redis 状态标志，确认 robot_main.py 启动时有清理逻辑（因 stop.sh 用 kill -9，finally 不执行） |
| **关键规范** | Redis 键必须在 robot_redis_key.py 注册常量；MQ 通过 robot_rabbit_mq.py 发布；pro/ult 双版本都要处理 |

#### Analytics-Impl — 分析管道开发者

| 属性 | 描述 |
|------|------|
| **模块** | mr_ult_analystic_2.1 |
| **技术栈** | Python asyncio, 4 阶段 pipeline |
| **测试** | pytest-asyncio + mock |
| **特有检查** | **数据类型覆盖**：透传字段必须同时处理 dict 和 list 返回类型（试跑教训：只处理 dict 导致 list 场景数据丢失） |
| **关键规范** | 全异步 async/await（MQ 例外用同步 pika）；GAME_OVER_FLAG 常量引用 |

#### Vue-Impl — 前端开发者

| 属性 | 描述 |
|------|------|
| **模块** | mr_ult_vue_2.1（4 个子应用） |
| **技术栈** | Vue 2+3 混合, ElementUI/Vant/Avue |
| **测试** | `npm run build` 构建检查 |
| **特有检查** | ① **变量使用自查**：每个从 WebSocket/API 解析的新字段必须被实际用于控制 UI（不能只赋值后丢弃）；② **多端一致检查**：grep 所有子应用的同一 WebSocket sid 订阅点 |
| **关键规范** | 纯 JS 无 TS；window.Glod(pad/web) vs window.Glob(大屏) 保留；向后兼容旧 WebSocket 格式 |
| **前置依赖** | Java-Impl 的 `api_changes_summary`（串行等待） |

#### Algor-Impl — 算法系统开发者

| 属性 | 描述 |
|------|------|
| **模块** | mr_ult_algor_2.1 |
| **技术栈** | Flask + Gunicorn, PyTorch 1.8 |
| **两种模式** | **实现模式**（有代码改动）/ **验证模式**（确认不需改动，输出验证报告） |
| **特点** | 纯 HTTP 服务，不感知 MQ/DB/任务类型，多数需求为验证模式 |

---

### 2.3 审查类（2 个）

#### Code-Reviewer — 代码审查员

| 属性 | 描述 |
|------|------|
| **职责** | 审查所有 Impl Agent 产出的代码质量 |
| **审查框架** | **六维**：Blueprint 遵循度 / 编码规范一致性 / 安全性 / 健壮性 / 性能 / 测试质量 |
| **输出** | approve / request_changes / comment_only，含分级 findings（🔴critical / 🟡important / 🟢suggestion） |
| **特殊规则** | 只审查本次变更文件；critical 仅用于真 bug/安全漏洞/数据丢失 |
| **不做** | 不修改代码，只输出报告 |

#### Integration-Checker — 集成验证工程师

| 属性 | 描述 |
|------|------|
| **职责** | 验证跨模块变更的一致性 |
| **检查框架** | **三层联测**：L1 契约一致性（枚举值/MQ 字段/HTTP API/WebSocket/DB 五项静态比对）→ L2 模拟联调（字段流转追踪）→ L3 构建验证 |
| **输出** | pass / warn / fail，含 fix_actions 指定修复模块 |
| **特殊规则** | Blueprint §4 字段契约表作为"正确答案"参照；L1+L3 必做，L2 跨模块变更时必做 |
| **不做** | 不修改代码，只输出报告 |

---

### 2.4 验收类（1 个）

#### Acceptance-Reviewer — 交付验收审查员

| 属性 | 描述 |
|------|------|
| **职责** | 最终关卡——验证交付物是否匹配用户原始需求 |
| **验收框架** | **五维**：需求覆盖度 / 场景完整性 / 交付完整性 / 范围控制 / 风险闭环 |
| **输出** | accept / conditional_accept / reject |
| **特殊规则** | 以用户原始需求为唯一标准；自行 grep/read 代码验证，不依赖 Impl 报告；"隐式实现"（Architect 判定无需改动）必须独立验证；Blueprint §5 每条风险逐项核对 |
| **不关心** | 代码风格、安全漏洞、跨模块一致性（已由其他 Agent 覆盖） |

---

### 2.5 角色关系总览

```
                           用户
                            │
                   ┌────────┴────────┐
                   │   /mpdev 编排器  │  ← 主会话，管理全局流程
                   └────────┬────────┘
                            │
              ┌─────────────┴─────────────┐
              ▼                           ▼
        ┌───────────┐              ┌───────────────┐
        │ Architect │              │Contract-Designer│
        │  (架构师)  │──Blueprint──→│  (契约维护者)   │
        └─────┬─────┘              └───────┬───────┘
              │                            │
              │ §3.x+§5                    │ Part 2 结构化摘要
              │                            │
    ┌─────────┼──────────┬─────────┐       │
    ▼         ▼          ▼         ▼       │
┌───────┐┌────────┐┌──────────┐┌───────┐  │
│Java   ││Dispatch││Analytics ││Algor  │←─┘
│Impl   ││Impl    ││Impl      ││Impl   │
└───┬───┘└────────┘└──────────┘└───────┘
    │ api_changes_summary
    ▼
┌────────┐
│Vue Impl│
└────────┘
    │ (全部 Impl 完成)
    ▼
┌─────────────┐     ┌────────────────────┐
│Code-Reviewer│     │Integration-Checker │
│ (代码审查)   │     │  (集成验证)         │
└──────┬──────┘     └────────┬───────────┘
       │         并行         │
       └──────────┬───────────┘
                  ▼
         ┌────────────────┐
         │Acceptance-     │
         │Reviewer (验收)  │
         └────────────────┘
```

---

## 3. 流程详解

### 3.1 三种工作模式

| 模式 | 适用场景 | 流程 | 示例 |
|------|---------|------|------|
| **Quick (A)** | 单模块、小改动、无跨模块字段变更 | Architect(可选) → Contract → 单 Impl → Review+Check → Acceptance → 汇总 | `/mpdev 给告警表加一个备注字段` |
| **Cross-Module (B)** | 涉及 2+ 模块、新增 MQ/API/DB 字段 | Architect → Contract → 并行 Impl → Review+Check(全三层) → Acceptance → 汇总 | `/mpdev 增加夜间巡检任务类型` |
| **Exploration (C)** | 探索/调查/理解代码，不改代码 | Architect(仅分析) → 多 Explore Agent 并行 → 汇总报告 | `/mpdev 追踪 GAME_OVER 在 5 个模块中的流转` |

**模式判断规则：**
- 涉及 2+ 模块同时变更（新增字段/接口/事件/状态流转）→ B
- 提到"前端/页面/UI"且不涉及新 API → 可能 A
- 提到"查看/分析/追踪/调查/了解" → C
- 不确定 → 默认 B

### 3.2 Cross-Module (B) 完整 7 步流程

这是最完整的流程，Quick (A) 是其简化版，Exploration (C) 是其探索版。

```
时间线 ──────────────────────────────────────────────────────────────────────→

Step 1                Step 2                 Step 3
模式识别 ──→ Architect 读代码+Blueprint ──→ Contract-Designer 更新契约
 (主会话)      (subagent)  │                    (subagent)
                           ↓
                      用户确认 Blueprint
                                                  │
        ┌─────────────────────────────────────────┘
        │
Step 4  │   Phase 1: 并行启动                Phase 2: 串行启动
        ├──→ Java-Impl ──────┐
        ├──→ Dispatch-Impl ──┤                     ┌─→ Vue-Impl
        ├──→ Analytics-Impl ──┼── 全部返回后 ──────→┤   (需要 Java 的
        └──→ Algor-Impl ─────┘                     │    api_changes_summary)
                                                   └───────┐
                                                           │
Step 5      并行启动                                        │
        ┌── Code-Reviewer ──────┐                          │
        │                       ├── 合并处理 ──→ [修复循环≤2轮]
        └── Integration-Checker─┘
                │
Step 6          ↓
        Acceptance-Reviewer ──→ [修复循环≤1轮]
                │
Step 7          ↓
            汇总报告
```

---

### 3.3 Step 逐步详解

#### Step 1：模式识别（主会话）

编排器分析需求关键词，判断 A/B/C 模式，一句话说明原因，等用户确认。

#### Step 2：Architect 架构评估

1. 编排器从各模块 CLAUDE.md 按关键词提取 ≤200 行相关段落
2. 启动 Architect Agent，注入需求原文 + 模块上下文
3. Architect 读代码产出 Technical Blueprint（5 段）
4. **编排器提取摘要呈现给用户，等待用户确认后才继续**

用户可在此调整方向（"不改算法"/"降速改 0.3"等）。

#### Step 3：Contract-Designer 契约更新

注入 Blueprint §2+§4，Contract-Designer 更新：
- SQL 迁移脚本（幂等）
- MQ JSON Schema（新字段 optional）
- OpenAPI 定义（标注 x-added-version）
- 事件目录

产出 Part 2 结构化摘要，直接作为 Impl Agent 的输入。

#### Step 4：Impl Agent 并行实现

**Phase 1 — 并行启动（4 Agent 同时执行）：**

每个 Impl Agent 注入：
- Blueprint §3.x（仅本模块段落）
- Blueprint §5（风险缓解措施，作为必做 checklist）
- 契约变更 Part 2
- 对应模块 CLAUDE.md 相关段落

```
Java-Impl ──────────┐
Dispatch-Impl ──────┤  并行执行，互不依赖
Analytics-Impl ─────┤
Algor-Impl ─────────┘
```

**Phase 2 — 串行启动（1 Agent）：**

Phase 1 全部返回后：
- Java-Impl 成功 → 提取 `api_changes_summary` → 启动 Vue-Impl
- Java-Impl 失败 → Vue-Impl 跳过，标注"因 Java-Impl 失败而阻塞"

**每个 Impl Agent 内部执行：**
```
读 Blueprint → 读目标代码 → 实现变更 → 写测试 → 运行测试
→ 编译/import 检查 → 风险缓解 checklist → 变量使用自查
→ [模块特有检查] → 发现问题则自修复（最多 3 轮）
```

#### Step 5：Code Review + Integration Check（并行）

所有 Impl 完成后，**并行**启动两个审查 Agent。

**3×3 结果矩阵（关键决策表）：**

| Code-Reviewer | Integration-Checker | 处理方式 |
|:---:|:---:|------|
| approve | pass | → 直接进入 Step 6 |
| approve | warn | 呈现 warn → 用户确认 → Step 6 |
| approve | fail | → 修复循环(integration) |
| request_changes | pass | → 修复循环(review critical) |
| request_changes | warn | → 修复循环(合并两方) |
| request_changes | fail | → 修复循环(合并两方) |
| comment_only | pass | 呈现 comments → Step 6 |
| comment_only | warn | 呈现 comments+warn → 用户确认 → Step 6 |
| comment_only | fail | → 修复循环(integration) |

**修复循环：** 合并 findings 按模块分组 → 分派对应 Impl Agent → 并行重跑检查（只审修复文件）→ 最多 2 轮，超限残留 warn 呈现用户。

#### Step 6：Acceptance Review（验收）

注入：用户原始需求（一字不改） + Blueprint 全文 + 所有 Impl 变更摘要 + Review/Check 结果

| 验收结果 | 处理 |
|---------|------|
| accept | → Step 7 |
| conditional_accept | 呈现条件 → 用户选择修复或接受 |
| reject | 呈现缺失项 → 轻度补充 / 重度回 Architect |

最多 1 轮验收修复。第 2 次仍 reject → 交用户人工判断。

#### Step 7：汇总报告

输出结构化报告：模式 + 验收状态 + 变更统计 + 代码审查 + 集成校验 + 验收审查 + 未修复项。

---

## 4. 协作方式

### 4.1 上下文传递链

Agent 之间不直接通信，由**编排器**（/mpdev）负责上下文提取和注入：

```
Architect
  │
  ├── Blueprint §2+§4 ─────────────────────→ Contract-Designer
  ├── Blueprint §3.1 + §5 ─────────────────→ Java-Impl
  ├── Blueprint §3.2 + §5 ─────────────────→ Dispatch-Impl
  ├── Blueprint §3.3 + §5 ─────────────────→ Analytics-Impl
  ├── Blueprint §3.4 + §5 ─────────────────→ Algor-Impl
  └── Blueprint §3.5 + §5 ─────────────────→ Vue-Impl
                                                 ↑
Contract-Designer                                │
  └── Part 2 (new_fields/enum/api) ────────→ 所有 Impl
                                                 ↑
Java-Impl                                       │
  └── api_changes_summary ──────────────────────┘
                                              (仅 Vue)
所有 Impl 产出
  ├── changes + mq_publish_changes ────────→ Integration-Checker
  ├── 变更文件列表 ────────────────────────→ Code-Reviewer
  └── 全部变更摘要 ────────────────────────→ Acceptance-Reviewer
```

### 4.2 依赖与并行规则

```
                    串行依赖链
    ┌─────────────────────────────────┐
    │                                 │
 Architect → Contract-Designer → Impl Phase 1 → Impl Phase 2 → Review/Check → Acceptance
                                  (并行)        (串行)          (并行)
                               Java ──┐         Vue
                               Dispatch┤
                               Analytics┤
                               Algor ──┘
```

| 规则 | 说明 |
|------|------|
| Contract → 所有 Impl | 契约是实现的前置依赖，必须先完成 |
| Java → Vue | Vue 需要 Java 的 api_changes_summary，必须串行 |
| Java/Dispatch/Analytics/Algor | 互不依赖，并行执行 |
| Code-Reviewer / Integration-Checker | 互不依赖，并行执行 |
| 某 Impl 失败 | 不阻塞其他无依赖 Impl（Java 失败会阻塞 Vue） |

### 4.3 三级质量门禁

```
     ┌─────────────────────────────────────────────────────────────────┐
     │                                                                 │
     │  第一级: 自测 (Impl 内部)                                        │
     │  ├── 单元测试 (JUnit/pytest/npm build)                          │
     │  ├── 编译/import 检查                                           │
     │  ├── 风险缓解 checklist (逐条核对 Blueprint §5)                  │
     │  ├── 变量使用自查 (新字段是否被实际使用)                          │
     │  └── 模块特有检查 (启动恢复/数据类型覆盖/多端一致等)              │
     │      ↓ 自修复≤3轮                                               │
     ├─────────────────────────────────────────────────────────────────┤
     │                                                                 │
     │  第二级: 审查+联测 (并行)                                        │
     │  ├── Code-Reviewer: 六维代码审查                                │
     │  │   (Blueprint 遵循/规范/安全/健壮/性能/测试)                   │
     │  └── Integration-Checker: 三层联测                              │
     │      (L1 契约一致/L2 模拟联调/L3 构建验证)                       │
     │      ↓ 修复循环≤2轮                                             │
     ├─────────────────────────────────────────────────────────────────┤
     │                                                                 │
     │  第三级: 验收 (最终)                                             │
     │  └── Acceptance-Reviewer: 五维需求验收                          │
     │      (覆盖度/场景/交付/范围/风险)                                │
     │      ↓ 修复循环≤1轮                                             │
     └─────────────────────────────────────────────────────────────────┘
```

**各级聚焦维度不重叠：**

| 门禁 | 聚焦 | 不关心 |
|------|------|--------|
| 自测 | 代码能跑、测试通过、无遗漏字段 | 跨模块一致性 |
| 代码审查 | 代码质量、安全、性能、规范 | 需求是否完整 |
| 集成验证 | 跨模块字段对齐、协议一致 | 代码风格 |
| 验收 | 需求是否做对、场景是否完整 | 代码风格、安全 |

### 4.4 容错与降级

#### 关键路径 vs 非关键路径

| Agent | 路径类型 | 失败处理 |
|-------|---------|---------|
| Architect | 🔴 关键路径 | 流程终止 |
| Contract-Designer | 🔴 关键路径 | 流程终止 |
| Impl Agents | 🟡 非关键路径 | 跳过该模块，下游依赖标注阻塞 |
| Code-Reviewer | 🟡 非关键路径 | 跳过 Review，标注"未审查" |
| Integration-Checker | 🟡 非关键路径 | 跳过联测，标注"未验证" |
| Acceptance-Reviewer | 🟡 非关键路径 | 跳过验收，标注"未验收" |

#### 修复循环上限

| 环节 | 最大轮次 | 超限处理 |
|------|---------|---------|
| Impl 自测自修复 | 3 轮 | 输出 fail_with_report，不重试 |
| Step 5 Review/Integration | 2 轮 | 残留 warn 呈现用户决定 |
| Step 6 Acceptance | 1 轮 | 交用户人工判断 |

#### 通用规则
- 用户说"停"/"取消" → 立即停止后续 Agent，已变更保留
- 不自动 git commit，用户决定何时提交
- 部分完成也有价值，汇总报告标注完成度

### 4.5 用户参与点

| 时机 | 用户操作 | 是否阻塞 |
|------|---------|---------|
| Step 1 模式识别后 | 确认模式判断 | 是 |
| Step 2 Blueprint 产出后 | **审阅 Blueprint**，可调整方向 | 是（最关键决策点） |
| Step 5 有 warn 时 | 决定修复还是接受 | 是 |
| Step 6 conditional_accept 时 | 决定修复还是接受 | 是 |
| Step 7 汇总后 | 决定 git commit / 回退 / 调整 | 是 |

---

## 5. 命名规范与数据契约

### 5.1 跨模块命名规范

| 位置 | 规范 | 示例 |
|------|------|------|
| MQ 消息字段 | snake_case | `mission_type`, `alarm_level` |
| Java Entity | camelCase | `missionType`, `alarmLevel` |
| SQL 列名 | snake_case | `mission_type`, `alarm_level` |
| HTTP 请求参数 (算法) | camelCase | `imageUrl`, `detectType` |
| HTTP 响应 code (算法) | 字符串 | `"1"` 成功 / `"-1"` 失败 |
| 逻辑删除 | 固定 | `F_DeleteMark`（1=已删，0=未删） |

### 5.2 历史拼写保留

| 错误拼写 | 位置 | 说明 |
|---------|------|------|
| algoritmic_server | 多模块 | 应为 algorithmic，但已全局使用 |
| insepct_device_indicator_data | MQ | 应为 inspect |
| WebsocktUrl | Vue | 应为 WebSocketUrl |
| TASK_TWELVEN | 枚举 | 应为 TWELVE |
| TASK_THRYTEEN | 枚举 | 应为 THIRTEEN |
| window.Glod | Vue pad/web | 应为 Global/Gold |
| window.Glob | Vue 大屏 | 同上但拼写不同 |

**原则：历史拼写不修正，新代码必须沿用已有拼写。**

---

## 6. 试跑验证的教训

以下教训来自"增加夜间巡检任务类型"试跑，已全部融入 Agent 定义：

| # | 教训 | 根因 | 严重度 | 已应用到 |
|---|------|------|--------|---------|
| 1 | Architect 说"无需改动"但功能实际缺失 | 未读代码验证 | 🔴 | Architect：必须给 file:line 证据 |
| 2 | 新枚举值遗漏 MissionInfoApi 硬编码白名单 | Architect 未搜索 hardcoded map | 🔴 | Architect：5 步枚举必查项 |
| 3 | WebSocket payload 变更未标注 breaking | Blueprint §4 缺 breaking 标注 | 🔴 | Architect：§4 必须标注 breaking/非 breaking |
| 4 | Blueprint §5 有 3 条风险但 Impl 只实现 1 条 | §5 未指定负责模块 | 🔴 | Architect：§5 指定负责模块；Impl：§5 作为必做 checklist |
| 5 | Vue 解析了 silent 字段但赋值后丢弃 | 前端无 if 分支使用 | 🟡 | Vue-Impl：变量使用自查 |
| 6 | Analytics 透传字段只处理 dict 不处理 list | 未覆盖全部返回类型 | 🟡 | Analytics-Impl：数据类型覆盖检查 |
| 7 | kill -9 后 Redis 状态残留 | stop.sh 强制终止 | 🟡 | Dispatch-Impl：启动恢复检查 |

---

## 7. 通用化设计（v1.1 新增）

### 7.1 三层架构

```
框架层（不变）             配置层（每项目一份）          生成层（由配置+模板生成）
  mpdev.md 编排器            各模块 CLAUDE.md              architect.md
  code-reviewer.md           契约仓库/CLAUDE.md            dba.md（DB 项目）
  integration-checker.md                                    contract-designer.md
  acceptance-reviewer.md                                    *-impl.md (N 个)
  templates/*.tmpl + dialects/
```

### 7.2 CLAUDE.md 即 Manifest

各模块的 CLAUDE.md 已包含完整的项目信息（技术栈、目录结构、编码规范、MQ 事件、通信关系），无需额外 manifest 文件。Agent 定义通过 `/mpdev-init` 从 CLAUDE.md 自动生成。

### 7.3 九个命令（按生命周期分阶段）

**阶段 0：项目准备**（新项目从空仓库开始；包装现有 skill）

| 命令 | 职责 | 使用时机 | 底层 |
|------|------|---------|------|
| `/mpdev-understand` | 各模块代码深度理解 → 生成 CLAUDE.md | 新项目 / CLAUDE.md 缺失或过期 | 包装 `project-understanding` skill |
| `/mpdev-contracts` | 多 CLAUDE.md 交叉比对 → 生成契约仓库（默认目录名 `contracts/`，mpdevops 实例叫 `robot-contracts/`）| 跨模块项目首次建立共享接口 | 包装 `contract-extraction` skill |

**阶段 1：框架初始化**

| 命令 | 职责 | 使用时机 |
|------|------|---------|
| `/mpdev-init` | 扫描 CLAUDE.md + 模板 → 生成全部 agent 定义 | 阶段 0 完成后 / CLAUDE.md 更新后 / 换项目时 |

**阶段 2+：日常开发与运维**

| 命令 | 职责 | 使用时机 |
|------|------|---------|
| `/mpdev` | 编排全部 agent 完成跨模块开发（含 Step 7/4.5/6.5 三阶段测试嵌入） | 日常开发（新功能、跨模块需求） |
| `/mpdev-fix` | 单 bug 或批量清单（禅道 CSV/Markdown）修复，跳过 Architect+Contract | 单模块 bug / 测试给的 bug list / `/mpdev` 产出的代码有问题时 |
| `/mpdev-test` | 测试套件入口（plan/cases/run/report/uat/bug/detect-flavor 7 子命令）| 测试专项任务 / 已有代码补测试 / 缺陷管理 |
| `/mpdev-check` | 检测契约与代码的漂移 | 手动修改后 / `/mpdev` 运行前 |
| `/mpdev-env` | 检测中间件 → 配置 → 启动，支持 restart/stop/status；含 Compose 自适应 | 克隆后首次启动 / 切换环境 / 重启服务 |
| `/mpdev-commit` | 扫 diff 生成中文 commit 说明，识别契约风险 | 代码改完准备提交时 / 想快速生成规范 message 时 |

### 7.4 模板体系

```
.claude/templates/
├── impl-java.tmpl           Java Impl 通用工作流 + {placeholder}
├── impl-python.tmpl         Python Impl 通用工作流 + {placeholder}
├── impl-vue.tmpl            前端 Impl 通用工作流 + {placeholder}
├── architect.tmpl           Architect 通用框架 + {placeholder}
├── contract-designer.tmpl   Contract 通用框架 + {placeholder}
├── dba.tmpl                 DBA 通用框架 + {{占位符}}（从 dialects 注入方言）
└── dialects/                数据库方言库（按 DB 引擎分片）
    ├── mysql.md             MySQL / MariaDB
    ├── postgresql.md        PostgreSQL / openGauss / GaussDB
    ├── dameng.md            达梦 DM7 / DM8
    └── kingbase.md          人大金仓 KingbaseES V7 / V8
```

**模板 = 通用框架逻辑 + `{placeholder}`**（由 /mpdev-init 注入项目特定内容）。

**DBA 模板的双层体系**（新）：
- **dba.tmpl** 定义通用框架（7 步设计、9 节产出、8 条约束骨架）—— 245 行
- **dialects/*.md** 定义每种 DB 的差异（类型选型、DDL 锁级、索引类型、审计字段 SQL、方言约束）—— 每份 130-170 行
- `/mpdev-init` 自动识别项目 DB 引擎 → 选对应 dialect → 注入 dba.tmpl 生成 `agents/dba.md`
- 未覆盖的 DB（如 Oracle / TiDB / OceanBase / SQL Server）兜底用 mysql 方言，在生成的 dba.md 顶部加"待人工补差异"注释

**维护文档**：[`.claude/templates/dialects/README.md`](./templates/dialects/README.md) —— 规范说明 + 添加新 dialect 的 step-by-step 指南 + 现有覆盖清单 + 待支持 DB 建议。

**Tester 模板的双层体系**（同款思路）：
- **tester.tmpl** 定义通用框架（ISTQB 5 阶段、IEEE 829 文档、6 种用例设计技术、3 种工作模式）—— 285 行
- **test-flavors/*.md** 定义每种项目类型的差异（测试级别 / 风险点 / 自动化栈 / CI / 度量 / 非功能 / 用例样板 / 特定约束）—— 每份 240-310 行
- `/mpdev-init` Step 9 自动识别项目类型 → 选对应 flavor → 注入 tester.tmpl 生成 `agents/tester.md`
- **当前覆盖**（7 个，1887 行）：
  - `http-api`（Spring Boot/Express/FastAPI/Gin 后端）
  - `web-frontend`（Vue/React/Angular/Svelte SPA）
  - `microservices`（Spring Cloud/Dubbo/gRPC 集群 + 契约测试核心）
  - `mobile-app`（原生 iOS/Android + Flutter/React Native）
  - `algo-service`（ML 推理：YOLO/PaddleOCR/torch/onnx + 准确率回归）
  - `data-pipeline`（Airflow/Spark/Kafka + 数据质量监控）
  - `robot-iot`（ROS/嵌入式 + 仿真先行 + HIL）
- 未覆盖项目类型兜底用 `http-api.md`，在生成的 tester.md 顶部加"项目类型未识别"注释

### 7.5 换项目操作流程

```
1. 确保新项目每个模块有 CLAUDE.md（含 ## 技术栈 + ## 目录结构 + ## 编码规范）
2. 如有契约仓库，确保其 CLAUDE.md 含 ## 命名约定
3. /mpdev-init → 自动扫描并生成全部 agent 定义
4. Review 生成的文件，按需微调
5. /mpdev 需求描述 → 开始工作
```

### 7.6 漂移检测

`/mpdev-check` 执行三层检测：

| 层级 | 检测内容 | 方式 |
|------|---------|------|
| L1 | MQ 消息字段：schema vs 生产者 vs 消费者 | 三者交叉比对 |
| L2 | SQL 迁移 vs Java Entity / Python Model | 列名映射比对 |
| L3 | OpenAPI vs Controller 路由 | path+method 比对 |

---

## 8. 文档生成机制（v1.2 新增）

### 8.1 动机

v1.0 的痛点：全流程产出只有 Blueprint 在对话上下文里"飘着"，其他阶段（契约变更、各模块实现自测、审查、验收）的产出没有落地。跑完一个需求想复盘，只能翻 chat 历史。

v1.2 引入**运行目录**机制：每次 `/mpdev` 运行产出一个独立的文件夹，包含从需求到验收的全链路文档。

### 8.2 目录结构

```
.claude/mpdev-runs/
├── INDEX.md                       所有运行的索引（最新在顶）
├── {run_id}/                      一次 /mpdev 运行
│   ├── 00-requirement.md          用户需求 + 模式判断
│   ├── 01-blueprint.md            架构蓝图 + 用户确认记录
│   ├── 02-contract-changes.md     契约变更清单 + 结构化摘要
│   ├── 03-impl-{module}.md × N    各模块实现报告（自测结果重点在此）
│   ├── 04-code-review.md          代码审查
│   ├── 04-integration-check.md    L1-L3 集成校验
│   ├── 05-acceptance.md           验收审查
│   └── 99-summary.md              汇总（含全流程关联文档链接）
└── fixes/                         /mpdev-fix 轻量修复记录
    └── {timestamp}-{module}-{slug}.md
```

### 8.3 run_id 命名

```
run_id = {YYYY-MM-DD}_{HHMM}_{slug}
       = 例如 "2026-04-17_1530_night-patrol-task-type"

slug = 从用户需求原文首句取前 8 个词 → 去虚词 → kebab-case → 截断 40 字符
```

编号前缀（`00/01/02/.../99`）让文件按自然顺序排列，一眼看出流程进度和缺失环节（只到 `03` 说明跑到 impl 就失败了）。

### 8.4 谁写文档

由**编排器（主会话）**渲染写入，不是各 agent 写。Agent 产出结构化 YAML，编排器按模板渲染成 markdown。

**好处**：
- Agent 保持专注核心任务，不分心写文档
- 文档格式跨项目一致
- 编排器掌握全局上下文（如时间线、用户确认记录），更适合写汇总

### 8.5 失败也要写

即使某个 Step 失败（如 architect 返回"不可行"），也要写对应文档记录失败原因。**复盘失败比复盘成功更有价值**。

文档头部的 YAML frontmatter 统一标注 `status: success / failed / skipped`。

### 8.6 每个命令的文档产出

| 命令 | 产出位置 | 文档数量 |
|------|---------|---------|
| `/mpdev` | `.claude/mpdev-runs/{run_id}/` | 7-10 份（含各 impl 模块） |
| `/mpdev-fix` | `.claude/mpdev-runs/fixes/{fix_id}.md` + 批量模式加 `batch-{timestamp}.md` | 单 bug: 1 份；批量 N 个: N+1 份 |
| `/mpdev-commit` | `.claude/mpdev-runs/commits/{commit_id}.md` | 1 份（dry-run 不写） |
| `/mpdev-init` | 不产出文档（配置类命令） | 0 |
| `/mpdev-check` | 结果直接输出到对话（用户可手动保存） | 0 |
| `/mpdev-env` | `.claude/.mpdev-env-state.yml`（状态文件，不是文档） | 0 |

三个会产出文档的命令都会维护 `INDEX.md` 的对应表格，形成可浏览的运行历史。

### 8.7 文档模板库

完整的 7 类文档模板（T0-T6）在 `.claude/commands/mpdev.md` 的 **"文档模板库"** 段定义。每个模板指定：
- YAML frontmatter 字段
- 章节结构
- 变量占位符（由编排器运行时替换）

### 8.8 用户如何使用这些文档

| 使用场景 | 阅读哪份文档 |
|---------|------------|
| 了解本次做了什么 | `99-summary.md`（全局视图） |
| 查看某模块开发细节 | `03-impl-{module}.md` |
| 对照验收结论 | `05-acceptance.md` |
| 追溯契约变更 | `02-contract-changes.md` |
| 复盘失败原因 | `99-summary.md` + 失败那个 Step 的文档 |
| 审阅历史记录 | `INDEX.md` |

---

## 9. 文件清单

```
.claude/
├── commands/                  9 个斜杠命令（按生命周期阶段）
│   ├── mpdev-understand.md    阶段 0a: 项目理解 → 各模块 CLAUDE.md
│   ├── mpdev-contracts.md     阶段 0b: 契约提取 → 契约仓库（mpdevops 实例: robot-contracts/）
│   ├── mpdev-init.md          阶段 1:  初始化器（含 dba/tester 识别）
│   ├── mpdev.md               阶段 2:  跨模块开发主编排（含三阶段测试嵌入）
│   ├── mpdev-fix.md           阶段 2:  轻量修复（单 bug / 批量清单）
│   ├── mpdev-test.md          阶段 2:  测试套件（plan/cases/run/report/uat/bug/detect-flavor）
│   ├── mpdev-check.md         阶段 2:  契约漂移检测
│   ├── mpdev-env.md           阶段 2:  环境配置与启动（含 Compose 自适应）
│   └── mpdev-commit.md        阶段 2:  提交辅助（diff→中文说明）
├── templates/
│   ├── impl-java.tmpl         Java Impl 模板
│   ├── impl-python.tmpl       Python Impl 模板
│   ├── impl-vue.tmpl          前端 Impl 模板
│   ├── architect.tmpl         Architect 模板
│   ├── contract-designer.tmpl Contract 模板
│   ├── dba.tmpl               DBA 模板（方言无关骨架）
│   ├── dialects/              数据库方言库（mysql / postgresql / dameng / kingbase）
│   │   └── *.md
│   ├── tester.tmpl            Tester 模板（项目类型无关骨架）
│   ├── test-flavors/          测试方言库（7 类项目类型）
│   │   ├── http-api.md         HTTP API 后端
│   │   ├── web-frontend.md     Web SPA
│   │   ├── microservices.md    微服务集群
│   │   ├── mobile-app.md       移动 App
│   │   ├── algo-service.md     算法/ML 推理
│   │   ├── data-pipeline.md    数据管道
│   │   └── robot-iot.md        机器人/IoT
│   └── understand/            project-understanding skill 的本地副本（自包含 fallback）
│       └── references/        按技术栈分片（java/python×4/vue），共 2333 行
├── agents/                    由 /mpdev-init 生成（当前实例: mpdevops）
│   ├── architect.md
│   ├── dba.md                 条件触发（DB 变更时）
│   ├── contract-designer.md
│   ├── tester.md              项目类型自适应（当前 http-api flavor）
│   ├── java-impl.md
│   ├── dispatch-impl.md
│   ├── analytics-impl.md
│   ├── vue-impl.md
│   ├── algor-impl.md
│   ├── code-reviewer.md       通用（跨项目复用）
│   ├── integration-checker.md 通用（跨项目复用）
│   └── acceptance-reviewer.md 通用（跨项目复用）
├── mpdev-runs/                运行记录（每次命令产出的文档）
│   ├── INDEX.md               运行/修复/提交/测试 索引
│   ├── {run_id}/              单次 /mpdev 运行（含 02.5/02.7/03.5/03.6/05.5 测试文档）
│   ├── fixes/                 /mpdev-fix 修复报告
│   ├── commits/               /mpdev-commit 提交记录
│   ├── setup/                 /mpdev-understand + /mpdev-contracts 归档
│   ├── test-plans/            /mpdev-test plan 独立产出
│   ├── test-cases/            /mpdev-test cases 独立产出
│   └── test-exports/          /mpdev-test bug export 给 /mpdev-fix 的清单
├── mpdev-suite-workflow.md    人读说明（套件级使用文档，覆盖 9 个命令）
└── MPDev-Scheme.md            本文档
```
