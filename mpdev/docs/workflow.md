# MPDev 多模块开发套件工作流说明

> 本项目实例: `mpdevops`

## 什么是 MPDev 套件

MPDev 是通用的多模块开发套件：**9 个斜杠命令**驱动 **13 个 AI agent**（含条件触发的 DBA + 项目类型自适应的 Tester + v1.1.0 新增的 doc-refresher），覆盖"理解项目 → 提取契约 → 框架初始化 → 开发 → 测试 → 修复 → 提交 → 运维"的**全生命周期**。你只需用自然语言描述需求，系统自动编排。

## 九个命令一览

**阶段 0 项目准备**（新项目从空仓库出发）：

| 命令 | 一句话职责 | 典型时机 |
|------|------------|---------|
| `/mpdev:understand` | 深度理解项目 → 生成 CLAUDE.md（包装 `project-understanding` skill） | 新项目 / CLAUDE.md 缺失或过期 |
| `/mpdev:contracts` | 多 CLAUDE.md 交叉比对 → 生成 robot-contracts（包装 `contract-extraction` skill） | 跨模块项目建立共享接口规范 |

**阶段 1 框架初始化**：

| 命令 | 一句话职责 | 典型时机 |
|------|------------|---------|
| `/mpdev:init` | 扫 CLAUDE.md + 模板 → 生成 13 个 agent（含条件触发的 dba + 项目类型自适应的 tester）| 阶段 0 完成后 / 换项目 |

**阶段 2+ 日常开发与运维**：

| 命令 | 一句话职责 | 典型时机 |
|------|------------|---------|
| `/mpdev:dev` | 跨模块开发主编排（含 Step 7/9/12 三阶段测试嵌入） | 日常需求、新功能 |
| `/mpdev:fix` | 单 bug / 批量清单修复 | bug 修复 / 测试反馈 |
| `/mpdev:test` | 测试套件入口（plan/cases/run/report/uat/bug/detect-flavor）| 测试专项 / 缺陷管理 |
| `/mpdev:check` | 契约 vs 代码一致性检测 | 手改完 / `/mpdev:dev` 前 |
| `/mpdev:env` | 环境启停（含 Compose 自适应） | 启动服务栈 / 重启 |
| `/mpdev:commit` | 扫 diff 生成中文 commit 说明 | 代码改完准备提交 |

## 典型生命周期

```
阶段 0：项目准备（仅新项目需要，CLAUDE.md/contracts 已有则跳过）
  /mpdev:understand ─────────────▶ 各模块 CLAUDE.md
  /mpdev:contracts  ─────────────▶ robot-contracts/
        ↓
阶段 1：框架初始化（一次性）
  /mpdev:init ───────────────────▶ 扫模块 CLAUDE.md → 生成 13 个 agent
        ↓
阶段 2+：日常开发循环
  ① /mpdev:dev 描述需求 ──────▶ 跨模块代码 + 全套文档 ─┐
                                                    │
  ② (自测发现 bug) /mpdev:fix {module} ◀───────────┘
                                                    │
  ③ /mpdev:commit ◀──────────────────── 代码就绪    │
                                                    │
  ④ git push（手动）◀──────────────────── 确认后 ──┘

偶发运维:
  · /mpdev:env start | restart | stop | status
  · /mpdev:check （怀疑契约漂移时）
```

---

## /mpdev:dev — 跨模块开发主编排

### 快速开始

```
/mpdev:dev 增加一个"夜间巡检"任务类型，夜间巡检时机器人降速、关闭语音
```

### 流程总览

```
你 ──────────────────────────────────────────────────────────────→ 时间线
│                                                                   │
│ /mpdev:dev 需求描述                                                   │
│   ↓                                                               │
│ ④ Step 4: architect 读代码 → Blueprint                            │
│   ↓ ← 你确认 / 调整                                               │
│ ⑤ Step 5: dba 深化数据层（仅 DB 变更时条件触发）                    │
│   ↓                                                               │
│ ⑥ Step 6: contract-designer 更新契约仓库                           │
│   ↓                                                               │
│ ⑦ Step 7: tester 设计测试计划+用例（IEEE 829）                     │
│   ↓                                                               │
│ ⑧ Step 8: impl agents ×5 并行写代码+自测    ← 第一道关：自测        │
│   ↓                                                               │
│ ⑨ Step 9: tester 跑测试+登记缺陷                                   │
│   ↓                                                               │
│ ⑩ Step 10: code-reviewer ──┐                                       │
│                              ├─ 并行         ← 第二道关：质量+一致性 │
│   integration-checker────────┘                                     │
│   ↓ (修复循环 ≤2轮)                                                │
│ ⑪ Step 11: acceptance-reviewer            ← 第三道关：做对了吗      │
│   ↓                                                               │
│ ⑫ Step 12: tester 测试总结报告+准出建议                            │
│   ↓                                                               │
│ ⑫.5 Step 12.5: doc-refresher 文档增量刷新（v1.1.0）              │
│   ↓                                                               │
│ ⑬ Step 13: 汇总报告                                                │
│   ↓ ← 你决定 commit / 调整                                        │
```

