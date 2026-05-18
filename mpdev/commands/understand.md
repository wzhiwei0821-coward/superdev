---
name: understand
description: 项目深度理解 — 给各模块生成高质量 CLAUDE.md（mpdev 生命周期阶段 0a）
allowed-tools: Read, Grep, Glob, Bash, TodoWrite, Write, Edit, AskUserQuestion, mcp__mysql__*
---

# /mpdev:understand — 项目深度理解 + CLAUDE.md 生成

mpdev 套件**生命周期阶段 0a**。读懂项目代码 → 沉淀为高质量 CLAUDE.md。

按 5 轮递进理解项目，每轮笔记写入文件（不占对话上下文），最后合成 CLAUDE.md。

```
Step 1：范围确认           → 多模块仓库选 SCOPE_DIRS
Step 3：检测项目类型       → 加载 templates/understand/references/{lang}.md
第 1 轮：项目骨架           → 依赖 + 配置 + 目录
第 2 轮：接口边界           → API + MQ + DB + 外部调用
第 3 轮：核心业务流         → 链路追踪 + 隐含规则
第 4 轮：基础设施           → 异常/日志/编码风格采样
第 4.5 轮：接口完整性校验   → 多策略交叉扫描 + 已有文档对照
第 5 轮：验证补盲           → 读测试 + 接口定向确认 + 向用户提问
合成轮                     → 读全部笔记 + 用户回答 → 写 CLAUDE.md（含置信度标注）+ TODO.md
```

**定位**：

| mpdev 命令 | 阶段 | 产出 |
|----------|------|------|
| **`/mpdev:understand`** | 0a | 各模块 `CLAUDE.md` |
| `/mpdev:contracts` | 0b | `robot-contracts/` 仓库 |
| `/mpdev:init` | 1 | `.claude/agents/` |
| `/mpdev:dev` ... | 2+ | 日常开发 |

**何时用**：

- 拿到一个新项目（CLAUDE.md 缺失）
- 已有项目但 CLAUDE.md 已经过期（技术栈变了 / 加了新模块）
- 多模块仓库要把每个模块的语义沉淀下来

**何时不用**：

- 单文件脚本或玩具项目
- CLAUDE.md 已经很新且高质量（但你想刷新部分章节，可手工编辑或用 `/init` 局部更新）

---

## 用户输入

$ARGUMENTS

### 支持参数

| 参数 | 含义 | 示例 |
|------|------|------|
| 空 | 交互式发现并选择模块（走 Step 1 范围确认） | `/mpdev:understand` |
| `only=<模块名列表>` | 只处理指定模块 | `/mpdev:understand only=java,vue` |
| `exclude=<模块名列表>` | 排除某些模块 | `/mpdev:understand exclude=docs,tools` |
| `force` | 覆盖现有 CLAUDE.md（默认会询问） | `/mpdev:understand only=java force` |
| 自由文本 | 触发"快速路径"（Step 1.4） | `/mpdev:understand 只看 gateway 和 user-service` |

**force 模式**：检测到现有 CLAUDE.md 时，跳过"是否覆盖"询问，直接备份后覆盖。备份位置：`{原路径}.bak.{timestamp}`

---

## Step 1: 范围确认（多模块仓库必经）

进入仓库**首先**判断是单模块还是多模块；多模块要让用户先选范围，避免浪费上下文分析无关模块。

### 1.1 列出一级目录 + 识别模块

```bash
# 列出一级目录，排除明显非业务目录
DIRS=$(ls -d */ 2>/dev/null | grep -vE "^(\.git|\.venv|node_modules|target|dist|build|__pycache__|\.idea|\.vscode|\.claude|\.claude-notes|docs|scripts|deploy|infra|tools|examples|test|tests)/$")

# 对每个目录识别模块类型
for d in $DIRS; do
  TYPE=""
  [ -f "$d/pom.xml" ] || [ -f "$d/build.gradle" ] && TYPE="Java"
  [ -f "$d/package.json" ] && TYPE="${TYPE:+$TYPE+}Node/Vue"
  [ -f "$d/requirements.txt" ] || [ -f "$d/pyproject.toml" ] && TYPE="${TYPE:+$TYPE+}Python"
  [ -f "$d/go.mod" ] && TYPE="${TYPE:+$TYPE+}Go"
  [ -f "$d/Cargo.toml" ] && TYPE="${TYPE:+$TYPE+}Rust"
  echo "  $d  $TYPE"
done
```

