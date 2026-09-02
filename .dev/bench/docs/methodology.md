# 性能基准（bench）

CUI 的性能测试统一在此目录，按“日常无头回归、真实窗口端到端、增量架构压力”三层组织。可复用工具与
场景各自沉淀为独立包，并输出 HTML、JSON 和架构证据报告。

## 一键运行

脚本用 Python 实现（跨平台，需 Python 3）：

```
python .dev/cli.py bench run                 # 构建并运行无头基准，生成 target/bench/results/report.html
python .dev/cli.py bench run --open          # 生成后在浏览器打开
python .dev/cli.py bench run --no-run        # 复用上次采集的数据，仅重新生成报告
python .dev/cli.py bench run --display        # 额外运行端到端基准（自终止、短暂开窗），并入真实帧率
python .dev/cli.py bench run --display --samples 5 --capture-baseline-candidate  # 采集完整、可审阅候选
python .dev/cli.py bench run --promote-baseline-candidate  # 独立校验并晋升候选，唯一活动基线写入口
python .dev/cli.py bench run --display --samples 5 --check  # 稳定 AC 环境下独立裁决；电池只观测
python .dev/cli.py bench run --samples 5      # 独立采样 5 次，保留中位数、MAD 与全距
python .dev/cli.py test tools             # 自测 --check 门禁逻辑（合成数据，不跑基准）
python .dev/cli.py bench compare --a old.txt --b new.txt  # 两组原始采集直接 A/B（默认同侧取中位数）
python .dev/cli.py test tools          # 自测 A/B 解析、聚合和不对称用例报告
python .dev/cli.py bench probe          # 运行局部更新/状态生命周期架构压力与演进回归实验（默认 3 样本）
python .dev/cli.py test tools     # 自测压力实验的记录解析、聚合和证据判定
powershell -File .dev/bench/probes/native/windows/build_sdl_gpu_msaa_probe.ps1 -Run # Windows 原生 MSAA/SSAA 隔离 A/B
powershell -File .dev/bench/probes/native/windows/build_sdl_gpu_scene_probe.ps1 -Run # 几何/clip/alpha/atlas 代表场景裁决
cd .dev/bench/workloads/headless/micro && cjpm run --run-args paint-outset  # 10k 零值/大非对称绘制域 A/B
cd .dev/bench/workloads/headless/micro && cjpm run --run-args retained       # 显式 retained 命中/替换与生命周期隔离采样
cd .dev/bench/workloads/headless/micro && cjpm run --run-args retained-hit   # 新进程隔离稳定命中，避免 miss/GC 污染
cd .dev/bench/workloads/headless/micro && cjpm run --run-args retained-miss  # 新进程隔离 revision 变化冷路径
cd .dev/bench/workloads/headless/micro && cjpm run --run-args layout         # ≥约 100ms 的稳定/重建深层布局口径
cd .dev/bench/workloads/headless/micro && cjpm run --run-args state          # State 事务合并与 1/256 观察者直接通知
cd .dev/bench/workloads/headless/micro && cjpm run --run-args derived        # 缓存/重算、外置/remembered/内联派生与手工 A/B
cd .dev/bench/workloads/headless/micro && cjpm run --run-args binding        # 深层 Binding 与朴素/endomorphism-fused Lens A/B
cd .dev/bench/workloads/headless/micro && cjpm run --run-args automatic      # 自动脏路径、keyless/显式状态、显示列表 A/B
cd .dev/bench/workloads/headless/micro && cjpm run --run-args state-scale    # 1k/10k build scope + 稳定/替换 phase State 分相曲线
cd .dev/bench/workloads/headless/micro && cjpm run --run-args semantics-scale # 1k/10k 提交、稳定帧、动作与空间查询
cd .dev/bench/workloads/headless/micro && cjpm run --run-args overlay-scale   # 1k/4k keyed 注册、事件与稳定片段采用
cd .dev/bench/workloads/headless/micro && cjpm run --run-args modifier        # 1/8/128/1024/8192 步左结合/平衡 Modifier A/B
cd .dev/bench/workloads/headless/micro && cjpm run --run-args reducer-concat  # 8/128/1024 项 Reducer 左结合/平衡 A/B
python .dev/cli.py bench suite --display --samples 5   # Python/驱动自测 + 三层套件完整执行
python .dev/cli.py bench suite --display --samples 5 --capture-baseline-candidate  # 完整套件并暂存候选
```

报告将每帧成本对照业界交互帧预算（120 / 60 / 30 fps）着色排布，自动归纳短板与长板，并给出文本度量
诊断。显示基准同时保留 P50/P90/P95/P99、最大值及三个帧预算的超限帧数，报告按 P95 评级；`report.json`
在 `frameDistributions` 中保存完整分布，在 `hostEnvironment` / `displayEnvironments` 中保存主机、AC/电池、
Windows 基础方案与性能 overlay、GPU/驱动/刷新率、实际 SDL 驱动、超采样与 vsync 环境；`source` 同时保存
CangjieGUI/CangjieSDL 的 commit、dirty 状态和性能相关源码 SHA-256 指纹。`sampleStability` 保留每个独立样本、
中位数、MAD 与全距，`pairedComparisons` 保留同进程 A/B 比率。`check.json` 保存独立门禁结果而不覆盖前者，`suite.json` 保存全套
命令及退出状态；原始日志与报告都落在
`target/bench/results/`（该目录已被 gitignore）。

