# Python 算法系统 — 分轮执行指令

> 本文件由 SKILL.md 在检测到 Python 算法/推理/检测类项目时加载。按 Prompt 1-6 逐轮执行。
>
> **适用场景**：核心是"模型推理 / 计算密集型算法 / 异常检测 / 数据分析"的 Python 服务（CV/NLP/时序检测/规则引擎等）。文中"异常检测"段为示例性子模块——若项目无该模块按"无"处理；术语保持中性。

---

## Prompt 1 — 项目骨架

笔记写入 `.claude-notes/round1.md`。

1. 依赖：
   cat requirements.txt 2>/dev/null
   cat pyproject.toml 2>/dev/null
   → 提取：MQ 客户端、科学计算库（numpy / scipy / scikit-learn）、
     深度学习框架（torch / tensorflow / onnxruntime / 无）、
     性能优化（cython / numba / multiprocessing）、可视化（matplotlib / 无）

2. 目录结构：
   find . -type f -name "*.py" | grep -v __pycache__ | grep -v ".venv" | grep -v test | sort

3. 模型文件：
   find . -name "*.pkl" -o -name "*.onnx" -o -name "*.pt" -o -name "*.h5" -o -name "*.joblib" -o -name "*.bin" | head -10
   → 记录路径 + ls -lh 查看大小

4. 入口文件：
   cat src/main.py 2>/dev/null || cat app.py 2>/dev/null || cat run.py 2>/dev/null

5. 配置（特别关注算法参数）：
   find . -name "*.yml" -o -name "*.yaml" | grep -iv test | grep -i config | head -5
   → cat → 提取所有算法参数（阈值、窗口大小、模型路径、超参数）

6. 训练/推理分离：
   find . -path "*train*" -name "*.py" | head -5
   find . -path "*inference*" -o -path "*predict*" | head -5

笔记格式：

```
# 第 1 轮：项目骨架
## 技术栈
- Python 版本：
- MQ 客户端：
- 科学计算库：
- 深度学习框架：
- 性能优化库：
- 序列化：
- 异步：
## 算法基础设施
- 模型文件：路径、格式、大小
- 训练/推理分离：是否有训练代码
- 算法参数配置位置：
## 目录结构
（每个目录一句话说明）
## 启动方式
## 关键配置项
（逐个列出，特别是算法参数：阈值、窗口、模型路径、超参数）
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
   grep -rn "basic_consume\|on_message\|callback\|consume\|subscribe" src/ --include="*.py" -l
   → 逐个 cat → 提取：queue、消息体、回调
   fallback：grep -rn "def.*handle\|def.*process\|def.*on_" src/ --include="*.py" -l

B. MQ 生产者：
   grep -rn "basic_publish\|publish\|send\|produce" src/ --include="*.py" -l
   → 逐个 cat → 提取：exchange、routing_key、消息体
   fallback：grep -rn "channel\.\|producer\." src/ --include="*.py" -l

C. 消息体模型：
   find src/ -name "schemas.py" -o -name "messages.py" -o -name "events.py" -o -name "models.py" | sort
   → cat → 提取字段名和类型，标注 snake_case/camelCase 对应
   fallback：grep -rn "dataclass\|BaseModel\|TypedDict" src/ --include="*.py" -l

D. HTTP API（如有推理接口）：
   grep -rn "Flask\|FastAPI\|app\.route\|router\." src/ --include="*.py" | head -5

E. 算法触发方式：
   grep -rn "schedule\|cron\|while True\|sleep\|interval\|periodic" src/ --include="*.py" | head -10
   → 被动（收到 MQ 消息执行）还是主动（定时/持续循环）？

F. 共享数据库 SQL（如果存在 contracts/ 子模块）：
   ls contracts/sql/ 2>/dev/null && cat contracts/sql/*.sql
   → 如果存在，了解算法系统可能读取的表结构（如机器人位置表、地图数据表）
   → grep "SELECT\|INSERT\|execute\|cursor\|session\." src/ --include="*.py" | head -10
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
## 消息体字段映射
| Python 字段(snake_case) | MQ 消息字段(camelCase) | 类型 | 说明 |
|---|---|---|---|
## 数据库操作
（有/无。如有，列出读写的表名和操作类型，标注来源是 contracts/sql/ 还是本模块自有）
## 算法触发方式
（被动 / 主动定时 / 持续监控循环）
## HTTP API
（有/无）
## 存疑项
```

---

## Prompt 3 — 核心业务流 + 算法详解

先读取前两轮笔记：
   cat .claude-notes/round1.md
   cat .claude-notes/round2.md
笔记写入 `.claude-notes/round3.md`。
大文件防护：算法文件可能很长，超 200 行先 `grep -n "def "` 看方法列表再选择性读核心方法。

A. 找到所有算法实现：
   find src/ -path "*algo*" -o -path "*engine*" -o -path "*detector*" -o -path "*solver*" -o -path "*model*" | grep ".py$" | grep -v test | sort
   → 对每个文件先 wc -l 再选择性读

B. 对每个算法提取：
   - 算法名称和用途
   - 输入数据：格式、来源（MQ / 文件 / 数据库）
   - 输出数据：格式、去向
   - 算法原理：用自然语言描述核心思路（不需要数学公式，但要说明白步骤）
   - 关键参数：每个参数的含义、默认值、取值范围、在配置文件中的位置
   - 性能特征：执行时间量级（ms/s/min）、内存占用、是否可并行
   - 模型加载：怎么加载（启动时/每次调用/懒加载）？

