# MPDev 套件

> 多模块 AI 协同开发框架。**9 个 slash 命令** 驱动 **13 个 AI agent**，覆盖"理解项目 → 提取契约 → 框架初始化 → 开发 → 测试 → 修复 → 提交 → 运维"的全生命周期。

## 30 秒读懂

- **解决什么**：跨模块 / 多语言项目（Java + Vue + Python）的协同开发，避免人工对齐契约、协调多模块改动
- **怎么用**：用户用自然语言描述需求 → 系统自动编排 11 个 subagent 完成跨模块改动 + 文档归档
- **核心能力**：契约先行 / 三阶段测试嵌入（IEEE 829 标准）/ DBA 数据层设计 / 缺陷生命周期闭环
- **当前实例**：`mpdevops`（机器人巡检平台 6 模块跨栈）—— 框架本身通用，可拷贝到任意多模块项目

---

## 套件全景

```
.claude/
├── commands/             9 个 slash 命令（按生命周期分阶段）
├── agents/              13 个 AI agent（架构 / 实现 / 审查 / 验收 / 测试 5 类）
├── templates/            模板体系
│   ├── *.tmpl           5 个基础 agent 模板
│   ├── dba.tmpl + dialects/      DBA 双层（骨架 + 4 种数据库方言）
│   ├── tester.tmpl + test-flavors/   Tester 双层（骨架 + 7 种项目类型 flavor）
│   └── understand/references/    project-understanding skill 的本地 fallback（6 个语言指南）
├── mpdev-runs/           运行档案（每次命令产出的文档持久化在此）
│   ├── INDEX.md          全局索引（运行 / 修复 / 提交 / 测试 4 张表）
│   ├── {run_id}/         /mpdev 单次运行 14 步全套文档
│   ├── fixes/            /mpdev-fix 修复报告
│   ├── commits/          /mpdev-commit 提交记录
│   ├── setup/            /mpdev-understand + /mpdev-contracts 归档
│   └── test-{plans,cases,exports}/   /mpdev-test 子命令产出
├── MPDev-Scheme.md       方案说明书（设计决策 + 角色定义，给架构师/技术决策者）
├── mpdev-suite-workflow.md   使用手册（详细使用，给开发者）
└── README.md             本文件（顶层入口 + 速查）
```

**累积规模**：约 6000 行 markdown 命令 + 50+ 个文件。

---

## 9 个命令一览

| 阶段 | 命令 | 一句话职责 | 典型时机 |
|---|---|---|---|
| **0a** | `/mpdev-understand` | 给各模块生成 CLAUDE.md（包装 project-understanding skill） | 新项目首次进入 |
| **0b** | `/mpdev-contracts` | 多 CLAUDE.md 交叉比对生成 robot-contracts/ | 跨模块项目建立共享接口 |
| **1** | `/mpdev-init` | 扫描 + 模板 → 生成 13 个 agent 定义 | 阶段 0 完成后 |
| **2** | `/mpdev` | 跨模块开发主编排（含 14 步全流程 + 三阶段测试嵌入） | 日常需求、新功能 |
| **2** | `/mpdev-fix` | 单 bug / 批量清单（禅道 CSV / Markdown）修复 | 测试反馈 / 自测发现 bug |
| **2** | `/mpdev-test` | 测试套件（plan / cases / run / report / uat / bug / detect-flavor） | 测试专项 / 缺陷管理 |
| **2** | `/mpdev-check` | 契约 vs 代码漂移检测 | 手改完代码 / `/mpdev` 运行前 |
| **2** | `/mpdev-env` | 环境配置启停（含 Docker Compose 自适应） | 启动服务栈 / 重启 |
| **2** | `/mpdev-commit` | 扫 diff → 中文 commit 说明 + 契约风险检测 | 代码改完准备提交 |

---

## 13 个 AI Agent（分 6 类）

