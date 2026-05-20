# Changelog

All notable changes to mpdev plugin will be documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 版本规则

- **Major (X.0.0)**: 不向后兼容（命令重命名、目录结构变更、安装方式变更）
- **Minor (1.X.0)**: 新增命令 / agent / 探针 / flavor / dialect
- **Patch (1.0.X)**: bug 修复、文档完善、模板小调整

## [2.1.0] — 2026-05-20 — 套件防漏判加固

针对 F-001（UReport2 报表 P0 需求被错误 FU 化）暴露的"隐藏代码资产漏判"模式，在三处加防线：

### Added

- **架构师 S2.5 Resource Asset Matrix**（`templates/architect.tmpl`）
  - 内置 20 类隐藏代码资产清单（报表模板 / 数据字典 / SQL 迁移 / DB 视图 / 种子数据 / 配置中心 / 算法模型 / 工作流 / 规则引擎 / API 契约 / 权限菜单 / MQ 拓扑 / 定时任务 / 搜索索引 / 缓存策略 / 国际化 / 静态资源 / 监控埋点 / CI 编排 / 文档资产）
  - PRD §1 / 变更点表每一行必须在 Matrix 中至少出现一次，缺失则蓝图 fail-fast
  - 新增 S6 AC↔Asset 预映射章节，每条 P0 AC 必须挂到 Matrix 行
- **acceptance-reviewer 强追踪表**（`agents/acceptance-reviewer.md`）
  - 新增 `ac_artifact_trace` 输出字段：每条 AC 必填关联 Matrix 行 + 实际产物 + 测试证据 + 用户可感知判定
  - 重定义 Met/Partial/Missed/Untested 边界：用户看不见 = Missed（不是 Partial）；依赖链断 = Missed（不是 Untested）；"无变更跳过" = Missed（不再合法）
- **FU 任务白名单/黑名单**（`commands/dev.md`）
  - 白名单 `env / model / external / hw_perf`：限定环境、业务方提供物、跨团队对齐、实机性能基准
  - 黑名单 `source / sql / template / dict / iac`：任何研发产物（含 UReport / Jasper / BPMN 等模板）必须由 implementer 输出版本化资产，不允许 FU 化
  - 验收阶段产出黑名单类别的 FU → 自动 fail，回退 implementer

### Changed

- **conditional_accept 门槛收紧**：任何 P0 AC = Missed / Partial 强制 reject，不再允许 conditional 兜底
- **Step 11 注入扩展**：acceptance-reviewer 调用时强制注入 Blueprint S2.5 + S6，缺失则拒绝验收并反推 architect
- **Step 8 impl 注入扩展（I1）**：implementer 同时接收 §3.x（改动指令）和 S2.5 中归属本模块的资产行（资产清单），两者交叉防漏；S2.5 列了但 §3.x 未展开时 implementer 主动 fail_with_report 反推 architect。同步更新 `impl-java.tmpl` / `impl-vue.tmpl` / `impl-python.tmpl` 三个模板的"# 输入"清单
- **Asset Matrix 扫描源降级兜底（I2）**：架构师扫描源优先 PRD §1 变更点表，PRD 无 §1 时降级为 `02-breakdown.md` 的 F1..Fn 功能点；两者都缺则反推 02-breakdown 阶段补全。覆盖精简需求 / 一句话需求场景

### Why

F-001 验收时 P0 AC-023（UReport 白灯列）实际未实现，但被验收 reviewer 标 ⚠️ Partial（"数据源就绪，模板未变更"），FU-2 把模板修改归到「运维操作」让运维去 `/ureport/designer` 浏览器界面手工拖列保存——绕过版本控制、绕过 CI、绕过研发评审。根因是套件用「源码 case 覆盖」作为完成判据，扫不到 `.ureport.xml` / `sys_rpt_file` 这类声明式资产。本次加固把判据从「扫源码找 case」升级为「扫 PRD 找资产」。

## [2.0.0] — 2026-05-18

mpdev 首个正式发布版（Claude Code Plugin 模式）。从 mpdev-suite v1.x「项目级 `.claude/` 复制」迁移到 plugin 分发，并集成双源安装、hooks、runtime probe、维护者同步脚本等能力。

### Plugin 化（BREAKING from v1.x）

- `.claude-plugin/plugin.json` + `marketplace.json`：Claude Code 官方 plugin manifest
- `agents/` 顶级目录：4 个框架级 shared agent（code-reviewer / integration-checker / acceptance-reviewer / doc-refresher）
- 命令命名：所有命令 drop `mpdev-` 前缀
  - `/mpdev` → `/mpdev:dev`
  - `/mpdev-fix` → `/mpdev:fix`（其余 7 个同理）
- 目录结构：`mpdev-suite/.claude/{commands,templates,...}` → `mpdev/{commands,templates,agents,docs,...}`
- 模板引用：命令 .md 内的路径从 `.claude/templates/...` → `${CLAUDE_PLUGIN_ROOT}/templates/...`
- 安装：从「项目内跑 install.sh」改为「全局跑 install.sh + /plugin install」
- 升级：从「项目内跑 update.sh + 三方合并」改为「/plugin update 一键」
- `/mpdev:init` 不再生成 4 个框架 agent（plugin 自带）；只生成 9 个项目特化 impl agent

