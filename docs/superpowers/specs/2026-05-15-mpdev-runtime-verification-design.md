---
title: mpdev-fix / mpdev-understand 接入运行时探针
status: approved
date: 2026-05-15
author: brainstorming session
target_version: mpdev-suite v1.3.0
---

# mpdev 运行时验证设计

## 1. 问题陈述

`/mpdev-fix` 和 `/mpdev-understand` 当前完全是**静态分析模式**：grep + 读代码 + LLM 推理。用户提出 5 个具体痛点：

1. **fix 浮于表面**：依赖印象瞎猜，修完没有任何运行时验证
2. **fix 缺少环境复现**：直接交给 impl agent，没要求先连 DB / 调 API / 看真实报错
3. **fix 不会自动检索同类问题**：只修当前 bug，相同模式的其他位置被遗漏
4. **fix 没有浏览器能力**：前端 bug 也只读代码，不复现不验证
5. **understand 缺运行时事实**：字典值、WebSocket 端点、DB 实际数据未读取，CLAUDE.md 全靠 schema 文件推断

5 个问题指向同一根因：**两个命令都缺乏"连接真实环境采集事实"的步骤**。

## 2. 设计目标

把 fix 和 understand 升级为**"静态分析 → 运行时验证 → 推理 → 再次验证"** 的闭环，但不破坏现有 9 个 slash 命令的简洁分工。

成功标准：
- 一个前端 bug，从 fix 启动到生成报告，整个过程**至少有一次 playwright 截图**作为证据
- 一个 DB 相关 bug，fix 流程中**实际执行过一次 SQL 探测**
- understand 生成的 CLAUDE.md 含**字典常量** + **WebSocket 端点**两个新区块
- 所有上述能力在**环境不可用**时优雅降级（软门），报告标注 ⚠️
- 凭据（DB 密码 / API token）**从不**写入归档报告，仅存于 gitignored `.mpdev-runtime-creds.yml`

## 3. 决策记录

| 决策点 | 选择 | 理由 |
|--------|------|------|
| 范围 | fix + understand 一份设计同时改造 | 二者复用同一组运行时能力，分开做会重复实现 |
| 复现策略 | **软门**：失败降级 + 报告标注 ⚠️ | 硬门会被"环境暂时不可用"卡死，软门保留可用性 |
| WebSocket 扫描 | **静态扫描**端点 / 消息类型 | 动态 WS 监听需鉴权、有隐私、可能等不到消息；静态收益大成本低 |
| 同类问题处置 | 全仓 grep + 用户确认 + 批量修 | 全仓覆盖防遗漏；用户确认防误伤 |
| Playwright 触发 | 模块 ∈ {vue,h5,pad,web} 或 bug 含前端关键词 → 全程参与（复现+验证） | 后端 bug 启浏览器没意义；命中即三阶段（复现/修复/验证）都用 |
| DB 凭据来源 | 首次输入 → 缓存到 `.claude/.mpdev-runtime-creds.yml`（gitignored） | 与代码仓凭据隔离；可手动预填；不会污染 LLM 上下文之外的归档 |
| 抽象方案 | 抽出独立的 runtime-probe 子能力 | fix/understand 共用；命令文件不膨胀；未来 /mpdev-test 也能复用 |

## 4. 总体架构

```
┌──────────────────────────────────────────────────────────────────┐
│                       现有命令（轻度改造）                          │
│  /mpdev-fix         /mpdev-understand        /mpdev-env (不变)    │
└────────┬─────────────────────┬──────────────────────┬────────────┘
         │ Step 2.5 / 4.5 / 5.5 │ Step 4.6 / 4.7        │ 产 state.yml
         ↓                      ↓                       ↓
┌──────────────────────────────────────────────────────────────────┐
│              templates/runtime-probe/  (新增子能力)                │
│  ┌─────────────┐ ┌─────────────┐ ┌──────────────┐ ┌─────────────┐│
│  │ probe-db.md │ │probe-http.md│ │probe-browser │ │ probe-ws.md ││
│  │   连 DB     │ │  调 API 触发 │ │ playwright   │ │  WS 静态扫   ││
│  │  查字典/数据 │ │  报错复现   │ │  复现+验证    │ │  端点+消息    ││
│  └─────────────┘ └─────────────┘ └──────────────┘ └─────────────┘│
└────────┬─────────────────────────────────────────┬───────────────┘
         │ 读                                       │ 写
         ↓                                          ↓
┌──────────────────────────────────────┐  ┌───────────────────────┐
│ .claude/.mpdev-env-state.yml         │  │ mpdev-runs/fixes/...  │
│ .claude/.mpdev-runtime-creds.yml(新) │  │  含 repro-trace.md(新)│
│ {module}/application*.yml            │  │ .claude-notes/        │
└──────────────────────────────────────┘  │  含 dict-snapshots(新)│
                                          └───────────────────────┘
```

