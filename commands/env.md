---
description: 环境配置与启动 — 自动检测中间件需求，收集连接信息，配置并启动服务
allowed-tools: Agent, Read, Grep, Glob, Bash, Edit, Write, AskUserQuestion
---

# /mpdev:env — 项目环境配置与启动

开发环境一站式管理。支持首次配置启动，也支持日常的重启、停止和状态查看。

## 用法

```
/mpdev:env              首次配置并启动（完整流程；含 compose 检测）
/mpdev:env start        同上（显式写法）
/mpdev:env start gateway       只配置并启动匹配 "gateway" 的模块（Spring Cloud 单服务场景）
/mpdev:env start gateway,user  多模块子集（逗号分隔，各自模糊匹配）
/mpdev:env start --profile=dev              所有模块用 dev profile（跳过交互式选择）
/mpdev:env start gateway --profile=test     指定模块 + 指定 profile
/mpdev:env start user-service --add-instance-port=8082   启动 user-service 的第二个实例（端口 8082）
/mpdev:env restart      重启所有模块（跳过检测和配置，保留 compose 运行）
/mpdev:env restart java 重启指定模块（模糊匹配模块名）
/mpdev:env restart user-service@8082         精确匹配某实例（多实例场景）
/mpdev:env restart java --profile=test   重启指定模块并切换 Spring profile（会更新 state.yml）
/mpdev:env restart --full                先 compose down/up，再重启业务模块
/mpdev:env stop         停止所有业务模块（保留 compose）
/mpdev:env stop dispatch 停止指定模块
/mpdev:env stop --all-including-infra    停止业务模块 + docker compose down
/mpdev:env status       查看业务模块 + compose 基础设施状态
/mpdev:env open         在浏览器中打开所有可访问的模块页面
/mpdev:env open java    只打开指定模块的页面
```

## $ARGUMENTS

用户在 `/mpdev:env` 后追加的文本。解析规则：

```
取第一个词为 action，剩余切分为 target + flags

action 匹配:
  空 / "start"       → 走 [完整启动流程]（支持 target 过滤）
  "restart"          → 走 [快捷: 重启]
  "stop"             → 走 [快捷: 停止]
  "status" / "ps"    → 走 [快捷: 状态]
  "open"             → 走 [打开页面]

target 匹配（对所有 action 统一）:
  空                     → 操作全部模块（或 state.yml 中所有实例）
  单个词                 → 模糊匹配模块名（包含即命中，命中全部实例）
  逗号分隔              → 多子集（如 "gateway,user" → 命中含 gateway 或 user 的模块）
  name@port             → **精确实例匹配**（多实例场景）；只匹配 name=xxx 且 port=yyy 的那一个
  name@port,name@port   → 多实例精确匹配

  匹配源:
    - start  → 从 Step 1 模块发现结果中匹配（state.yml 可能还不存在）
    - 其他   → 从 .claude/.mpdev-env-state.yml 的 modules 中匹配（含所有实例）

flags（以 `--` 起始的参数，可选）:
  --profile={value}          → start / restart 支持；
                                · start：跳过 Step 6 交互，对 target（或全部）模块统一用此 profile
                                · restart：覆盖 state.yml 中对应模块的 profile 字段并重启
  --add-instance-port={port} → 仅 start 支持，必须配合具体 target（单模块）；
                                从现有 state.yml 中的该模块克隆一份配置，改端口后作为新实例写入并启动
  --full                     → 仅 restart 支持，连同 compose 一起重启
  --all-including-infra      → 仅 stop 支持，连同 compose 一起停止

解析示例:
  "start gateway --profile=dev"
    → action=start, target=[gateway], flags={profile: dev}
  "start user-service --add-instance-port=8082"
    → action=start, target=[user-service], flags={add_instance_port: 8082}
  "restart user-service@8082"
    → action=restart, target=[user-service@8082], flags={}
    → 精确匹配 name=user-service 且 port=8082 的实例
```

## 状态文件

路径：`.claude/.mpdev-env-state.yml`

首次 `/mpdev:env start` 完成 Step 10（启动）后自动生成。后续的 `restart / stop / status` 依赖此文件。

```yaml
# .claude/.mpdev-env-state.yml — 由 /mpdev:env 自动生成，勿手动编辑
generated_at: "2026-04-16T15:30:00"
project_root: "F:/claude/ult_2.2"

modules:
  - name: algorithm
    directory: mr_ult_algor_2.1
    start_cmd: "cd F:/claude/ult_2.2/mr_ult_algor_2.1 && python -m gunicorn -c lib/gunicorn.py app:app"
    port: 8087
    health_check: "curl -sf http://localhost:8087/"
    stop_strategy: port       # port | pid | cmd_pattern
    order: 1

  - name: java-backend
    directory: mr_ult_java_2.1
    start_cmd: "cd F:/claude/ult_2.2/mr_ult_java_2.1 && mvn spring-boot:run -pl moss-admin"
    port: 8094
    health_check: "curl -sf http://localhost:8094/actuator/health"
    stop_strategy: port
    order: 2

  - name: dispatch
    directory: mr_ult_dispatch_2.1
    start_cmd: "cd F:/claude/ult_2.2/mr_ult_dispatch_2.1 && python main.py"
    port: 8888
    health_check: "curl -sf http://localhost:8888/"
    stop_strategy: port
    order: 3

  - name: analytics
    directory: mr_ult_analystic_2.1
    start_cmd: "cd F:/claude/ult_2.2/mr_ult_analystic_2.1 && python main.py"
    port: 8089
    health_check: "curl -sf http://localhost:8089/"
    stop_strategy: port
    order: 4

  - name: vue-frontend
    directory: mr_ult_vue_2.1
    start_cmd: "cd F:/claude/ult_2.2/mr_ult_vue_2.1/robot_pad && npm run serve"
    port: 8080
    health_check: "curl -sf http://localhost:8080/"
    stop_strategy: port
    order: 5
    skip_auto_start: true      # 标记为手动启动

middleware:
  - type: mysql
    host: 127.0.0.1
    port: 3306
  - type: redis
    host: 127.0.0.1
    port: 6379
  - type: rabbitmq
    host: 127.0.0.1
    port: 5672
```

