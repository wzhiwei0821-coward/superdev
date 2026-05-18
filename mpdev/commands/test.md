---
name: test
description: 测试套件入口 — 测试计划/用例/执行/报告/UAT/缺陷管理（mpdev 生命周期阶段 2 测试专项）
allowed-tools: Agent, Read, Grep, Glob, Bash, TodoWrite, Write, Edit, AskUserQuestion
---

# /mpdev:test — 测试套件入口

mpdev 测试角色的**统一命令入口**。支持 7 个子命令覆盖测试全生命周期。

| 子命令 | 用途 | 调用 tester 模式 |
|--------|------|-----------------|
| `/mpdev:test plan` | 单独生成测试计划 | A（test-architect）|
| `/mpdev:test cases <module>` | 给某模块设计/补测试用例 | A |
| `/mpdev:test run [scope]` | 执行测试（生成或运行自动化代码）| B（test-executor）|
| `/mpdev:test report [run_id]` | 跨模块测试报告 | C（test-reporter）|
| `/mpdev:test bug <action>` | 缺陷生命周期管理 | 不调 agent，直接操作 incidents.md |
| `/mpdev:test uat [run_id]` | UAT 验收文档 | C（uat 模式）|
| `/mpdev:test detect-flavor` | 重新识别项目类型，重生成 tester.md | 不调 agent，跑 init Step 9 |

**底层 agent**：`tester` agent（基于 `templates/tester.tmpl` + `test-flavors/{type}.md` 合成）。

## 与 /mpdev:dev 主流程的关系

`/mpdev:dev` 主流程**自动**在 Step 7 / 9 / 12 调用 tester agent —— **日常开发场景不用手工跑 /mpdev:test**。

`/mpdev:test` 用于**专项任务**：
- 单独生成测试计划（无需启动完整 /mpdev:dev 流程）
- 给已有代码补测试用例（项目历史代码测试覆盖不足）
- 跑回归、查缺陷、生成 UAT
- 项目结构变化后重新识别 flavor

---

## 用户输入

$ARGUMENTS

### 子命令路由

```
解析 $ARGUMENTS 第一个词作为 subcommand:

  "plan"          → 子命令 1
  "cases"         → 子命令 2
  "run"           → 子命令 3
  "report"        → 子命令 4
  "bug"           → 子命令 5（再解析 action: add/list/close/export/reopen）
  "uat"           → 子命令 6
  "detect-flavor" → 子命令 7
  其他 / 空       → 显示帮助菜单
```

如果 `tester.md` 不存在 → 提示用户先跑 `/mpdev:init`（或 `/mpdev:test detect-flavor`）。

---

## 子命令 1：plan（单独生成测试计划）

`/mpdev:test plan [需求描述或 run_id]`

适用：不走 /mpdev:dev 主流程，独立生成测试计划。

```
1. 解析输入:
   - 数字/run_id 格式 → 读 mpdev-runs/{run_id}/03-blueprint.md 作为上下文
   - 自由文本 → 视为需求描述
   - 空 → 提示用户输入需求或选 run_id

2. 调 tester agent:
   Agent(
     subagent_type="general-purpose",
     description="生成测试计划",
     prompt="<tester.md 全文>\n\n## 任务: 模式 A\n仅生成测试计划，不需要用例规格。\n\n输入: {需求描述或 Blueprint 摘要}"
   )

3. 输出到 .claude/mpdev:runs/test-plans/{timestamp}-{slug}.md
```

---

## 子命令 2：cases（给某模块补测试用例）

`/mpdev:test cases <module> [关键词]`

适用：已有代码但测试缺失/不足，想批量补一份用例。

```
1. 解析 module（必填）:
   - 在 .claude/agents/ 下找 {module}-impl.md 确认存在
   - 不存在 → 列出可用模块让用户选

2. 收集上下文（并行）:
   - Glob 该模块的 controller/service 文件
   - Grep 现有测试代码（test/*.java 或 tests/*.py）
   - 找到 keyword 相关的 test gap

3. 调 tester agent (mode A):
   prompt: "为以下文件设计测试用例（重点关注未覆盖方法）：{file_list}\n\n关键词过滤: {keyword}"

4. 输出:
   .claude/mpdev:runs/test-cases/{module}-{timestamp}.md

5. 提示用户:
   "已生成 N 条用例。下一步可用 /mpdev:test run --module {module} 执行。"
```

---

## 子命令 3：run（执行测试）

`/mpdev:test run [scope]`

scope 选项：

| 参数 | 含义 |
|------|------|
| 空 | 跑全部已有测试 |
| `--module <name>` | 只跑某模块测试 |
| `--regression {bug_ids}` | 只跑特定 bug 的回归 |
| `--perf` | 只跑性能基准 |
| `--smoke` | 只跑冒烟测试（P0 子集）|

```
1. 根据 scope 确定要跑的测试集
2. 调 tester agent (mode B):
   prompt: "执行 {scope}，登记失败用例为缺陷"

3. agent 执行:
   - Java: mvn test -Dtest='{pattern}'
   - Python: pytest {path} -m {marker}
   - Node: npm test -- --testPathPattern={pattern}

4. 收集结果 → 09-test-log.md
5. 失败用例 → 自动登记到 10-test-incidents.md（已存在则追加，不覆盖）

6. 回归模式特殊处理（--regression）:
   - 通过 → bug 状态自动改为 closed
   - 不通过 → bug 状态改为 reopen
```

---

## 子命令 4：report（生成测试报告）

`/mpdev:test report [run_id]`