`--check` 和候选采集默认各运行 5 个独立外层样本，并对每个用例取中位数，以降低 GC、操作系统调度和
混合性能核迁移造成的偶发偏差；普通报告仍只采 1 次。runner 在每个 benchmark 包首次运行前先执行一次
`cjpm clean`，防止 coverage/profile 或陈旧产物被误当成当前优化构建。Windows 混合 CPU 通过
`GetSystemCpuSetInformation` 选择最高 EfficiencyClass 的 group-0 逻辑处理器并设置进程 affinity，子进程继承
同一执行域；策略、mask、逻辑处理器与 efficiency class 全部写入 `hostEnvironment.benchmarkAffinity`，与基线
不一致时直接判为环境不可比。无头套件拆为 25 个独立进程域并跨外层样本轮换，避免
堆历史、固定顺序和 OOM 成为未声明的基准输入。已实测为 allocation/scheduler 敏感的 content-scroll、
lazy-navigation、ModelStore 会在每个外层样本内再取独立进程中位数；成对路径交替 A/B 顺序。显示用例按轮次
确定性轮转；硬裁决前先执行两轮不记入样本的完整显示稳态预热。pair 在同一外层样本同时聚合 AB/BA，dashboard
的 full/command/damage 使用彼此独立的 host/state/driver，并聚合三个正逆序窗口进程；40 分区窗口化 controls
同样取三个进程中位数。这样场景分别经历套件早/中/晚位置而不丢失同轮相关性，也不会让后一变体继承前一变体
的状态历史。单次尖峰由中位数/MAD 稳健排除；无头 frame 若出现低于中位数 70% 的异常快样本，会被识别为尚未
固定的更快执行域而判 `inconclusive`，不会把其余慢簇误判成代码回归。材料用例或配对比率 MAD 超过 10% 时拒绝候选或让
检查返回 `inconclusive`。可用 `--samples N` 显式调整外层样本数。`--no-run` 只用于重绘最近报告，不能与
`--check`/候选采集组合。每个样本必须给出完全一致的用例、迭代次数与诊断键，否则工具会失败。
`--check` 还严格要求本次出现的每个 frame/display 用例都在基线中；新增场景未审阅、未录基线时返回设置错误，
不会以“没有可比记录”为由悄悄放行。
活动基线更新是强制两阶段协议。先以 `--display --samples 5 --capture-baseline-candidate` 写入忽略目录中的候选；
评审 `baseline-capture.json`、样本/MAD、环境和源码后，单独运行 `--promote-baseline-candidate`。晋升会重新验证
候选摘要、当前 frame/display 完整键集、显示环境、至少 3 个样本、每项中位数、源码指纹、全部配对覆盖及 10%
MAD 门限；失败不会触碰活动文件。候选数值与来源元数据由 SHA-256 摘要绑定，成功后在
`.dev/bench/baselines/default/baseline.meta.json` 写入 `explicit-reviewed-candidate-v1` 晋升记录。旧 `--save-baseline` 只保留为候选采集兼容
别名，不能直接覆盖活动门禁；`--check` 也不能与采集动作组合。电池采集可带噪声警告保存为 observational
candidate 供趋势分析，但晋升必然拒绝。`.dev/bench/baselines/default/baseline.json` 保存 Windows x64 活动数值，对应元数据保存 `verdictMode`、
源码、环境、后端、样本稳定性与同进程 A/B 来源；缺少元数据的历史基线不参与裁决。
基线按目标平台和架构隔离，不能跨机器族比较：Windows x64 使用 `baselines/default/baseline.json` /
`baseline.meta.json`；其它目标使用 `baselines/<system>-<arch>.json` 与对应 `.meta.json`，例如
`baselines/linux-x86_64.json`、`baselines/macos-arm64.json`。候选元数据保存 `baselineProfile`，晋升时实际 host
必须匹配；因此在 Windows 下载 Linux 候选后误点晋升不会覆盖任何活动门禁。只有明确检测为 AC 的环境可晋升，
电池或无法证明电源来源的 runner 均只产生 observational 候选。
电池供电下即使选择“最佳性能”，固件仍可能随电量、温度和平台功耗限制动态调频，因此采集、预算评级和
同进程 A/B 仍照常执行，但 `--check` 只返回 observational/inconclusive（退出码 3），不产生硬 PASS/FAIL。
硬回归门禁应接交流电并保持相同 power overlay。若基线与本次两个仓库的源码指纹完全相同却出现候选退化，
工具会把它归类为会话可复现性漂移而非代码回归。`bench suite` 遇到日常套件回归或不可判定时仍继续执行独立的
架构压力套件，确保一次完整运行不丢失后续证据；工具自测/场景契约自身失败时才提前停止。
子进程输出以原始字节捕获：严格 UTF-8 解码失败时才回退到平台首选代码页。这样 Windows 仓颉工具链的
cp936 中文场景名不会被替换字符污染；报告、基线和 JSON 始终写成 UTF-8。

