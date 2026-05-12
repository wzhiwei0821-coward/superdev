# Java Spring 后端 — 分轮执行指令（覆盖 Spring Boot 与 Spring Cloud）

> 本文件由 `/mpdev-understand` 在 Step 3 检测到 Java 项目时加载。按 Prompt 1-6 逐轮执行。
>
> **适用范围**：Spring Boot 单体应用 + Spring Cloud 微服务架构。Prompt 中标注 `[Cloud]` 的小节仅在检测到 Spring Cloud 依赖时执行。

---

## Prompt 1 — 项目骨架

执行以下命令，将分析笔记写入 `.claude-notes/round1.md`。

### 0. 路径兜底（多 module 必读）

先确定本项目是单 module 还是多 module，所有后续命令都要按此走：

```bash
# 检测是否多 module
if grep -q "<modules>" pom.xml 2>/dev/null; then
  ARCH_LAYOUT="multi-module"
  # 收集所有子模块的源码根（每个子模块都有自己的 src/main/java）
  SRC_ROOTS=$(find . -type d -path "*/src/main/java" | grep -v "/target/" | sort)
else
  ARCH_LAYOUT="single-module"
  SRC_ROOTS="src/main/java"
fi
echo "布局：$ARCH_LAYOUT"
echo "源码根：$SRC_ROOTS"
```

**所有 `src/main/java` 路径都需替换**：
- 单 module → 直接用 `src/main/java`
- 多 module → 对 `$SRC_ROOTS` 中的每个根分别执行；或用 `find . -type d -path "*/src/main/java" -exec grep ... {} +` 一次性扫全部
- 配置文件类似：`find . -path "*/src/main/resources/application*.yml"`

### 1. 构建文件：
   - 单 module：直接 cat 根 pom.xml / build.gradle
   - **多 module（聚合工程）**：先 `grep -A20 "<modules>" pom.xml` 看子模块清单；对每个子模块 cat 其 pom.xml
   - 提取：Java 版本、Spring Boot 版本、**Spring Cloud 版本**（`spring-cloud.version` 或 `<spring-cloud.version>`）、**Spring Cloud Alibaba 版本**、所有 starter 依赖（逐个列出并说明用途）、第三方库
   - **架构判定**：依赖中含以下任一 → Spring Cloud；否则 Spring Boot 单体
     - `spring-cloud-starter-*`（gateway/openfeign/loadbalancer/circuitbreaker/sleuth/...）
     - `spring-cloud-starter-alibaba-*`（nacos-discovery/nacos-config/sentinel/seata）
     - `spring-cloud-starter-netflix-*`（eureka/hystrix/zuul，老版本）

2. 配置文件：
   ```bash
   # 单 module + 多 module 通用：用 find 把所有 application*.yml / bootstrap*.yml 收齐
   find . -path "*/src/main/resources/application*.yml" -o -path "*/src/main/resources/application*.properties" -o -path "*/src/main/resources/bootstrap*.yml" 2>/dev/null | head -30
   ```
   逐个 cat 上述命中文件。bootstrap.yml **Spring Cloud 用 bootstrap 在 application 之前加载，配置中心地址在这里**。
   - 提取：数据库类型、Redis 配置、MQ 配置、端口、自定义配置项（业务前缀）
   - **同时记录**每个文件所属的子模块（`{子模块名}/src/main/resources/...`）
   - **重要**：`spring.application.name` 几乎都在 application.yml 顶部 — 这是注册到注册中心的服务名，是 Step 6 微服务清单和 contract-extraction 比对的关键
   - **[Cloud]** 提取：`spring.cloud.nacos.discovery.server-addr` / `spring.cloud.nacos.config.server-addr` / `eureka.client.service-url` / `spring.cloud.gateway.routes` / `feign.client.config.*` / `sentinel.transport.dashboard`

3. 目录结构（只看包名，不读代码）：
   ```bash
   # 单 module
   find src/main/java -type f -name "*.java" | sed 's|/[^/]*\.java$||' | sort -u | head -50

   # 多 module
   find . -type d -name "java" -path "*/src/main/*" | while read d; do
     echo "=== $d ==="
     find "$d" -type f -name "*.java" | sed 's|/[^/]*\.java$||' | sort -u | head -20
   done
   ```
   → 提取：分包方式（controller/service/repository/model/mq/config/...）
   → 如果包路径超过 50 个，只记录前 50 个并标注"已截断"

