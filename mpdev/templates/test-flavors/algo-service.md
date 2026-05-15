# 算法服务 测试 flavor

> 适用 CV（YOLO / PaddleOCR / OpenCV）/ NLP（BERT / LLM 推理）/ 推荐 / 风控 等 ML 推理服务。模型训练流程不在范围。

## 元数据

```yaml
project_type: 算法/ML 推理服务
project_type_short: algo-service
identification_signals:
  - "requirements.txt 含 torch / tensorflow / paddlepaddle / onnxruntime / transformers"
  - "模型文件存在：*.pt / *.onnx / *.pb / *.pdmodel / *.bin"
  - "存在 weights/ models/ checkpoints/ 目录"
  - "依赖 opencv-python / pillow / numpy（CV 项目）或 jieba / sentencepiece（NLP）"
  - "存在 GPU 相关配置（CUDA / cudnn / device:cuda）"
default_test_dir: "tests/ + tests/data/ 含 test fixtures（图片、JSON、文本）"
```

<!-- BLOCK:PROJECT_TYPE_SCOPE -->
- **项目定位**：ML 模型推理服务（CV / NLP / 推荐 / 风控 / 多模态）
- **主要交付**：模型加载、预处理、推理、后处理、HTTP/gRPC 接口
- **测试焦点**：**模型准确率回归** / 推理延迟 / 显存峰值 / 输入鲁棒性 / 模型版本切换 / GPU/CPU 一致性 / 批处理 / 异常输入处理
- **不做**：模型训练效果（独立 ML 团队负责）、模型本身的 SOTA 验证（信任原始 paper/repo）、端到端业务正确性（由 http-api flavor 覆盖）
<!-- /BLOCK:PROJECT_TYPE_SCOPE -->

<!-- BLOCK:TEST_LEVELS -->
| 级别 | 工具 | 占比 | 关注 |
|------|------|------|------|
| **单元测试** | pytest + mock | **40%** | 预处理 / 后处理函数（图像 resize / NMS / token 编解码）|
| **模型推理测试** | pytest + 固定测试集 | **30%** | 已知输入 → 期望输出（黄金集对比）|
| **准确率回归** | pytest + 标注数据集 | **15%** | precision/recall/F1/mAP 指标不退化 |
| **API 集成测试** | httpx + 真实模型 | **10%** | HTTP 接口 + 模型端到端 |
| **性能基准** | locust / k6 / 自定义脚本 | **5%** | 延迟 P99 / 吞吐 / 显存 |

**算法服务测试金字塔**：和 Web 不同——准确率回归权重大（不是 E2E）。
<!-- /BLOCK:TEST_LEVELS -->

<!-- BLOCK:KEY_RISK_AREAS -->
| 风险域 | 关注点 | 必测场景 |
|--------|--------|---------|
| **准确率退化** | 模型升级 / 重训后效果是否退步 | 在固定标注集上跑，对比上版 mAP/F1，差异 > 1% 报警 |
| **输入鲁棒性** | 异常图片 / 噪声 / 格式 | 损坏 JPEG / 1px 图 / 超大图（10K×10K）/ 灰度图 / 透明 PNG / 非 UTF-8 文本 |
| **预处理一致性** | 训练/推理 transform 是否一致 | mean/std 归一化、resize 算法、padding 策略一致 |
| **GPU/CPU 一致性** | 同输入 GPU vs CPU 输出是否一致 | 容差 1e-4 内（float16）/ 1e-6 内（float32）|
| **显存** | 长时间推理 / 大 batch 显存泄漏 | 跑 10K 次推理后显存增长 < 10% |
| **推理延迟** | P50 / P95 / P99 | 不同输入大小下延迟稳定（不是 batch 1 快、batch 32 暴增）|
| **模型版本切换** | 热更新 / 回滚 | 新模型加载失败 → 自动回退到旧版 |
| **批处理 vs 单条** | 同输入两种模式输出一致 | batch=1 单条 vs batch=8 第 1 条结果一致 |
| **边界输入** | 空输入 / 全黑图 / 重复字符 | 不崩溃；返回明确错误码或合理默认 |
| **多模型协同**（如 OCR + 后处理） | 上下游兼容 | upstream 输出格式变 → downstream 是否兼容 |
<!-- /BLOCK:KEY_RISK_AREAS -->

<!-- BLOCK:AUTOMATION_STACK -->
**Python 通用**：

| 类型 | 工具 |
|------|------|
| 单元 | `pytest` + `pytest-mock` |
| 准确率 | `sklearn.metrics`（分类 P/R/F1）/ `pycocotools`（检测 mAP）/ `seqeval`（序列）|
| 性能 | `locust` / `pytest-benchmark` |
| 显存监控 | `nvidia-smi` 命令行 / `pynvml` 编程接口 / `torch.cuda.memory_*` |
| Mock 模型 | `unittest.mock`（小测试中跳过真模型加载）|
| 数据 fixture | 固定测试集 + DVC（Data Version Control）追踪 |