### 1.2 判定路径

| 情况 | 处理 |
|------|------|
| 仓库根直接含 pom.xml/package.json/requirements.txt | **单模块仓库** → 跳过 Step 1，进入 Step 3 |
| 一级目录中有 ≥2 个识别为模块的目录，**且**根目录无项目文件 | **Monorepo** → 走 1.3 |
| 一级目录中只有 1 个模块，且根无项目文件 | 自动选定该模块，告知用户后进入 Step 3 |
| 仓库根含 pom.xml 但 pom.xml 中有 `<modules>` 多 module Maven | **多 module 聚合工程** → 走 1.3（特殊：所有子模块同属一个 Java 项目） |

### 1.3 呈现并等待用户选择

```
发现以下模块：
  1) gateway/         (Java/pom.xml)
  2) user-service/    (Java/pom.xml)
  3) order-service/   (Java/pom.xml)
  4) admin-ui/        (Vue/package.json)
  5) data-pipeline/   (Python/requirements.txt)

其他目录（无明显项目标识）：docs/, scripts/, config/

请选择本次要深度理解的范围：
  - 全部分析：回 "all" 或 "全部"
  - 选择子集：回编号（如 "1,2,4" 或 "1-3"）
  - 排除：回 "排除 5" 或 "exclude 4,5"
  - 模糊匹配：回 "user-*" 或 "*-service"
  - 退出：回 "退出"
```

### 1.4 解析用户回复

**快速路径（$ARGUMENTS 已含范围描述）**：

如果命令触发时的 $ARGUMENTS 或 `only=`/`exclude=` 参数已包含明确范围，**跳过 1.3 的等待**，直接按以下规则解析：

1. 在 $ARGUMENTS / `only=` 中抽取模块名候选词（中英文名词 / `user-*` 通配符 / 数字编号）
2. 对 1.1 列出的目录做**包含/glob/编号**三路匹配
3. 匹配成功：呈现"我理解为：已选 [gateway, user-service]，确认吗？"让用户一句话确认（是/改）
4. 匹配失败或歧义：降级到 1.3 完整清单

**标准路径（无描述 → 等用户回复）**：

| 输入 | 解析 |
|------|------|
| `all` / `全部` | SCOPE_DIRS = 全部识别模块 |
| `1,2,4` | 取编号对应的目录 |
| `1-3` | 取范围 |
| `排除 5` | 全部减掉编号 5 的目录 |
| `user-*` | 名字 glob 匹配 |
| `gateway, user-service` | 名字直接匹配 |
| 含糊（"差不多"/"你定"）| 拒绝并重申选项，再等 |
| `退出` | 终止流程 |

### 1.5 跨模块依赖预检（可选告警）

对选中模块做一次**轻量**的引用扫描，提示用户范围外的依赖。**每类只扫对应语言的模块**：

```bash
# 先按语言分组 SCOPE_DIRS
JAVA_DIRS=""; PY_DIRS=""; NODE_DIRS=""
for d in $SCOPE_DIRS; do
  [ -f "$d/pom.xml" ] || [ -f "$d/build.gradle" ] && JAVA_DIRS="$JAVA_DIRS $d"
  [ -f "$d/requirements.txt" ] || [ -f "$d/pyproject.toml" ] && PY_DIRS="$PY_DIRS $d"
  [ -f "$d/package.json" ] && NODE_DIRS="$NODE_DIRS $d"
done

# Feign 引用（Java）— 仅当有 Java 模块
if [ -n "$JAVA_DIRS" ]; then
  grep -rln "@FeignClient" $JAVA_DIRS 2>/dev/null | xargs -r grep -h "@FeignClient(name=\"" 2>/dev/null \
    | sed -E 's/.*name="([^"]+)".*/\1/' | sort -u
fi

# Python 同 repo import — 仅当有 Python 模块
if [ -n "$PY_DIRS" ]; then
  grep -rh "^from \(\.\|src\.\)" $PY_DIRS --include="*.py" 2>/dev/null | head -10
fi

# Node 同 repo import — 仅当有 Node 模块
if [ -n "$NODE_DIRS" ]; then
  grep -rh "^import .* from ['\"]\\.\\./" $NODE_DIRS --include="*.ts" --include="*.js" --include="*.vue" 2>/dev/null | head -10
fi
```

