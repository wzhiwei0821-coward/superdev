---
name: fix
description: 轻量修复 — 单 bug 或批量清单（禅道 CSV / Markdown），跳过 Architect 和 Contract 直接让 impl agent 修复
allowed-tools: Agent, Read, Grep, Glob, Bash, TodoWrite, Write, Edit, AskUserQuestion, mcp__playwright__*, mcp__mysql__*
---

# /mpdev:fix — 轻量 Bug 修复（单 bug + 批量清单）

`/mpdev:dev` 的精简版。跳过 Architect（用户已定位问题）和 Contract-Designer（bug 修复极少改契约），直接让目标模块的 impl agent 修复，最后过**一次** code-reviewer 整批把关。

**两种使用方式**：

| 方式 | 用法 | 场景 |
|------|------|------|
| **A. 单 bug** | `/mpdev:fix {模块} {描述}` | 一眼定位的问题 |
| **B. 批量清单** | `/mpdev:fix @bugs.md` 或 `/mpdev:fix @zentao.csv` | 测试产出的 bug 清单 |

**适用场景**：
- `/mpdev:dev` 产出的代码有 bug，需要快速修复
- 单模块内的问题（不涉及新增跨模块字段/接口）
- 测试给的 bug 清单（禅道导出或手写 markdown），批量分模块处理

**不适用**（应该用 `/mpdev:dev`）：
- 不清楚 bug 根因在哪个模块
- 修复需要新增 MQ 字段、API 接口、数据库列
- 涉及 3 个以上模块的联动修改（批量模式会自动检测并提示升级）

---

## 用户输入

$ARGUMENTS

### 方式 A：单 bug

描述 **哪个模块 + 什么现象 + （可选）错误日志或期望行为**：

```
/mpdev:fix dispatch 启动后报 KeyError: 'task_type'，night_patrol 没加入 TASK_TYPE_MAP
/mpdev:fix java /api/task/create 返回 500，日志 NullPointerException at TaskServiceImpl:127
/mpdev:fix vue pad 端任务列表不显示新增的 night_patrol，下拉框缺少选项
```

### 方式 B：批量清单

**B.1 通过文件引用**：

```
/mpdev:fix @bugs.md              # 读文件解析
/mpdev:fix @zentao-export.csv    # 禅道导出的 CSV
/mpdev:fix @test-report.md       # 任何包含 bug 清单的文件
```

**B.2 直接粘贴清单**（用 `--batch` 触发，下行开始是清单）：

```
/mpdev:fix --batch
| 模块 | 问题 |
|------|------|
| java | /api/task 返回 500 |
| vue  | 列表页下拉框缺少 night_patrol |
| dispatch | 启动报 KeyError: 'task_type' |
```

### 支持的清单格式

| 格式 | 识别条件 | 典型来源 |
|------|---------|---------|
| **禅道 CSV** | `.csv` 扩展或首行含 `Bug编号,标题,所属模块` 模式 | 禅道导出 → bug 列表 → 导出 CSV |
| **Markdown 表格** | 含 `\|` 分隔，表头含"模块/问题/bug" | 自己写的测试报告、钉钉/飞书复制 |
| **Markdown 列表** | 行首 `-` / `*` / `1.`，可带 `[模块]` 标注 | 自己整理的 bug 清单 |
| **自由文本** | 兜底：按段落拆 + 关键词推断模块 | 聊天记录、邮件 |

---

## Step 0: 模式识别与清单解析

### 0.1 模式判断

```
if $ARGUMENTS 含 "@{文件路径}":
  bug_source = file
  Read(file_path) → content
elif $ARGUMENTS 以 "--batch" 开头:
  bug_source = pasted
  content = $ARGUMENTS 去 "--batch" 后剩余部分
elif $ARGUMENTS 是单行自然语言（无表格/列表标记，无换行）:
  bug_source = single
  → 构造 bugs = [{id:1, module: 第一个词, title/description: 剩余}]
  跳过 Step 0.2~Step 1，直接进入 Step 2（单 bug 快路径）
else:
  bug_source = pasted_inline
  content = $ARGUMENTS（可能是粘贴的多行内容但忘了 --batch）
```

### 0.2 清单格式识别

对 content 按优先级判断：