`state-scale` 在一个 build scope 以及稳定/逐帧替换的 phase 节点中分别读取 1k/10k 个 State，每帧只写一个源，
并报告完整帧、写入/失效、build、measure/layout 和关闭依赖收集后的原始读取；依赖/读取计数必须始终精确等于
源数。稳定节点看护 phase trace 与 committed canonical frontier 的顺序证书，替换节点隔离无法复用证书时的
动态路由成本，并看护 child 替换不能提前销毁最后成功 phase 的依赖 facet。当前 build scope 五进程中位为
117.408 μs/1.013 ms；统一 collector 前同轮基线为 187.691 μs/2.072 ms；稳定 phase 的证书禁用/启用 A/B 为
139.091→92.275 μs 与
1.238→0.935 ms；替换节点保留 committed facet 前后为 661.558→101.016 μs 与
5.015→0.866 ms。时间用于同口径趋势，精确前沿、失败换源和卸载释放单测负责语义门禁。

## 目录结构

- `workloads/shared/harness/`：可复用基准工具库（`bench_harness`，依赖 sdl）。计时循环 `timeit`、机器可读输出 `report`、
  `reportCount`、`reportFrameDistribution` 与 `reportBenchmarkEnvironment`、最近秩帧分布统计、滚动偏移发生器
  `ScrollSweep`。
- `workloads/shared/scenes/`：可复用场景与数据构建库（`bench_scenes`，依赖 cui）。确定性数据生成器、组合内容页
  `contentScrollScene`（无头与上机共用同一棵树），以及自终止驱动 `BenchDriver` / `BenchAccumulator`。
