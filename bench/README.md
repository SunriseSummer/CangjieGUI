# 性能基准（bench）

CUI 的性能测试统一在此目录，按“日常无头回归、真实窗口端到端、增量架构压力”三层组织。可复用工具与
场景各自沉淀为独立包，并输出 HTML、JSON 和架构证据报告。

## 一键运行

脚本用 Python 实现（跨平台，需 Python 3）：

```
python bench/run.py                 # 构建并运行无头基准，生成 bench/results/report.html
python bench/run.py --open          # 生成后在浏览器打开
python bench/run.py --no-run        # 复用上次采集的数据，仅重新生成报告
python bench/run.py --display        # 额外运行端到端基准（自终止、短暂开窗），并入真实帧率
python bench/run.py --display --save-baseline  # 保存完整且带环境/源码指纹的基线
python bench/run.py --check          # 稳定 AC 环境下裁决；电池环境只给观测结论（见下）
python bench/run.py --samples 5      # 独立采样 5 次，保留中位数、MAD 与全距
python bench/run_test.py             # 自测 --check 门禁逻辑（合成数据，不跑基准）
python bench/compare.py --a old.txt --b new.txt  # 两组原始采集直接 A/B（默认同侧取中位数）
python bench/compare_test.py          # 自测 A/B 解析、聚合和不对称用例报告
python bench/phase3_probe.py          # 运行局部更新/状态生命周期架构压力与演进回归实验（默认 3 样本）
python bench/phase3_probe_test.py     # 自测压力实验的记录解析、聚合和证据判定
python bench/run_all.py --display --samples 5   # Python/驱动自测 + 三层套件完整执行
python bench/run_all.py --display --samples 5 --save-baseline  # 评审结果后刷新完整基线
```

报告将每帧成本对照业界交互帧预算（120 / 60 / 30 fps）着色排布，自动归纳短板与长板，并给出文本度量
诊断。显示基准同时保留 P50/P90/P95/P99、最大值及三个帧预算的超限帧数，报告按 P95 评级；`report.json`
在 `frameDistributions` 中保存完整分布，在 `hostEnvironment` / `displayEnvironments` 中保存主机、AC/电池、
Windows 基础方案与性能 overlay、GPU/驱动/刷新率、实际 SDL 驱动、超采样与 vsync 环境；`source` 同时保存
CangjieGUI/CangjieSDL 的 commit、dirty 状态和性能相关源码 SHA-256 指纹。`sampleStability` 保留每个独立样本、
中位数、MAD 与全距，`pairedComparisons` 保留同进程 A/B 比率。`check.json` 保存独立门禁结果而不覆盖前者，`suite.json` 保存全套
命令及退出状态；原始日志与报告都落在
`bench/results/`（该目录已被 gitignore）。