**关键点**：
- 必须用 `[ -n "$X" ] && ...` 或 `if [ -n ... ]` 兜底，**空变量传给 grep 会导致扫 cwd 全部**，误报严重
- `xargs -r` 防止 grep 无匹配时传空参数给下一个命令

若发现引用了**未选中**的模块，提示：
```
⚠️ {selected_module} 引用了未选中的 {referenced_module}（通过 Feign / import）
  - 加入分析（推荐，否则契约比对会缺一边）
  - 跳过（仅理解 SCOPE 内的代码）
```

### 1.6 写入 scope.md

```bash
mkdir -p .claude-notes
cat > .claude-notes/scope.md <<EOF
# 本次分析范围（由 Step 1 用户确认）

mode: {single | monorepo | multi-module-maven}
generated_at: {timestamp}

## 选中的模块
EOF
for d in $SCOPE_DIRS; do
  echo "- \`$d\`" >> .claude-notes/scope.md
done
```

后续所有 Step 都依赖这份文件。

## Step 2: 解析用户参数

```
将 $ARGUMENTS 解析为:
  - scope_filter: only / exclude / 自由文本 / 全部
  - force_overwrite: bool
  - specific_modules: List[str]

把解析结果作为 Step 1 的"已知范围描述"输入。
```

## Step 3: 检测项目类型 + 加载 references

**先读 `.claude-notes/scope.md`**：
- 如果文件存在且 mode=single → 在仓库根检测类型（按下表）
- 如果文件存在且 mode=monorepo → **遍历每个 SCOPE 模块**，每个独立检测类型并独立走完整 Step 5-7（笔记目录用 `.claude-notes/{module_name}/roundN.md` 区分）
- 如果文件存在且 mode=multi-module-maven → 仍统一加载 `java_springboot.md`，但 Prompt 1.0 的 SRC_ROOTS 限制为 SCOPE 内的子模块
- 文件不存在 → 默认仓库根（单模块快路径）

进入仓库后，按以下顺序检测：

```
存在 build.gradle 或 pom.xml     → Java Spring Boot → 读 ${CLAUDE_PLUGIN_ROOT}/templates/understand/references/java_springboot.md
存在 package.json 且含 "vue"      → Vue 前端         → 读 ${CLAUDE_PLUGIN_ROOT}/templates/understand/references/vue_frontend.md
存在 requirements.txt 或 pyproject.toml → Python 项目 → 进入 Python 子类型检测
```

Python 子类型检测（优先用仓库名判断，不明确时用依赖+代码特征判断）：

```
第一优先级：仓库目录名匹配业务关键词
  目录名含 schedul/dispatch/planner/orchestrat/job      → 调度系统   → references/python_scheduler.md
  目录名含 data/proc/etl/pipeline/transform/aggregat    → 数据处理   → references/python_dataproc.md
  目录名含 algo/detect/vision/inference/predict         → 算法系统   → references/python_algo.md
  目录名含 api/service/server/web/gateway               → 通用 HTTP API → references/python_generic.md
  目录名含 cli/tool/util/script                          → 通用 CLI    → references/python_generic.md
  目录名含 sdk/lib/-py/_py（结尾 .py 后缀）              → 通用 库     → references/python_generic.md
  目录名含 agent/llm/ai/chatbot                          → 通用 LLM 应用 → references/python_generic.md

第二优先级：依赖特征
  requirements.txt 含 APScheduler/celery/rq                       → 调度系统
  requirements.txt 含 pandas/polars/pyspark + 无 web/CLI 框架      → 数据处理
  requirements.txt 含 numpy+scipy / torch / onnx / 模型文件存在    → 算法系统
  requirements.txt 含 fastapi/flask/django/starlette/sanic         → 通用（http-api）
  requirements.txt 含 click/typer + 无 web 框架                     → 通用（cli-tool）
  requirements.txt 含 anthropic/openai/langchain/llamaindex         → 通用（llm-app）
  pyproject.toml 含 [project.scripts] 但无 web 框架                  → 通用（cli-tool 或 library）

第三优先级（fallback）：
  都不匹配 → references/python_generic.md（**不再用 scheduler 兜底**）
```