> 上面是示例。实际内容由 Step 10 执行过程中动态生成，字段值来自检测和用户输入。

### 场景 B 扩展示例：Spring Cloud + Docker Compose

当项目含 `docker-compose*.yml` 时，状态文件额外包含 **compose_infra 顶层块**，模块条目多两个字段（`depends_on_compose` / `profile`）：

```yaml
# .claude/.mpdev-env-state.yml（场景 B 示例）
generated_at: "2026-04-17T18:00:00"
project_root: "F:/work/my-cloud-app"

# 新增：Docker Compose 管理的基础设施（由 Step 2 检测）
compose_infra:
  file: "docker-compose.yml"
  files_merged: ["docker-compose.yml", "docker-compose.override.yml"]
  services:
    - name: nacos
      type: nacos
      image: "nacos/nacos-server:v2.2.3"
      ports: [8848, 9848, 9849]
      health: "curl -sf http://localhost:8848/nacos/v1/ns/operator/servers"
      requires_auth: false
      role: [service_registry, config_center]
    - name: mysql
      type: mysql
      image: "mysql:8.0"
      ports: [3306]
      health: "nc -z localhost 3306"
    - name: redis
      type: redis
      image: "redis:7-alpine"
      ports: [6379]
      health: "redis-cli -h localhost ping"

# 业务微服务（本地 mvn 启动）
modules:
  - name: gateway
    directory: gateway
    start_cmd: "cd gateway && mvn spring-boot:run -Dspring-boot.run.profiles=dev"
    port: 8080
    health_check: "curl -sf http://localhost:8080/actuator/health"
    stop_strategy: port
    order: 1
    depends_on_compose: [nacos, redis]   # 等待 compose 服务就绪后才启动
    profile: dev                         # Spring profile（可选字段）
  - name: user-service
    directory: user-service
    start_cmd: "cd user-service && mvn spring-boot:run -Dspring-boot.run.profiles=dev"
    port: 8081
    health_check: "curl -sf http://localhost:8081/actuator/health"
    stop_strategy: port
    order: 2
    depends_on_compose: [nacos, mysql, redis]
    profile: dev

# 传统外部中间件（compose 未覆盖的才列在这里）
middleware: []
```

---

## 快捷: 重启 (`/mpdev:env restart [target]`)

```
1. Read ".claude/.mpdev-env-state.yml"
   - 如果不存在 → 提示 "尚未初始化，请先执行 /mpdev:env start" 并终止
2. 如果有 target → 模糊匹配模块名，只操作匹配的模块
   如果无 target → 操作所有模块（skip_auto_start 的除外）
3. 对每个目标模块按 order 排序，依次执行:
   a. 停止: 按 stop_strategy 停止
      - port 策略: 查找占用该端口的进程并 kill
        Windows: `netstat -ano | findstr :{port}` → 取 PID → `taskkill /PID {pid} /F`
        Linux:   `lsof -ti:{port} | xargs kill -9` 或 `fuser -k {port}/tcp`
      - 如果端口无进程 → 跳过停止（可能已停止）
   b. 等待 2 秒确认端口释放
   c. 启动: `Bash(start_cmd, run_in_background=true)`
   d. 健康检查: 执行 health_check 命令（最多 30 秒，每 5 秒一次）
4. 输出结果（多实例时用 name@port 标识，便于用户区分）:
   重启完成:
     OK   java-backend           :8094  已就绪
     OK   user-service@8081      :8081  已就绪
     OK   user-service@8082      :8082  已就绪
     WARN analytics              :8089  启动中
```

**扩展选项**：
- `/mpdev:env restart --full` → 先 `docker compose down && up -d`，再重启业务模块
- `/mpdev:env restart {target} --profile={value}` → 切换 Spring profile 后重启：
  1. Read `.claude/.mpdev-env-state.yml`，定位 target 模块
  2. **校验**：每个匹配的 entry 必须是 Spring 模块——判定标准：
       - `start_cmd` 含 `mvn spring-boot:run` / `gradlew bootRun` / `java -jar`，或
       - state.yml 已有非空 `profile` 字段
     非 Spring 模块（如 Python `python main.py` / Node `npm run dev`）→ **报错并终止**：
       `❌ {module_name} 不是 Spring 模块，--profile 无效。请去掉此 flag 或换一个 target。`
  3. 将 `profile` 字段改为 `{value}`
  4. 重写 `start_cmd`：去掉原有 `-Dspring-boot.run.profiles=xxx` 或 `--spring.profiles.active=xxx`，按 Step 10.2 的占位符规则追加新值
  5. `Write` 回 state.yml
  6. 按正常 restart 流程（停→等→起→健康检查）
