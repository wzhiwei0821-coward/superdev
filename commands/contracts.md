---
description: 契约仓库提取 — 从各模块 CLAUDE.md 交叉比对生成 robot-contracts（mpdev 生命周期阶段 0b）
allowed-tools: Read, Grep, Glob, Bash, TodoWrite, Write, Edit, AskUserQuestion
---

# /mpdev:contracts — 契约仓库提取

mpdev 套件**生命周期阶段 0b**。从多模块 CLAUDE.md 提取共享接口规范，生成 schemas / openapi / sql / 事件目录 / 数据流 / 校验脚本。

**定位**：

| mpdev 命令 | 阶段 | 前置 | 产出 |
|----------|------|------|------|
| `/mpdev:understand` | 0a | （新项目） | 各模块 `CLAUDE.md` |
| **`/mpdev:contracts`** | 0b | 各模块 `CLAUDE.md` 已就绪 | `robot-contracts/`（schemas + openapi + sql + events + flows + scripts） |
| `/mpdev:init` | 1 | `CLAUDE.md` + `robot-contracts/` 都已就绪 | `.claude/agents/` |
| `/mpdev:dev` ... | 2+ | 同上 | 日常开发 |

**前置条件**（命令运行时会自检）：

- 各模块的 `CLAUDE.md` 已经存在且含**接口区块**（REST API / MQ 事件 / 数据库表 / 消息体字段映射 / 与其他模块的关系）
- 如果 CLAUDE.md 缺失或不完整 → 提示用户先跑 `/mpdev:understand`

**何时用**：

- 跨模块项目首次建立共享接口规范
- 模块接口发生大变更，需要重新提取契约（覆盖现有 contracts）
- Spring Cloud / 多服务项目要把分散的接口规范统一管理

**何时不用**：

- 单模块项目（无跨模块协作）
- 接口规范已用其他工具维护（如 Swagger Hub、Backstage）且不希望被覆盖

**Spring Cloud 项目特殊产出**（任一模块 CLAUDE.md 含 `spring-cloud-starter-*` / `Feign 远程调用` / `Gateway 路由` / `spring.application.name` 时自动触发）：

- `openapi/{service-name}.yaml` — 每个微服务独立一份（按 `spring.application.name` 而非目录名，便于 Feign 索引）
- `services/SERVICE_REGISTRY.md` — service-name ↔ 模块映射 + Feign 调用关系图
- `services/gateway-routes.yaml` — Gateway 路由契约（`lb://{service-name}`）
- Step 7 比对会额外验证 Feign 客户端的 service-name 是否在所有模块中可解析

---

## 用户输入

$ARGUMENTS

### 支持参数

| 参数 | 含义 | 示例 |
|------|------|------|
| 空 | 自动发现兄弟目录/二级目录的 CLAUDE.md | `/mpdev:contracts` |
| `output=<路径>` | 指定契约仓库目录（默认当前目录） | `/mpdev:contracts output=../robot-contracts` |
| `modules=<路径列表>` | 手动指定模块（不自动发现） | `/mpdev:contracts modules=../svc-a,../svc-b` |
| `force` | 覆盖现有 contracts（默认询问） | `/mpdev:contracts force` |
| `dry-run` | 只输出比对报告，不生成文件 | `/mpdev:contracts dry-run` |

---

## Step 1: 前置自检

```
1. 自动发现模块（兄弟目录扫描，与 Step 4 复用同一份模块列表）
   计 N = 发现的有 CLAUDE.md 的模块数

2. 前置质量检查:
   - N == 0 → 终止，提示"未发现任何 CLAUDE.md，请先 /mpdev:understand"
   - N == 1 → 警告"只发现 1 个模块，提取契约意义有限"，询问是否继续
   - 任一 CLAUDE.md 缺少"接口区块"（REST API / MQ / DB 任一）→ 警告并列出缺失模块
```

## Step 2: 解析用户参数

```
output_dir = $ARGUMENTS.output 或 当前目录
explicit_modules = $ARGUMENTS.modules 或 自动发现
force = bool
dry_run = bool
```