**多匹配的处理**：
- 业务专属（调度/数据处理/算法）+ 通用形态（HTTP API/CLI）同时命中 → 业务专属优先（业务知识更值钱）
- 多个业务专属同时命中（如既有 pandas 又有 torch）→ 问用户：
  "我检测到依赖中同时有 [pandas] 和 [torch]，可能是数据处理或算法系统。请确认项目主要类型。"
- 通用形态多种同时命中（如 FastAPI + Click） → 选 `python_generic.md`，在 Prompt 1 中识别为 mixed 子形态

检测方式：
```bash
REPO_NAME=$(basename $(pwd))
echo "仓库名: $REPO_NAME"

# 业务专属
grep -i "apscheduler\|celery\|^rq$" requirements.txt 2>/dev/null | head -3
grep -i "pandas\|polars\|pyspark" requirements.txt 2>/dev/null | head -3
grep -i "numpy\|scipy\|torch\|tensorflow\|onnx\|scikit" requirements.txt 2>/dev/null | head -3
find . -maxdepth 3 -name "*.pkl" -o -name "*.onnx" -o -name "*.pt" -o -name "*.h5" 2>/dev/null | head -3

# 通用形态
grep -i "fastapi\|flask\|django\|starlette\|sanic\|aiohttp" requirements.txt 2>/dev/null | head -3
grep -iE "^(click|typer)([=<>~!]|$)" requirements.txt 2>/dev/null | head -3
grep -i "anthropic\|openai\|langchain\|llamaindex" requirements.txt 2>/dev/null | head -3

# pyproject.toml 检查（PEP 621/518）
grep -A5 "\[project.scripts\]\|\[tool.poetry.scripts\]" pyproject.toml 2>/dev/null
```

**检测完成后，读取对应的 reference 文件，按其中的 6 个 Prompt 逐轮执行。**

**references 路径**：所有指南都在 `${CLAUDE_PLUGIN_ROOT}/templates/understand/references/`（套件自带，无外部依赖）。

| 检测条件 | 加载文件 | 行数 |
|---------|---------|------|
| `pom.xml` / `build.gradle` 存在 | `java_springboot.md` | 530 |
| Python 通用 | `python_generic.md` | 452 |
| 算法服务（YOLO/PaddleOCR/CV）| `python_algo.md` | 379 |
| 数据处理（asyncio/pandas）| `python_dataproc.md` | 337 |
| 调度系统（Flask/ROS）| `python_scheduler.md` | 333 |
| Vue 前端（vue.config.js）| `vue_frontend.md` | 302 |

reference 文件未找到 → 提示套件安装不完整（`${CLAUDE_PLUGIN_ROOT}/templates/understand/references/` 缺失），重跑 install 脚本。

## Step 4: 初始化笔记目录

```bash
mkdir -p .claude-notes
```

## Step 5: 按轮次执行 Prompt 1-4.5

读取对应的 reference 文件后，**自动执行 Prompt 1 到 Prompt 4.5**（用户无需介入）。

**执行完 Prompt 4.5 后不要继续，进入 Step 6。**

每轮通用规则：

### 5.1 SCOPE 处理（Monorepo / 多 module 必读）

读 `.claude-notes/scope.md` 获取本次分析范围 `SCOPE_DIRS`。

**对 reference 文件中的所有 `find . / grep ... .` 命令做以下替换**：
- 单模块仓库（`mode: single`）→ 不变，保持 `.`
- Monorepo（`mode: monorepo`）→ **每个模块独立运行 reference 流程**，cwd 切到该模块目录，find/grep 仍用 `.`，但起点变了
- 多 module Maven（`mode: multi-module-maven`）→ `find` 命令限制在 SCOPE_DIRS 内，例如 `find $SCOPE_DIRS -path "*/src/main/java/*"`；grep 命令的搜索路径改为 `$SCOPE_DIRS`