- `workloads/headless/micro/`：无头基准可执行程序（`bench_micro`）。逐用例打印并输出 `@@RESULT` / `@@COUNT` 行供报告解析。
  覆盖字符串、派生状态（含 1/256 源稳定读取、精确重算、稳定聚合边、State-backed 融合快照、擦除数组自动正规化、`deriveStates` 静态专用路径、四异构源融合/嵌套 A/B、融合 policy/layered distinct A/B、remembered 稳定图和手工读取对照），以及 1/8/32 层 Binding setter/update、朴素 get/set-only Lens 与 endomorphism-fused Lens、Reducer pullback 组合复杂度，另含 scoped selector 分层/融合 A/B、1–8192 步 Modifier 左结合/平衡 A/B；另覆盖表格排序（含边界）、长列表、文本区域、深层布局、控件密集表单、内容页滚动，以及
  每帧文本度量次数诊断；增量运行时部分另看护 retained 命中、状态写事务合并、默认/结构/闭包等价策略的
  等值写入成本与 revision 抑制，并对比默认/结构策略的单写、净变化、净零事务以及净零事务后完整帧；异常事务
  另验证首源失败后仍精确排空 64 个 State。这些窗口同时看护 State-owned 类型擦除通知槽：最终直接 `T` 版本
  相对每事务新建对象的单写基线改善约 0.4–3.0%，而曾尝试的 `Option<T>` 槽因 11–20% 退化已回退。另看护 1/256 个 State 观察者的
  直接通知与精确回调数；1/32 个 Derived observer 的事务窗口看护稳定 deferred action，使 32 节点中位改善约
  3.9%，并把 640000 个瞬时 action 创建收敛为 32 个 observation-owned 节点。`ModelStore` 窗口同时报告直接
  `State.update`/单 Action 门面成本与 32 Action 逐次/单快照折叠；确定性计数要求后者把 revision 从 640000
  收敛为 20000，而批末观察回调仍同为 20000。`ScopedStore` 另报告 1/8/32 层局部 Action 提升，以及这些深度下
  稳定局部读取、派发后首次局部读取和 32 Action 无中间数组融合；每种批量路径都要求根 revision 精确为 20000。
  读取深度曲线看护无策略投影融合不会退化回逐层 Derived 刷新；`--run-args="scoped-store"` 隔离这组曲线。
  特征 reducer 窗口比较手写/标准 Option lift；
  `--run-args="feature-path"` 隔离比较手写 Lens/Action 闭包与复用 `FeaturePath` 的 reducer、Store 热路径；另在
  16/1024/2048/4096/8192/10000 项上配对“线性末项扫描+完整数组复制”与稳定 ID 索引+32 元素分块持久更新；
  `--run-args="identified-array"` 可隔离该曲线，并以 1/4/8/16/32/128 个 Action 配对逐次 `identifiedReducer` 与
  一次 `identifiedBatchReducer`，另在 16/1024/100000 项复核小集合固定成本和外层 chunk 表摊销；
  `--run-args="entity-table"` 再以 16/1024/10000/100000 项比较线性数组、每次克隆 HashMap 与分层持久实体表更新，
  同时轮转读取全部 ID，防止优化器把固定键查询移出计时循环；同一路由另以 1/4/8/16/32/128 个更新比较逐次
  持久版本与 `updatingAll` 自适应批次，并在 100000 项上复核 32 更新的目录摊销；同场景再以 4/32/128 个
  `IdentifiedAction` 配对逐次 `entityReducer` 与一次 `entityBatchReducer`，把 Action 解释和闭包成本计入总账；
  每次都核对集合规模，防止优化器消除工作。240 个同根 selector 的单字段变更 A/B 另要求普通失效执行
  240 个分支、结果等价策略只执行 1 个，并分别报告完整帧与 build 时间，把主动比较成本计入总账。
  `EffectStore` 以零效果单动作对照普通 `ModelStore` 的 opt-in 成本，并比较 32 个无效果 Action、32/128 个
  带效果 Action 的 Writer 批量折叠；另比较每次显式 handler 与一次 `connect` 后的 UI 门面，并看护 identity
  读取和根批次快路径。`--run-args="effect-store"` 可隔离该组曲线。
  逐次/直接折叠/connect 三侧效果数必须同为 640000、回调同为 20000，后两者 revision 必须降到 20000。
  另覆盖显式 Frame 订阅表和 lifecycle effect 稳定/替换成本。自动运行时用普通 UI 代码对照增量/强制全量：240 分支单点更新看护
  脏 body 为 1/240，并以 256 个位置槽/显式字符串键的稳定重建 A/B 看护 keyless 人体工学不引入隐藏初始化或
  全局 scope 分配；同时单独报告局部/全量自动组合的 `buildNs`，避免布局和绘制噪声掩盖依赖/声明前沿成本。
  该 build 相位也看护有界 transaction arena：arena 落地时局部/全量五样本为 145.72/505.74 μs，对 arena 前
  178.45/585.77 μs。稀疏 committed facet 的固定 HashMap 首版为 164.53/508.38 μs；committed 小集合再自适应后
  当前为 147.19/498.15 μs，基本收回局部成本。同一命令精确输出 2 个 ownership-only、240 个 dependency-only、
  0 个并存 scope，并要求 240 个 State-reading 行全部保持 dependency-only；第 8/9 条索引升降级、容量、降级和
  未回滚 cell 禁止复用由确定性内核测试负责，不用易抖动的时间值代替内存契约。
  measure/layout/paint collector 另看护惰性分相依赖：改造前后的自动命令命中为 3.117→2.628 μs，复杂兄弟自动
  晋升为 18.113→16.087 μs；强制对照保持噪声量级。跨执行状态优先看同进程 direct/cache 与 full/auto 比率，
  当前分别约 13.58×/3.70×。显式 `retained-hit` 单独看护空 phase 的提交短路，最终 53.605 μs 对改造前
  53.227 μs；Element measure/layout 改为封闭状态和类型后的同轮五进程中位为 hit 51.75 μs、miss 2.382 ms，
  改造前本轮为 75.73 μs/2.999 ms。短窗口只用于拒绝明显退化，状态转移与旧几何保留由确定性测试负责。
  空/单边/宽边存储数量和第 8/9 条升降级由确定性内核测试负责。
  稳定绘制看护自动显示列表使 widget draw 访问为 0；复杂兄弟更新看护自动晋升边界
  使稳定子树 layout 访问为 0。`--run-args scene-patch` 隔离测量 flat/层次父列表、稳定重放和 96/256/1024
  子槽单区域 damage，并以 1024/256 不超过 3x 看护持久 slot-run BVH 不退化回线性扫描。惰性视口用例直接
  对比 10000 行 legacy 每帧高度扫描与 revision 缓存，
  并看护 100000 行 `LazyListExtents` 单点更新+完整 headless 帧。规模探针另以确定性访问计数配对耗时，
  测量单作用域读取 1000/10000 个 State、10000/100000 项随机 `scrollToKey`/`scrollToIndex`、1000/10000 个
  focusable 的注册与遍历、1000/10000 节点最上层/最深层事件命中，以及语义动作/快照/稳定帧；这些曲线用于
  决定是否引入依赖 HashMap、key-index、焦点、事件或语义索引，不预设优化结论。
- `workloads/diagnostics/phase3/` 与 `bench probe`：与普通回归基线隔离的架构决策及演进回归实验。对大而密 UI 的单区域高频更新做
  full-tree/manual-retained/auto-retained/command/damage 同进程 A/B，记录 build/layout/event/draw 的耗时与
  访问数；另测 retained 命中时后代状态/effect 生命周期簿记的规模曲线，并验证漏写 revision 与 dynamic paint
  安全旁路。结果写入
  `target/bench/results/phase3.{md,json}`，不修改 `baseline.json`。目录名保留阶段性实验的历史来源，报告语义已是
  长期的“增量架构压力套件”。