### 双源安装（GitLab 内网 + GitHub 外网）

- `bin/install.sh` / `bin/install.ps1` 支持双源：
  - 默认 GitLab 内网（`git@10.173.28.211:robot-ai/mppm/mpdev.git` SSH, 分支 `master`）
  - `--source=github` 或 `MPDEV_SOURCE=github` 切公网 GitHub HTTPS（分支 `main`）
  - install.sh 新增 SSH 主机指纹自动接受（可 `--skip-ssh-keyscan` 关）
  - 6 步结构：preflight → SSH → clone → version → guide → hooks+BOM
  - `--help` 显示完整 source / target / branch / subdir / env var 用法

### Hooks 集成（3 个）

位于 `${CLAUDE_PLUGIN_ROOT}/hooks/`，`MPDEV_NO_HOOKS=1` 一开关全禁：

- **SessionStart** (`hooks/session-start.sh`)：启动时自动检测项目里所有 CLAUDE.md，提取「## 技术栈」节摘要注入 Claude 上下文。省去手工说明项目背景。
- **UserPromptSubmit** (`hooks/inject-keyword-hint.sh`)：用户输入含 7 种模式关键词时（"修 bug" / "新需求" / "理解项目" / "启动服务" / "写测试" / "检查契约" / "生成 commit"），systemMessage 提示对应 `/mpdev:*` 命令。
- **SubagentStop** (`hooks/post-subagent-check.sh`)：impl agent 输出 `cross_module_issue` 字段非 null 时，additionalContext 提示跨模块影响 + 启发式抽出目标模块名建议下一步。
- `hooks/_lib.sh` 共享工具（禁用检查 / 项目根定位 / YAML 解析）
- 全部 fail-silent + 3-5 秒超时；hooks 只读（不写项目数据）
- bash only；Windows 用户需 Git Bash for Windows

### Runtime Probe（5 个）

`${CLAUDE_PLUGIN_ROOT}/templates/runtime-probe/` 下 5 个探针：DB / HTTP / Playwright / WebSocket / 静态扫描。fix 软门复现 + 验证；凭据走 `.claude/.mpdev-runtime-creds.yml`（gitignored），probe-http 自动 redact `Bearer ***`。

### 安装脚本健壮性

- `install.sh` / `install.ps1` 末尾扫描 `mpdev/**/*.ps1`，缺 UTF-8 BOM 自动补齐 — 修复中文 Windows 上无 BOM 的 .ps1 被 GBK 解码 → migrate 等脚本完全无法运行
- `install.sh` 末尾 chmod +x hooks/*.sh
- `install.ps1` 末尾把 .sh 行尾从 CRLF 转 LF（防 Windows git autocrlf 引入 \r\n 破坏 shebang）

### 维护者工具

- `scripts/sync-to-gitlab.sh`：把 `superdev/mpdev/` 同步到 GitLab 独立 mpdev 仓
  - 4 步：clone → 同步（POSIX `find + cp`，兼容 Git Bash 无 rsync）→ commit + tag → push
  - 支持 `--dry-run`（不 push 只看 diff）
  - 检测 v 版本 tag 冲突时弹询问
  - `MPDEV_GITLAB_REPO` / `MPDEV_GITLAB_BRANCH` / `MPDEV_SOURCE_DIR` env 覆盖
  - `set -o pipefail` + clone 失败明确错误提示

- `scripts/migrate-from-v1.sh` / `migrate-from-v1.ps1`：v1.x 项目迁移到 v2 的辅助脚本
  - `--auto-clean-framework-agents` flag（opt-in）：删除 4 个框架 agent 让 plugin 接管
  - `--help` / `-h` 输出 usage

### 文档

- `docs/quickstart.md`：5 分钟速览（含 SSH key 配置引导）
- `docs/upgrade-guide.md`：从 v1.x 升级
- `docs/troubleshooting.md`：故障排查 + hook 章节
- `docs/MPDev-Scheme.md`：架构与角色设计
- `docs/workflow.md`：9 命令使用手册

### Removed

- 老仓库 `scripts/install.sh` / `update.sh` / `pack.sh`（被 plugin 机制取代）
- `.claude/` 作为分发根（plugin 用 `.claude-plugin/` + 顶级目录）
- `.mpdev-version` 文件（plugin 系统自带版本管理）

### Migration

- v1.x 用户：跑 `migrate-from-v1.sh` + 装 plugin。详见 [upgrade-guide.md](./docs/upgrade-guide.md)
- 老仓库 `mpdev-suite/` 保留半年（v1.3.x 维护模式），2026-11-15 归档
- v1.3.0 的所有功能行为在 v2.0.0 中**功能等价**（9 命令 / 4 探针 / 所有 Step / 报告格式）
- 项目数据文件（`.claude/agents/` / `.claude/mpdev-runs/` / `.claude/.mpdev-env-state.yml` / `.claude/.mpdev-runtime-creds.yml` / `.claude-notes/`）位置不变，零迁移

### 内部迭代历史（已并入 v2.0.0）

v2.0.0 在开发过程中经历过 v2.0.1 (BOM 自检) / v2.1.0 (3 个 hooks) / v2.1.1 (双源 + sync-to-gitlab.sh) 三轮内部迭代，最终统一作为 v2.0.0 首个正式发布。这些迭代未对外发布过 tag，统一并入本段。
