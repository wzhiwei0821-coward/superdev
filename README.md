# superdev — mpdev 分发仓库

> **多模块 AI 协同开发框架的分发仓库**。提供 mpdev plugin（v2.0.0 推荐）和 mpdev-suite（v1.3.x 维护期）两份并存的发布通道。

[![mpdev version](https://img.shields.io/badge/mpdev-v2.1.1-blue)](./mpdev/) [![mpdev-suite version](https://img.shields.io/badge/mpdev--suite-v1.3.1-yellow)](./mpdev-suite/) [![license](https://img.shields.io/badge/license-MIT-green)](./mpdev/LICENSE)

---

## 一句话定位 🎯

**给在多模块（Java + Python + Vue / Spring Cloud / 微服务 + 前端）项目里搞 AI 协作开发的工程师**：从一句话需求 / 一个 bug，自动跑完架构 → 契约 → 实现 → 评审 → 测试 → 提交全流程，不用手动协调多个 agent。

9 个 slash 命令 + 13 个 AI agent + 5 个 runtime probe，覆盖「理解项目 → 提取契约 → 框架初始化 → 开发 → 测试 → 修复 → 提交 → 运维」全生命周期。

---

## 两条发布通道

| 通道 | 状态 | 安装方式 | 命名空间 | 适用 |
|------|------|----------|---------|------|
| **[mpdev/](./mpdev/) v2.0.0** | ✅ **推荐** | Claude Code Plugin | `/mpdev:fix` `/mpdev:dev` … | 新用户 / 想升级的老用户 |
| **[mpdev-suite/](./mpdev-suite/) v1.3.1** | 🟡 维护期 | 项目级 `.claude/` 复制 | `/mpdev-fix` `/mpdev` … | v1 老项目暂不迁移者 |

> v1.x 维护期到 **2026-11-15**，期间只修关键 bug。强烈建议新项目直接用 v2.0.0 plugin。

---

## ⚡ 5 分钟跑通（v2.1.1 推荐）

```bash
# 1. 装 plugin（全局一次，所有项目可用）

# 内网（默认，从 GitLab；需 SSH key 配好）
bash <(curl -fsSL http://10.173.28.211/robot-ai/mppm/mpdev/-/raw/master/bin/install.sh)

# 外网（GitHub）
bash <(curl -fsSL https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev/bin/install.sh) --source=github
```

**Windows PowerShell**（强制 UTF-8 解码，避免乱码）：
```powershell
# 默认 GitLab；切公网用 $env:MPDEV_SOURCE='github'
$wc = New-Object Net.WebClient; $wc.Encoding = [Text.Encoding]::UTF8
$s = $wc.DownloadString('https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev/bin/install.ps1')
if ($s[0] -eq [char]0xFEFF) { $s = $s.Substring(1) }
iex $s
```

安装脚本会引导你在 Claude Code 内跑：
```
/plugin marketplace add file://~/dev/mpdev
/plugin install mpdev@mpdev
```

**完全重启 Claude Code**（不仅 `/clear`），任意项目内输入 `/mpdev:` 应见 9 个命令补全：

```
/mpdev:check    /mpdev:commit  /mpdev:contracts
/mpdev:dev      /mpdev:env     /mpdev:fix
/mpdev:init     /mpdev:test    /mpdev:understand
```

然后 4 个命令完成首次跑通：
```
/mpdev:understand          # 阶段 0a：生成各模块 CLAUDE.md
/mpdev:contracts           # 阶段 0b：跨模块项目才需要
/mpdev:init                # 阶段 1：生成项目特化 impl agent
/mpdev:dev "需求描述"        # 阶段 2：日常开发
```

完整文档：[`mpdev/docs/quickstart.md`](./mpdev/docs/quickstart.md)

---

## 仓库结构

```
superdev/
├── mpdev/                              v2.0.0 plugin（推荐）
│   ├── .claude-plugin/
│   │   ├── plugin.json                 plugin manifest
│   │   └── marketplace.json            marketplace manifest
│   ├── commands/                       9 个 /mpdev:* 命令
│   ├── templates/                      模板（.tmpl + dialects + test-flavors + understand + runtime-probe）
│   ├── agents/                         4 个框架级 shared agent
│   ├── docs/                           quickstart / upgrade-guide / troubleshooting / MPDev-Scheme / workflow
│   ├── bin/install.{sh,ps1}            plugin 一键安装
│   ├── scripts/migrate-from-v1.{sh,ps1}  v1→v2 项目迁移
│   ├── VERSION                         2.0.0
│   ├── CHANGELOG.md
│   ├── LICENSE                         MIT
│   └── README.md
│
├── mpdev-suite/                        v1.3.x 维护期（旧用户）
│   ├── .claude/                        套件本体（install.sh 拷贝这里）
│   │   ├── commands/                   9 个 /mpdev-* slash 命令
│   │   ├── templates/                  含 runtime-probe（v1.3.0 新增）
│   │   ├── mpdev-runs/INDEX.md
│   │   ├── MPDev-Scheme.md
│   │   ├── mpdev-suite-workflow.md
│   │   └── README.md
│   ├── scripts/
│   │   ├── install.{sh,ps1}            v1 首次安装
│   │   ├── update.{sh,ps1}             v1 升级
│   │   └── pack.sh
│   ├── VERSION                         1.3.1
│   ├── CHANGELOG.md
│   └── README.md                       含 v2 deprecation 横幅
│
├── docs/superpowers/                   spec/plan 设计文档（开发者参考）
│   ├── specs/
│   └── plans/
│
└── README.md                           本文件
```

---

## 从 v1 升级到 v2

详见 [`mpdev/docs/upgrade-guide.md`](./mpdev/docs/upgrade-guide.md)。要点：

```bash
# 1. 装 v2 plugin（全局，一次性）
bash <(curl -fsSL https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev/bin/install.sh)
# 后在 Claude Code 内: /plugin install mpdev@mpdev

# 2. 在每个 v1 项目根跑迁移脚本
cd /path/to/old-v1-project
bash ~/dev/mpdev/scripts/migrate-from-v1.sh
# Windows: powershell -File ~/dev/mpdev/scripts/migrate-from-v1.ps1

# 3. 完全重启 Claude Code 后用新命令名
/mpdev:fix vue 下拉框 bug    # 不再是 /mpdev-fix
```

**命令重命名映射**：

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

**项目数据完全保留**（不需要迁移）：`.claude/agents/`、`.claude/mpdev-runs/`、`.claude/.mpdev-env-state.yml`、`.claude/.mpdev-runtime-creds.yml`、`.claude-notes/`、`CLAUDE.md`。

---

## v1.x 安装（老项目使用）

⚠️ 仅当你不想迁移到 v2 时使用。新项目请用 v2。

**Linux / macOS / Git Bash：**
```bash
curl -fsSL https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev-suite/scripts/install.sh | bash
```

**Windows PowerShell：**
```powershell
$wc = New-Object Net.WebClient; $wc.Encoding = [Text.Encoding]::UTF8
$s = $wc.DownloadString('https://raw.githubusercontent.com/wzhiwei0821-coward/superdev/main/mpdev-suite/scripts/install.ps1')
if ($s[0] -eq [char]0xFEFF) { $s = $s.Substring(1) }
iex $s
```

详见 [`mpdev-suite/README.md`](./mpdev-suite/README.md)。

---

## v2 vs v1 — 数据架构

```
┌───────────────────────────────────────────────────────────────────┐
│                v2.0.0 Plugin 架构（推荐）                          │
│                                                                    │
│  ┌──────────────────────────────────────┐                          │
│  │  ~/.claude/plugins/cache/mpdev/      │  ← plugin 自带（只读）  │
│  │  ├── commands/  9 个                  │     全局一次安装        │
│  │  ├── templates/                       │     所有项目共享        │
│  │  ├── agents/    4 个框架 agent        │                        │
│  │  └── docs/                            │                        │
│  └──────────────────────┬───────────────┘                          │
│                         │ ${CLAUDE_PLUGIN_ROOT}                    │
│                         ▼                                          │
│  ┌──────────────────────────────────────┐                          │
│  │  <project>/.claude/                  │  ← 项目数据（git 管理） │
│  │  ├── agents/                         │     plugin 永不写入     │
│  │  ├── mpdev-runs/                     │                        │
│  │  ├── .mpdev-env-state.yml            │                        │
│  │  └── .mpdev-runtime-creds.yml        │     gitignored         │
│  └──────────────────────────────────────┘                          │
└───────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────┐
│                v1.x 项目级 .claude/ 复制（维护期）                  │
│                                                                    │
│  <project>/.claude/                                                │
│  ├── commands/    框架文件 (每个项目一份)                          │
│  ├── templates/   框架文件 (每个项目一份)                          │
│  ├── agents/      项目数据                                         │
│  ├── mpdev-runs/  项目数据                                         │
│  └── .mpdev-version                                                │
└───────────────────────────────────────────────────────────────────┘
```

---

## 发布新版本（维护者用）

### v2.x 发布流程（mpdev/）

1. 改 `mpdev/VERSION`（如 `2.1.1`）
2. 在 `mpdev/CHANGELOG.md` 顶部加 `## [2.1.1] — YYYY-MM-DD` 段
3. 在 `mpdev/.claude-plugin/plugin.json` + `marketplace.json` 同步 `"version"` 字段
4. commit + tag：
   ```bash
   git add mpdev/VERSION mpdev/CHANGELOG.md mpdev/.claude-plugin/
   git commit -m "release: mpdev v2.1.1"
   git tag mpdev-v2.1.1
   git push origin main --tags
   ```
5. **同步到 GitLab**（v2.1.1+ 新增）：
   ```bash
   bash mpdev/scripts/sync-to-gitlab.sh           # 真同步
   bash mpdev/scripts/sync-to-gitlab.sh --dry-run # 先 dry-run 看 diff
   ```
   GitLab 仓: http://10.173.28.211/robot-ai/mppm/mpdev

### v1.x patch 流程（mpdev-suite/）

仅修关键 bug。改 `mpdev-suite/VERSION` + CHANGELOG，commit tag `mpdev-suite-v1.3.x`。

---

## fork 给同事使用

如果同事 fork 本套件，需要更改 `install.sh` 内的默认 URL：

```bash
# v2 plugin（推荐）
sed -i 's|wzhiwei0821-coward/superdev|colleague/myrepo|g' \
  mpdev/bin/install.sh mpdev/bin/install.ps1 mpdev/README.md
```

详见各子目录的 README。

---

## License

MIT — 详见 [`mpdev/LICENSE`](./mpdev/LICENSE)
