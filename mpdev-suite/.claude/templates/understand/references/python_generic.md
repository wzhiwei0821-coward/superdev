# Python 通用项目 — 分轮执行指令

> 本文件由 SKILL.md 在检测到通用 Python 项目时加载（fallback；不属于调度/数据处理/算法专属类型）。按 Prompt 1-6 逐轮执行。
>
> **适用场景**：
> - HTTP API 服务（FastAPI / Flask / Django / Starlette / Sanic）
> - CLI 工具（Click / Typer / argparse）
> - 后台 worker / 守护进程
> - 库 / SDK / 框架
> - 自动化脚本 / ETL one-shot 任务
> - AI Agent / LLM 应用
>
> **判断子形态**：在 Prompt 1 完成后，根据依赖和入口选择本文件后续 Prompt 中对应的"子形态分支"。

---

## Prompt 1 — 项目骨架

笔记写入 `.claude-notes/round1.md`。

1. 依赖：
   ```bash
   cat requirements.txt 2>/dev/null
   cat pyproject.toml 2>/dev/null
   cat setup.py 2>/dev/null
   cat Pipfile 2>/dev/null
   ```
   → 提取：Python 版本、Web 框架（FastAPI/Flask/Django/...）、CLI 框架（Click/Typer/argparse）、ORM、数据库驱动、HTTP 客户端、LLM SDK（anthropic/openai/langchain）、其他重要库

2. **子形态识别**（重要）：
   | 形态 | 判定条件 |
   |------|---------|
   | http-api | 依赖含 fastapi / flask / django / starlette / sanic / aiohttp.web |
   | cli-tool | 依赖含 click / typer，或入口含 `argparse.ArgumentParser` |
   | worker | 入口含无限循环 + 不开 HTTP 端口；或依赖含 celery worker / rq |
   | library | 有 setup.py / pyproject.toml 但无入口脚本；目录含 `__init__.py` 主包；有 `[project.urls]` 或 PyPI 元数据 |
   | script | 单个/少量 .py 文件，无 framework 依赖，主要靠 `if __name__ == "__main__":` 触发 |
   | llm-app | 依赖含 anthropic / openai / langchain / llamaindex |
   | mixed | 多个形态混合（如 FastAPI + 后台 worker 同进程）|

3. 目录结构：
   ```bash
   find . -type f -name "*.py" | grep -v __pycache__ | grep -v ".venv" | grep -v test | sort | head -80
   ```

4. 入口文件：
   ```bash
   cat src/main.py 2>/dev/null || cat app.py 2>/dev/null || cat main.py 2>/dev/null || cat run.py 2>/dev/null
   # CLI
   grep -l "ArgumentParser\|@click\|@app.command\|typer.Typer" --include="*.py" -r . | head -3 | xargs cat
   # FastAPI/Flask 入口
   grep -l "FastAPI()\|Flask(__name__)\|asgi_app\|wsgi_app" --include="*.py" -r . | head -3
   ```
   → 提取：启动方式、入口签名（CLI 命令、HTTP 服务器、worker 主循环）、初始化组件、命令行参数

5. 配置：
   ```bash
   # 先确定代码搜索根（src layout vs flat layout）
   if [ -d "src" ]; then CODE_ROOT="src"; else CODE_ROOT="."; fi
   echo "代码根：$CODE_ROOT"

   find . -name "*.yml" -o -name "*.yaml" -o -name "*.toml" -o -name "*.ini" | grep -iv test | grep -i "config\|settings" | head -5
   cat .env.example 2>/dev/null
   # Pydantic Settings / dynaconf
   grep -rn "BaseSettings\|Dynaconf\|os.environ" $CODE_ROOT --include="*.py" 2>/dev/null | grep -v "/.venv/\|/__pycache__/" | head -10
   ```

   注：每个 Prompt 在 bash 中独立执行，`$CODE_ROOT` 不会跨 Prompt 持久。后续每个 Prompt 开头都重新做一次相同的 `if [ -d "src" ]` 判定。

笔记格式：

```
# 第 1 轮：项目骨架
## 子形态
（http-api / cli-tool / worker / library / script / llm-app / mixed — 主形态 + 次形态）
## 技术栈
- Python 版本：
- 主框架：（FastAPI 0.x / Click 8.x / 无 / ...）
- ORM：
- HTTP 客户端：（仅有外调时）
- LLM SDK：（仅 llm-app）
- 异步：
## 目录结构
（每个目录一句话说明）
## 入口
（命令行/HTTP 路径/worker 启动函数；说明形态）
## 关键配置项
## 存疑项
```

---

## Prompt 2 — 接口边界

先 `cat .claude-notes/round1.md` 确认子形态。笔记写入 `.claude-notes/round2.md`。

