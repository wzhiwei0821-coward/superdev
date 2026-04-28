# 微服务集群 测试 flavor

> 适用 Spring Cloud（Nacos/Eureka/Consul）/ Spring Cloud Alibaba / Dubbo / gRPC 微服务、Service Mesh（Istio）等多服务架构。HTTP API 单体请用 `http-api.md` flavor。

## 元数据

```yaml
project_type: 微服务集群
project_type_short: microservices
identification_signals:
  - "存在 docker-compose*.yml 含 5+ services（含 nacos/eureka/consul/zookeeper）"
  - "pom.xml 含 spring-cloud-starter-* 或 spring-cloud-alibaba-*"
  - "存在 Feign 客户端（@FeignClient）或 RPC（@Reference / @DubboReference）"
  - "存在 gateway 模块（spring-cloud-starter-gateway 或 zuul）"
  - "存在 K8s 部署文件（k8s/ 或 charts/）"
default_test_dir: "{module}/src/test/java/ 含 *Test / *IT / *ContractTest"
```

<!-- BLOCK:PROJECT_TYPE_SCOPE -->
- **项目定位**：微服务集群 / Service Mesh / Spring Cloud 体系
- **主要交付**：N 个独立微服务 + 服务发现 + 配置中心 + Gateway + 链路追踪
- **测试焦点**：**服务间契约一致性** / 服务发现注册 / 熔断降级 / 限流 / 分布式事务 / 链路追踪完整性 / 配置热更新 / 灰度发布
- **不做**：基础设施测试（Nacos/Eureka 自身可靠性，由运维保障）、单服务内部业务（每个微服务用 `http-api.md` 独立测）
<!-- /BLOCK:PROJECT_TYPE_SCOPE -->

<!-- BLOCK:TEST_LEVELS -->
| 级别 | 工具 | 占比 | 关注 |
|------|------|------|------|
| **单元测试** | JUnit 5 + Mockito（每个微服务内部） | **50%** | 函数级，mock 所有外部依赖 |
| **集成测试** | `@SpringBootTest` + Testcontainers | **20%** | 单服务 + 真实 DB/Redis（**mock 远程服务**） |
| **契约测试** | **Spring Cloud Contract** 或 **Pact** | **15%** | 消费方 vs 生产方契约一致性 |
| **服务集成测试** | Testcontainers Compose + WireMock | **10%** | 启动多服务联测，mock 极少数下游 |
| **E2E 集群测试** | docker-compose / K8s 测试集群 + Postman/Newman | **5%** | 关键端到端流程（如下单完整链路） |

**契约测试是微服务测试体系的核心**——比 E2E 更早暴露问题，且不需要启动整个集群。
<!-- /BLOCK:TEST_LEVELS -->

<!-- BLOCK:KEY_RISK_AREAS -->
| 风险域 | 关注点 | 必测场景 |
|--------|--------|---------|
| **服务发现** | Nacos/Eureka 注册成功、服务列表更新、心跳失败踢出 | 启动后注册成功；Nacos 重启后服务能否自动重注；故障节点 30s 内被踢出 |
| **Feign / RPC 调用** | 客户端调用、超时、重试、负载均衡 | 下游慢（>3s 默认超时）→ 客户端 Hystrix/Sentinel 熔断；3 个实例随机分配 |
| **熔断降级**（Resilience4j/Sentinel）| 熔断触发条件、降级方法、半开恢复 | 失败率 50% 触发熔断；降级返回兜底数据；30s 后半开试探 |
| **Gateway 路由** | 路径匹配、Header 转发、限流、黑白名单 | `/api/order/**` 路由到 order-service；同 IP 1 分钟 100 次触发限流 |
| **配置中心** | 配置热更新、回滚 | Nacos 改配置 → 服务无需重启即生效；配置错误 → 回滚 |
| **分布式事务** | Seata / TCC / Saga 补偿 | A 扣款成功 + B 加款失败 → A 回滚（最终一致）|
| **链路追踪** | Sleuth / SkyWalking / Zipkin 链路完整 | 一次请求穿 5 个服务，traceId 全程一致 |
| **消息可靠性**（如有 MQ） | 重试、死信、幂等消费 | RabbitMQ 消费失败 3 次进 DLX；同 messageId 不重复处理 |
| **健康检查** | Actuator `/actuator/health` 真实反映状态 | 数据库挂 → health=DOWN，K8s 不路由流量 |
| **优雅停机** | 停机前完成进行中请求 | SIGTERM 后 30s 内不接新请求，处理完老请求再退出 |
<!-- /BLOCK:KEY_RISK_AREAS -->