| 类别 | Agent | 触发 |
|---|---|---|
| **架构类（3）** | architect / dba ⚡ / contract-designer | dba 条件触发（DB 变更时）|
| **实现类（5）** | java-impl / dispatch-impl / analytics-impl / vue-impl / algor-impl | /mpdev Step 8 并行调用 |
| **审查类（2）** | code-reviewer / integration-checker | /mpdev Step 10 并行调用 |
| **验收类（1）** | acceptance-reviewer | /mpdev Step 11 |
| **测试类（1）** | tester 🧪（项目类型自适应）| /mpdev Step 7 / 9 / 12 三阶段嵌入 |
| **文档类（1）** | doc-refresher（v1.1.0 新增）| /mpdev Step 12.5 文档增量刷新 |

---

## 复用到新项目（5 步激活）

### 第 1 步：拷贝套件

```bash
# 在新项目根目录
cp -r /path/to/mpdevops/.claude ./.claude

# 删除项目实例（agents/ 和 mpdev-runs/）— 这些是 mpdevops 特化的
rm -rf .claude/agents/*.md
rm -rf .claude/mpdev-runs/*/
rm -f .claude/mpdev-runs/test-cases/*

# 删除项目特化设置（保留套件级配置）
# settings.json / settings.local.json 视情况
```

### 第 2 步：理解项目（生成各模块 CLAUDE.md）

```
/mpdev-understand
```

- 单模块项目：自动检测后直接分析
- 多模块（monorepo）：让你确认范围，然后 5 轮分析每个模块

产出：每个模块根的 `CLAUDE.md` + `TODO.md`，归档到 `mpdev-runs/setup/`。

### 第 3 步：提取契约（仅跨模块项目）

```
/mpdev-contracts
```

读各模块 CLAUDE.md 的接口区块（REST / MQ / DB），交叉比对后生成 `robot-contracts/` 仓库。

**单模块项目跳过这步**。

### 第 4 步：初始化 mpdev 框架

```
/mpdev-init
```

执行 12 个 Step：扫模块 → 读 CLAUDE.md → 识别语言 → 生成 5 个 impl agent + architect + contract-designer + **dba（条件）+ tester（条件）** + 复制 4 个通用 agent（含 v1.1.0 新增 doc-refresher）+ 生成 mpdev.md 编排器 + 输出汇总。

产出：`.claude/agents/` 全套 13 个 agent 定义。

### 第 5 步：开始日常开发

```
/mpdev 给告警表加一个 silent_until 字段，支持告警静默到指定时间
```

主流程 14 步执行（详见 `MPDev-Scheme.md` §3）。

---

## 拷贝清单（精确版）

### ✅ 必拷贝（框架级，跨项目通用）

| 路径 | 文件数 | 说明 |
|---|---:|---|
| `commands/*.md` | 9 | 9 个 slash 命令 |
| `templates/*.tmpl` | 7 | architect / contract-designer / impl-java / impl-python / impl-vue / dba / tester |
| `templates/dialects/*.md` | 5 | mysql / postgresql / dameng / kingbase + README |
| `templates/test-flavors/*.md` | 7 | 7 种项目类型方言（http-api / web-frontend / microservices / mobile-app / algo-service / data-pipeline / robot-iot）|
| `templates/understand/references/*.md` | 6 | project-understanding skill 的本地副本（不依赖 skill 安装）|
| `MPDev-Scheme.md` | 1 | 方案说明书（改 §0 本项目实例后复用）|
| `mpdev-suite-workflow.md` | 1 | 使用手册 |
| `README.md` | 1 | 本文件 |
| `mpdev-runs/INDEX.md` | 1 | 索引模板（清空表格内容）|
| **合计** | **38** | 框架核心 |

### ❌ 不拷贝（项目实例 / 历史归档 / 运行时生成）