- `workloads/display/planner_scroll/`：端到端应用（需显示）。复刻规划台右栏组合内容页，自动上下滚动，跑满固定帧数后自动
  退出并打印真实帧率；完整套件在同一进程依次采显式 `ss2`、物理密度 Auto 和显式 `ss1`，避免新进程落在
  不同核心/功耗状态。`ss1/ss2` 看护像素填充成本，`Auto/ss1` 验证高 DPI 上的策略开销与实际选择。
- `workloads/display/controls_form/`：端到端密集控件表单，覆盖几何、阴影、交互控件与滚动组合成本；完整套件同时采
  全量 `ScrollView` 和惰性视口的 12/24/40 分区规模曲线，直接看护窗口化收益及随总量近似平坦的成本。
- `workloads/display/large_table/`：端到端应用（需显示）。完整套件在同一进程依次运行 500/5000 行窗口化表格；绝对耗时看真实
  帧成本，5000/500 比率看护总数据量增长时可见行成本保持近似平坦。
- `workloads/display/incremental_dashboard/`：96 区域真实渲染 A/B，同场景比较强制全量、命令全场重放和单区域 damage。
- `workloads/display/text_layout/`：真实 SDL_ttf 的 20000 字段落稳定缓存与 96 个真正唯一文本的 LRU 冷抖动；两者同进程运行，
  专门看护有界 shaping window、P95、热/冷比率和 4 MiB 段落缓存淘汰行为。
- `workloads/display/primitive_batch/`：2048 个相同矩形逐条提交与相邻同色命令批处理的同像素 A/B，隔离驱动调用摊销；不跨 clip/文本/纹理或颜色重排。
- `probes/native/windows/`：固定到 SDL 3.4.12 ABI 的 Windows 原生压力探针；以交替 ABBA/BAAB、最终 GPU 排空和
  机器 JSON 对照 D3D11 2× SSAA 与 SDL_GPU/D3D12 4× MSAA resolve。第一层隔离 clear/resolve 下界；第二层
  用同一值 IR 覆盖几何、scissor、透明混合和模拟 glyph atlas，并在计时外读回像素证明两侧确实画出近似结果。
  它不进入跨机器日常基线。当前代表场景未过收益/P95 门槛，因此明确拒绝生产后端扩张。
- `tooling/` 与 `templates/report.html`：按执行、解析、采样、环境、基线、门禁和报告拆分的 Python 工具。

## 三层口径

三层测的是不同问题，不能混用绝对数：

- 无头口径：以 `Renderer.headless()` 驱动真实的 build / layout / draw，几何、事件与字符串照常执行，但渲染
  为空操作、文本按估算宽度计。故它准确反映布局遍历与 CPU 侧每帧成本，但不含 GPU 光栅，也不含 SDL_ttf
  的真实文本度量耗时。计时用 `PerformanceClock.ticksNanoseconds`，无需建窗。
- 端到端口径：真实窗口逐帧更新控件树，每个 Label 经 SDL_ttf 实测、可见文本被光栅化，给出用户实际体感的
  帧率。以 `frameDelay = 0` 运行，故平均帧耗时即真实每帧工作量（发布应用会再额外睡眠约 16ms/帧）。端到端
  基准自终止：跑满固定帧数后自动关窗，无需人工读表。`@@RESULT` 保留兼容的均值，`@@FRAME_DIST` 记录
  单次运行的 P50/P90/P95/P99、最大值和 120/60/30fps 超预算计数；`@@BENCH_ENV` 记录实际驱动、超采样与
  vsync；场景驱动另以 `@@COUNT` 记录 sampling target pixels/bytes 和 SDL 最大纹理边长，并门禁 RGBA8 的
  `bytes = 4 × pixels`，从报告可直接分辨 Auto、显式 ss2 与资源回退。多次采样逐字段取中位数，并要求环境字段完全相同。注意在无显示或窗口被遮挡的环境下（例如 CI 或后台
  会话），系统可能跳过 GPU 与文本光栅，实测值会失真，故端到端帧率应在交互式显示环境采集。
- 架构压力口径：固定复杂 UI 拓扑，分阶段记录访问数、命令数/估算字节和规模曲线。同进程变体比例与确定性
  访问数是主证据；它不进入跨提交 fleet 基线，避免把结构性实验的阈值误当作普适 SLA。

## 与 `.dev` 的边界

