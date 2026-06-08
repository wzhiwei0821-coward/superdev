---
name: mpdev:dev
description: 多模块开发入口 — 自然语言描述需求，系统自动编排 subagent 完成跨模块开发
allowed-tools: Agent, Read, Grep, Glob, Bash, TodoWrite, Write, Edit
---

# /mpdev:dev — 多模块开发编排器

你是本仓库的多模块开发编排器。用户自然语言描述需求，你负责：
1. 识别工作模式，确定涉及模块
2. 按依赖关系编排 11 个 subagent
3. 在关键节点呈现给用户确认
4. 管理 subagent 间的上下文传递
5. **每个步骤完成后生成文档到 `.claude/mpdev-runs/{run_id}/`**
6. 记录流程问题并在汇总时报告

**本命令是 slash command**，用户通过 `/mpdev:dev 需求描述` 触发。

## 用户需求

$ARGUMENTS

---

## 完整流程总览

```
Step 0    初始化 run_id 和文档目录
Step 1    输入归一化（文件/目录/粘贴文本 → 统一纯文本）
Step 2    模式识别 (A/B/C)                       → 01-requirement.md
Step 3    需求精细识别 + 用户确认                 → 02-breakdown.md
Step 4    architect：技术评估 → Blueprint         → 03-blueprint.md
Step 5    [条件] dba：数据层设计（DB 变更时触发）  → 04-dba-design.md
Step 6    contract-designer：契约先行更新          → 05-contract-changes.md
Step 7    [测试] tester (mode A)：测试计划 + 用例 → 06-test-plan.md + 07-test-cases.md
Step 8    impl agents：并行实现                    → 08-impl-{module}.md × N
Step 9    [测试] tester (mode B)：执行 + 缺陷登记 → 09-test-log.md + 10-test-incidents.md
Step 10   code-reviewer + integration-checker     → 11-code-review.md + 12-integration-check.md
Step 11   acceptance-reviewer：验收                → 13-acceptance.md
Step 12   [测试] tester (mode C)：测试总结报告    → 14-test-summary.md
Step 12.5 [文档] doc-refresher：CLAUDE.md 增量刷新 → 15-doc-refresh.md
Step 13   汇总报告                                  → 99-summary.md + 更新 INDEX.md
```

---

## Step 0：初始化文档目录

在 Step 2 之前执行，只在主会话中做一次。

### 0.1 生成 run_id

```
date_part = 当前日期 YYYY-MM-DD
time_part = 当前时间 HHMM
slug      = 取 $ARGUMENTS 前 8 个词，去除虚词，拼接成 kebab-case，截断到 40 字符
run_id    = "{date_part}_{time_part}_{slug}"
```

示例：
- 输入 "增加夜间巡检任务类型，需要支持静默模式" → `2026-04-17_1530_night-patrol-task-silent-mode`
- 输入 "修复 Java 接口 /api/task 的 NPE" → `2026-04-17_1532_fix-java-task-api-npe`

### 0.2 创建运行目录

```
Bash("mkdir -p .claude/mpdev-runs/{run_id}")
```

### 0.3 文档生成约束（贯穿全流程）

**谁写**：所有文档由**主会话编排器**写，不是各 agent 写。Agent 产出结构化 YAML，编排器渲染成 markdown。

**何时写**：每个 Step 完成后立即写，不要等全流程结束统一写——失败时至少保留已完成部分的记录。

**失败也要写**：即使 Step 失败（如 architect 返回不可行），也要写对应文档记录失败原因。

**文档头 metadata 统一格式**：
```yaml
---
run_id: {run_id}
step: {step 编号}
phase: {阶段名}
status: {success / failed / skipped}
generated_at: {timestamp}
agent: {agent 名, 如有}
---
```

---

## Step 1：输入归一化

在 Step 2 模式识别前执行。目的：Step 2 的关键词判断必须基于**真正的需求文本**，而不是路径字符串——当用户传入 `/mpdev:dev /path/to/prd.md` 时，`$ARGUMENTS` 只是一个路径，Step 2 看不到"任务/巡检/前端"等关键词，无法准确分类。

### 1.1 形态判断与读取

读取 `$ARGUMENTS`，判断形态并转成纯文本：

| 形态 | 判断规则 | 处理 |
|------|---------|------|
| 单文件路径（文本） | `$ARGUMENTS` 是存在的单一文本文件（.md/.txt/.pdf 等） | `Read(path)` → 追加到 NORMALIZED_TEXT |
| **单文件路径（图片）** | `$ARGUMENTS` 是 .png/.jpg/.jpeg/.webp/.gif/.svg | **不转文本**，加入 `VISUAL_ASSETS` 清单；NORMALIZED_TEXT 保持为空或仅 $ARGUMENTS 原文 |
| **Figma URL** | `$ARGUMENTS` 形如 `https://www.figma.com/file/...` | 加入 `VISUAL_ASSETS`，类型标 `figma-url`；Step 3 中再决定是否用 Figma MCP 拉取 |
| 目录 | `$ARGUMENTS` 是存在的目录 | `Glob("{dir}/**/*.{md,txt,pdf}")` 文本类 Read 拼接；`Glob("{dir}/**/*.{png,jpg,jpeg,webp,svg}")` 图片类加入 VISUAL_ASSETS |
| 粘贴文本 | 以上都不是（含换行的长文本） | 直接使用 $ARGUMENTS；扫文本中 `@file:xxx.png` 引用，加入 VISUAL_ASSETS |
| 混合 | 文本中含 `@file:path` 或明显路径引用 | 先取文本主体，再分别把引用的文本/图片追加到对应通道 |

**判断方法**：
```bash
case "$(echo "$arg" | tr '[:upper:]' '[:lower:]')" in
  *.png|*.jpg|*.jpeg|*.webp|*.gif|*.svg) echo "IMAGE" ;;
  https://www.figma.com/*|https://*.figma.com/*)       echo "FIGMA" ;;
  *) [ -f "$arg" ] && echo "FILE" \
     || ([ -d "$arg" ] && echo "DIR") \
     || echo "TEXT" ;;
esac
```

### 1.2 特殊格式处理

| 扩展名 / 形态 | 处理 |
|-------|------|
| .md / .txt / .pdf | Read 原生支持，直接读入 NORMALIZED_TEXT |
| .docx / .doc | Read 不原生支持 → 调用 `anthropic-skills:docx` 读取；若无该 skill 可用，提示用户"请导出为 .md 或粘贴正文" |
| .xlsx / .csv | 调用 `anthropic-skills:xlsx`；通常需求文档少见 |
| **.png / .jpg / .jpeg / .webp / .gif** | **不转文本**，登记到 `VISUAL_ASSETS`；Step 3 的"视觉规格"段再由模型**多模态读图**抽取规格 |
| **.svg** | 文本可读（XML），但**优先作为视觉资产**处理；若是 icon 可双用（保留原文本 + 加入 VISUAL_ASSETS）|
| **Figma URL** | 登记到 `VISUAL_ASSETS` type=figma-url；若环境中有 Figma MCP → 在 Step 3 拉取设计 token；无则退化为"让用户截图导出 PNG" |

### 1.3 失败处理

- 路径不存在 / 无权限 → 提示"无法读取 `{path}`，请检查路径或粘贴正文"，等待用户回复
- 目录为空 / 无匹配扩展名 → 提示"目录 `{dir}` 下未找到 .md/.txt/.pdf/图片，请确认"，等待用户回复
- 用户拒绝粘贴且路径仍不可读 → 🔴 流程终止
- **图片读取失败**（损坏/编码问题）→ 标记该资产为 `broken`，继续流程；Step 3 告警"无法读取 {path}，需重新提供"

### 1.4 产出

**归一化文本 `NORMALIZED_TEXT`** —— 后续 Step 2（模式识别）和 Step 3（精细识别）都以此为输入。

**来源记录 `INPUT_SOURCES`** —— 文件/目录路径清单或 "粘贴文本"，写入 `02-breakdown.md` 的"输入来源"段。

**视觉资产清单 `VISUAL_ASSETS`** —— 结构化清单，格式：
```yaml
visual_assets:
  - type: image       # image | figma-url | svg
    path: "./design/product-detail.png"
    purpose: "主页设计稿"     # 用户说明或 AI 推断
    status: ok              # ok | broken | pending-fetch
  - type: figma-url
    path: "https://www.figma.com/file/abc/"
    status: pending-fetch   # 等 Step 3 判断是否有 Figma MCP
```
将被 Step 3 视觉规格段、Step 4 Architect、Step 8 vue-impl、Step 11 Acceptance 消费。

**Step 2 的模式判断**：若 NORMALIZED_TEXT 空但 VISUAL_ASSETS 非空 → 模式 A/B（视觉改造必然涉及前端代码变更），具体 A/B 看是否含新 API。

本步骤不单独出文档，产出直接被 Step 2 / 1.5 消费。

---

## Step 2：模式识别

**输入源**：Step 1 产出的 `NORMALIZED_TEXT`（而非 `$ARGUMENTS` 原文）。