### 13 个 Agent 角色

| 角色 | 职责 | 关键产出 |
|------|------|---------|
| **architect** | 读代码评估可行性，产出技术蓝图 | Technical Blueprint (5段) |
| **dba** ⚡ | （条件触发）深入数据层设计：表结构/索引/迁移/一致性/容量 | DBA Design Doc (9段) |
| **contract-designer** | 先于代码更新接口契约（使用 dba DDL 草稿）| schema + SQL + 结构化字段摘要 |
| **java-impl** | Spring Boot 后端实现+自测 | 代码 + JUnit 测试 |
| **dispatch-impl** | Python+ROS 调度实现+自测 | 代码 + pytest 测试 |
| **analytics-impl** | asyncio 分析管道实现+自测 | 代码 + pytest 测试 |
| **vue-impl** | 4子应用前端实现+构建验证 | 代码 + build check |
| **algor-impl** | 算法服务实现/验证 | 代码或验证报告 |
| **code-reviewer** | 六维代码审查 (遵循度/规范/安全/健壮/性能/测试) | review 报告 |
| **integration-checker** | 三层联测 (契约一致/模拟联调/构建) | 联测报告 |
| **acceptance-reviewer** | 五维需求验收 (覆盖/场景/交付/范围/风险) | 验收报告 |
| **tester** 🧪 | （3 模式：架构师/执行者/报告者）ISTQB 流程 + IEEE 829 文档 + 缺陷生命周期；项目类型自适应（flavor）| 5 份测试文档（plan/cases/log/incidents/summary）+ 自动化代码 |
| **doc-refresher** 📝 | （v1.1.0 新增）`/mpdev:dev` Step 12.5 文档增量刷新；只追加机械可推导内容（API 表行 / MQ 字段 / 文件路径），不动语义段落；找不到目标章节 → 落 TODO | `15-doc-refresh.md` 刷新报告 |

### 三种模式

| 模式 | 适用场景 | 示例 |
|------|---------|------|
| **Quick (A)** | 单模块小改动 | `/mpdev:dev 给告警表加一个备注字段` |
| **Cross-Module (B)** | 跨模块特性 | `/mpdev:dev 增加夜间巡检任务类型` |
| **Exploration (C)** | 只调查不改代码 | `/mpdev:dev 追踪 GAME_OVER 在 5 个模块中的流转` |

### 你的参与点

| 时机 | 你做什么 |
|------|---------|
| Step 2 后 | 确认模式判断 (通常自动正确) |
| Step 4 后 | **审阅 Blueprint**，可调整 ("不改算法"/"降速改 0.3") |
| Step 10 后 | 如有 warn，决定修复还是接受 |
| Step 11 后 | 如 conditional_accept，决定修复还是接受 |
| Step 13 后 | 决定 `/mpdev:commit` / 回退 / 调整 |

### 容错设计

- architect / contract-designer 失败 → 流程终止 (这两个是基础)
- 某个 impl 失败 → 跳过该模块，其他继续，汇总标注
- review / integration / acceptance 失败 → 跳过该检查，汇总标注
- 你随时可以说"停" → 立即中断，已完成的变更保留
- 不自动 git commit → 你决定何时提交（或交给 `/mpdev:commit`）

### 试跑验证的教训（已融入 agent 定义）