`--check` 和 `--save-baseline` 默认各运行 5 个独立样本，并对每个用例取中位数，以降低 GC、操作系统调度和
混合性能核迁移造成的偶发偏差；普通报告仍只采 1 次。显示用例按轮次确定性轮转，使每个场景分别经历套件的
早/中/晚位置，功耗或温度漂移会进入该场景自己的样本分布。单次尖峰由中位数/MAD 稳健排除；MAD 超过 10%
返回 `inconclusive`，不生成回归结论。可用 `--samples N` 显式调整样本数。`--no-run` 只用于重绘最近报告，
不能与 `--check`/`--save-baseline` 组合。每个样本必须给出完全一致的用例与诊断键，否则工具会失败。
`--check` 还严格要求本次出现的每个 frame/display 用例都在基线中；新增场景未审阅、未录基线时返回设置错误，
不会以“没有可比记录”为由悄悄放行。
刷新基线与判定回归是两个独立动作，`--save-baseline` 与 `--check` 不可同时使用；保存基线必须带 `--display`
并至少有 3 个样本。交流电硬门禁基线会拒绝任一物质案例或配对比率 MAD 超限；电池采集允许带明确噪声警告
保存为 observational baseline，以保留完整覆盖和趋势数据，但不能成为硬门禁。`baseline.json` 保存数值，
`baseline.meta.json` 保存 `verdictMode`、源码、环境、后端、样本稳定性与同进程 A/B 来源；缺少元数据的历史基线
不参与裁决。
电池供电下即使选择“最佳性能”，固件仍可能随电量、温度和平台功耗限制动态调频，因此采集、预算评级和
同进程 A/B 仍照常执行，但 `--check` 只返回 observational/inconclusive（退出码 3），不产生硬 PASS/FAIL。
硬回归门禁应接交流电并保持相同 power overlay。若基线与本次两个仓库的源码指纹完全相同却出现候选退化，
工具会把它归类为会话可复现性漂移而非代码回归。`run_all.py` 遇到日常套件回归或不可判定时仍继续执行独立的
架构压力套件，确保一次完整运行不丢失后续证据；工具自测/场景契约自身失败时才提前停止。
子进程输出以原始字节捕获：严格 UTF-8 解码失败时才回退到平台首选代码页。这样 Windows 仓颉工具链的
cp936 中文场景名不会被替换字符污染；报告、基线和 JSON 始终写成 UTF-8。

## 目录结构

- `harness/`：可复用基准工具库（`bench_harness`，依赖 sdl）。计时循环 `timeit`、机器可读输出 `report`、
  `reportCount`、`reportFrameDistribution` 与 `reportBenchmarkEnvironment`、最近秩帧分布统计、滚动偏移发生器
  `ScrollSweep`。
- `scenes/`：可复用场景与数据构建库（`bench_scenes`，依赖 cui）。确定性数据生成器、组合内容页
  `contentScrollScene`（无头与上机共用同一棵树），以及自终止驱动 `BenchDriver` / `BenchAccumulator`。
- `micro/`：无头基准可执行程序（`bench_micro`）。逐用例打印并输出 `@@RESULT` / `@@COUNT` 行供报告解析。
  覆盖字符串、派生状态、表格排序（含边界）、长列表、文本区域、深层布局、控件密集表单、内容页滚动，以及
  每帧文本度量次数诊断；增量运行时部分另看护 retained 命中、状态写事务合并、显式 Frame 订阅表和
  lifecycle effect 稳定/替换成本。自动运行时用普通 UI 代码对照增量/强制全量：240 分支单点更新看护
  脏 body 为 1/240；稳定绘制看护自动显示列表使 widget draw 访问为 0；复杂兄弟更新看护自动晋升边界
  使稳定子树 layout 访问为 0。惰性视口用例直接对比 10000 行 legacy 每帧高度扫描与 revision 缓存，
  并看护 100000 行 `LazyListExtents` 单点更新+完整 headless 帧。
- `phase3/`、`phase3_probe.py`：与普通回归基线隔离的架构决策及演进回归实验。对大而密 UI 的单区域高频更新做
  full-tree/manual-retained/auto-retained/command/damage 同进程 A/B，记录 build/layout/event/draw 的耗时与
  访问数；另测 retained 命中时后代状态/effect 生命周期簿记的规模曲线，并验证漏写 revision 与 dynamic paint
  安全旁路。结果写入
  `bench/results/phase3.{md,json}`，不修改 `baseline.json`。目录名保留阶段性实验的历史来源，报告语义已是
  长期的“增量架构压力套件”。
- `planner_scroll/`：端到端应用（需显示）。复刻规划台右栏组合内容页，自动上下滚动，跑满固定帧数后自动
  退出并打印真实帧率；完整套件在同一进程依次采 `ss2` 和 `ss1`，避免新进程落在不同核心/功耗状态，
  两者比率单独进入配对门禁。