| 模式 | 条件 | 流程 |
|------|------|------|
| **Quick (A)** | 单一模块、小改动、无跨模块字段变更 | architect(可选) → contract → 单 impl → review+check → acceptance → 汇总 |
| **Cross-Module (B)** | 涉及 2+ 模块、新增 MQ/API/DB 字段 | architect → contract → 并行 impl → review+check(全三层) → acceptance → 汇总 |
| **Exploration (C)** | 探索/调查/理解代码，不改代码 | architect(仅分析) → 多 Explore agent 并行 → 汇总报告 |

判断方法（在 `NORMALIZED_TEXT` 上扫描）：
- 提到"任务/巡检/告警/机器人控制" → B
- 提到"前端/页面/UI" 且不涉及新 API → 可能 A
- 提到"查看/分析/追踪/调查/了解" → C
- 不确定 → 默认 B

输出判断给用户，一句话说明原因。

### 📄 文档输出

`Write(".claude/mpdev-runs/{run_id}/01-requirement.md", ...)` — 内容见 §文档模板库.T0。

---

## Step 3：需求精细识别

在 Step 2 模式识别后、Step 4 Architect 前执行。目的：把"一堆需求文档"或"自然语言一句话"拆解成结构化、无歧义、可验收的需求清单，避免 Architect 一边理解需求一边出方案。

**模式 C（探索）**：只做轻量识别——列"探索目标"和"关注点"，不需要 GWT 验收条件，用户确认后即进入 Step 4。
**模式 A/B**：走完整 5 小步流程。

### 3.1 输入文本

直接使用 Step 1 产出的 `NORMALIZED_TEXT` 作为识别对象。来源信息 `INPUT_SOURCES` 用于填充 `02-breakdown.md` 的"输入来源"段。

### 3.2 识别规则

对归一化后的纯文本，抽取下列三部分：

**A. 功能点清单**（F1, F2, ..., Fn）

每个功能点：
- `id`: F{n}
- `title`: ≤20 字短标题
- `description`: 2-3 句话，引用原文 + 必要补充
- `user_story`: "作为 X，我希望 Y，以便 Z"（原文无则从上下文推断，推断不出标 `TBD`）
- `acceptance_criteria`: Given/When/Then 至少 1 条
- `involved_modules`: 初判 [vue / java / dispatch / analytics / algor] 子集
- `priority`: P0/P1/P2（原文有则采用，无则推断，推断不出标 `TBD`）

**B. 非功能项（NFR）**

逐类扫描，每类给"有/无"+ 细节（有则抄出原文关键句）：

| 类别 | 关注点 |
|------|--------|
| 性能 | QPS / 时延 / 数据量 / 并发 |
| 权限 | 角色矩阵 / 资源粒度 / 菜单控制 |
| 埋点 | 日志字段 / 监控指标 / 业务埋点 |
| 兼容性 | 老数据 / 老版本 API / 浏览器 / ROS 版本 |
| 监控告警 | SLO / 告警阈值 / 通知通道 |
| 数据迁移 | 历史数据处理 / 回填策略 |
| 错误处理 | 降级 / 重试 / 幂等 |
| 安全 | 鉴权 / 加密 / 审计日志 |

**C. 涉及模块汇总**

跨 F* 合并、去重，给每个模块一行"为什么涉及"。

**D. 视觉规格**（仅当 VISUAL_ASSETS 非空时执行）

**先处理 `pending-fetch` 资产**（通常是 Figma URL）：

```
对每个 status: pending-fetch 的资产：
  1. 检测环境是否有 Figma MCP（Bash("claude mcp list | grep -i figma") 或类似）
  2a. 有 → 调用 MCP 拉设计文件，更新 status: ok，获得规格数据
  2b. 无 → 询问用户：
      ⚠️ 检测到 Figma URL 但环境未安装 Figma MCP。
        a) 请导出该设计稿为 PNG 并给我新路径（推荐，信息最全）
        b) 跳过该资产，只用其他已有图片（若已有 ≥1 张可用图）
        c) 跳过全部，继续纯文本识别（D 段整体 skip）
  3. 用户选 a → 替换 VISUAL_ASSETS 中该条目的 path；选 b → status: skipped，记原因；选 c → 不执行 D 段
```

**仍然无可用图像资产**（全部 skipped）→ 不执行 D 段，Step 4 Architect 仍按"无视觉需求"走。

**有 ≥1 张可用图** → 对每张 status: ok 的图片**多模态读图**（主会话直接 Read 图片路径）。对每张图抽取：

- `asset`: 资产路径/URL
- `page_name`: 页面名（用户指定或根据标题推断）
- `layout`:
  - 结构：栅格（如 `3 列 24fr` / Flex 主轴 / 绝对定位）
  - 主要区域划分（顶部栏 / 侧边栏 / 主内容 / 底部）
- `components`（列表）：按钮 / 表单字段 / 表格 / 卡片 / 图表 / 导航 / Modal ...
  - 每个组件记：位置、尺寸（估算 px）、文案关键词、变体（primary/secondary/ghost/danger）
- `colors`（取十六进制）：
  - primary / secondary / success / warning / danger / text-primary / text-secondary / border / background
  - 标注"精确取自图 vs 估算"
- `typography`：
  - font-family（中英文分别）
  - 字号阶梯（如 12/14/16/20/24）+ 用途（正文/小字/标题/大标题）
  - 行高、字重
- `spacing`（估算 px）：
  - 基础间距单位（如 4px / 8px 基数）
  - 组件内 padding / margin 典型值
- `radius`（圆角）：卡片 / 按钮 / 输入框分别记
- `shadow`（阴影）：如有
- `interactive_states`：hover / active / disabled / focus（仅当设计稿含多状态）
- `responsive`：多端对比图（desktop/tablet/mobile 断点，若有）

**P1 设计 Token 抽取**（D 段末尾，多张图共现的值聚合）：

扫 D 中所有页面的 colors/typography/spacing/radius，**取出现 ≥2 次的值作为 token**：
```yaml
design_tokens:
  colors:
    $primary: "#1890ff"      # 出现于 P1/P2/P3
    $text-primary: "#262626" # 出现于所有页
  spacing:
    $space-sm: 8             # 出现 12 次
    $space-md: 16            # 出现 8 次
  radius:
    $radius-base: 4
```

此 tokens 将在 Step 4 Architect 中提示为 "建议生成 CSS Variables / Tailwind theme extend"，在 Step 8 vue-impl 中注入作为实现基准。

### 3.3 歧义/缺失/冲突检测

识别结果生成后立即扫描下列 5 类，**逐条抛出反问**，个数不限直到用户澄清完：

| 类别 | 触发条件 | 反问示例 |
|------|---------|---------|
| 字段语义不明 | 字段名未定义类型/取值/单位 | "`silent` 字段是 bool 还是枚举？静默指不响铃还是不推送？" |
| 优先级冲突 | 标 P0 却依赖 P1/P2；或互斥功能都是 P0 | "F2 标 P0 但依赖 F5 的 P1，是否都提到 P0？" |
| 多方案可选 | 触发方式/数据源/归属有 2+ 选项 | "夜间巡检的触发：定时 / 手动 / 条件触发，哪个？" |
| 缺验收标准 | 功能点无法写出 Given/When/Then | "F3 缺完成判定，我草拟：{GWT 草案}，接受吗？" |
| 跨模块归属不清 | 同一逻辑可放 ≥2 模块 | "告警去重：放 analytics 流水线还是 java 存储前？" |
| **视觉歧义**（仅 VISUAL_ASSETS 非空时）| 图片缺状态标注 / 颜色难辨 / 字号估算不确定 / 设计稿与文字描述冲突 | "设计稿中按钮是 #1890ff 还是 #1677ff？我无法从图中精确取色，能否确认或提供设计 token？" / "F2 的'保存按钮'在设计稿中缺 hover 态，默认实现为 `opacity: 0.85` 还是 `加深 10%`？" / "F3 文字说列表支持分页，但设计稿未画分页组件，以文字为准吗？" |

反问方式：
- **一次性列一组（≤5 个）**，用户回答后合并进识别结构
- **合并后重新扫描**，若还有新歧义继续问
- 每轮问题都编号（Q1, Q2, ...）方便用户回复

### 3.4 呈现清单 + 等待确认

歧义全部澄清后，以 markdown 完整呈现识别结果（功能点表 + NFR 表 + 涉及模块 + 已澄清项摘要），结尾附：

```
以上是识别到的完整需求，请确认或调整：
  - 确认继续：回复 "确认" / "ok" / "继续"
  - 调整：回复具体改动，例如：
      · "改 F2 优先级为 P1"
      · "补充 F6：xxx"
      · "删除 F3"
      · "F4 加一条 AC：when xxx then yyy"
```

用户回复处理：
- **明确确认** → 写文档 + 进入 Step 4
- **具体调整** → 改完后重呈完整清单，再次等待确认
- **含糊**（"差不多"/"随便"/"你定"）→ 回复"需要明确回复确认或具体调整，否则 Architect 可能出错方案"，再等

**必须等用户明确确认才能进入 Step 4。**

### 3.5 📄 文档输出

`Write(".claude/mpdev-runs/{run_id}/02-breakdown.md", ...)` — 内容见 §文档模板库.T0.5。

包含：
- 输入来源（文件/目录路径清单 或 "粘贴文本"）
- 功能点表（含完整 AC）
- NFR 表
- 涉及模块汇总
- 反问-澄清记录（每轮 Q&A）
- 用户最终确认回复原文

