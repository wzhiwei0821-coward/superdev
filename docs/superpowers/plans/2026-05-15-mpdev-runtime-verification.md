# mpdev 运行时验证 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `/mpdev-fix` 和 `/mpdev-understand` 升级为「静态分析 → 运行时验证 → 推理 → 再验证」闭环，新增 4 个独立探针（DB / HTTP / Playwright / WS 静态扫描）作为通用子能力。

**Architecture:** 在 `mpdev-suite/.claude/templates/runtime-probe/` 抽出 5 个独立 markdown 探针文件，作为 fix/understand 的可复用子能力。fix 加 3 个 Step（复现 / 同类扫描 / 浏览器验证），understand 加 2 个 Step（字典查询 / WS 端点）。所有探针失败时软门降级 + 报告标注 ⚠️，凭据存于 gitignored `.mpdev-runtime-creds.yml`。

**Tech Stack:** Markdown skill files (Claude Code interpreted); Bash + PowerShell installers; MCP tools `mcp__mysql__*` + `mcp__playwright__*`; YAML state files.

**Spec:** [`docs/superpowers/specs/2026-05-15-mpdev-runtime-verification-design.md`](../specs/2026-05-15-mpdev-runtime-verification-design.md)

---

## File Structure

### 新增（套件分发；项目零侵入）

| 路径 | 责任 | 行数预估 |
|------|------|----------|
| `mpdev-suite/.claude/templates/runtime-probe/README.md` | 探针总览 / 命名约定 / 调用契约 | ~80 |
| `mpdev-suite/.claude/templates/runtime-probe/probe-db.md` | MySQL 连接 + 字典查询 + 复现/验证 SQL | ~180 |
| `mpdev-suite/.claude/templates/runtime-probe/probe-http.md` | HTTP 探测（curl 触发 endpoint） | ~120 |
| `mpdev-suite/.claude/templates/runtime-probe/probe-browser.md` | Playwright 复现/验证 | ~150 |
| `mpdev-suite/.claude/templates/runtime-probe/probe-ws.md` | WebSocket 端点静态 grep | ~140 |

### 修改

| 路径 | 修改内容 |
|------|----------|
| `mpdev-suite/.claude/commands/mpdev-fix.md` | frontmatter + Step 0.3 + 新增 Step 2.5/4.5/5.5 + Step 6 报告字段 |
| `mpdev-suite/.claude/commands/mpdev-understand.md` | frontmatter + 新增 Step 4.6/4.7 + Step 5.6 round2 笔记格式 + Step 7 CLAUDE.md 区块 |
| `mpdev-suite/scripts/install.sh` | gitignore 注入 + runtime-probe/ 已自动拷贝（无需改） |
| `mpdev-suite/scripts/install.ps1` | 同上 |
| `mpdev-suite/scripts/update.sh` | 把 `runtime-probe/` 加入框架覆盖列表 |
| `mpdev-suite/scripts/update.ps1` | 同上 |
| `mpdev-suite/VERSION` | `1.2.0` → `1.3.0` |
| `mpdev-suite/CHANGELOG.md` | 新增 `## [1.3.0]` 段 |

---

## Task 1: 创建 runtime-probe/README.md

**Files:**
- Create: `mpdev-suite/.claude/templates/runtime-probe/README.md`

- [ ] **Step 1: 创建文件**

写入完整内容：

```markdown
# runtime-probe — 运行时探针子能力

mpdev-suite v1.3.0 引入。被 `/mpdev-fix` 和 `/mpdev-understand` 调用，用来从真实环境采集事实，避免静态分析瞎猜。

## 4 个探针

| 文件 | 用途 | 调用方 |
|------|------|--------|
| `probe-db.md` | 连 DB 查字典 / 复现 / 验证 | fix Step 2.5, 5.5; understand Step 4.6 |
| `probe-http.md` | curl 触发 endpoint 复现 | fix Step 2.5 |
| `probe-browser.md` | Playwright 复现/验证前端 | fix Step 2.5, 5.5 |
| `probe-ws.md` | WS 端点 + 消息类型静态扫描 | understand Step 4.7 |

## 通用调用契约

调用方（命令文件）通过 `Read .claude/templates/runtime-probe/probe-{name}.md` 加载探针，按其中"步骤"节执行，并按"输入"节准备上下文变量。

每个探针返回 YAML 块给调用方，必含：

```yaml
status: ok | skipped | conn-failed | <probe-specific-errors>
error: "..."           # 仅失败时
```

调用方根据 `status`：
- `ok`: 使用 evidence/结果
- `skipped` / 其他失败: 进入软门降级（继续静态分析 + 报告标注 ⚠️）

## 凭据约定

DB / API token 等敏感信息存于 `.claude/.mpdev-runtime-creds.yml`（项目 .gitignore）。
- 文件不存在 / 缺该模块节 → 探针 AskUserQuestion 收集 → 写回
- 凭据失效 → 提示用户编辑文件 → 重试 1 次 → 失败则 `skipped`
- **绝不**写入归档报告 / CLAUDE.md / mpdev-runs

## 通用约束

1. 探针**只读不改**项目代码（probe-browser 的页面交互除外，状态不持久）
2. 探针**不调其他探针**（避免嵌套递归）
3. 探针超时设 10s（probe-browser 30s）
4. 探针**不写入** 任何 mpdev-runs 文件 — 只写 `.claude-notes/` 下的 snapshots
```

- [ ] **Step 2: 提交**

```bash
cd F:/claude/superdev && git add mpdev-suite/.claude/templates/runtime-probe/README.md && git commit -m "feat(runtime-probe): add probes README

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: 创建 probe-db.md

**Files:**
- Create: `mpdev-suite/.claude/templates/runtime-probe/probe-db.md`

- [ ] **Step 1: 写入完整内容**

```markdown
# probe-db — DB 连接探针

被 fix/understand 调用，连项目数据库做查询。3 种用途：
- `query-dict`：扫字典表（understand 用）
- `reproduce`：按 bug 描述拼定向 SELECT（fix 用）
- `verify-fix`：与 reproduce 阶段保存的查询对比（fix 用）

## 输入（调用方提供）

| 变量 | 必填 | 含义 |
|------|------|------|
| `module` | 是 | 模块名（state.yml 定位 DB 连接） |
| `intent` | 是 | `query-dict` / `reproduce` / `verify-fix` |
| `query_hint` | 否 | bug 描述里的表名/列名/错误关键词 |
| `batch_id` | 否 | 复现 trace 归档 ID（fix 批量场景） |

## 步骤

### 1. 加载环境元数据

```
Read .claude/.mpdev-env-state.yml
找 middleware[].type=mysql 节 → host / port
找 modules[name={module}].directory → 模块根目录（备用）
若 state.yml 不存在 → 返回 status=skipped, error="no state.yml, run /mpdev-env start first"
```

### 2. 加载或收集凭据

```
Read .claude/.mpdev-runtime-creds.yml （文件可能不存在）
查 modules.{module}.db 节
若节缺失:
  AskUserQuestion 收集:
    - username [模块 {module} 的 MySQL 用户名]
    - password [密码（不会展示在报告里）]
    - database [数据库名，缺省自动取 state.yml 中的 mysql 默认]
  写回 creds.yml（保留其他节不动）
```

### 3. 选择 SQL 客户端（按优先级）

```
策略 A: 优先 mcp__mysql__execute_query
  - 若 MCP 配的 host:port:db 与目标一致 → 用 MCP
  - 不一致 → 跳到策略 B
  
策略 B: 降级到 Bash mysql CLI
  Bash("which mysql") → 有 → 用 Bash 调
  
策略 C: 都不可用
  返回 status=skipped, error="no mysql client available; install mysql CLI or configure MCP"
```

### 4. 按 intent 执行查询

#### intent=query-dict

```
1. SHOW TABLES → 拿表名列表
2. 匹配字典模式（任一即视为字典表）:
   - 以 dict_ 开头 或 _dict 结尾
   - 以 type_ 开头 或 _type 结尾
   - 以 enum_ 开头 或 _enum 结尾
   - 含 status / state / role / category / level / priority
3. 对每个匹配表:
   SELECT COUNT(*) FROM {table};
   若 count <= 100 → SELECT * FROM {table};
   若 count > 100 → SELECT * FROM {table} LIMIT 100;（注 totalRows={count}）
4. 写 .claude-notes/{module}/dict-snapshots.md:
   每表一节，含 markdown 表格 + （若截断）totalRows 注释
```

#### intent=reproduce

```
1. 解析 query_hint:
   - 包含 SQL 关键字 → 直接当作 SQL（移除危险动词：DROP/DELETE/UPDATE/TRUNCATE 后才执行）
   - 包含表名 + 列名 → 拼 SELECT
   - 仅含错误关键词 → 返回 status=skipped, error="cannot infer query from hint"
2. 执行查询 → 拿结果
3. 存档到 .claude-notes/repro/{batch_id|"single"}/db-{timestamp}.sql:
   含查询语句 + 结果（前 50 行）
```

#### intent=verify-fix

```
1. 读 .claude-notes/repro/{batch_id|"single"}/db-{timestamp}.sql 中的查询语句
2. 重跑同一查询
3. 对比两次结果 → repro_confirmed:
   - 行数不变 + 关键列值不变 → false（bug 仍存在）
   - 行数变化 / 错误数据消失 → true（修复生效）
```