- 默认**不动 compose**（基础设施起停成本高，业务重启应保持基础设施运行）

## 快捷: 停止 (`/mpdev:env stop [target]`)

```
1. Read ".claude/.mpdev-env-state.yml"
   - 如果不存在 → 提示 "尚未初始化" 并终止
2. 如果有 target → 模糊匹配，只操作匹配的模块
   如果无 target → 操作所有模块（按 order 逆序停止）
3. 对每个目标模块:
   a. 查找占用端口的进程:
      Windows: `netstat -ano | findstr :{port}` → 取 PID
      Linux:   `lsof -ti:{port}`
   b. 如果找到进程 → kill 并等 2 秒确认
   c. 如果未找到 → 标记 "已停止"
4. 输出结果:
   停止完成:
     STOP java-backend   :8094  已停止 (PID 12345)
     STOP dispatch       :8888  已停止 (PID 12346)
     --   analytics      :8089  未在运行
```

**扩展选项**（Docker Compose 场景）：
- `/mpdev:env stop --all-including-infra` → 业务模块全停 + `docker compose down`
- 默认**只停业务模块**，保留 compose 基础设施运行（下次 start 更快）
- 若 state.yml 无 `compose_infra`，此选项等同默认 stop

## 快捷: 状态 (`/mpdev:env status`)

```
1. Read ".claude/.mpdev-env-state.yml"
   - 如果不存在 → 提示 "尚未初始化" 并终止
2. 对每个模块检测当前状态:
   a. 检查端口是否被监听:
      Windows: `netstat -ano | findstr :{port}`
      Linux:   `lsof -i:{port}`
   b. 如果端口被占用 → 执行 health_check 确认是否健康
3. 若 state.yml 含 compose_infra:
   a. Bash("docker compose ps --format json") 获取各 service 运行状态
   b. 对每个 compose 服务，执行其 health 命令验证（Nacos/MySQL/Redis 等）
4. 检查中间件连通性（非 compose 管理的外部服务，同 Step 7 逻辑但简化输出）
4. 输出:
   MPDev 环境状态
   ===========================

   Docker 基础设施（若 state.yml 含 compose_infra）:
     RUN  nacos     :8848  healthy
     RUN  mysql     :3306  up 3h
     RUN  redis     :6379  up 3h

   中间件（非 compose 管理）:
     OK  MySQL     127.0.0.1:3306
     OK  Redis     127.0.0.1:6379
     ERR RabbitMQ  127.0.0.1:5672 — 连接超时

   模块（多实例时用 name@port 标识）:
     RUN  algorithm              :8087  PID 11234  运行中
     RUN  java-backend           :8094  PID 11235  运行中
     RUN  user-service@8081      :8081  PID 11236  运行中  (instance=1, profile=dev)
     RUN  user-service@8083      :8083  PID 11240  运行中  (instance=2, profile=dev)
     DOWN dispatch               :8888  --         未运行
     RUN  analytics              :8089  PID 11237  运行中
     SKIP vue-frontend           :8080  --         (手动管理)

   运行时间: 自 2026-04-16 15:30 起
```

**渲染规则**：
- 单实例模块（state.yml 无 `instance` 字段或仅一个 entry）→ 显示 `name`
- 多实例模块（同 name 有 ≥2 entries）→ 全部显示 `name@port`
- Spring 模块附带 `(profile=xxx)` 提示

---

## 完整启动流程 (`/mpdev:env` 或 `/mpdev:env start`)

**使用场景**：
- 克隆项目后首次启动
- 切换开发环境（如从本地切到测试服务器）
- 中间件地址/凭据变更后批量更新配置
- `/mpdev:dev` 开发完成后需要启动验证

## Step 1: 模块发现

```
Glob("**/CLAUDE.md")
排除: .claude/ node_modules/ .git/ __pycache__/ target/ dist/ build/
```

对每个 CLAUDE.md 提取：

| 提取项 | 搜索段落 | 用途 |
|--------|---------|------|
| 模块名 | 所在目录名 | 标识 |
| 技术栈 | `## 技术栈` / `## Tech Stack` | 中间件检测 |
| 启动方式 | `## 构建与部署` / `## Build and Deploy` / `## 启动` | Step 10 启动 |
| 模块关系 | `## 与其他模块的关系` / `## Module Relations` | Step 10 排序 |

读取规则同 mpdev-init：段落 ≤200 行直接读，>200 行 grep 关键词后读周围 30 行。

### 1.x Target 过滤（单/多服务场景）

若 `$ARGUMENTS` 含 target（如 `/mpdev:env start gateway` 或 `start gateway,user`）：

1. 将 target 切分（逗号分隔）→ 关键词列表 `[kw1, kw2, ...]`
2. 对 Step 1 发现的每个模块，模块名含任一关键词即保留
3. 展示过滤结果给用户确认：
   ```
   按 target "gateway,user" 过滤，匹配到 2 个模块：
     - gateway          (gateway/)
     - user-service     (user-service/)
   未匹配：order-service, payment-service
   是否只对这 2 个模块继续？[继续 / 全量启动 / 取消]
   ```