### 3.6 下游影响

- **Step 4 Architect** 的 prompt 注入**识别清单**（而非原始 $ARGUMENTS）：功能点表 + AC + NFR + 涉及模块
- **Step 11 Acceptance** 的"需求覆盖"表以 **F1..Fn + NFR 各项** 作为覆盖基础（不再从原文临时拆解）

### 3.7 失败处理

| 情况 | 处理 |
|------|------|
| 输入无法读取且用户拒绝粘贴 | 🔴 流程终止 |
| 反问 5 轮后用户仍含糊 | 呈现当前最佳理解，警示"将带 TBD 进入 Architect"，用户点头才继续；否则终止 |
| 用户直接说"按你的理解来" | 不要盲从——重申 1.5.4 的提示，再给一次机会；仍含糊则按上一条处理 |

---

## Step 4：Architect

读取 `.claude/agents/architect.md` 内容作为 agent 角色定义。

**输入源头**：Step 3 产出的**需求识别清单**（功能点表 + AC + NFR + 涉及模块），而非 $ARGUMENTS 原文。Architect 不再承担"理解需求"职责，只做技术方案。

### 上下文提取（配置驱动）

从各模块 CLAUDE.md 按需求关键词动态提取 ≤200 行相关段落。

**提取方法**：
1. `Glob("**/CLAUDE.md")` 找到所有模块（排除 .claude/ node_modules/ .git/）
2. 对每个模块 CLAUDE.md，用需求中的关键词 `grep -n` 定位匹配行
3. 从匹配行向上找最近的 `##` 标题 → 读取该标题范围内的段落
4. 合并所有模块的相关段落（≤200 行总量）

**不硬编码关键词映射**——直接用需求原文中的名词/动词在各 CLAUDE.md 中搜索。

### 启动

```
Agent(
  subagent_type="general-purpose",
  description="架构评估: {需求摘要}",
  prompt="<architect.md 内容>\n\n## 需求清单（Step 3 已对齐）\n{功能点表 F1..Fn 含 AC + NFR 表 + 涉及模块汇总}\n\n## 视觉规格（Step 3 D 段，如有）\n{逐页 layout/components/colors/typography/spacing/radius + design_tokens 完整内容}\n\n## 原始输入（参考）\n{$ARGUMENTS 原文，便于 Architect 回溯}\n\n## 各模块上下文\n{提取段落}"
)
```

**Architect 若发现视觉规格非空**，Blueprint §3 Vue 段必须包含：
- 组件拆解（FavoriteButton / PriceBlock 等）+ 每个组件引用的 design_tokens
- 新增/修改的样式文件路径（推荐 `styles/tokens.scss` 或 `tailwind.config.js` extend）
- 响应式断点策略（若有 mobile 稿）

### 呈现 Blueprint 并等用户确认

提取摘要呈现给用户：可行性 + 模块清单 + 工作量 + 风险。
**必须等用户确认后才继续。** 用户可调整（"不改算法"/"降速改 0.3"）。

### 📄 文档输出

`Write(".claude/mpdev-runs/{run_id}/03-blueprint.md", ...)` — 内容见 §文档模板库.T1。包含 Blueprint 全文 + 用户确认记录（是否调整、调整了什么）。

如果 architect 返回"不可行" → 仍然写文档，status: failed，记录失败原因，整个流程终止。

---

## Step 5：DBA（条件触发）

**仅当 Step 4 产出的 Blueprint 命中 DB 变更信号时执行**；否则跳到 Step 6。

### 5.1 触发判定

扫描 Blueprint 的 §2 架构影响和 §3 模块实现蓝图：

```
触发条件（任一命中）:
  - Blueprint §2 标注"数据库变更"非"无"
  - 描述含"新增表" / "新表" / "新增字段" / "add column" / "新列" / "索引"
  - 描述含现有表的字段类型 / 长度 / NULL 约束变更
```

**不命中** → 跳到 Step 6（contract-designer 使用 Blueprint §2 的 DDL 草稿作为 SQL 迁移依据）。

### 5.2 调用 DBA Agent

```
读取 .claude/agents/dba.md 的完整内容

Agent(
  subagent_type="general-purpose",
  description="DBA 深化设计: {需求标题}",
  prompt="""
<dba.md 内容>

## 输入
- Architect Blueprint: {03-blueprint.md 全文}
- 触发信号: {命中的具体信号}
- Step 3 NFR 摘要（重点关注**数据迁移 / 性能 / 兼容性 / 安全审计**四项，直接影响 DB 设计）：
  {从 02-breakdown.md 抽取 NFR 表中这四类的"有"行}

## 任务
按 dba.md 中 "设计思考顺序（7 步）" 完成数据库设计，严格按 "输出格式：DBA Design Doc" 的 9 节产出。
NFR 中的"数据迁移"决定回填策略；"性能"决定索引与分区；"兼容性"决定是否允许破坏性变更；"安全审计"决定是否加审计字段/表。
  """
)
```

### 5.3 处理产出

| DBA status | 行为 |
|---|---|
| `approved` | 继续 Step 6；contract-designer 使用 DBA §2 DDL 草稿（而非 Blueprint 占位符）|
| `needs_revision` | 展示 DBA 的质疑点给用户，让用户决定：修 Blueprint、接受 DBA 妥协、还是终止 |
| `no_change_needed` | 误触发（signal 命中但实际不需改 DB），跳 Step 6 |

### 5.4 📄 文档输出

`Write(".claude/mpdev-runs/{run_id}/04-dba-design.md", ...)` — DBA Design Doc 全文。

---

## Step 6：Contract-Designer

读取 `.claude/agents/contract-designer.md`。

注入：Blueprint §2（架构影响）+ §4（跨模块协作）。

```
Agent(
  subagent_type="general-purpose",
  description="契约更新: {需求摘要}",
  prompt="<contract-designer.md>\n\n## Blueprint §2+§4\n{...}"
)
```

产出的 `contract_changes` 包含两部分：
- Part 1: 文件级变更清单（sql/schemas/openapi/events）
- Part 2: 结构化字段摘要（new_fields / new_enum_values / api_changes）

**Part 2 是 impl agents 的直接输入。**

### 📄 文档输出

`Write(".claude/mpdev-runs/{run_id}/05-contract-changes.md", ...)` — 内容见 §文档模板库.T2。包含 Part 1 文件清单 + Part 2 结构化摘要 + 契约仓库 commit/branch 信息（如有）。

模式 A 如果未触发 contract-designer，写一个"skipped, 无契约变更"的占位文档。

---

## Step 7：测试架构师（test-architect）

contract-designer 完成后，**impl 启动前**调用 tester agent（模式 A），基于契约设计测试计划和测试用例规格。

### 7.1 前置检查

- `.claude/agents/tester.md` 存在 → 继续
- 不存在 → 提示："tester agent 未配置，请先运行 `/mpdev:init` 或 `/mpdev:test detect-flavor` 生成。或本次跳过测试设计（不推荐）。"

### 7.2 调用 tester agent

```
读取 .claude/agents/tester.md 完整内容

Agent(
  subagent_type="general-purpose",
  description="测试架构师: {需求标题}",
  prompt="""
<tester.md 内容>

## 任务: 模式 A（test-architect）

### 输入
- Blueprint:  {.claude/mpdev-runs/{run_id}/03-blueprint.md 全文}
- Contract:   {.claude/mpdev-runs/{run_id}/05-contract-changes.md 全文}
- 项目类型:    {tester.md frontmatter 中的 project_type}
- DBA 设计（如有）: {04-dba-design.md}

### 任务
按 ISTQB + IEEE 829 标准输出两份文档:
1. 06-test-plan.md   — 测试计划（含范围、级别、资源、准入准出）
2. 07-test-cases.md  — 测试用例规格（每条标注设计技术，至少用 3 种：等价类/边界值/决策表/状态机/场景/错误推测）

P0 用例必须设计完整（含输入、期望、后置条件）；P1 用例可标注 todo。
  """
)
```

### 7.3 处理产出

- `status: approved` → 继续 Step 8（impl）
- `status: needs_revision` → 展示 tester 提出的契约/Blueprint 问题（如"缺少 idempotency 字段"），让用户决定改契约还是带瑕疵继续

### 7.4 📄 文档输出

```
Write(.claude/mpdev-runs/{run_id}/06-test-plan.md, ...)
Write(.claude/mpdev-runs/{run_id}/07-test-cases.md, ...)
```

---

## Step 8：Impl Agents

### 依赖规则
```
contract-designer → 所有 impl（契约是前置依赖）
java-impl → vue-impl（vue 需要 java 的 api_changes_summary）
java / dispatch / analytics / algor → 互不依赖，并行
```

### Phase 1：并行启动（配置驱动）

读取 `.claude/agents/*-impl.md` 获取所有 impl agent 列表。
读取每个 agent 的 frontmatter `depends_on` 字段。

**depends_on 为空的 agent → Phase 1 并行启动。**