如检测到 `output_dir` 已存在 `robot-contracts/` 内容且未指定 `force`：询问 `[覆盖 / 仅 dry-run 看差异 / 取消]`。`force` 模式仍需备份现有 robot-contracts/ 到 `.bak.{timestamp}/`。

---

## 工作流主线（Step 3-10）

```
Step 3-5：初始化 + 发现模块 + 读取 CLAUDE.md 接口区块（自动）
    ↓
Step 6-8：MQ 事件 / REST API / 数据库 交叉比对（自动）
    ↓
⏸️ 第一暂停：呈现合并比对报告，等用户确认不一致项
    ↓
Step 9：生成 Schema / OpenAPI / SQL / 事件目录 / 数据流 / 校验脚本 / CLAUDE.md
    ↓
Step 10：输出一致性报告
    ↓
⏸️ 第二暂停：等用户审核
```

## Step 3: 初始化契约仓库目录

```bash
mkdir -p openapi schemas sql events flows scripts services
```

**目录说明**：
- `services/` 仅在 Spring Cloud / 多服务项目中填充（含 SERVICE_REGISTRY.md + gateway-routes.yaml）；单体项目可为空

## Step 4: 自动发现所有模块

找到所有包含 CLAUDE.md 的目录（先搜兄弟目录，再搜二级子目录）：

```bash
PARENT_DIR=$(dirname $(pwd))
MODULE_LIST=""
MODULE_COUNT=0

# 第一级：兄弟目录
for dir in "$PARENT_DIR"/*/; do
  if [ -f "$dir/CLAUDE.md" ] && [ "$(basename "$dir")" != "$(basename "$(pwd)")" ]; then
    MODULE_NAME=$(basename "$dir")
    echo "✅ 发现模块: $MODULE_NAME"
    MODULE_LIST="$MODULE_LIST $dir"
    MODULE_COUNT=$((MODULE_COUNT + 1))
  fi
done

# 如果一级没找到，尝试二级搜索（Monorepo 场景）
if [ "$MODULE_COUNT" -eq 0 ]; then
  echo "一级搜索未发现模块，尝试二级搜索..."
  for dir in "$PARENT_DIR"/*/*/; do
    if [ -f "$dir/CLAUDE.md" ]; then
      MODULE_NAME=$(basename "$dir")
      echo "✅ (二级目录) $MODULE_NAME"
      MODULE_LIST="$MODULE_LIST $dir"
      MODULE_COUNT=$((MODULE_COUNT + 1))
    fi
  done
fi

echo ""
echo "共发现 $MODULE_COUNT 个模块"
```

如果发现 0 个模块，请用户手动指定模块路径：
```
我的模块不在兄弟目录或二级子目录中，请从以下路径读取 CLAUDE.md：
- /path/to/module-a/CLAUDE.md
- /path/to/module-b/CLAUDE.md
```

如果发现的模块数少于预期，提示：
```
"共发现 N 个模块。如果你的项目有更多模块但未显示，
请先对那些模块执行 /mpdev:understand 生成 CLAUDE.md。"
```

## Step 5: 选择性读取 CLAUDE.md 的接口区块

**不要读全文**，只提取每个 CLAUDE.md 中的接口相关部分。对每个发现的模块执行：

```bash
# 对每个模块，用 sed/awk 提取接口相关区块
for dir in $MODULE_LIST; do
  MODULE_NAME=$(basename "$dir")
  echo "========== $MODULE_NAME =========="

  # 提取以下区块（通过 ## 标题定位）：
  # - REST API
  # - 发布的 MQ 事件
  # - 消费的 MQ 事件
  # - 消息体字段映射
  # - 数据库表 / 数据库核心表
  # - WebSocket
  # - 与其他模块的关系
  # - 核心业务流（用于生成 DATAFLOW.md）
  cat "$dir/CLAUDE.md"
done
```

读取时重点关注：
- **MQ 事件表格**：发布了什么、消费了什么、字段列表
- **REST API 表格**：路径、方法、参数、返回类型
- **数据库表**：表名、字段名、类型
- **消息体字段映射**：Python snake_case 与 MQ camelCase 的对应关系
- **核心业务流**：端到端链路（用于生成 DATAFLOW.md）

如果某个 CLAUDE.md 超过 400 行，用 awk 提取接口相关章节（从 ## 标题到下一个 ## 标题）：