## 5. 文件清单

### 5.1 新增（套件分发）

```
mpdev-suite/.claude/templates/runtime-probe/
├── README.md           # 探针总览：如何被调用、契约、命名约定
├── probe-db.md         # DB 连接 + 查询
├── probe-http.md       # HTTP 复现（curl 触发 endpoint）
├── probe-browser.md    # playwright 复现 + 验证
└── probe-ws.md         # WS 端点 + 消息类型静态扫描
```

### 5.2 新增（项目运行时，gitignored）

```
.claude/.mpdev-runtime-creds.yml      # DB / API token 凭据缓存
.claude-notes/{module}/dict-snapshots.md  # 字典快照
.claude-notes/{module}/ws-endpoints.md    # WS 端点扫描结果
.claude-notes/repro/{batch_id}/bug-{id}.md  # 复现证据（fix 用）
```

### 5.3 改造（命令文件）

- `mpdev-suite/.claude/commands/mpdev-fix.md`：加 Step 2.5 / 4.5 / 5.5 + 报告字段
- `mpdev-suite/.claude/commands/mpdev-understand.md`：加 Step 4.6 / 4.7 + CLAUDE.md 区块
- 两者的 `allowed-tools` frontmatter

### 5.4 安装脚本（脚本同步增强）

- `scripts/install.sh` / `install.ps1`：拷贝 `runtime-probe/`；在项目 `.gitignore` 追加 3 行
- `scripts/update.sh` / `update.ps1`：升级时也拷贝 `runtime-probe/`（无三方合并需求，全量覆盖）
- `VERSION`: `1.2.0` → `1.3.0`
- `CHANGELOG.md`: 加 v1.3.0 段

## 6. runtime-probe 探针契约

每个探针是一个 markdown 文件，主命令通过 `Read` 加载后按其中步骤执行。统一输入/输出契约：

### 6.1 probe-db.md

**输入**：
- `module`：模块名（state.yml 定位 DB 连接）
- `intent`：`reproduce` | `query-dict` | `verify-fix`
- `query_hint`（可选）：bug 描述中的表名/列名/错误关键词

**步骤**：
1. Read `.claude/.mpdev-env-state.yml` → 拿 `middleware[].mysql` 的 host/port + database
2. Read `.claude/.mpdev-runtime-creds.yml`，定位 `modules.{module}.db`
3. 凭据缺失 → AskUserQuestion 收集 username/password/database → 写回 creds 文件
4. 连接策略（按顺序尝试）：
   - 优先 `mcp__mysql__execute_query`（若 MCP 配的 host/db 与目标一致）
   - 降级到 `Bash("mysql -h ... -e \"...\"")`（要求宿主机有 `mysql` CLI）
   - 若两者皆不可用 → 返回 `skipped`（reason: "no mysql client available"）
5. 按 intent 执行：
   - `query-dict`：`SHOW TABLES` → 匹配字典模式（dict_/_dict/_type/enum_/status/state/role/category/level/priority）→ 每表 `SELECT * LIMIT 100`
   - `reproduce`：按 query_hint 拼定向 SELECT；找不到 hint 字段则跳过返回 skipped
   - `verify-fix`：与 reproduce 阶段保存的同一查询对比

**输出**（返回给调用方的 yaml）：
```yaml
status: ok | no-creds | conn-failed | query-failed | skipped
evidence:
  - table: dict_task_type
    rows_sample: [...]
notes_path: .claude-notes/{module}/dict-snapshots.md   # 仅 query-dict
error: "..."   # 仅失败时
```

### 6.2 probe-http.md

**输入**：`module`, `endpoint`, `method`, `payload_hint`（可选）