| 教训 | 影响 | 已应用到 |
|------|------|---------|
| architect 说"无需改动"但实际缺失 | 功能遗漏 | architect: 必须给代码证据 |
| 新增枚举遗漏硬编码白名单 | 功能不可用 | architect: 枚举必查项 5 步 |
| WebSocket payload 格式变更未标注 breaking | 前端崩溃 | architect: §4 必须标注 |
| Blueprint 风险措施 impl 未全部实现 | 生产风险 | impl: §5 作为必做 checklist |
| 前端解析了新字段但忘了用 | 功能不生效 | vue-impl: 变量使用自查 |
| 透传字段只处理 dict 不处理 list | 数据丢失 | analytics-impl: 数据类型覆盖 |
| kill -9 后 Redis 状态残留 | 状态泄漏 | dispatch-impl: 启动恢复检查 |

---

## /mpdev:understand — 项目深度理解（阶段 0a）

**做什么**：包装 `project-understanding` skill，给各模块生成 CLAUDE.md。

**5 轮 + 合成**：项目骨架 → 接口边界 → 核心业务流 → 基础设施 → 验证补盲 → 合成 CLAUDE.md + TODO.md。

**何时用**：
- 新项目（CLAUDE.md 缺失）
- CLAUDE.md 过期或技术栈变化

**关键行为**：
- 多模块仓库**强制范围确认**（避免浪费上下文）
- 5 轮笔记写文件不占上下文
- CLAUDE.md 含置信度标注（high/medium/low）
- 同步产出 TODO.md 列出待优化项

**示例**：

```
/mpdev:understand                                # 交互式发现
/mpdev:understand only=java,vue                  # 限定范围
/mpdev:understand 只看 gateway 和 user-service    # 自由文本
```

**文档产出**：每个模块写 `CLAUDE.md`，再加一份归档到 `mpdev-runs/setup/{timestamp}-understand-{slug}.md`。

---

## /mpdev:contracts — 契约仓库提取（阶段 0b）

**做什么**：包装 `contract-extraction` skill，从多模块 CLAUDE.md 交叉比对生成 `robot-contracts/`。

**8 步流程**：初始化目录 → 发现模块 → 读接口区块 → MQ/REST/DB 三层比对 → 用户确认不一致项 → 生成 schemas/openapi/sql/events/flows/scripts → 一致性报告。

**前置**：各模块 CLAUDE.md 已就绪（缺则跑 `/mpdev:understand`）。

**关键行为**：
- 不一致项**必须用户确认**才生成最终契约（避免错误固化）
- 生成的 SQL 必须**幂等**（INSERT IGNORE / IF NOT EXISTS）
- 同步生成 `scripts/validate_contracts.py`（供 `/mpdev:check` 使用）

**示例**：

```
/mpdev:contracts                          # 自动发现
/mpdev:contracts output=../robot-contracts # 指定输出
/mpdev:contracts dry-run                   # 只报告不生成
```

**文档产出**：`robot-contracts/` 全套契约文件 + 归档到 `mpdev-runs/setup/{timestamp}-contracts.md`。

---

## /mpdev:init — 项目初始化

**做什么**：扫描所有模块的 `CLAUDE.md` → 识别技术栈与目录结构 → 从 `templates/*.tmpl` 生成 `agents/` 下的专项 agent 定义。

**何时用**：
- 新项目首次启用 MPDev
- 模块 CLAUDE.md 更新后（技术栈变了、新增模块）
- 复用 MPDev 到其他工程（拷 commands + templates 后必须跑）

**重要**：不需要手动维护 `agents/` 里的文件——init 会覆盖重生成。

---

## /mpdev:fix — 轻量 Bug 修复（单 bug + 批量清单）

**做什么**：跳过 Architect 和 Contract，直接让目标模块的 impl agent 修复，最后过**一次** code-reviewer 整批把关。

**两种模式**：

| 方式 | 输入形式 | 适用 |
|------|---------|------|
| **单 bug** | `/mpdev:fix {模块} {描述}` | 一眼定位的问题 |
| **批量清单** | `/mpdev:fix @bugs.md` / `@zentao.csv` / `--batch` 粘贴 | 测试给的 bug 清单 |

**支持的清单格式**：禅道 CSV（自动识别中英文列名）、Markdown 表格、Markdown 列表、自由文本兜底。

**流程**：模式识别/清单解析 → 模块分组确认 → 升级信号检查 → 按模块组 impl 修复 → 整批 code-review → 修复报告。

**关键行为**：
- **按模块分组**：同模块所有 bug 合并给一个 impl agent（能发现共享根因）
- **失败继续**：单个 bug `cannot_fix` 不终止整批
- **整批 review 一次**：不是每个 bug 都 review，全部修完统一审
- **升级信号整批停下**：任一 bug 触发契约变更信号 → 弹窗询问"改用 /mpdev:dev 或继续"