**笔记目录命名规则**：
- 单模块 → `.claude-notes/round1.md`（现状）
- Monorepo → `.claude-notes/{module_name}/round1.md`（每模块独立）
- 多 module Maven → 仍用 `.claude-notes/round1.md`（统一一份，但内容里按子模块分段）

### 5.2 大文件防护

读任何代码文件前先 `wc -l` 检查行数：
- ≤ 200 行：直接 cat
- 200-500 行：只读关键部分（方法签名 + 核心逻辑），用 `sed -n 'Xp,Yp'` 截取
- \> 500 行：先 `grep -n "关键词"` 定位，再读目标段落前后 30 行

### 5.3 文件数量防护

find/grep 找到文件列表后先数数量：
- ≤ 10 个：逐个读
- 10-20 个：只读前 10 个 + 列出剩余文件名
- \> 20 个：只列文件名，按以下优先级选 5-8 个读：
  1. 被 Controller/Consumer 方法直接引用的（从 Prompt 2 结果中提取参数类型名）
  2. 被 MQ Producer 引用的消息体类
  3. 文件名含 Create/Update/Request/Response 的

### 5.4 命令找不到结果

每个 reference 文件中的 grep 命令都附带 fallback 关键词。主命令返回空就用 fallback 重试。

### 5.5 笔记写入

每轮产出必须写入 `.claude-notes/roundN.md`，不要只输出到对话中。
下一轮开头从文件读取上一轮笔记。

### 5.6 笔记格式

每轮笔记必须包含：
- 结构化条目（不是散文）
- 【确认项】：确定正确的信息
- 【存疑项】：无法从代码确认的问题

## Step 5.5: Prompt 4.6 — DB 字典查询（按模块）

时序：Prompt 4.5 之后、Prompt 5（验证 + 提问）之前。

**目的**：CLAUDE.md 不能只描述 schema，要含真实字典值，方便后续 fix/dev 知道枚举有哪些。

### 5.5.1 判断模块是否有 DB

```
对每个 SCOPE 模块:
  Phase A: 读 .claude-notes/{module}/round2.md "DB schema" 节，找 MySQL/PostgreSQL/SQLite 关键字
  Phase B（兜底）: Grep "datasource|jdbc:|database:|DATABASE_URL" path={module_dir}/**/application*.yml + config*.yml + settings.py
  
  任一命中 → 视为有 DB，进入 5.5.2
  都未命中 → 跳过该模块
```

### 5.5.2 调 probe-db intent=query-dict

```
Read ${CLAUDE_PLUGIN_ROOT}/templates/runtime-probe/probe-db.md
准备输入:
  module = {当前模块名}
  intent = "query-dict"
按"步骤"节执行 → 拿 query_result
```

### 5.5.3 结果归档

```
match query_result.status:
  "ok":
    探针已写 .claude-notes/{module}/dict-snapshots.md
    在 round2.md 的 "DB Schema" 节末尾追加一行链接:
      "- 字典值快照: [dict-snapshots.md](./dict-snapshots.md)"
  
  "no-creds" / "conn-failed" / "skipped":
    在 round2.md 末尾追加:
      "字典查询跳过：{query_result.error}"
    继续下一个模块（不阻塞合成 Step）
```

### 容错

| 场景 | 行为 |
|------|------|
| state.yml 不存在 | 探针返 skipped → 在 round2.md 末尾追加"字典查询跳过：no state.yml"，提示用户先 /mpdev:env start，继续 |
| 用户拒填凭据（选"跳过此次"）| 探针返 skipped, error="credentials collection declined by user" → 本模块跳过，继续下一个 |
| mysql MCP 未配置 + 无 mysql CLI | 探针策略 C → skipped, error="no mysql client available" → 本模块跳过，继续 |
| 字典表 0 命中 | 探针返 status=ok 但 evidence 为空，写 "未发现字典表" 到 snapshots |

## Step 5.6: Prompt 4.7 — WebSocket 端点静态扫描

时序：5.5 之后、Step 6 之前。

### 5.6.1 调 probe-ws

```
对每个 SCOPE 模块:
  Read ${CLAUDE_PLUGIN_ROOT}/templates/runtime-probe/probe-ws.md
  准备输入:
    module = {当前模块名}
  按"步骤"节执行 → 拿 ws_result
```