确定代码搜索路径：
```bash
if [ -d "src" ]; then CODE_ROOT="src"; else CODE_ROOT="."; fi
```

**按子形态执行不同的扫描组合**：

### 子形态 A — http-api（FastAPI/Flask/Django/...）

A1. 路由扫描：
   ```bash
   # FastAPI
   grep -rn "@app\.\(get\|post\|put\|delete\|patch\)\|@router\.\(get\|post\|put\|delete\|patch\)\|APIRouter" $CODE_ROOT --include="*.py" -B1 -A5
   # Flask
   grep -rn "@app\.route\|@bp\.route\|add_url_rule" $CODE_ROOT --include="*.py" -B1 -A5
   # Django
   grep -rn "path(\|re_path(\|url(" $CODE_ROOT --include="*.py" -B1 -A2
   find $CODE_ROOT -name "urls.py" | head -10 | xargs cat
   ```
   → 提取：路径、HTTP 方法、handler 函数、参数模型、返回模型

A2. 请求/响应模型：
   ```bash
   grep -rn "BaseModel\|TypedDict\|dataclass\|@dataclass\|Schema" $CODE_ROOT --include="*.py" -l
   ```
   → 提取：类名、字段、校验规则

A3. 中间件 / 依赖注入：
   ```bash
   grep -rn "Depends\|@app.middleware\|@app.before_request\|@app.exception_handler" $CODE_ROOT --include="*.py"
   ```

A4. 鉴权：
   ```bash
   grep -rn "Security\|HTTPBearer\|OAuth2\|JWT\|@login_required" $CODE_ROOT --include="*.py" -l
   ```

### 子形态 B — cli-tool

B1. 命令清单：
   ```bash
   grep -rn "@app.command\|@cli.command\|@group.command\|add_subparsers" $CODE_ROOT --include="*.py" -B1 -A5
   ```
   → 提取：每个命令名、参数、help 文本

B2. 全局选项：
   ```bash
   grep -rn "@click.option\|typer.Option\|add_argument" $CODE_ROOT --include="*.py" | head -20
   ```

B3. 入口脚本 entry point：
   ```bash
   grep -A10 "entry_points\|\[project.scripts\]" pyproject.toml setup.py 2>/dev/null
   ```

### 子形态 C — worker / 后台进程

C1. 任务源：
   - 消息队列：参考 python_scheduler.md 的 MQ 消费者扫描
   - 定时调度：grep -rn "APScheduler\|schedule\.\|cron\|@scheduler" $CODE_ROOT --include="*.py"
   - 文件监听：grep -rn "watchdog\|inotify" $CODE_ROOT --include="*.py"
   - 数据库轮询：grep -rn "while True\|sleep" $CODE_ROOT --include="*.py" -B2 -A5

### 子形态 D — library

D1. 公开 API：
   ```bash
   # __init__.py 中的 __all__ 列表
   find $CODE_ROOT -name "__init__.py" | xargs grep -l "__all__"
   ```
   → 提取每个模块对外暴露的符号

D2. 文档/示例：
   ls examples/ 2>/dev/null
   ls docs/ 2>/dev/null

### 子形态 E — llm-app

E1. LLM 调用：
   ```bash
   grep -rn "anthropic\.\|client\.messages\.\|openai\.\|client\.chat\." $CODE_ROOT --include="*.py" -B2 -A8
   ```
   → 提取：模型名（claude-* / gpt-*）、参数（temperature/max_tokens）、prompt cache 配置

E2. Tools / Function Calling：
   ```bash
   grep -rn "tool_use\|function_call\|tools=\|@tool" $CODE_ROOT --include="*.py" | head -20
   ```

E3. 提示词管理：
   ```bash
   grep -rn 'system="""\|prompt =\|system_prompt' $CODE_ROOT --include="*.py" | head -10
   find $CODE_ROOT -name "prompts.py" -o -name "*.prompt" -o -path "*prompt*" | head -5
   ```

### 通用扫描（所有子形态都做）

F. 外部 HTTP 调用：
   ```bash
   grep -rn "requests\.\|httpx\.\|aiohttp\.\|urllib" $CODE_ROOT --include="*.py" | head -10
   ```

G. 数据库（如有）：
   ```bash
   grep -rn "SELECT\|INSERT\|UPDATE\|execute\|cursor\|session\.\|to_sql" $CODE_ROOT --include="*.py" -l | head -10
   ls contracts/sql/ 2>/dev/null && cat contracts/sql/*.sql
   ```

H. MQ（如有，参考 python_scheduler 的 A/B 两节）

笔记格式（按子形态填）：