每个 agent 注入：
1. Blueprint §3.x（只给该模块段落，按模块名匹配）
2. **Blueprint S2.5 中归属本模块的资产行**（cross-check：S3.x 是改动清单，S2.5 是资产清单，两者交叉防漏）
   - 过滤规则：`S2.5 Matrix` 中 `归属模块 == 本模块名` 且 `是否变更 == 是` 的行
   - 注入位置：以表格形式追加到 §3.x 段后
   - 校验约束：impl agent 必须确保 S3.x 改动覆盖了 S2.5 本模块的所有"是"行；若发现 S2.5 列了但 S3.x 没展开 → fail_with_report 反推架构师补全（不允许沉默跳过）
3. Blueprint §5（风险缓解措施——impl 作为必做 checklist）
4. 契约变更摘要 Part 2
5. 对应模块 CLAUDE.md 相关段落
6. **Step 3 中 `involved_modules` 包含本模块的所有 F\* 的 AC**（从 00.5 抽取，让 impl 的自测用例直接对应 AC；T3 "覆盖场景"每条对应一条 AC）
7. **[仅 vue-impl] 视觉资产与规格**（当 VISUAL_ASSETS 非空时）：
   - Step 3 D 段完整内容（layout / components / colors / typography / spacing / radius / interactive_states）
   - 设计 Token（design_tokens）
   - 图片路径清单（agent 可自行 Read 图片二次核对）
   - **强制约束（必须以此内容开头注入）**：
     ```
     ⚠️ 本任务含视觉资产，你必须：
     1. 先通读视觉规格 + Read 至少一张图片做二次核对
     2. 产出"组件拆解清单"（新增/复用/改动文件），以 JSON 返回 status: "pending_breakdown_review"
     3. 立即停止，不要写任何代码
     4. 等主会话的下一条消息（内容为 "已确认，继续实现" 或具体调整要点），收到后再进入实现
     5. 实现阶段：颜色/字号/间距/圆角优先引用 design_tokens，禁止硬编码（除非 token 里没有该值，需在自测报告标注"新增未登记值"）
     ```

### Phase 1.5：组件拆解确认（仅当 vue-impl 启动且 VISUAL_ASSETS 非空时）

vue-impl 被要求**在写代码前先产出"组件拆解清单"并以 `status: pending_breakdown_review` 暂停返回**（不继续实现）。主会话编排器：

1. 收到 vue-impl 的拆解清单后**停止其他 impl agent 的等待**，立即呈现给用户：
   ```
   vue-impl 的组件拆解方案：
     - 新增组件：
       · FavoriteButton.vue        (圆形按钮，含填充/描边两态)
       · PriceBlock.vue            (划线价/折扣价/到手价三行)
     - 复用组件：
       · el-image（图片轮播）
       · el-button（加购）
     - 改动文件：
       · views/product/Detail.vue  (结构重组)
       · styles/tokens.scss        (新增 design_tokens)
   确认 / 调整（如"把 FavoriteButton 合并到 PriceBlock"）？
   ```
2. 用户确认 → 向 vue-impl 发"已确认，继续实现"消息（同一 Agent 会话续跑）
3. 用户调整 → 汇总修改要点再派回 vue-impl
4. **含糊回复** → 重申选项再等（同 1.5.4 的含糊处理）

此阶段**不影响其他 impl agent 并行**（java/dispatch/algor 正常跑完），只是 vue 的完成时间延后到用户确认后。

```
# 同一消息中发出多个 Agent 调用实现并行
# 具体 agent 列表从 .claude/agents/*-impl.md 动态读取
Agent({impl_a}, ...)
Agent({impl_b}, ...)
Agent({impl_c}, ...)
```

### Phase 2：串行启动（依赖驱动）

Phase 1 全部返回后，启动 `depends_on` 非空的 agent：
- 检查依赖的 agent 是否成功
  - 成功 → 提取其产出（如 `api_changes_summary`）→ 注入并启动
  - 失败 → **跳过**，标注"因 {dependency} 失败而阻塞"

### 失败处理
```
pass / verified_no_change → 正常继续
fail_with_report →
  1. 该 impl 不重试（内部已自修复 3 轮）
  2. 下游依赖标注"阻塞"并跳过
  3. 其他无依赖 impl 继续
  4. 汇总时明确标注失败模块
```

### 📄 文档输出（每个 impl 一份）

所有 impl 返回后（无论成功失败），**每个 impl 产出一份独立文档**：

```
对每个 impl agent:
  Write(".claude/mpdev-runs/{run_id}/08-impl-{module}.md", ...)
  — 内容见 §文档模板库.T3
```

文档包含：
- agent 的 status（pass / fail_with_report / verified_no_change / blocked）
- 变更文件列表 + 新增/修改行数统计
- 自测结果（测试命令 + pass/fail + 覆盖场景）
- 自修复循环记录（每轮发现的问题 + 修复方案）
- api_changes_summary / mq_publish_changes（供下游 agent 使用）

**这一步是用户最关心的——开发自测结果都在这份文档里。**

---

## Step 9：测试执行（test-executor）

各 impl agent 全部完成后，**code-review 之前**调用 tester agent（模式 B），生成自动化测试代码、执行测试、登记缺陷。

### 9.1 前置检查

- `07-test-cases.md` 存在 → 继续
- 不存在（Step 7 跳过）→ 警告并询问：[基于代码现状自动设计简化用例 / 仅跑现有测试 / 跳过 Step 9]

### 9.2 调用 tester agent

```
Agent(
  subagent_type="general-purpose",
  description="测试执行: {需求标题}",
  prompt="""
<tester.md 内容>

## 任务: 模式 B（test-executor）

### 输入
- 测试用例: {07-test-cases.md 全文}
- 各模块实现产出: {08-impl-{module}.md 列表 + 变更文件清单}

### 任务
1. 为 P0 / P1 用例生成自动化测试代码（按 flavor AUTOMATION_STACK 选用工具）
   测试代码放到 test/ / tests/ / src/test/，注释 TC-ID 便于追溯
2. 执行测试套件（mvn test / pytest / npm test）
3. 失败用例 → 登记缺陷到 10-test-incidents.md，分配 BUG-ID（递增）
4. 输出测试日志到 09-test-log.md（含覆盖率、缺陷数）
  """
)
```

### 9.3 处理产出

- 全部通过（无 P0/P1 fail）→ 继续 Step 10
- 有 P0 缺陷 → 警告并询问：[阻断流程修缺陷 / 标记风险继续到 review]
- 有 P1+ 缺陷 → 在 review/integration 阶段一并展示

### 9.4 📄 文档输出

```
Write(.claude/mpdev-runs/{run_id}/09-test-log.md, ...)
Write(.claude/mpdev-runs/{run_id}/10-test-incidents.md, ...) (如有缺陷)
新增/修改的测试代码文件（在各模块的 test/ 目录下）
```

---

## Step 10：Code Review + Integration Check（并行）

所有 impl 完成后，**并行**启动两个审查 agent。

### 5.1 code-reviewer

读取 `.claude/agents/code-reviewer.md`。注入：
1. Blueprint 全文
2. 所有 impl 变更文件列表（含完整路径）
3. 各模块编码规范段落
4. **[Vue 模块有 VISUAL_ASSETS 时] 设计 Token 清单**：要求审查变更文件中的颜色/字号/间距/圆角是否**引用 design_tokens / CSS 变量**而非硬编码字面量。硬编码值且 token 中有对应定义的 → 标记 🟡 Important 要求改引用；token 中确实无值（新 token）→ 标记 🟢 Suggestion 建议补登记

### 5.2 integration-checker

读取 `.claude/agents/integration-checker.md`。注入：
1. Blueprint §4（正确答案参照）
2. 所有 impl 产出摘要（changes + mq_publish_changes + api_changes_summary）

### 5.3 合并处理

```
code-reviewer        | integration-checker | 处理
---------------------|---------------------|------
approve              | pass                | → Step 11
approve              | warn                | 呈现 warn → 用户确认 → Step 11
approve              | fail                | → 修复循环(integration)
request_changes      | pass                | → 修复循环(review critical)
request_changes      | warn                | → 修复循环(合并 review critical + integration warn)
request_changes      | fail                | → 修复循环(合并两方)
comment_only         | pass                | 呈现 comments → Step 11
comment_only         | warn                | 呈现 comments+warn → 用户确认 → Step 11
comment_only         | fail                | → 修复循环(integration)，comments 附汇总
```

### 修复循环

合并 findings 按 module 分组，分派 impl agent：
```
你之前的实现需修复以下问题：
[Code Review — 必修] CR-001: {title} — {fix_suggestion}
[Integration — 必修] IC-001: {issue} — {fix_suggestion}
请逐项修复，不改其他文件。修复后重跑测试。
```

修复后**并行重跑**对应检查（只审修复文件，不全量重跑）。
最多 2 轮修复循环，超限残留 warn 呈现给用户。

### 📄 文档输出（两份）

Step 10 产出两份独立文档：

```
Write(".claude/mpdev-runs/{run_id}/11-code-review.md", ...)       — 见 §文档模板库.T4a
Write(".claude/mpdev-runs/{run_id}/12-integration-check.md", ...) — 见 §文档模板库.T4b
```

每份文档包含：
- 最终结论 + 各轮修复循环的演进记录
- 按模块分类的 finding 列表（严重度 + 修复建议 + 是否已修复）
- 跳过 / 失败情况也要记录