### 5.6.2 结果归档

```
match ws_result.status:
  "ok":
    探针已写 .claude-notes/{module}/ws-endpoints.md
    在 round2.md "接口边界" 节追加 "WebSocket 端点" 子节，含摘要表（路径 + handler + 方向 + 消息数）
  
  "no-endpoints":
    在 round2.md "接口边界" 节追加 "WebSocket 端点：无（grep 未命中）"
  
  "skipped":
    在 round2.md 追加 "WebSocket 扫描跳过：{ws_result.error}"
```

### 容错

| 场景 | 行为 |
|------|------|
| 模块语言未识别 | 探针返 skipped，本 Step 跳过 |
| handler 文件不可读 | 探针仍返 ok，messages 为空，notes 中标注 |

## Step 6: Prompt 5 — 验证、提问与 TODO

Prompt 1-4.5 执行完后，执行 Prompt 5：
- 读测试文件 + git log
- 汇总存疑项
- **将分析过程中发现的代码问题整理为 TODO 清单**，分四类（🔴 Bug/风险、🟡 设计优化、🟢 规范改进、❓ 待确认），写入 `.claude-notes/todo.md`

**⏸️ 暂停点：执行完 Prompt 5 后必须停下来**，将存疑项和 TODO 清单一起呈现给用户，等待用户逐条回答。不要跳过这一步直接合成 CLAUDE.md。

每个问题必须说明：
- 问题本身
- 为什么代码中看不出答案
- 当前的猜测（如果有）

### 6.1 补救重跑（用户发现遗漏模块时）

如果用户在 Prompt 5 之后发现还需要分析范围外的模块（来自 Step 1.5 的依赖预检或自己提出）：

1. **已回答的存疑项不重复呈现**：旧模块的存疑项用户已答复，结果已存在于 `.claude-notes/{旧模块}/round5-answers.md`，直接保留
2. **更新 scope.md**：把新加入的模块追加到"选中的模块"列表，并加 `amended_at: {timestamp}` + `amended_modules: [...]`
3. **只对新模块跑 Prompt 1~4.5**：不重跑旧模块，避免上下文浪费
4. **只对新模块做 Prompt 5 提问**：用户单独回答新模块的存疑项 + 同类补救问题（此时若再发现新的范围外依赖，递归处理，最多 2 轮防止无限扩张）
5. **Step 7 合成时**：旧模块用户答 + 新模块用户答 **合并使用**，旧模块的 CLAUDE.md **不重写**（其内容不会因为新模块的加入而变化；只是"与其他模块的关系"段需要把新模块的依赖关系显式标注从 `⚠️ 未深度理解` 升级为 `✅ 已理解`——这一条更新用 Edit 做局部修改，不是 Write 全量重写）

## Step 7: Prompt 6 — 合成 CLAUDE.md + TODO.md

用户回答存疑项后，执行 Prompt 6。**先读 `.claude-notes/scope.md` 决定写入位置**：

| mode | 笔记读取 | 写入位置 |
|------|---------|---------|
| `single` 或 scope.md 不存在 | `.claude-notes/round{1..4}.md` + `todo.md` | 仓库根 `CLAUDE.md` + `TODO.md`（现状）|
| `monorepo` | 对每个 SCOPE 模块：`.claude-notes/{module}/round{1..4}.md` + `{module}/todo.md` | **每个模块的根** `{module}/CLAUDE.md` + `{module}/TODO.md`（多份）|
| `multi-module-maven` | `.claude-notes/round{1..4}.md`（统一一份按子模块分段） | 仓库根 `CLAUDE.md` 一份；TODO.md 同 |

读取笔记 + 用户回答，生成：
1. **CLAUDE.md**：项目上下文文件
2. **TODO.md**：待优化项清单（根据用户回答更新——确认是 bug 的保留，用户说"有意设计"的移除）

**如果项目根目录已有 CLAUDE.md**：
1. 先备份：`cp CLAUDE.md CLAUDE.md.bak.{timestamp}`
2. 读取旧 CLAUDE.md 中的"已知隐含知识"区块内容，合并到新版本中
3. 新 CLAUDE.md 末尾标注生成时间