**步骤**：
1. 从 state.yml 拿模块的 port + health_check（用于构造 base URL）
2. 拼完整 URL：`http://localhost:{port}{endpoint}`
3. 如需 auth token → 从 creds.yml 取 `modules.{module}.api.auth_token`，缺则问用户
4. `Bash("curl -i -X {method} -H 'Authorization: ...' -d '{payload}' {url}")`
5. 截取响应头 + 前 200 行 body

**输出**：
```yaml
status: ok | conn-refused | timeout | skipped
status_code: 500
error_signature: "NullPointerException at TaskServiceImpl:127"   # 是否 match bug 描述
response_excerpt: "..."
```

### 6.3 probe-browser.md

**输入**：`module`, `bug_description`, `intent` (`reproduce` | `verify`), `entry_url`（默认从 state.yml 取）

**步骤**：
1. `mcp__playwright__playwright_navigate(entry_url)`
2. impl agent（调用方）按 bug_description 自由探索点击/填表（LLM 主导，非脚本化）
3. 触发疑似 bug 路径后：
   - `mcp__playwright__playwright_screenshot` → 存 `.claude-notes/repro/{batch_id}/bug-{id}-{intent}-{ts}.png`
   - `mcp__playwright__playwright_console_logs` → 截取 errors
4. intent=`verify` 时：把 reproduce 阶段的截图 + console_errors 作为对照基线

**输出**：
```yaml
status: ok | navigate-failed | timeout | skipped
screenshot_path: .claude-notes/repro/.../bug-1-reproduce-20260515-1430.png
console_errors:
  - "Uncaught TypeError: Cannot read property 'taskType' of undefined"
network_errors: []
repro_confirmed: true | false   # 是否触发了与 bug_description 一致的现象
```

### 6.4 probe-ws.md

**输入**：`module`（纯静态，不需服务运行）

**步骤**（按模块语言并行 grep）：
- Java：`@ServerEndpoint`, `@OnMessage`, `WebSocketHandler`, `extends TextWebSocketHandler`
- Python：`@sio.on(`, `websockets.serve(`, `fastapi.WebSocket`, `@router.websocket(`
- Node：`new WebSocket.Server`, `ws.on('message'`, `io.on('connection'`
- Vue / 前端：`new WebSocket(`, `socket.io-client` 用法
- 对每个端点向上找消息类型 DTO（参数类型 / payload schema）

**输出**：写 `.claude-notes/{module}/ws-endpoints.md`，并返回摘要：
```yaml
status: ok | no-endpoints | skipped
endpoints:
  - path: /ws/task-events
    handler: TaskEventsHandler.java:45
    direction: server_push | bidirectional | client_request
    messages:
      - event: task.created
        schema: TaskCreatedEvent (com.example.dto.TaskCreatedEvent)
notes_path: .claude-notes/{module}/ws-endpoints.md
```

### 6.5 通用约定

- 所有探针**只读不改**项目代码（probe-browser 的页面交互除外，但页面状态不持久）
- 所有探针都有 `status: skipped` 出口——状态不允许时返回 skipped + reason，主流程进入软门降级
- 凭据**绝不写报告**——只写到 `.mpdev-runtime-creds.yml`（gitignored）
- 探针不调其他探针——避免嵌套递归

## 7. `/mpdev-fix` 改造点

### 7.1 现状回顾

现有 Step 0-6：模式识别 → 模块分组 → 升级信号检查 → 收集上下文 → impl 修复 → code review → 报告。

### 7.2 Step 0.3 模块识别 — 加 frontend 标记

不改判定逻辑，但每个 bug 新增 `is_frontend_bug: bool` 字段：
- 模块名 ∈ {vue, h5, pad, web, frontend}，或
- 描述含关键词：`页面|白屏|下拉框|按钮|点击|表单|路由|跳转|样式|展示|刷新`

### 7.3 新增 Step 2.5 — 环境复现（软门）

时序：在 Step 2（升级信号检查）之后、Step 3（收集上下文）之前。

```
对每个 bug（按 module 分组）:
  
  Step 2.5.1 选择探针:
    bug.is_frontend_bug = true            → probe-browser
    bug 描述含 "/api/" 或具体 endpoint    → probe-http
    bug 描述含 SQL / DB 字段 / 表名        → probe-db (intent=reproduce)
    否则                                   → probe-http 兜底（试图触发服务异常）
  
  Step 2.5.2 调探针 → 拿 reproduction_result
  
  Step 2.5.3 判定 bug.repro_state:
    status=ok  + repro_confirmed=true   → "confirmed"
    status=ok  + repro_confirmed=false  → "diverged"   （触发了但与描述对不上 → 警告）
    status=skipped/conn-failed          → "skipped"    （软门：继续走静态分析）
  
  Step 2.5.4 把 evidence 注入 bug 上下文:
    impl agent 在 Step 4 能看到真实堆栈/截图/SQL 结果
    持久化到 .claude-notes/repro/{batch_id}/bug-{id}.md
```