---

## Step 11：Acceptance Review

Step 10 通过后（含修复循环），启动最终验收。

读取 `.claude/agents/acceptance-reviewer.md`。注入：
1. **Step 3 需求识别清单**（功能点 F1..Fn 含 AC + NFR 表）——作为需求覆盖表的**基础清单**
2. **用户原始需求**（一字不改：$ARGUMENTS）——作为交叉核对参考，防止识别遗漏
3. Blueprint 全文
   - **3.1 Blueprint S2.5 Asset Matrix**（架构师产物，PRD §1 变更点 → 资产路径逐行映射）——验收追踪表必须以此为底
   - **3.2 Blueprint S6 AC↔Asset 预映射**（架构师产物，每条 AC → Matrix 行）——用于核对实现产物是否覆盖
   - **缺失 S2.5 / S6 时**：acceptance-reviewer 必须拒绝验收并反推 architect 补齐，**不允许自行推断**
4. 所有 impl 变更摘要（含完整文件路径 + 资产 diff 列表，供 grep/read 验证）
5. code-reviewer + integration-checker 最终结果
6. **[有 VISUAL_ASSETS 时] 视觉规格 + 设计 Token + 原始图片路径清单**——用于视觉对比

**视觉对比流程**（仅 VISUAL_ASSETS 非空时执行）：

0. **先探测可用截图工具**：
   ```bash
   # 检测环境中是否存在可自动截图的 MCP / 工具
   available=""
   claude mcp list 2>/dev/null | grep -iE "playwright|chrome|preview" && available="$available mcp"
   command -v playwright >/dev/null && available="$available playwright"
   command -v puppeteer >/dev/null && available="$available puppeteer"
   echo "可用截图工具：${available:-无}"
   ```

1. **根据探测结果呈现选项**：
   ```
   请提供实现后的运行时截图（用于视觉验收）：
   {若 available 非空}
     a) 由我自动截图（检测到：mcp__Claude_in_Chrome / playwright / ...）
         → 需告诉我：前端已启动的 URL（如 http://localhost:5173/product/123）+ 视口尺寸（默认 1440×900 desktop + 375×812 mobile）
   {始终提供}
     b) 手动截图后给我路径（如 ./screenshots/actual-desktop.png, actual-mobile.png）
     c) 跳过视觉对比——仅做功能验收
   ```

   如果 `available` 为空，只呈现 b / c 两项。

2. **逐图对比**（用户提供截图后，主会话多模态同时读**设计稿 + 实现截图**）：
   - 布局一致性（栅格/区域划分）
   - 组件一致性（位置/尺寸/变体）
   - 配色一致性（主色/强调色，取色对比）
   - 字号/间距一致性（估算偏差 ≤ 2px 视为通过）
   - 交互状态（若设计稿含 hover/active，要求用户也提供相应状态截图）

3. **产出视觉相似度评估**：
   ```
   | 维度 | 评估 | 偏差说明 |
   |------|------|---------|
   | 布局 | ✅ 一致 | — |
   | 主色 | ✅ 一致 | 设计 #1890ff vs 实现 #1890ff |
   | 按钮圆角 | ⚠️ 偏差 | 设计 8px vs 实现 4px |
   | 表格行高 | ❌ 不一致 | 设计 48px vs 实现 32px |
   ```

4. **视觉偏差处理**：
   - ❌ 严重不一致（布局错位 / 主色错误 / 核心组件缺失）→ 回 vue-impl 修复
   - ⚠️ 轻微偏差（≤5 个像素级问题）→ 列入验收条件或 TODO，不阻塞 accept
   - **明确告知用户：Claude 的视觉评估是语义级的近似还原，不是像素完全一致**

### 处理结果
```
accept             → Step 13
conditional_accept → 呈现条件 → 用户说"修"→ 分派修复 → 重跑 acceptance / 用户说"接受"→ Step 13
reject             → 呈现缺失项 → 轻度: 分派补充 / 重度: 回 architect
```

**严格门槛（防止"P0 缺失被 conditional 兜底"）**：
- 任何 **P0 AC = Missed / Partial** → 不允许 conditional_accept，**强制 reject**
- 任何 **P0 AC = Untested 且非环境硬约束**（环境硬约束限定：实机性能 / 真实硬件 / 业务方提供物）→ 反推至 tester 补证据，暂判 reject
- conditional_accept 仅允许：P1/P2 边界缺陷 + 环境硬约束 Untested + 真·外部依赖
- **FU 任务类别黑名单**（acceptance-reviewer 输出的 `follow_up_tasks` 若包含 `category ∈ {source, sql, template, dict, iac}` → 自动转为 reject，要求回 implementer 完成研发产物）

最多 1 轮验收修复。第 2 次仍 reject → 交给用户人工判断。

### 📄 文档输出

`Write(".claude/mpdev-runs/{run_id}/13-acceptance.md", ...)` — 内容见 §文档模板库.T5。

包含：
- 需求覆盖清单（逐项 ☑/☐ + 证据位置）
- 场景完整性评估
- 风险闭环检查（Blueprint §5 的每项风险是否已缓解）
- 最终结论：accept / conditional_accept / reject + 理由
- 验收修复循环记录（如有）

---

## Step 12：测试总结报告（test-reporter）

acceptance-reviewer 完成后、**Step 13 汇总前**调用 tester agent（模式 C），生成测试总结报告。

### 12.1 调用 tester agent

```
Agent(
  subagent_type="general-purpose",
  description="测试总结: {需求标题}",
  prompt="""
<tester.md 内容>

## 任务: 模式 C（test-reporter）

### 输入
- 测试日志:   {09-test-log.md}
- 缺陷登记:   {10-test-incidents.md}
- 代码审查:   {11-code-review.md}
- 集成校验:   {12-integration-check.md}
- 验收审查:   {13-acceptance.md}

### 任务
按 IEEE 829 测试总结报告模板输出 14-test-summary.md，必含:
- 总用例数 / 通过率 / 阻塞数
- 缺陷分布（按模块、严重度）
- 覆盖率（行 / 分支 / 需求）
- 关键发现 / 风险评估
- **准出建议**：建议上线 / 暂缓 / 阻断（附依据）
  """
)
```

### 12.2 处理产出

- 准出建议=建议上线 → 进 Step 13 汇总
- 准出建议=暂缓/阻断 → 警告用户并展示 Top 3 阻断项；用户决定继续或终止

### 12.3 📄 文档输出

```
Write(.claude/mpdev-runs/{run_id}/14-test-summary.md, ...)
```

---

## Step 12.5：文档增量刷新（doc-refresher）

test-reporter 完成后、Step 13 汇总前调用 doc-refresher agent，把本次引入的"机械可推导"接口/字段/文件变更增量同步到各模块 CLAUDE.md 和 `robot-contracts/CLAUDE.md` 的表总表。**无暂停点、低风险（只追加）、失败不阻塞 Step 13**。

### 12.5.1 触发判定

任一命中 → 跳过 Step 12.5（直接进 Step 13）：

- 模式 == C（探索，不改代码）
- 所有 impl 状态都是 `verified_no_change` / `skipped` / `blocked`（说明本次没产生需要同步的变更）
- `Glob("**/CLAUDE.md")` 排除 `.claude/ node_modules/ .git/ target/ dist/` 后返回空（项目还没跑过 `/mpdev:understand`）
- `.claude/agents/doc-refresher.md` 不存在（v1.0.0 项目升级到 v1.1.0 但未重跑 `/mpdev:init`）→ 跳过并在 99-summary.md 提示"建议重跑 `/mpdev:init` 让 Step 10 落地 doc-refresher.md，下次 `/mpdev:dev` 即可启用 Step 12.5 文档增量刷新"

否则继续 12.5.2。

### 12.5.2 聚合输入

主编排器从已有产出聚合（不引入新读取，全部来自 `.claude/mpdev-runs/{run_id}/`）：

```yaml
involved_modules: [...]              # 来自 02-breakdown.md "涉及模块"

impl_outputs:                        # 来自 08-impl-{module}.md × N
  - module: java
    status: pass
    changed_files: [{path, type, lines_added}]   # 抓 "## 变更文件" 表
    api_changes_summary: [...]                   # 抓 "## 产出供下游的摘要" yaml
    mq_publish_changes: [...]
    new_db_fields: [...]
  ...

contract_changes:                    # 来自 05-contract-changes.md
  files: { sql:[...], schemas:[...], openapi:[...], events:[...] }
  new_fields: [...]
  new_enum_values: [...]
  api_changes: [...]

existing_claude_md_paths:            # Glob 一次取全部
  - {module}/CLAUDE.md × N
  - robot-contracts/CLAUDE.md       # 若存在则纳入

run_id: {run_id}                     # 用于 TODO 行前缀
```

如果 `05-contract-changes.md` status 为 `skipped`（模式 A 简单需求未触发 contract-designer），`contract_changes` 各字段输出空列表。

### 12.5.3 调用 doc-refresher agent

```
读取 .claude/agents/doc-refresher.md 完整内容

Agent(
  subagent_type="general-purpose",
  description="文档增量刷新: {需求标题}",
  prompt="""
<doc-refresher.md 内容>

## 输入
{聚合后的 yaml，见 12.5.2}

## 任务
按 doc-refresher.md 中"工作步骤"完成增量刷新，严格按"输出格式"返回 refresh_report。
  """
)
```