- `controls_form/`：端到端密集控件表单，覆盖几何、阴影、交互控件与滚动组合成本；完整套件同时采
  全量 `ScrollView` 和惰性视口的 12/24/40 分区规模曲线，直接看护窗口化收益及随总量近似平坦的成本。
- `large_table/`：端到端应用（需显示）。完整套件在同一进程依次运行 500/5000 行窗口化表格；绝对耗时看真实
  帧成本，5000/500 比率看护总数据量增长时可见行成本保持近似平坦。
- `incremental_dashboard/`：96 区域真实渲染 A/B，同场景比较强制全量、命令全场重放和单区域 damage。
- `text_layout/`：真实 SDL_ttf 的 20000 字段落稳定缓存与 96 个真正唯一文本的 LRU 冷抖动；两者同进程运行，
  专门看护有界 shaping window、P95、热/冷比率和 4 MiB 段落缓存淘汰行为。
- `primitive_batch/`：2048 个相同矩形逐条提交与相邻同色命令批处理的同像素 A/B，隔离驱动调用摊销；不跨 clip/文本/纹理或颜色重排。
- `run.py`、`run_all.py`、`compare.py`、`report.template.html`：日常采集、全套编排、A/B 与报告工具。

## 三层口径

三层测的是不同问题，不能混用绝对数：

- 无头口径：以 `Renderer.headless()` 驱动真实的 build / layout / draw，几何、事件与字符串照常执行，但渲染
  为空操作、文本按估算宽度计。故它准确反映布局遍历与 CPU 侧每帧成本，但不含 GPU 光栅，也不含 SDL_ttf
  的真实文本度量耗时。计时用 `PerformanceClock.ticksNanoseconds`，无需建窗。
- 端到端口径：真实窗口逐帧更新控件树，每个 Label 经 SDL_ttf 实测、可见文本被光栅化，给出用户实际体感的
  帧率。以 `frameDelay = 0` 运行，故平均帧耗时即真实每帧工作量（发布应用会再额外睡眠约 16ms/帧）。端到端
  基准自终止：跑满固定帧数后自动关窗，无需人工读表。`@@RESULT` 保留兼容的均值，`@@FRAME_DIST` 记录
  单次运行的 P50/P90/P95/P99、最大值和 120/60/30fps 超预算计数；`@@BENCH_ENV` 记录实际驱动、超采样与
  vsync；多次采样逐字段取中位数，并要求环境字段完全相同。注意在无显示或窗口被遮挡的环境下（例如 CI 或后台
  会话），系统可能跳过 GPU 与文本光栅，实测值会失真，故端到端帧率应在交互式显示环境采集。
- 架构压力口径：固定复杂 UI 拓扑，分阶段记录访问数、命令数/估算字节和规模曲线。同进程变体比例与确定性
  访问数是主证据；它不进入跨提交 fleet 基线，避免把结构性实验的阈值误当作普适 SLA。

## 与 `.devtools` 的边界

- `bench/`：定义工作负载、计时区间、采样聚合、性能基线、A/B、预算评级和架构规模证据。
- `.devtools/`：验证结果是否正确，包括示例 E2E、快照像素、包隔离、真实窗口生命周期、文档链接与超时归因。
- E2E 工具即使记录耗时，也只用来定位卡在哪一步，不据此宣称性能回归；性能脚本即使带确定性断言，也只用
  断言保障测到的是预期路径。两边可共享 `.devtools/process_runner.py` 的安全进程树基础设施，但不共享场景语义。

## 文本度量诊断

每帧文本度量次数（`@@COUNT`）是定位文本瓶颈而无需开窗的关键指标：一棵树每帧发起多少次文本度量，与是否
上机无关；乘以单次 SDL_ttf 成本即该帧的文本预算。未窗口化的组合内容页每帧上千次度量（约 2400 次），是
规划台右栏滚动帧率偏低的主因；窗口化的表格与列表只度量可见行，故低一到两个数量级。诊断由 `Renderer` 的
`textMeasureCount` / `resetTextMeasureCount` 探针采集。

