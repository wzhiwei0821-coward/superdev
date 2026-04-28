# Python 调度系统 — 分轮执行指令

> 本文件由 SKILL.md 在检测到 Python 调度/任务编排类项目时加载。按 Prompt 1-6 逐轮执行。
>
> **适用场景**：以"调度/分配/编排"为核心的 Python 服务，如：任务调度器、作业编排引擎、资源分配服务、工作流引擎等。术语保持中性——文中的"任务（task）"指**被调度的工作单元**（可以是机器人巡检、CI 作业、数据 ETL Job 等），"业务实体 ID"是被调度对象的标识（机器人 ID / Worker ID / Pod ID 等）。请按项目实际语义替换。

---

## Prompt 1 — 项目骨架

笔记写入 `.claude-notes/round1.md`。

1. 依赖：
   cat requirements.txt 2>/dev/null
   cat pyproject.toml 2>/dev/null
   cat setup.py 2>/dev/null
   → 提取：Python 版本、MQ 客户端（pika / aio_pika / kombu）、调度框架（APScheduler / Celery / 自研）、ORM（SQLAlchemy / 无）、序列化（json / msgpack / protobuf）、异步框架（asyncio / 同步）

2. 目录结构：
   find . -type f -name "*.py" | grep -v __pycache__ | grep -v ".venv" | grep -v test | sort

3. 入口文件：
   cat src/main.py 2>/dev/null || cat app.py 2>/dev/null || cat run.py 2>/dev/null
   → 提取：启动方式、初始化组件、命令行参数

4. 配置：
   find . -name "*.yml" -o -name "*.yaml" -o -name "*.toml" -o -name "*.ini" | grep -iv test | grep -i config | head -5
   → cat
   cat .env.example 2>/dev/null
   → 提取：MQ 连接、调度参数（超时、并发、重试）

笔记格式：

```
# 第 1 轮：项目骨架
## 技术栈
- Python 版本：
- MQ 客户端：
- 调度框架：
- ORM：
- 序列化：
- 异步：
## 目录结构
（每个目录一句话说明）
## 启动方式
（入口、参数、初始化流程）
## 关键配置项
（逐个列出，特别是调度相关参数）
## 存疑项
```

---

## Prompt 2 — 接口边界

先 `cat .claude-notes/round1.md`，笔记写入 `.claude-notes/round2.md`。

先确定代码搜索路径（如果 src/ 目录不存在，搜索当前目录）：
```bash
if [ -d "src" ]; then CODE_ROOT="src"; else CODE_ROOT="."; fi
echo "代码根目录: $CODE_ROOT"
```
后续所有 grep/find 命令中的 `src/` 替换为 `$CODE_ROOT/`，并在结果中排除 `.venv|test|__pycache__`。

A. MQ 消费者：
   grep -rn "basic_consume\|on_message\|callback\|consume\|subscribe\|queue" src/ --include="*.py" -l
   → 逐个 cat → 提取：queue/routing_key、反序列化方式、回调函数
   fallback：grep -rn "def.*handle\|def.*process\|def.*on_" src/ --include="*.py" -l

B. MQ 生产者：
   grep -rn "basic_publish\|publish\|send\|produce" src/ --include="*.py" -l
   → 逐个 cat → 提取：exchange、routing_key、消息体
   fallback：grep -rn "channel\.\|connection\.\|producer\." src/ --include="*.py" -l

C. 消息体模型：
   find src/ -name "schemas.py" -o -name "messages.py" -o -name "events.py" -o -name "models.py" -o -name "types.py" | sort
   → cat → 提取字段名和类型
   → 特别关注 snake_case/camelCase 转换逻辑
   fallback：grep -rn "dataclass\|BaseModel\|TypedDict\|NamedTuple" src/ --include="*.py" -l

D. HTTP API（如有）：
   grep -rn "Flask\|FastAPI\|app\.route\|router\.\|@app\." src/ --include="*.py" | head -10
   → 有则提取，无则写"无"

E. 外部调用：
   grep -rn "requests\.\|httpx\.\|aiohttp\.\|urllib" src/ --include="*.py" | head -10