### 5. 返回结果

```yaml
status: ok | no-creds | conn-failed | query-failed | skipped
evidence:
  - table: dict_task_type   # 仅 query-dict
    rows_sample: [...]
    total_rows: 8
notes_path: .claude-notes/{module}/dict-snapshots.md  # 仅 query-dict
repro_path: .claude-notes/repro/.../db-....sql        # 仅 reproduce
repro_confirmed: true | false                         # 仅 verify-fix
error: "..."                                          # 仅失败
```

## 错误处理

| 失败 | status | 说明 |
|------|--------|------|
| state.yml 不存在 | skipped | "no state.yml" |
| 凭据收集后仍连不上 | conn-failed | 重试 1 次后返回 |
| SQL 语法错误 | query-failed | 返回 mysql 报错首行 |
| query_hint 无法推断 | skipped | "cannot infer query" |
| 10s 超时 | conn-failed | "timeout" |

## 安全约束

- 凭据**只**写 `.claude/.mpdev-runtime-creds.yml`
- **不**在返回的 YAML 中包含密码字段
- **不**对 query_hint 中的危险 SQL 关键字（DROP/DELETE/UPDATE/TRUNCATE/ALTER/INSERT）执行——遇到直接 status=skipped, error="dangerous SQL refused"
```

- [ ] **Step 2: 提交**

```bash
cd F:/claude/superdev && git add mpdev-suite/.claude/templates/runtime-probe/probe-db.md && git commit -m "feat(runtime-probe): add probe-db (dict / reproduce / verify-fix)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: 创建 probe-http.md

**Files:**
- Create: `mpdev-suite/.claude/templates/runtime-probe/probe-http.md`

- [ ] **Step 1: 写入完整内容**

```markdown
# probe-http — HTTP 探针

被 fix 调用，curl 触发 endpoint 来复现后端 bug。

## 输入

| 变量 | 必填 | 含义 |
|------|------|------|
| `module` | 是 | 模块名（state.yml 定位端口） |
| `endpoint` | 是 | 完整路径，如 `/api/task/create` |
| `method` | 是 | GET / POST / PUT / DELETE |
| `payload_hint` | 否 | POST/PUT body（JSON 字符串或片段） |
| `batch_id` | 否 | 复现 trace 归档 ID |

## 步骤

### 1. 拼接 base URL

```
Read .claude/.mpdev-env-state.yml
找 modules[name={module}].port → port
找 modules[name={module}].health_check → 提取 host（多为 localhost / 127.0.0.1）
base_url = "http://{host}:{port}"
若 modules 节缺失 → status=skipped, error="module not in state.yml, run /mpdev-env start first"
```

### 2. 加载 auth token（可选）

```
若 endpoint 含 "auth required" 提示 或 调用方传了 require_auth=true:
  Read .claude/.mpdev-runtime-creds.yml
  查 modules.{module}.api.auth_token
  若缺失:
    AskUserQuestion: "{module} 的 API endpoint {endpoint} 需要鉴权 token 吗？
      [是 / 否（无需 token） / 跳过此探针]"
    选"是" → 收集 token（粘贴整段 "Bearer xxx" 或纯 jwt）→ 写回 creds.yml
    选"否" → 不带 header
    选"跳过" → status=skipped
```

### 3. 执行 curl

```
构造命令:
  Bash("curl -i -s -m 10 -X {method} {auth_header} -H 'Content-Type: application/json' -d '{payload_hint}' {base_url}{endpoint}")

注: payload_hint 为空时省略 -d 和 Content-Type
注: -m 10 是 10s 超时
```

### 4. 解析响应

```
拆头部 + body:
  status_code = 取第一行 HTTP/1.1 后的数字
  headers = 拿到首个空行之前
  body = 空行之后（截前 200 行 / 8192 字节）

error_signature 提取:
  若 body 含 "Exception" / "Error" / "stacktrace" → 取首行作为 signature
  若 status_code >= 500 → "HTTP {status_code}: {body 第一行}"
  否则 → null
```

### 5. 归档

```
写 .claude-notes/repro/{batch_id|"single"}/http-{timestamp}.log:
  含完整 curl 命令 (脱敏 auth_header 为 Bearer ***) + 响应头 + 响应 body
```

### 6. 返回

```yaml
status: ok | conn-refused | timeout | skipped
status_code: 500
error_signature: "NullPointerException at TaskServiceImpl:127"
response_excerpt: "..."  # 前 8KB
repro_path: .claude-notes/repro/.../http-....log
error: "..."  # 仅失败
```

## 错误处理

| 失败 | status | 说明 |
|------|--------|------|
| 服务未启动（curl: Failed to connect） | conn-refused | 提示 `/mpdev-env restart {module}` |
| 10s 超时 | timeout | "request timeout" |
| state.yml 缺模块 | skipped | "module not in state.yml" |
| 用户选不带 auth + endpoint 返 401/403 | ok | 仍返回，由调用方判断 |

## 安全约束

- auth_token **只**写 `.mpdev-runtime-creds.yml`
- 归档日志中 Authorization header **必须脱敏**（替换为 `Bearer ***`）
- 不接受危险 method（PATCH/DELETE/PUT）若 endpoint 含 admin / config / system 关键字 → AskUserQuestion 确认
```

- [ ] **Step 2: 提交**

```bash
cd F:/claude/superdev && git add mpdev-suite/.claude/templates/runtime-probe/probe-http.md && git commit -m "feat(runtime-probe): add probe-http (endpoint trigger via curl)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: 创建 probe-browser.md

**Files:**
- Create: `mpdev-suite/.claude/templates/runtime-probe/probe-browser.md`

- [ ] **Step 1: 写入完整内容**

```markdown
# probe-browser — Playwright 探针

被 fix 调用，启浏览器复现/验证前端 bug。基于 `mcp__playwright__*` 工具。

## 输入

| 变量 | 必填 | 含义 |
|------|------|------|
| `module` | 是 | 模块名（state.yml 定位前端 URL） |
| `bug_description` | 是 | bug 描述全文（LLM 据此自由探索） |
| `intent` | 是 | `reproduce` / `verify` |
| `entry_url` | 否 | 自定义入口（缺省从 state.yml health_check 取根） |
| `batch_id` | 否 | trace 归档 ID |

## 步骤

### 1. 解析入口 URL

```
若 entry_url 已传 → 用之
否则:
  Read .claude/.mpdev-env-state.yml
  找 modules[name={module}].health_check
  若是 curl URL（如 "curl -sf http://localhost:8080/"） → 提取 http://localhost:8080
  否则取 modules[name={module}].port → http://localhost:{port}
  
若仍取不到 → status=skipped, error="cannot resolve entry_url"
```

### 2. 启浏览器

```
mcp__playwright__playwright_navigate(url=entry_url, browserType="chromium", timeout=10000)
失败（navigate-failed / 服务未启动） → status=conn-refused
                                     建议: "运行 /mpdev-env restart {module}"
```

### 3. 自由探索（LLM 主导）

```
调用方（impl agent）按 bug_description 推断复现路径，使用 playwright 工具:
  - mcp__playwright__playwright_click(selector=...)
  - mcp__playwright__playwright_fill(selector=..., value=...)
  - mcp__playwright__playwright_select(selector=..., value=...)
  - mcp__playwright__playwright_press_key(key=...)

每步操作后:
  - 必要时 mcp__playwright__playwright_get_visible_text() 确认页面状态
  - 出现疑似 bug 现象 → 跳到 Step 4

时长上限: 30s（intent=reproduce） / 60s（intent=verify，因要走更长路径）
超过上限 → 截当前状态 + repro_confirmed=false (intent=reproduce) / verified=false (intent=verify)
```

### 4. 抓取证据

```
路径前缀:
  reproduce: .claude-notes/repro/{batch_id|"single"}/bug-{id}-reproduce-{ts}
  verify:   .claude-notes/repro/{batch_id|"single"}/bug-{id}-verify-{ts}

抓取:
  mcp__playwright__playwright_screenshot(name="{prefix}.png", fullPage=true, savePng=true,
                                          downloadsDir=".claude-notes/repro/{batch_id}/")
  mcp__playwright__playwright_console_logs(type="error", limit=20) → 存 {prefix}.console.txt
```

### 5. 判定 repro_confirmed

#### intent=reproduce

```
LLM 据 bug_description 判断:
  - console errors 含 bug 描述中提到的错误码/字段 → true
  - 页面文本含 bug 描述中提到的现象（"白屏"/"找不到下拉项"等）→ true
  - 页面截图明显异常（空白 / 错误提示）→ true
  - 否则 → false（diverged - 没复现到预期现象）
```

#### intent=verify

```
读 reproduce 阶段保存的 {prefix=...-reproduce-*}.console.txt 作为对照基线:
  - 同样的 console error 仍存在 → repro_confirmed=true（bug 没修好）
  - 之前的 error 消失 + 页面正常 → repro_confirmed=false（修复生效，verified=true）
```

### 6. 关闭浏览器

```
mcp__playwright__playwright_close()
```

### 7. 返回