```
1. 禅道 CSV（首行形如 "Bug编号,标题,所属模块,..." 或 .csv 扩展）:
   - 首行 = 表头，提取列名索引
   - 关键字段映射:
       标题 / 主题 / Title       → bug.title
       所属模块 / 模块 / Module   → bug.module（显式）
       重现步骤 / 描述 / Description → bug.description
       严重程度 / 优先级          → bug.severity（可选）
       Bug 编号                  → bug.source

2. Markdown 表格（含 | 分隔，表头 grep 到 "模块|问题|bug"）:
   - 按 | 切分，提取"模块"列 和"问题/描述"列

3. Markdown 列表（^[-*]\s 或 ^\d+\.\s）:
   - 每项一个 bug
   - 扫 [xxx] / (xxx) / @module:xxx 作为显式模块标注
   - 其余文本作为 title+description

4. 兜底（自由文本）:
   - 按双换行或"\n\d+\."拆段，每段一个 bug
   - 模块留空（Step 0.3 推断）
```

### 0.3 模块识别（按优先级）

对每个 bug：

```
1. 已有显式 module（禅道"所属模块" / [xxx] 标注 / @module:xxx） → 直接用
2. 描述中含模块关键词 → java/dispatch/analytics/vue/algor
3. 描述中含文件扩展 → .java=java, .vue=vue, .py→看路径前缀(dispatch/analytics/algor)
4. 描述中含类/路径特征 → Controller/Service=java, Pad/H5/Web=vue
5. 都不行 → module=unknown（Step 1 让用户补）
```

### 0.3.1 前端 bug 标记（决定 Step 2.5 探针选择）

对每个 bug 追加字段 `is_frontend_bug`：

```
判定（任一即为 true）:
  - bug.module ∈ {vue, h5, pad, web, frontend}
  - bug.title + bug.description 含关键词:
    页面 | 白屏 | 下拉框 | 按钮 | 点击 | 表单 | 路由 | 跳转 | 样式 | 展示 | 刷新 | 渲染
```

### 0.4 统一数据结构

```yaml
bugs:
  - id: 1
    module: java
    title: "NPE at TaskServiceImpl:127"
    description: "/api/task/create 返回 500..."
    severity: high        # 可选
    source: "BUG-3421"    # 可选，用于追溯原始 ID
  - id: 2
    module: vue
    ...
```

---

## Step 1: 模块分组与确认

### 1.1 按模块分组

```
groups = {
  java:     [bug#1, bug#3, bug#8],
  dispatch: [bug#5],
  vue:      [bug#2, bug#7],
  unknown:  [bug#4]     # 未识别
}
```

### 1.2 展示 + 确认（单 bug 模式跳过此步）

```
识别出 {N} 条 bug，按模块分组：

  📦 java (3)
     #1  /api/task/create NPE at TaskServiceImpl:127
     #3  告警删除接口返回 404
     #8  TaskService NullPointer

  📦 vue (2)
     #2  pad 端下拉框缺少 night_patrol
     #7  H5 列表页面白屏

  📦 dispatch (1)
     #5  启动报 KeyError: 'task_type'

  ❓ unknown (1) —— 需要你补充模块
     #4  消息延迟 20 秒到达
```

**若有 unknown**：
```
对每个 unknown bug:
  AskUserQuestion: "#{id} {title} 属于哪个模块？"
  选项: [java / vue / dispatch / analytics / algor / 丢弃此 bug]
```

**最终确认**：
```
AskUserQuestion: "分组正确吗？"
  选项:
    - 开始修复
    - 删除某些 bug（让用户输入要删的 id）
    - 取消
```

### 1.3 单 bug 快路径

`len(bugs) == 1` 时跳过 1.1 / 1.2 展示，直接进 Step 2。

---

## Step 2: 升级信号检查

### 2.1 扫描升级信号

对所有 bug 的 title + description 做组合扫描：

```
触发信号（任一命中即算整批命中）:
  - 正则: "新增字段|add\\s+field|new\\s+API|新接口|新增接口"
  - 涉及模块数 >= 3（groups 中非 unknown 的 key 数 >= 3）
  - 任何 bug 描述含"数据库迁移|add\\s+column|DDL|alter\\s+table"
  - 任何 bug 描述含"breaking|向后不兼容|breaking\\s+change"
```

### 2.2 提示升级（整批停下）

命中时 → AskUserQuestion：