**示例**：
```
# 单 bug
/mpdev:fix dispatch 启动后报 KeyError: 'task_type'

# 批量 - 从禅道 CSV
/mpdev:fix @zentao-export.csv

# 批量 - 从 markdown 清单
/mpdev:fix @bugs.md
```

**文档产出**：每个 bug 一份详报 + 批量模式额外一份总览。

---

## /mpdev:test — 测试套件入口

**做什么**：mpdev 测试角色的**统一命令入口**。底层调用 `tester` agent（基于 `templates/tester.tmpl` + `test-flavors/{type}.md` 合成）。

**与 /mpdev:dev 主流程的关系**：日常开发**不用**手工跑这条 —— `/mpdev:dev` 自动在 **Step 7 / 9 / 12** 调用 tester。本命令用于专项任务：单独生成计划、给已有代码补用例、跑回归、查/导/修缺陷、UAT、重新识别项目类型。

### 7 个子命令

| 子命令 | 用途 | tester 模式 |
|--------|------|-----------|
| `/mpdev:test plan [需求/run_id]` | 单独生成测试计划 | A |
| `/mpdev:test cases <module> [关键词]` | 给已有模块补测试用例 | A |
| `/mpdev:test run [scope]` | 执行测试（scope: `--module/--regression/--perf/--smoke`）| B |
| `/mpdev:test report [run_id]` | 生成测试总结报告 | C |
| `/mpdev:test bug <action>` | 缺陷管理（`add`/`list`/`close`/`export`/`reopen`）| 不调 agent |
| `/mpdev:test uat [run_id]` | 生成 UAT 验收文档 | C（uat 模式）|
| `/mpdev:test detect-flavor` | 重新识别项目类型，重生成 `agents/tester.md` | 不调 agent |

### tester 三模式（A / B / C）

tester 是一个 agent 三种工作模式，**自动**在 mpdev 不同 Step 调用：

| 模式 | 调用时机 | 输入 | 产出 |
|------|---------|------|------|
| **A. test-architect** | `/mpdev:dev` Step 7（contract 后、impl 前）| Blueprint + contracts | 测试计划 + 测试用例规格 |
| **B. test-executor** | `/mpdev:dev` Step 9（impl 后、review 前）| 实现代码 + 用例 | 自动化代码 + 测试日志 + 缺陷登记 |
| **C. test-reporter** | `/mpdev:dev` Step 12（acceptance 后）| 测试日志 + 缺陷状态 | 测试总结报告 + (可选)UAT |

### 5 份 IEEE 829 标准文档

每次 `/mpdev:dev` 跑出来 `mpdev-runs/{run_id}/` 下含：

| 文件 | 含义 | 产出模式 | 标准 |
|------|------|---------|------|
| `06-test-plan.md` | 测试计划（目标/范围/级别/技术/资源/风险/准入准出）| A | IEEE 829 §4.1 |
| `07-test-cases.md` | 测试用例规格（用例 ID/设计技术/优先级/输入/期望）| A | IEEE 829 §4.2 |
| `09-test-log.md` | 测试日志（执行情况/覆盖率/未执行原因）| B | IEEE 829 §4.6 |
| `10-test-incidents.md` | 缺陷登记（BUG-ID/严重度/复现/状态）| B | IEEE 829 §4.7 |
| `14-test-summary.md` | 测试总结报告（通过率/缺陷分布/准出建议）| C | IEEE 829 §4.8 |
| `uat.md`（可选）| UAT 验收（业务场景/角色矩阵/签字栏）| C | 自定 |

### 缺陷生命周期闭环（核心创新）

`/mpdev:test bug` 与 `/mpdev:fix` 形成**测试 → 修复 → 回归**闭环：

```
test-executor 跑测试 → fail 用例 → 10-test-incidents.md (status=open)
       ↓
/mpdev:test bug list             # 看 open/reopen 缺陷
/mpdev:test bug export           # 导出 markdown 清单到 test-exports/
       ↓
/mpdev:fix --batch @bugs.md      # 按模块分组并行修
       ↓ 修复完成
缺陷状态自动更新 → status=resolved（待回归）
       ↓
/mpdev:test run --regression {bug_ids}
       ↓
通过 → status=closed   |   不通过 → status=reopen
```