```bash
awk '/^## .*(REST|API|MQ|消息|事件|数据库|DB|表|WebSocket|接口字段|核心业务|与其他模块|关系|Feign|Gateway|远程调用|路由|配置中心)/{found=1} found{print} /^## /{if(found && !/(REST|API|MQ|消息|事件|数据库|DB|表|WebSocket|接口字段|核心业务|与其他模块|关系|Feign|Gateway|远程调用|路由|配置中心)/) found=0}' "$dir/CLAUDE.md"
```

**关键词说明**：`Feign|Gateway|远程调用|路由|配置中心` 用于覆盖 Spring Cloud 项目的章节标题（如 `## [Cloud] Feign 远程调用` / `## [Cloud] Gateway 路由` / `## [Cloud] 服务治理`）。

**如果某个模块提取到的接口信息为空**（所有区块都没匹配到），说明该模块的 CLAUDE.md 标题格式不标准。此时改为 cat 全文读取，并在比对报告中标注"⚠️ 该模块 CLAUDE.md 格式非标准，建议重新生成"。

## Step 6: MQ 事件交叉比对

从各模块提取的 MQ 信息，构建一张交叉比对表：

```
| 事件 Topic | 发布者模块 | 发布方字段定义 | 消费者模块 | 消费方字段定义 | 是否一致 |
```

比对规则：
- 同一事件 Topic，发布方和消费方的字段名、类型、必填/可选必须一致
- 不一致则标记 ❌ 并列出具体差异
- 注意 camelCase（Java/MQ）和 snake_case（Python）的对应——如果 CLAUDE.md 中有"消息体字段映射"表，用那张表做转换

异常情况处理：
- 某事件有发布者但无消费者 → 标记"⚠️ 无消费者，可能是废弃事件"
- 某事件有消费者但无发布者 → 标记"❌ CLAUDE.md 遗漏了发布方"
- 多个模块发布同一事件 → 标记"⚠️ 多发布者，需确认是否合理"

**将比对结果暂存，和 Step 7、Step 8 的结果一起在 Step 8 结束后统一呈现给用户确认。**

## Step 7: REST API 交叉比对

识别 API 的提供方和消费方（**支持 Spring Cloud 微服务间的 Feign 调用**）：
- **REST API 提供方**：CLAUDE.md 中有"REST API"或"对外暴露的 REST API"或"Gateway 路由"表格
- **REST API 消费方**：
  - 前端模块：CLAUDE.md 中有"API 调用"表格
  - **Spring Cloud 微服务**：CLAUDE.md 中有"Feign 远程调用"表格（`@FeignClient(name="xxx")` 中的 name 即下游服务名）

比对维度：
- **路径一致性**：消费方调用的路径 vs 提供方暴露的路径
- **目标服务一致性**（仅 Cloud）：Feign 的 `@FeignClient(name="user-service")` → user-service 模块的 `spring.application.name` 必须等于 `user-service`
- **方法签名一致性**（仅 Cloud）：Feign 接口方法 vs 下游 Controller 方法的 path / method / 参数类型 / 返回类型必须严格匹配

异常情况：
- 提供方有但无消费方 → 标记"⚠️ 未使用的 API"
- 消费方调了但无提供方 → 标记"❌ 调用了不存在的 API"
- Feign 客户端的 service name 在所有模块的 `spring.application.name` 中找不到 → 标记"❌ Feign 指向的服务不存在"

**将比对结果暂存，与 Step 6 和 Step 8 的结果合并到 Step 8 结束后统一呈现。**

## Step 8: 数据库 SQL 提取与比对

从各模块收集 SQL 文件：

```bash
PARENT_DIR=$(dirname $(pwd))
for dir in "$PARENT_DIR"/*/; do
  if [ -f "$dir/CLAUDE.md" ] && [ "$(basename "$dir")" != "$(basename "$(pwd)")" ]; then
    SQL_FILES=$(find "$dir" \( -path "*/migration/*" -o -path "*/sql/*" \) -name "*.sql" 2>/dev/null)
    if [ -n "$SQL_FILES" ]; then
      echo "=== $(basename "$dir") 的 SQL 文件 ==="
      echo "$SQL_FILES"
    fi
  fi
done
```