### 7.4 新增 Step 4.5 — 同类问题扫描

时序：Step 4（impl agent 修复）之后、Step 5（code review）之前。

```
对每个 status=fixed 的 bug:
  
  Step 4.5.1 提取根因特征:
    从 root_cause + files_changed[*].changes 提取 2-3 个 grep 模式（impl agent 输出）:
      - 涉及的方法签名（如 "getUserById(Long"）
      - 涉及的字段访问链（如 ".getTask().getType()"）
      - 错误类型 + 触发条件（如 "Optional.get() 未先 isPresent"）
    impl agent 在 Step 4 输出 YAML 时，新增字段:
      similar_patterns:
        - description: "未做 null 检查直接解引用"
          grep: "\\.getTask\\(\\)\\.[a-z]"
  
  Step 4.5.2 全仓 grep + 排除已修文件:
    Grep pattern + path=. + 排除 fixed.files_changed[*].path
    收集 similar_candidates[]
  
  Step 4.5.3 AskUserQuestion 批量确认:
    "修 #{id} 时识别出 {N} 个可能同类的位置:
       a) {file:line} {context_excerpt}
       b) ...
     选哪些一起修？[全选 / 部分（输入字母） / 都不修]"
  
  Step 4.5.4 用户选中 → 调 impl agent 第二轮（仅这些位置）:
    输出 → 追加到 fixed_list（标记 from_similar_scan: true）
  
  容错: 候选 > 20 个 → 截前 20 + 报告附"还有 N 个未审视"
```

### 7.5 新增 Step 5.5 — 浏览器验证（仅前端 bug）

时序：Step 5（code review）通过 之后、Step 6（报告）之前。

```
对每个 is_frontend_bug=true 且 status=fixed 的 bug:
  
  Step 5.5.1 确认服务已重启（前端 hot-reload 大多自动，但 vite/webpack 偶尔需手动）:
    检测 modules.{module}.start_cmd 是否含 npm/vite/webpack → 假定自动 hot-reload，等 3 秒后继续
    否则（如 Java + Thymeleaf SSR）→ AskUserQuestion: "已修代码，是否运行 /mpdev-env restart {module}？[是/已重启/跳过验证]"
    用户选"是" → Bash 执行 /mpdev-env restart 等价命令
  
  Step 5.5.2 调 probe-browser intent=verify:
    传入 reproduction_result 的 screenshot/console_errors 作对照
  
  Step 5.5.3 判定:
    verify.repro_confirmed=false → bug.verified = true     ✅
    verify.repro_confirmed=true  → bug.verified = false    ❌ 仍复现
                                    → AskUserQuestion: [回 Step 4 再修 / 标 cannot_fix / 强制通过]
```

### 7.6 报告字段扩展

单 bug 报告 frontmatter 增加：
```yaml
repro_state: confirmed | diverged | skipped
verified: true | false | not_applicable
verification_method: browser | http | db | none
similar_fixes_count: N
```

报告正文增加 3 个章节：**复现证据**（嵌截图/curl/SQL）、**同类位置**（Step 4.5 一并修的列表）、**验证结果**（前后对照）。

批量总览的统计表新增列：
```markdown
| 模块 | 总数 | ✅ fixed&verified | ⚠️ fixed未验证 | ❌ cannot_fix |
```

### 7.7 `allowed-tools` 改造

```yaml
allowed-tools: Agent, Read, Grep, Glob, Bash, TodoWrite, Write, Edit, AskUserQuestion,
               mcp__playwright__*, mcp__mysql__*
```

## 8. `/mpdev-understand` 改造点

### 8.1 新增 Step 4.6 — DB 字典查询

时序：现有 "第 2 轮（接口边界）" 完成后、"第 3 轮（核心业务流）" 之前。

