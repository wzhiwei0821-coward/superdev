# mpdev 📦

> **多模块 AI 协同开发框架** — Claude Code Plugin
>
> 9 个 `/mpdev:*` 命令 + 4 个框架 agent + 5 个 runtime probe + 13 个 AI agent 模板，覆盖「理解项目 → 提取契约 → 框架初始化 → 开发 → 测试 → 修复 → 提交」全生命周期。

[![version](https://img.shields.io/badge/version-2.0.0-blue)](./VERSION) [![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE) [![claude-code](https://img.shields.io/badge/Claude%20Code-Plugin-orange)](https://docs.claude.com/en/docs/claude-code)

---

## 一句话定位 🎯

**给在多模块（Java + Python + Vue / Spring Cloud / 微服务 + 前端）项目里搞 AI 协作开发的工程师**：从一句话需求 / 一个 bug，自动跑完架构 → 契约 → 实现 → 评审 → 测试 → 提交全流程，不用手动协调多个 agent。

- 👥 **目标场景**: B 端管理后台 / 机器人 IoT / 物联网平台 / 数据中台 / 算法服务
- 📦 **数据解耦**: Plugin 升级**永远不写**项目里的 `.claude/agents/`、`.claude/mpdev-runs/`、`.claude/.mpdev-*`
- 🛡️ **运行时验证**: v1.3.0 起内置 4 个探针（DB / HTTP / Playwright / WS 静态扫描），fix 软门复现 + 验证
- 🌐 **跨项目复用**: 一次装 plugin，所有项目里 `/mpdev:` 自动可用

---

## ⚡ 5 分钟跑通

```bash
# 1. 装 plugin（30 秒）

# 内网（默认，从 GitLab；需 SSH key 配好）
bash <(curl -fsSL http://10.173.28.211/robot-ai/mppm/mpdev/-/raw/master/bin/install.sh)

# 外网（GitHub）
bash <(curl -fsSL https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev/bin/install.sh) --source=github

# 然后在 Claude Code 内:
/plugin marketplace add file://~/dev/mpdev
/plugin install mpdev@mpdev

# 2. 任意项目内（4 分钟）
/mpdev:understand           # 阶段 0a: 生成各模块 CLAUDE.md
/mpdev:contracts            # 阶段 0b: 跨模块项目才需要
/mpdev:init                 # 阶段 1: 生成项目特化 impl agent
/mpdev:dev "需求描述"        # 阶段 2: 开始开发
```

详见 [docs/quickstart.md](./docs/quickstart.md)。

---

## 9 个命令

| 命令 | 作用 | 典型用法 |
|------|------|---------|
| `/mpdev:understand` | 各模块代码深度理解 → 生成 CLAUDE.md | 新项目 / CLAUDE.md 过期 |
| `/mpdev:contracts` | 多 CLAUDE.md 交叉比对 → 生成契约仓库 | 跨模块项目首次建立 |
| `/mpdev:init` | 按 CLAUDE.md 生成 9 个项目特化 impl agent | 阶段 0 完成后 |
| `/mpdev:env` | 检测中间件 + 配置 + 启动 / 重启 / 停止 / 状态 | 开发环境一站式管理 |
| `/mpdev:dev` | 主流程：架构 → 契约 → 实现 → 评审 → 测试 → 提交 | 日常开发主入口 |
| `/mpdev:fix` | 轻量修复（单 bug + 批量清单） | bug 修复 |
| `/mpdev:test` | 测试用例生成 / 执行 / bug 导出 | 测试阶段 |
| `/mpdev:check` | 跨模块契约一致性 + 兜底测试 | merge 前体检 |
| `/mpdev:commit` | 智能 commit 消息生成 | 提交前 |

---

## 3 个 Hooks（v2.1.0+）

| Hook 事件 | 触发 | 作用 |
|----------|------|------|
| `SessionStart` | Claude Code 启动 | 扫项目 CLAUDE.md → 注入技术栈摘要给 Claude（用户不可见） |
| `UserPromptSubmit` | 用户提交 prompt | 含 "修 bug / 新需求 / 启动服务" 等关键词时，提示对应 `/mpdev:*` 命令 |
| `SubagentStop` | subagent 跑完 | impl agent 报 `cross_module_issue` 时，提示下一步 `/mpdev:fix <module>` |

**禁用**：`export MPDEV_NO_HOOKS=1` 一开关全禁。

**跨平台**：bash only；Windows 需 Git Bash for Windows。

---

## 数据架构

```
┌───────────────────────────────────────────────────────────┐
│  Plugin 自带（只读，住 ~/.claude/plugins/cache/mpdev/）   │
│                                                            │
│   commands/    9 个 /mpdev:* 命令                          │
│   templates/   ├─ 7 个 .tmpl（架构/契约/impl/dba/tester）  │
│                ├─ dialects/      4 DB 方言                  │
│                ├─ test-flavors/  7 测试 flavor              │
│                ├─ understand/    6 语言指南                │
│                └─ runtime-probe/ 5 探针（v1.3.0）           │
│   agents/      4 个框架 agent                              │
│                code-reviewer / integration-checker /        │
│                acceptance-reviewer / doc-refresher          │
│   docs/        架构 / workflow / 快速上手 / 排错 / 升级    │
└────────────────────────┬───────────────────────────────────┘
                         │ ${CLAUDE_PLUGIN_ROOT}/...
                         ▼
┌───────────────────────────────────────────────────────────┐
│  项目数据（写入项目本地，git 管理）                       │
│                                                            │
│   .claude/agents/                项目特化 impl agent (9 个)│
│   .claude/mpdev-runs/            运行历史                  │
│   .claude/.mpdev-env-state.yml   /mpdev:env 维护           │
│   .claude/.mpdev-runtime-creds.yml runtime-probe 凭据      │
│                                  （gitignored）            │
│   .claude-notes/                 第二阶段笔记 + snapshots │
│   CLAUDE.md                      /mpdev:understand 产物    │
└───────────────────────────────────────────────────────────┘
```

---

## 文档

- 📘 [quickstart.md](./docs/quickstart.md) — 5 分钟速览
- 🔄 [upgrade-guide.md](./docs/upgrade-guide.md) — 从 v1.x 升级
- 🛟 [troubleshooting.md](./docs/troubleshooting.md) — 故障排查
- 🏛️ [MPDev-Scheme.md](./docs/MPDev-Scheme.md) — 架构与角色设计
- 📖 [workflow.md](./docs/workflow.md) — 9 命令使用手册

---

## 升级

```bash
/plugin update
```

或手动：

```bash
cd ~/dev/mpdev && git pull
/plugin update
```

---

## License

MIT