对找到的 SQL 文件：
1. 逐个 cat 读取
2. 与各模块 CLAUDE.md 中"数据库表"区块的字段定义交叉比对
3. Entity 字段(camelCase) vs SQL 列(snake_case) 是否一致
4. 多个模块有同一张表的不同版本 → 标记 ❌

**⏸️ 第一暂停：Steps 6-8 的全部比对完成后，将以下三份结果合并输出，等用户逐条确认后再进入 Step 9 生成文件：**

```
## 交叉比对报告（请逐条确认）

### 一、MQ 事件比对
| 事件 Topic | 发布者 | 发布方字段 | 消费者 | 消费方字段 | 状态 |
|---|---|---|---|---|---|
（Step 6 的结果）

### 二、REST API 比对
| API 路径 | 后端定义 | 前端调用 | 状态 |
|---|---|---|---|
（Step 7 的结果）

### 三、数据库比对
| 表名 | SQL 来源 | Entity/Model 来源 | 状态 |
|---|---|---|---|
（Step 8 的结果）

### 需要你决定的问题
1. （列出所有 ❌ 不一致项，每个问你以哪边为准）
2. ...
```

**用户确认全部项后才进入 Step 9。如启用 `dry-run`，到此为止——只输出比对报告，不生成文件，跳过 Step 9 直接进入 Step 11 归档。**

## Step 9: 用户确认后，生成所有契约文件

用户确认 Steps 6-8 的比对结果后：

**先做 git 检查点（方便回退）：**
```bash
git add -A && git commit -m "checkpoint: before contract generation" --allow-empty 2>/dev/null || true
```
如果需要回退，执行 `git checkout .` 即可恢复到此检查点。

按以下顺序生成文件（全部写入当前契约仓库目录）：

### 9.1 生成 JSON Schema（schemas/）

对每个确认后的 MQ 事件，生成 `schemas/{topic名，点号替换为下划线}.json`：

以发布方的字段定义为准，生成 JSON Schema Draft 07。

每个 Schema 必须：
- 包含 $schema、$id、title、description
- 所有字段有 description 说明
- 必填字段列入 required 数组
- 公共字段：traceId(string, format: uuid) + timestamp(string, format: date-time)
- 枚举值全大写（UPPER_SNAKE_CASE）
- 默认 additionalProperties: false

### 9.2 生成 OpenAPI（openapi/）

**粒度规则**：
- **单体后端项目**（1 个后端模块）→ 一份 `openapi/backend.yaml`
- **Spring Cloud 多微服务**（N 个后端服务）→ **每个服务独立一份** `openapi/{service-name}.yaml`，其中 `{service-name}` 取该模块的 `spring.application.name`（非目录名）。便于 Feign 客户端按 service name 索引
- **Gateway 服务** → 不生成 `openapi/gateway.yaml`，其路由单独写到 `services/gateway-routes.yaml`（见 9.8）

生成内容（OpenAPI 3.0.3）：
- 每个接口有 operationId
- 请求/响应体用 components/schemas 定义
- Response 统一 Result<T> 包装：{code, message, data}
- 分页统一 PageResult<T>：{total, page, size, records}
- **多服务场景**：yaml 顶部的 `info.title` 用 service-name；`servers` 段填 `lb://{service-name}` 或网关对外 URL

### 9.3 整合 SQL（sql/）

将各模块的 SQL 文件整合到 sql/ 目录：
- 如果多个模块都有 V1__xxx.sql → 按"建表依赖顺序"重新编号（被依赖的表在前）
- 建表和初始化数据可以放在同一脚本中
- 字段名统一 snake_case
- 初始化数据必须幂等（INSERT IGNORE 或 ON DUPLICATE KEY UPDATE）
- 最终版本号连续递增：V1__create_xxx.sql, V2__create_yyy.sql, ...

### 9.4 生成 EVENT_CATALOG.md（events/）

```markdown
# 事件目录

## MQ 基础设施
- 消息队列类型：
- Exchange 名称和类型：
- Queue 命名规则：
- 公共字段：traceId(UUID) + timestamp(ISO 8601)

## 事件总表
| Topic | 发布者 | 消费者 | Schema 文件 | 说明 |
|---|---|---|---|---|
（从 Step 6 的确认结果填充）
```