| 路径 | 原因 | 处理 |
|---|---|---|
| `agents/*.md` | mpdevops 项目特化（含 MR-ULT 巡检平台细节）| 跑 `/mpdev-init` 在新项目重新生成 |
| `mpdev-runs/{run_id}/` | 运行历史，与新项目无关 | 不拷 |
| `mpdev-runs/fixes/` | 修复历史 | 不拷（清空）|
| `mpdev-runs/commits/` | 提交历史 | 不拷 |
| `mpdev-runs/setup/` | 阶段 0 历史归档 | 不拷 |
| `mpdev-runs/test-{plans,cases,exports}/` | 测试历史 | 不拷 |
| `settings.json` / `settings.local.json` | Claude Code 工程级配置 | 视情况（跨项目通用部分可拷） |

### 一键打包脚本（推荐用法）

```bash
#!/bin/bash
# pack-mpdev.sh — 打包框架核心，给同事用

mkdir -p mpdev-pack/.claude/{commands,templates/dialects,templates/test-flavors,templates/understand/references,mpdev-runs}

cp .claude/commands/*.md mpdev-pack/.claude/commands/
cp .claude/templates/*.tmpl mpdev-pack/.claude/templates/
cp .claude/templates/dialects/*.md mpdev-pack/.claude/templates/dialects/
cp .claude/templates/test-flavors/*.md mpdev-pack/.claude/templates/test-flavors/
cp .claude/templates/understand/references/*.md mpdev-pack/.claude/templates/understand/references/
cp .claude/MPDev-Scheme.md mpdev-pack/.claude/
cp .claude/mpdev-suite-workflow.md mpdev-pack/.claude/
cp .claude/README.md mpdev-pack/.claude/
cp .claude/mpdev-runs/INDEX.md mpdev-pack/.claude/mpdev-runs/

# 清空 INDEX.md 的表格内容（保留结构）
# 同事拿到 mpdev-pack/ 后 cp -r mpdev-pack/.claude /target-project/
echo "Done. mpdev-pack/.claude/ 共 $(find mpdev-pack -type f | wc -l) 个文件"
```

---

## 文档导航

| 我想... | 看这里 |
|---|---|
| **快速上手** | 本文件（README.md）|
| **详细使用每个命令** | [`mpdev-suite-workflow.md`](mpdev-suite-workflow.md)（使用手册，484 行）|
| **了解架构设计 / 角色定义** | [`MPDev-Scheme.md`](MPDev-Scheme.md)（方案说明书，881 行）|
| **给 DBA 加新数据库方言** | [`templates/dialects/README.md`](templates/dialects/README.md) |
| **给 Tester 加新项目类型 flavor** | 暂无独立 README，参考 [`templates/test-flavors/http-api.md`](templates/test-flavors/http-api.md) 模仿 |

---

## 维护提示

### 同步外部 skill 副本

`templates/understand/references/` 是 `project-understanding` skill 的本地副本。skill 仓库更新后手工同步：

```bash
cp ~/.claude/skills/project-understanding/references/*.md \
   .claude/templates/understand/references/
```

### 添加新数据库方言

参考 [`templates/dialects/README.md`](templates/dialects/README.md) 的 step-by-step 指南。复制现有 dialect 作骨架 → 改 yaml + 9 个 BLOCK → 在 `mpdev-init.md` Step 8.2 表格加识别行。

### 添加新测试类型 flavor

参考已有 7 个 flavor（如 `templates/test-flavors/http-api.md`）模仿。每个 flavor 文件必含：
- yaml 元数据 4 字段（`project_type` / `project_type_short` / `identification_signals` / `default_test_dir`）
- **9 个 BLOCK 完整开闭对成**（每个 `<!-- BLOCK:X -->` 必须有 `<!-- /BLOCK:X -->`）
- BLOCK 名固定：PROJECT_TYPE_SCOPE / TEST_LEVELS / KEY_RISK_AREAS / AUTOMATION_STACK / CI_INTEGRATION / METRICS / NON_FUNCTIONAL / SAMPLE_CASES / DIALECT_CONSTRAINTS

写完后用 grep 验证：`grep -c "<!-- /BLOCK:" your-flavor.md` 必须等于 9。