### 12.5.4 处理产出

| status | 行为 |
|---|---|
| `success` | 继续 Step 13；refresh_report 摘要塞进 99-summary.md "文档刷新" 段 |
| `partial` | 同上；99-summary.md 中标注"X 个段落跳过+TODO，建议日后跑 `/mpdev:understand only={modules} force` 全量刷新" |
| `failed` | 不阻塞 Step 13；99-summary.md 标 "文档未刷新（{原因}）"，warn 呈现给用户 |
| `skipped` | 主编排器在触发判定阶段已拦截，本路径理论上不进入 |

**用户不被打断** — 本步骤无暂停点。事后用户可：
- 看 `15-doc-refresh.md` 详情
- `git diff` 审查具体改动（若是 git 仓库）
- `git checkout {file}` 撤回单文件
- 发现 TODO 需要补 → `/mpdev:understand only={module} force` 全量刷新该模块

### 12.5.5 📄 文档输出

`Write(".claude/mpdev-runs/{run_id}/15-doc-refresh.md", ...)` — 内容见 §文档模板库.T7。

包含：
- 触发判定摘要
- refresh_report 全文（已刷新 / 跳过+TODO / 未触碰 / 错误）
- 每个被刷新文件的 git diff 摘要（用 `Bash("git diff -- {file}")` 抓；若非 git 仓库则在文档中标注"非 git 仓库，跳过 diff 抓取"）
- 后续建议

---

## Step 13：汇总报告

```markdown
## ✅ MPDev 完成: {需求标题}

**模式**: {A/B/C} | **验收**: {accept/conditional/reject}

### 变更统计
| 模块 | 文件数 | 新增行 | 修改行 | 测试 |
|------|--------|--------|--------|------|
| ... | ... | ... | ... | ... |

### 代码审查
- Blueprint 遵循度: {high/medium/low}
- 🔴 Critical: N | 🟡 Important: N | 🟢 Suggestion: N

### 集成校验
- L1 契约一致性: ✅/❌ | L2 模拟联调: ✅/⚠️ | L3 构建验证: ✅/❌

### 验收审查
- 需求覆盖: {N}/{N} | 场景完整性: {N}项建议 | 风险闭环: {N}/{N}

### 视觉对比（仅 VISUAL_ASSETS 非空时）
- 设计稿页数: {N} | 运行时截图: {N}（自动/手动/跳过）
- 一致性: {X} 维度 ✅ / {Y} 维度 ⚠️ 轻微偏差 / {Z} 维度 ❌ 严重偏差
- design_tokens 引用合规: {K}/{K}（code-reviewer 统计）

### 文档刷新（Step 12.5）
- ✅ 已刷新: {N} 个文件 / {M} 个段落
- ⚠️ 跳过+TODO: {K} 个段落（需要语义改写，详见 15-doc-refresh.md）
- 未触碰: DATAFLOW.md, EVENT_CATALOG.md（设计上不动）

### 未修复项（如有）
{残留的 warn / conditional 条件 / 建议手动处理的项}
```

### 📄 文档输出（两处写入）

**A. 运行目录的最终汇总文档**

`Write(".claude/mpdev-runs/{run_id}/99-summary.md", ...)` — 内容见 §文档模板库.T6。

包含：
- 运行结论 + 各阶段时间线 + 总耗时
- 变更统计（与会话内汇总一致）
- **测试结论**：用例总数 / 通过率 / 缺陷分布 / 行覆盖率 / 准出建议（来自 `14-test-summary.md`）
- 各阶段文档的相对链接（便于跳转阅读）：
  - 设计阶段：`01-requirement.md` / `03-blueprint.md` / `04-dba-design.md`（如有）/ `05-contract-changes.md`
  - 测试阶段：`06-test-plan.md` / `07-test-cases.md` / `09-test-log.md` / `10-test-incidents.md`（如有）/ `14-test-summary.md`
  - 实现阶段：`08-impl-{module}.md` × N
  - 质量阶段：`11-code-review.md` / `12-integration-check.md` / `13-acceptance.md`
  - 文档阶段：`15-doc-refresh.md`（如有）
- 未修复项清单（含测试发现的未修复缺陷 BUG-ID）

**B. 更新 INDEX.md**

`Read + Edit` 修改 `.claude/mpdev-runs/INDEX.md`，在"运行记录"表格顶部追加一行：

```markdown
| {timestamp} | {run_id} | {需求摘要 ≤40字} | {A/B/C} | ✅ accept / ⚠️ conditional / ❌ reject / 🔴 failed | [详情](./{run_id}/) |
```

---

## 模式 C 特殊流程

探索模式不改代码：
1. 不启动 contract-designer / impl / review / integration / acceptance / doc-refresher
2. architect 指明"仅分析，不输出实现蓝图"
3. 可并行多个 Explore agent 调查不同模块
4. 汇总为调查报告

### 📄 文档输出（模式 C）

写三份：
- `01-requirement.md`（标明模式 C）
- `02-breakdown.md`（轻量版：只列"探索目标"和"关注点"，**无 AC / NFR / 涉及模块**；status 标 `success`，在文档头 `phase: requirement-breakdown-lite`）
- `99-summary.md`（内容即调查报告：探索目标 + 发现 + 证据引用 + 结论/建议）

---

## 文档模板库

所有 Write 调用按以下模板渲染 markdown。模板中的 `{变量}` 由编排器在运行时替换。所有文档开头统一带 YAML frontmatter（见 Step 0.3）。

### T0 — 需求文档 (`01-requirement.md`)

```markdown
---
run_id: {run_id}
step: 1
phase: requirement
status: success
generated_at: {timestamp}
---

# 需求：{一句话标题}

## 模式
{A / B / C} — {一句话判断理由}

## 原始需求（用户输入）
> {$ARGUMENTS 原文，一字不改}

## 涉及模块（粗判）
仅由模式识别关键词推断，**权威清单见 Step 3 的 00.5 文档**。
- {module_1}
- {module_2}
- ...

## 上下文提取
从各模块 CLAUDE.md 匹配到的关键段落清单：
| 模块 | 段落标题 | 匹配关键词 | 行范围 |
|------|---------|-----------|--------|
| ... | ... | ... | ... |
```

### T0.5 — 需求精细识别 (`02-breakdown.md`)

```markdown
---
run_id: {run_id}
step: 1.5
phase: requirement-breakdown
status: {success / failed}
generated_at: {timestamp}
---

# 需求精细识别

## 输入来源
{三选一，据实填写}
- 类型：单文件 / 目录 / 粘贴文本
- 路径清单（如有）：
  - `{路径 1}`
  - `{路径 2}`
- 归一化后文本长度：{N 行 / M 字符}

## 功能点清单

### F1: {标题}
- **描述**：{2-3 句，引用原文 + 必要补充}
- **用户故事**：作为 {角色}，我希望 {动作}，以便 {价值}
- **验收条件（AC）**：
  - Given {前提} When {动作} Then {结果}
  - Given {...} When {...} Then {...}
- **涉及模块**：[java, vue]
- **优先级**：P0

### F2: ...
{同上结构}

## 非功能项（NFR）

| 类别 | 有/无 | 细节 |
|------|------|------|
| 性能 | 有 | "峰值 100 QPS，P99 <500ms"（原文节选）|
| 权限 | 有 | 新增 `task:night_patrol:manage` 权限点 |
| 埋点 | 无 | — |
| 兼容性 | 有 | 老任务记录需保持可查 |
| 监控告警 | 无 | — |
| 数据迁移 | 有 | tasks 表加枚举值，无需回填 |
| 错误处理 | 有 | 失败降级为常规巡检 |
| 安全 | 无 | — |

## 涉及模块汇总

| 模块 | 为什么涉及 |
|------|-----------|
| java | F1 F3 需新增 Controller 和字段 |
| vue | F1 F2 需新增页面表单项 |
| dispatch | F3 需扩展任务调度器识别 task_type |

## 视觉资产（仅含设计稿/图片时填；否则写"无"）

### 资产清单
| type | path | purpose | status |
|------|------|---------|--------|
| image | ./design/product-detail.png | 商品详情页 | ok |
| image | ./design/states.png | 组件状态图（hover/disabled）| ok |
| figma-url | https://www.figma.com/file/abc | 完整设计源 | pending-fetch |

### 视觉规格（按页展开）

#### 页面 1：商品详情页（./design/product-detail.png）
- **布局**：12 栅格 主内容 8 + 侧栏 4；顶部 60px 导航栏
- **组件**：
  - 图片轮播（左 8 格，宽 480px，高 360px）
  - 标题 H1 字号 24 粗体，SKU 小字 12
  - 价格主色 #ff4d4f，划线价 #8c8c8c
  - 加入购物车按钮 primary，宽 120，高 40，圆角 6
- **配色**：primary #1890ff / danger #ff4d4f / text-primary #262626 / text-secondary #8c8c8c / border #d9d9d9
- **字号阶梯**：12 / 14 / 16 / 20 / 24
- **间距基数**：8px
- **圆角**：卡片 8 / 按钮 6 / 输入框 4
- **交互状态**：设计稿未画 hover，按惯例实现
- **响应式**：仅 desktop 稿，<768px 降级按惯例

#### 页面 2：状态图（./design/states.png）
...

### 设计 Token（跨页聚合，出现 ≥2 次的值）
```yaml
design_tokens:
  colors:
    $primary: "#1890ff"
    $danger: "#ff4d4f"
    $text-primary: "#262626"
    $text-secondary: "#8c8c8c"
    $border: "#d9d9d9"
  typography:
    font-sizes: [12, 14, 16, 20, 24]
  spacing:
    base-unit: 8
  radius:
    $radius-card: 8
    $radius-button: 6
    $radius-input: 4
