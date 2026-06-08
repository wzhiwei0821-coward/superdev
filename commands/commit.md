---
description: 提交辅助 — 扫描 git diff 自动生成中文 commit 说明，识别契约风险，用户确认后提交
allowed-tools: Read, Grep, Glob, Bash, TodoWrite, Write, Edit, AskUserQuestion
---

# /mpdev:commit — Git 提交辅助

扫描本次改动（git diff）→ 识别涉及的模块与变更类型 → 生成**自由中文风格** commit message 草稿 → 用户确认后执行 `git commit`。

**核心定位**：把 diff → what 这部分自动化，作者只需要填写/微调 why。**不替作者思考**，只替作者写字。

**适用场景**：
- 改完代码懒得写 commit message
- 想确认本次改动是否影响契约（MQ schema / SQL / OpenAPI）
- 跨模块改动，需要一条清晰的 message 说明每个模块改了什么

**不适用**（请用原生 git）：
- 空提交（`git commit --allow-empty`）
- 修正历史（`git commit --amend`） — 本命令**永不** amend
- 合并/变基场景

## 用户输入

$ARGUMENTS

**支持格式**：

| 输入 | 含义 |
|------|------|
| （空） | 全自动，从 diff 推断主题 |
| `"一句话描述"` | 用户给 why，命令补 what |
| `--dry-run` | 只生成草稿，不真提交 |
| `--with-check` | 同时跑 `/mpdev:check`，把契约校验结果附在 footer |
| `--dry-run "一句话描述"` | flag + 草稿组合 |

示例：
```
/mpdev:commit
/mpdev:commit 修复夜间巡检降速BUG
/mpdev:commit --with-check
/mpdev:commit --dry-run 新增静默告警接口
```

---

## Step 1: 读 git 状态

### 1.1 解析 $ARGUMENTS

```
提取 flags: --dry-run, --with-check
剩余部分作为 user_subject（用户提供的主题草稿，可能为空）
```

### 1.2 检查工作区

```
Bash("git status --porcelain")
```

分类结果：

| 情况 | 处理 |
|------|------|
| 无任何改动 | 输出"无改动可提交"，退出 |
| 只有已 stage（`M `/`A `/`D ` 在第 1 列） | 进入 Step 2 |
| 只有未 stage（第 2 列有变） | Step 1.3 询问用户 |
| 混合（部分 stage 部分未 stage） | Step 1.3 询问用户 |
| 存在 untracked 文件（`??`） | Step 1.3 一并询问 |

### 1.3 未 stage / untracked 时询问（不自动 add）

```
AskUserQuestion({
  question: "检测到未 stage 的改动，如何处理？",
  header: "Stage 策略",
  multiSelect: false,
  options: [
    {label: "仅提交已 stage", description: "保持现状，只提交已 git add 的文件"},
    {label: "add 跟踪中的改动", description: "git add -u（不加 untracked 新文件）"},
    {label: "add 全部", description: "git add .（包括新文件，注意 .env 等敏感文件）"},
    {label: "取消", description: "退出命令，手动 git add 后重跑"}
  ]
})
```

根据用户选择执行对应 `git add` 命令；选"取消"则退出。

**关键**：不自动 `git add .`，避免误带 `.env` / 日志 / 构建产物。

## Step 2: 收集 diff 数据

并行执行：

```
Bash("git diff --cached --stat")      → stat_output（文件×增删行）
Bash("git diff --cached --name-only") → file_list（改动的文件列表）
Bash("git branch --show-current")     → current_branch
Bash("git log -1 --format=%H --no-merges") → parent_sha（用于追溯）
```

**diff 正文按需读取**（避免超大 diff 拖慢）：

```
if file_list.length ≤ 10:
  Bash("git diff --cached")  → 完整读
else:
  仅对 Step 4 触发的信号点抽读：
    Bash("git diff --cached -- {path}")  → 每次只读一个文件
```

## Step 3: 识别涉及的模块

对 `file_list` 中每个文件，按路径前缀归类。**先读 CLAUDE.md 确定模块目录**（避免硬编码）：

```
Glob("**/CLAUDE.md") → 排除 .claude/ node_modules/ .git/ target/ dist/
读取每个 CLAUDE.md 所在目录名作为模块名
```

路径归类规则：

| 路径前缀（示例） | 归类 |
|----------------|------|
| `{module_dir}/...` | 对应模块名（如 `java`, `vue`, `dispatch`, `analytics`, `algor`） |
| `robot-contracts/*` 或 `contracts/*` | `contracts` |
| `.claude/*` | `config`（MPDev 配置本身） |
| 根目录文档（`README.md`, `*.md`） | `docs` |
| 其他 | `misc` |

结果：`module_map = {模块名: [文件列表]}`

## Step 4: 识别变更类型

对每个文件的 diff 扫描信号词，标注变更类型。

### 4.1 结构性变更信号