F. 共享数据库 SQL（如果存在 contracts/ 子模块）：
   ls contracts/sql/ 2>/dev/null && cat contracts/sql/*.sql
   → 如果存在，提取本模块可能读写的表结构和初始化数据
   → 如果本模块有直接的数据库操作（grep "SELECT\|INSERT\|UPDATE\|execute\|cursor\|session\." src/ --include="*.py"），
     比对代码中引用的表名/列名是否与 SQL 定义一致

笔记格式：

```
# 第 2 轮：接口边界
## 消费的 MQ 事件（共 x 个）
| Queue/RoutingKey | 来源模块 | 消息体类/结构 | 处理函数 |
|---|---|---|---|
## 发布的 MQ 事件（共 x 个）
| Exchange | RoutingKey | 消息体类/结构 | 核心字段 | 发送位置 |
|---|---|---|---|---|
## 消息体字段映射
| Python 字段(snake_case) | MQ 消息字段(camelCase) | 类型 | 说明 |
|---|---|---|---|
## 数据库操作
（有/无。如有，列出读写的表名和操作类型，标注来源是 contracts/sql/ 还是本模块自有）
## HTTP API
（有/无）
## 外部调用
（有/无）
## 存疑项
```

---

## Prompt 3 — 核心业务流 + 调度算法

先读取前两轮笔记：
   cat .claude-notes/round1.md
   cat .claude-notes/round2.md
笔记写入 `.claude-notes/round3.md`。
大文件防护：超 200 行先 `grep -n "def "` 看方法列表再选择性读。

A. 调度算法：
   find src/ -path "*schedul*" -o -path "*algorithm*" -o -path "*planner*" -o -path "*solver*" | grep ".py$" | sort
   → 对每个文件先 wc -l 再选择性读
   → 提取：算法用途、输入（任务列表？机器人状态？地图？）、输出（分配方案？路径？）、
     算法策略（贪心？最优化？启发式？规则引擎？）、约束条件、可配置参数、性能特征

B. 消息处理链路：
   选 2-3 条核心调度链路（按本项目实际命名替换示例）：
   - 链路示例：收到 `{被调度对象创建事件}` → 处理 → 发出 `{调度结果事件}`
   - 链路示例：收到 `{取消/重置事件}` → 处理
   → 完整读 consumer → 追踪调度函数 → 追踪 producer
   对每条链路提取：调用链、业务判断、错误处理、幂等机制、隐含规则（标注出处 xxx.py L行号）

C. 运行时状态：
   grep -rn "class.*State\|class.*Context\|class.*Manager\|self\._[a-z]" src/ --include="*.py" | head -20
   → 是否维护内存状态（被调度对象缓存？任务队列？分布式锁？）
   → 怎么初始化、怎么持久化、重启后怎么恢复

笔记格式：

```
# 第 3 轮：核心业务流
## 调度算法
### 算法 1：（名称）
用途：
输入：
输出：
策略：（自然语言描述）
约束条件：
可配置参数：
  - param_a：含义，默认值，配置位置
性能：
## 消息处理链路
### 链路 1：{被调度对象创建事件} → {调度结果事件}
入口：XxxConsumer.on_message()
调用链：consumer → scheduler.assign() → producer.publish()
详细步骤：
  1.
  2.
错误处理：
幂等处理：
隐含业务规则：
  - 规则1：描述（出处：xxx.py L行号）
## 运行时状态
| 状态名 | 类型 | 初始化方式 | 持久化方式 | 重启后 |
|---|---|---|---|---|
## 存疑项
```

---

## Prompt 4 — 基础设施与编码风格

先 `cat .claude-notes/round3.md`，笔记写入 `.claude-notes/round4.md`。

A. 异常处理：
   find src/ -name "*exception*" -o -name "*error*" | grep ".py$" | head -5 → cat
   grep -rn "except.*:" src/ --include="*.py" | head -20 → 归纳模式

B. 日志：
   grep -rn "logging\.\|logger\.\|structlog\.\|log\." src/ --include="*.py" | head -20
   → 归纳：库、格式、级别使用

C. 编码风格采样（从第 3 轮读过的文件归纳）：
   - 类型标注：type hints 深度
   - 数据类：dataclass / Pydantic / TypedDict / dict
   - 异步：async/await 还是同步
   - 风格：OOP 还是函数式
   - 依赖注入：DI 容器还是手动传参
   - 测试风格：pytest fixtures 还是 setUp/tearDown

D. 代码质量：
   从 pyproject.toml 提取 [tool.black] / [tool.ruff] / [tool.mypy]
   cat .flake8 2>/dev/null

笔记格式：

```
# 第 4 轮：基础设施与编码风格
## 异常处理
- 自定义异常类：
- 异常处理模式：
## 日志规范（从采样归纳）
- 日志库：
- 格式模式：
- 级别使用：
## 编码风格（从采样归纳，标注依据来源）
- 类型标注深度：（依据：xxx.py）
- 数据类选择：
- 异步模式：
- OOP/函数式偏好：
- 依赖注入：
- 命名约定：
## 代码质量配置
## 存疑项
```

---

## Prompt 4.5 — 接口完整性校验

先 `cat .claude-notes/round2.md` 回顾已提取的接口列表。
然后用以下策略重新扫描，与 round2 交叉比对。

```bash
# 策略 A：覆盖封装后的 MQ 发送
grep -rn "\.send\|\.publish\|\.emit\|\.dispatch\|\.produce\|\.push\|channel\." src/ --include="*.py" | grep -v "test\|#\|log\|\.pyc"

# 策略 B：更广范围的消息接收回调
grep -rn "def.*handle\|def.*on_\|def.*callback\|def.*consume\|def.*receive\|def.*process_message\|def.*listener" src/ --include="*.py"

# 策略 C：字符串常量中的 topic 名
grep -rn "'[a-z]*\.[a-z]*\.[a-z]*'\|\"[a-z]*\.[a-z]*\.[a-z]*\"" src/ --include="*.py" | grep -v "import\|#\|log\|http\|file\|test"
find src/ -name "constants.py" -o -name "topics.py" -o -name "events.py" | head -5
# 如果找到，cat 读取

# 策略 D：配置文件中的 queue/exchange 声明
grep -rn "queue\|exchange\|topic\|routing_key" config/ --include="*.yml" --include="*.yaml" --include="*.toml" 2>/dev/null

# 策略 E：已有文档
find docs/ -type f 2>/dev/null | head -10
```

将比对结果追加写入 `.claude-notes/round2.md` 末尾，格式：

```
## 完整性校验补充
### 新发现（round2 遗漏）
| 类型 | 内容 | 发现方式 | 置信度 |
|---|---|---|---|
### 需在 Prompt 5 中追加确认的问题
```

---

## Prompt 5 — 验证与补盲

先读取全部笔记：
   cat .claude-notes/round1.md
   cat .claude-notes/round2.md
   cat .claude-notes/round3.md
   cat .claude-notes/round4.md

1. 读测试：find . -path "*test*" -name "*.py" | grep -i "schedul\|algorithm\|planner" | head -3
   → 大文件防护：超 300 行只 grep "def test_" 看用例名
2. git log --oneline -20
3. head -100 README.md 2>/dev/null
4. 汇总存疑项提问。每个问题说明：问题、为什么代码看不出、猜测。
5. 接口完整性定向确认：
   - "我发现本模块发布了以下 MQ 事件：[列出]。是否还有遗漏？特别是通过封装类发送的？"
   - "我发现本模块消费了以下 MQ 事件：[列出]。是否还有遗漏？"
   - 如果 Prompt 4.5 发现了新接口，逐个向用户确认

6. 将分析过程中发现的所有代码问题整理为 TODO 清单，写入 `.claude-notes/todo.md`，格式：
   ```
   # 深度理解发现的待优化项
   ## 🔴 Bug / 潜在风险
   - [ ] 问题描述（出处：类名/文件名 L行号）
   ## 🟡 设计优化
   - [ ] 问题描述（出处）
   ## 🟢 规范改进
   - [ ] 问题描述（出处）
   ## ❓ 待确认
   - [ ] 问题描述（出处）— 我的猜测：...
   ```
   同时在对话中向用户展示这份清单。

---

## Prompt 6 — 合成 CLAUDE.md

先读取全部笔记：
   cat .claude-notes/round1.md
   cat .claude-notes/round2.md
   cat .claude-notes/round3.md
   cat .claude-notes/round4.md
   cat .claude-notes/todo.md

结合用户回答的内容，生成两个文件：

### 文件 1：CLAUDE.md（写入项目根目录）

必须包含的区块：
1. 技术栈
2. 目录结构
3. 消费的 MQ 事件（表格，含置信度列）
4. 发布的 MQ 事件（表格，含置信度列）
5. 消息体字段映射（snake_case ↔ camelCase）
6. HTTP API（如有）
7. 调度算法详解（用途、输入、输出、策略、约束、参数、性能 — **核心，必须完整保留**）
8. 核心消息处理链路（调用链 + 隐含规则，标注出处）
9. 运行时状态管理
10. ⚠️ 接口字段（标注 Python 字段名和 MQ 字段名对应关系）
11. 内部字段
12. 编码规范（从采样归纳，标注依据）
13. 异常处理机制
14. 构建与部署（venv + systemd）
15. 与其他模块的关系
16. 已知隐含知识

### 文件 2：TODO.md（写入项目根目录）

基于 .claude-notes/todo.md，结合用户回答更新后生成最终版。

接口置信度标注规则：
- ✅ 高：代码扫描找到 + 链路追踪验证 + 用户确认
- ⚠️ 中：代码扫描找到但未做链路追踪或用户未确认
- ❓ 低：仅从字符串常量或配置推测