长文必须区分冷布局与热缓存：`micro` 同时输出 `长文换行（冷）` 与 `长文换行`，并记录段落缓存命中/未命中；
端到端 `text_layout` 再用真实 SDL_ttf 验证。原先把整段余串传给 `TTF_MeasureString` 会产生秒级尖峰，当前以
UTF-8 边界对齐的有限 shaping window 约束单次工作量。工具同时硬检查确定性特征：热缓存 miss 保持很低且
不淘汰，96 文本冷抖动必须确实触发淘汰；planner ss1 的文本实算数必须显著低于度量请求数。计数契约不依赖
CPU/GPU 频率，失败时即使在电池环境也会判失败；易变化的绝对数以 `bench/results/` 当次报告为准。

深层布局也同时报告稳定实例与“逐帧重建”口径。前者证明同一约束的 measure→layout memo，后者防止实例缓存
掩盖声明式重建成本；两者不可互相替代。逐帧重建会持续分配完整树，单个独立样本累计至少约 100 ms 工作量，
让多个 GC 周期进入均值，避免某一次收集把五样本 MAD 推成伪回归。

## 基线与回归守护

交互式界面以帧预算为准：60fps 对应 16.67ms/帧，120fps 对应 8.33ms/帧，30fps 对应 33.33ms/帧。显示报告按
P95 评级，并列出各分位数及超出 60fps 预算的帧比例；旧采集没有分布记录时明确显示 `-`，不伪造尾延迟。
`--save-baseline` 将当前各用例平均帧成本写入 `bench/baseline.json` 并把来源写入 `baseline.meta.json`；
`--check` 重新运行并比对。退出码 `0` 表示可信通过、`1` 表示稳定回归、`2` 表示基线或环境不可比、`3`
表示样本/执行域噪声过大、同源码重放漂移或当前为电池观测环境而不可硬判定；后三者均不会被 CI 当作通过。

当前跨机器回归门禁仍以多次运行的平均帧成本中位数判定，分布数据先作为结构化观测和阶段验收证据。待积累稳定
的同机 P95 基线后再启用尾延迟门禁，避免把窗口调度或遮挡造成的单次尖峰误判为代码回归。

### --check 如何隔离环境变化

直接把各用例的绝对耗时与基线比，在整机变慢时会全面误报：本项目实测过一台移动 P/E 核机器长时间跑后进入约
3x 的变慢态，此时 39 个用例**全部**「退化」，门禁沦为噪声。故 `--check` 分层判定：

- **环境前置门禁**：AC/电池、基础方案、Windows 性能 overlay、CPU/GPU/驱动/刷新率或 SDL 后端不一致时
  返回设置错误，不把环境变化解释为代码变化；GUI/SDL dirty 工作树也有可追溯源码指纹。电池与电池可用于
  趋势观测，但不输出硬 PASS/FAIL；完全相同源码的重放若漂移，只作为环境可复现性证据。
- **分域归一化**：分别在 headless CPU、`display/<driver>/ssN/vsyncN` 内取各用例「当前/基线」比值的中位数，
  不再用 CPU 用例为 GPU present 校速。再逐用例除以域因子——同域一起变慢即被约掉，
  单个用例的相对退化仍然突出。判退化时按 `max(机器因子, 1)` 归一，故一次让多数用例**变快**的提交不会把
  未改动的用例误报成「相对退化」。**盲区（如实声明）**：让**过半**用例等比变慢的退化会被吸收进机器因子、
  表现如「机器变慢」，不可区分——故机器因子总会打印出来，数值偏大时应换空闲机器复测再下结论。