```yaml
status: ok | navigate-failed | conn-refused | timeout | skipped
screenshot_path: .claude-notes/repro/.../bug-1-reproduce-20260515-1430.png
console_errors:
  - "Uncaught TypeError: Cannot read property 'taskType' of undefined"
network_errors: []                                 # 来自 playwright_console_logs type=error
repro_confirmed: true | false                      # reproduce intent 时表示"复现到 bug"
                                                    # verify intent 时表示"bug 仍存在"
error: "..."                                       # 仅失败
```

## 错误处理

| 失败 | status | 说明 |
|------|--------|------|
| 服务未启动 | conn-refused | "navigate failed, run /mpdev-env restart {module}" |
| 30s/60s 自由探索超时 | timeout（但仍返回 status=ok + repro_confirmed=false） | 截当前页面，让调用方判断 |
| state.yml 缺前端模块 | skipped | "cannot resolve entry_url" |
| Playwright MCP 未配置 | skipped | "playwright MCP unavailable" |

## 注意事项

- impl agent 自由探索的步骤**不超过 15 步**（点击/填表加起来）
- 每个 mcp__playwright__* 调用失败 → 截当前页面 + 进入失败返回
- 浏览器**始终关闭**（finally 语义）
```

- [ ] **Step 2: 提交**

```bash
cd F:/claude/superdev && git add mpdev-suite/.claude/templates/runtime-probe/probe-browser.md && git commit -m "feat(runtime-probe): add probe-browser (playwright reproduce/verify)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 创建 probe-ws.md

**Files:**
- Create: `mpdev-suite/.claude/templates/runtime-probe/probe-ws.md`

- [ ] **Step 1: 写入完整内容**

```markdown
# probe-ws — WebSocket 静态扫描探针

被 understand 调用，**纯静态 grep**——不连真实 WS 端点。

## 输入

| 变量 | 必填 | 含义 |
|------|------|------|
| `module` | 是 | 模块名（决定扫描根目录 + 使用的 grep 模式） |
| `module_dir` | 否 | 模块根目录（缺省从 state.yml 取） |

## 步骤

### 1. 决定扫描语言

```
读 state.yml 或 module/CLAUDE.md "技术栈" 节判定:
  - Java/Spring → 用 Java 模式
  - Python (FastAPI/Starlette/Sanic/python-socketio) → Python 模式
  - Node (ws / socket.io) → Node 模式
  - Vue / React / 前端 → Frontend 模式

未识别语言 → status=skipped, error="unknown language"
```

### 2. 按语言并行 grep

#### Java 模式

```bash
# 端点声明
Grep "@ServerEndpoint" type=java path={module_dir}
Grep "@OnMessage" type=java path={module_dir}
Grep "extends TextWebSocketHandler|extends AbstractWebSocketHandler" type=java path={module_dir}
Grep "WebSocketHandler" type=java path={module_dir}
# STOMP 注解（如要包含 STOMP）
Grep "@MessageMapping|@SubscribeMapping|@SendTo" type=java path={module_dir}
```

#### Python 模式

```bash
Grep "@sio\.on\(|@socketio\.on\(" type=py path={module_dir}
Grep "websockets\.serve\(" type=py path={module_dir}
Grep "@app\.websocket\(|@router\.websocket\(" type=py path={module_dir}   # FastAPI
Grep "fastapi\.WebSocket" type=py path={module_dir}
```

#### Node 模式

```bash
Grep "new WebSocket\.Server|new WebSocketServer" type=js path={module_dir}
Grep "ws\.on\('message'|ws\.on\(\"message\"" type=js path={module_dir}
Grep "io\.on\('connection'|io\.on\(\"connection\"" type=js path={module_dir}
```

#### Frontend 模式

```bash
Grep "new WebSocket\(" type=js path={module_dir}
Grep "new WebSocket\(" type=ts path={module_dir}
Grep "io\(.*['\"]ws|socket\.io-client" type=js path={module_dir}
```

### 3. 提取消息类型

对每个命中的 handler 位置:

```
读 handler 文件 ±30 行上下文
找:
  - @OnMessage 参数类型 → 消息 DTO 类名
  - 紧邻的 class 或 schema 定义 → 关联 DTO
  - 字符串 literal 形如 "task.created" / "TASK_CREATED" → event name
  - 注释里的 schema 描述 → payload schema

对找到的 DTO 类名:
  Glob "**/{ClassName}.java"  # Java 同 DTO 命名规则
  Glob "**/{ClassName}.ts"    # 前端 / Node 单独 DTO 文件
  Read 找到的文件 → 提取字段列表
```

### 4. 判定方向

```
- @ServerEndpoint + @OnMessage → bidirectional
- @SubscribeMapping / @SendTo → server_push
- ws.send() 调用频繁 + ws.on('message') 少 → server_push
- ws.send() 与 on('message') 都有 → bidirectional
- 调用方为客户端（new WebSocket） + 仅监听 onmessage → server_push（从服务端看）
```

### 5. 写入归档

```
Write .claude-notes/{module}/ws-endpoints.md:

# {module} WebSocket 端点

## 端点列表

| 路径 | handler | 方向 | 消息类型数 |
|------|---------|------|----------:|
| /ws/task-events | TaskEventsHandler.java:45 | bidirectional | 3 |

## /ws/task-events

handler: `src/main/java/com/example/ws/TaskEventsHandler.java:45`
direction: bidirectional

### 消息类型

#### task.created
- 方向: server → client
- DTO: `com.example.dto.TaskCreatedEvent`
- 字段:
  | 字段 | 类型 | 必填 | 说明 |
  | id | Long | 是 | 任务 ID |
  | taskType | String | 是 | 任务类型（见 dict_task_type） |
  ...

#### task.updated
...
```

### 6. 返回

```yaml
status: ok | no-endpoints | skipped
endpoints:
  - path: /ws/task-events
    handler: TaskEventsHandler.java:45
    direction: bidirectional
    messages:
      - event: task.created
        schema: TaskCreatedEvent (com.example.dto.TaskCreatedEvent)
        fields_count: 5
notes_path: .claude-notes/{module}/ws-endpoints.md
error: "..."  # 仅失败
```

## 错误处理

| 失败 | status | 说明 |
|------|--------|------|
| 模块语言未识别 | skipped | "unknown language" |
| 所有 grep 模式 0 命中 | no-endpoints | "no WebSocket endpoints found" |
| handler 文件不可读 | ok（部分） | 该端点 messages 留空，notes 中标注"无法提取消息类型" |

## 限制

- 当前**未覆盖** Go / Rust / C# 的 WS 模式（后续补充）
- 动态注册的端点（如 `WebSocketHandlerRegistry.addHandler(path)`）能扫到 handler 但路径可能为变量名 — 标注 "path: ${variable}"
```

- [ ] **Step 2: 提交**