```
对每个 SCOPE 模块:
  Step 4.6.1 判断是否有 DB:
    Phase A: 读 .claude-notes/{module}/round2.md "DB schema" 节，找 MySQL/PostgreSQL 关键字
    Phase B（兜底）: Grep "datasource|jdbc:|database:" path={module_dir}/**/application*.yml + config*.yml + settings.py
    任一命中即视为有 DB；都未命中 → 跳过该模块
  
  Step 4.6.2 调 probe-db intent=query-dict
  
  Step 4.6.3 结果归档:
    成功 → 写 .claude-notes/{module}/dict-snapshots.md
    失败 → 在 round2.md 末尾追加 "字典查询跳过：{reason}"，不阻塞
```

字典识别按表名模式（不固化白名单）：`dict_*` / `*_dict` / `type_*` / `*_type` / `enum_*` / `*_enum` / 含 `status|state|role|category|level|priority`。每表 `SELECT * LIMIT 100`；超 100 行注 `totalRows=N`。

### 8.2 新增 Step 4.7 — WS 静态扫描

```
对每个 SCOPE 模块:
  Step 4.7.1 调 probe-ws → 输出 .claude-notes/{module}/ws-endpoints.md
  Step 4.7.2 在 round2.md "接口边界"节追加 WebSocket 子节（摘要）
```

### 8.3 round2.md 笔记结构调整

```markdown
# round2.md
## REST API（原有）
## MQ 事件（原有）
## DB Schema（原有 + 加链接到 dict-snapshots.md）
## WebSocket 端点（新增）              ← 从 ws-endpoints.md 摘要
## 外部 HTTP 调用（原有）
```

### 8.4 Step 7 合成 CLAUDE.md — 加 2 个区块

在原有"内部字段"区块下添加：

```markdown
4. 内部字段
   4a. WebSocket 端点              ← 从 round2 的 WS 节抽
   4b. 字典常量                    ← 从 dict-snapshots 抽（仅表名+用途+引用，不嵌全表）
```

CLAUDE.md 中的字典常量形态：
```markdown
## 字典常量
| 字典表           | 用途           | 值数量 | 详细快照 |
|------------------|---------------|------:|---------|
| dict_task_type   | 任务类型枚举   | 8     | [snapshots](.claude-notes/.../dict-snapshots.md#dict_task_type) |
```

### 8.5 `allowed-tools` 改造

```yaml
allowed-tools: Read, Grep, Glob, Bash, TodoWrite, Write, Edit, AskUserQuestion,
               mcp__mysql__*
```

## 9. 凭据管理

### 9.1 文件 schema

`.claude/.mpdev-runtime-creds.yml`（gitignored）：

```yaml
# DO NOT COMMIT — DB / API tokens for runtime probes
# Generated by mpdev probes, kept in .gitignore
version: 1
modules:
  java-backend:
    db:
      username: root
      password: "******"
      database: mr_ult
    api:
      auth_token: "Bearer eyJ..."
  dispatch:
    db:
      username: dispatch_user
      password: "******"
      database: dispatch_db
```

### 9.2 生命周期

- 探针 read-or-prompt：定位不到 `modules.{module}.{type}` → AskUserQuestion → 写回
- 用户可手动预填（避免首次跑 fix/understand 时被打断）
- 凭据失效（连接 401/403）→ 提示用户编辑 creds → 重试 1 次仍失败 → `skipped`
- **从不写入** 报告 / CLAUDE.md / mpdev-runs 任何归档

### 9.3 gitignore 注入

install.sh / install.ps1 在项目 `.gitignore` 追加（已有则跳过）：
```
.claude/.mpdev-runtime-creds.yml
.claude/.mpdev-env-state.yml
.claude-notes/
```

## 10. 错误处理矩阵

| 失败场景 | 软门行为 | 报告标注 |
|---------|---------|---------|
| state.yml 不存在 | 探针返回 `skipped`，提示 `/mpdev-env start` | `⚠️ 环境未初始化，跳过运行时复现` |
| 凭据缺失（首次） | AskUserQuestion 收集 → 写 creds.yml | （正常流程） |
| 凭据失效（401/403） | 提示编辑 creds.yml → 重试 1 次 → 失败则 `skipped` | `⚠️ 凭据失效` |
| DB 连接超时（10s） | `skipped` | `⚠️ DB 不可达（{host}:{port}）` |
| 服务未启动（probe-http/browser） | `skipped` | `⚠️ 服务未启动`，附 `/mpdev-env restart {module}` 建议 |
| Playwright 操作超时 | 截当前页面 + `repro_state=diverged` | `⚠️ 浏览器操作未完成，但已截图` |
| Step 4.5 同类扫描 0 命中 | 跳过用户确认，继续 | （无标注） |
| Step 4.5 同类扫描 > 20 命中 | 截前 20 让用户确认，剩余只列文件名 | 报告附"还有 N 个未审视" |
| Step 5.5 验证仍复现 | AskUserQuestion → [回 Step 4 / cannot_fix / 强制通过] | `⚠️ 修复后浏览器仍可复现` |
| 字典表 > 100 行 | 取前 100，注 `totalRows=N` | snapshot 里注明 |