### 7.1 通用区块（所有项目类型都必须包含）

1. 技术栈
2. 目录结构
3. ⚠️ 接口字段（跨模块字段，改了必须同步契约仓库）
4. 内部字段（模块内自由修改的字段）
   4a. WebSocket 端点（v1.3.0 新增；从 Step 5.6 的 ws-endpoints.md 抽摘要）
   4b. 字典常量（v1.3.0 新增；从 Step 5.5 的 dict-snapshots.md 抽表名+用途+引用，不嵌全表）
5. 编码规范（必须从第 4 轮代码采样归纳，标注依据来源，不要写泛泛空话）
6. 构建与部署
7. 与其他模块的关系
8. 已知隐含知识（第 5 轮用户回答的内容）

#### 4a. WebSocket 端点 — 形态规则

```markdown
## WebSocket 端点

| 路径 | handler | 方向 | 消息类型数 | 详细 |
|------|---------|------|----------:|------|
| /ws/task-events | TaskEventsHandler.java:45 | bidirectional | 3 | [ws-endpoints.md](.claude-notes/{module}/ws-endpoints.md#ws-task-events) |
```

不嵌完整消息 schema —— 详细 schema 留在 ws-endpoints.md，CLAUDE.md 只给索引。

#### 4b. 字典常量 — 形态规则

```markdown
## 字典常量

| 字典表           | 用途           | 值数量 | 详细快照 |
|------------------|---------------|------:|---------|
| dict_task_type   | 任务类型枚举   | 8     | [snapshots](.claude-notes/{module}/dict-snapshots.md#dict_task_type) |
| sys_status       | 系统状态码     | 5     | [snapshots](.claude-notes/{module}/dict-snapshots.md#sys_status) |
```

不嵌全表内容 —— 详细行留在 dict-snapshots.md，CLAUDE.md 只给目录。

### 7.2 类型特有区块

在 reference 文件的 Prompt 6 中定义，不同项目类型有不同的核心区块。

### 7.3 质量要求

- 总长度 300-500 行
- 业务规则标注代码出处（类名.方法名 L行号）
- 不写显而易见的内容（"这是一个 Java 项目"）
- 编码规范从代码采样归纳，不要写"遵循阿里规范"这类空话

### 7.4 中间产物（用户应了解，但无需手工管理）

合成过程会产生以下中间文件（命令运行时自管理）：

- `.claude-notes/scope.md` — Step 1 写入的范围确认结果
- `.claude-notes/round{1..4}.md` 和 `round4.5.md` — 各轮分析笔记
- `.claude-notes/todo.md` — Step 6 整理的 TODO 清单（用户回答后会被更新）
- **Monorepo 模式**笔记目录改为 `.claude-notes/{module_name}/round{N}.md`

**最终产出**（用户关心的）：

- 各模块根的 `CLAUDE.md`（mode 决定一份/多份）
- 各模块根的 `TODO.md`
- `mpdev-runs/setup/{timestamp}-understand-{slug}.md`（Step 8 额外的归档）

### 7.5 三种 mode 对照表

| mode | 适用 | 笔记目录 | CLAUDE.md 写入位置 |
|------|------|---------|-------------------|
| `single` | 单模块仓库（根含 pom.xml / package.json 等） | `.claude-notes/round*.md` | 仓库根一份 |
| `monorepo` | 多模块仓库（兄弟目录各有独立项目文件） | `.claude-notes/{module}/round*.md` | 每个模块根各一份 |
| `multi-module-maven` | Maven 聚合工程（根 pom.xml 含 `<modules>`） | `.claude-notes/round*.md`（按子模块分段） | 仓库根一份（按子模块分段） |

## Step 8: 📄 文档归档

在每个模块目录写完 `CLAUDE.md` 之后，额外在 mpdev 体系归档执行记录：

```
timestamp = 当前时间 YYYYMMDD-HHMM
slug = scope 简述（如 "java-vue-dispatch"）
file_id = "{timestamp}-understand-{slug}"

Bash("mkdir -p .claude/mpdev:runs/setup")
Write(".claude/mpdev:runs/setup/{file_id}.md", ...)
```

**归档模板**：