```
"清单中以下 bug 可能涉及契约变更：
   #{id1} {title1}
   #{id2} {title2}
   （共 {N} 个触发项）

/mpdev:fix 不改契约仓库。建议：
  A. 整批终止，改用 /mpdev:dev 做系统性修复（推荐）
  B. 继续批量 /mpdev:fix（风险自担：契约可能漂移，最终报告会标注）
  C. 移除这些 bug，其他的继续修"
```

- 选 A → 终止，提示："请用 `/mpdev:dev 描述整体需求` 重新启动"
- 选 B → 继续 Step 3，标记 `contract_risk_acknowledged=true`，总览报告单独提示
- 选 C → 从 bugs 列表删除触发项，更新 groups，继续

**单 bug 模式且命中**：同样弹此询问（保持行为一致）。

---

## Step 2.5: 环境复现（软门）

时序：Step 2 升级信号检查之后、Step 3 收集上下文之前。

**目的**：在让 impl agent 推理之前，先用真实环境采集事实——避免凭印象瞎猜。复现失败时软门降级，继续走静态分析，但报告标注 ⚠️。

### 2.5.1 选择探针

```
对每个 bug:
  if bug.is_frontend_bug == true:
    probe = probe-browser
  elif bug.title + bug.description 含 "/api/" 或具体 endpoint 路径（正则 /\/[a-z][a-z0-9/]+/）:
    probe = probe-http
  elif bug.title + bug.description 含 SQL 关键字 / 表名 / 列名 / "database":
    probe = probe-db (intent=reproduce)
  else:
    probe = probe-http (兜底，尝试触发服务异常日志)
```

### 2.5.2 加载并执行探针

```
Read ${CLAUDE_PLUGIN_ROOT}/templates/runtime-probe/probe-{name}.md
按其中"输入"节准备上下文变量:
  - module = bug.module
  - intent = "reproduce"
  - 其他变量按 bug 描述提取
按"步骤"节执行 → 拿 reproduction_result
```

### 2.5.3 判定 repro_state

```
bug.repro_state = match reproduction_result.status:
  "ok" + repro_confirmed=true:
    bug.repro_state = "confirmed"
    bug.repro_evidence = reproduction_result（含 screenshot/SQL/HTTP log 路径）
  
  "ok" + repro_confirmed=false:
    bug.repro_state = "diverged"
    （触发了，但与描述对不上 → 警告，但继续走 impl）
  
  其他（skipped/conn-failed/timeout/no-endpoints/...）:
    bug.repro_state = "skipped"
    bug.repro_skip_reason = reproduction_result.error
    （软门：继续走静态分析）
```

### 2.5.4 持久化 + 注入上下文

```
对每个 repro_state ∈ {confirmed, diverged} 的 bug:
  归档已由探针自己完成（.claude-notes/repro/{batch_id}/bug-{id}.*）
  在 bug.repro_evidence 中记录所有相关路径（供 Step 4 impl agent 用 + Step 5.5 verify 阶段对照）:
    entry_url: <浏览器入口 URL，若 probe-browser>
    screenshot_path: <截图路径，若 probe-browser>
    console_log_path: <{prefix}.console.txt 路径，若 probe-browser>
    repro_path: <SQL/HTTP log 路径，按探针类型>
    evidence_summary: <2-3 句关键信号摘要>
```

### 容错

| 场景 | 行为 |
|------|------|
| 探针文件不存在 | 警告 + 标 repro_state=skipped, reason="probe-{name}.md missing" |
| state.yml 不存在 | 探针返 skipped → repro_state=skipped, reason="no state.yml, run /mpdev:env start first" |
| 服务未启动 | 探针返 conn-refused → skipped + 提示 `/mpdev:env restart {module}` |
| playwright MCP 未配置 | probe-browser 守卫返 skipped → repro_state=skipped, reason="playwright MCP unavailable" |
| mysql MCP 未配置 + 无 mysql CLI | probe-db 策略 C → skipped, reason="no mysql client available" |
| 用户拒填凭据 | probe-db 收到"跳过此次" → skipped, reason="credentials collection declined by user" |
| 凭据收集后仍连不上 | skipped + reason="creds may be stale, check .mpdev-runtime-creds.yml" |

---

## Step 3: 收集上下文（按模块组）