4. 启动类：
   ```bash
   find . -name "*Application.java" -path "*/src/main/*" | head -10 | xargs cat
   ```
   → 提取注解：
     - **Boot 通用**：`@EnableScheduling` / `@EnableWebSocket` / `@EnableCaching` / `@EnableAsync` / `@EnableTransactionManagement`
     - **[Cloud]**：`@EnableDiscoveryClient` / `@EnableEurekaClient` / `@EnableFeignClients(basePackages=...)` / `@EnableCircuitBreaker` / `@EnableConfigServer`（说明这是 Config Server 本身）

5. 数据库迁移：
   ls src/main/resources/db/migration/ 2>/dev/null | head -20
   → 记录迁移版本数量；多模块时遍历每个子模块

6. **[Cloud] 微服务清单**（仅 Spring Cloud 项目执行）：
   - 子模块名 + **从该子模块的 `application.yml` / `bootstrap.yml` 提取 `spring.application.name`** → 注册到注册中心的服务名
   - 命令示例：
     ```bash
     find . -path "*/src/main/resources/application*.yml" -o -path "*/src/main/resources/bootstrap*.yml" | while read f; do
       name=$(grep -A1 "application:" "$f" 2>/dev/null | grep "name:" | head -1 | awk '{print $2}')
       [ -n "$name" ] && echo "$f → $name"
     done
     ```
   - 标记每个子模块的角色：`gateway`（含 spring-cloud-starter-gateway）/ `business-service`（含 @RestController）/ `config-server`（含 @EnableConfigServer）/ `auth-server` / `common`（无启动类，被其他子模块依赖）

笔记格式：

```
# 第 1 轮：项目骨架
## 架构类型
（Spring Boot 单体 / Spring Cloud 微服务）
## 技术栈
- Java 版本：
- Spring Boot 版本：
- Spring Cloud 版本：（仅 Cloud）
- 构建工具：
## 模块结构（仅多 module）
| 子模块 | 角色 | 端口 | spring.application.name |
|---|---|---|---|
## 核心依赖
（逐个列出，每个一句话说明用途；Cloud 元素如 nacos-discovery / openfeign / gateway / sentinel 单独标注）
## 中间件
- 数据库：
- 缓存：
- 消息队列：
- 注册中心：（仅 Cloud — Nacos/Eureka/Consul + 地址）
- 配置中心：（仅 Cloud — Nacos/Spring Cloud Config + 地址）
- 熔断/限流：（仅 Cloud — Sentinel/Resilience4j/Hystrix）
- 链路追踪：（仅 Cloud — Sleuth/Micrometer Tracing/SkyWalking Agent）
## 目录结构
（列出所有包路径，每个一句话说明）
## 自定义配置项
（列出 application.yml + bootstrap.yml 中所有业务配置项及默认值）
## 存疑项
```

---

## Prompt 2 — 接口边界

先 `cat .claude-notes/round1.md`，然后执行以下分析，写入 `.claude-notes/round2.md`。

A. REST API 全量提取：
   grep -rn "@RestController" src/main/java --include="*.java" -l
   → 对每个 Controller：grep -B1 -A8 "@GetMapping\|@PostMapping\|@PutMapping\|@DeleteMapping\|@RequestMapping" {文件}
   → 提取每个接口的路径、HTTP 方法、方法名、参数类型、返回类型
   fallback：grep -rn "RequestMapping\|@Controller" 或 grep -rn "@Path\|@GET\|@POST"

B. DTO/VO/请求/响应模型：
   find src/main/java -type f \( -path "*/dto/*" -o -path "*/vo/*" -o -path "*/request/*" -o -path "*/response/*" \) -name "*.java" | sort
   → 数量防护：超过 10 个只读前 10 个
   → 提取：类名、字段名+类型、校验注解
   fallback：grep -rn "class.*DTO\|class.*VO\|class.*Request" src/main/java --include="*.java" -l

C. MQ 生产者：
   grep -rn "convertAndSend\|rabbitTemplate\.\|KafkaTemplate\|kafkaTemplate\|StreamBridge\|send(" src/main/java --include="*.java" -B5 -A5
   → 提取：exchange/topic、routingKey、消息体类和字段
   fallback：grep -rn "publish\|produce\|EventPublisher\|\.send(" src/main/java --include="*.java" -l

