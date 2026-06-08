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