按依赖顺序处理模块组：`java → dispatch → analytics → algor → vue`
（不存在的组跳过；unknown 在 Step 1 已清理；**注**：不含 contracts —— 涉及契约的 bug 在 Step 2 升级信号里已被拦截到 /mpdev:dev）

### 3.1 读取该组的 agent 定义

```
Read(".claude/agents/{module}-impl.md") → agent 定义全文
```

### 3.2 收集现场信息（并行 Grep）

```
对该组所有 bug 提取关键词:
  - 错误码 / 异常类型（NPE, 500, KeyError, NullPointerException）
  - 类名 / 方法名（从描述中正则提取驼峰名）
  - 文件路径（描述中提到的）

并行 Grep(关键词, path=模块目录)
Read 定位到的相关代码文件（最多 10 个）
```

### 3.3 最近变更（可选）

```
Bash("git log --oneline -10 -- {module_dir}")
Bash("git diff HEAD~3 -- {module_dir}")  # 可能是引入 bug 的变更
```

---

## Step 4: Impl Agent 修复（按模块组）

**一组 bug 只调用 impl 一次**——让 agent 能看到同模块全景，识别共享根因。

```
for module in [java, dispatch, analytics, algor, vue]:
  if module not in groups: continue
  
  Agent(
    subagent_type="{module}-impl",
    description="修复 {module} 模块 {N} 个 bug",
    prompt="""
<{module}-impl.md 内容>

## 任务: 批量 Bug 修复（同模块）

### 本组 Bug 清单
{对该组每个 bug 列出 id/title/description/严重程度/现场信息}

### 修复要求
1. 逐个修复，每个都要找根因（不止修表面）
2. 识别共享根因——多个 bug 可能是同一个问题的不同表现
3. **一个 bug 修复失败不终止——继续下一个 bug**
4. 不引入新副作用——只改与 bug 直接相关的代码
5. 若发现需要改其他模块 → 在 cross_module_issue 标注，不自行改

### 输出格式（必须严格按此 YAML 格式返回）
```yaml
module: {module}
bugs_result:
  - id: 1
    status: fixed | cannot_fix
    root_cause: "一句话根因"
    files_changed:
      - path: "..."
        changes: "..."
    test_result: pass | fail | no_test
    similar_patterns:                  # 新增：用于 Step 4.5 同类问题扫描
      - description: "未做 null 检查直接解引用"
        grep: "\\.getTask\\(\\)\\.[a-z]"
      - description: "..."
        grep: "..."
  - id: 3
    ...
shared_root_cause: null | "多个 bug 共享根因的描述"
cross_module_issue: null | "其他模块也需改的描述"
```
    """
  )
```

### 4.1 处理组结果

```
对每个 bug_result:
  status=fixed → 加入 fixed_list
  status=cannot_fix → 加入 failed_list，保留 agent 的失败原因

如果整组 agent 调用失败（异常/超时）:
  标记整组全部 cannot_fix，继续下一组
```

### 4.2 继续下一组

**不论本组结果，继续下一个模块组**。失败不终止整批。

---

## Step 4.5: 同类问题扫描（用户确认后批量修）

时序：Step 4 impl agent 修复完成之后、Step 5 code review 之前。

**目的**：修一个 bug 不等于修一类问题。impl agent 输出的 `similar_patterns` 告诉我们去哪儿 grep 同类位置。

### 4.5.1 收集 grep 模式

```
对每个 status=fixed 的 bug:
  从 bug.similar_patterns 提取 grep 模式列表
  跳过 similar_patterns 为空的 bug（impl agent 认为没有模式可扫）
```

### 4.5.2 全仓 grep + 排除已修文件

```
对每个 grep 模式:
  Grep(pattern, path=".", -n=true, output_mode="content", head_limit=30)
  排除:
    - 本批次已修文件: fixed.files_changed[*].path
    - 测试/示例目录: **/test/**, **/tests/**, **/example/**, **/demo/**
    - 构建产物: target/, dist/, build/, node_modules/
  收集 → similar_candidates[]
```

### 4.5.3 展示 + 用户确认

```
若 similar_candidates 为空 → 跳过本 bug 的 4.5.4，继续
若 similar_candidates 超过 20 个 → 截前 20 + 备注"还有 N 个未审视"

展示:
  "修 #{bug.id} 时识别出 {N} 个可能同类的位置:
     a) {file:line} {context_excerpt}
     b) {file:line} {context_excerpt}
     ...
   选哪些一起修？
   选项: [全选 / 部分（输入字母如 'a,c,e'） / 都不修]"

AskUserQuestion 收集
```