```markdown
---
stage: understand
generated_at: {timestamp}
scope: [{module1}, {module2}, ...]
total_modules_processed: N
---

# 项目理解记录

## 用户输入
> {$ARGUMENTS 原文}

## 处理范围
| 模块 | 路径 | CLAUDE.md 状态 | TODO.md 项数 |
|------|------|----------------|------------:|
| {name} | {dir} | 新建/覆盖/未变 | N |

## 关键发现
- 技术栈分布：...
- 跨模块通信：...
- 风险/盲区（来自 TODO.md 汇总）：...

## 下一步建议

- ✅ 各模块 CLAUDE.md 已就绪
- ➡️ 建议下一步运行 `/mpdev:contracts` 生成契约仓库
- 或手动 review 某模块的 CLAUDE.md 后再决定

## 关联文件
- {module1}/CLAUDE.md
- {module1}/TODO.md
- ...
```

## Step 9: 与下游命令的衔接提示

执行完成后，根据本次产出动态推荐下一步：

```
if 多模块且未发现现有 robot-contracts/:
  → "建议下一步: /mpdev:contracts 生成契约仓库"
elif 已有 robot-contracts/ 但 .claude/agents/ 缺失:
  → "建议下一步: /mpdev:init 初始化 mpdev 编排器"
elif .claude/agents/ 已就绪:
  → "建议: /mpdev:dev 描述需求开始开发；或先 /mpdev:check 验证契约一致性"
```

---

## 中断恢复

流程支持中断恢复：

- 中断后再跑 `/mpdev:understand`，会读 `.claude-notes/` 已有 round 文件，**从下一轮继续**
- 例：`round1.md` / `round2.md` 已存在 → 直接从 Prompt 3 开始，节省上下文
- 想强制重新开始：先 `rm -rf .claude-notes/`

## 何时更新 CLAUDE.md

| 触发条件 | 更新方式 |
|---|---|
| 新增 API / MQ 事件 / 数据库表 | 追加到对应列表 |
| 重构目录结构 | 更新目录结构部分 |
| 引入新编码规范 | 更新编码规范部分 |
| 大版本升级 | 重跑完整 5 轮 |
| 半年以上没更新 | 重跑完整 5 轮 |
| 日常小改动 | 通过 git diff 增量更新即可 |

## 多模块项目的执行顺序

如果项目有多个仓库，推荐顺序：
1. 后端（连接中心）→ 2. 契约仓库 → 3. 调度 → 4. 数据处理 → 5. 算法 → 6. 前端

每完成一个模块的 CLAUDE.md，和已完成的做交叉验证：
- A 模块说发布了 task.created，B 模块说消费了 task.created → ✅
- A 模块说字段是 taskId(String)，B 模块说是 task_id(int) → ❌ 需确认

---

## 容错规则

| 情况 | 处理 |
|------|------|
| reference 文件未找到 | 提示套件安装不完整（`${CLAUDE_PLUGIN_ROOT}/templates/understand/references/` 缺失），重跑 install 脚本 |
| 单模块仓库（无需选范围） | 跳过 Step 1，直接进 Step 3 |
| 用户输入歧义（"差不多""你定"）| 拒绝并重申选项 |
| CLAUDE.md 已存在且未指定 force | 询问用户：[覆盖 / 跳过此模块 / 全部覆盖 force]|
| 中途用户说"停" | 立即终止；已生成的 CLAUDE.md 保留 |
| 模块识别失败 | 让用户手动指定模块路径 |

## 约束

1. **强制范围确认** — 多模块仓库不跳过 Step 1
2. **置信度标注必有** — 生成的 CLAUDE.md 必须含 confidence 字段（high/medium/low）
3. **TODO.md 同步产出** — 不只写 CLAUDE.md，把待优化项落到 TODO.md
4. **覆盖前必备份** — force 模式也要备份 `.bak.{timestamp}`
5. **不自动跳到 contracts** — 完成后展示建议，不自动调用 `/mpdev:contracts`（让用户审查 CLAUDE.md 后再决定）
6. **必写归档文档** — 即使部分模块失败也写一份归档到 `mpdev-runs/setup/`
7. **Prompt 5 后必暂停** — 不跳过用户回答直接合成 CLAUDE.md