### mpdev-runs/ 历史归档清理

- 保留最近 3 个月的运行档案
- 旧档案移到 `mpdev-runs-archive/{year}-{quarter}/`
- **不要把整个 mpdev-runs/ 加 .gitignore** —— 它是协作历史，应当随代码进 git

---

## 故障排查（FAQ）

### Q1: `/mpdev` 跑到 Step 7 报"tester.md 不存在"

**原因**：没跑过 `/mpdev-init`（或 init 时跳过了 tester 生成）。

**解决**：跑 `/mpdev-init` 完整一遍，或 `/mpdev-test detect-flavor` 单独生成 tester.md。

### Q2: `/mpdev-init` 识别不出项目类型 / DB 引擎

**原因**：项目结构不是主流（如非 Maven/Gradle/npm）或 CLAUDE.md 缺关键信息。

**解决**：
- DB 引擎不识别 → init 会弹询问，从 5 种里选
- 项目类型不识别 → 兜底用 http-api flavor，可手工换：`/mpdev-test detect-flavor` 选

### Q3: 同事拿到套件跑 `/mpdev-understand` 但不安装 project-understanding skill 也能用？

**能**。套件已自包含 `templates/understand/references/`（6 份 references，2333 行），skill 不存在时自动 fallback 用本地副本。

### Q4: `/mpdev-env` 在 Spring Cloud 项目（含 Nacos + Docker Compose）能跑吗？

**能**。`/mpdev-env` 自动检测 `docker-compose*.yml`，识别到 Nacos 等基础设施会两阶段启动（先 compose up 等就绪 → 再启业务模块）。详见 mpdev-env.md 的 Step 2 段。

### Q5: 同事的项目是单模块（无跨模块通信），用不到 `/mpdev-contracts` 怎么办？

**跳过即可**。`/mpdev-init` 会检测到无 robot-contracts/ 跳过 contract-designer 生成；后续 `/mpdev` 流程的 Step 6 也会跳过。

### Q6: `/mpdev-fix --batch` 接什么格式的输入？

支持 4 种格式（自动识别）：
- 禅道 CSV 导出
- Markdown 表格 `| 模块 | 问题 |`
- Markdown 列表 `- [java] xxx`
- 自由文本（兜底）

`/mpdev-test bug export` 输出的是 Markdown 列表格式，可直接 pipe 给 `/mpdev-fix --batch`。

### Q7: 我改了 templates/test-flavors/xxx.md 但跑 `/mpdev-test detect-flavor` 没生效

**原因**：detect-flavor 重生成 `agents/tester.md`，但缓存的对话上下文可能还是旧的。

**解决**：detect-flavor 会备份旧 tester.md 为 `.bak.{ts}`，确认 `agents/tester.md` 已更新即可。新对话自动加载新版。

---

## 命令速记卡

```bash
# 阶段 0 - 项目准备（仅新项目）
/mpdev-understand                    # 各模块 CLAUDE.md
/mpdev-contracts                     # robot-contracts/

# 阶段 1 - 框架初始化（一次性）
/mpdev-init                          # 生成 13 个 agent

# 阶段 2 - 日常开发
/mpdev "需求描述"                     # 跨模块开发主流程
/mpdev-fix dispatch 启动报 KeyError    # 单 bug 修复
/mpdev-fix @bugs.md                  # 批量从清单修复
/mpdev-test cases java               # 给 java 模块设计测试用例
/mpdev-test run --module java        # 跑 java 测试
/mpdev-test bug list                 # 查缺陷
/mpdev-test bug export               # 导出缺陷 → 喂给 /mpdev-fix
/mpdev-check                         # 契约漂移检测
/mpdev-env start                     # 启动服务栈
/mpdev-env restart java              # 重启某模块
/mpdev-commit                        # 自动生成 commit message
```

---

**新项目从 0 到第一次 `/mpdev` 实跑，预计 30 分钟内**（含 understand 5 轮分析 + contracts 比对 + init 模板合并）。