### 4.5.4 调 impl agent 第二轮（仅选中位置）

```
若用户选了候选:
  bug.similar_fixes_count = len(selected_candidates)   # 用于 Step 6 报告
  bug.similar_locations = selected_candidates           # 用于 Step 6 报告"同类位置"节
  
  Agent(
    subagent_type="{module}-impl",
    description="修同类位置 {N} 处",
    prompt="""
    刚刚修了 bug #{id}: {root_cause}
    
    现在请用同一思路修以下位置（已用户确认）:
    {selected_candidates}
    
    要求:
    - 复用 bug #{id} 修复的代码风格
    - 输出格式同 Step 4 的 YAML（必含 status / files_changed）
    - 标记 from_similar_scan: true
    - 标记 parent_bug_id: {bug.id}    # 用于 Step 6 报告归属
    """
  )
  
  追加结果到 fixed_list（标记 from_similar_scan: true, parent_bug_id={bug.id}）

若用户选"都不修":
  bug.similar_fixes_count = 0
  bug.similar_locations = []
```

### 容错

| 场景 | 行为 |
|------|------|
| similar_patterns 为空 | 跳过本 bug 的 4.5（impl agent 没识别出可推广模式） |
| grep 0 命中 | 跳过用户确认，继续 |
| 候选 > 20 | 截前 20 + 报告附"还有 N 个未审视" |
| impl agent 第二轮失败 | 标 cannot_fix + 保留原 bug fixed 状态 |

---

## Step 5: 整批 Code Review

**全部模块组修复完成后，code-reviewer 只调用一次**。

### 5.1 准备审查清单

```
all_changed_files = 去重收集所有 status=fixed 的 bugs_result.files_changed[*].path
```

### 5.2 调用 reviewer

```
Agent(
  subagent_type="code-reviewer",
  description="批量修复整批审查: {N} bug / {M} 模块",
  prompt="""
<code-reviewer.md 内容>

## 审查范围（仅以下文件）
{all_changed_files}

## 修复背景
本次批量修复 {N} 个 bug，涉及 {M} 个模块：
- java: {简要 bug 列表}
- dispatch: {...}
- vue: {...}

## 审查重点
1. 每个 bug 修复是否对症（对照 root_cause）
2. **跨模块一致性**（MQ 字段、API 返回格式在多个 impl 手里是否对齐）
3. 是否引入新 bug 或副作用
4. 编码规范一致性
5. 测试覆盖

注意: 这是批量修复审查，不需要审查修复范围外的代码。
  """
)
```

### 5.3 处理 review 结果

```
approve / comment_only → Step 6
request_changes → 最多 1 轮修复:
  提取 critical issues，按模块归类
  分发给对应 impl agent 修（不回到整批循环，只修 review 提的点）
  重跑 code-reviewer（仅审修复文件）
  第 2 轮仍 request_changes → 残留问题写进 Step 6 报告
```

---

## Step 5.5: 浏览器验证（仅前端 bug，软门）

时序：Step 5 code review 通过之后、Step 6 修复报告之前。

**目的**：前端 bug 修完后，跑同一复现路径，用截图 + console errors 比对 Step 2.5 的基线，证明 bug 真的修好了。

### 5.5.1 确认服务已重启