```bash
cd F:/claude/superdev && git add mpdev-suite/.claude/templates/runtime-probe/probe-ws.md && git commit -m "feat(runtime-probe): add probe-ws (static WebSocket scanner)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: 验证 probe 文件可读

**Files:**
- Verify: 所有 5 个新 probe 文件

- [ ] **Step 1: 验证文件存在 + 行数合理**

```bash
cd F:/claude/superdev
ls -la mpdev-suite/.claude/templates/runtime-probe/
wc -l mpdev-suite/.claude/templates/runtime-probe/*.md
```

Expected: 5 个文件 (README.md, probe-db.md, probe-http.md, probe-browser.md, probe-ws.md)，每个 80-200 行。

- [ ] **Step 2: 验证 frontmatter / markdown 结构合法**

```bash
cd F:/claude/superdev
for f in mpdev-suite/.claude/templates/runtime-probe/*.md; do
  echo "=== $f ==="
  head -5 "$f"
done
```

Expected: 每个文件开头是合法 markdown，含 `# <title>` 标题行。

- [ ] **Step 3: 验证 git 记录干净**

```bash
cd F:/claude/superdev && git log --oneline -7
```

Expected: 看到 5 个 `feat(runtime-probe)` commit 加上前面的 spec commit。

---

## Task 7: mpdev-fix.md — 更新 frontmatter + Step 0.3 加 is_frontend_bug

**Files:**
- Modify: `mpdev-suite/.claude/commands/mpdev-fix.md` (frontmatter 行 1-5, Step 0.3 周边)

- [ ] **Step 1: 改 allowed-tools 行**

把原行（第 4 行）：
```yaml
allowed-tools: Agent, Read, Grep, Glob, Bash, TodoWrite, Write, Edit, AskUserQuestion
```

改为：
```yaml
allowed-tools: Agent, Read, Grep, Glob, Bash, TodoWrite, Write, Edit, AskUserQuestion, mcp__playwright__*, mcp__mysql__*
```

使用 Edit 工具：
- old_string: `allowed-tools: Agent, Read, Grep, Glob, Bash, TodoWrite, Write, Edit, AskUserQuestion`
- new_string: `allowed-tools: Agent, Read, Grep, Glob, Bash, TodoWrite, Write, Edit, AskUserQuestion, mcp__playwright__*, mcp__mysql__*`

- [ ] **Step 2: 在 Step 0.3 模块识别小节末尾插入 is_frontend_bug 判定**

找到 Step 0.3（约第 124-134 行），在该节最后一行 `5. 都不行 → module=unknown` 后追加：

old_string:
```
5. 都不行 → module=unknown（Step 1 让用户补）
```
```

new_string:
```
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
```

- [ ] **Step 3: 验证编辑成功**

```bash
cd F:/claude/superdev
grep -n "is_frontend_bug" mpdev-suite/.claude/commands/mpdev-fix.md
grep -n "mcp__playwright" mpdev-suite/.claude/commands/mpdev-fix.md
```

Expected: 各有 1 行命中。

- [ ] **Step 4: 提交**

```bash
cd F:/claude/superdev && git add mpdev-suite/.claude/commands/mpdev-fix.md && git commit -m "feat(mpdev-fix): expand allowed-tools + add is_frontend_bug field

为后续 Step 2.5/5.5 接入 playwright/mysql 探针铺路。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: mpdev-fix.md — 新增 Step 2.5（环境复现）

**Files:**
- Modify: `mpdev-suite/.claude/commands/mpdev-fix.md` (在 Step 3 之前插入)

- [ ] **Step 1: 找到 Step 3 起始位置**

```bash
cd F:/claude/superdev && grep -n "^## Step 3" mpdev-suite/.claude/commands/mpdev-fix.md
```

Expected: 输出 `## Step 3: 收集上下文（按模块组）` 所在行号（应在约第 247 行）。

- [ ] **Step 2: 在 Step 3 标题之前插入新 Step 2.5**

old_string:
```

---

## Step 3: 收集上下文（按模块组）
```

new_string:
```

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
Read .claude/templates/runtime-probe/probe-{name}.md
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
  在 bug.context 中追加引用，供 Step 4 impl agent 使用:
    repro_path: <路径>
    evidence_summary: <2-3 句关键信号摘要>
```

### 容错

| 场景 | 行为 |
|------|------|
| 探针文件不存在 | 警告 + 标 repro_state=skipped, reason="probe-{name}.md missing" |
| 服务未启动 | 探针返 conn-refused → skipped + 提示 `/mpdev-env restart {module}` |
| 凭据收集后仍连不上 | skipped + reason="creds may be stale, check .mpdev-runtime-creds.yml" |

---

## Step 3: 收集上下文（按模块组）
```

- [ ] **Step 3: 验证插入成功**

```bash
cd F:/claude/superdev
grep -n "^## Step 2.5\|^## Step 3" mpdev-suite/.claude/commands/mpdev-fix.md
```

Expected: 看到 Step 2.5 在 Step 3 之前。

- [ ] **Step 4: 提交**

```bash
cd F:/claude/superdev && git add mpdev-suite/.claude/commands/mpdev-fix.md && git commit -m "feat(mpdev-fix): add Step 2.5 environment reproduction (soft gate)

调 4 个探针之一采集运行时事实，注入到 impl agent 上下文。失败时软门降级到静态分析。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: mpdev-fix.md — 新增 Step 4.5（同类问题扫描）

**Files:**
- Modify: `mpdev-suite/.claude/commands/mpdev-fix.md` (在 Step 5 之前插入)

- [ ] **Step 1: 修改 Step 4 impl agent prompt，增加 similar_patterns 字段要求**

找 Step 4 的 YAML 输出格式（约第 304-322 行）。

old_string:
```
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
  - id: 3
    ...
shared_root_cause: null | "多个 bug 共享根因的描述"
cross_module_issue: null | "其他模块也需改的描述"
```
```

new_string:
```
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
```

- [ ] **Step 2: 找 Step 5 起始位置**

```bash
cd F:/claude/superdev && grep -n "^## Step 5: 整批 Code Review" mpdev-suite/.claude/commands/mpdev-fix.md
```

Expected: 行号约 343。

- [ ] **Step 3: 在 Step 5 之前插入新 Step 4.5**

old_string:
```

---

## Step 5: 整批 Code Review
```

new_string:
```

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
```

- [ ] **Step 4: 验证**

```bash
cd F:/claude/superdev
grep -n "^## Step 4.5\|^## Step 5" mpdev-suite/.claude/commands/mpdev-fix.md
grep -n "similar_patterns" mpdev-suite/.claude/commands/mpdev-fix.md
```

Expected: Step 4.5 出现在 Step 5 之前；similar_patterns 出现至少 2 处（YAML schema + Step 4.5 内）。

- [ ] **Step 5: 提交**

```bash
cd F:/claude/superdev && git add mpdev-suite/.claude/commands/mpdev-fix.md && git commit -m "feat(mpdev-fix): add Step 4.5 similar problem scan

impl agent 输出 similar_patterns → 全仓 grep → 用户确认 → 调 impl 第二轮修。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: mpdev-fix.md — 新增 Step 5.5（浏览器验证）

**Files:**
- Modify: `mpdev-suite/.claude/commands/mpdev-fix.md` (在 Step 6 之前插入)

- [ ] **Step 1: 找 Step 6 起始位置**

```bash
cd F:/claude/superdev && grep -n "^## Step 6:" mpdev-suite/.claude/commands/mpdev-fix.md
```

Expected: 输出 Step 6 行号。

- [ ] **Step 2: 在 Step 6 之前插入新 Step 5.5**

old_string:
```

---

## Step 6: 修复报告
```

new_string:
```

---

## Step 5.5: 浏览器验证（仅前端 bug，软门）

时序：Step 5 code review 通过之后、Step 6 修复报告之前。

**目的**：前端 bug 修完后，跑同一复现路径，用截图 + console errors 比对 Step 2.5 的基线，证明 bug 真的修好了。

### 5.5.1 确认服务已重启

```
对每个 is_frontend_bug=true 且 status=fixed 的 bug:
  
  Read .claude/.mpdev-env-state.yml
  找 modules[name={module}].start_cmd
  
  判定:
    含 "npm" / "vite" / "webpack" / "vue-cli-service" → 假定 hot-reload 自动
                                                       等 3 秒后继续
    其他（如 Java SSR / Python 模板）:
      AskUserQuestion:
        "代码已修，是否运行 /mpdev-env restart {module} 后再验证？
        选项: [是，自动重启 / 已手动重启 / 跳过验证]"
      选"自动重启" → Bash 执行 /mpdev-env restart 等价命令
      选"跳过验证" → bug.verified = skipped, 跳到下一个 bug
```

### 5.5.2 调 probe-browser intent=verify

```
Read .claude/templates/runtime-probe/probe-browser.md
准备输入:
  module = bug.module
  bug_description = bug.title + bug.description
  intent = "verify"
  entry_url = bug.repro_evidence.entry_url（沿用 Step 2.5 的入口）
  batch_id = 当前批次 ID
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
| 服务重启失败 | bug.verified = skipped, reason="service restart failed" |
| Playwright 在 navigate 阶段就失败 | bug.verified = skipped, reason="navigate failed" |
| verify 阶段已经走到第二轮 | 强制标 cannot_fix（防止死循环） |

---

## Step 6: 修复报告
```

- [ ] **Step 3: 验证**

```bash
cd F:/claude/superdev
grep -n "^## Step 5\.5\|^## Step 6" mpdev-suite/.claude/commands/mpdev-fix.md
```

Expected: Step 5.5 出现在 Step 6 之前。

- [ ] **Step 4: 提交**

```bash
cd F:/claude/superdev && git add mpdev-suite/.claude/commands/mpdev-fix.md && git commit -m "feat(mpdev-fix): add Step 5.5 browser verification (frontend bugs)

修完前端 bug 后调 probe-browser intent=verify，对照 Step 2.5 基线。仍复现则走 [回炉 / cannot_fix / 强制通过] 三选一。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: mpdev-fix.md — 扩展 Step 6 报告字段

**Files:**
- Modify: `mpdev-suite/.claude/commands/mpdev-fix.md` (Step 6.1 单 bug 报告 + 6.2 批量总览)

- [ ] **Step 1: 改 Step 6.1 单 bug 报告 frontmatter**

找 Step 6.1 报告模板。

old_string:
```
**单 bug 报告模板**（保留原格式，新增 `batch_id` 追溯）：

```markdown
---
fix_id: {file_id}
module: {module}
status: {fixed / cannot_fix}
generated_at: {timestamp}
batch_id: {batch_id | null}     # 批量模式才有
source_id: {bug.source | null}   # 禅道 Bug 编号（若有）
---
```

new_string:
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
```

- [ ] **Step 2: 在单 bug 报告模板 body 末尾增加 3 个新章节**

找单 bug 报告模板 body（即模板 yaml 之后的部分），定位到末尾。

old_string:
```
# 修复报告：{bug.title}

## 原始问题
> {bug.description}

## 根因
{root_cause}

## 变更文件
| 文件 | 变更 |
|------|------|
| {path} | {changes} |

## 测试
- 结果：{pass / fail / no_test}

## 所属批次
{若 batch_id 非空}: 见 [批量总览](./batch-{timestamp}.md)
```

new_string:
```
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

- [ ] **Step 3: 改 Step 6.2 批量总览统计表**

找 Step 6.2 的统计表。

old_string:
```
| 模块 | 总数 | ✅ fixed | ❌ cannot_fix |
|------|-----:|---------:|--------------:|
| java | 3 | 3 | 0 |
| vue  | 2 | 2 | 0 |
| dispatch | 1 | 0 | 1 |
| **合计** | **6** | **5** | **1** |
```

new_string:
```
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
```

- [ ] **Step 4: 验证**

```bash
cd F:/claude/superdev
grep -n "repro_state\|verified\|similar_fixes_count" mpdev-suite/.claude/commands/mpdev-fix.md
```

Expected: 多处命中。

- [ ] **Step 5: 提交**

```bash
cd F:/claude/superdev && git add mpdev-suite/.claude/commands/mpdev-fix.md && git commit -m "feat(mpdev-fix): expand Step 6 report with repro/verified/similar fields

报告 frontmatter 新增 repro_state/verified/similar_fixes_count；body 新增 3 章节（复现证据/同类位置/验证结果）；批量总览改 3 列统计。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: mpdev-understand.md — 更新 frontmatter

**Files:**
- Modify: `mpdev-suite/.claude/commands/mpdev-understand.md` (frontmatter 第 4 行)

- [ ] **Step 1: 改 allowed-tools**

old_string:
```yaml
allowed-tools: Read, Grep, Glob, Bash, TodoWrite, Write, Edit, AskUserQuestion
```

new_string:
```yaml
allowed-tools: Read, Grep, Glob, Bash, TodoWrite, Write, Edit, AskUserQuestion, mcp__mysql__*
```

- [ ] **Step 2: 验证**

```bash
cd F:/claude/superdev && grep -n "mcp__mysql" mpdev-suite/.claude/commands/mpdev-understand.md
```

Expected: 1 行命中。

- [ ] **Step 3: 提交**

```bash
cd F:/claude/superdev && git add mpdev-suite/.claude/commands/mpdev-understand.md && git commit -m "feat(mpdev-understand): expand allowed-tools with mcp__mysql

为 Step 4.6 字典查询铺路。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 13: mpdev-understand.md — 新增 Step 4.6（DB 字典查询）

**Files:**
- Modify: `mpdev-suite/.claude/commands/mpdev-understand.md` (在第 3 轮之前插入)

- [ ] **Step 1: 找第 3 轮位置（核心业务流）**

```bash
cd F:/claude/superdev && grep -n "Prompt 1-4.5\|## Step 6" mpdev-suite/.claude/commands/mpdev-understand.md
```

Expected: 看到 Step 5 / 6 等位置。需要在 Step 5（按轮次执行）末尾、Step 6（Prompt 5 验证）之前插入 4.6 / 4.7。

- [ ] **Step 2: 找 Step 6 之前**

```bash
cd F:/claude/superdev && grep -n "^## Step 6:" mpdev-suite/.claude/commands/mpdev-understand.md
```

Expected: 输出 Step 6 行号（约第 354）。

- [ ] **Step 3: 在 Step 6 之前插入新 Step 4.6**

old_string:
```
## Step 6: Prompt 5 — 验证、提问与 TODO
```

new_string:
```
## Step 5.5: Prompt 4.6 — DB 字典查询（按模块）

时序：Prompt 4.5 之后、Prompt 5（验证 + 提问）之前。

**目的**：CLAUDE.md 不能只描述 schema，要含真实字典值，方便后续 fix/dev 知道枚举有哪些。

### 5.5.1 判断模块是否有 DB

```
对每个 SCOPE 模块:
  Phase A: 读 .claude-notes/{module}/round2.md "DB schema" 节，找 MySQL/PostgreSQL/SQLite 关键字
  Phase B（兜底）: Grep "datasource|jdbc:|database:|DATABASE_URL" path={module_dir}/**/application*.yml + config*.yml + settings.py
  
  任一命中 → 视为有 DB，进入 5.5.2
  都未命中 → 跳过该模块