<!-- BLOCK:AUTOMATION_STACK -->
**Spring Cloud 生态（推荐主用）**：

| 类型 | 工具 |
|------|------|
| 单元/集成 | `JUnit 5` + `Mockito` + `Testcontainers` |
| 契约测试 | **`Spring Cloud Contract`**（Spring 生态首选）或 **`Pact`**（跨语言） |
| Mock 远程服务 | `WireMock`（HTTP）/ `MockServer` |
| 集群联测 | Testcontainers `DockerComposeContainer` 起 nacos+多服务 |
| 链路追踪验证 | Sleuth + Zipkin（验证 trace 完整性）|
| 混沌工程 | `Chaos Monkey for Spring Boot` / Chaos Mesh |

**Dubbo / RPC 生态**：

| 类型 | 工具 |
|------|------|
| 服务测试 | Dubbo 自带 `@DubboReference` mock 机制 |
| 契约 | Pact 跨语言版 |

**通用工具**：
- API 编排测试：Postman 集合 + Newman（CI 跑端到端）
- 性能：JMeter / Gatling / k6
- 数据生成：Faker
<!-- /BLOCK:AUTOMATION_STACK -->

<!-- BLOCK:CI_INTEGRATION -->
**典型 CI Pipeline**（GitLab CI 多 stage）：

```yaml
stages: [unit, contract, integration, e2e]

test:unit:
  stage: unit
  script: mvn test -pl '!gateway' -Dtest='*Test'   # 跳过 gateway，它没单测

test:contract-producer:
  stage: contract
  script:
    - mvn verify -Dtest='*ContractTest'  # 生产方生成契约
    - mvn cloud-contract:publish          # 发布到 Nexus 或 Pact Broker

test:contract-consumer:
  stage: contract
  needs: [test:contract-producer]
  script: mvn verify -Dpact.verifier.publishResults=true

test:integration:
  stage: integration
  services:
    - mysql:8.0
    - nacos/nacos-server:v2.2.3
  script: mvn verify -Dtest='*IT' -Pintegration

test:e2e:
  stage: e2e
  script:
    - docker-compose -f docker-compose.test.yml up -d
    - sleep 60   # 等所有服务就绪
    - newman run e2e-collection.json -e env-staging.json
    - docker-compose down
  artifacts:
    paths: [newman-report.html]
```

**关键约束**：
- 契约测试**必须早于** integration 跑 — 不一致直接 fail，省一次集群启动
- E2E 在 nightly，PR 只跑 smoke 子集（< 5 分钟）
- 服务集成测启动至少 nacos + 2 个相关服务（按调用关系）
<!-- /BLOCK:CI_INTEGRATION -->

<!-- BLOCK:METRICS -->
| 指标 | 阈值 | 工具 |
|------|------|------|
| 单元覆盖率（Line） | ≥ **70%** | JaCoCo |
| 契约一致性 | **100%**（不一致阻断 merge）| Spring Cloud Contract / Pact |
| 服务可用性 | ≥ **99.95%**（生产 SLO）| Prometheus + Grafana |
| Feign 调用 P95 延迟 | < **500ms** | Sleuth + Zipkin |
| 熔断触发延迟 | < **5s**（失败率达阈后） | 自定义指标 |
| 链路完整性 | ≥ **99%**（traceId 全程贯穿） | Zipkin / SkyWalking |
| Gateway 限流准确性 | ±5% | 压测验证 |
| 配置热更新延迟 | < **10s** | Nacos 推送 → 服务生效 |
| 测试代码量 / 业务代码 | 0.6 ~ 0.8 | 行数统计 |
<!-- /BLOCK:METRICS -->

<!-- BLOCK:NON_FUNCTIONAL -->
**契约测试**（核心）：

Spring Cloud Contract 生产方：

```groovy
// contracts/shouldReturnOrder.groovy
Contract.make {
    request {
        method GET()
        url "/api/order/123"
    }
    response {
        status 200
        body([id: 123, status: "PAID", amount: 99.0])
        headers { contentType applicationJson() }
    }
}
```

消费方自动生成 stub，集成测试用 stub 替代真实服务。

**性能基准**（每次 release 跑）：

