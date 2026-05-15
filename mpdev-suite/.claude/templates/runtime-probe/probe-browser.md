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
