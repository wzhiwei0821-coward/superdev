# superdev — mpdev 分发仓库

> **多模块 AI 协同开发框架** — Claude Code Plugin

[![mpdev version](https://img.shields.io/badge/mpdev-v2.2.0-blue)](./mpdev/) [![license](https://img.shields.io/badge/license-MIT-green)](./mpdev/LICENSE)

---

## 一句话定位

**给在多模块（Java + Python + Vue / Spring Cloud / 微服务 + 前端）项目里搞 AI 协作开发的工程师**：从一句话需求 / 一个 bug，自动跑完架构 → 契约 → 实现 → 评审 → 测试 → 提交全流程，不用手动协调多个 agent。

9 个 `/mpdev:*` 命令 + 4 个框架 agent + 13 个 AI agent 模板 + 5 个 runtime probe。

---

## ⚡ 安装（30 秒）

在 Claude Code 内直接执行：

```
/plugin marketplace add https://github.com/wzhiwei0821-coward/superdev
/plugin install mpdev@superdev
```

**完全重启** Claude Code。更新只需 `/plugin update`。

---

## 验证

输入 `/mpdev:` 应自动补全 9 个命令：

```
/mpdev:check    /mpdev:commit  /mpdev:contracts
/mpdev:dev      /mpdev:env     /mpdev:fix
/mpdev:init     /mpdev:test    /mpdev:understand
```

---

## 首次使用

```
/mpdev:understand          # 阶段 0a：生成各模块 CLAUDE.md
/mpdev:contracts           # 阶段 0b：跨模块项目才需要
/mpdev:init                # 阶段 1：生成项目特化 impl agent
/mpdev:dev "需求描述"        # 阶段 2：日常开发
```

完整文档：[mpdev/docs/quickstart.md](./mpdev/docs/quickstart.md)

---

## 仓库结构

```
superdev/
├── marketplace.json               GitHub marketplace 入口
├── mpdev/                         v2.2.0 plugin
│   ├── .claude-plugin/
│   │   ├── plugin.json
│   │   └── marketplace.json
│   ├── commands/                  9 个 /mpdev:* 命令
│   ├── agents/                    4 个框架 agent
│   ├── templates/                 模板（dialects / test-flavors / runtime-probe）
│   ├── hooks/                     3 个 Session/UserPrompt/SubagentStop hooks
│   ├── docs/                      quickstart / upgrade-guide / troubleshooting
│   ├── bin/install.{sh,ps1}       一键安装
│   ├── scripts/
│   │   ├── migrate-from-v1.{sh,ps1}  v1→v2 项目迁移
│   │   └── fix-v2.1.168.{sh,ps1}    v2.1.0 缓存修复
│   ├── CHANGELOG.md
│   ├── LICENSE (MIT)
│   └── README.md
└── README.md                      本文件
```

---

## 从 v1 升级到 v2

详见 [mpdev/docs/upgrade-guide.md](./mpdev/docs/upgrade-guide.md)。

命令重命名映射：

| v1.x | v2.x |
|------|------|
| `/mpdev` | `/mpdev:dev` |
| `/mpdev-fix` | `/mpdev:fix` |
| `/mpdev-understand` | `/mpdev:understand` |
| `/mpdev-init` | `/mpdev:init` |
| `/mpdev-env` | `/mpdev:env` |
| `/mpdev-test` | `/mpdev:test` |
| `/mpdev-check` | `/mpdev:check` |
| `/mpdev-commit` | `/mpdev:commit` |
| `/mpdev-contracts` | `/mpdev:contracts` |

---

## 发布新版本

1. 改 `mpdev/VERSION`
2. 更新 `mpdev/CHANGELOG.md`
3. 同步 `mpdev/.claude-plugin/plugin.json` + `marketplace.json` 版本号
4. commit + tag + push：
   ```bash
   git add mpdev/VERSION mpdev/CHANGELOG.md mpdev/.claude-plugin/
   git commit -m "release: mpdev vX.Y.Z"
   git tag vX.Y.Z
   git push origin main --tags
   ```

---

## License

MIT — 详见 [mpdev/LICENSE](./mpdev/LICENSE)