```

### 5.5.2 调 probe-db intent=query-dict

```
Read .claude/templates/runtime-probe/probe-db.md
准备输入:
  module = {当前模块名}
  intent = "query-dict"
按"步骤"节执行 → 拿 query_result
```

### 5.5.3 结果归档

```
match query_result.status:
  "ok":
    探针已写 .claude-notes/{module}/dict-snapshots.md
    在 round2.md 的 "DB Schema" 节末尾追加一行链接:
      "- 字典值快照: [dict-snapshots.md](./dict-snapshots.md)"
  
  "no-creds" / "conn-failed" / "skipped":
    在 round2.md 末尾追加:
      "字典查询跳过：{query_result.error}"
    继续下一个模块（不阻塞合成 Step）
```

### 容错

| 场景 | 行为 |
|------|------|
| state.yml 不存在 | 提示用户先 /mpdev-env start 或手动建 state.yml，跳过本 Step |
| 用户拒填凭据 | 探针返 skipped，本 Step 跳过 |
| 字典表 0 命中 | 探针返 status=ok 但 evidence 为空，写 "未发现字典表" 到 snapshots |

## Step 5.6: Prompt 4.7 — WebSocket 端点静态扫描

时序：5.5 之后、Step 6 之前。

### 5.6.1 调 probe-ws

```
对每个 SCOPE 模块:
  Read .claude/templates/runtime-probe/probe-ws.md
  准备输入:
    module = {当前模块名}
  按"步骤"节执行 → 拿 ws_result
```

### 5.6.2 结果归档

```
match ws_result.status:
  "ok":
    探针已写 .claude-notes/{module}/ws-endpoints.md
    在 round2.md "接口边界" 节追加 "WebSocket 端点" 子节，含摘要表（路径 + handler + 方向 + 消息数）
  
  "no-endpoints":
    在 round2.md "接口边界" 节追加 "WebSocket 端点：无（grep 未命中）"
  
  "skipped":
    在 round2.md 追加 "WebSocket 扫描跳过：{ws_result.error}"
```

### 容错

| 场景 | 行为 |
|------|------|
| 模块语言未识别 | 探针返 skipped，本 Step 跳过 |
| handler 文件不可读 | 探针仍返 ok，messages 为空，notes 中标注 |

## Step 6: Prompt 5 — 验证、提问与 TODO
```

- [ ] **Step 4: 验证**

```bash
cd F:/claude/superdev
grep -n "^## Step 5.5\|^## Step 5.6\|^## Step 6" mpdev-suite/.claude/commands/mpdev-understand.md
```

Expected: Step 5.5 + 5.6 + 6 都存在，顺序正确。

- [ ] **Step 5: 提交**

```bash
cd F:/claude/superdev && git add mpdev-suite/.claude/commands/mpdev-understand.md && git commit -m "feat(mpdev-understand): add Step 5.5 DB dict + Step 5.6 WS static scan

调 probe-db query-dict 和 probe-ws 采集运行时事实。失败时不阻塞合成。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 14: mpdev-understand.md — Step 7 合成 CLAUDE.md 区块扩展

**Files:**
- Modify: `mpdev-suite/.claude/commands/mpdev-understand.md` (Step 7.1 通用区块列表)

- [ ] **Step 1: 找 Step 7.1 通用区块列表**

```bash
cd F:/claude/superdev && grep -n "7.1 通用区块" mpdev-suite/.claude/commands/mpdev-understand.md
```

Expected: 行号约 398。

- [ ] **Step 2: 扩展通用区块列表**

old_string:
```
### 7.1 通用区块（所有项目类型都必须包含）

1. 技术栈
2. 目录结构
3. ⚠️ 接口字段（跨模块字段，改了必须同步契约仓库）
4. 内部字段（模块内自由修改的字段）
5. 编码规范（必须从第 4 轮代码采样归纳，标注依据来源，不要写泛泛空话）
6. 构建与部署
7. 与其他模块的关系
8. 已知隐含知识（第 5 轮用户回答的内容）
```

new_string:
```
### 7.1 通用区块（所有项目类型都必须包含）

1. 技术栈
2. 目录结构
3. ⚠️ 接口字段（跨模块字段，改了必须同步契约仓库）
4. 内部字段（模块内自由修改的字段）
   4a. WebSocket 端点（v1.3.0 新增；从 Step 5.6 的 ws-endpoints.md 抽摘要）
   4b. 字典常量（v1.3.0 新增；从 Step 5.5 的 dict-snapshots.md 抽表名+用途+引用，不嵌全表）
5. 编码规范（必须从第 4 轮代码采样归纳，标注依据来源，不要写泛泛空话）
6. 构建与部署
7. 与其他模块的关系
8. 已知隐含知识（第 5 轮用户回答的内容）

#### 4a. WebSocket 端点 — 形态规则

```markdown
## WebSocket 端点

| 路径 | handler | 方向 | 消息类型数 | 详细 |
|------|---------|------|----------:|------|
| /ws/task-events | TaskEventsHandler.java:45 | bidirectional | 3 | [ws-endpoints.md](.claude-notes/{module}/ws-endpoints.md#ws-task-events) |
```

不嵌完整消息 schema —— 详细 schema 留在 ws-endpoints.md，CLAUDE.md 只给索引。

#### 4b. 字典常量 — 形态规则

```markdown
## 字典常量

| 字典表           | 用途           | 值数量 | 详细快照 |
|------------------|---------------|------:|---------|
| dict_task_type   | 任务类型枚举   | 8     | [snapshots](.claude-notes/{module}/dict-snapshots.md#dict_task_type) |
| sys_status       | 系统状态码     | 5     | [snapshots](.claude-notes/{module}/dict-snapshots.md#sys_status) |
```

