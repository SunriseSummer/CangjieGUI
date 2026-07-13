# 性能基准（bench）

CUI 的性能测试统一在此目录。基准分两档口径，可复用的工具与场景各自沉淀为独立包，并配跨平台的一键脚本
汇总为 HTML 报告。

## 一键运行

脚本用 Python 实现（跨平台，需 Python 3）：

```
python bench/run.py                 # 构建并运行无头基准，生成 bench/results/report.html
python bench/run.py --open          # 生成后在浏览器打开
python bench/run.py --no-run        # 复用上次采集的数据，仅重新生成报告
python bench/run.py --display        # 额外运行端到端基准（自终止、短暂开窗），并入真实帧率
python bench/run.py --save-baseline  # 将当前每帧成本记为回归基线
python bench/run.py --check          # 若有用例较基线退化超过阈值则以非零码退出
```

报告将每帧成本对照业界交互帧预算（120 / 60 / 30 fps）着色排布，自动归纳短板与长板，并给出文本度量
诊断。原始日志与报告落在 `bench/results/`（该目录已被 gitignore）。

## 目录结构

- `harness/`：可复用基准工具库（`bench_harness`，依赖 sdl）。计时循环 `timeit`、机器可读输出 `report`
  与 `reportCount`、滚动偏移发生器 `ScrollSweep`、帧率计 `FpsMeter`。
- `scenes/`：可复用场景与数据构建库（`bench_scenes`，依赖 cui）。确定性数据生成器、组合内容页
  `contentScrollScene`（无头与上机共用同一棵树），以及自终止驱动 `BenchDriver` / `BenchAccumulator`。
- `micro/`：无头基准可执行程序（`bench_micro`）。逐用例打印并输出 `@@RESULT` / `@@COUNT` 行供报告解析。
  覆盖字符串、派生状态、表格排序（含边界）、长列表、文本区域、深层布局、控件密集表单、内容页滚动，以及
  每帧文本度量次数诊断。
- `planner_scroll/`：端到端应用（需显示）。复刻规划台右栏组合内容页，自动上下滚动，跑满固定帧数后自动
  退出并打印真实帧率。
- `large_table/`：端到端应用（需显示）。大数据量表格窗口化绘制，同样自终止计时。
- `run.py`、`report.template.html`：一键脚本与报告模板。中文文案集中于模板，脚本负责数据与渲染。

## 两档口径

无头（`micro`）与端到端（`planner_scroll` / `large_table`）测的是不同的东西，互为补充：

- 无头口径：以 `Renderer.headless()` 驱动真实的 build / layout / draw，几何、事件与字符串照常执行，但渲染
  为空操作、文本按估算宽度计。故它准确反映布局遍历与 CPU 侧每帧成本，但不含 GPU 光栅，也不含 SDL_ttf
  的真实文本度量耗时。计时用 `PerformanceClock.ticksNanoseconds`，无需建窗。
- 端到端口径：真实窗口逐帧重建控件树，每个 Label 经 SDL_ttf 实测、可见文本被光栅化，给出用户实际体感的
  帧率。以 `frameDelay = 0` 运行，故平均帧耗时即真实每帧工作量（发布应用会再额外睡眠约 16ms/帧）。端到端
  基准自终止：跑满固定帧数后自动关窗，无需人工读表。注意在无显示或窗口被遮挡的环境下（例如 CI 或后台
  会话），系统可能跳过 GPU 与文本光栅，实测值会失真，故端到端帧率应在交互式显示环境采集。

## 文本度量诊断

每帧文本度量次数（`@@COUNT`）是定位文本瓶颈而无需开窗的关键指标：一棵树每帧发起多少次文本度量，与是否
上机无关；乘以单次 SDL_ttf 成本即该帧的文本预算。未窗口化的组合内容页每帧上千次度量（约 2400 次），是
规划台右栏滚动帧率偏低的主因；窗口化的表格与列表只度量可见行，故低一到两个数量级。诊断由 `Renderer` 的
`textMeasureCount` / `resetTextMeasureCount` 探针采集。

## 基线与回归守护

交互式界面以帧预算为准：60fps 对应 16.67ms/帧，120fps 对应 8.33ms/帧，30fps 对应 33.33ms/帧。报告据此评级
并显示预算占用条。`--save-baseline` 将当前各用例每帧成本写入 `bench/baseline.json`；`--check` 重新运行并与
基线比对，任一用例退化超过阈值即以非零码退出，可接入 CI 看护整体性能质量。基线随机器而异，跨机对比需重
新采集。

## 运行时特征备忘

`String` 逐字节下标（带越界检查）开销显著，标准库批量字符串操作通常更优（见 `micro` 中 split 与手写字节
扫描的对照）。故字符串与文本路径的优化必须实测，勿凭“减少分配”的直觉。

## 新增基准

- 无头用例：在 `micro/src/` 加一个 `*.cj`，用 `bench_harness` 的 `timeit(name, iterations, body)`（`body`
  返回 `Int64` 校验值以防被优化掉）配合 `report(kind, group, result)` 输出；`kind` 取 `frame`（每帧成本，
  对照帧预算）或 `micro`（局部操作，看吞吐）。需完整控件树时用 `bench_scenes` 的场景并以 `headlessContext()`
  驱动，再在 `main.cj` 中调用。
- 端到端应用：仿 `planner_scroll/` 或 `large_table/` 新建可执行包，用 `BenchAccumulator` 一次性创建、
  `BenchDriver` 作为同级节点逐帧转发，即可自终止并打印真实帧率。共用 `bench_scenes` 的场景可与无头用例同
  口径对照。
