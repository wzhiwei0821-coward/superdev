# Python 数据处理系统 — 分轮执行指令

> 本文件由 `/mpdev-understand` 在 Step 3 检测到 Python 数据处理/ETL 类项目时加载。按 Prompt 1-6 逐轮执行。
>
> **适用场景**：以"消息转换/聚合/清洗/路由"为核心的 Python 中间层服务。术语保持中性——示例中的事件名（如 `algo.anomaly.detected` / `alert.processed`）只是占位，请按项目实际事件命名替换。

---

## Prompt 1 — 项目骨架

笔记写入 `.claude-notes/round1.md`。

1. 依赖：
   cat requirements.txt 2>/dev/null
   cat pyproject.toml 2>/dev/null
   → 提取：MQ 客户端、数据处理库（pandas / numpy / polars / 无）、
     ETL 框架（Luigi / Airflow / Prefect / 自研 / 无）、数据库连接器、序列化库

2. 目录结构：
   find . -type f -name "*.py" | grep -v __pycache__ | grep -v ".venv" | grep -v test | sort

3. 入口文件：
   cat src/main.py 2>/dev/null || cat app.py 2>/dev/null || cat run.py 2>/dev/null

4. 配置：
   find . -name "*.yml" -o -name "*.yaml" | grep -iv test | grep -i config | head -5
   → cat
   cat .env.example 2>/dev/null

笔记格式：

```
# 第 1 轮：项目骨架
## 技术栈
- Python 版本：
- MQ 客户端：
- 数据处理库：（pandas / numpy / polars / 无）
- ETL 框架：
- 数据库连接器：
- 序列化：
- 异步：
## 目录结构
（每个目录一句话说明）
## 启动方式
## 关键配置项
## 数据 I/O
- 文件读写：（CSV / Parquet / 无）
- 数据库写入：（写到哪里 / 无）
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

数据处理系统是中间层——既消费又生产，重点在消息转发拓扑。

A. MQ 消费者：
   grep -rn "basic_consume\|on_message\|callback\|consume\|subscribe" src/ --include="*.py" -l
   → 逐个 cat → 提取：queue/routing_key、消息体、回调
   fallback：grep -rn "def.*handle\|def.*process\|def.*on_" src/ --include="*.py" -l

B. MQ 生产者：
   grep -rn "basic_publish\|publish\|send\|produce" src/ --include="*.py" -l
   → 逐个 cat → 提取：exchange、routing_key、消息体
   fallback：grep -rn "channel\.\|producer\." src/ --include="*.py" -l

C. 消息体模型：
   find src/ -name "schemas.py" -o -name "messages.py" -o -name "events.py" -o -name "models.py" | sort
   → cat → 提取字段名和类型，标注 snake_case/camelCase 对应关系
   fallback：grep -rn "dataclass\|BaseModel\|TypedDict" src/ --include="*.py" -l

D. 数据库写入（如果有）：
   grep -rn "to_sql\|INSERT\|insert\|save\|write_to\|dump" src/ --include="*.py" | head -10

E. 文件 I/O（如果有）：
   grep -rn "read_csv\|to_csv\|read_parquet\|to_parquet\|open(" src/ --include="*.py" | head -10

F. HTTP API（如果有）：
   grep -rn "Flask\|FastAPI\|app\.route\|router\." src/ --include="*.py" | head -5

G. 外部 HTTP 调用：
   grep -rn "requests\.\|httpx\.\|aiohttp\." src/ --include="*.py" | head -10

H. 共享数据库 SQL（如果存在 contracts/ 子模块）：
   ls contracts/sql/ 2>/dev/null && cat contracts/sql/*.sql
   → 如果存在，提取本模块可能读写的表结构和初始化数据
   → grep "SELECT\|INSERT\|UPDATE\|execute\|cursor\|session\.\|to_sql" src/ --include="*.py" | head -10
   → 比对代码中引用的表名/列名是否与 SQL 定义一致

笔记格式：

```
# 第 2 轮：接口边界
## 消费的 MQ 事件（共 x 个）
| Queue/RoutingKey | 来源模块 | 消息体类/结构 | 处理函数 |
|---|---|---|---|
## 发布的 MQ 事件（共 x 个）
| Exchange | RoutingKey | 消息体类/结构 | 核心字段 | 发送位置 |
|---|---|---|---|---|
## 消息转发拓扑（本模块核心特征）
| 消费事件 | 来源 | 处理逻辑概要 | 产出事件 | 去向 |
|---|---|---|---|---|
## 消息体字段映射
| Python 字段(snake_case) | MQ 消息字段(camelCase) | 类型 | 说明 |
|---|---|---|---|
## 数据库操作
（有/无。如有，列出读写的表名和操作类型，标注来源是 contracts/sql/ 还是本模块自有）
## 数据库写入
（有/无，写到哪里）
## 文件 I/O
（有/无）
## HTTP API
（有/无）
## 存疑项
```

---

## Prompt 3 — 核心业务流 + 数据处理规则

先读取前两轮笔记：
   cat .claude-notes/round1.md
   cat .claude-notes/round2.md
笔记写入 `.claude-notes/round3.md`。
大文件防护：超 200 行先 `grep -n "def "` 看方法列表再选择性读。

对每条消息处理链路完整读代码。数据处理系统的核心 = 转换/聚合/去重/清洗规则。

对每条链路，除了调用链追踪外，额外提取：
- 输入消息字段 → 经过什么转换 → 输出消息字段（字段级映射）
- 聚合逻辑：按什么维度？时间窗口多大？怎么实现（内存/Redis/数据库）？
- 去重逻辑：去重 key 是什么？窗口多大？
- 数据清洗：过滤什么？补全什么？格式转换？
- 异常数据处理：格式错误丢弃还是标记？缺字段怎么办？
- 批处理 vs 逐条处理？

对每条链路也要提取：调用链、错误处理、幂等、隐含业务规则（标注出处 xxx.py L行号）

笔记格式：

```
# 第 3 轮：核心业务流
## 消息处理链路
### 链路 1：（消费事件 → 产出事件）
入口：XxxConsumer.on_message()
调用链：consumer → processor.transform() → producer.publish()
详细步骤：
  1.
  2.