```
1. 解析 run_id:
   - 空 → 取最近一次 /mpdev:dev 运行
   - "latest" → 同上
   - 具体 ID → 直接用

2. 校验数据齐全:
   - 09-test-log.md 必须存在
   - 10-test-incidents.md 可缺失（无缺陷场景）

3. 调 tester agent (mode C):
   prompt: "汇总以下数据生成测试总结报告..."

4. 输出: mpdev-runs/{run_id}/14-test-summary.md

5. 更新 INDEX.md:
   - 在"测试记录"表追加一行（含 run_id / 通过率 / 缺陷数 / 准出建议）
```

---

## 子命令 5：bug（缺陷管理）

`/mpdev:test bug <action> [args]`

### 5.1 `bug add` — 登记新缺陷

```
交互式 AskUserQuestion 收集:
- 标题
- 模块（默认从用户最近上下文推断）
- 严重度（P0/P1/P2/P3）
- 复现步骤
- 实际 vs 期望
- 关联用例 TC-ID（可选）

写入到当前 run_id 的 10-test-incidents.md，状态 = open
分配 BUG-ID（递增序号 + 全局唯一）
```

### 5.2 `bug list [filter]`

```
读 mpdev-runs/*/10-test-incidents.md 所有缺陷
按 filter 过滤展示:
  - status=open / in-progress / resolved / closed / reopen
  - severity=P0 / P1 / P2 / P3
  - module=java / vue / dispatch / ...
  - 不带 filter → 默认展示 open + reopen
```

### 5.3 `bug close <id>` — 关闭缺陷

```
找到 BUG-{id}:
- 不存在 → 提示并列出所有 ID
- 存在 → 状态改 closed，记录关闭时间和原因（询问用户）
```

### 5.4 `bug export [filter]` — 导出（接 /mpdev:fix）

```
读符合 filter 的缺陷
按 /mpdev:fix --batch 期望的 markdown 格式输出:
  - [java] BUG-001 NPE on null taskName / 复现: ...
  - [vue]  BUG-007 列表页白屏 / 复现: ...

保存到 .claude/mpdev:runs/test-exports/bugs-{timestamp}.md

提示: "已导出 N 个缺陷。运行 /mpdev:fix @{path} 批量修复。"
```

### 5.5 `bug reopen <id> <reason>` — 重开缺陷

```
回归测试发现已 closed 的 bug 又出现
找到 BUG-{id} → 状态改 reopen，记录重开原因
```

---

## 子命令 6：uat（UAT 验收文档）

`/mpdev:test uat [run_id]`

```
1. 收集本次 run_id 全部测试数据
2. 调 tester agent (mode C, uat-mode=true):
   prompt: "生成 UAT 验收文档，含业务场景验证清单 / 角色矩阵 / 验收准则 / 签字栏"

3. 输出 mpdev-runs/{run_id}/uat.md

4. 提示用户: "UAT 文档已生成，建议导出为 PDF 提交相关方签字。"
```

---

## 子命令 7：detect-flavor（重新识别项目类型）

`/mpdev:test detect-flavor`

适用：项目结构发生重大变化（加新模块、技术栈切换等）后，重新识别 flavor 并刷新 `agents/tester.md`。

```
1. 重跑 /mpdev:init 的 Step 9 项目类型识别逻辑
2. AskUserQuestion 让用户确认结果:
   "检测到项目类型为 {type}。要应用此识别结果吗？"
   选项: [是 / 我自己选（列出 7 种）/ 取消]

3. 用户确认后:
   - **如果 agents/tester.md 已存在** → 备份为 tester.md.bak.{timestamp}
   - **如果不存在** → 跳过备份（首次创建）
   - 读 templates/tester.tmpl + templates/test-flavors/{type}.md
   - 注入占位符 → 写入 agents/tester.md

4. 输出: 显示新 flavor 的关键差异（KEY_RISK_AREAS / AUTOMATION_STACK 等）

**说明**：本子命令同时是 `/mpdev:init` Step 9 的轻量替代——单独跑这条不需要走完整 init 流程，适合"只补 tester"或"换项目类型重生成"。
```

---

## 容错规则

| 情况 | 处理 |
|------|------|
| 不识别的 subcommand | 显示帮助菜单 |
| run_id 不存在 | 列出所有 run_id 让用户选 |
| `tester.md` 不存在 | 提示先跑 `/mpdev:init` 或 `/mpdev:test detect-flavor` |
| 缺 flavor（项目类型未识别）| 提示 detect-flavor 或回退用 `http-api.md` flavor |
| 缺陷 BUG-id 不存在 | 列出所有缺陷 ID 让用户选 |
| /mpdev:dev 主流程已经登记过缺陷 | 累加，不覆盖（每个缺陷有唯一 ID）|
| run 失败（编译错/环境错）| 不视为缺陷，提示用户修环境后重试 |
| Testcontainers 启动失败 | 提示 Docker 是否可用，或回退用 mock |

## 约束

1. **bug 唯一 ID**：BUG-{递增序号}，不允许复用，跨 run_id 全局唯一
2. **状态机**：`open → in-progress → resolved → closed`；回归失败 → `reopen`
3. **不自动 close**：bug 状态变更必须有用户操作或回归验证通过
4. **导出格式与 /mpdev:fix --batch 兼容**：复用现有清单格式，不重新发明
5. **覆盖率阈值见 flavor METRICS BLOCK**
6. **测试代码不污染业务代码**：放到 `test/` / `tests/` / `src/test/`
7. **每个子命令必写归档**：plan/cases/run/report/uat 都要在 `mpdev-runs/` 留存档
8. **detect-flavor 必备份**：覆盖 `agents/tester.md` 前先 `.bak.{timestamp}`
