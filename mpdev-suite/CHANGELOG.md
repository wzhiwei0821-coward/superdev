# Changelog

All notable changes to mpdev-suite will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

新增文档增量刷新闭环。第 13 个 AI agent（`doc-refresher`）属于 MPDev-Scheme.md §7.1 定义的"框架层（不变）"通用 agent，与 code-reviewer / integration-checker / acceptance-reviewer 同等定位，由 `/mpdev-init` Step 10 按通用职责落地。

### Added
- **第 13 个通用 agent：`doc-refresher`**（框架层）—— 用于 `/mpdev` 主流程 Step 12.5，根据 impl 变更和契约新增条目增量刷新各模块 CLAUDE.md 与契约仓 CLAUDE.md 的表总表，让文档不漂移。
- **`/mpdev-init` Step 10 扩展**：通用 agent 列表从 3 个扩展到 4 个，加入 `doc-refresher.md`；新增"doc-refresher 标准职责"段（角色 / 触发 / 会做 / 不做 / 跳过 / 输出 / 工作目录）作为生成时的内容指引。
- **`/mpdev` 主流程 Step 12.5：文档增量刷新**：在 test-reporter 与汇总报告之间无暂停执行，仅追加机械可推导的内容（API 表行 / MQ 字段 / 文件路径条目 / 契约总表条目）；找不到目标章节或需语义改写一律跳过 + 落 TODO 到模块 `TODO.md`（前缀 `[doc-refresh YYYY-MM-DD run_id=...]`）。
- **文档模板 T7**：`15-doc-refresh.md` 标准化记录已刷新文件、跳过+TODO、未触碰、git diff 摘要、后续建议。
- **99-summary.md 文档刷新段**：T6 模板新增"文档刷新（Step 12.5）"摘要段落与时间线行；关联文档列表加 `15-doc-refresh.md` 链接。
- **MPDev-Scheme.md §7.1 三层架构**：框架层（不变）列加入 `doc-refresher.md`；§8 套件目录树加入相应 agent 行。
- **README.md 更新**：套件级 README + .claude/README.md 同步刷新到"13 个 AI agent"，agent 分类表新增"文档类（1）"行。

### Changed
- `/mpdev` 容错规则表增加 `doc-refresher (Step 12.5)` 行：失败不阻塞 Step 13，warn 进 99-summary。
- 模式 C（探索）流程明确不启动 doc-refresher。
- Step 编号约束放宽：v1.0.0 注记 "Step 编号已用整数（0-13），不再使用 0.5 / 1.5 等小数" 在 1.1.0 中放宽——`/mpdev` Step 12.5（文档刷新嵌入在 Step 12 与 Step 13 之间）属于"附属于主步骤、不重排现有编号"的合理用法。

### Notes
- doc-refresher **不走 `.tmpl` 路径** —— 它是通用框架层 agent，结构稳定，不依赖项目特化占位符（contract 仓库目录由 agent runtime 通过 `Glob("**/CLAUDE.md")` 自行探测，无契约仓时仅维护各模块 CLAUDE.md）。这点与 code-reviewer / integration-checker / acceptance-reviewer 完全一致。
- doc-refresher **不修改** schemas/openapi/sql 契约定义本身（contract-designer 的领域），**不修改** EVENT_CATALOG.md（同上），**不重写** DATAFLOW.md（需 architect 视野）。
- doc-refresher 追加幂等 — 重复跑 `/mpdev` 同一需求不会产生重复条目（agent 在 Edit 前用 Grep 确认目标行不存在）。
- **升级路径**：跑过 `/mpdev-init` 的现有项目，重跑一次 `/mpdev-init` 即可让 Step 10 落地 `agents/doc-refresher.md`（按规则"如果不存在，按通用职责定义生成"）；模式 C 与无 CLAUDE.md 项目自动跳过 Step 12.5，对现有用户零侵入。

## [1.0.0] — 2026-04-28

首发版本。

### Added
- **9 个 slash 命令**：mpdev, mpdev-init, mpdev-fix, mpdev-test, mpdev-check, mpdev-env, mpdev-commit, mpdev-understand, mpdev-contracts
- **12 个 AI agent**（运行时通过 mpdev-init 生成）：3 架构 + 5 实现 + 2 审查 + 1 验收 + 1 测试
- **DBA 双层模板**：dba.tmpl 骨架 + 4 数据库方言（mysql / postgresql / dameng / kingbase）
- **Tester 双层模板**：tester.tmpl 骨架 + 7 项目类型 flavor（http-api / web-frontend / microservices / mobile-app / algo-service / data-pipeline / robot-iot）
- **三阶段测试嵌入**：mpdev 主流程 Step 7 / 9 / 12（IEEE 829 标准）
- **缺陷生命周期闭环**：/mpdev-test bug export → markdown → /mpdev-fix --batch
- **project-understanding 本地副本**：6 份 references（2333 行）随套件分发，免依赖外部 skill 安装
- **install.sh / update.sh / pack.sh**：一行命令安装、保留实例升级、离线 tarball
- **install.ps1 / update.ps1**：Windows PowerShell 原生支持，不依赖 bash（绕开 PowerShell `curl` 别名陷阱）
- **分发渠道**：GitHub（raw.githubusercontent.com 拉脚本 / Releases 发离线包）

### Notes
- mpdev 主流程 Step 编号已用整数（0-13），不再使用 0.5 / 1.5 等小数
- 套件总规模约 6000 行 markdown + 50+ 文件
- 适用范围：单模块 / 跨模块（monorepo）/ Spring Cloud + Nacos / 多语言混合栈