| 信号（在 + 行出现） | 变更类型 | 契约风险 |
|--------------------|---------|---------|
| `@RequestMapping` / `@PostMapping` / `@GetMapping` / `@DeleteMapping` / `@PutMapping` | 新增 API | ⚠️ 高：需同步 `openapi/*.yaml` |
| `@RabbitListener` | 新增 MQ 消费者 | ⚠️ 中：需对照 schema |
| `rabbitTemplate.convertAndSend` / `channel.basic_publish` / `publish(queue` | 新增 MQ 生产者 | ⚠️ 高：需对照 schema |
| `CREATE TABLE` / `ALTER TABLE` （在 `.sql` 文件） | DB 迁移 | ⚠️ 高：需同步 Entity |
| `@TableField` / `private.*;` （在 Entity 文件） | Entity 字段变更 | ⚠️ 高：需同步 SQL |
| `path:` / `/api/v1/` （在 `openapi/*.yaml`） | API 契约变更 | ✅ 契约内部一致 |
| `const routes` / `router.addRoute` （Vue） | 前端路由 | ℹ️ 低 |
| `application.yml` / `application.properties` | 配置变更 | ⚠️ 中：部署需注意 |

### 4.2 意图性变更信号（从文件名 / commit-like 关键词推断）

| 信号 | 推断意图 |
|------|---------|
| 文件名含 `Test.java` / `_test.py` / `.spec.ts` | 测试 |
| diff 只加注释 / 重命名变量 | 重构 |
| 路径含 `*.md` / `docs/` | 文档 |
| 新增 `.gitignore` / `Dockerfile` / `pom.xml` 等配置 | 构建/工程 |
| 用户输入的主题含 "修复"/"bug"/"fix" | 修复 |
| 用户输入的主题含 "新增"/"增加"/"实现" | 新功能 |
| 未明确 | 默认"调整"（中性词） |

### 4.3 生成 change_summary

对每个模块，组合"变更类型 + 涉及文件"生成 1-3 句人类可读摘要。示例：

```yaml
module_map:
  java:
    files: ["AlarmController.java", "AlarmService.java"]
    types: ["新增 API: POST /api/v1/alarm/silent", "新增 Service 方法 silentAlarm"]
  vue:
    files: ["pad/src/pages/alarm/list.vue"]
    types: ["告警列表页增加'静默告警'按钮"]
  contracts:
    files: ["openapi/alarm.yaml"]
    types: ["同步 openapi: 新增 /alarm/silent"]
```

## Step 5: （可选）契约校验

**仅当 $ARGUMENTS 含 `--with-check`** 时执行：

```
调用 /mpdev:check 的检测逻辑（不重新读 command 文件，直接按 L1/L2/L3 流程执行）
结果汇总为 contract_check_summary
```

如果发现 ⚠️ 不一致：**不阻塞提交**，但在 message footer 标注警告。

## Step 6: 生成 commit message 草稿

### 6.1 确定主题（subject）

```
if user_subject 非空:
  subject = user_subject
else:
  从 module_map 和变更类型推断:
    单模块 + 单一变更类型 → "{模块}{意图}{变更描述}"
      示例: "java新增静默告警接口"
    多模块 → "{主要意图}{主模块变更}，同步更新{副模块}"
      示例: "新增静默告警功能，同步更新 openapi 与前端"
    纯重构/文档 → 对应模板
```

**中文风格约束**：
- 不强制 `feat(scope):` 前缀
- 主题控制在 30 字以内
- 避免 "update"/"fix" 这种无信息量的词

### 6.2 组装完整 message

```markdown
{subject}

{如涉及多模块，逐模块列：}
- [java] AlarmController 新增 /api/v1/alarm/silent POST 接口
- [vue] pad 端告警列表增加"静默告警"按钮
- [contracts] openapi/alarm.yaml 同步新增该路径

{如 --with-check 且有契约风险：}
⚠️ 契约检查：SQL V012__add_alarm_silent.sql 新增 silent 列，但 AlarmEntity.java 未同步字段

{固定 footer：}
🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

### 6.3 展示草稿并请用户确认

```
用 markdown 代码块展示完整 message。