```
# 第 2 轮：接口边界
## 子形态：{从 round1 复制}

## (http-api) 路由清单
| 路径 | 方法 | handler | 请求模型 | 响应模型 | 鉴权 |
|---|---|---|---|---|---|

## (cli-tool) 命令清单
| 命令 | 子命令 | 参数 | 说明 |
|---|---|---|---|

## (worker) 任务源
| 类型 | 触发 | 处理函数 | 说明 |
|---|---|---|---|

## (library) 公开 API
| 模块 | 符号 | 类型(类/函数/常量) | 说明 |
|---|---|---|---|

## (llm-app) LLM 调用
| 调用位置 | 模型 | 关键参数 | 是否带 tools | 是否启用 cache |
|---|---|---|---|---|
（必检：是否启用 prompt caching、是否开启 extended thinking、是否复用 client）

## 数据模型
（BaseModel / dataclass / TypedDict 列表）

## 外部 HTTP 调用
## 数据库操作
## MQ 接口（如有）
## 存疑项
```

---

## Prompt 3 — 核心业务流

先读前两轮笔记。笔记写入 `.claude-notes/round3.md`。
大文件防护：超 200 行先 `grep -n "def "` 看方法列表。

选 2-4 条最核心的"端到端调用"（按子形态各异）：
- **http-api**：从一条 API 入口追到 DB 写入 / 外部 HTTP / 响应返回
- **cli-tool**：从命令入口追到副作用完成
- **worker**：从任务接收追到处理完成 + 状态变更
- **library**：从公开 API 函数追到关键私有函数完成
- **llm-app**：从 user input 追到 LLM 响应返回（含 tool 调用循环）

对每条链路提取：
1. 入口签名 → 调用链 → 出口
2. 参数校验 / 异常处理 / 重试机制
3. 副作用（DB 写、文件写、网络调用、状态变更）
4. 异步 vs 同步、并发模型
5. 隐含业务规则（标注出处 xxx.py L行号）

笔记格式：

```
# 第 3 轮：核心业务流
## 链路 1：（名称）
入口：xxx.py 中的 funcName / route handler
调用链：A → B → C
详细步骤：
  1.
  2.
副作用：
异常处理：
异步/同步：
隐含业务规则：
  - 规则1（出处：xxx.py L行号）

## 链路 2：...

## 状态机（如有）
## 全局状态（如有：内存缓存、单例、连接池）
## 存疑项
```

---

## Prompt 4 — 基础设施与编码风格

先 `cat .claude-notes/round3.md`，笔记写入 `.claude-notes/round4.md`。

A. 异常处理：
   ```bash
   find $CODE_ROOT -name "*exception*" -o -name "*error*" | grep ".py$" | head -5 | xargs cat
   grep -rn "except.*:" $CODE_ROOT --include="*.py" | head -20
   # FastAPI exception_handler / Flask errorhandler
   grep -rn "exception_handler\|errorhandler" $CODE_ROOT --include="*.py"
   ```

B. 日志：
   ```bash
   grep -rn "logging\.\|logger\.\|structlog\.\|loguru\." $CODE_ROOT --include="*.py" | head -20
   ```

C. 编码风格采样：
   - 类型标注深度（PEP 484 / PEP 695 / mypy strict）
   - 数据类（dataclass / Pydantic / attrs / TypedDict / dict）
   - 异步模式（async/await / threading / multiprocessing / 同步）
   - OOP / 函数式 / 过程式
   - 依赖注入（DI 容器 / FastAPI Depends / 手动）
   - 测试框架（pytest / unittest / hypothesis）
   - 项目布局（src layout / flat layout）

D. 代码质量：
   ```bash
   cat pyproject.toml | grep -A10 "\[tool\.\(black\|ruff\|mypy\|isort\|pytest\)\]"
   cat .pre-commit-config.yaml 2>/dev/null
   cat .ruff.toml .flake8 mypy.ini 2>/dev/null
   ```

E. **[llm-app] LLM 应用专项检查**：
   - **Prompt cache 启用情况**：搜 `cache_control` / `extended-cache-ttl` — 系统提示是否被缓存？
   - **Client 复用**：是否 module-level 单例 client，还是每次新建（每次新建丢 cache）
   - **Token 用量监控**：是否记录 `usage.input_tokens` / `cache_creation` / `cache_read`
   - **错误重试**：429/529 是否走 SDK 内置重试（默认开启）

笔记格式：

```
# 第 4 轮：基础设施与编码风格
## 异常处理
- 自定义异常类：
- 处理模式：
- 框架级 handler（如有）：
## 日志规范（从采样归纳）
- 日志库：
- 格式模式：
- 级别使用：
## 编码风格（从采样归纳，标注依据来源）
- 类型标注深度：（依据：xxx.py）
- 数据类选择：
- 异步模式：
- 项目布局：
- 命名约定：
## 代码质量配置
（black/ruff/mypy 配置摘要）
## (llm-app) LLM 应用质量
- Prompt caching：（启用/未启用 — 命中率指标？）
- Client 复用：
- Token 监控：
- 错误重试策略：
## 存疑项
```