```

## 反问-澄清记录

### Round 1
- **Q1 [字段语义不明]**：`silent` 字段是 bool 还是枚举？
  - 用户答：bool，true = 不响铃，通知推送照常
- **Q2 [缺验收标准]**：F3 完成判定草案"机器人开始巡检路径"是否接受？
  - 用户答：接受，补充"且上报一次位置"

### Round 2
- **Q3 [跨模块归属不清]**：告警去重放 analytics 还是 java？
  - 用户答：analytics，复用现有去重逻辑

## 用户最终确认

- 确认时间：{timestamp}
- 回复原文：> {"确认" / "改 F2 为 P1，其余OK" 之类}
- 最终调整项：
  - {列出用户在确认环节要求的最终改动}
```

### T1 — 架构蓝图 (`03-blueprint.md`)

```markdown
---
run_id: {run_id}
step: 2
phase: architect
status: {success / failed}
agent: architect
generated_at: {timestamp}
---

# 架构蓝图

## §1 可行性结论
{feasible / feasible_with_risks / infeasible + 理由}

## §2 架构影响
{哪些模块要改、怎么改、依赖关系}

## §3 各模块实现蓝图
### Java
{具体到哪些 Controller / Service / Entity}
### Dispatch
...
### Analytics
...
### Vue
...
### Algor
...

## §4 跨模块协作
{MQ 字段 / HTTP 接口 / WebSocket / DB 新增列的完整规格}

## §5 风险与缓解
**必须覆盖** Step 3 NFR 中标注"有"的每一项（性能 / 权限 / 兼容性 / 监控告警 / 数据迁移 / 错误处理 / 安全），每项至少一行缓解措施。功能风险可另行补充。

**当 Step 3 D 段视觉规格存在时（VISUAL_ASSETS 非空），必须额外加一行**：
```
| 视觉一致性偏差 | 视觉规格 | 中 | Claude 是语义级还原（非像素比对）；实现完由 Acceptance 的视觉对比做 desktop/mobile 截图核验；严重偏差打回 vue-impl，轻微偏差列 TODO |
```

| 风险 | 来源 | 严重度 | 缓解措施 |
|------|------|--------|---------|
| 峰值 100 QPS 下 P99 超 500ms | NFR-性能 | 高 | 增加缓存 / 压测验证 |
| 老任务记录兼容 | NFR-兼容性 | 中 | 读侧兼容枚举缺失 |
| 视觉一致性偏差（如有 VISUAL_ASSETS）| 视觉规格 | 中 | 见上条说明 |
| ... | ... | ... | ... |

## §6 工作量估计
{按模块给出 S/M/L 或小时数}

---

## 用户确认记录
- 确认时间：{timestamp}
- 用户反馈：{原样摘录，例如"不改算法，降速改 0.3"}
- 调整项：{列出用户要求的调整点}
```

### T2 — 契约变更 (`05-contract-changes.md`)

```markdown
---
run_id: {run_id}
step: 3
phase: contract
status: {success / skipped / failed}
agent: contract-designer
generated_at: {timestamp}
---

# 契约变更

## Part 1：文件级变更清单
| 文件路径 | 变更类型 | 摘要 |
|---------|---------|------|
| schemas/xxx.json | 新增字段 | 在 AlarmData 添加 silent 字段 |
| sql/V20260417__add_night_patrol.sql | 新增迁移 | tasks 表加 task_type 枚举值 |
| openapi/task.yaml | 修改 | /api/task/create 请求体新增 task_type |

## Part 2：结构化摘要（供 impl agents 消费）

```yaml
new_fields:
  - queue: alarm_data_queue
    field: silent
    type: boolean
    default: false

new_enum_values:
  - enum: task_type
    values: [night_patrol]

api_changes:
  - path: /api/task/create
    method: POST
    change: "请求体新增 task_type 字段"
```

## 契约仓库关联
- 仓库：robot-contracts
- 分支/Commit：{branch or sha}
- 验证脚本：{是否通过 schemas 校验}
```

### T3 — 模块实现报告 (`08-impl-{module}.md`)

**这是用户最关心的文档——开发自测结果就在这里。**

```markdown
---
run_id: {run_id}
step: 4
phase: impl
module: {module_name}
status: {pass / fail_with_report / verified_no_change / blocked}
agent: {module}-impl
generated_at: {timestamp}
---

# {模块} 实现报告

## 结论
{pass → 实现完成，测试通过}
{fail_with_report → 失败原因摘要}
{verified_no_change → 验证后确认无需改动}
{blocked → 因 {dependency} 失败而跳过}

## 变更文件
| 路径 | 类型 | 新增行 | 修改行 | 说明 |
|------|------|--------|--------|------|
| {path} | new/modified | N | M | {一句话说明} |

**总计**：新增 N 行 / 修改 M 行 / 新建文件 K 个

## 自测结果
- 测试命令：`{测试命令}`
- 结果：{pass / fail / no_test}
- 覆盖场景：
  - [x] {场景 1}
  - [x] {场景 2}
  - [ ] {未覆盖的场景，附原因}

## 自修复循环（如有）
### Round 1
- 发现问题：{描述}
- 修复方案：{描述}
- 结果：{pass / 进入 Round 2}
### Round 2
...

## 产出供下游的摘要

```yaml
# 供 vue-impl / code-reviewer / integration-checker 使用
api_changes_summary: {...}  # Java 才有
mq_publish_changes: {...}    # Dispatch/Analytics 才有
variable_usage_check: {...}  # Vue 才有
```

## 风险缓解措施落实
{从 Blueprint §5 复制的 checklist，逐项勾选是否完成}
```

### T4a — 代码审查报告 (`11-code-review.md`)

```markdown
---
run_id: {run_id}
step: 5
phase: code-review
status: {approve / request_changes / comment_only / skipped}
agent: code-reviewer
generated_at: {timestamp}
---

# 代码审查报告

## 结论
{approve / request_changes / comment_only}

Blueprint 遵循度：{high / medium / low}

**发现分布**：🔴 Critical: N | 🟡 Important: N | 🟢 Suggestion: N

## 按模块的发现

### Java
| ID | 严重度 | 文件:行 | 问题 | 建议 | 修复状态 |
|----|--------|--------|------|------|---------|
| CR-001 | 🔴 | TaskService.java:127 | ... | ... | ✅ 已修复 |

### Dispatch
...

## 修复循环
- **Round 1**：发现 N 个问题 → 分派 → 修复 M 个，剩 {N-M} 个进入下一轮
- **Round 2**：剩余 {N-M} 个 → 修复 K 个，剩 {N-M-K} 个残留 warn（已呈现给用户）
```

### T4b — 集成校验报告 (`12-integration-check.md`)

```markdown
---
run_id: {run_id}
step: 5
phase: integration-check
status: {pass / warn / fail / skipped}
agent: integration-checker
generated_at: {timestamp}
---

# 集成校验报告

## L1 契约一致性
- 检查项 N 条 | ✅ N-k | ⚠️/❌ k

{如有不一致，逐条列出}

## L2 模拟联调
{模拟生产者发消息 → 消费者解析，检查字段是否对齐}

## L3 构建验证
- Java: `mvn compile` → {pass/fail}
- Dispatch: `python -m py_compile` → ...
- Vue: `npm run build` → ...
```

### T5 — 验收审查 (`13-acceptance.md`)

