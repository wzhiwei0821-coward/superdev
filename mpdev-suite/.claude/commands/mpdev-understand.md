---
name: mpdev-understand
description: 项目深度理解 — 给各模块生成高质量 CLAUDE.md（mpdev 生命周期阶段 0a）
allowed-tools: Read, Grep, Glob, Bash, TodoWrite, Write, Edit, AskUserQuestion
---

# /mpdev-understand — 项目深度理解 + CLAUDE.md 生成

mpdev 套件**生命周期阶段 0a**。把"读懂项目代码 → 沉淀为 CLAUDE.md"这件事变成 mpdev 体系内的标准入口。

**底层工作流**：调用 `project-understanding` skill（位于 `~/.claude/skills/project-understanding/SKILL.md`，约 389 行）。本命令**不复制 skill 内容**——skill 是单一事实源，命令只做包装。

**定位**：

| mpdev 命令 | 阶段 | 产出 |
|----------|------|------|
| **`/mpdev-understand`** | 0a | 各模块 `CLAUDE.md` |
| `/mpdev-contracts` | 0b | `robot-contracts/` 仓库 |
| `/mpdev-init` | 1 | `.claude/agents/` |
| `/mpdev` ... | 2+ | 日常开发 |

**何时用**：

- 拿到一个新项目（CLAUDE.md 缺失）
- 已有项目但 CLAUDE.md 已经过期（技术栈变了 / 加了新模块）
- 多模块仓库要把每个模块的语义沉淀下来

**何时不用**：

- 单文件脚本或玩具项目
- CLAUDE.md 已经很新且高质量（但你想刷新部分章节，可手工编辑或用 `/init` 局部更新）

---

## 用户输入

$ARGUMENTS

### 支持参数

| 参数 | 含义 | 示例 |
|------|------|------|
| 空 | 交互式发现并选择模块（走 skill Step 0.5） | `/mpdev-understand` |
| `only=<模块名列表>` | 只处理指定模块 | `/mpdev-understand only=java,vue` |
| `exclude=<模块名列表>` | 排除某些模块 | `/mpdev-understand exclude=docs,tools` |
| `force` | 覆盖现有 CLAUDE.md（默认会询问） | `/mpdev-understand only=java force` |
| 自由文本 | 触发 skill 的"快速路径"（skill Step 0.5.4） | `/mpdev-understand 只看 gateway 和 user-service` |

---

## Step 1: 加载工作流

### 1.1 加载主 SKILL.md

```
读 ~/.claude/skills/project-understanding/SKILL.md（如不存在尝试备用路径）
将其作为本次执行的工作流指南（5 轮 + 0.5 范围确认 + 合成）
```

skill 文件未找到 → 提示："`project-understanding` skill 未安装。请安装后重试，或读 `.claude/mpdev-suite-workflow.md` 的 `/mpdev-understand` 章节获取流程概览。"

### 1.2 references 加载优先级（**重要**）

SKILL.md 在 Step 1 检测到项目技术栈后会加载 `references/{lang}.md`（按语言/领域分片的详细执行指令）。**本套件已自包含一份副本**，加载顺序如下：

```
1. 优先读 .claude/templates/understand/references/{lang}.md   ← 套件内自包含
2. 找不到 → 回退到 ~/.claude/skills/project-understanding/references/{lang}.md
3. 都找不到 → 提示用户安装或更新 skill
```

**为什么自包含**：让本套件拷贝到新项目后**无需先装 skill** 也能跑（skill 仍是 source of truth，本地副本是 fallback for portability）。

**已包含的 references**（按 SKILL.md Step 1 检测规则触发）：

| 检测条件 | 加载文件 | 行数 |
|---------|---------|------|
| `pom.xml` / `build.gradle` 存在 | `java_springboot.md` | 530 |
| Python 通用 | `python_generic.md` | 452 |
| 算法服务（YOLO/PaddleOCR/CV）| `python_algo.md` | 379 |
| 数据处理（asyncio/pandas）| `python_dataproc.md` | 337 |
| 调度系统（Flask/ROS）| `python_scheduler.md` | 333 |
| Vue 前端（vue.config.js）| `vue_frontend.md` | 302 |

**同步策略**：本地副本基于 skill 在某时刻的快照。若 skill 更新了 references，需手工 `cp ~/.claude/skills/project-understanding/references/*.md .claude/templates/understand/references/` 同步。

## Step 2: 解析用户参数

```
将 $ARGUMENTS 解析为:
  - scope_filter: only / exclude / 自由文本 / 全部
  - force_overwrite: bool
  - specific_modules: List[str]

把解析结果作为 skill 的 Step 0.5 输入"已知范围描述"传入。
```

**force 模式**：检测到现有 CLAUDE.md 时，跳过"是否覆盖"询问，直接备份后覆盖。备份位置：`{原路径}.bak.{timestamp}`

## Step 3: 执行 skill 流程

按 project-understanding skill 的 5 轮 + 合成轮执行：

```
第 1 轮 项目骨架    → 笔记
第 2 轮 接口边界    → 笔记
第 3 轮 核心业务流  → 笔记
第 4 轮 基础设施    → 笔记
第 4.5 轮 接口完整性 → 笔记
第 5 轮 验证补盲    → 用户提问 + 笔记
合成轮           → CLAUDE.md + TODO.md
```

**关键约束**（继承自 skill）：