**状态机**：`open → in-progress → resolved → closed`；不通过回归 → `reopen`。**严重度**：P0/Critical（阻断主流程） / P1/High（核心异常有 workaround） / P2/Medium（边缘） / P3/Low（建议）。

### 6 种黑盒测试设计技术（每条用例必标 1+ 种）

| 技术 | 何时用 | 示例 |
|------|--------|------|
| **等价类划分** | 输入域分类 | 长度 0/1-20/21-50/>50 → 4 类 |
| **边界值分析** | 找极值缺陷 | 长度=0、1、20、21、最大值±1 |
| **决策表** | 多条件组合 | 是否 VIP × 金额 × 是否首单 → 8 组合 |
| **状态转换** | 状态机驱动业务 | task: pending → running → done → archived |
| **场景法** | 业务流端到端 | 登录→下单→支付→收货 |
| **错误推测** | 经验直觉 | 空字符串/特殊字符/超长/并发 |

强制约束：**P0 用例 100% 自动化**；P1 ≥ 80%；P2/P3 可手工。

### 项目类型 flavor 系统

`tester.tmpl` + `test-flavors/{type}.md` **双层模板**：骨架（ISTQB 流程 + IEEE 829 文档结构）通用，方言（项目类型特定的风险点/自动化栈/CI/度量）按项目识别。

7 种内置 flavor，由 `/mpdev:init` Step 9 或 `/mpdev:test detect-flavor` 自动识别：

| Flavor | 识别信号 | 主要风险 | 自动化栈 |
|--------|---------|---------|---------|
| `http-api` | Spring Boot / FastAPI / Express / Gin | 边界/契约/并发/数据边界 | JUnit/pytest + RestAssured |
| `web-frontend` | Vue/React/Angular（pnpm-workspace、vite）| 表单边界/路由权限/状态/A11y | Vitest + Cypress/Playwright + axe |
| `microservices` | Spring Cloud / Dubbo / k8s manifests | 契约一致/熔断/分布式事务 | Spring Cloud Contract / Pact + Testcontainers |
| `mobile-app` | iOS/Android/Flutter/RN | 设备碎片/版本兼容/沙箱支付 | XCTest/Espresso/Detox + Firebase Test Lab |
| `algo-service` | YOLO/PaddleOCR/torch/onnx | 准确率回归/GPU/CPU 一致/输入鲁棒 | golden test set + DVC + pytest |
| `data-pipeline` | Airflow/Spark/Kafka/dbt | **幂等**/数据完整/迟到事件/upstream 失败 | Great Expectations / Soda + chispa |
| `robot-iot` | ROS / 嵌入式 / HIL | 仿真先行/控制环抖动 <5ms / 安全保护链 | rosbag 回归 + Gazebo + 故障注入 |

每个 flavor 文件含 **9 个 BLOCK**：`PROJECT_TYPE_SCOPE` / `TEST_LEVELS` / `KEY_RISK_AREAS` / `AUTOMATION_STACK` / `CI_INTEGRATION` / `METRICS` / `NON_FUNCTIONAL` / `SAMPLE_CASES` / `DIALECT_CONSTRAINTS`。`/mpdev:init` Step 9 把它们注入 `tester.tmpl` 占位符 → 生成项目特化的 `agents/tester.md`。

### 何时用 detect-flavor

- 项目结构有重大变化（加了新模块、技术栈切换）
- 第一次用 mpdev 跑某项目，init 自动识别错误，想手动改
- 改进了某个 flavor 文件后，刷新现有项目的 tester.md

`detect-flavor` 会在覆盖前备份旧 `agents/tester.md` 为 `.bak.{timestamp}`，可回退。

### 示例

```bash
/mpdev:test plan 增加银行卡管理功能       # 独立测试计划
/mpdev:test cases java payment           # 给 java 模块的 payment 模块补用例
/mpdev:test run --module java            # 跑 java 模块所有测试
/mpdev:test run --regression BUG-001,BUG-007  # 回归两个修复
/mpdev:test bug list status=open severity=P0 # 查 open 的 P0 缺陷
/mpdev:test bug export                   # 导出 → 喂给 /mpdev:fix --batch
/mpdev:test report latest                # 给最近一次 /mpdev:dev 跑生成总结
/mpdev:test uat 2026-04-17_1530-night-patrol  # 给历史 run 生成 UAT
/mpdev:test detect-flavor                # 重识别项目类型
```