不嵌全表内容 —— 详细行留在 dict-snapshots.md，CLAUDE.md 只给目录。
```

- [ ] **Step 3: 验证**

```bash
cd F:/claude/superdev
grep -n "4a. WebSocket\|4b. 字典常量" mpdev-suite/.claude/commands/mpdev-understand.md
```

Expected: 两处命中。

- [ ] **Step 4: 提交**

```bash
cd F:/claude/superdev && git add mpdev-suite/.claude/commands/mpdev-understand.md && git commit -m "feat(mpdev-understand): add WS endpoints + dict constants to CLAUDE.md template

通用区块 4a (WS) + 4b (字典) 作为内部字段的子节。表格形态仅索引，详细内容留在 .claude-notes/{module}/ 下。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 15: install.sh — gitignore 注入

**Files:**
- Modify: `mpdev-suite/scripts/install.sh`

- [ ] **Step 1: 在 `info "$TARGET 已存在 mpdev-suite v$cur ..."` 块之前加 gitignore 注入逻辑（约第 65 行 ok 之后）**

old_string:
```
# 打版本标
echo "$ACTUAL_VERSION" > "$TARGET/.mpdev-version"

ok "mpdev-suite v$ACTUAL_VERSION 已安装到 $TARGET"
```

new_string:
```
# 打版本标
echo "$ACTUAL_VERSION" > "$TARGET/.mpdev-version"

# .gitignore 注入（v1.3.0+ 引入 runtime-probe 凭据 + 笔记目录）
GITIGNORE_PATH="$(dirname "$TARGET")/.gitignore"
GITIGNORE_ENTRIES=(
  ".claude/.mpdev-runtime-creds.yml"
  ".claude/.mpdev-env-state.yml"
  ".claude-notes/"
)
if [ -f "$GITIGNORE_PATH" ]; then
  for entry in "${GITIGNORE_ENTRIES[@]}"; do
    if ! grep -qxF "$entry" "$GITIGNORE_PATH"; then
      echo "$entry" >> "$GITIGNORE_PATH"
      info "已追加到 .gitignore: $entry"
    fi
  done
else
  printf '%s\n' "${GITIGNORE_ENTRIES[@]}" > "$GITIGNORE_PATH"
  info "已新建 .gitignore（含运行时文件忽略规则）"
fi

ok "mpdev-suite v$ACTUAL_VERSION 已安装到 $TARGET"
```

- [ ] **Step 2: 测试脚本语法**

```bash
cd F:/claude/superdev && bash -n mpdev-suite/scripts/install.sh && echo "syntax ok"
```

Expected: `syntax ok`

- [ ] **Step 3: 提交**

```bash
cd F:/claude/superdev && git add mpdev-suite/scripts/install.sh && git commit -m "feat(install.sh): inject .gitignore for runtime-probe creds + notes

新装项目自动 ignore .mpdev-runtime-creds.yml / .mpdev-env-state.yml / .claude-notes/

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 16: install.ps1 — gitignore 注入

**Files:**
- Modify: `mpdev-suite/scripts/install.ps1`

- [ ] **Step 1: 在 `Ok "mpdev-suite v$ActualVersion 已安装到 $Target"` 之前加注入逻辑**

old_string:
```
    # 版本标
    Set-Content -Path (Join-Path $Target '.mpdev-version') -Value $ActualVersion -Encoding utf8 -NoNewline

    Ok "mpdev-suite v$ActualVersion 已安装到 $Target"
```

new_string:
```
    # 版本标
    Set-Content -Path (Join-Path $Target '.mpdev-version') -Value $ActualVersion -Encoding utf8 -NoNewline

    # .gitignore 注入（v1.3.0+ 引入 runtime-probe 凭据 + 笔记目录）
    $GitignorePath = Join-Path (Split-Path $Target -Parent) '.gitignore'
    $GitignoreEntries = @(
        '.claude/.mpdev-runtime-creds.yml',
        '.claude/.mpdev-env-state.yml',
        '.claude-notes/'
    )
    if (Test-Path $GitignorePath) {
        $existing = Get-Content $GitignorePath -ErrorAction SilentlyContinue
        foreach ($entry in $GitignoreEntries) {
            if ($existing -notcontains $entry) {
                Add-Content -Path $GitignorePath -Value $entry -Encoding utf8
                Info "已追加到 .gitignore: $entry"
            }
        }
    } else {
        Set-Content -Path $GitignorePath -Value ($GitignoreEntries -join "`n") -Encoding utf8
        Info "已新建 .gitignore（含运行时文件忽略规则）"
    }

    Ok "mpdev-suite v$ActualVersion 已安装到 $Target"
```

- [ ] **Step 2: 验证脚本可解析**

```powershell
cd F:/claude/superdev; powershell -NoProfile -Command "& { try { [scriptblock]::Create((Get-Content 'mpdev-suite/scripts/install.ps1' -Raw)); 'syntax ok' } catch { Write-Host \$_.Exception.Message; exit 1 } }"
```

或者 Bash：

```bash
cd F:/claude/superdev && pwsh -NoProfile -Command "try { [scriptblock]::Create((Get-Content 'mpdev-suite/scripts/install.ps1' -Raw)); 'syntax ok' } catch { Write-Host \$_.Exception.Message; exit 1 }"
```

Expected: `syntax ok`（如果有 pwsh）

- [ ] **Step 3: 提交**

```bash
cd F:/claude/superdev && git add mpdev-suite/scripts/install.ps1 && git commit -m "feat(install.ps1): inject .gitignore for runtime-probe creds + notes (PS)

PowerShell 等价 install.sh 的变更，确保 Windows 用户也获得 gitignore 保护。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 17: update.sh — 拷贝 runtime-probe 到框架文件列表

**Files:**
- Modify: `mpdev-suite/scripts/update.sh`

- [ ] **Step 1: 在 "templates/understand" 拷贝之后追加 "templates/runtime-probe" 拷贝**

old_string:
```
# understand/references/ 是 /mpdev-understand 按技术栈加载的语言指南
if [ -d "$SUITE_ROOT/.claude/templates/understand" ]; then
  mkdir -p "$TARGET/templates/understand"
  cp -r "$SUITE_ROOT/.claude/templates/understand/." "$TARGET/templates/understand/"
fi
cp "$SUITE_ROOT/.claude/MPDev-Scheme.md" "$TARGET/"
```

new_string:
```
# understand/references/ 是 /mpdev-understand 按技术栈加载的语言指南
if [ -d "$SUITE_ROOT/.claude/templates/understand" ]; then
  mkdir -p "$TARGET/templates/understand"
  cp -r "$SUITE_ROOT/.claude/templates/understand/." "$TARGET/templates/understand/"
fi
# runtime-probe/ 是 v1.3.0+ 引入的运行时探针子能力
if [ -d "$SUITE_ROOT/.claude/templates/runtime-probe" ]; then
  mkdir -p "$TARGET/templates/runtime-probe"
  cp -r "$SUITE_ROOT/.claude/templates/runtime-probe/." "$TARGET/templates/runtime-probe/"
  info "  + 框架文件: templates/runtime-probe/"
fi
cp "$SUITE_ROOT/.claude/MPDev-Scheme.md" "$TARGET/"
```

- [ ] **Step 2: 测试脚本语法**

```bash
cd F:/claude/superdev && bash -n mpdev-suite/scripts/update.sh && echo "syntax ok"
```

Expected: `syntax ok`

- [ ] **Step 3: 提交**

```bash
cd F:/claude/superdev && git add mpdev-suite/scripts/update.sh && git commit -m "feat(update.sh): copy templates/runtime-probe on upgrade

确保 v1.3.0 升级时 runtime-probe/ 5 个探针文件被覆盖到已安装项目。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 18: update.ps1 — 同步 runtime-probe 拷贝

**Files:**
- Modify: `mpdev-suite/scripts/update.ps1`

- [ ] **Step 1: 在 templates/understand 拷贝之后追加 templates/runtime-probe**

old_string:
```
    # understand/references/ 是 /mpdev-understand 按技术栈加载的语言指南
    if (Test-Path (Join-Path $ClaudeRoot 'templates/understand')) {
        New-Item -ItemType Directory -Force -Path (Join-Path $Target 'templates/understand') | Out-Null
        Copy-Item -Path (Join-Path $ClaudeRoot 'templates/understand/*') -Destination (Join-Path $Target 'templates/understand') -Recurse -Force
    }
    Copy-Item -Path (Join-Path $ClaudeRoot 'MPDev-Scheme.md') -Destination $Target -Force