- `.dev/bench/`：定义工作负载、计时区间、采样聚合、性能基线、A/B、预算评级和架构规模证据。
- `.dev/cui_dev/`：验证结果是否正确，包括示例 E2E、快照像素、包隔离、真实窗口生命周期、文档链接与超时归因。
- E2E 工具即使记录耗时，也只用来定位卡在哪一步，不据此宣称性能回归；性能脚本即使带确定性断言，也只用
  断言保障测到的是预期路径。两边可共享 `.dev/cui_dev/common/process.py` 的安全进程树基础设施，但不共享场景语义。

## 文本度量诊断

每帧文本度量次数（`@@COUNT`）是定位文本瓶颈而无需开窗的关键指标：一棵树每帧发起多少次文本度量，与是否
上机无关；乘以单次 SDL_ttf 成本即该帧的文本预算。未窗口化的组合内容页每帧上千次度量（约 2400 次），是
规划台右栏滚动帧率偏低的主因；窗口化的表格与列表只度量可见行，故低一到两个数量级。诊断由 `Renderer` 的
`textMeasureCount` / `resetTextMeasureCount` 探针采集。

长文必须区分冷布局与热缓存：`micro` 同时输出 `长文换行（冷）` 与 `长文换行`，并记录段落缓存命中/未命中；
端到端 `text_layout` 再用真实 SDL_ttf 验证。原先把整段余串传给 `TTF_MeasureString` 会产生秒级尖峰，当前以
UTF-8 边界对齐的有限 shaping window 约束单次工作量。工具同时硬检查确定性特征：热缓存 miss 保持很低且
不淘汰，96 文本冷抖动必须确实触发淘汰；planner ss1 的文本实算数必须显著低于度量请求数。计数契约不依赖
CPU/GPU 频率，失败时即使在电池环境也会判失败；易变化的绝对数以 `target/bench/results/` 当次报告为准。

深层布局也同时报告稳定实例与“逐帧重建”口径。前者先执行一次根 measure，再证明同一环境/约束的
measure→layout memo；后者防止实例缓存
掩盖声明式重建成本；两者不可互相替代。逐帧重建会持续分配完整树，单个独立样本累计至少约 100 ms 工作量，
让多个 GC 周期进入均值，避免某一次收集把五样本 MAD 推成伪回归。

`semantics-scale` 同时报告首次归一化提交、稳定语义/同构空节点帧、动作、快照、点查询和焦点查询。稳定帧
必须保持语义相对空节点的额外 P50 低于 10 μs；首次提交与查询曲线用于观察 Element-owned layout/fragment
所有权是否把一次性正确性成本错误搬到每帧。跨 Context provider 与环境变化后的 paint command 正确性由单测
看护，不用易抖动的时间阈值代替行为断言。`semantic-empty` 只运行 1k/10k 冷空树，分别报告 semantics/layout
相位并断言平台语义节点与 active overlay 均为 0，用于隔离
`(None | OverlaySnapshot) × (None | SemanticFragment)` 的稀疏布局效果表示；冷分配时间只作量级观察。

## 基线与回归守护

交互式界面以帧预算为准：60fps 对应 16.67ms/帧，120fps 对应 8.33ms/帧，30fps 对应 33.33ms/帧。显示报告按
P95 评级，并列出各分位数及超出 60fps 预算的帧比例；旧采集没有分布记录时明确显示 `-`，不伪造尾延迟。
候选采集保留各用例平均帧成本及完整来源，显式晋升才写入 `.dev/bench/baselines/default/baseline.json` / `baseline.meta.json`；
`--check` 用另一批样本重新运行并比对。退出码 `0` 表示可信通过、`1` 表示稳定回归、`2` 表示基线或环境不可比、`3`
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
- **计时窗口与堆生命周期**：带进程内确定性比例断言的 headless 场景应覆盖足够工作量；完整无头集合按 25 个
  GC/所有权域逐进程运行并轮换。分配密集的 48 区块重建相位独享堆生命周期，content-scroll、lazy-navigation、
  ModelStore 在每个外层样本内再做进程中位数；这里增加观察量和隔离边界，不降低 4×、绝对帧预算或 10% MAD。
- **同进程配对**：原语 batch/single、段落热缓存/LRU 冷抖动、planner ss1/ss2 与 Auto/ss1、表格
  5000/500、dashboard command/full 与 damage/command 另以同进程比率看护；绝对速度漂移时仍能判断
  优化路径是否退化。显示环境记录的是渲染器最终生效倍数，因此 Auto 的策略结果也可审计。
- **确定性特性契约**：除耗时外，显示驱动输出 text measure/compute/shape/draw 与段落缓存计数；热缓存、真实
  LRU 淘汰和 ss1 逻辑文本缓存路径不满足预期时直接失败，不允许用抖动或放宽阈值掩盖。
- **覆盖护栏**：任一执行域与基线可比的重要用例不足 6 个（中位数失去意义，孤例退化可能自成中位），或全部低于 0.5ms
  （只剩抖动），同样报 INCONCLUSIVE 而非给出裁决。