### 9.5 生成 DATAFLOW.md（flows/）

从各模块 CLAUDE.md 的"核心业务流"和"与其他模块的关系"串联端到端数据流：

```markdown
# 端到端数据流

## 流程一：（名称）
用户操作 → [模块A] 处理 → 发布事件X
  → [模块B] 消费 → 处理 → 发布事件Y
    → [模块C] 消费 → 处理 → 推送前端
```

至少覆盖：核心业务主流程、异常/告警流程、取消/回滚流程。

### 9.6 生成 scripts/validate_contracts.py

```python
#!/usr/bin/env python3
"""契约校验脚本：检查 schemas/ 下 JSON Schema 的格式合法性"""
import json, glob, sys

def validate():
    errors = []
    schemas = glob.glob("schemas/*.json")
    if not schemas:
        print("⚠️ schemas/ 下没有找到 JSON Schema 文件")
        return

    for path in sorted(schemas):
        with open(path) as f:
            schema = json.load(f)

        name = path.split("/")[-1]

        # 检查必须字段
        for field in ["$schema", "title", "type"]:
            if field not in schema:
                errors.append(f"❌ {name}: 缺少 {field}")

        # 检查公共字段
        props = schema.get("properties", {})
        for common in ["traceId", "timestamp"]:
            if common not in props:
                errors.append(f"⚠️ {name}: 缺少公共字段 {common}")

        # 检查 additionalProperties
        if schema.get("additionalProperties") is not False:
            errors.append(f"⚠️ {name}: 建议设置 additionalProperties: false")

        if not errors or all("⚠️" in e for e in errors):
            print(f"✅ {name}: 格式合法")

    if errors:
        print("\n问题清单：")
        for e in errors:
            print(f"  {e}")
        sys.exit(1)
    else:
        print("\n✅ 全部 Schema 校验通过")

if __name__ == "__main__":
    validate()
```

### 9.7 生成契约仓库自身的 CLAUDE.md

写入项目根目录的 CLAUDE.md，模板：

```markdown
# {仓库目录名} — 共享接口契约仓库

## 用途
各模块间所有接口和共享数据库结构的 Single Source of Truth。

## 维护规则
- 接口变更必须先在本仓库提 PR，相关消费者团队 review 后合并
- 破坏性变更（删字段/改类型/必填变更）提前通知 + 一个版本过渡期
- 新增字段默认 optional，至少一个版本后才能改 required
- 表结构变更只能新增迁移脚本，不能修改已有脚本
- 初始化数据必须幂等（INSERT IGNORE 或 ON DUPLICATE KEY UPDATE）
- PR 标题格式：[模块名] 变更描述

## 各模块引用方式
Git Submodule，挂载到各模块的 contracts/ 目录
更新命令：git submodule update --remote contracts

## 目录说明
- openapi/：后端 REST API 定义（**多微服务时每个 service-name 一份**）
- schemas/：MQ 消息 JSON Schema（生产者和消费者都遵循）
- sql/：数据库迁移脚本（建表 + 初始化数据，按版本号递增）
- events/EVENT_CATALOG.md：事件发布/订阅关系
- flows/DATAFLOW.md：核心业务的端到端数据流
- scripts/validate_contracts.py：校验 Schema 格式合法性
- services/（仅 Spring Cloud 项目）：
  - SERVICE_REGISTRY.md：service-name ↔ 模块的映射 + Feign 调用关系图
  - gateway-routes.yaml：Gateway 路由契约（外部 URL → lb://service-name）

## 校验命令
python scripts/validate_contracts.py

## 事件总表
（从 events/EVENT_CATALOG.md 同步）

## 数据库表总表
| 表名 | 主要维护模块 | 说明 |
|---|---|---|
（从 sql/ 中提取）
```

### 9.8 [Cloud] 生成服务注册表 + Gateway 路由契约

**触发条件**：任一模块 CLAUDE.md 含 Spring Cloud 标识（`spring-cloud-starter-*` / `Feign 远程调用` / `Gateway 路由` / `spring.application.name`）。无则跳过 9.8，不产出 services/ 下的文件。