```markdown
---
run_id: {run_id}
step: 6
phase: acceptance
status: {accept / conditional_accept / reject / skipped}
agent: acceptance-reviewer
generated_at: {timestamp}
---

# 验收审查

## 结论
{accept / conditional_accept / reject}

## 上游产物完整性校验
| 产物 | 状态 |
|------|------|
| acceptance_criteria | present / missing |
| Blueprint S2.5 Asset Matrix | present / missing |
| Blueprint S6 AC↔Asset 预映射 | present / missing |

任一 missing → **拒绝验收，反推 architect 补齐**。

## 需求覆盖
基于 Step 3 识别清单（F1..Fn + NFR）逐项核对：

| 需求点 | 来源 | 状态 | 实现位置 |
|--------|------|------|---------|
| F1: {功能点标题} | 1.5 清单 | ☑ 已实现 | TaskService.java:127 |
| F2: {...} | 1.5 清单 | ☐ 未实现 | — |
| NFR-性能: {...} | 1.5 清单 | ☑ 已实现 | {验证方式} |
| {原文新发现的点} | $ARGUMENTS 回溯 | ⚠️ 1.5 未识别 | — |

## AC↔产物强追踪表（核心，每条 AC 必填）

| AC | 优先级 | S2.5 Matrix 行 | 预期产物 | 实际产物（文件 / commit / 资产 diff） | 测试证据 | 用户可感知? | 状态 | 阻塞发布? |
|----|------|---------------|---------|------------------------------------|---------|-----------|------|----------|
| AC-001 | P0 | PRD §X.Y | code | src/...:42 | test/...:pass | ✅ | Met | 否 |
| AC-XXX | P0 | PRD §X.Y | asset | sys_rpt_file:tpl.ureport.xml diff | manual screenshot | ❌ | **Missed** | **是** |

**判定流程**（防语义滑坡）：
1. 无产物 + P0 → **Missed**（不论后端是否就绪）
2. 用户/运维实际看不到 → **Missed**（不是 Partial）
3. 依赖前置 AC 未达成 → **Missed**（不是 Untested）
4. 测试设计有用例但执行被"无变更跳过" → **Missed**，必须补反向验证证据
5. 仅生产环境性能 / 业务方提供物缺失 → Untested（环境硬约束才允许）

## 场景完整性
{异常路径、边界条件、并发场景等建议}

## 风险闭环
Blueprint §5 的每项风险：
- ☑ 风险 1 → 已通过 {方式} 缓解
- ☐ 风险 2 → 未处理（原因）

## 验收条件（如 conditional_accept）
- {条件 1}
- {条件 2}

## 验收修复循环（如有）
...
```

### T6 — 运行汇总 (`99-summary.md`)

```markdown
---
run_id: {run_id}
step: 7
phase: summary
status: {success / partial_success / failed}
generated_at: {timestamp}
---

# MPDev 运行汇总：{需求标题}

**结论**：{✅ accept / ⚠️ conditional / ❌ reject / 🔴 failed}
**模式**：{A / B / C}
**总耗时**：{N} 分钟

## 时间线
| 时间 | 阶段 | 结果 |
|------|------|------|
| 00:00 | 触发 | — |
| 00:01 | 输入归一化 + 模式识别 | ✅ 模式 B（含 {N} 张设计稿） |
| 00:03 | 需求精细识别（含视觉规格） | ✅ 用户确认 |
| 00:05 | Blueprint | ✅ 用户确认 |
| 00:08 | 契约更新 | ✅ |
| 00:12 | vue-impl 组件拆解 | ✅ 用户确认（仅 VISUAL_ASSETS 非空时）|
| 00:18 | Impl 完成 | ✅ 5/5 |
| 00:20 | 审查+联测 | ✅ |
| 00:23 | 验收（含视觉对比） | ✅ accept / ⚠️ 轻微视觉偏差列 TODO |
| 00:25 | 文档增量刷新 | ✅ {N} 文件 / ⚠️ {K} 段落落 TODO |

## 变更统计
| 模块 | 文件数 | 新增行 | 修改行 | 测试 |
|------|--------|--------|--------|------|
| ... | ... | ... | ... | ... |

## 文档刷新（Step 12.5）
- ✅ 已刷新: {N} 个文件 / {M} 个段落
- ⚠️ 跳过+TODO: {K} 个段落
- 详情: [15-doc-refresh.md](./15-doc-refresh.md)

## 关联文档
- [需求](./01-requirement.md)
- [需求精细识别](./02-breakdown.md)
- [架构蓝图](./03-blueprint.md)
- [契约变更](./05-contract-changes.md)
- [Java 实现](./08-impl-java.md)
- [Dispatch 实现](./08-impl-dispatch.md)
- [Analytics 实现](./08-impl-analytics.md)
- [Vue 实现](./08-impl-vue.md)
- [算法实现](./08-impl-algor.md)
- [代码审查](./11-code-review.md)
- [集成校验](./12-integration-check.md)
- [验收审查](./13-acceptance.md)
- [文档刷新](./15-doc-refresh.md)（如有）

## 未解决项（严格遵守 FU 任务类别清单）

| # | 项 | category | 阻塞 AC | 负责 | 指南 |
|---|----|----------|---------|------|------|

**FU 任务类别白名单**（允许的 follow-up 类别）：
- `env` — 环境配置、生产部署 checklist
- `model` — 业务方提供的算法模型 / 训练数据
- `external` — 跨团队对齐（多机同步白名单、安全审计、订阅人列表）
- `hw_perf` — 实机性能基准（必须真实硬件场景）

**FU 任务类别黑名单**（禁止 FU 化，必须研发产出版本化资产）：
- `source` — 任何 .java / .py / .vue / .ts / .sql 源码变更
- `sql` — DDL / DML / 迁移脚本 / 种子数据
- `template` — UReport / Jasper / FineReport / BPMN / Drools 等模板文件
- `dict` — sys_dict_data / 字典初始化
- `iac` — Dockerfile / K8s manifest / Helm / Terraform / CI/CD pipeline

**若验收阶段产出的 FU 任务命中黑名单 → Step 13 自动 fail，回退到 implementer 阶段完成研发产物，不允许通过 99-summary 兜底。**

历史教训：UReport 报表模板被错误归到"运维操作"导致 P0 AC 未实现仍通过 conditional_accept。模板属于 `template` 类别，必须由 implementer 产出 `.ureport.xml` diff 或 `sys_rpt_file` 升级 SQL。

## 下一步建议
- {是否执行 /mpdev:check 验证契约漂移}
- {是否执行 /mpdev:env restart 让改动生效}
- {是否 git commit}
- {如 15-doc-refresh.md 有 TODO 段落 → 建议跑 /mpdev:understand only={modules} force 全量刷新}
```

### T7 — 文档刷新报告 (`15-doc-refresh.md`)

```markdown
---
run_id: {run_id}
step: 7.5
phase: doc-refresh
status: {success / partial / failed / skipped}
agent: doc-refresher
generated_at: {timestamp}
---

# 文档增量刷新

## 触发判定
- 模式: {A / B}（C 跳过）
- 涉及模块: {N} 个
- 契约新增条目: sql {N} / schemas {N} / openapi {N} / events {N}
- 是否 git 仓库: {true / false}

## 已刷新
| 文件 | 段落 | +行 | 摘要 |
|------|------|----:|------|
| java/CLAUDE.md | ## REST API | 1 | +POST /api/task/create |
| java/CLAUDE.md | ## 数据模型 | 1 | +Task.task_type |
| robot-contracts/CLAUDE.md | ## 表总表 - schemas | 1 | +alarm_data.silent |

## 跳过 + TODO
| 文件 | 目标段落 | 原因 | TODO 落点 |
|------|---------|------|----------|
| dispatch/CLAUDE.md | ## 工作流程 | 需要语义重写 | dispatch/TODO.md |

原因取值：`section_not_found` / `section_format_unrecognized` / `already_present` / `edit_failed`

## 未触碰（设计上不动）
- `robot-contracts/flows/DATAFLOW.md`（需要 architect 视野，建议大改后跑 `/mpdev:contracts force` 重建）
- `robot-contracts/events/EVENT_CATALOG.md`（contract-designer 已经维护）

## 错误（如有）
{致命错误列表，如 Read 文件失败导致整文件未处理}

## Git Diff 摘要
{若是 git 仓库，每个被刷新文件用 `Bash("git diff -- {file}")` 抓 diff，纯文本逐行列出，不嵌套代码块。例：}

> `git diff -- java/CLAUDE.md`
>   + `| POST | /api/task/create | 创建任务 | ... |`

{若非 git 仓库：标注"非 git 仓库，跳过 diff 抓取"}

## 后续建议
- 漂移度高（跳过 + TODO 超过 5 项）→ 建议跑 `/mpdev:understand only={modules} force` 全量刷新
- 文档刷新有误 → `git checkout {file}` 撤回单文件（需 git 仓库）
- robot-contracts/CLAUDE.md 不存在但项目跨模块 → 建议跑 `/mpdev:contracts` 首次建立
```

---

## 容错规则

### 关键路径 vs 非关键路径

| Agent | 失败处理 |
|-------|---------|
| 需求精细识别 (Step 3) | 🔴 **流程终止**（需求不清 Architect 会出错方案）|
| architect | 🔴 **流程终止** |
| contract-designer | 🔴 **流程终止**（impl 无契约可遵循）|
| impl agents | 🟡 跳过该模块，下游依赖标注阻塞 |
| code-reviewer | 🟡 跳过 review，标注"未审查" |
| integration-checker | 🟡 跳过联测，标注"未验证" |
| acceptance-reviewer | 🟡 跳过验收，标注"未验收" |
| doc-refresher (Step 12.5) | 🟡 不阻塞 Step 13；99-summary.md 标注"文档未刷新（{原因}）"，建议手动跑 `/mpdev:understand` 补救 |

### 修复循环上限

| 环节 | 最大轮次 | 超限处理 |
|------|---------|---------|
| impl 自测自修复 | 3 | fail_with_report |
| Step 10 review/integration | 2 | 残留 warn 呈现用户 |
| Step 11 acceptance | 1 | 交用户人工判断 |

### 通用规则
- 用户说"停"/"取消" → 立即停止后续 agent，已变更保留
- 不自动 git commit，用户决定何时提交
- 部分完成也有价值，汇总报告标注完成度