D. MQ 消费者：
   grep -rn "@RabbitListener\|@RabbitHandler\|@KafkaListener\|@StreamListener" src/main/java --include="*.java" -l
   → 逐个 cat（消费者文件通常不长）
   → 提取：queue/topic 名、消息类型、处理逻辑概要
   fallback：grep -rn "MessageListener\|Consumer\|onMessage\|@EventHandler" src/main/java --include="*.java" -l

E. 数据库实体：
   find src/main/java -path "*/entity/*" -name "*.java" | sort
   → 逐个 cat → 提取：@Table 表名、字段+类型+注解、关联关系
   fallback：find -path "*/model/*" -name "*.java" | grep -v dto | grep -v vo

E2. 共享数据库 SQL（如果存在 contracts/ 子模块）：
   ls contracts/sql/ 2>/dev/null && echo "发现共享 SQL"
   → 如果存在，逐个 cat contracts/sql/*.sql
   → 提取：建表语句中的表名、列名、类型、索引、初始化数据（枚举值等）
   → 与 E 中的 Entity 字段交叉比对：Entity 字段 vs SQL 列定义是否一致
   如果不存在 contracts/ 目录：
   → 读取本模块的迁移脚本：ls src/main/resources/db/migration/*.sql 2>/dev/null | head -20
   → 逐个 cat，提取建表语句

F. Repository 自定义查询：
   find src/main/java -path "*/repository/*" -name "*.java" | sort
   → 只提取非 JPA 默认的方法（@Query 或复杂 findByXxx）

G. WebSocket：
   grep -rn "WebSocket\|STOMP\|SimpMessagingTemplate\|@MessageMapping" src/main/java --include="*.java" -l
   → 如果有，提取推送 channel 和消息格式

H. 外部 HTTP 调用：
   grep -rn "RestTemplate\|WebClient\|HttpClient" src/main/java --include="*.java" -l
   → 有则提取，无则写"无"

I. **[Cloud] Feign 远程调用**：
   ```bash
   grep -rln "@FeignClient" src/main/java --include="*.java"
   ```
   → 逐个 cat，提取：
     - `@FeignClient(name="user-service", path="/api", fallback=...)` — 调用哪个服务
     - 接口中每个 `@GetMapping/@PostMapping` — 远程方法签名
     - 是否有 fallback 类（熔断降级）
   - 这些是**消费的远程 API**，对应另一个微服务暴露的 REST API

J. **[Cloud] Spring Cloud Gateway 路由**：
   ```bash
   # YAML 配置式路由
   grep -A30 "spring.cloud.gateway.routes" src/main/resources/application*.yml
   # Java DSL 路由
   grep -rln "RouteLocator\|RouteLocatorBuilder" src/main/java --include="*.java"
   ```
   → 提取每条路由：id / predicates / filters / uri (lb://service-name)
   → 这是网关层的"虚拟 API"，对外暴露但实际转发到下游服务

K. **[Cloud] 配置中心引用的配置项**：
   ```bash
   # @Value / @ConfigurationProperties 读的配置项（Nacos Config 上往往有同名 key）
   grep -rn '@Value("${' src/main/java --include="*.java" | head -30
   grep -rn "@ConfigurationProperties" src/main/java --include="*.java" -l
   # @RefreshScope（动态刷新的 Bean）
   grep -rn "@RefreshScope" src/main/java --include="*.java" -l
   ```
   → 提取配置项 key 和 @RefreshScope 标记的 Bean（这些是**运行时可热更新**的配置）

笔记格式：

```
# 第 2 轮：接口边界
## REST API（共 x 个）
| 路径 | 方法 | 参数类型 | 返回类型 | 说明 |
|---|---|---|---|---|
## DTO/VO 定义（共 x 个）
### XxxDTO
- fieldA (Type) [必填]
- fieldB (Type) [可选]
## 发布的 MQ 事件（共 x 个）
| Exchange | RoutingKey | 消息体类 | 核心字段 | 触发位置 |
|---|---|---|---|---|
## 消费的 MQ 事件（共 x 个）
| Queue | 来源模块 | 消息体类 | 处理逻辑概要 | 处理类 |
|---|---|---|---|---|
## 数据库表（共 x 张）
### t_xxx
- column (TYPE) PK/NOT NULL
自定义查询：findByXxx
## 数据库 SQL 来源
（contracts/sql/ 或本模块 migration/，标注来源）
## Entity vs SQL 一致性
| Entity 字段(camelCase) | SQL 列(snake_case) | 类型是否一致 | 说明 |
|---|---|---|---|
## WebSocket 推送
| Channel | 消息格式 | 触发时机 |
|---|---|---|
## 外部 HTTP 调用
## [Cloud] Feign 远程调用（共 x 个）
| @FeignClient name | 路径 | 方法 | 参数 | 返回 | fallback |
|---|---|---|---|---|---|
## [Cloud] Gateway 路由（共 x 条）
| route id | predicates | filters | uri (lb://...) | 说明 |
|---|---|---|---|---|
## [Cloud] 配置中心引用项
| key | 来源(application/bootstrap/Nacos) | @RefreshScope | 默认值 |
|---|---|---|---|
## 存疑项
```

---

## Prompt 3 — 核心业务流

先 `cat .claude-notes/round1.md` 和 `cat .claude-notes/round2.md`。

基于第 2 轮的 API 和 MQ 消费者列表，选 3-5 条最核心的业务链路。
选择标准：涉及 MQ 发布/消费的优先，涉及数据库写入的优先，涉及 WebSocket 推送的优先。

大文件防护：Service 文件超过 200 行时，先 `grep -n "public\|private\|protected" {文件}` 看方法列表，用 `sed -n 'Xp,Yp'` 只读目标方法。

对每条链路追踪：
1. 入口（Controller 方法体 或 MQ Consumer 的 onMessage）→ 调了哪个 Service 方法？
2. Service → 做了什么校验？调了哪个 Repository？发了什么 MQ？推了什么 WebSocket？
3. 逐步提取：
   - 参数校验规则（什么条件拒绝？异常码？）
   - 数据库操作（INSERT/UPDATE/SELECT？哪些字段？）
   - 状态变更（字段从什么值变成什么值？）
   - 事务注解（@Transactional 在哪层？readOnly？）
   - 幂等机制（traceId 去重？怎么实现？）
   - MQ 发送时机（事务提交后？@TransactionalEventListener？）
   - 异常降级（MQ 发送失败怎么办？）
   - 隐含业务规则（if/else 背后的业务含义）

笔记写入 `.claude-notes/round3.md`，格式：

```
# 第 3 轮：核心业务流
## 链路 1：（名称）
入口：XxxController.method()
调用链：Controller → Service.method() → Repository.xxx() → Producer.publish()
### 详细步骤
1. （每步做了什么，含业务判断）
### 事务处理
### 幂等处理
### 异常降级
### 隐含业务规则
- 规则1：描述（出处：XxxService.java L45-52）
## 链路 2：...
## 状态机
t_task.status: PENDING → SCHEDULED → RUNNING → COMPLETED
各转换触发条件和触发位置（类.方法 L行号）
## 存疑项
```

---

## Prompt 4 — 基础设施与编码风格

先 `cat .claude-notes/round3.md`，笔记写入 `.claude-notes/round4.md`。

A. 全局异常处理：
   find src/main/java -name "*ExceptionHandler*" -o -name "*GlobalException*" | head -3 → cat
   find src/main/java -name "*Exception.java" -not -name "*Handler*" | sort → cat
   fallback：grep -rn "@ControllerAdvice\|@ExceptionHandler" src/main/java --include="*.java" -l

B. 统一响应包装：
   grep -rn "class Result\|class R<\|class ApiResult\|class Response<" src/main/java --include="*.java" -l → cat

C. 日志风格采样：
   grep -n "log\.\|logger\." {第3轮读过的Service} | head -20
   → 归纳格式模式和级别使用

D. 编码风格采样（从第 3 轮读过的 Service 归纳）：
   - 方法参数：DTO vs 散装？
   - 返回值：entity vs VO？转换方式？
   - 空值处理：Optional vs null check？
   - 集合操作：for vs Stream？
   - 注释习惯：JavaDoc？行内注释？
   - import 风格：通配符 * vs 具体类？
   - 命名约定：getXxx/findXxx/queryXxx？

E. 公共基类：
   find src/main/java -path "*/common/*" -o -path "*/base/*" -o -path "*/util/*" | sort | head -10
   → 选择性 cat，每个写一句话用途

F. 安全认证：
   grep -rn "SecurityConfig\|SecurityFilterChain\|@PreAuthorize\|JWT\|Token" src/main/java --include="*.java" -l | head -5
   → 有则提取，无则写"无"

G. **[Cloud] 熔断/限流/降级**：
   ```bash
   grep -rln "@SentinelResource\|@CircuitBreaker\|@HystrixCommand\|@Retry\|@Bulkhead\|@RateLimiter" src/main/java --include="*.java"
   ```
   → 提取注解所在方法 + 配置（fallback 方法名、阈值规则）
   → 配置规则可能在 application.yml 中：grep -A5 "sentinel\|resilience4j\|hystrix" src/main/resources/application*.yml

H. **[Cloud] 链路追踪与监控**：
   ```bash
   # Sleuth / Micrometer Tracing
   grep -rn "Tracer\|@NewSpan\|@SpanTag\|TraceContext" src/main/java --include="*.java" -l
   # SkyWalking / Pinpoint Agent（通常通过 javaagent 启动参数）
   grep -rn "skywalking\|pinpoint" src/main/resources/ -l
   ```
   → 记录追踪框架；记录是否自定义了 span（业务级追踪）

笔记格式：

```
# 第 4 轮：基础设施与编码风格
## 异常处理
- 全局处理器：
- 自定义异常类：
- 错误码规则：
- 响应格式：
## 统一响应
## 日志规范（从采样归纳）
## 编码风格（从采样归纳，标注依据来源）
- 方法参数风格：（依据：XxxService.java）
- 返回值风格：
- 空值处理：
- 集合操作偏好：
- 注释习惯：
- 命名约定：
## 公共基类
| 类名 | 用途 |
|---|---|
## 安全认证
## 存疑项
```

---

## Prompt 4.5 — 接口完整性校验

先 `cat .claude-notes/round2.md` 回顾已提取的接口列表。
然后用以下策略重新扫描，与 round2 的结果交叉比对。

策略 A — 从配置和声明反向查找：
```bash
# MQ 队列/Exchange 的 @Bean 声明（配置式声明，Prompt 2 的 @RabbitListener 扫不到）
grep -rn "Queue\|Binding\|Exchange" src/main/java --include="*.java" | grep -i "@Bean\|new Queue\|new Binding\|new Exchange"

# 已有的 OpenAPI/Swagger 文件
find . -name "*.yaml" -o -name "*.yml" | xargs grep -l "openapi\|swagger\|paths:" 2>/dev/null

# 编程式路由注册
grep -rn "RouterFunction\|route(\|WebMvcConfigurer" src/main/java --include="*.java"
```

策略 B — 从调用关系反向查找：
```bash
# 所有 MQ 发送（比 Prompt 2 范围更广，覆盖封装类）
grep -rn "rabbitTemplate\|amqpTemplate\|messageSender\|eventBus\|eventPublisher\|EventBus\|\.publish(" src/main/java --include="*.java" -l

# 实现 MessageListener 接口的类（非注解方式的消费者）
grep -rn "implements.*MessageListener\|implements.*Consumer\|implements.*Handler" src/main/java --include="*.java"

# Spring 内部事件（可能代替 MQ 做内部通信）
grep -rn "ApplicationEvent\|@EventListener\|publishEvent" src/main/java --include="*.java"
```

策略 C — 从字符串常量反向查找：
```bash
# 形如 "task.created" 的字符串（可能是硬编码的 topic 名）
grep -rn '"[a-z]*\.[a-z]*\.\?[a-z]*"' src/main/java --include="*.java" | grep -v "import\|package\|http\|jdbc\|log\.\|test"

# 常量类（topic 名通常集中定义在常量类中）
find src/main/java -name "*Constant*" -o -name "*Topics*" -o -name "*Queues*" -o -name "*Events*" | grep ".java$"
# 如果找到，cat 读取
```

策略 D — 已有文档对照：
```bash
find . -name "*.http" -o -name "*.rest" -o -name "postman*" -o -name "*.postman_collection*" | head -5
find docs/ -type f 2>/dev/null | head -10
```

将比对结果追加写入 `.claude-notes/round2.md` 末尾，格式：

```
## 完整性校验补充
### 新发现（round2 遗漏）
| 类型 | 内容 | 发现方式 | 置信度 |
|---|---|---|---|
（如果有新发现逐行填写，没有就写"无新发现"）
### 已有文档对照
（有/无，如有列出差异）
### 需在 Prompt 5 中追加确认的问题
（列出需要向用户定向确认的接口完整性问题）
```

---

## Prompt 5 — 验证与补盲

先读取全部笔记：cat .claude-notes/round{1,2,3,4}.md

1. 读 2 个核心测试文件（只读不跑）：
   find src/test -name "*ServiceTest*" -o -name "*ControllerTest*" | head -4
   → 大文件防护：超 300 行只 grep -n "@Test" 看用例名
   → 提取测试用例名（暴露业务边界条件）

2. git log --oneline -20 → 近期趋势

3. head -100 README.md 2>/dev/null

4. 汇总全部【存疑项】向用户提问。每个问题说明：问题、为什么代码看不出、你的猜测。

5. 接口完整性定向确认（基于 Prompt 4.5 的校验结果）：
   将 round2.md 中已提取的接口完整列表展示给用户，追加以下定向问题：
   - "我发现本模块发布了以下 MQ 事件：[列出]。是否还有遗漏？特别是通过封装类发送的、Spring 内部事件、定时任务触发的？"
   - "我发现本模块暴露了以下 API：[列出]。是否还有遗漏？特别是基类中的通用接口、编程式注册的路由？"
   - "我发现本模块消费了以下 MQ 事件：[列出]。是否还有遗漏？"
   - 如果 Prompt 4.5 发现了新接口，逐个向用户确认是否有效

6. 将分析过程中发现的所有代码问题整理为 TODO 清单，分类输出：

   将 TODO 清单写入 `.claude-notes/todo.md`，格式：
   ```
   # 深度理解发现的待优化项

   ## 🔴 Bug / 潜在风险
   （代码逻辑明确有问题的，如：MQ 在事务内发送无补偿、幂等缺失、异常未处理）
   - [ ] 问题描述（出处：类名.方法名 L行号）

   ## 🟡 设计优化
   （能工作但设计不合理的，如：缺少事务注解、硬编码配置、缺少索引）
   - [ ] 问题描述（出处）

   ## 🟢 规范改进
   （编码风格、命名、注释、测试覆盖等）
   - [ ] 问题描述（出处）

   ## ❓ 待确认
   （不确定是 bug 还是有意设计，需用户判断）
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

必须包含的区块（按此顺序）：
1. 技术栈（标注 Spring Boot 单体 / Spring Cloud 微服务）
2. 目录结构（多 module 列出所有子模块、角色、端口、**`spring.application.name`** — 后两项是 contract-extraction 跨服务比对的关键，**多 module + Cloud 项目必填**）
3. 对外暴露的 REST API（表格，含置信度列）
4. **[Cloud]** Feign 远程调用（消费的下游服务 API；表格含目标服务、路径、方法、fallback）
5. **[Cloud]** Gateway 路由（如本模块是网关；表格含 id/predicates/filters/uri）
6. 发布的 MQ 事件（表格，含置信度列）
7. 消费的 MQ 事件（表格，含置信度列）
8. WebSocket 推送（如有）
9. 数据库核心表（每张表列出字段）
10. 核心业务流（自然语言描述链路 + 隐含规则，标注代码出处；含跨服务调用的远程跳转）
11. 状态机（如果有）
12. ⚠️ 接口字段（列出所有跨模块/跨服务字段名和类型，标注哪些改了必须同步契约仓库）
13. 内部字段（模块内部自由修改的）
14. **[Cloud]** 服务治理（注册中心 + 配置中心 + 熔断/限流策略 + 链路追踪）
15. 编码规范（从第 4 轮采样归纳，标注依据来源）
16. 异常处理机制（错误码规则；Cloud 场景含 Feign 异常解码）
17. 构建与部署（多 module 注明 mvn package -pl 等）
18. 与其他模块的关系（Cloud 项目区分"同进程模块" vs "跨进程服务"）
19. 已知隐含知识

### 文件 2：TODO.md（写入项目根目录）

基于 .claude-notes/todo.md 的内容，结合用户对存疑项的回答，生成最终版 TODO.md：
- 用户确认是 bug 的 → 保留在 🔴 Bug 分类
- 用户说"是有意设计"的 → 从清单中移除
- 用户补充了新信息的 → 更新描述
- 每个 TODO 项保留代码出处（类名.方法名 L行号）

接口置信度标注规则：
- ✅ 高：grep 找到 + 业务链路追踪验证 + 用户确认
- ⚠️ 中：grep 找到但未做链路追踪，或用户未确认
- ❓ 低：仅从字符串常量或配置推测
只有 ✅ 高置信度的接口后续才进入契约仓库。