**文档产出位置**：
- 主流程跑出来的 5 份在 `mpdev-runs/{run_id}/`（与 architect/impl 等其他文档同目录）
- 子命令独立产出在 `mpdev-runs/test-plans/` / `test-cases/` / `test-exports/`

---

## /mpdev:env — 环境启停

**子命令**：

| 子命令 | 场景 |
|--------|------|
| `start` | 首次启动或完整启动服务栈（含 compose 检测，走完整配置） |
| `restart` | 快速重启业务模块（读状态文件，跳过检测/配置，~10 秒，保留 compose） |
| `restart --full` | `docker compose down/up` + 业务模块重启 |
| `stop` | 停止业务模块（保留 compose 基础设施运行） |
| `stop --all-including-infra` | 业务模块全停 + `docker compose down` |
| `status` | 查看业务模块 + compose 基础设施状态 |

**Docker Compose 自适应**：

若项目根（或 `infra/` / `docker/` / `deploy/`）含 `docker-compose*.yml`，命令自动分两阶段：
1. **Step 2 + 9**：检测并启动 compose 基础设施（Nacos/MySQL/Redis 等）
2. **Step 10**：按 `depends_on_compose` 等待 compose 服务就绪后，启动业务模块

内置识别：Nacos（含 auth 模式自动回退）、MySQL/MariaDB、Redis、RabbitMQ、PostgreSQL、Zookeeper、Consul。

**状态文件**：`.claude/.mpdev-env-state.yml` 缓存启动信息。只存运行时信息（命令/端口/健康检查/compose_infra），**不存密码**（密码仍在各模块 config 里）。

---

## /mpdev:check — 契约漂移检测

**做什么**：只读检测，三层扫描，不修改任何文件。