4. 后续 Step 3~7 都只处理过滤后的模块子集

**注意**：
- 中间件检测（Step 3）只扫子集内的模块，可能漏掉其他模块依赖的共享中间件
- Step 9 compose 启动仍然**启动全部 compose services**（基础设施不按模块切分）
- 若子集内某模块的依赖模块未被启动（如 gateway 依赖 user-service 但未选），给 warn 但不阻塞

## Step 2: Docker Compose 基础设施检测

检测项目内是否存在 docker-compose 文件，如有则解析其服务定义。**无 compose → 直接跳到 Step 3**。

### 2.1 扫描 compose 文件

```
Glob("docker-compose*.yml", "docker-compose*.yaml")
搜索优先位置: 项目根 → infra/ → docker/ → deploy/
```

按 Docker Compose 规范识别：
- **主文件**: `docker-compose.yml` / `docker-compose.yaml`
- **override 文件**: `docker-compose.override.yml` / `docker-compose.dev.yml` / `docker-compose.local.yml`

**未找到** → 设置 `has_compose = false`，直接进入 Step 3（走原有中间件检测流程）。

### 2.2 解析 services

Read 所有 compose 文件（含 override）。对每个 `services.{name}` 提取：

```
- name: 服务名（yaml 的 key）
- image: 镜像名称
- ports: 端口映射（"8848:8848" → [8848]）
- depends_on: 依赖链
- healthcheck: Docker 原生健康检查（如有）
- environment / env_file: 环境变量（扫描 auth 相关）
```

### 2.3 识别服务类型

按 `image` 关键词归类：

| image 匹配 | 类型 | 默认端口 | 角色 |
|-----------|------|---------|------|
| `nacos/nacos-server` | nacos | 8848, 9848, 9849 | service_registry + config_center（双身份）|
| `mysql` / `mysql:*` | mysql | 3306 | database |
| `mariadb` | mariadb | 3306 | database |
| `redis` / `redis:*` | redis | 6379 | cache |
| `rabbitmq` | rabbitmq | 5672, 15672 | mq |
| `postgres` / `postgres:*` | postgres | 5432 | database |
| `zookeeper` | zookeeper | 2181 | service_registry |
| `consul` | consul | 8500 | service_registry |
| 其他 | unknown | - | - |

**Nacos 认证模式检测**：
- 扫 `environment` 块，找 `NACOS_AUTH_ENABLED=true`
- 找 `auth.token.secret.key` / `auth.enabled` 等配置
- 识别到启用 auth → 记录 `requires_auth: true`，后续健康检查会走 token 流程

### 2.4 结果结构

检测结果记入内存 `compose_infra`（Step 9 使用，Step 10.5 写入状态文件）：

```yaml
compose_infra:
  has_compose: true
  file: "docker-compose.yml"
  files_merged: ["docker-compose.yml", "docker-compose.override.yml"]
  services:
    - name: nacos
      image: "nacos/nacos-server:v2.2.3"
      type: nacos
      ports: [8848, 9848, 9849]
      requires_auth: false
      role: [service_registry, config_center]
    - name: mysql
      image: "mysql:8.0"
      type: mysql
      ports: [3306]
```

## Step 3: 中间件检测

对每个模块执行两阶段检测：

### Phase A: CLAUDE.md 关键词扫描

在 `## 技术栈` 段匹配关键词（大小写不敏感）：

| 关键词模式 | 中间件类型 | 默认端口 |
|-----------|-----------|---------|
| `MySQL` `MariaDB` `JDBC` `datasource` `pymysql` `SQLAlchemy` `aiomysql` | mysql | 3306 |
| `Redis` `Lettuce` `Jedis` `redis-py` `aioredis` | redis | 6379 |
| `RabbitMQ` `AMQP` `pika` `spring-amqp` | rabbitmq | 5672 |
| `Kafka` `kafka-python` `spring-kafka` | kafka | 9092 |
| `MongoDB` `pymongo` `Mongoose` | mongodb | 27017 |
| `PostgreSQL` `psycopg2` `asyncpg` | postgresql | 5432 |
| `Elasticsearch` `opensearch` | elasticsearch | 9200 |
| `MinIO` `S3` `OSS` | object_storage | 9000 |
| `Nacos` `Consul` `Eureka` `Zookeeper` | service_registry | 8848 |

> 此表可扩展：遇到未覆盖的中间件，按同样模式追加即可。

### Phase B: 配置文件扫描

在每个模块目录下搜索配置文件：

```
Glob("{module_dir}/**/application*.yml")
Glob("{module_dir}/**/application*.yaml")
Glob("{module_dir}/**/application*.properties")
Glob("{module_dir}/**/config.yml")
Glob("{module_dir}/**/config.yaml")
Glob("{module_dir}/**/*config*.yaml")
Glob("{module_dir}/**/*config*.yml")
Glob("{module_dir}/**/.env*")
Glob("{module_dir}/**/settings.py")
```

对找到的配置文件，提取中间件连接块：

```
1. Grep "host|port|password|url|uri" 附近含中间件名的行
2. 读匹配行 ±5 行，提取完整连接配置块
3. 记录: {模块名, 中间件类型, 配置文件路径, 键路径, 当前值}
```