```
对每个 is_frontend_bug=true 且 status=fixed 的 bug:
  
  # 守卫 1: state.yml 不存在 / 模块不在 state.yml
  Read .claude/.mpdev-env-state.yml
  若文件不存在 → bug.verified = skipped, verify_skip_reason = "no state.yml, run /mpdev:env start first"
                跳到下一个 bug
  找 modules[name={module}]
  若该模块不在 state.yml → bug.verified = skipped, verify_skip_reason = "module not registered in state.yml"
                          跳到下一个 bug
  
  # 守卫 2: 服务是否实际在跑（先 ping 一下，比"猜 hot-reload"靠谱）
  health_url = modules[name={module}].health_check 提取出的 URL
  Bash("curl -sf {health_url} --max-time 3 -o /dev/null") → exit_code
  若 exit_code != 0:
    AskUserQuestion:
      "{module} 服务似乎未在 {health_url} 响应。验证步骤需要服务在跑。
       选项: [运行 /mpdev:env restart {module} / 已手动重启过 / 跳过验证此 bug]"
    选"运行 /mpdev:env restart" → Bash 等价命令 + 等 5 秒 + 重新 curl
       仍失败 → bug.verified = skipped, verify_skip_reason = "service restart failed"
    选"已手动重启过" → 重新 curl 验证
       仍失败 → 提示用户检查服务后 → bug.verified = skipped
    选"跳过验证" → bug.verified = skipped, verify_skip_reason = "user declined restart"
                  跳到下一个 bug
  
  # 服务确认在跑后：判定是否需要刷新（hot-reload vs 重启）
  start_cmd = modules[name={module}].start_cmd
  判定:
    start_cmd 含 "npm" / "vite" / "webpack" / "vue-cli-service" → 假定 hot-reload 自动
                                                                  等 3 秒让 reload 生效 后继续
    其他（如 Java SSR / Python 模板）:
      AskUserQuestion:
        "代码已修，{module} 不属于 hot-reload 系。是否运行 /mpdev:env restart {module}？
        选项: [是，自动重启 / 已手动重启 / 跳过验证]"
      选"自动重启" → Bash 执行 /mpdev:env restart 等价命令 + 等 5 秒 + 重新 curl health 确认
      选"跳过验证" → bug.verified = skipped, verify_skip_reason = "restart declined"
                    跳到下一个 bug
```

### 5.5.2 调 probe-browser intent=verify

```
Read ${CLAUDE_PLUGIN_ROOT}/templates/runtime-probe/probe-browser.md
准备输入:
  module = bug.module
  bug_description = bug.title + bug.description
  intent = "verify"
  entry_url = bug.repro_evidence.entry_url（沿用 Step 2.5 的入口）
  batch_id = 当前批次 ID
  bug_id = bug.id（用于基线 console.txt 文件名匹配）
  repro_console_log_path = bug.repro_evidence.console_log_path（若 Step 2.5 已记录）
                          缺省值 = 让探针自己 glob
按"步骤"节执行 → 拿 verify_result
```

### 5.5.3 判定 verified 状态

```
match verify_result.status:
  "ok" + repro_confirmed=false:
    bug.verified = true
    bug.verify_evidence = verify_result（含修后截图/console log）
    继续下一个 bug
  
  "ok" + repro_confirmed=true:
    bug.verified = false
    AskUserQuestion:
      "{bug.title} 修复后浏览器仍可复现:
        - 修前 errors: {bug.repro_evidence.console_errors 前 3 条}
        - 修后 errors: {verify_result.console_errors 前 3 条}
       
       选项:
         a) 回 Step 4 让 impl agent 再修一轮（建议）
         b) 标 cannot_fix，记录到报告
         c) 强制通过（用户认为 bug 已修，浏览器假阳性）"
    选 a → 回 Step 4 重修该 bug（最多 1 轮，第二轮仍 verified=false 则强制走 b）
    选 b → bug.status = "cannot_fix" + verified = false
    选 c → bug.verified = "forced"
  
  其他失败:
    bug.verified = skipped
    bug.verify_skip_reason = verify_result.error
```

### 容错

| 场景 | 行为 |
|------|------|
| state.yml 不存在 | bug.verified = skipped, reason="no state.yml, run /mpdev:env start first" |
| 模块不在 state.yml | bug.verified = skipped, reason="module not registered in state.yml" |
| 服务未在跑（curl health 失败）| AskUserQuestion 3 选 1：自动重启 / 已手动重启 / 跳过 |
| 服务重启失败 | bug.verified = skipped, reason="service restart failed" |
| playwright MCP 未配置 | probe-browser 守卫返 skipped → bug.verified = skipped, reason="playwright MCP unavailable" |
| Playwright 在 navigate 阶段就失败 | bug.verified = skipped, reason="navigate failed" |
| reproduce 基线 console.txt 找不到 | bug.verified = skipped, reason="no reproduce baseline found"（建议人工目视确认） |
| verify 阶段已经走到第二轮 | 强制标 cannot_fix（防止死循环） |

---

## Step 6: 修复报告

### 6.1 生成每个 fixed bug 的单独报告