| 层 | 比对内容 | 示例报错 |
|----|---------|---------|
| **L1** | MQ schema ↔ 生产者/消费者字段 | "schema 定义了 silent 但消费者未解析" |
| **L2** | SQL V*.sql ↔ Entity/Model 字段 | "SQL 新增 alarm.silent 列但 Java Entity 未更新" |
| **L3** | openapi/*.yaml ↔ Controller 路径 | "OpenAPI 定义 POST /alarm/silent 但无对应 Controller" |

**适用**：手动改完契约或代码后、运行 `/mpdev:dev` 前。
**不适用**：查"这次提交改了什么"——那是 `/mpdev:commit` 的职责。

---

## /mpdev:commit — 提交辅助

**做什么**：扫 `git diff --cached` → 识别涉及模块与变更类型 → 生成中文 commit 草稿 → 用户确认后 `git commit`。

**输入形式**：

```
/mpdev:commit                    # 全自动（从 diff 推主题）
/mpdev:commit "修复夜间巡检BUG"    # 你给 why，命令补 what
/mpdev:commit --dry-run          # 只生成草稿不提交
/mpdev:commit --with-check       # 附带契约校验结果到 footer
```

**生成的 message 风格**：自由中文（不强制 Conventional Commits），主题 30 字内，多模块时 body 分行列出各模块改动，固定 footer 含 `Co-Authored-By: Claude`。

**安全底线**：
- ❌ 永不 `--amend` / `--no-verify` / 自动 `git push`
- ❌ 无 stage 时不自动 `git add .`（会问你）
- ❌ pre-commit hook 失败不绕过，交作者解决

---

## 跨命令协作：文档留痕

每次跑完 `/mpdev:dev`、`/mpdev:fix`、`/mpdev:commit` 都会在 `.claude/mpdev:runs/` 下留下完整档案：

```
.claude/mpdev:runs/
├── INDEX.md              全部历史一览（3 张表：运行 / 修复 / 提交）
├── {run_id}/             /mpdev:dev 每次运行的 7-10 份文档
├── fixes/                /mpdev:fix 修复报告
└── commits/              /mpdev:commit 提交记录
```

即使对话被压缩、会话重开，读档案即可恢复完整上下文——这是 MPDev 框架应对"长上下文丢失"的核心设计。

---

## 文件结构

```
.claude/
├── agents/                    13 个 agent 定义（/mpdev:init 按项目生成）
│   ├── architect.md
│   ├── dba.md                 条件触发（DB 变更时，骨架 + 4 个数据库方言）
│   ├── contract-designer.md
│   ├── java-impl.md
│   ├── dispatch-impl.md
│   ├── analytics-impl.md
│   ├── vue-impl.md
│   ├── algor-impl.md
│   ├── tester.md              项目类型自适应（骨架 + 7 个 flavor），三阶段嵌入主流程
│   ├── code-reviewer.md       通用（跨项目复用）
│   ├── integration-checker.md 通用（跨项目复用）
│   └── acceptance-reviewer.md 通用（跨项目复用）
├── commands/                  9 个斜杠命令（按生命周期阶段）
│   ├── mpdev-understand.md    阶段 0a: 项目理解 → 各模块 CLAUDE.md
│   ├── mpdev-contracts.md     阶段 0b: 契约提取 → robot-contracts/
│   ├── mpdev-init.md          阶段 1:  扫描 + 生成 agent（含 dba/tester 识别）
│   ├── mpdev.md               阶段 2:  跨模块开发主编排（含三阶段测试嵌入）
│   ├── mpdev-fix.md           阶段 2:  轻量 bug 修复
│   ├── mpdev-test.md          阶段 2:  测试套件（plan/cases/run/report/uat/bug）
│   ├── mpdev-env.md           阶段 2:  环境启停 (含 Compose)
│   ├── mpdev-check.md         阶段 2:  契约漂移检测
│   └── mpdev-commit.md        阶段 2:  提交辅助（diff→中文说明）
├── templates/                 /mpdev:init 用的占位符模板
│   ├── impl-java.tmpl
│   ├── impl-python.tmpl
│   ├── impl-vue.tmpl
│   ├── architect.tmpl
│   ├── contract-designer.tmpl
│   ├── dba.tmpl               DBA 骨架（方言独立）
│   ├── dialects/              数据库方言库
│   │   ├── mysql.md           MySQL / MariaDB
│   │   ├── postgresql.md      PostgreSQL / openGauss / GaussDB
│   │   ├── dameng.md          达梦 DM
│   │   └── kingbase.md        人大金仓 KingbaseES
│   ├── tester.tmpl            Tester 骨架（项目类型独立）
│   ├── test-flavors/          测试方言库（7 个，覆盖 90% 主流项目）
│   │   ├── http-api.md         HTTP API 后端（Spring Boot/Express/FastAPI/Gin）
│   │   ├── web-frontend.md     Web SPA（Vue/React/Angular/Svelte）
│   │   ├── microservices.md    微服务集群（Spring Cloud/Dubbo/gRPC + 契约测试）
│   │   ├── mobile-app.md       移动 App（iOS/Android/Flutter/RN）
│   │   ├── algo-service.md     算法/ML 推理（YOLO/PaddleOCR/torch + 准确率回归）
│   │   ├── data-pipeline.md    数据管道（Airflow/Spark/Kafka + DQ 监控）
│   │   └── robot-iot.md        机器人/IoT/嵌入式（ROS + 仿真先行 + HIL）
│   └── understand/            /mpdev:understand 自包含 fallback
│       └── references/        按技术栈分片（共 2333 行）
│           ├── java_springboot.md       Java Spring Boot / Cloud
│           ├── python_generic.md        Python 通用
│           ├── python_algo.md           Python 算法服务
│           ├── python_dataproc.md       Python 数据处理
│           ├── python_scheduler.md      Python 调度
│           └── vue_frontend.md          Vue 前端
├── mpdev-runs/                运行记录（每次命令产出的文档）
│   ├── INDEX.md               运行/修复/提交 索引
│   ├── {run_id}/              /mpdev:dev 单次运行的全套文档（00-99）
│   ├── fixes/                 /mpdev:fix 修复报告
│   ├── commits/               /mpdev:commit 提交记录
│   └── setup/                 /mpdev:understand + /mpdev:contracts 归档
├── MPDev-Scheme.md            方案说明书（设计决策 + 完整文件清单）
└── mpdev-suite-workflow.md    本文件（人读的使用说明）
```

---

## 维护手册

本套件含若干**生成产物**，以及需要演进的工作流定义，需要在特定事件下手工或半自动维护。

### 1. `/mpdev:understand` 和 `/mpdev:contracts` 工作流

两个命令的完整工作流已直接写在 slash command 文件中：

- [`commands/mpdev:understand.md`](commands/mpdev:understand.md) — 5 轮分析 + 范围确认 + 合成（~600 行）
- [`commands/mpdev:contracts.md`](commands/mpdev:contracts.md) — 8 步交叉比对 + 两暂停点（~700 行）

**改动方式**：直接编辑 slash command 文件。**无外部 skill 源**，套件即单一事实源。

`templates/understand/references/` 是 6 份语言指南（java/python×4/vue），被 `/mpdev:understand` Step 3 按技术栈检测后加载：

- 改 reference 内容 → 直接编辑对应文件
- 新增语言支持 → 加 reference 文件 + 在 `mpdev-understand.md` Step 3 加检测规则

### 2. 添加新数据库方言

参考 [`.claude/templates/dialects/README.md`](./templates/dialects/README.md) 的 §3 "添加新 dialect"。完整 step-by-step 在那里，本文件不重复。

简短流程：复制现有 dialect 作骨架 → 改 yaml 元数据 → 改 9 个 BLOCK → 在 `mpdev-init.md` 的 Step 8.2 表格加识别行。

### 3. 添加新测试 flavor（项目类型）

如果项目类型不在内置 7 种里（http-api / web-frontend / microservices / mobile-app / algo-service / data-pipeline / robot-iot），需要新增 flavor。

简短流程：

1. **复制骨架**：`cp templates/test-flavors/http-api.md templates/test-flavors/{your-type}.md`
2. **改 yaml 元数据**：`project_type` / `project_type_short` / `identification_signals` / `default_test_dir`
3. **改 9 个 BLOCK**（每个 `<!-- BLOCK:X -->` 必须配对 `<!-- /BLOCK:X -->`，否则 init 注入失败）：
   - `PROJECT_TYPE_SCOPE` — 适用项目范围
   - `TEST_LEVELS` — 测试金字塔比例（单元/集成/E2E）
   - `KEY_RISK_AREAS` — 高风险测试域
   - `AUTOMATION_STACK` — 自动化栈（库/工具）
   - `CI_INTEGRATION` — CI 配置示例
   - `METRICS` — 度量阈值（覆盖率/通过率）
   - `NON_FUNCTIONAL` — 非功能测试（性能/安全/兼容性）
   - `SAMPLE_CASES` — 典型用例样板
   - `DIALECT_CONSTRAINTS` — 项目类型特定约束
4. **在 `mpdev-init.md` Step 9 加识别表行**：识别信号（项目根含什么文件/yaml 关键词）→ 推荐 flavor
5. **校验**：`grep -c "<!-- /BLOCK:" templates/test-flavors/{your-type}.md` 必须等于 9
6. **测试**：在样本项目跑 `/mpdev:test detect-flavor` 验证识别 + 注入正确

### 4. Agent 文件 (`agents/*.md`) 重新生成

`agents/*.md` 是 `/mpdev:init` 从 `templates/*.tmpl` + 各模块 CLAUDE.md 生成的产物。**何时重新生成**：

- 模块 CLAUDE.md 大幅更新后
- 项目结构变化（加了/删了模块）
- 模板（`*.tmpl`）本身改进后

**重新生成命令**：

```bash
/mpdev:init
# 它会询问是否覆盖已存在的 agents/*.md，一般选"全部覆盖"（除非你手动改过）
```

### 5. 跨项目复用整套 `.claude/`

把整个 `.claude/` 拷到新项目后，标准激活流程：

```
1. /mpdev:understand    → 给新项目各模块生成 CLAUDE.md
2. /mpdev:contracts     → 跨模块项目才需要
3. /mpdev:init          → 生成新项目的 agents/
4. 修改 .claude/MPDev-Scheme.md §0 "本项目实例" 小节（项目名等）
5. /mpdev:dev               → 开始用
```

无需手动改 commands / templates —— 这两个目录是框架级、跨项目通用。

### 6. mpdev-runs/ 历史归档清理

`mpdev-runs/` 会随时间膨胀。建议策略：

- 保留最近 **3 个月** 的 `{run_id}/`、`fixes/`、`commits/`、`setup/`
- 旧的归档：移到 `mpdev-runs-archive/{year}-{quarter}/` 或干脆 `git rm` 后从 git 历史回溯
- `INDEX.md` 中的旧行可酌情清理（保留近 50 行近期记录足够日常查阅）

**不要**把整个 `mpdev-runs/` 加 `.gitignore` —— 它是项目协作的重要档案，应当随代码进 git。
