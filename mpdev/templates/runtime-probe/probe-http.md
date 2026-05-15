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
