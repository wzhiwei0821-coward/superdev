# MPDev 运行记录索引

> 自动维护。每次 `/mpdev`、`/mpdev-fix`、`/mpdev-commit`、`/mpdev-understand`、`/mpdev-contracts` 运行完成后，编排器会在此追加记录。

## 使用说明

- 每个 `/mpdev` 运行产出一个完整的文件夹，包含从需求到验收的全链路文档
- 每个 `/mpdev-fix` 运行产出修复报告：单 bug 一份；批量 N 个 bug 产出 N 份单报告 + 1 份批量总览
- 每个 `/mpdev-commit` 运行产出一份提交记录（dry-run 不写）
- `/mpdev-understand` 和 `/mpdev-contracts` 是**阶段 0 准备类**命令，归档到 `setup/` 子目录
- 失败的运行也会保留文档，便于复盘

## 目录结构

```
.claude/mpdev-runs/
├── INDEX.md                       本文件
├── {run_id}/                      /mpdev 运行
│   ├── 01-requirement.md          用户需求
│   ├── 03-blueprint.md            架构蓝图
│   ├── 04-dba-design.md         DBA 设计（仅 DB 变更时产出）
│   ├── 05-contract-changes.md     契约变更
│   ├── 06-test-plan.md          测试计划（tester mode A，IEEE 829）
│   ├── 07-test-cases.md         测试用例规格（tester mode A，IEEE 829）
│   ├── 08-impl-{module}.md        各模块实现报告
│   ├── 09-test-log.md           测试日志（tester mode B，IEEE 829）
│   ├── 10-test-incidents.md     缺陷登记（tester mode B，IEEE 829）
│   ├── 11-code-review.md          代码审查
│   ├── 12-integration-check.md    集成校验
│   ├── 13-acceptance.md           验收审查
│   ├── 14-test-summary.md       测试总结报告（tester mode C，IEEE 829）
│   └── 99-summary.md              汇总
├── fixes/                         /mpdev-fix 轻量修复
│   ├── {timestamp}-{module}-{slug}.md              单 bug 模式
│   ├── {timestamp}-{bug_id}-{module}-{slug}.md     批量模式（每个 bug 一份，文件名含 bug_id 区分）
│   └── batch-{timestamp}.md                        批量模式（总览，仅 len(bugs)>1 时产出）
├── commits/                       /mpdev-commit 提交记录
│   └── {timestamp}-{short_sha}-{subject_slug}.md
├── setup/                         阶段 0 准备类命令归档（understand / contracts）
│   ├── {timestamp}-understand-{slug}.md     /mpdev-understand
│   └── {timestamp}-contracts.md              /mpdev-contracts
├── test-plans/                    /mpdev-test plan 独立产出
│   └── {timestamp}-{slug}.md
├── test-cases/                    /mpdev-test cases <module> 独立产出
│   └── {module}-{timestamp}.md
└── test-exports/                  /mpdev-test bug export 给 /mpdev-fix 的清单
    └── bugs-{timestamp}.md
```

## 运行记录

<!-- 编排器在下方以 markdown 表格维护，最新的在上 -->

| 时间 | Run ID | 需求摘要 | 模式 | 结果 | 链接 |
|------|--------|---------|------|------|------|

<!-- 示例条目（仅供参考，实际内容由编排器填充）:
| 2026-04-17 15:30 | 2026-04-17_1530_night-patrol-task-type | 增加夜间巡检任务类型 | B | ✅ Accept | [详情](./2026-04-17_1530_night-patrol-task-type/) |
| 2026-04-17 16:12 | fixes/20260417-1612-dispatch-keyerror | 修复 dispatch 启动 KeyError | - | ✅ fixed | [详情](./fixes/20260417-1612-dispatch-keyerror.md) |
-->

## 修复记录（/mpdev-fix）

| 时间 | 模块 | 问题摘要 | 结果 | 链接 |
|------|------|---------|------|------|

<!-- 示例:
| 2026-04-17 16:12 | dispatch | 启动 KeyError: 'task_type' | ✅ fixed | [详情](./fixes/20260417-1612-dispatch-keyerror.md) |
-->

## 提交记录（/mpdev-commit）

| 时间 | Commit | 主题 | 涉及模块 | 链接 |
|------|--------|------|---------|------|

<!-- 示例:
| 2026-04-17 17:00 | 3a2b1c5 | 新增静默告警接口 | java, vue, contracts | [详情](./commits/20260417-1700-3a2b1c5-silent-alarm.md) |
| 2026-04-17 18:30 | 9f8e7d6 | 修复夜间巡检降速BUG     | dispatch | [详情](./commits/20260417-1830-9f8e7d6-fix-night-patrol-speed.md) |
-->