C. 异常检测模块（如果有）：
   find src/ -path "*detect*" -o -path "*anomal*" -o -path "*monitor*" | grep ".py$" | sort
   → cat 核心文件
   → 提取：检测哪些**异常类型/事件类别**（业务上的枚举命名）、每种的检测逻辑和阈值、
     检测频率、误报处理策略
   → 项目无异常检测模块时跳过此小节

D. 算法编排（如有多算法串联/并联）：
   → Pipeline / Chain / DAG？算法间数据传递方式？

E. 消息处理链路追踪：
   对每条 MQ 消费链路完整读代码：consumer 回调 → 算法调用 → producer 发布
   提取：调用链、业务判断、错误处理（算法失败怎么办？重试？降级？通知？）、
   幂等机制、隐含业务规则（标注出处 xxx.py L行号）

笔记格式：

```
# 第 3 轮：核心业务流

## 算法清单
| 算法名 | 用途 | 输入 | 输出 | 触发方式 | 关键参数 |
|---|---|---|---|---|---|

## 算法 1 详解：（名称）
用途：
原理：（自然语言描述核心步骤）
输入：
  - 数据格式
  - 来源
输出：
  - 数据格式
  - 去向
关键参数：
  - param_a：含义，默认值，取值范围，配置位置
性能：执行时间约 x，内存约 x
模型文件：（路径、格式、加载方式、更新方式）

## 异常检测详解（如本项目无此模块则跳过）
| 异常类型/事件类别 | 检测逻辑 | 阈值 | 检测频率 | 误报处理 |
|---|---|---|---|---|

## 消息处理链路
### 链路 1：{上游数据事件} → {算法结果事件}
入口：XxxConsumer.on_message()
调用链：consumer → algorithm.execute() → producer.publish()
详细步骤：
  1.
  2.
错误处理：
幂等处理：
隐含业务规则：
  - 规则1：描述（出处：xxx.py L行号）

## 算法编排
（有/无，如有描述 Pipeline 结构）

## 存疑项
```

---

## Prompt 4 — 基础设施与编码风格

先 `cat .claude-notes/round3.md`，笔记写入 `.claude-notes/round4.md`。

A. 异常处理：
   find src/ -name "*exception*" -o -name "*error*" | grep ".py$" | head -5 → cat
   grep -rn "except.*:" src/ --include="*.py" | head -20

B. 日志：
   grep -rn "logging\.\|logger\.\|structlog\." src/ --include="*.py" | head -20

C. 编码风格采样（从第 3 轮读过的文件归纳）：
   - 类型标注深度
   - 数据类选择
   - 数值计算风格：纯 numpy / pandas DataFrame / 原生 Python
   - 算法与工程分离：算法核心能否独立于 MQ/IO 运行？
   - 测试方式：numpy.testing.assert_allclose？固定随机种子？
   - 配置管理：算法参数在哪管理（硬编码/配置文件/环境变量）
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
- 数值计算风格：（numpy / pandas / 原生）
- 算法与工程分离：（能否独立跑算法不启动 MQ）
- 测试方式：（numpy.testing / 固定随机种子 / 普通 assert）
- 配置管理：（算法参数管理方式）
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

1. 读测试：find . -path "*test*" -name "*.py" | grep -i "algo\|detect\|engine" | head -3
   → 大文件防护：超 300 行只 grep "def test_" 看用例名
   → 提取测试用例名（暴露算法边界条件和预期行为）

2. git log --oneline -20

3. head -100 README.md 2>/dev/null

4. 汇总存疑项提问。算法系统必须额外关注的问题方向：
   - 算法参数的调优频率和责任人
   - 模型文件的更新流程（在线/停服？谁更新？）
   - 有没有算法效果度量指标（准确率/召回率/延迟）
   - 异常检测阈值怎么定的（经验值？数据驱动？自适应？）
   - 算法降级策略（模型加载失败时怎么办？）

5. 接口完整性定向确认：
   - "我发现本模块发布了以下 MQ 事件：[列出]。是否还有遗漏？特别是异常检测模块是否有额外的告警事件类型？"
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

每个问题说明：问题、为什么代码看不出、猜测。

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
6. 算法清单（表格 — **核心，必须完整**）
7. 每个算法的详解（原理、输入输出、参数、性能、模型文件 — **核心，必须完整**）
8. 异常检测详解（类型/阈值/逻辑/频率/误报处理 — **核心，必须完整**）
9. 核心消息处理链路（调用链 + 隐含规则，标注出处）
10. 算法编排（如有）
11. ⚠️ 接口字段（MQ 字段 + 从配置/消息传入的算法参数，标注 snake_case/camelCase）
12. 内部字段（算法内部变量、中间计算结果）
13. 编码规范（从采样归纳，含算法与工程分离边界，标注依据）
14. 模型文件管理（路径、格式、加载方式、更新方式）
15. 异常处理机制
16. 构建与部署（venv + systemd）
17. 与其他模块的关系
18. 已知隐含知识

接口置信度标注规则：
- ✅ 高：代码扫描找到 + 链路追踪验证 + 用户确认
- ⚠️ 中：代码扫描找到但未做链路追踪或用户未确认
- ❓ 低：仅从字符串常量或配置推测

### 文件 2：TODO.md（写入项目根目录）

基于 .claude-notes/todo.md，结合用户回答更新后生成最终版。