**键路径识别规则**（通用，不硬编码）：

- YAML 文件：沿缩进层级向上追溯完整路径（如 `spring.datasource.url`）
- Properties 文件：直接取 key（如 `spring.datasource.url=...`）
- .env 文件：取 `KEY=value` 中的 KEY
- Python 文件：取赋值语句的变量名

### 结果合并

将 Phase A 和 Phase B 结果合并去重，建立 **中间件需求表**：

```
内部数据结构（不展示给用户，Step 4 用简化版）:
[
  { module: "java-backend", type: "mysql",
    config_file: "application-db.yml",
    keys: { host: "spring.datasource.url 中的 host 部分", port: "...", user: "spring.datasource.username", password: "spring.datasource.password" },
    current_values: { host: "10.173.30.67", port: "3306", ... }
  },
  ...
]
```

## Step 4: 需求汇总与确认

向用户展示简化结果表：

```
检测到以下中间件需求：

| 中间件     | 依赖模块                              | 当前配置主机      |
|-----------|--------------------------------------|-----------------|
| MySQL     | java-backend, dispatch, analytics    | 10.173.30.67 / 127.0.0.1 |
| Redis     | java-backend, dispatch, analytics    | 10.173.26.181 / 127.0.0.1 |
| RabbitMQ  | java-backend, dispatch, analytics    | 10.173.26.181 / 127.0.0.1 |

无需中间件的模块: algorithm, vue-frontend

是否正确？如有遗漏请补充。
```

等待用户确认。若用户补充了新的中间件需求，手动添加到需求表中。

## Step 5: 收集连接信息

### 4.1 共享分析

对同一类中间件被 ≥2 个模块使用的情况：
- 检查当前配置中各模块的凭据（username + password）是否相同
- 如果相同 → 默认建议 "共享凭据"
- 询问用户："MySQL 被 3 个模块使用，是否共用同一凭据？（Host 可分别指定）"
  - **是** → 凭据只问一次，Host 可按模块覆盖
  - **否** → 逐模块分别收集

### 4.2 逐中间件收集

对每种中间件，用 AskUserQuestion 收集连接信息。默认值取 Step 3 扫描到的当前配置值。

**MySQL：**
```
- Host    [默认: {当前值}]
- Port    [默认: 3306]
- Database [默认: {当前值}]
- Username [默认: {当前值}]
- Password
```

**Redis：**
```
- Host     [默认: {当前值}]
- Port     [默认: 6379]
- Password [默认: 空 / {当前值}]
- Database [默认: 0]
```

**RabbitMQ：**
```
- Host     [默认: {当前值}]
- Port     [默认: 5672]
- Username [默认: {当前值}]
- Password
- Virtual Host [默认: /]
```

**其他中间件：** 根据 Step 3 检测到的键路径动态生成问题项。

### 4.3 主机覆盖

若 4.1 选择共享凭据，追问：
"各模块是否使用相同的 Host？（如 Java 连远程 IP、Python 连 localhost 的情况）"
- **相同** → 统一填写
- **不同** → 按模块分别指定 Host（凭据共享）

## Step 6: Spring Profile 采集

**仅当至少一个模块是 Spring Boot / Spring Cloud 时执行**；否则跳到 Step 7。

### 6.0 命令行快速路径（`--profile=` flag）

若 `$ARGUMENTS` 含 `--profile={value}`：
- **跳过 4.5.2~4.5.3 的交互**
- 对 target 过滤后的所有 Spring 模块（target 为空时即全部 Spring 模块），统一写入 `module_profiles[{name}] = {value}`
- 仍执行 4.5.1（识别）和 4.5.4（Nacos 提示），便于用户看清楚受影响的模块
- 在日志中告知："已通过 --profile=dev 为 {N} 个 Spring 模块设置 profile，跳过交互"

若未提供 `--profile`，走 4.5.1~4.5.5 完整流程。

### 6.1 识别 Spring 模块

对 Step 1 过滤后的每个模块，满足任一即判定为 Spring 模块：
- 存在 `pom.xml` 且含 `spring-boot` 依赖（`Grep -l "spring-boot" {dir}/pom.xml`）
- 存在 `build.gradle` / `build.gradle.kts` 且含 `spring-boot-starter`
- CLAUDE.md 明确声明 Spring Boot / Spring Cloud

### 6.2 扫描可用 profile

对每个 Spring 模块：
1. `Glob("{module_dir}/**/application-*.yml")` + `.yaml` + `.properties`
2. 从文件名 `application-{profile}.xxx` 抽 profile 列表
3. 读主 `application.yml` / `application.yaml` / `application.properties`，找 `spring.profiles.active` 的默认值
4. 若有 `bootstrap.yml` / `bootstrap.yaml`（Spring Cloud Config），同样扫 profile

**如果一个模块没有任何 `application-{profile}` 文件**：
- 说明它不按 profile 分离配置 → 仍然允许用户指定 profile（通过 `-Dspring-boot.run.profiles=`），只是没有候选列表

### 6.3 展示并收集