```bash
# k6 模拟 100 并发持续 1 分钟，关注 P95
k6 run --vus 100 --duration 1m order-flow.k6.js
```

关注：吞吐量、P50/P95/P99 延迟、链路追踪完整性、熔断触发记录。

**混沌工程**（季度演练）：
- 随机杀单实例 → 服务恢复时间
- 网络延迟 +500ms → 链路 SLA
- 数据库不可达 → 降级路径

**安全**：
- 微服务间通信：mTLS（Service Mesh 场景）
- Feign 客户端跨服务带 traceId / userId（链路上下文）
- API Gateway 鉴权：JWT 校验 + 黑名单
<!-- /BLOCK:NON_FUNCTIONAL -->

<!-- BLOCK:SAMPLE_CASES -->
**典型用例**（订单服务调用支付服务场景）：

```markdown
| TC-ID | 标题 | 设计技术 | 优先级 | 期望 |
|-------|------|---------|--------|------|
| TC-001 | order 调 payment 成功（契约） | 等价类(有效) | P0 | 契约一致：req/resp 字段、类型、状态码 |
| TC-002 | payment 慢响应（>3s） | 错误推测 | P0 | order 端 Hystrix/Sentinel 熔断，返回降级数据 |
| TC-003 | payment 服务全挂 | 错误推测 | P0 | order 端熔断打开，30s 后半开试探，恢复后关闭 |
| TC-004 | Nacos 重启 | 错误推测 | P1 | 服务自动重注册，调用恢复 |
| TC-005 | 配置 dynamic.config.x 改值 | 等价类(有效) | P0 | 服务无需重启，新值 10s 内生效 |
| TC-006 | Gateway 限流（100/min IP） | 边界值 | P1 | 第 101 次请求返回 429 |
| TC-007 | 分布式事务部分失败回滚 | 错误推测 | P0 | A 扣款 + B 加款，B 失败 → A 自动回滚 |
| TC-008 | 链路 traceId 跨服务 | 集成 | P0 | 一次请求穿 4 个服务，logs 中 traceId 全程一致 |
```

**Spring Cloud Contract 测试代码**（消费方）：

```java
@SpringBootTest
@AutoConfigureStubRunner(
    ids = "com.example:payment-service:+:stubs:8080",
    stubsMode = StubRunnerProperties.StubsMode.LOCAL
)
class OrderServiceContractTest {

    @Autowired PaymentClient paymentClient;

    // TC-001
    @Test
    void getPayment_returnsContractCompliantResponse() {
        Payment p = paymentClient.findById(123L);
        assertThat(p.getId()).isEqualTo(123L);
        assertThat(p.getStatus()).isEqualTo("PAID");
        assertThat(p.getAmount()).isEqualByComparingTo("99.0");
    }
}
```

**熔断测试代码**（用 WireMock 模拟下游慢）：

```java
@Test
void paymentSlow_triggersFallback() throws Exception {
    wireMock.stubFor(get(urlPathEqualTo("/api/payment/123"))
        .willReturn(aResponse().withFixedDelay(5000)));  // 模拟慢响应

    // Sentinel 设置 RT > 1s 触发熔断
    Order order = orderService.placeOrder(123L, BigDecimal.valueOf(99));
    assertThat(order.getStatus()).isEqualTo("PENDING_FALLBACK");  // 降级
    assertThat(circuitBreaker.getState()).isEqualTo(CircuitBreaker.State.OPEN);
}
```
<!-- /BLOCK:SAMPLE_CASES -->

<!-- BLOCK:DIALECT_CONSTRAINTS -->
8. **契约测试是 P0** — 服务间接口必须有契约测试，覆盖率不达 100% 阻断 merge
9. **集成测必须用 Testcontainers**，不要全 mock；至少包含 nacos + 调用关系上的 1 层下游
10. **服务集成测必带链路追踪验证** — 验证 traceId 全程一致
11. **熔断/降级方法必有用例** — 不允许"下游挂了不知道怎么办"的代码
12. **配置热更新必测** — 涉及业务配置的字段（限流阈值、特性开关）改值后立即生效
13. **K8s 探针测试** — readiness/liveness probe 在 DB 不可达时正确返回 DOWN
14. **优雅停机必测** — 在 mvn 进程发 SIGTERM 验证 30s 内完成进行中请求
15. **每季度做一次混沌演练** — 杀实例、网络抖动、DB 不可达，记录恢复时间
<!-- /BLOCK:DIALECT_CONSTRAINTS -->