```
timestamp = 当前时间 YYYYMMDD-HHMM
batch_id  = "batch-{timestamp}"（仅批量模式）

for bug in fixed_list + failed_list:
  slug = 取 bug.title 前 30 字符，转 kebab-case
  
  # 命名策略：单 bug 保留原格式（向后兼容），批量含 bug.id 做区分
  if len(bugs) == 1:
    file_id = "{timestamp}-{module}-{slug}"
  else:
    file_id = "{timestamp}-{bug.id}-{module}-{slug}"
  
  Write(".claude/mpdev-runs/fixes/{file_id}.md", ...)
```

**单 bug 报告模板**（保留原格式，新增 `batch_id` 追溯 + 运行时验证字段）：

```markdown
---
fix_id: {file_id}
module: {module}
status: {fixed / cannot_fix}
generated_at: {timestamp}
batch_id: {batch_id | null}                  # 批量模式才有
source_id: {bug.source | null}                # 禅道 Bug 编号（若有）
repro_state: {confirmed / diverged / skipped} # 新增：Step 2.5 复现结果
verified: {true / false / forced / skipped / not_applicable}  # 新增：Step 5.5 验证结果
verification_method: {browser / http / db / none}             # 新增
similar_fixes_count: {N}                      # 新增：Step 4.5 同类位置数
---

# 修复报告：{bug.title}

## 原始问题
> {bug.description}

## 根因
{root_cause}

## 变更文件
| 文件 | 变更 |
|------|------|
| {path} | {changes} |

## 复现证据（Step 2.5）
{若 repro_state=confirmed: 嵌入截图引用 / curl 输出 / SQL 结果路径 + 关键摘要}
{若 repro_state=diverged: ⚠️ 触发了相似现象但与描述不一致：<说明>}
{若 repro_state=skipped: ⚠️ 未能复现 — 原因：{skip_reason}}

## 同类位置（Step 4.5）
{若 similar_fixes_count > 0: 列出一并修的位置表（file:line / 修复要点）}
{若 0: "未发现同类位置" 或 "impl agent 未输出 similar_patterns"}

## 验证结果（Step 5.5）
{若 verified=true: ✅ 修后浏览器路径正常 + 嵌入对照截图引用}
{若 verified=false: ⚠️ 浏览器复现仍触发 — 已标 cannot_fix / 强制通过}
{若 verified=forced: ⚠️ 用户强制通过 — 浏览器仍有此现象，用户认为假阳性}
{若 verified=skipped: 跳过验证 — 原因：{verify_skip_reason}}
{若 verified=not_applicable: 后端 bug，无浏览器验证}

## 测试
- 结果：{pass / fail / no_test}

## 所属批次
{若 batch_id 非空}: 见 [批量总览](./batch-{timestamp}.md)
```

### 6.2 生成批量总览（仅 `len(bugs) > 1` 时）

```
Write(".claude/mpdev-runs/fixes/batch-{timestamp}.md", ...)
```

**批量总览模板**：

