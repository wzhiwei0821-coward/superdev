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