---

## Prompt 4.5 — 接口完整性校验

先 `cat .claude-notes/round2.md`。按本项目子形态执行对应的反向扫描：

```bash
# 通用 — 字符串常量定义的 endpoint / topic
grep -rn "'/[a-z_]*'\|\"/[a-z_]*\"" $CODE_ROOT --include="*.py" | grep -v test | head -20

# (http-api) 反向：所有装饰器形式的 handler
grep -rn "^@.*\(get\|post\|put\|delete\|patch\|route\)" $CODE_ROOT --include="*.py" | head -30

# (cli-tool) 反向：所有 entry_points 注册的脚本
grep -rn "console_scripts\|\[project.scripts\]\|@.*command" $CODE_ROOT --include="*.py" pyproject.toml setup.py 2>/dev/null

# (library) 反向：__init__.py 之外可能被外部 import 的公开符号
grep -rn "^def [a-z]\|^class [A-Z]" $CODE_ROOT --include="*.py" | grep -v "^.*:\s*\(def _\|class _\)" | head -30

# (llm-app) 反向：所有 system prompt 出现位置（避免遗漏多个 prompt 入口）
grep -rn 'system\s*=\|system_prompt\|"role":\s*"system"' $CODE_ROOT --include="*.py" | head -20

# 已有文档
find docs/ openapi/ -type f 2>/dev/null | head -10
```

将比对结果追加到 `.claude-notes/round2.md` 末尾，格式同其他 reference 文件。

---

## Prompt 5 — 验证与补盲

先读取全部笔记。

1. 读测试：
   ```bash
   find . -path "*test*" -name "*.py" | head -3 | while read f; do
     wc -l "$f"
     grep "def test_" "$f" | head -10
   done
   ```

2. `git log --oneline -20`

3. `head -100 README.md 2>/dev/null`

4. 汇总存疑项提问。每个问题说明：问题、为什么代码看不出、猜测。**子形态相关**的特别问题：
   - **http-api**：是否有 OpenAPI/Swagger 自动生成？版本管理策略？
   - **cli-tool**：发布到 PyPI / 内部仓库？输出格式（人类可读 vs JSON）？
   - **worker**：单实例 vs 多实例？任务幂等性？
   - **library**：语义化版本？破坏性变更如何通知？
   - **llm-app**：模型升级测试机制？fallback 模型？人工审核流程？

5. 接口完整性定向确认：把 round2 的清单展示给用户，按子形态问"是否还有遗漏"。

6. 整理 TODO 清单到 `.claude-notes/todo.md`，分类：🔴 Bug / 🟡 设计优化 / 🟢 规范改进 / ❓ 待确认。

---

## Prompt 6 — 合成 CLAUDE.md

先 `cat .claude-notes/round{1,2,3,4}.md` 和 `cat .claude-notes/todo.md`。

### 文件 1：CLAUDE.md（写入项目根目录）

**通用区块（所有子形态都写）**：
1. 子形态 + 技术栈
2. 目录结构
3. 入口与启动方式
4. 数据模型（请求/响应/领域对象）
5. 外部依赖（HTTP/DB/MQ/LLM API 等）
6. 核心业务流（调用链 + 隐含规则，标注出处）
7. ⚠️ 接口字段（对外接口的字段名/类型/必填）
8. 内部字段
9. 编码规范（从采样归纳，标注依据）
10. 异常处理机制
11. 构建与部署
12. 已知隐含知识

**子形态特有区块（按本项目实际形态选用）**：

| 子形态 | 必加区块 |
|--------|---------|
| http-api | 路由清单 + 鉴权方案 + 请求/响应统一格式 |
| cli-tool | 命令清单 + 全局选项 + 输出约定 + entry_points |
| worker | 任务源（MQ/定时/文件）+ 处理链路 + 幂等机制 + 单/多实例策略 |
| library | 公开 API 索引 + 版本策略 + 兼容性承诺 |
| llm-app | LLM 调用清单 + Prompt cache 策略 + Tool 清单 + 提示词管理 + token/成本监控 |

### 文件 2：TODO.md

基于 `.claude-notes/todo.md` + 用户回答更新后生成最终版。

接口置信度标注规则：
- ✅ 高：代码扫描找到 + 链路追踪验证 + 用户确认
- ⚠️ 中：代码扫描找到但未做链路追踪或用户未确认
- ❓ 低：仅从字符串常量或配置推测