```

new_string:
```
    # understand/references/ 是 /mpdev-understand 按技术栈加载的语言指南
    if (Test-Path (Join-Path $ClaudeRoot 'templates/understand')) {
        New-Item -ItemType Directory -Force -Path (Join-Path $Target 'templates/understand') | Out-Null
        Copy-Item -Path (Join-Path $ClaudeRoot 'templates/understand/*') -Destination (Join-Path $Target 'templates/understand') -Recurse -Force
    }
    # runtime-probe/ 是 v1.3.0+ 引入的运行时探针子能力
    if (Test-Path (Join-Path $ClaudeRoot 'templates/runtime-probe')) {
        New-Item -ItemType Directory -Force -Path (Join-Path $Target 'templates/runtime-probe') | Out-Null
        Copy-Item -Path (Join-Path $ClaudeRoot 'templates/runtime-probe/*') -Destination (Join-Path $Target 'templates/runtime-probe') -Recurse -Force
        Info "  + 框架文件: templates/runtime-probe/"
    }
    Copy-Item -Path (Join-Path $ClaudeRoot 'MPDev-Scheme.md') -Destination $Target -Force
```

- [ ] **Step 2: 验证脚本可解析**

```bash
cd F:/claude/superdev && pwsh -NoProfile -Command "try { [scriptblock]::Create((Get-Content 'mpdev-suite/scripts/update.ps1' -Raw)); 'syntax ok' } catch { Write-Host \$_.Exception.Message; exit 1 }" 2>/dev/null || echo "skipped (no pwsh)"
```

- [ ] **Step 3: 提交**

```bash
cd F:/claude/superdev && git add mpdev-suite/scripts/update.ps1 && git commit -m "feat(update.ps1): copy templates/runtime-probe on upgrade (PS)

PowerShell 等价 update.sh 的变更。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 19: VERSION + CHANGELOG bump

**Files:**
- Modify: `mpdev-suite/VERSION`
- Modify: `mpdev-suite/CHANGELOG.md`

- [ ] **Step 1: 改 VERSION**

old_string: `1.2.0`
new_string: `1.3.0`

（VERSION 文件只有这一行）

- [ ] **Step 2: 在 CHANGELOG.md 顶部 `## [1.1.0]` 之前插入新版本段**

找 `## [1.1.0]` 行（约第 14 行）。

old_string:
```
## 版本规则

- **Major (X.0.0)**: 不向后兼容（BLOCK 命名变更、命令重命名、Step 重排、目录结构变更）
- **Minor (1.X.0)**: 新增 flavor / dialect / 命令 / agent
- **Patch (1.0.X)**: bug 修复、文档完善、模板小调整

## [1.1.0] — 2026-04-30
```

new_string:
```
## 版本规则

- **Major (X.0.0)**: 不向后兼容（BLOCK 命名变更、命令重命名、Step 重排、目录结构变更）
- **Minor (1.X.0)**: 新增 flavor / dialect / 命令 / agent
- **Patch (1.0.X)**: bug 修复、文档完善、模板小调整

## [1.3.0] — 2026-05-15

把 `/mpdev-fix` 和 `/mpdev-understand` 从纯静态分析升级为「静态 → 运行时验证 → 推理 → 验证」闭环，新增 4 个独立探针作为通用子能力。fix 加 Step 2.5（复现）/ 4.5（同类扫描）/ 5.5（浏览器验证）；understand 加 Step 5.5（DB 字典）/ 5.6（WS 静态扫描）。所有探针失败时软门降级，凭据存于 gitignored creds.yml。

### Added
- **`templates/runtime-probe/` 新目录**（5 个文件 ~700 行）：通用探针子能力
  - `README.md`：探针总览 / 命名约定 / 调用契约 / 凭据约定
  - `probe-db.md`：MySQL 连接 + 3 种 intent（query-dict / reproduce / verify-fix）
  - `probe-http.md`：curl 触发 endpoint，超时/auth/归档处理
  - `probe-browser.md`：基于 mcp__playwright__*，LLM 自由探索复现/验证前端 bug
  - `probe-ws.md`：纯静态 grep WS 端点 + 消息类型（Java/Python/Node/Frontend 4 语言）
- **`/mpdev-fix` 新增 3 个 Step**：
  - Step 2.5 环境复现（软门）：按 bug 类型选探针采集运行时事实
  - Step 4.5 同类问题扫描：基于 impl agent 输出的 similar_patterns 全仓 grep，用户确认后批量修
  - Step 5.5 浏览器验证（仅前端 bug）：调 probe-browser intent=verify 对照 Step 2.5 基线
- **`/mpdev-fix` 报告字段扩展**：单 bug frontmatter 新增 repro_state/verified/similar_fixes_count；body 新增 3 章节（复现证据/同类位置/验证结果）；批量总览改 3 列统计（fixed&verified / fixed未验证 / cannot_fix）
- **`/mpdev-understand` 新增 2 个 Step**：
  - Step 5.5 DB 字典查询：调 probe-db query-dict 自动扫字典表 + 写 .claude-notes/{module}/dict-snapshots.md
  - Step 5.6 WS 端点扫描：调 probe-ws 写 .claude-notes/{module}/ws-endpoints.md
- **CLAUDE.md 通用区块新增 4a/4b**：WebSocket 端点 + 字典常量（仅索引，不嵌全表）
- **`.gitignore` 自动注入**（install.sh / install.ps1）：`.mpdev-runtime-creds.yml` / `.mpdev-env-state.yml` / `.claude-notes/` 三条
- **`update.sh` / `update.ps1`**：拷贝 `templates/runtime-probe/` 作为框架文件（全量覆盖，无三方合并）

### Changed
- `/mpdev-fix` frontmatter `allowed-tools` 新增 `mcp__playwright__*` 和 `mcp__mysql__*`
- `/mpdev-understand` frontmatter `allowed-tools` 新增 `mcp__mysql__*`
- `/mpdev-fix` Step 4 impl agent YAML 输出新增 `similar_patterns` 字段（用于 Step 4.5 输入）

### Notes
- **凭据隔离**：DB / API token 仅写 gitignored `.mpdev-runtime-creds.yml`，不进归档报告
- **软门设计**：环境不可用时所有探针返 `skipped` + 报告标注 ⚠️，不阻塞主流程
- **playwright 触发条件**：模块 ∈ {vue, h5, pad, web, frontend} 或 bug 描述含前端关键词，全程参与（复现+验证）
- **同类扫描安全网**：全仓 grep + 用户确认 + impl agent 二次修复（不强制）
- **限制**：纯后端 bug 不做自动 HTTP 验证（用户手动 curl 或在 /mpdev-commit 前自验）；动态 WS 监听 / 多数据库实例切换不在本期范围
- **升级路径**：跑过老版本的项目重跑 update.sh / update.ps1 即可拿到 runtime-probe；首次 fix/understand 调用会触发凭据收集 AskUserQuestion

## [1.1.0] — 2026-04-30
```

- [ ] **Step 3: 验证**

```bash
cd F:/claude/superdev
cat mpdev-suite/VERSION
head -25 mpdev-suite/CHANGELOG.md
```

Expected: VERSION 显示 `1.3.0`；CHANGELOG 顶部有 1.3.0 段。

- [ ] **Step 4: 提交**

```bash
cd F:/claude/superdev && git add mpdev-suite/VERSION mpdev-suite/CHANGELOG.md && git commit -m "release: v1.3.0 - runtime verification

详见 CHANGELOG.md [1.3.0] 段。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 20: 自查 + 综合 git log

**Files:**
- 无修改；最终验证

- [ ] **Step 1: 验证文件清单完整**

```bash
cd F:/claude/superdev
echo "=== runtime-probe ==="
ls -la mpdev-suite/.claude/templates/runtime-probe/
echo ""
echo "=== 改过的命令 ==="
grep -l "Step 2.5\|Step 4.5\|Step 5.5" mpdev-suite/.claude/commands/mpdev-fix.md
grep -l "Step 5.5\|Step 5.6\|4a. WebSocket\|4b. 字典" mpdev-suite/.claude/commands/mpdev-understand.md
echo ""
echo "=== VERSION + CHANGELOG ==="
cat mpdev-suite/VERSION
grep "## \[1.3.0\]" mpdev-suite/CHANGELOG.md
```

Expected: 
- runtime-probe/ 有 5 个 .md 文件
- 两个命令文件都被识别为含新 Step
- VERSION = 1.3.0
- CHANGELOG 含 [1.3.0] 段

- [ ] **Step 2: 综合 git log 概览**

```bash
cd F:/claude/superdev && git log --oneline -20
```

Expected: 看到约 18 个 commit，覆盖：
- 5 个 feat(runtime-probe) 探针
- 5 个 feat(mpdev-fix) Step 改造
- 3 个 feat(mpdev-understand) Step 改造  
- 4 个 feat 脚本改造
- 1 个 release: v1.3.0

- [ ] **Step 3: 全文 grep 占位符（确保实施时不留 TBD/TODO）**

```bash
cd F:/claude/superdev
grep -rn "TBD\|TODO\|FIXME\|XXX\|TODO(.*)" \
  mpdev-suite/.claude/templates/runtime-probe/ \
  mpdev-suite/.claude/commands/mpdev-fix.md \
  mpdev-suite/.claude/commands/mpdev-understand.md \
  mpdev-suite/scripts/install.sh \
  mpdev-suite/scripts/install.ps1 \
  mpdev-suite/scripts/update.sh \
  mpdev-suite/scripts/update.ps1 \
  mpdev-suite/CHANGELOG.md 2>/dev/null | grep -v "/mpdev-suite/.claude/commands/mpdev-test\|TODO\.md\|TODO 清单"