- **样本与域双重噪声检查**：每用例先检查独立样本 MAD；分域归一化后再计算用例间稳健离散度。P/E 核机器把不同用例调度到不同
  核上，本就不是均匀变慢，此时任何阈值都分不开信号与噪声——离散度过大即报 **INCONCLUSIVE**（列出嫌疑、
  不判回归并以退出码 3 阻断门禁），而非掷硬币。空闲机器上离散度只有几个百分点，阈值自动收紧回 25%。
- **同进程配对**：原语 batch/single、段落热缓存/LRU 冷抖动、planner ss1/ss2、表格 5000/500、dashboard
  command/full 与 damage/command 另以同进程比率看护；绝对速度漂移时仍能判断优化路径是否退化。
- **确定性特性契约**：除耗时外，显示驱动输出 text measure/compute/shape/draw 与段落缓存计数；热缓存、真实
  LRU 淘汰和 ss1 逻辑文本缓存路径不满足预期时直接失败，不允许用抖动或放宽阈值掩盖。
- **覆盖护栏**：任一执行域与基线可比的重要用例不足 6 个（中位数失去意义，孤例退化可能自成中位），或全部低于 0.5ms
  （只剩抖动），同样报 INCONCLUSIVE 而非给出裁决。

低于 0.5ms 的用例不参与判定（它们撼动不了帧预算，却贡献了绝大部分抖动），但其中大幅移动者会在裁决后以
FYI 单独列出——微基准的算法性劣化今天进不了帧预算，放大后会。只有 `--check` 做归一化，报告与预算计数仍是
本机原始实测值（整机偏慢时会在摘要行注明，并换算出「按基线速度约有几例超预算」）。门禁逻辑本身由
`python bench/run_test.py` 用合成数据自测（含「整机 3x 变慢下仍能揪出单点退化」「多数用例提速不误报
其余用例」等）。基线随机器而异，跨机对比需重新采集；负载/变慢态下勿 `--save-baseline`。

## 架构压力实验

`phase3_probe.py` 回答“现有更新粒度是否构成结构性瓶颈”，也看护已实现的层次化状态所有权是否保持近似常数命中
成本；它不是普通提交的整体性能门禁。脚本默认独立运行 3 次，
逐记录字段取中位数，并要求每次给出完全相同的实验集合。局部更新实验每帧只修改一个区域；手工 retained 变体
是显式版本对照，auto-retained 用实际 State 读取驱动同一局部更新，`auto-command` 开启透明 display list，
`auto-damage` 再限定损伤区域；`auto-dynamic` 在 paint 中请求续帧，验证安全旁路不会留下陈旧 display list。
探针严格解析 `@@PHASE3_BUFFER`，报告每区命令数/估算字节、命令重放相对全树 draw 的收益，以及 damage
是否进一步减少相交外工作。damage 的独立验证阈值是相对命令全场重放 draw 至少 1.50×；未达到时报告保留
能力但不宣称收益。最新七样本为总帧 1.10×、draw 1.33×，真实 96 区域 Direct3D11 也近似持平，说明原语
批处理后它属于规模/后端相关优化。动态 paint 另以 `@@PHASE3_DIAG` 看护录制探测率、旁路直绘数和剩余退避，并将
其总帧/draw 与非缓存 retained 对照，目标是不超过 15%。Frame 访问数看护显式订阅表；状态生命周期实验的 retained body 在计时段完全不执行，因此随后代状态数增长的
build 时间可归因于挂载标记和清理簿记，而不是业务 UI 构建。

这些实验使用与普通无头基准相同的工具链构建，绝对耗时受优化级别与机器影响；同进程比例、各阶段访问数和规模
曲线才是架构决策及演进验收的主要证据。完整结论见[阶段三必要性压力实验与演进决策](../docs/phase3-architecture-decision.md)。

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
- A/B 留档：保存两个代码状态各自多次 `@@RESULT` 输出，运行 `python bench/compare.py --a ... --b ...`。
  默认同侧按中位数聚合并严格要求用例集合一致；`--aggregate min` 只用于明确以单向系统抢占为主的历史实验。