- 多模块仓库 **必须先确认范围**（Step 0.5 不可跳过）
- 笔记写文件不占上下文
- 含置信度标注（high/medium/low）
- 同步产出 `TODO.md` 列出待优化项

### 3.1 skill 中间产物（用户应了解，但无需手工管理）

skill 执行时会产生以下中间文件（由 skill 自管理，本命令不接管）：

- `.claude-notes/scope.md` — 范围确认结果（mode + 选中模块）
- `.claude-notes/round{1..4}.md` 和 `round4.5.md` — 各轮分析笔记
- `.claude-notes/todo.md` — Prompt 5 整理的 TODO 清单（用户回答后会被更新）
- **Monorepo 模式**笔记目录改为 `.claude-notes/{module_name}/round{N}.md`

**最终产出**（用户关心的）：

- 各模块根的 `CLAUDE.md`（mode 决定一份/多份）
- 各模块根的 `TODO.md`
- `mpdev-runs/setup/{timestamp}-understand-{slug}.md`（本命令额外的归档）

### 3.2 三种 mode（skill 在 Step 0.5 自动判定）

| mode | 适用 | 笔记目录 | CLAUDE.md 写入位置 |
|------|------|---------|-------------------|
| `single` | 单模块仓库（根含 pom.xml / package.json 等） | `.claude-notes/round*.md` | 仓库根一份 |
| `monorepo` | 多模块仓库（兄弟目录各有独立项目文件） | `.claude-notes/{module}/round*.md` | 每个模块根各一份 |
| `multi-module-maven` | Maven 聚合工程（根 pom.xml 含 `<modules>`） | `.claude-notes/round*.md`（按子模块分段） | 仓库根一份（按子模块分段） |

### 3.3 中断恢复

skill 支持中断恢复：

- 中断后再跑 `/mpdev-understand`，会读 `.claude-notes/` 已有 round 文件，**从下一轮继续**
- 例：`round1.md` / `round2.md` 已存在 → 直接从 Prompt 3 开始，节省上下文
- 想强制重新开始：先 `rm -rf .claude-notes/`

## Step 4: 📄 文档归档

在每个模块目录写完 `CLAUDE.md` 之后，额外在 mpdev 体系归档执行记录：

```
timestamp = 当前时间 YYYYMMDD-HHMM
slug = scope 简述（如 "java-vue-dispatch"）
file_id = "{timestamp}-understand-{slug}"

Bash("mkdir -p .claude/mpdev-runs/setup")
Write(".claude/mpdev-runs/setup/{file_id}.md", ...)
```

**归档模板**：

```markdown
---
stage: understand
generated_at: {timestamp}
scope: [{module1}, {module2}, ...]
skill: project-understanding
total_modules_processed: N
---

# 项目理解记录

## 用户输入
> {$ARGUMENTS 原文}

## 处理范围
| 模块 | 路径 | CLAUDE.md 状态 | TODO.md 项数 |
|------|------|----------------|------------:|
| {name} | {dir} | 新建/覆盖/未变 | N |

## 关键发现
- 技术栈分布：...
- 跨模块通信：...
- 风险/盲区（来自 TODO.md 汇总）：...

## 下一步建议

- ✅ 各模块 CLAUDE.md 已就绪
- ➡️ 建议下一步运行 `/mpdev-contracts` 生成契约仓库
- 或手动 review 某模块的 CLAUDE.md 后再决定

## 关联文件
- {module1}/CLAUDE.md
- {module1}/TODO.md
- ...
```

## Step 5: 与下游命令的衔接提示

执行完成后，根据本次产出动态推荐下一步：

```
if 多模块且未发现现有 robot-contracts/:
  → "建议下一步: /mpdev-contracts 生成契约仓库"
elif 已有 robot-contracts/ 但 .claude/agents/ 缺失:
  → "建议下一步: /mpdev-init 初始化 mpdev 编排器"
elif .claude/agents/ 已就绪:
  → "建议: /mpdev 描述需求开始开发；或先 /mpdev-check 验证契约一致性"
```

---

## 容错规则

| 情况 | 处理 |
|------|------|
| skill 文件未找到 | 提示用户安装 `project-understanding` skill；不降级用本命令内嵌流程（避免双源） |
| 单模块仓库（无需选范围） | 跳过 Step 0.5，直接进 Step 1 |
| 用户输入歧义（"差不多""你定"）| 拒绝并重申选项（继承 skill 行为）|
| CLAUDE.md 已存在且未指定 force | 询问用户：[覆盖 / 跳过此模块 / 全部覆盖 force]|
| 中途用户说"停" | 立即终止；已生成的 CLAUDE.md 保留 |
| 模块识别失败 | 让用户手动指定模块路径 |

## 约束

1. **不复制 skill 内容** — skill 是单一事实源；命令只做包装、参数解析、归档
2. **强制范围确认** — 多模块仓库不跳过 Step 0.5
3. **置信度标注必有** — 生成的 CLAUDE.md 必须含 confidence 字段（high/medium/low）
4. **TODO.md 同步产出** — 不只写 CLAUDE.md，把待优化项落到 TODO.md
5. **覆盖前必备份** — force 模式也要备份 `.bak.{timestamp}`
6. **不自动跳到 contracts** — 完成后展示建议，不自动调用 `/mpdev-contracts`（让用户审查 CLAUDE.md 后再决定）
7. **必写归档文档** — 即使部分模块失败也写一份归档到 `mpdev-runs/setup/`