## 11. 测试策略（人工验收剧本）

实现完成后按这 6 个剧本逐一验证：

1. **fix 软门**：在未启动服务的目录跑 `/mpdev-fix java NPE at X.java:123` → 报告含"⚠️ 服务未启动，跳过复现"，但仍走完静态分析
2. **fix 全链路前端**：启动 vue-frontend，跑 `/mpdev-fix vue 下拉框缺 night_patrol` → 启 playwright 复现 → 修代码 → 重启前端 → 二次 playwright 验证 → 报告含前后截图
3. **fix 同类扫描**：构造含 NPE 的方法 + 另外 2 处类似 → fix 修主 bug → 扫到 2 处候选 → 用户选"全选" → 一并修
4. **understand 字典**：清空 `.mpdev-runtime-creds.yml`，跑 `/mpdev-understand only=java` → 第 2 轮触发 AskUserQuestion 收凭据 → 生成 dict-snapshots.md → CLAUDE.md 含"字典常量"区块
5. **understand WS**：在含 `@OnMessage` 的 Java 项目跑 understand → CLAUDE.md "内部字段 > WebSocket 端点"节有内容
6. **凭据隔离**：grep `mpdev-runs/` 和所有 `CLAUDE.md`，不应出现 creds.yml 里的密码字符串

## 12. 影响与风险

### 12.1 兼容性

- 现有 `/mpdev-fix` / `/mpdev-understand` 调用方式不变
- 报告格式向后兼容（新字段都是追加）
- 旧版本生成的 CLAUDE.md 在升级后下次跑 understand 时自动补"字典常量"和"WebSocket 端点"区块（合成轮会读现有 CLAUDE.md 的"已知隐含知识"区块保留）

### 12.2 风险点

- **playwright MCP 启动开销**：每次 fix 流程涉及前端 bug 会启动 chromium，比纯文本流程慢 30-60s。缓解：仅 frontend bug 触发。后续若实测仍嫌重，可加 `--no-browser` flag 跳过（不在本期范围）
- **凭据文件忘记 gitignore**：install 自动注入，但用户在 install 后才手工建仓的情况会漏。缓解：探针每次写 creds.yml 时检查 `.gitignore` 是否含本文件，缺则警告
- **同类扫描的假阳性**：grep 模式可能误伤无关代码。缓解：必须用户确认 + impl agent 二次修复时仍走 root_cause 判断，不强制修
- **WS 静态扫描语言覆盖不全**：当前覆盖 Java/Python/Node/Vue，Go/Rust 等未覆盖。缓解：在 probe-ws.md 中标注"未覆盖语言返回 no-endpoints"，未来按需补

### 12.3 不在本期范围

- 动态 WS 监听（连真实 WS 端点观察消息流）—— 后续可作为 probe-ws-live.md 补充
- API 凭据自动刷新（仅手动维护 creds.yml）
- 多数据库实例切换（一个模块只能有一组 DB 凭据；分库分表场景需用户预填多组）
- **纯后端 bug 的自动验证**：Step 5.5 仅覆盖前端 bug。后端 bug 修复后由用户在 `/mpdev-commit` 前自行 curl 验证，或后续扩展 probe-http 增加 verify-fix intent

## 13. 实施顺序建议（供 writing-plans 参考）

1. 先建 `templates/runtime-probe/` 4 个文件 + README（独立可测）
2. 改 `mpdev-fix.md` 接入 Step 2.5 / 4.5 / 5.5（最痛的需求先满足）
3. 改 `mpdev-understand.md` 接入 Step 4.6 / 4.7
4. 改 install.sh / install.ps1 / update.sh / update.ps1
5. CHANGELOG + VERSION bump
6. 跑测试剧本 1-6 逐一确认

每一步建议独立 PR，便于回滚。