```
检测到 Spring Boot 模块及其可用 profile：
| 模块           | 候选 profile              | application 默认 | 建议 |
|----------------|--------------------------|-----------------|------|
| gateway        | dev, test, prod, local   | (未设)           | dev  |
| user-service   | dev, test                | dev             | dev  |
| order-service  | (无 application-*.yml)    | (未设)           | —    |

如何指定 Spring profile？
  [选项]
    (a) 全部用同一个 profile（推荐）
    (b) 逐模块指定
    (c) 不设（沿用各模块 application.yml 中的默认）
```

用 AskUserQuestion 收集。

**选 (a)**：再问"用哪个 profile？"，提供候选列表取并集（如 `[dev, test, prod, local]` + "其他：手动输入"）。
**选 (b)**：对每个模块分别问"用哪个 profile？"，候选取本模块的列表 + "不设"。
**选 (c)**：跳过，不注入 profile 参数。

### 6.4 Nacos Config 提示

若 Step 2 检测到 compose 中含 Nacos **且**任一 Spring 模块的 `bootstrap.yml` 引用 Nacos Config：

```
⚠️ 检测到 Nacos Config，profile 会影响 Data ID 拉取规则：
  默认 Data ID：{application-name}-{profile}.{file-extension}
  请确认 Nacos 上已有对应 profile 的配置，否则启动可能失败。
```

不自动拉取验证（成本高），仅提示。

### 6.5 写入内存

产出 `module_profiles` 映射供 Step 10 使用：
```yaml
module_profiles:
  gateway: dev
  user-service: dev
  order-service: null    # 用户选"不设"
```

## Step 7: 连接验证

对每种中间件依次验证连通性：

| 中间件 | 验证方式（按优先级） |
|--------|-------------------|
| MySQL | ① `python -c "import pymysql; c=pymysql.connect(host=..., port=..., user=..., password=..., db=...); c.close(); print('OK')"` ② `mysql -h ... -P ... -u ... -p... -e "SELECT 1"` ③ `nc -zv {host} {port}` |
| Redis | ① `python -c "import redis; r=redis.Redis(host=..., port=..., password=...); r.ping(); print('OK')"` ② `redis-cli -h ... -p ... -a ... ping` ③ `nc -zv {host} {port}` |
| RabbitMQ | ① `python -c "import pika; pika.BlockingConnection(pika.ConnectionParameters(host=..., port=..., credentials=pika.PlainCredentials(...))).close(); print('OK')"` ② `curl -sf -u {user}:{pass} http://{host}:15672/api/overview > /dev/null && echo OK` ③ `nc -zv {host} {port}` |
| Kafka | ① `python -c "from kafka import KafkaConsumer; ..."` ② `nc -zv {host} {port}` |
| 其他 | `nc -zv {host} {port}` 端口连通性 |

输出结果：
```
连接验证结果：
  OK  MySQL    (127.0.0.1:3306) — 连接成功, 数据库 mr_ult 存在
  OK  Redis    (127.0.0.1:6379) — PONG
  ERR RabbitMQ (127.0.0.1:5672) — Connection refused
```

**失败处理**：
- 展示具体错误信息
- 询问："RabbitMQ 连接失败，是否仍要写入此配置？（可能中间件尚未启动）"
- 用户确认后继续，否则允许重新输入连接信息

## Step 8: 配置写入

对 Step 3 中记录的每个 `{模块, 配置文件, 键路径}` 条目：

1. **Read** 配置文件获取当前内容
2. **定位** 目标键值行
3. **Edit** 精确替换旧值为新值

**写入策略**：

| 文件类型 | 替换方式 |
|---------|---------|
| YAML (`*.yml / *.yaml`) | Edit 替换值部分，保留缩进和注释 |
| Properties (`*.properties`) | 按 `key=value` 格式整行替换 |
| .env | 按 `KEY=value` 格式整行替换 |
| Python config | 按赋值语句替换值部分 |

**写入约束**：
- **只替换连接参数**：host、port、username、password、database/db、url/uri
- **不动其他配置**：连接池大小、超时时间、序列化器等保持原样
- **保留格式**：使用 Edit 精确替换，不重写整个文件

**JDBC URL 特殊处理**：
如果 MySQL 配置是 JDBC URL 格式（`jdbc:mysql://host:port/db`），需组装完整 URL 后替换。

写入完成后展示摘要：
```
配置写入完成：
  java-backend / application-db.yml    — MySQL host+port+user+password
  java-backend / application.yml       — Redis host+port+password, RabbitMQ host+port+user+password
  dispatch / conf/public_config.yaml   — MySQL + Redis + RabbitMQ 全部更新
  analytics / conf/config.yml          — MySQL + Redis + RabbitMQ 全部更新
  algorithm                            — 无需配置 (跳过)
  vue-frontend                         — 无中间件配置 (跳过)
```

## Step 9: 基础设施启动（Docker Compose）

**仅当 Step 2 识别到 `compose_infra.has_compose = true` 时执行**；否则跳到 Step 10。

### 9.1 启动 compose

```
1. 展示服务清单（名字 + 镜像 + 端口）给用户确认
2. AskUserQuestion: "是否立即启动 Docker 基础设施？"
   选项: [立即启动 / 已在运行跳过 / 取消]
3. 若"立即启动":
   无 override → Bash("docker compose up -d")
   有 override → Bash("docker compose -f docker-compose.yml -f docker-compose.override.yml up -d")
```