低于 0.5ms 的用例不参与判定（它们撼动不了帧预算，却贡献了绝大部分抖动），但其中大幅移动者会在裁决后以
FYI 单独列出——微基准的算法性劣化今天进不了帧预算，放大后会。只有 `--check` 做归一化，报告与预算计数仍是
本机原始实测值（整机偏慢时会在摘要行注明，并换算出「按基线速度约有几例超预算」）。门禁逻辑本身由
`python .dev/cli.py test tools` 用合成数据自测（含「整机 3x 变慢下仍能揪出单点退化」「多数用例提速不误报
其余用例」等）。基线随机器而异，跨机对比需重新采集；负载/变慢态下勿采集或晋升候选。

## 架构压力实验

`bench probe` 回答“现有更新粒度是否构成结构性瓶颈”，也看护已实现的层次化状态所有权是否保持近似常数命中
成本；它不是普通提交的整体性能门禁。脚本默认独立运行 3 次，
逐记录字段取中位数，并要求每次给出完全相同的实验集合。局部更新实验每帧只修改一个区域；手工 retained 变体
是显式版本对照，auto-retained 用实际 State 读取驱动同一局部更新，`auto-command` 开启透明 display list，
`auto-damage` 再限定损伤区域；`auto-dynamic` 在 paint 中请求续帧，验证安全旁路不会留下陈旧 display list。
探针严格解析 `@@PHASE3_BUFFER`，报告每区命令数/估算字节、命令重放相对全树 draw 的收益，以及 damage
是否进一步减少相交外工作。damage 的独立验证阈值是相对命令全场重放 draw 至少 1.50×；未达到时报告保留
能力但不宣称收益。最新七样本为总帧 1.10×、draw 1.33×，真实 96 区域 Direct3D11 也近似持平，说明原语
批处理后它属于规模/后端相关优化。动态 paint 另以 `@@PHASE3_DIAG` 看护录制探测率、旁路直绘数和剩余退避，并将
其总帧/draw 与非缓存 retained 对照，目标是不超过 15%。Frame 访问数看护显式订阅表；512 订阅场景还要求预热后
稳定片段创建精确为 0。修改后五个暖样本的 0/512 订阅中位为 5.81/7.16 μs，修改前单样本为
5.65/11.21 μs；确定性创建计数是主门禁，时间只用于观察回调外的维护成本。状态生命周期实验的 retained body 在计时段完全不执行，因此随后代状态数增长的
build 时间可归因于挂载标记和清理簿记，而不是业务 UI 构建。

这些实验使用与普通无头基准相同的工具链构建，绝对耗时受优化级别与机器影响；同进程比例、各阶段访问数和规模
曲线才是架构决策及演进验收的主要证据。完整结论见[阶段三必要性压力实验与演进决策](../../../docs/phase3-architecture-decision.md)。

层次化命令槽使用独立的同进程 A/B，避免旧机器基线把新实验误判为未知常规用例：

```powershell
cd .dev/bench/workloads/headless/micro
cjpm run --run-args scene-patch
```

它同时报告 96×24 命令在 flat/hierarchical 父列表中的重建与稳定重放成本，以及 48 区普通 Widget 的单区域
patch/强制全树帧时和绘制访问数。保留门禁是：父列表重建至少 2×，普通 Widget 局部帧不退化，稳定重放新增
绝对成本不超过 5 μs，且单区域只访问该区域的 8 个绘制叶。正式刷新同机完整 baseline 前，该实验不进入默认
`micro` 记录集合。

语义提交索引使用独立命令，避免新架构证据混入旧机器 baseline：

```powershell
cd .dev/bench/workloads/headless/micro
cjpm run --run-args semantics-scale
cjpm run --run-args semantic-empty
```

它测量 1000/10000 节点最早/最新动作、重复快照、稀疏点的线性/提交索引查询和已聚焦语义查询，并以同构无语义
节点树对照稳定帧。门禁要求动作、快照、索引点查询和焦点查询均低于 2 μs，稳定语义帧相对空节点树增加不超过
10 μs；确定性 action/focus 结果还防止“优化”为漏派发。

事件空间拓扑使用独立命令，同时保留全重叠语义下界与稀疏可剪枝场景：

```powershell
cd .dev/bench/workloads/headless/micro
cjpm run --run-args event-scale
```