#### 9.8.1 `services/SERVICE_REGISTRY.md`

```markdown
# 服务注册表

各微服务与模块的对应关系，是跨服务调用的导航图。

## 服务总表
| service-name (spring.application.name) | 所在模块 | 角色 | 端口 | 提供的接口数 | 消费的下游服务 |
|---|---|---|---|---|---|
| gateway          | gateway/        | 网关      | 8080 | — (路由转发) | user-service, order-service |
| user-service     | user-service/   | 业务服务   | 8081 | 12 | payment-service |
| order-service    | order-service/  | 业务服务   | 8082 | 8  | user-service, payment-service |
| payment-service  | payment-service/| 业务服务   | 8083 | 5  | — |

## 调用关系图（Feign）
```
gateway ────Feign──> user-service
gateway ────Feign──> order-service
order-service ──Feign──> user-service
order-service ──Feign──> payment-service
user-service ──Feign──> payment-service
```

## 未解析的调用
| 调用方 | 目标 service-name | 原因 |
|---|---|---|
| X | unknown-svc | spring.application.name 未找到对应模块 |
```

**数据来源**：
- `所在模块 / 角色 / 端口 / spring.application.name` → 各模块 CLAUDE.md 的模块结构段
- `提供接口数` → openapi/{service-name}.yaml 的 paths 数量
- `消费下游` → 各模块 CLAUDE.md 的 Feign 远程调用表
- `未解析的调用` → Step 7 比对时记录的 ❌ Feign 指向不存在服务

#### 9.8.2 `services/gateway-routes.yaml`

仅当存在 Gateway 服务时生成：

```yaml
# Spring Cloud Gateway 路由契约
# 来源：各模块 CLAUDE.md 的 "[Cloud] Gateway 路由" 表
gateway_service: gateway
routes:
  - id: user-api
    predicates:
      - Path=/api/user/**
    filters:
      - StripPrefix=2
    uri: lb://user-service
    downstream_openapi: openapi/user-service.yaml
  - id: order-api
    predicates:
      - Path=/api/order/**
    filters:
      - StripPrefix=2
    uri: lb://order-service
    downstream_openapi: openapi/order-service.yaml
```

**关键点**：
- `uri` 必须是 `lb://{service-name}`，service-name 必须在 SERVICE_REGISTRY.md 中能找到；若找不到 → 报错进入 Step 10 的一致性报告
- `downstream_openapi` 指向同一契约仓库内的 OpenAPI，便于读者跳转查看下游接口

## Step 10: 输出一致性报告

所有文件生成完毕后，输出最终报告：

```
## 契约一致性报告

### MQ 事件一致性
| 事件 | 发布方 | 消费方 | 状态 | 备注 |
|---|---|---|---|---|
（从 Step 6 填充）

### REST API 一致性
| API 路径 | 后端定义 | 前端调用 | 状态 | 备注 |
|---|---|---|---|---|
（从 Step 7 填充）

### 数据库一致性
| 表名 | SQL 定义 | Entity 定义 | 状态 | 备注 |
|---|---|---|---|---|
（从 Step 8 填充）

### 生成的文件清单
（列出所有生成的文件路径和行数）
```

**⏸️ 第二暂停：等用户审核报告。**

## Step 11: 📄 文档归档

```
timestamp = 当前时间 YYYYMMDD-HHMM
file_id = "{timestamp}-contracts"

Bash("mkdir -p .claude/mpdev-runs/setup")
Write(".claude/mpdev-runs/setup/{file_id}.md", ...)
```

**归档模板**：