### 9.2 按依赖拓扑等待就绪

按 `depends_on` 拓扑排序，逐服务验证（最多 60 秒）：

```
优先级:
  ① 服务自带 healthcheck:
     轮询 `docker compose ps --format json`，检查 Health=healthy
  ② 按 type 专用检查:
     - nacos（无鉴权）: curl -sf http://localhost:8848/nacos/v1/ns/operator/servers
     - nacos（auth）  : 先 POST /v1/auth/users/login 获 token，再带 token 查 /v1/ns/...
     - mysql          : nc -z localhost 3306
     - redis          : redis-cli -h localhost ping → 期望 PONG
     - rabbitmq       : curl -sf http://localhost:15672 或 nc -z localhost 5672
     - zookeeper/consul: nc -z 端口 兜底
  ③ 兜底: nc -z localhost {port}

失败处理:
  Bash("docker compose logs {service} --tail 30") 展示日志
  AskUserQuestion: [重试 / 跳过此服务 / 终止]
```

### 9.3 报告

```
Docker 基础设施状态:
  OK  nacos      :8848  healthy
  OK  mysql      :3306  connected
  OK  redis      :6379  PONG
  ERR rabbitmq   :5672  timeout → 查看 docker compose logs rabbitmq
```

所有关键服务就绪后进入 Step 10 启动业务模块。业务模块若声明了 `depends_on_compose`，Step 10.3 启动时会再次验证这些依赖服务仍然健康。

## Step 10: 模块启动

### 7.0 多实例克隆（`--add-instance-port=` flag）

若 `$ARGUMENTS` 含 `--add-instance-port={port}`（此时 target 必须指向唯一模块，否则报错并终止）：

1. Read `.claude/.mpdev-env-state.yml`，找到 target 模块的**基准实例**（无 `instance` 字段的 primary，或 `instance=1`）
2. 校验：
   - state.yml 中不能已存在同 name + 同 port 的实例 → 已存在则报错
   - 新端口需空闲（`lsof -i:{new_port}` / `netstat -ano | findstr :{new_port}` 无监听）
3. **克隆**基准实例为新 entry，修改以下字段：
   - `port: {new_port}`
   - `health_check`: 把 URL 中的端口替换为 `{new_port}`
   - `start_cmd`: 注入 `-Dserver.port={new_port}`（Spring Boot）/ `--port={new_port}`（Node）/ 其他语言按用户启动命令模式替换
   - `instance`: 原实例若无此字段则**同时回填基准实例 `instance: 1`**（方便后续识别 primary），新实例写 `2`（若已有 2 则递增到下一个未占用编号）
   - `order`: 新实例取原 `order + 0.1`（仅影响启动排序，不改变 stop 时的逆序）
4. **profile 继承**：新实例默认继承基准实例的 `profile`；若 `$ARGUMENTS` 同时含 `--profile=`，新实例用新值、基准实例不变
5. Append 到 state.yml 的 modules，Write 回
6. **只启动新实例**（不重启基准实例），走 7.3~7.4

**无此 flag** → 跳过 7.0，进入常规 7.1~7.5 流程（state.yml 若已含多实例，全部启动）。

### 7.1 启动顺序

从各模块 CLAUDE.md 的 `## 与其他模块的关系` 段解析依赖，构建启动顺序。

规则：
- 无依赖 / 被依赖最多的模块优先
- 前端模块最后（依赖后端 API）
- 如果无法确定顺序，按以下通用策略：`基础服务 → 后端 → 中间层 → 前端`

### 7.2 启动命令提取

对每个模块，按优先级获取启动命令：

1. **CLAUDE.md 明确指定** — 读 `## 构建与部署` / `## 启动` 段中的命令
2. **推断** — 如果 CLAUDE.md 无明确命令，按语言推断：

| 检测条件 | 启动命令 |
|---------|---------|
| 存在 `pom.xml` + `spring-boot` | `cd {dir} && mvn spring-boot:run {PROFILE_MVN}` |
| 存在 `build.gradle` + `spring-boot` | `cd {dir} && ./gradlew bootRun {PROFILE_GRADLE}` |
| 存在 `*.jar` | `cd {dir} && java -jar {jar_file} {PROFILE_JAR}` |
| 存在 `gunicorn.py` / `gunicorn_config.py` | `cd {dir} && gunicorn -c gunicorn.py ...` |
| 存在 `main.py` (Python) | `cd {dir} && python main.py` |
| 存在 `manage.py` (Django) | `cd {dir} && python manage.py runserver` |
| 存在 `package.json` + `"dev"` script | `cd {dir} && npm run dev` |
| 存在 `package.json` + `"serve"` script | `cd {dir} && npm run serve` |

**PROFILE 占位符展开**（仅 Spring Boot 分支用；由 Step 6 产出的 `module_profiles[{module}]` 决定）：

| 占位符 | profile 有值（如 `dev`） | profile 为 null/未设 |
|-------|-------------------------|---------------------|
| `{PROFILE_MVN}` | `-Dspring-boot.run.profiles=dev` | （空字符串）|
| `{PROFILE_GRADLE}` | `--args='--spring.profiles.active=dev'` | （空字符串）|
| `{PROFILE_JAR}` | `--spring.profiles.active=dev` | （空字符串）|