错误处理：
幂等处理：
隐含业务规则：
  - 规则1：描述（出处：xxx.py L行号）

## 数据处理规则表（核心产出）
| 输入事件 | 处理类型 | 规则描述 | 关键参数 | 输出事件 |
|---|---|---|---|---|
| {上游事件名}    | 聚合去重 | 同 {业务键} N min 内只保留一条 | 窗口=N min, key={业务键} | {下游事件名} |

## 字段级映射（核心产出）
### 事件 A → 事件 B
| 输入字段 | 转换 | 输出字段 |
|---|---|---|
| {字段名} | 直传 | {字段名} |
| {字段路径} | 聚合（如取最大/平均/计数） | {字段路径} |
| (新增) | 计算（如累加值/统计量） | {字段名} |

## 存疑项
```

---

## Prompt 4 — 基础设施与编码风格

先 `cat .claude-notes/round3.md`，笔记写入 `.claude-notes/round4.md`。

A. 异常处理：
   find src/ -name "*exception*" -o -name "*error*" | grep ".py$" | head -5 → cat
   grep -rn "except.*:" src/ --include="*.py" | head -20 → 归纳

B. 日志：
   grep -rn "logging\.\|logger\.\|structlog\." src/ --include="*.py" | head -20

C. 编码风格采样（从第 3 轮读过的文件归纳）：
   - 类型标注深度
   - 数据类选择（dataclass / Pydantic / dict）
   - 异步模式
   - 数据处理风格（pandas DataFrame vs 原生循环）
   - 依赖注入方式
   - 命名约定

D. 代码质量：
   从 pyproject.toml 或 .flake8 提取

笔记格式：

```
# 第 4 轮：基础设施与编码风格
## 异常处理
- 自定义异常类：
- 处理模式：
## 日志规范（从采样归纳）
- 日志库：
- 格式模式：
- 级别使用：
## 编码风格（从采样归纳，标注依据来源）
- 类型标注深度：（依据：xxx.py）
- 数据类选择：
- 异步模式：
- 数据处理风格：（pandas vs 原生）
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

1. 读测试：find . -path "*test*" -name "*.py" | grep -i "process\|transform\|aggregat\|consumer" | head -3
   → 大文件防护：超 300 行只 grep "def test_" 看用例名
2. git log --oneline -20
3. head -100 README.md 2>/dev/null
4. 汇总存疑项提问。每个问题说明：问题、为什么代码看不出、猜测。
5. 接口完整性定向确认（数据处理是中间层，两侧都要确认）：
   - "我发现本模块消费了以下事件：[列出]。是否还有遗漏？"
   - "我发现本模块发布了以下事件：[列出]。是否还有遗漏？特别是通过封装类发送的？"
   - "消息转发拓扑：[消费X→处理→产出Y]。是否完整？有没有遗漏的转发链路？"
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
5. 消息转发拓扑（消费什么 → 处理 → 产出什么，**本模块核心特征**）
6. 消息体字段映射（snake_case ↔ camelCase）
7. 数据处理规则表（**核心，必须完整保留**）
8. 字段级映射表（**核心，必须完整保留**）
9. 核心消息处理链路（调用链 + 隐含规则，标注出处）
10. ⚠️ 接口字段（本模块同时是消费者和生产者，两侧字段都要列）
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