```markdown
---
stage: contracts
generated_at: {timestamp}
output_dir: {output_dir}
modules_scanned: N
mode: full | dry-run
---

# 契约提取记录

## 用户输入
> {$ARGUMENTS 原文}

## 扫描范围
- 模块数：N
- 来源目录：{自动发现 / 手动指定}

## 三层比对结果

### MQ 事件层
- 发布者-消费者匹配：N 对一致 / M 对不一致
- 不一致明细（用户已确认）：...

### REST API 层
- 路径冲突：N 处
- 参数不一致：M 处

### 数据库层
- 表结构冲突：N 处
- 字段类型不一致：M 处

## 生成的契约文件
- openapi/*.yaml: N 个
- schemas/*.json: N 个
- sql/V*.sql: N 个
- events/EVENT_CATALOG.md
- flows/DATAFLOW.md
- scripts/validate_contracts.py
- {output_dir}/CLAUDE.md（契约仓库自身的元数据）

## 一致性报告
{Step 10 的输出}

## 下一步建议

- ✅ 契约仓库已生成
- ➡️ 建议下一步：`/mpdev:init` 生成 mpdev agent 定义
- 或：`/mpdev:check` 验证契约与代码的一致性

## 关联文件
- {output_dir}/openapi/...
- {output_dir}/schemas/...
- {output_dir}/sql/...
```

## Step 12: 与下游命令的衔接提示

```
if 是否首次创建（之前无 robot-contracts/）:
  → "建议下一步: /mpdev:init 初始化 mpdev 编排框架"
else:
  → "建议下一步: /mpdev:check 验证契约与现有代码的一致性"

如果检测到代码已经存在但 contracts 是新生成的:
  → 强烈建议跑 /mpdev:check 找漂移点
```

---

## 暂停规则总结

本命令有两个必须暂停的节点：

1. **Step 8 完成后**：Steps 6-8 的 MQ + API + SQL 交叉比对结果合并呈现，等用户逐条确认不一致项
2. **Step 10 完成后**：一致性报告呈现，等用户审核

**Steps 3-5 自动执行；Steps 6-8 自动执行但不生成文件。用户确认 Step 8 的比对报告后才进入 Step 9 生成文件。**

## 生成后的维护

| 场景 | 操作 |
|---|---|
| 新增 MQ 事件 | 先在契约仓库加 Schema + 更新 EVENT_CATALOG → PR → 各模块再编码 |
| 修改事件字段 | 先改 Schema → PR → 逐模块同步 |
| 新增 REST API | 先在 openapi/ 中添加 → PR → 后端和前端再编码 |
| 新增数据库表 | 先在 sql/ 新增 V{N}__xxx.sql → PR → 后端迁移 → 各模块更新 Entity |
| 修改表结构(加列) | 先在 sql/ 新增 V{N}__alter_xxx.sql → PR → 各模块同步 |
| 修改表结构(改/删列) | ⚠️ 破坏性：先加新列 → 各模块切换 → 再删旧列（两步迁移） |

**核心原则：契约仓库是先行的。先改契约，再改代码。**

---

## 容错规则

| 情况 | 处理 |
|------|------|
| 0 个模块 | 终止，提示先 `/mpdev:understand` |
| 1 个模块 | 警告并询问是否继续（可能不需要 contracts） |
| CLAUDE.md 缺接口区块 | 警告并列出，让用户选：[继续（接口少不准）/ 终止补 CLAUDE.md / 排除该模块] |
| 已存在 robot-contracts/ 且未指定 force | 询问：[覆盖 / 仅 dry-run 看差异 / 取消] |
| 比对发现严重不一致（>20%）| 强制进入 dry-run，不自动生成；让用户先修 CLAUDE.md |
| 命名规范冲突（同一字段 snake vs camel）| 询问采用哪种规范，写入契约 CLAUDE.md 的"命名约定"段 |

## 约束

1. **两个暂停点不可跳过** — Step 8 后等比对确认 + Step 10 后等报告审核
2. **不一致项必须用户确认** — 不能静默选边
3. **SQL 必须幂等** — 生成的 V*.sql 用 `INSERT IGNORE` / `IF NOT EXISTS`
4. **生成校验脚本** — `scripts/validate_contracts.py` 是 `/mpdev:check` 的依赖
5. **覆盖前必备份** — force 模式也要备份现有 robot-contracts/ 到 `.bak.{timestamp}/`
6. **不自动跳到 init** — 完成后展示建议，让用户审查契约后再决定
7. **必写归档文档** — 即使是 dry-run 也写一份归档到 `mpdev-runs/setup/`
8. **命名约定写入契约自身 CLAUDE.md** — 让 `/mpdev:init` 之后能读到统一规范
9. **Step 9 前必 git checkpoint** — 让用户可以一行 `git checkout .` 回退