**优先级**：CLAUDE.md 明确指定的命令 > 推断命令。若 CLAUDE.md 的命令已含 profile，**不要**再追加；若未含而 `module_profiles` 有值，按同样规则在尾部追加相应后缀。

3. **询问用户** — 如果推断不出，展示模块信息并请用户提供启动命令

### 7.3 逐模块启动

对每个模块：

```
0. 检查 depends_on_compose（仅 Step 2 识别到 compose_infra 时）:
   如果模块声明了 depends_on_compose（如 [nacos, redis]）:
     对每个依赖服务，执行其 health 命令再次确认存活
     任何一个失败 → AskUserQuestion:
       [继续启动（忽略依赖） / 跳过此模块 / 终止]
1. 展示即将执行的启动命令，等用户确认
2. 执行: Bash(command, run_in_background=true)
3. 等待 5 秒
4. 检查进程是否存活: ps aux | grep {关键字} 或 lsof -i:{port}
5. 如果进程存活 → 进入健康检查
6. 如果进程已退出 → 读最后 30 行日志，报告启动失败原因
```

### 7.4 健康检查

启动后轮询检测（最多 30 秒，每 5 秒一次）：

| 检查方式 | 条件 | 适用场景 |
|---------|------|---------|
| Spring Boot Actuator | `curl -sf http://localhost:{port}/actuator/health` | Spring Boot / Cloud 微服务 |
| Nacos（无鉴权） | `curl -sf http://localhost:{port}/nacos/v1/ns/operator/servers` | Nacos Server |
| Nacos（启用 auth） | 先 `curl -X POST .../v1/auth/users/login` 取 token，再带 token 查 | Nacos 开启鉴权 |
| 通用 HTTP | `curl -sf http://localhost:{port}/` | 其他 HTTP 服务 |
| 端口监听 | `lsof -i:{port}` 或 `netstat -tlnp \| grep {port}` | 非 HTTP 服务（DB/MQ/cache） |
| 日志关键词 | grep "Started" / "Listening on" / "ready" / "Running" | 兜底 |

### 7.5 保存状态文件

启动完成后，将所有模块的运行信息写入 `.claude/.mpdev-env-state.yml`：

```
对每个模块记录:
  - name: 模块名
  - directory: 模块目录（绝对路径）
  - start_cmd: 实际使用的启动命令
  - port: 监听端口
  - health_check: 健康检查命令
  - stop_strategy: "port"（默认按端口停止）
  - order: 启动顺序编号
  - skip_auto_start: true/false（前端等手动启动的标记 true）
  - depends_on_compose: [服务名列表]（仅 compose 场景；来自 CLAUDE.md 或 start_cmd 中的依赖声明）
  - profile: Spring profile（仅 Java/Spring 模块；从 start_cmd 解析 -Dspring-boot.run.profiles=xxx）
  - instance: 实例编号（仅多实例场景；单实例模块可省略。同 name 的 entries 通过 instance + port 组合区分）

对中间件记录（非 compose 管理的外部服务）:
  - type / host / port

对 compose_infra 记录（若 Step 2 识别到）:
  - file / files_merged
  - services[]: name / type / image / ports / health / requires_auth / role

Write(".claude/.mpdev-env-state.yml", yaml_content)
```

此文件供 `restart / stop / status` 子命令使用，避免重复检测。

## Step 11: 最终报告

```
MPDev 环境启动报告
===========================

中间件连接:
  OK  MySQL     127.0.0.1:3306/mr_ult
  OK  Redis     127.0.0.1:6379
  OK  RabbitMQ  127.0.0.1:5672

模块状态:
  OK  algorithm      :8087  已就绪
  OK  java-backend   :8094  已就绪
  OK  dispatch       :8888  已就绪
  WARN analytics     :8089  启动中 (日志无报错, 等待就绪)
  SKIP vue-frontend  --    跳过 (请手动 npm run serve)

配置文件变更:
  application-db.yml         — MySQL 连接已更新
  application.yml            — Redis + RabbitMQ 连接已更新
  conf/public_config.yaml    — 全部连接已更新
  conf/config.yml            — 全部连接已更新

提示:
  - 查看日志: tail -f {各模块日志路径}
  - 查看状态: /mpdev:env status
  - 重启全部: /mpdev:env restart
  - 重启某个: /mpdev:env restart java
  - 停止全部: /mpdev:env stop
  - 重新配置: /mpdev:env start (重走完整流程)
```

## 约束

1. **密码安全** — 用户输入的密码只写入原有的配置文件（`.yml`, `.properties`, `.env`），绝不写入 `.md` 文件或状态文件
2. **最小修改** — 只替换连接值，不改连接池参数、超时设置、序列化配置等
3. **格式保留** — 使用 Edit 精确替换，保持文件原有格式、注释和缩进
4. **失败容忍** — 单个模块启动失败不阻塞其他模块，最终报告中标注失败项
5. **不自动安装** — 缺少依赖库只提示，不执行 `pip install` / `npm install`
6. **可重复执行** — 多次运行只更新变更的值，幂等操作
7. **启动前确认** — 每个模块启动命令执行前展示给用户确认（restart/stop 快捷操作免确认）
8. **状态文件** — `.claude/.mpdev-env-state.yml` 不含密码，仅记录启动命令、端口、健康检查等运行时信息