AskUserQuestion({
  question: "Commit 草稿如上。如何处理？",
  header: "提交决策",
  multiSelect: false,
  options: [
    {label: "直接用此 message 提交", description: "执行 git commit"},
    {label: "我要改 subject", description: "保留 body，我提供新的主题行"},
    {label: "我自己重写", description: "你给我完整稿，我贴新版"},
    {label: "取消，不提交", description: "保留已 stage 状态退出"}
  ]
})
```

根据选择：
- 选 1 → Step 7
- 选 2 → 询问新 subject，替换第一行后重新展示一次 → Step 7
- 选 3 → 提示用户把完整新 message 贴在下一条输入 → Step 7 使用用户版本
- 选 4 → 退出（保留已 stage 状态）

## Step 7: 执行 commit

**除非 `--dry-run`**：

```bash
git commit -m "$(cat <<'EOF'
{最终 message 全文}
EOF
)"
```

**严格约束**：
- ❌ 永不使用 `--amend`
- ❌ 永不使用 `--no-verify`
- ❌ 永不自动 `git push`
- ❌ 永不 `-s` 签名（除非用户未来明确要求）

### 7.1 提交失败处理

如果 `git commit` 返回非 0（常见：pre-commit hook 失败）：

```
展示 hook 输出给用户，提示:
"pre-commit hook 拦截了本次提交。请修复后重新执行 /mpdev:commit。
（注意：commit 未成功，改动仍在 stage 区，不会丢失）"
```

**不自动重试，不加 --no-verify 绕过。** 让作者面对问题根因。

### 7.2 提交成功

```
Bash("git log -1 --format=%H")  → new_commit_sha
Bash("git log -1 --format=%s")  → 验证 subject 落地
```

## Step 8: 📄 文档输出

生成提交记录，文件名：

```
commit_id = "{timestamp}-{short_sha}-{subject_slug}"
  timestamp   = YYYYMMDD-HHMM
  short_sha   = new_commit_sha[:7]
  subject_slug = subject 前 30 字符，中文转拼音首字母或保留，kebab-case
```

```
Write(".claude/mpdev-runs/commits/{commit_id}.md", ...)
```

**文档模板**：

```markdown
---
commit_id: {commit_id}
commit_sha: {new_commit_sha}
branch: {current_branch}
generated_at: {timestamp}
modules: [{module_list}]
with_check: {true/false}
dry_run: {true/false}
---

# 提交记录：{subject}

## 用户输入
> {$ARGUMENTS 原文}

## 改动范围

| 模块 | 文件数 | 变更类型 |
|------|-------:|---------|
| {module} | {n} | {types} |

## Diff 摘要
```
{git diff --cached --stat 的输出}
```

## 完整 Message
```
{提交时使用的 message}
```

## 契约校验
{若 --with-check:}
- L1 MQ: {结果摘要}
- L2 SQL↔Entity: {结果摘要}
- L3 OpenAPI↔Controller: {结果摘要}
{若未启用：}
- 未执行（可用 /mpdev:commit --with-check 启用）

## 关联
- 父提交：{parent_sha[:7]}
- 本提交：{new_commit_sha[:7]}
- 如本次改动源自某 /mpdev:dev 运行，手动在此处链接 `.claude/mpdev-runs/{run_id}/`

## 下一步建议
- 是否 push：由作者决定（本命令不自动 push）
- 如需推送：`git push origin {current_branch}`
- 如发现提交有误：`git reset --soft HEAD~1`（回退到 stage 状态）
```

### 8.1 更新 INDEX.md

在 `.claude/mpdev-runs/INDEX.md` "提交记录" 表格顶部追加一行：

```markdown
| {timestamp} | {short_sha} | {subject ≤40字} | {modules} | [详情](./commits/{commit_id}.md) |
```

如果 `--dry-run`，不更新 INDEX，只在控制台输出"已生成草稿但未提交"。

---

## 容错规则

| 情况 | 处理 |
|------|------|
| 非 git 仓库 | 提示"当前目录不是 git 仓库"，退出 |
| HEAD detached | 警告但允许继续（用户可能在做特殊操作） |
| diff 超过 2000 行 | 只逐文件读 Step 4 信号点，不全量读 diff |
| message 含特殊字符（` $ 等） | 用 heredoc 单引号形式 `<<'EOF'` 防止 shell 插值 |
| pre-commit hook 失败 | 展示原因，退出，不自动绕过 |
| 用户 3 次都选"我自己重写" | 提示可直接用原生 `git commit`，不再循环 |
| `.claude/mpdev-runs/commits/` 目录不存在 | 自动 `mkdir -p` 创建 |

## 约束

1. **绝不 amend** — `--amend` 会覆盖历史，已 push 的 amend 会让团队 pull 冲突
2. **绝不 --no-verify** — pre-commit hook 是团队治理，命令不帮忙绕过
3. **绝不自动 push** — push 影响他人环境，必须人工执行
4. **不自动 add** — 无 stage 时问用户，避免误带 .env/日志/构建产物
5. **Message 用 heredoc** — 防止 `$`、`` ` ``、换行在 shell 中被破坏
6. **dry-run 模式不写 INDEX** — 保持索引表的可信度（只记录真实提交）
7. **透明标注 Claude** — footer 固定含 `Co-Authored-By: Claude`（用户偏好）
8. **必写文档** — 非 dry-run 情况下，每次成功提交都写一份记录到 `commits/`
9. **不依赖 subagent** — 本命令全部逻辑在主编排器完成（相比 /mpdev:fix 更轻量）
10. **中文自由格式** — 不强制 Conventional Commits，但保持"主题 + 分模块列表"结构