```

Expected: 0 行命中（已有 TODO.md 提示是合理的，应被排除）

---

## Task 21: 验收剧本 #1 — fix 软门

**目的**：在没启服务的目录跑 `/mpdev-fix`，应该看到 "⚠️ 服务未启动，跳过复现"，但仍完成静态修复。

- [ ] **Step 1: 准备**

找一个**已安装** mpdev-suite 的项目（如 `F:/claude/ult_2.2`，确保 `.claude/templates/runtime-probe/` 存在）。

```bash
cd <project>
ls .claude/templates/runtime-probe/   # 应有 5 个 .md
```

不要启动任何服务（确保 java/python 后端未运行）。

- [ ] **Step 2: 跑 fix**

```
/mpdev-fix java NPE at TaskServiceImpl:127
```

- [ ] **Step 3: 检查报告**

```bash
ls .claude/mpdev-runs/fixes/   # 找最新报告
```

打开报告，验证：
- `repro_state: skipped`
- `verified: not_applicable`（因为是后端 bug）
- "复现证据" 节含 `⚠️ 未能复现 — 原因：no state.yml, run /mpdev-env start first` 或类似
- "变更文件" 节仍有内容（静态分析没被阻塞）

✅ 通过条件：报告生成、含 ⚠️ 标注、静态修复完成

---

## Task 22: 验收剧本 #2 — fix 全链路前端

**目的**：启 vue-frontend，真实跑 fix → 复现 → 修代码 → 重启前端 → 验证 → 报告含前后截图。

- [ ] **Step 1: 准备环境**

```bash
cd <vue 项目根>
# 确保 state.yml 已生成
/mpdev-env start vue
# 等 vue dev server 起来 (http://localhost:8080)
```

- [ ] **Step 2: 跑 fix**

```
/mpdev-fix vue 下拉框缺少 night_patrol 选项
```

期待执行流程：
1. Step 2.5 调 probe-browser → 启 chromium → 导航到 http://localhost:8080
2. impl agent 自由探索点击下拉框 → 截图 + console_errors
3. Step 4 让 vue-impl 修代码
4. Step 5 code review
5. Step 5.5：检测到 npm 启动 → 等 3 秒 → 二次启 chromium → 验证截图
6. 报告生成

- [ ] **Step 3: 检查报告**

```bash
ls .claude-notes/repro/   # 应有 batch_id 目录
ls .claude/mpdev-runs/fixes/  # 找最新报告
```

打开报告，验证：
- `repro_state: confirmed`
- `verified: true`（修后浏览器正常）
- "复现证据" 节嵌入 `bug-1-reproduce-*.png` 引用
- "验证结果" 节嵌入 `bug-1-verify-*.png` 引用 + ✅
- "变更文件" 节含 vue 文件路径

✅ 通过条件：两次截图都生成、verified=true、报告完整

---

## Task 23: 验收剧本 #3 — fix 同类扫描

**目的**：构造含 NPE 的方法 + 另外 2 处类似 → fix 修主 bug → 扫到 2 处候选 → 用户选"全选" → 一并修。

- [ ] **Step 1: 准备测试代码**

在某个 java 模块中，临时插入：

```java
// File1.java
public String getTaskName(Task t) {
  return t.getInfo().getName();  // <-- 没 null 检查
}
// File2.java
public String getTaskType(Task t) {
  return t.getInfo().getType();  // <-- 同样没 null 检查
}
// File3.java
public Long getTaskId(Task t) {
  return t.getInfo().getId();  // <-- 同样没 null 检查
}
```

- [ ] **Step 2: 跑 fix 针对 File1**

```
/mpdev-fix java getTaskName NPE on t.getInfo() at File1:N
```

期待：
1. Step 4 修 File1，输出 `similar_patterns: [{description: "未对 t.getInfo() 做 null 检查", grep: "t\\.getInfo\\(\\)\\.[a-z]"}]`
2. Step 4.5 全仓 grep → 命中 File2 和 File3
3. AskUserQuestion: 列出 2 个候选 → 选"全选"
4. impl agent 第二轮修 File2/File3
5. 报告 `similar_fixes_count: 2`

- [ ] **Step 3: 验证**

```bash
git diff   # 应看到 File1/2/3 都被改了
cat .claude/mpdev-runs/fixes/<latest>.md  # 应有 "同类位置" 节列出 File2/File3
```

✅ 通过条件：3 个文件都改了、报告含同类位置节、similar_fixes_count=2

- [ ] **Step 4: 还原测试代码（git checkout）**

```bash
git checkout File1.java File2.java File3.java
```

---

## Task 24: 验收剧本 #4 — understand 字典

**目的**：清空 creds，跑 understand → 触发 AskUserQuestion 收凭据 → 生成 dict-snapshots → CLAUDE.md 含"字典常量"区块。

- [ ] **Step 1: 准备**

```bash
cd <java 项目>
rm -f .claude/.mpdev-runtime-creds.yml
rm -rf .claude-notes/   # 强制重跑
```

确保 state.yml 存在且 MySQL 中间件已配（host/port/database）。

- [ ] **Step 2: 跑 understand**

```
/mpdev-understand only=java force
```

期待：
1. 走完 Prompt 1-4.5
2. Step 5.5：调 probe-db query-dict → AskUserQuestion 收 username/password
3. 探针扫字典表 → 写 `.claude-notes/java/dict-snapshots.md`
4. Step 7 合成 → CLAUDE.md 含 "4b. 字典常量" 节

- [ ] **Step 3: 验证**

```bash
ls .claude-notes/java/dict-snapshots.md   # 应存在
grep "字典常量\|dict_" java/CLAUDE.md       # 应有命中
cat .claude/.mpdev-runtime-creds.yml      # 应含 modules.java.db 节
```

✅ 通过条件：snapshots 文件生成、CLAUDE.md 含区块、creds.yml 存在且不为空

---

## Task 25: 验收剧本 #5 — understand WS

**目的**：在含 `@OnMessage` 的 Java 项目跑 understand → CLAUDE.md "4a. WebSocket 端点" 节有内容。

- [ ] **Step 1: 准备**

确认目标 Java 模块含 WS handler（grep `@ServerEndpoint` 或 `@OnMessage` 至少 1 个命中）。

```bash
cd <java 项目>
grep -rn "@OnMessage\|@ServerEndpoint" mr_ult_java_2.1/ | head -3
```

- [ ] **Step 2: 跑 understand**

```
/mpdev-understand only=java force
```

期待 Step 5.6 调 probe-ws → 写 `.claude-notes/java/ws-endpoints.md`。

- [ ] **Step 3: 验证**

```bash
ls .claude-notes/java/ws-endpoints.md
grep "WebSocket 端点\|TaskEventsHandler\|@OnMessage" java/CLAUDE.md
```

✅ 通过条件：ws-endpoints.md 生成、CLAUDE.md 含 WS 端点表格

---

## Task 26: 验收剧本 #6 — 凭据隔离

**目的**：grep mpdev-runs/ 和所有 CLAUDE.md，不应出现 creds.yml 里的密码。

- [ ] **Step 1: 制造已知密码**

```bash
cd <project>
# 假设 creds.yml 已含 password: "test_password_xyz_12345"
cat .claude/.mpdev-runtime-creds.yml | grep password
```

- [ ] **Step 2: 跑一些 fix/understand 流程让归档生成**

如先跑 Task 22 + Task 24。

- [ ] **Step 3: grep 密码字符串**

```bash
cd <project>
grep -rn "test_password_xyz_12345" \
  .claude/mpdev-runs/ \
  ./*/CLAUDE.md \
  .claude-notes/ 2>/dev/null
```

Expected: **0 行命中**。

✅ 通过条件：密码字符串只出现在 `.claude/.mpdev-runtime-creds.yml` 中

- [ ] **Step 4: 同时验证 .gitignore 包含凭据文件**

```bash
cd <project>
grep "mpdev-runtime-creds" .gitignore
git check-ignore .claude/.mpdev-runtime-creds.yml && echo "正确 ignored"
```

Expected: `正确 ignored`

---

## Self-Review

实现完成后，重读 spec [`docs/superpowers/specs/2026-05-15-mpdev-runtime-verification-design.md`](../specs/2026-05-15-mpdev-runtime-verification-design.md)，对照检查：

- [ ] Spec §5 文件清单的每个新文件都在 Task 1-5 创建
- [ ] Spec §6 4 个探针契约都被 Task 2-5 实现，输入/输出格式一致
- [ ] Spec §7 fix 改造点 (Step 2.5/4.5/5.5/报告字段) 都在 Task 7-11 覆盖
- [ ] Spec §8 understand 改造点 (Step 5.5/5.6/CLAUDE.md 区块) 都在 Task 12-14 覆盖
- [ ] Spec §9 凭据管理 schema 与 Task 15-16 .gitignore 注入一致
- [ ] Spec §10 错误处理矩阵的每行都在某个 Task 的 "容错" 节中体现
- [ ] Spec §11 测试剧本 1-6 对应 Task 21-26
- [ ] Spec §12 限制（不在本期范围）未被任何 Task 实现

如发现 spec 要求但 plan 未覆盖的点，回到本计划补 Task；如发现 plan 实现了 spec 未要求的点，回 spec 确认是否漏写。