```markdown
---
batch_id: batch-{timestamp}
generated_at: {timestamp}
total_bugs: N
fixed: X
cannot_fix: Y
modules: [java, vue, dispatch]
source: "zentao-csv | markdown-list | markdown-table | pasted"
contract_risk_acknowledged: {true | false}
---

# 批量修复总览

## 清单来源
{$ARGUMENTS 原文或文件路径}

## 统计

| 模块 | 总数 | ✅ fixed & verified | ⚠️ fixed 未验证 | ❌ cannot_fix |
|------|-----:|--------------------:|---------------:|--------------:|
| java | 3 | 3 | 0 | 0 |
| vue  | 2 | 1 | 1 | 0 |
| dispatch | 1 | 0 | 0 | 1 |
| **合计** | **6** | **4** | **1** | **1** |

> verified 含义：
> - ✅ fixed & verified: status=fixed + verified ∈ {true, not_applicable}
> - ⚠️ fixed 未验证: status=fixed + verified ∈ {false, forced, skipped}
> - ❌ cannot_fix: 修复失败或验证失败标了 cannot_fix

## 逐 bug 结果

| # | 模块 | 标题 | 结果 | 详报 |
|---|------|------|------|------|
| 1 | java | NPE at TaskServiceImpl | ✅ | [详情](./{timestamp}-1-java-npe.md) |
| 2 | vue  | 下拉框缺少选项 | ✅ | [详情](./{timestamp}-2-vue-dropdown.md) |
| 5 | dispatch | 启动 KeyError | ❌ | [详情](./{timestamp}-5-dispatch-keyerror.md) |

## 共享根因（impl agent 识别到的）

- **[java 组]** TaskServiceImpl 对 null 参数缺少防御 → 修复 #1/#3
- **[vue 组]** night_patrol 枚举未注册到下拉组件 → 修复 #2/#7

## 未修复项（cannot_fix）

- **#5 [dispatch]** 启动 KeyError: agent 无法在当前代码中定位 TASK_TYPE_MAP 初始化位置，建议人工介入

## 跨模块影响

{若 Step 2 选择 B（继续含契约风险）:}
⚠️ 以下 bug 原本触发升级信号，继续修了但契约可能漂移，建议跑 `/mpdev:check`：
- #3 {title} - 涉及新字段

{若 impl agent 在 cross_module_issue 标注:}
- [java-impl] 修复 #8 时发现 analytics 侧也需要改——建议 `/mpdev:fix analytics ...`

## 整批代码审查

- 结论：{approve / comment_only / request_changes}
- 发现：{critical: N, important: M, suggestion: K}
- 修复循环：{Round 1 修了 N 个 / 残留 M 个}

## 下一步建议

- 需重启模块：{基于 files_changed 推断}
- 建议 commit：可用 `/mpdev:commit --with-check` 生成带契约校验的 message
- 若有 cannot_fix 或契约风险：建议 `/mpdev:dev` 做系统性处理
```

### 6.3 更新 INDEX.md

**批量模式**：在"修复记录"表顶部追加一行（汇总）：

```markdown
| {timestamp} | 批量({N} 个) | {模块列表} | ✅ X fixed / ❌ Y cannot_fix | [批量详情](./fixes/batch-{timestamp}.md) |
```

**单 bug 模式**：沿用原逻辑，追加单行：

```markdown
| {timestamp} | {module} | {bug 摘要 ≤40字} | ✅ fixed / ❌ cannot_fix | [详情](./fixes/{file_id}.md) |
```

---

## 容错规则

| 情况 | 处理 |
|------|------|
| 清单为空 / 解析失败 | 展示原文，提示"无法解析，请确认格式"并终止 |
| 清单含 > 20 个 bug | AskUserQuestion: "{N} 个 bug 耗时较长，是否拆批执行？" [一次跑完 / 拆成多批 / 取消] |
| 单个 bug 的 impl 失败 | 记录 cannot_fix + 原因，继续下一个 bug |
| 整组 impl 调用失败 | 标记该组全部 cannot_fix，继续下一组 |
| code-reviewer 失败 | 跳过审查，标注"未审查"，继续 Step 6 展示 |
| 模块匹配失败 | unknown 队列让用户补；用户选"丢弃" → 不进入修复 |
| 需要契约变更 | Step 2 升级信号已覆盖 |
| 批量模式中清单含 "/mpdev:fix" 字样 | 忽略，不执行嵌套 |
| 禅道 CSV 编码为 GBK | 尝试 utf-8 读失败 → 用 gbk 重读；失败 → 让用户转码 |

## 约束

1. **不改契约** — 不触碰 robot-contracts，触发信号强制弹升级提示
2. **最小范围** — 只改与 bug 直接相关的代码，不做"顺手"重构
3. **1 轮修复循环** — code-reviewer request_changes 只让 impl 修 1 轮，超限交用户
4. **不自动 commit** — 修复完成后建议用户用 `/mpdev:commit`，命令本身不自动 git add
5. **可链式**（单 bug） — 一个模块修完发现另一个也有问题，连续 `/mpdev:fix {m2} {...}`
6. **批量模式不嵌套** — 批量运行时忽略清单中出现的 /mpdev:fix 字符串
7. **必写文档** — 每个 fixed/cannot_fix bug 都写单独报告；批量模式额外写总览
8. **失败继续** — 单个 bug 失败不终止整批，最终在总览列出 cannot_fix
9. **整批 review 一次** — 无论多少 bug，code-reviewer 只调一次（request_changes 的修复循环除外）
10. **清单 > 20 时询问** — 避免一次性跑太多消耗资源、日志超长
11. **禅道 CSV 优先用标准字段** — 不强制用户改导出模板，自动识别常见中英文列名
