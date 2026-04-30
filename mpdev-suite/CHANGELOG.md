# Changelog

All notable changes to mpdev-suite will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 版本规则

- **Major (X.0.0)**: 不向后兼容（BLOCK 命名变更、命令重命名、Step 重排、目录结构变更）
- **Minor (1.X.0)**: 新增 flavor / dialect / 命令 / agent
- **Patch (1.0.X)**: bug 修复、文档完善、模板小调整

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