它对照 1000/10000 个完全重叠的兼容处理器与同规模稀疏 `LayoutBounds` 网格，并比较 10k detached
无界/有界提交及 Element-owned retained 稳定布局。重叠最深命中必须继续访问全部处理器；稀疏命中必须恰好
访问 1 个候选且低于 5 μs。detached 提交逐帧采样并输出 `@@FRAME_DIST`，有界 P50 相对无界增加不得超过
50 μs；Element-owned 稳定布局也不得超过有界 P50 50 μs。拓扑的 pending/committed 双缓冲与几何、overlay、
semantics 一起由 `ElementLayoutCommit` 提升；稳定 topology 必须走“无变化短路”，不能重建 AABB 树。当前五个
完整样本中位：10k 稀疏命中 650 ns、完全重叠最深命中 67.08 μs、Element-owned 稳定布局 858 ns；detached
无界/有界 P50 为 632.4/639.6 μs。命令还测量含 10k focus id 的 `EventListener` 键盘目标；最后命中与未命中
都必须低于 2 μs。线性数组基线为 345.34/204.01 μs，自适应索引后为 48/20 ns。Element typestate 改造后的
五进程 10k 稳定布局中位为 726 ns，未增加布局命中成本。事件 topology owner 再改为封闭状态机前/后的同轮中位为
稳定布局 788/772 ns、detached 无界提交 736.8/736.3 μs、有界提交 703.2/687.8 μs；同尺寸外来 topology 的
拒绝和所有权保留由确定性反例负责，不以时间阈值替代。Child topology 内部再以五阶段和类型替代三 Bool 后为
778 ns、703.7/691.4 μs；乱序操作、ready restart 和只发布最新写面由直接状态测试看护。

焦点声明提交使用独立命令，区分“全量拓扑改变”与“干净片段稳定采用”：

```powershell
cd .dev/bench/workloads/headless/micro
cjpm run --run-args focus-scale
```

它测量 1k/10k focusable 注册重建、`focusNext`、同构 focusable/无焦点稳定树及 build、focus/layout 子阶段。
时间分布用于观察长尾；确定性门禁要求预热后的 30 个稳定帧不再推进 focus graph revision。Root 隐式包装器进入
automatic 正规形后，五个独立进程的 P50 中位中，1k/10k focusable 稳定帧为 14.646/95.490 μs，10k 无焦点
稳定帧为 86.506 μs，10k focusable/无焦点 focus-layout 为 0.863/0.950 μs；稳定图提交均为 0。修复前对应
10k 稳定帧为 10.287/9.572 ms，说明此前残余成本不是焦点提交，而是缓存外每帧重建多子项 Root Stack。
命令还构造 10k 个只实现 legacy `focusableIds()` 的 automatic 输出；脏重建查询数必须为 0，防止已由
`FocusSnapshot` 取代的私有死数组重新出现。

自动组合声明重放可单独对照静态声明与外部版本声明：

```powershell
cd .dev/bench/workloads/headless/micro
cjpm run --run-args declaration-replay
```

场景在一个自动作用域内分别用显式键/keyless API 声明 128 个 lifecycle effect 和一个 retained 边界，预热后运行
500 帧。确定性门禁要求两种 `mountEffect` + key-only retained 的组合体执行均为 0 次/帧，而两种 revision 版本
保持 1 次/帧，防止优化冻结普通外部值。当前五样本 keyless/显式静态为 4.11/5.13 μs，外部版本为
25.20/45.96 μs；时间只作量级证据，0/1 次执行才是跨机器契约。

Overlay 注册簿使用独立规模命令：

```powershell
cd .dev/bench/workloads/headless/micro
cjpm run --run-args overlay-scale
```

它预构造 1k/4k 个 keyed overlay，分别测注册、全部未处理事件和 4k 稳定 Widget 帧。注册与事件分别使用
80/40 次窗口；事件必须精确访问 `overlay 数 × 迭代数` 个 handler，4k/1k 时间不得超过 8×，稳定 120 帧逐项
fragment replay 必须精确为 0。原始数组扫描基线的 4k 注册/事件为
48.701/10.729 ms；最终五样本中位为 421.51/101.91 μs，约改善 115×/105×。4k 稳定帧五样本中位为
25.51 μs。后续 optional snapshot capture 复验为 21.23 μs，逐项 replay 仍精确为 0；冷布局受分配器与调频
影响较大，所以对象恒等复用、空片段缺席和 suffix-only 归一化由确定性测试看护，不以单次纳秒波动代替契约。

Element 空间与双域 clip 的滚动帧门禁可单独运行：

```powershell
cd .dev/bench/workloads/headless/micro
cjpm run --run-args content-scroll
```

它先用同一个 `WidgetTestHost` 对照增量物化与强制全量：800 个滚动帧中增量路径的声明体执行必须少于全量四分之一，
且稳定化 pass 必须精确等于 `800 + 边界重建数`；当前为 51/800 次 body、851 pass，build 18.37/151.22 μs
（8.23x），端到端 213.05/285.32 μs（1.33x）。随后显式绕过 retained host、每帧构造完整 Widget，隔离
ScrollView+VStack、LazyColumn 与自测量 LazyList 的原始窗口化成本；12/48 区 LazyColumn 仍须分别低于
650/750 μs，且 48 区至少比未窗口化快 4x。两种口径不能互相替代。

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
- A/B 留档：保存两个代码状态各自多次 `@@RESULT` 输出，运行 `python .dev/cli.py bench compare --a ... --b ...`。
  默认同侧按中位数聚合并严格要求用例集合一致；`--aggregate min` 只用于明确以单向系统抢占为主的历史实验。