**框架特定**：

- **PyTorch**: `torch.testing.assert_close`（容差比较）/ `torch.no_grad()` 推理上下文
- **TensorFlow**: `tf.test.TestCase` / `tf.debugging.assert_*`
- **PaddlePaddle**: `paddle.no_grad()` / `paddle.utils.unique_name`
- **ONNX**: `onnxruntime` 多 backend 一致性测试
- **TensorRT / OpenVINO**: 量化前后精度对比

**模型监控**：MLflow / Weights & Biases / TensorBoard（追踪准确率历史）。
<!-- /BLOCK:AUTOMATION_STACK -->

<!-- BLOCK:CI_INTEGRATION -->
**关键挑战**：CI 通常没 GPU。处理策略：

```yaml
test:cpu-unit:
  stage: test
  image: python:3.10
  script:
    - pip install -r requirements-test.txt
    - pytest tests/unit -v --cov

test:cpu-inference:
  stage: test
  image: python:3.10
  script:
    - pip install torch onnxruntime  # CPU 版
    - pytest tests/inference --device=cpu

test:gpu-regression:
  stage: nightly
  tags: [gpu]   # 自托管 GPU runner
  image: nvidia/cuda:12.1.0-runtime-ubuntu22.04
  script:
    - pip install -r requirements.txt
    - pytest tests/accuracy --device=cuda --golden-set=tests/data/coco-val-mini
    - python scripts/check_metrics.py  # 对比基线
```

**关键约束**：
- CI 默认跑 CPU 测试（fast）
- GPU 准确率回归走 nightly（慢，专用 runner）
- 模型文件 > 100MB 用 Git LFS / S3 / OSS（不进 git）
- 每次 release 必跑全准确率回归
<!-- /BLOCK:CI_INTEGRATION -->

<!-- BLOCK:METRICS -->
| 指标 | 阈值（建议）| 工具 |
|------|------------|------|
| 单元覆盖率（Line）| ≥ **70%** | pytest-cov |
| 准确率退化阈值 | ≤ **1%** vs 基线（mAP/F1）| 自定义对比脚本 |
| 推理延迟 P99 | < **500ms**（业务定，CV 检测一般 < 200ms）| pytest-benchmark / locust |
| 推理吞吐（batch=8）| ≥ 业务 SLO | 同上 |
| 显存峰值 | < **GPU 显存 80%**（留余量） | nvidia-smi / torch.cuda |
| 显存泄漏率 | 10K 次推理后增长 < **10%** | 长时压测 |
| GPU/CPU 输出一致性 | 容差内 100% 一致 | torch.testing.assert_close(rtol=1e-4) |
| 异常输入崩溃率 | **0**（全部捕获）| 单元测 + fuzzing |
| 模型加载时间 | < **5s**（冷启动）| 性能日志 |
| 准确率监控覆盖率 | 业务核心场景 100% 有标注 | 标注集 vs 业务流量分布 |
<!-- /BLOCK:METRICS -->

<!-- BLOCK:NON_FUNCTIONAL -->
**准确率回归**（核心）：

```python
# tests/accuracy/test_yolo_regression.py
import pytest
from pycocotools.coco import COCO
from pycocotools.cocoeval import COCOeval

GOLDEN_MAP = 0.847  # v1.2 基线

def test_yolo_accuracy_no_regression(model, coco_val_mini):
    results = []
    for img_id in coco_val_mini.imgs:
        img = coco_val_mini.load_img(img_id)
        preds = model(img)
        results.extend(preds)

    coco_eval = COCOeval(coco_val_mini, results, 'bbox')
    coco_eval.evaluate(); coco_eval.accumulate(); coco_eval.summarize()
    map_50_95 = coco_eval.stats[0]

    # 退化超过 1% 失败
    assert map_50_95 >= GOLDEN_MAP - 0.01, \
        f"mAP 退化: {map_50_95:.3f} < {GOLDEN_MAP:.3f} - 0.01"
```

**性能基准**：

```python
# tests/perf/test_inference_latency.py
import pytest
import torch

@pytest.mark.benchmark
def test_inference_p99_under_200ms(model, benchmark, sample_images):
    # 跑 100 次取 P99
    benchmark.pedantic(
        lambda: model(sample_images),
        rounds=100, iterations=1
    )
    p99 = benchmark.stats['stats']['max']
    assert p99 < 0.2, f"P99 延迟 {p99*1000:.1f}ms > 200ms"
```

**输入鲁棒性**（重要 + 经常被忽视）：

```python
@pytest.mark.parametrize("img_path", [
    "tests/data/corrupted.jpg",     # 损坏文件
    "tests/data/1x1.png",           # 极小
    "tests/data/10000x10000.jpg",   # 极大
    "tests/data/grayscale.png",     # 灰度
    "tests/data/transparent.png",   # 透明 alpha 通道
])
def test_robust_to_edge_inputs(model, img_path):
    try:
        result = model.predict(img_path)
        assert result is not None  # 不抛异常
    except ModelInputError as e:
        assert e.code in KNOWN_ERROR_CODES  # 已知错误码
```

**安全**（模型相关）：
- **对抗样本**：FGSM / PGD 简单攻击下不全错（鲁棒性）
- **数据投毒**：训练数据来源审计
- **模型水印 / 提取攻击**：API 限流防止模型被偷
- **隐私**：人脸 / 身份证 / 医疗影像，本地化部署 + 不留日志
<!-- /BLOCK:NON_FUNCTIONAL -->

<!-- BLOCK:SAMPLE_CASES -->
**典型用例**（YOLO 目标检测服务为例）：

```markdown
| TC-ID | 标题 | 设计技术 | 优先级 | 期望 |
|-------|------|---------|--------|------|
| TC-001 | 标准图片检测（COCO 样本） | 等价类(有效) | P0 | 检测出≥1 个目标，置信度 > 0.5 |
| TC-002 | 损坏 JPEG | 错误推测 | P0 | 返回 400 + 明确错误"图片解码失败"，不崩溃 |
| TC-003 | 1×1 极小图 | 边界值 | P1 | 返回空检测列表（合理）或 400 |
| TC-004 | 10000×10000 极大图 | 边界值 | P1 | 自动缩放到模型输入尺寸，返回结果 |
| TC-005 | 灰度图（1 通道）| 等价类(无效) | P0 | 自动转 3 通道处理或明确报错 |
| TC-006 | batch=1 vs batch=8 输出一致性 | 一致性 | P0 | 同图片在两种模式下结果一致（容差 1e-4）|
| TC-007 | GPU vs CPU 输出一致性 | 一致性 | P0 | 同图片跨设备容差内一致 |
| TC-008 | 在 COCO val mini 上跑 mAP | 准确率回归 | P0 | mAP@50:95 ≥ 上版 - 0.01 |
| TC-009 | 推理 P99 延迟 | 性能 | P0 | < 200ms（416×416 输入）|
| TC-010 | 10K 次推理后显存增长 | 性能 | P1 | < 10% 增长 |
| TC-011 | 模型热更新（v1 → v2） | 状态转换 | P0 | 加载新模型成功，未结束的 v1 请求继续完成 |
| TC-012 | 加载损坏模型文件 | 错误推测 | P0 | 服务启动失败 + 明确错误，不带错误模型上线 |
```

**pytest 推理一致性测试**：

```python
import pytest
import torch
from PIL import Image

@pytest.fixture(params=['cpu', 'cuda'])
def model(request):
    m = load_yolo_v8()
    return m.to(request.param)

def test_inference_consistent_across_devices(sample_image_416):
    cpu_model = load_yolo_v8().to('cpu')
    gpu_model = load_yolo_v8().to('cuda')

    cpu_out = cpu_model(sample_image_416)
    gpu_out = gpu_model(sample_image_416).cpu()

    torch.testing.assert_close(cpu_out, gpu_out, rtol=1e-4, atol=1e-4)
```

**HTTP API 测试**（FastAPI 算法服务）：

```python
def test_detect_corrupted_image_returns_400(client):
    with open("tests/data/corrupted.jpg", "rb") as f:
        r = client.post("/api/detect", files={"image": f})
    assert r.status_code == 400
    assert r.json()["code"] == "IMAGE_DECODE_ERROR"
```
<!-- /BLOCK:SAMPLE_CASES -->

<!-- BLOCK:DIALECT_CONSTRAINTS -->
8. **准确率回归 P0** — 每次模型更新必跑标注集，退化 > 1% 阻断 release
9. **黄金测试集版本化** — 测试集本身要 DVC / Git LFS 追踪，避免"测试集偷偷变了导致基线漂移"
10. **GPU 测试走 nightly** — CI 默认 CPU；准确率回归在 self-hosted GPU runner 跑
11. **模型文件不进 git** — 用 LFS 或对象存储，提供 download script
12. **预处理 train/serve 一致性** — 训练用 transform 必须和 serve 端一致（mean/std/resize 顺序）
13. **显存监控全程** — 每个测试用例前后 record GPU memory，泄漏 > 10% 报警
14. **异常输入零崩溃** — 单元测 + fuzzing 必有，损坏文件 / 极端尺寸全覆盖
15. **模型回滚演练** — 每季度演练一次：模拟新模型加载失败，验证自动回退到旧版
<!-- /BLOCK:DIALECT_CONSTRAINTS -->
