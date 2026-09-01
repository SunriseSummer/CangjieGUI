<!-- kind: explanation; audience: maintainer -->

# 局部更新架构压力实验、演进决策与实测验收

本页不把既有“阶段三”设想当结论，而回答三个可证伪的问题：阶段一、二后是否仍有结构性瓶颈；哪种方案能以
可接受的正确性和内存代价消除它；实装后是否真的回收成本。结论来自同进程 A/B、真实窗口像素差分、执行图
诊断和失败路径测试，而不是从其他 GUI 框架直接类推。

截至 2026-08-22，层次化状态/effect 所有权、失败构建事务、build/measure/layout/paint 分相依赖、显式
Frame 订阅、透明绘制命令缓冲和保守局部 damage 均已实现。后续原语批处理显著降低了全场命令重放成本，
因此当前证据把两件事分开：retained scope/display list 的结构性收益已经确认；damage 的正确性已经确认，
但它在当前 Direct3D11 场景中的额外性能收益较小且依赖规模，不能再被描述为普遍必要的数量级优化。

**2026-08-24 自动化落地更新：**上述 retained 变体最初是隔离机制收益的显式实验，不再代表应用写法。
普通 builder 现已自动形成组合依赖图；根输出持久化，复杂单根作用域按结构宽度/规模选择性晋升；稳定绘制
自动录制透明命令，并受单候选 8 MiB、每应用 32 MiB LRU 预算约束；最近自动边界产生局部 damage。
`bench/micro` 新增的普通代码 A/B 实测为：240 分支单点变化只执行 1 个 body，2.04 ms 对 3.51 ms；
96 个稳定绘制节点 12.9 μs 对强制直绘 130.1 μs，widget draw 访问 0 对 9600；复杂兄弟更新
110.0 μs 对 368.3 μs，稳定子树 layout 访问 0 对 24。绝对时间随机器变化，确定性访问数和同进程比例
才是门禁。这些结果证明自动化回收了实验收益，同时避免要求业务选择边界或 cache 开关。

## 可复现实验

在仓库根目录执行：

```text
python bench/phase3_probe_test.py
python bench/phase3_probe.py --samples 3
python bench/run_all.py --samples 5 --display --check --timeout 240
python .devtools/test_desktop_lifecycle.py
python .devtools/test_examples.py --smoke-snapshots --retained-diff
```

`bench/phase3` 构造由指标卡、网格、文本和探针组成的复杂仪表盘，每帧严格只修改一个区域。六个变体共享
内容和最终状态：

- `full-tree`：普通声明式全树 build/layout/draw；
- `manual-retained`：每个边界在调用前读取显式 `State.revision`，代表兼容 API 的人工依赖清单；
- `auto-retained`：在边界 body 内读取 State，由实际读取自动失效 build/measure/layout，draw 仍遍历全场；
- `auto-command`：再为每区录制透明值命令，dirty 区重录，其余区重放；
- `auto-damage`：在命令缓冲上只重放与 damage 相交的 z 序内容；
- `auto-dynamic`：paint 每帧变化，验证命令录制探测退避后不会反复付出失败缓存成本。

另有 0～8192 个后代 State/effect 的完全命中实验；其 body 在计时段不执行，增长只可能来自所有权与订阅簿记。
命令记录还输出每区命令数和保守估算字节。脚本按 `--samples` 启动独立进程并逐字段取中位数，要求每次输出完全相同的实验
集合；当前留存报告使用三个样本，绝对时间受机器影响，同进程比例、访问数和规模曲线才是架构证据。真实后端另由
`bench/incremental_dashboard` 对 96 区域的强制全量、命令全场重放和单区域 damage 做同场景 A/B。

## 当前三样本结果（2026-08-22 22:55，原语批处理之后）

| 区域 | 变体 | 总帧时 | build | layout | event | draw | build/layout 访问 | event/draw 访问 |
|---:|---|---:|---:|---:|---:|---:|---:|---:|
| 24 | auto-command | 316.67 μs | 53.41 μs | 106.06 μs | 998 ns | 153.52 μs | 1/1 | 0/1 |
| 24 | auto-damage | 317.57 μs | 56.53 μs | 108.46 μs | 1088 ns | 145.27 μs | 1/1 | 0/1 |
| 24 | auto-dynamic | 540.00 μs | 60.88 μs | 107.75 μs | 1210 ns | 358.86 μs | 1/1 | 0/24 |
| 24 | auto-retained | 440.11 μs | 56.95 μs | 100.02 μs | 1080 ns | 280.58 μs | 1/1 | 0/24 |
| 24 | full-tree | 2.57 ms | 203.03 μs | 2.03 ms | 2358 ns | 296.54 μs | 24/24 | 0/24 |
| 24 | manual-retained | 544.92 μs | 123.61 μs | 107.90 μs | 1150 ns | 302.17 μs | 1/1 | 0/24 |
| 96 | auto-command | 849.12 μs | 161.65 μs | 153.11 μs | 1336 ns | 513.56 μs | 1/1 | 0/1 |
| 96 | auto-damage | 781.22 μs | 149.54 μs | 155.50 μs | 1448 ns | 470.08 μs | 1/1 | 0/1 |
| 96 | auto-dynamic | 1.68 ms | 180.98 μs | 156.66 μs | 1430 ns | 1.34 ms | 1/1 | 0/96 |
| 96 | auto-retained | 1.49 ms | 167.10 μs | 149.51 μs | 1440 ns | 1.17 ms | 1/1 | 0/96 |
| 96 | full-tree | 10.55 ms | 1.36 ms | 8.02 ms | 6246 ns | 1.19 ms | 96/96 | 0/96 |
| 96 | manual-retained | 2.46 ms | 1.13 ms | 155.41 μs | 1740 ns | 1.18 ms | 1/1 | 0/96 |
| 256 | auto-command | 1.99 ms | 354.92 μs | 253.45 μs | 1787 ns | 1.36 ms | 1/1 | 0/1 |
| 256 | auto-damage | 1.89 ms | 407.16 μs | 263.55 μs | 1883 ns | 1.19 ms | 1/1 | 0/1 |
| 256 | auto-dynamic | 4.27 ms | 379.95 μs | 235.97 μs | 1825 ns | 3.49 ms | 1/1 | 0/256 |
| 256 | auto-retained | 3.70 ms | 396.58 μs | 264.73 μs | 1916 ns | 3.03 ms | 1/1 | 0/256 |
| 256 | full-tree | 31.83 ms | 7.20 ms | 21.50 ms | 7416 ns | 3.16 ms | 256/256 | 0/256 |
| 256 | manual-retained | 10.21 ms | 6.68 ms | 345.97 μs | 4050 ns | 3.20 ms | 1/1 | 0/256 |

最大场景的普通路径跨过 16.67 ms 帧预算；自动 retained 将其降为 3.70 ms（8.60 倍），命令缓冲相对其再降
1.86 倍、draw 降 2.23 倍。命令密度为每区 24 条、约 1586 B，dirty 重录访问稳定为 1。由此可确认：全树
build/layout 和绘制全传播都是真实结构瓶颈，分相依赖与透明 display list 不是伪需求。

damage 的结论不同：三样本中它相对命令全场重放仅改善总帧 1.05 倍、draw 1.14 倍，未达到探针 1.50 倍验证
阈值；同批完整矩阵的真实 Direct3D11 96 区域场景为命令全场重放 2.032 ms、单区域 damage 1.926 ms，也只有
约 1.05 倍。原因是 SDL 路径即使只
更新持久目标的一小块，`endScene` 仍需把整张目标解析到窗口；而相邻原语批处理已经压低全场 replay 成本。
所以 damage 目前是“正确、内存不增、复杂大场景可能有小幅收益”的保守能力，不是继续扩大架构复杂度的依据。

`manual-retained` 的 256 区 build 明显慢于自动版也有解释价值：构造函数参数在进入边界前求值，256 次显式
`State.revision` 会成为 root build 读取并维护 root 依赖。它仍正确且比全树快，但不应再宣传为首选性能 API；
State 应尽量在目标 phase/body 内读取，显式 revision 只覆盖普通值和外部资源。

| retained 后代 | State 命中帧 | effect 命中帧 |
|---:|---:|---:|
| 0 | 6.381 μs | 6.962 μs |
| 256 | 6.407 μs | 7.473 μs |
| 2048 | 9.440 μs | 6.408 μs |
| 8192 | 7.300 μs | 7.235 μs |

8192 State/effect 相对空边界分别只增长 1.14/1.04 倍，且中间规模不单调，未观察到逐后代扫描瓶颈。卸载仍递归释放真实子树；
失败构建取消新增所有权和订阅，保留此前已提交图。effect setup/replace/cleanup 的提交、回滚、兄弟继续清理和
失败资源重试均有专门测试。

## 正确性与端到端证据

- 命令缓冲是不可变值命令，不保存 CPU closure；录制时复制可变点/alpha，显式 Texture 句柄去重并在重放前
  校验 renderer、resource 和 epoch，失败不会半画。普通嵌套 replay 仍可扁平化；自动场景通过稳定
  `RenderCommandSlot` 保留层次引用，子缓冲替换无需复制进祖先，根验证后共享一次 clip 保存。
- `cachePaint` 对 State 自动建立 paint 依赖；续帧、焦点/悬停/按压/拖拽、tooltip、IME、overlay 等动态
  `UiContext` 协议会让当前及祖先缓存自动 bypass，诊断保留具体原因，避免冻结光标、悬停态或动画。
- 真实 SDL 窗口先做一块局部更新并捕获 BMP，再以相同最终 State 全帧绘制；两图 0 差异像素，同时文本 draw
  从 2 降为 1。DesktopApp 还覆盖 2× 持久目标实际接受 damage，以及 1× 后端拒绝后全帧且诊断为 false。
- examples 是公开 API 的 E2E 消费者。smoke fleet 同一二进制分别跑默认增量与强制全量并逐像素比较；动态后台
  输入在 snapshot 模式固定，避免把两次独立采样的业务噪声误判为缓存回归。
- `--cui-disable-retained-damage` 只关闭 damage，`--cui-force-full-retained` 关闭整个 retained 命中；任何问题
  都有分层逃生口和可比较参照。

## 与业界实践的对应和取舍

Compose 按 composition、layout、draw 三个 phase 追踪 State 读取，绘制期读取只重启 draw；CUI 采用相同的
“读取位置决定失效相位”原则，但保留帧事务，禁止 setter 同步重入 UI。
[Jetpack Compose phases](https://developer.android.com/develop/ui/compose/phases)

Compose 的 `graphicsLayer` 会隔离并重放绘制指令，只有确需合成时才离屏栅格化；官方同时指出 offscreen 会分配
与区域等大的纹理、默认裁剪到边界，并且透明度/混合策略可能改变结果。CUI 因此默认保留透明命令，而不采用
“每个 scope 一张 GPU 位图”；将来若做 raster cache，必须是可撤销、有显存预算的二级提升。
[Compose graphics modifiers](https://developer.android.com/develop/ui/compose/graphics/draw/modifiers)

Flutter 的 `RepaintBoundary` 同样为子树建立独立 display list，只在父子重绘时序不对称时有收益；其运行时专门
暴露 asymmetric/symmetric paint 计数来判断边界是否有用。CUI 应借鉴这种证据驱动诊断，而不是自动把每个
Widget 提升为边界。[Flutter RepaintBoundary](https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary-class.html)

SDL 要求 render target texture 具备 target access，且 viewport、clip、scale 等状态按 target 独立持久化并只能
在主线程切换。CUI 的 damage 只复用自己拥有的兼容持久超采样目标，每帧显式恢复 target/clip；不尝试依赖不可控
的窗口 backbuffer。[SDL_SetRenderTarget](https://wiki.libsdl.org/SDL3/SDL_SetRenderTarget)

## 已采用的最优技术方案

当前内核是“分相依赖驱动的轻量 retained scope graph”，而不是完整虚拟 DOM，也不是业务可变 Widget 树：

1. scope 直接拥有局部 State、effect 和子 scope；命中为 O(直接边界)，替换在完整根构建成功后原子提交；
2. build/measure/layout/缓存 paint 各自收集真实 State 读取，setter 只标脏必要阶段；root 读取保守要求全帧；
3. Frame 只广播给显式订阅者；普通指针与 overlay 保持现有正确 z 序；
4. 持久节点观察稳定性和命令规模后自动保存透明 Renderer value display list；Element-owned 代际场景槽把
   子列表作为稳定引用嵌入祖先，动态协议退避，dirty scope 只重录 patch 前沿，资源/epoch 变化安全失效，
   全局 32 MiB LRU 防止缓存无界；
5. 最近自动晋升 scope 记录旧/新布局范围，状态写合并矩形；区域超过视口 70% 或有任何不安全触发时全帧；
6. 后端只在持久目标实际接受时报告 partial，随后按 damage 裁剪并重放全部相交 z 序内容。

这组设计直接对应实测热点，又保留当前函数式 DSL；`RetainedSubtree` 只作为兼容和实验边界。自动 State
依赖负责正确性，revision 只作为非 State 输入的覆盖；全量模式始终是语义参照。

## 明确避开的坑

- 不用 CPU closure 冒充 display list；否则捕获对象生命周期、动态状态和异常语义不可控。
- 不把 display list、GPU layer、raster cache 混为一谈；轻量命令边界可以较多，纹理层必须稀疏且受预算约束。
- 不要求用户声明 `@Stable` 才正确，也不让遗漏 revision 静默成为唯一正确性来源。
- 动态分支重建后必须替换依赖集并释放旧订阅；失败执行不能污染已提交图。
- damage 必须覆盖旧/新 paint bounds、阴影与越界绘制，按正确 z 序重放相交内容；不能只画“脏节点自己”。
- 不把计划采用局部更新等同于后端实际采用；诊断和 profiler 只报告后者。
- 不因 benchmark 较快就删除全量回退；像素差分、资源 epoch、窗口变化和异常恢复都是产品契约。
- 不自动给每个节点设 repaint boundary。冗余边界会增加命令、依赖、内存和调度成本，收益取决于父子重绘不对称。

## 下一步：以证据触发，而非继续照阶段清单扩张

1. **先固化当前层。** 保持 package/coverage、SDL、examples 增量/全量像素差分、真实 damage E2E、命令内存
   和 phase3 比例门禁；在 Windows 多个 SDL driver 及 Linux/macOS CI 建立 capability/回退矩阵。旧的短命
   Stack 索引未达阈值而撤销；后来 Element-owned ScenePatch 的 1k 节点尺度实验给出独立收益，才引入持久
   slot-run BVH。后端 partial 条件仍须跨 driver 证据才能扩大。
2. **持续校准已经自动化的边界策略。** 当前以单根、后代总量和最大分支宽度形成确定性候选，明确拒绝“每节点
   一层代理”和深廉价链；诊断输出 layout/paint 命中、command bytes、录制/拒绝/dynamic bypass 与 LRU 淘汰。
   后续只在 examples/bench 证明误升或漏升时调整阈值，应用代码不感知策略变化。
3. **把固定 16px 扩展演进为显式 paint bounds（已实现）。** `PaintOutset(left, top, right, bottom)` 逐分量
   join，shadow 自动从 offset/blur/spread 推导，自定义 Canvas 可显式声明；Scroll/Lazy/Reveal 只在非滚动轴放行，
   ScenePatch replay bounds、Element 空间和 damage 使用同一个值。普通节点不再支付全局余量。
4. **raster cache 仅作为二级、可撤销优化。** 只有真实 GPU profiler 证明“稳定复杂命令反复 replay”仍占预算，
   才按命令成本、稳定帧数和面积提升到纹理；必须有 LRU/显存上限、DPI/字体/资源 epoch 失效、透明混合测试和
   thrash 降级。当前无头数据不能证明需要它。
5. **hit-test 与语义索引分开判定。** 10k 全重叠最深层事件约 64.6 μs，但每个 handler 都可能消费，属于不可绕过
   的 Ω(n) 语义下界；因此不建立假装能消除该下界的全局事件索引。后续稀疏网格实测却显示 10k 节点最深命中
   71.08 μs、访问 10000 个处理器，存在独立的空间剪枝机会；这触发了显式边界契约和容器局部有序 AABB 索引。
   语义动作从最早到最新出现 81.9 μs/88 ns 的纯位置差，重复快照为 2.10 ms，则采用提交期 id 索引。

## 后续实测触发的层次化 ScenePatch（2026-08-26）

短命 Stack 索引失败后，新的实验把优化边界移到持久 Element：每个自动渲染节点拥有代际 `SceneNodeId` 和稳定
`RenderCommandSlot`，父列表只记录子槽引用。直接/传递环、错误线程和跨 Renderer 替换均在 API 边界拒绝；
清空、资源或 epoch 失效会让祖先在任何绘制前整体回退。失败根构建只关闭 staged scene node，已提交 slot
保持不变。

首个三样本中，96×24 命令的父列表重建中位数为 flat 109.38 μs、hierarchical 11.29 μs（9.69x）；稳定重放为
0.532/1.645 μs，层次间接开销约 1.11 μs。48 区普通 Widget 的单区域 patch 为 356.98 μs，强制全树为
2.470 ms（6.92x），绘制叶访问 8/384。与旧 damage 实验不同，这次收益来源、额外成本和适用边界均被同场景
A/B 分离，因此层次命令槽进入内核。

随后完成的空间索引纵切面把含阴影余量的布局边界固定在 slot 身份上；几何变化换新 slot，避免旧祖先复活后使用
过期边界。连续 slot run 在录制时建立保持声明顺序的持久 BVH；damage 只预验证并重放相交前沿，无边界时回退
线性路径。最新三样本的 96/256/1024 子树单区域查询中位数为 0.105/0.136/0.122 μs；1024 子树同机线性版本
为 19.65 μs，约慢 161x，而索引查询没有随节点数四倍增长。同期 96×24 父列表重建仍有 7.77x 收益，稳定重放
只增加约 0.95 μs；48 区普通 Widget patch 对强制全树为 382.39 μs/2.502 ms（6.54x），访问数保持 8/384。

## 后续实测触发的语义提交日志与 adapter（2026-08-26）

平台辅助技术不是偶尔读取一次快照：它需要按 id 查询、执行动作并订阅结构/属性变化。旧实现把 retained
`SemanticFragment` 的扁平化推迟到每次查询，动作又从最新贡献反向扫描；10k 节点最早动作为 81.9 μs，重复
快照为 2.10 ms，而最新动作仅 88 ns，证明成本来自数据结构而非业务闭包。

新实现把稳定布局视为事务边界：fragment 的结合 monoid 在提交时归一化为唯一 id 序列，生成单调 revision 和
Added/Removed/Updated/Moved change-set；动作和节点各有 HashMap 索引。provider 属性读取使用独立 State phase
依赖，动态 checked/value 能更新 adapter 而不让 layout 失效。稳定 fragment 序列以对象身份短路；三样本中 10k
最早动作/快照为 55/4 ns，稳定语义帧 75.47 μs，对照同构空节点 76.82 μs。`AccessibilityUpdate` 的动作入口
委托最新提交索引，因此 adapter 保存旧 patch 也无法调用卸载目标。

Windows 原生纵切面现已实现真正的 `WM_GETOBJECT`、`IRawElementProviderFragmentRoot`、fragment navigation、
point/focus 查询、Invoke/Value/Toggle pattern 与 UIA 结构/属性事件。COM provider 只保存单调 UInt64 token 和
共享不可变快照，不持有仓颉 GC 指针；跨线程动作进入 1024 项有界队列，再由 SDL 用户事件唤醒 UI 线程执行。
关闭窗口会恢复 subclass 并 `UiaDisconnectProvider`，slot/id 重用也不会复活旧 provider。
动态加载还在调用 `create` 前核对 ABI version 与两种跨语言结构的 size/alignment 指纹；不兼容 DLL 被卸载，
避免“符号仍存在但字段布局已变化”造成的静默内存破坏。
[Microsoft server-side UIA provider](https://learn.microsoft.com/en-us/dotnet/framework/ui-automation/server-side-ui-automation-provider-implementation)

10k 真实 SDL 窗口门禁先预热自动晋升，再取 5 帧语义阶段中位数；最近一次为 0.1 μs且原生 revision 不变，证明
稳定帧没有重复封送。首次 10k 发布为 53.3 ms；文本在原生快照中保持 UTF-8，只在 UIA 属性查询时转 UTF-16，
并直接消费语义父索引，避免提交期 20k 次重复哈希。独立进程 UIAutomation 客户端的 200 次属性查询 P50 为
0.104 ms，Invoke 经 COM、队列、UI 事务和属性更新的完整往返为 22.783 ms。

后续拓扑反例发现，`Moved` 只比较扁平声明索引仍不完整：节点可保持相同数组位置却从一个语义父节点换到另一个，
此时旧 patch 只发 `Updated`，Windows UIA 不会把它识别为结构变化。可访问树本来就是 Element 父子范畴把“无语义
输出”的对象收缩后得到的商树；因此变更不仅要比较对象顺序，还要比较投影后的父态射。

新实现给 `ElementArena` 增加单调结构 revision，只在成功 mount/release/clear 时推进。语义稳定快路现在同时要求
provider 未脏、fragment 引用序列相同、焦点相同且 arena revision 相同，仍是 O(1)；revision 变化时才重新投影
商树，并以父语义 id 比较拓扑。父节点变化会发 `Moved(id, oldIndex, newIndex)`，即使两个索引相等。三条反例分别
覆盖同索引重挂接、失败 release 不推进 revision，以及相同 `SemanticRegistration` 序列在 owner 释放后必须绕过
旧快路。五个独立 10k headless 进程中位为首次提交 16.052 ms，稳定语义/同构空树 72.05/77.92 μs，未观察到
可辨认附加成本；点查询/焦点查询/快照为 121/50/4 ns。Windows UIA 独立客户端继续通过，属性 P50
0.065 ms，Invoke 往返 38.261 ms。

## 后续实测触发的有界事件空间拓扑（2026-08-26）

完全重叠探针只能证明最坏语义下界，不能代表 Grid/VStack 中大量互不相交的控件。新增稀疏探针后，1k/10k
最深命中分别为 7.396/71.08 μs，并访问 1000/10000 个 handler。框架因此新增默认 `Unbounded`、显式
`LayoutBounds` 的 `PointerEventScope`；默认值保留自定义全局处理器，标准 Button/IconButton 和可证明安全的
自定义子树可进入空间剪枝。

`VStack`/`HStack`、Grid、FlowRow 与 ZStack 在 layout 提交时按连续 z 序构建平衡 AABB union 树，点查询右子树
优先，消费顺序与原逆序循环一致。分支含任意 `Unbounded` 叶时不可整体剪枝；活动 press/drag 时退回全量路由；
全兼容容器不构建树。索引按 layout 事务提交，相同子矩形与 scope 重复 layout 时复用已提交节点。最终三样本中位
的 1k/10k 稀疏命中为 0.455/0.560 μs且各访问 1 个候选，分别约 16.3x/126.9x；10k 完全重叠仍访问 10000 个，
中位 66.37 μs，对原 62.37 μs 基线增加约 4.0 μs。10k 稳定布局的无界/有界提交为 638.23/652.03 μs，增加
13.8 μs（约 2.2%）。门禁同时断言候选数、5 μs 查询上限与稳定提交不超过 50 μs 的绝对附加成本。

## 后续实测触发的语义空间与焦点索引（2026-08-26）

原语义快照虽然已有 O(1) id/action 索引，但 Windows UIA 等原生 provider 还需要 point/focus 查询。10k 个稀疏
语义节点的线性 point query 三样本中位为 17.89 μs，且 ScrollView 外的原始布局边界会错误命中不可见节点。

提交事务现在同时生成保持声明/z 顺序的 AABB union 树；查询右子树优先，使用祖先 ScrollView、Lazy 容器和
Reveal 组合后的 `visibleBounds`，零面积节点不参与命中。该树与事件索引共享结合的 ordered spatial branch
聚合，但不共享叶策略：语义返回最上层节点，事件仍处理 unbounded、capture 和消费顺序。10k 查询中位降至
138 ns（约 130x），1k 为 81 ns，均低于 2 μs 门禁。

语义归一化还保存代际 Element owner，提交后把节点分组挂入 `ElementSpaceFacet`。焦点注册同步维护 key→target
与 key→index；`focusedSemanticsNode` 通过 HashMap 和 owner generation 校验返回节点，10k 中位为 40 ns。
10k 稳定语义帧为 68.73 μs，同构空节点为 66.41 μs，额外约 2.32 μs，没有把查询收益转移为每帧全树税。

## 后续实测触发的 Element 空间几何与双域 clip（2026-08-26）

Scene 原先在 `ElementSceneNode` 内另存 layout/observed paint bounds，语义可见域在 `UiContext` 临时栈中，滚动
容器又分别为 draw 和 pointer 重写同一矩形。更严重的是自动布局缓存只比较 child rect：内核复现中 rect 保持
100×100、祖先 clip 从 40 扩到 60 后，缓存仍重放 `visibleBounds.bottom=40`。

新实现把每个代际 Scene slot 的 layout、visible、paint bounds 和空间 revision 移入 `ElementSpaceFacet`，读取
返回不可变 `ElementSceneSpaceSnapshot`；命令槽只负责内容与 replay。`SpatialClip=(visible, paint)` 明确区分
无障碍/输入的精确 viewport 和阴影安全绘制域，嵌套组合为分量矩形交。ScrollView、LazyColumn、LazyRow、
LazyList、Reveal 的 layout、pointer gate 与 draw 使用同一 clip 值，push/pop 由异常安全作用域管理。自动布局
缓存键加入祖先 visible clip，clip-only 变化只重算 layout fragment，不失效仍可复用的 paint commands。

迁移前后三样本同场景 A/B：96 子树层次父列表重建 14.86→14.84 μs，稳定层次重放 1.479→1.469 μs，1024
子树单区域 damage 121→122 ns，48 区单区域 Widget patch 402.74→385.00 μs，均未出现有意义退化。10k 语义
复验的稳定语义/空节点帧为 68.08/70.30 μs，点索引/焦点查询为 150/46 ns。最终内容滚动
三样本中，12/48 区 LazyColumn 为 124.46/145.19 μs，低于仓库基线 620.85/714.21 μs；48 区对同帧未窗口化
路径保持约 9.1x 优势。专项门禁同时约束绝对预算和窗口化相对收益。

## 后续实测触发的显式 PaintOutset（2026-08-27）

固定 16px cross-axis clip 无法同时满足两类界面：无阴影节点被无谓放宽，而 blur/spread 大于预设的 Canvas/卡片
仍会被截断；Scene replay bounds 与 retained damage 又各自再扩一次常量，形成多套不一致的保守域。

新 `PaintOutset` 是四方向非负值，合成取逐分量最大值，因此构成 join-semilattice；`expand(Rect)` 是非对称
Minkowski dilation。shadow modifier 按实际 offset、blur、spread 推导，focus leaf 保留 4px，theme 延迟解析的
Panel/ReorderableList 才使用 16px 最大 fallback。Stack/Grid/Flow/ZStack、单子 wrapper 与 automatic/retained
边界都转发或聚合；Scroll/Lazy/Reveal 在滚动轴保持精确 clip、只在交叉轴应用声明。Element 空间同时保存声明域
与录制命令实测域的 union，几何变化会清除旧 observed bounds，陈旧 halo 不会污染新 slot。

正确性用例覆盖 24/12/32/20px 非对称大 overflow、零声明精确 clip、nested Stack 聚合、Reorderable row 和
Scene generation 更新。10k 强制全量同构树三轮中，零值/大非对称值 P50 的额外成本约 4–8%（约 50–100 μs），
低于 25%/50 μs 门禁；内容页同机临时切换固定实现后，显式版本的 Lazy/未窗口化成对比率中位数反而低约
7.2%（12 区）和 8.7%（48 区），绝对值没有一致退化。ScenePatch 复验仍把 48 区单区域更新从 2.931 ms
降到 0.291 ms（约 10.1x），访问 8/384；1024 子树单区域 damage 为 139 ns。

## 后续实测触发的 Element-owned 事件提交日志（2026-08-27）

事件 AABB 树原先随短命容器对象保存；虽然查询已是 `O(log n + k)`，其身份、释放和 Scene/semantics 空间提交仍
彼此独立。直接把“当前活动 Element”作为 owner 又会让未晋升的嵌套容器共享最近祖先，因此绑定增加了严格
条件：只有 `AutomaticRenderNode.child` 与发起布局的 Widget 引用相同，才能取得该节点的 `SceneNodeId` slot；
VStack/HStack 由外层 facade 显式传递身份，其他容器直接绑定，无法证明时保留 detached 回退。

`ChildEventTopology` 现在生成不可变 `ElementEventTopologySnapshot` 与单调 revision，并由
`ElementSceneSpaceSnapshot` 聚合。它内部以 committed/pending 双缓冲分离事件读取面与布局写入面：普通即时容器在
`commitLayout` 后立即交换，Element-owned 容器只把 pending 标成 ready，最终由外层 `ElementLayoutCommit` 提升。
因此不只是 child count 改变，连相同容器的移动、失败布局和布局阶段 State 自写都不会改写当前 dispatch 使用的树。
Automatic child 稳定更新为非容器时通过同一布局提交清除旧 topology；Scene/generation release 同时关闭其索引，
陈旧引用不能查询或 dispatch。

迁移前后三样本/最终七样本中位：10k 稀疏命中 594→614 ns且仍只访问 1 个叶，完全重叠最深命中
68.21→68.03 μs且仍访问 10000 个处理器，最上层命中 340→358 ns。10k Element-owned 稳定布局为 1.03 μs；
detached 30 帧最近一次 P50 为无界 628.5 μs、有界 618.3 μs。查询的代际安全成本约 20 ns，稳定 retained 帧因
Automatic layout hit 无需再次提交 10k 节点。提交门禁改用逐帧 P50，平均值仍报告以暴露长尾。

## 后续实测触发的显式 retained Scene 所有权统一（2026-08-27）

审计发现 Automatic proxy、显式 `RetainedRecord` 与 Element scene 同时强引用同一命令缓冲，并各自保存布局矩形
和 paint bounds；显式 retained 的 layout hit 还没有把祖先可见域纳入键。新实现把两种持久边界都投影到唯一的
代际 scene/space：layout key 是 layout/visible/declared-paint 三元组，命令、实测 paint bounds 与统计只由 slot
持有。显式 retained 在祖先录制中发布一个 `ReplaySlot`；slot 关闭、资源失效或 generation 变化会在任何绘制前
使祖先验证失败，不需要手工递归清除每份扁平副本。

层次化后，一个直接命令很少的父缓冲可能代表大型子图。旧“至少 24 条直接命令”启发式会把 1 条 scene 引用
误判为廉价叶子，因此缓存价值函数改为“直接命令达阈值 **或** 包含稳定 scene 引用”，而预算继续只计算本层
增量字节，避免对子图重复计费。负向测试验证关闭 slot 后旧父列表不可重放；viewport 40→60 而 rect 不变时，
显式 retained 语义 visible bounds 也随之更新。

同机迁移前三样本中位：retained revision 命中 70.67→69.39 μs，每帧 revision 变化 3.137→3.152 ms；前者约
改善 1.8%，后者约 +0.5% 且处于调度噪声。自动显示列表仍为 3.30 μs 对直绘 56.90 μs；最新 48 区 patch
访问保持 8/384，帧耗时 0.309/2.570 ms。

## 后续实测触发的 Element-owned 测量环境（2026-08-27）

所有权审计继续发现 Automatic proxy 与显式 `RetainedRecord` 各保存一份
`measuredAvailable/measured/measureValid`。更严重的是，两份缓存都只比较 offered `Size`：同一上下文把
`fontScale` 从 1 改为 2，或把同一 retained 节点交给不同 Renderer 时，仍会返回旧尺寸；Stack、Label、
RichText 的实例内缓存还会在外层重测后再次遮蔽环境变化。先加的 5 个用例在旧实现上全部失败，原有 560 个
用例仍通过，证明这是独立的真实缺陷而非测试扰动。

新键把环境乘积 `(UiContext renderer/theme identity, displayScale, fontScale, Fonts.revision)` intern 成进程唯一
generation，再与 offered `Size` 组成 Element measure key。scale 变化立即推进 generation；全局字体注册表在
frame setter 处标记待采样，并由本帧第一次测量固定快照，后续所有节点只比较一个 UInt64。这同时给出事务语义：
同一 measure→layout 提交观察一个环境，失败测量不覆盖旧 memo，测量中写 State 的结果不能提交。Measure miss
只向 Layout/Paint 单向失效，开发者无需监听 DPI、无障碍字号或字体注册事件并手工清缓存。
测量也进入 `ElementSceneSpaceSnapshot` 的不可变 `ElementMeasureSnapshot`：稳定替换一次推进 space revision，
失效发布 `None`，失败路径不产生中间修订，诊断读取和运行时命中消费同一个提交事实。

最终增加 9 个专项用例，覆盖 Automatic/retained 的 scale 与 Context 身份、Stack 内层缓存、Label/RichText
跨 Renderer、失败测量回滚、测量期 State 自写、no-op scale setter 以及不可变 Element 测量快照。GUI 全量
569/569 通过。隔离五样本
retained hit 最终中位为 64.51 μs，对迁移前最近 69.45 μs 约改善 7.1%；miss 为 3.264 ms，对 3.190 ms 约 +2.3%。
这属于用极小冷路径成本换取跨 DPI/Renderer 正确性，同时热路径因去除 proxy 重复字段反而改善的综合正收益。

基准审计还发现旧深层布局稳定样本只有约 5–20 ms，且未像注释声称的那样先执行根 measure。现已按真实
measure→layout 协议预热，并把每个计时窗口延长到约 100 ms 以上；retained hit/miss 也可用独立进程参数分别
采样，避免前一场景的 GC/温度状态污染后一场景。

## 后续实测触发的 Element-owned 原子布局提交（2026-08-27）

继续审计发现 `AutomaticRenderNode` 与 `RetainedRecord` 仍各自保存
`layoutValid/layoutOverlays/layoutSemantics`，而 Element 只保存几何。旧实现的布局 State 自写虽会把 proxy 标为
dirty，却仍在收集结束后写入 Element 几何；Automatic 与 retained 两条路径均可观测到未提交矩形。布局键也不含
`UiContext` 身份，导致 cached `SemanticRegistration` 的失效闭包跨 Context 复用：旧 Context 卸载会关闭新
Context 仍在消费的 State dependency。再加上环境改变但 rect 不变时旧 paint commands 仍会重放，五条行为断言
在旧实现上全部失败。

新提交值建模为 `Geometry × UiEnvironment × Overlay* × SemanticFragment`。这是普通积类型，不把抽象泄漏给
Widget 作者；后两项分别是按声明序连接的自由幺半群与 fragment 结合幺半群。只有 `PhaseStateDependencies`
完成且未自失效时才发布整个积，失败尝试保留旧提交；Measure→Layout 的失效偏序由 Element 自身执行，发布新
measure 或撤销 measure 会在同一 space revision 中撤销 layout validity。`UiEnvironmentKey` 把 Context、
Renderer/Theme、display/font scale 与帧稳定字体表 intern 为单个 generation，所以热命中仍只多一个 UInt64 比较。

环境 miss 但几何相同时也撤销显示列表，这是必要而非保守浪费：绘制命令和 semantic provider 生命周期都可能
依赖环境。最终新增 5 个专项用例，布局相关套件 30/30、GUI 全量 574/574。最终串行五样本中，10k 首次语义
提交中位 20.94 ms、稳定语义帧 71.75 μs（修改前 23.50 ms/71.79 μs）；retained hit/miss 为
63.92 μs/3.264 ms（前一轮 64.51 μs/3.264 ms）。自动脏分支、显示列表和稳定兄弟访问数保持
1/240、0/96、0/24。

## 后续实测触发的布局—事件同一提交边界（2026-08-27）

上述原子布局提交落地后继续做反例驱动审计，发现事件拓扑仍有一条旁路：容器在 `layout` 内调用
`ChildEventTopology.commitLayout`，旧回调会在 `PhaseStateDependencies.collectionWasInvalidated` 被外层检查之前
推进 Element event revision。更隐蔽的是容器会长期保存这个 topology 引用，所以只延迟
`ElementSceneSpace.childEventTopology` 的指针替换仍无法阻止事件处理读到半提交对象。旧实现上的新增断言稳定复现：
`layoutCommitted=false`，但 snapshot 已出现新 event topology。

现在 `ElementLayoutCommit` 扩展为
`Geometry × UiEnvironment × Overlay* × SemanticFragment × EventTopologyΔ`，其中
`EventTopologyΔ = Preserve + Replace(Topology) + Clear` 是一个显式和类型。`ChildEventTopology` 的 pending buffer
只接受 `beginLayout → note* → commitLayout` 写入；Automatic 路径把完成的 buffer 作为 `Replace` 携入外层提交，
依赖稳定后才做 O(1) buffer swap。状态自写、异常或取消通过 `finally` 丢弃 pending；读面继续指向上次提交。
非容器清理也用 `Clear` 进入同一和类型，不再先行修改场景。这里使用积、和与有序聚合的原因是它们直接给出
“任何分量都不能单独可见”的可测试组合律；没有把范畴论或同调术语装饰性地暴露给 Widget API。

首版双缓冲在稳定拓扑上仍重建 10k 节点 AABB 树，事件基准立即触发 50 μs 附加成本门禁；实现据此恢复
“逐叶精确比较，无变化即短路”，只有真实变化才构建 pending 索引。最终新增 3 个事务专项用例，GUI 全量
577/577。串行五个通过样本中位：10k 稀疏命中 650 ns、完全重叠最深命中 67.08 μs、最上层命中 292 ns，
Element-owned 稳定布局 858 ns；detached 无界/有界提交的逐帧 P50 为 632.4/639.6 μs，附加约 7.2 μs，明显低于
50 μs 门禁。一次额外样本受 Windows 调度漂移触发相对门禁，查询/Element-owned 指标仍正常，因此保留原门禁并
以五个完整样本报告中位，不用放宽阈值掩盖噪声。

## 后续实测触发的持久焦点声明片段（2026-08-27）

焦点查询此前已有 key→target/key→index 哈希表，但稳定提交仍是线性的：每帧 `FocusRegistry.clear()`，每个干净
Automatic/retained 记录逐项重放 `FocusTarget`，随后 `UiContext` 再清空并重建两张表。新增行为反例证明同一干净
根连续 adopt 会把 focus graph revision 从 1 推到 2；这意味着“查询 O(1)”掩盖了“稳定提交 O(n)”。

新 `FocusSnapshot` 保存 `(declarations, normalizedTargets, keys)`。`declarations` 是自由幺半群的一个持久片段，
`normalizedTargets` 是 first-key-wins 商映射的结果。空 registry 直接采用片段对象；相同对象提交到 `UiContext`
时不复制数组、不清哈希表。只有片段前后还有声明、显式 key 改写或禁用删除时才把声明日志物化，然后按原顺序
重新归一化。这不是全局哈希捷径：原始声明仍保留，所以跨片段重复 key、Modal 切片和局部脏分支都可组合且可测试。

最终增加 3 个焦点专项用例，覆盖 Automatic/retained 稳定身份、干净—脏—干净片段顺序和跨片段重复 key，GUI
全量 580/580。`focus-scale` 每个样本预热后测 30 个稳定帧；五样本中 10k focusable/同构无焦点树 P50 中位为
12.883/12.918 ms，焦点树没有可辨识的稳定帧附加成本，`focusNext` 为 52 ns。最关键的确定性门禁是两种 10k 树
连续 30 帧的 focus graph 提交数都精确为 0；修改前反例每次稳定 adopt 都推进 revision。10k 全量焦点重建五样本
中位为 11.53 ms，对本轮修改前 11.10 ms 的单样本约 +3.9%，属于真实拓扑改变的冷路径和调度噪声量级，没有用
稳定路径收益掩盖查询或重建退化。

## 后续实测触发的声明重放半格（2026-08-27）

自动组合命中原先只要看到任意 retained/effect key 就保守拒绝，因此 `mountEffect` 或只带 key 的
`RetainedSubtree` 即使语义完全稳定，也会让整个自动祖先每帧重放。新增红测试先证明连续两个干净构建的组合体
执行数为 2；128 个静态声明的 500 帧隔离基线为 38.38 μs/帧、精确 1 次组合体执行/帧。

现在每条声明映射到二元半格 `Replay = {Static ≤ ExternalRevision}`：`mountEffect` 与 key-only retained 为
`Static`，显式 revision API 为 `ExternalRevision`；作用域的声明序列通过 join（布尔 OR）折叠。该折叠是声明连接
幺半群到 replay 半格的同态，所以无需保存每条额外分类，合并顺序也不影响安全性。两个分类位保存在 build-local
事务，只有完整根构建成功才替换已提交值；State 脏传播仍负责条件删除、卸载与重挂载，普通外部 revision 则继续
强制父作用域访问。

修改后同一命令中静态路径为 4.50 μs/帧、精确 0 次组合体执行/帧，单样本约 8.5×；外部版本路径仍精确为
1 次/帧。测试覆盖静态 effect、key-only retained、普通字段 revision、State 条件卸载/重挂载以及失败构建不能
降级已提交重放要求。时间值用于量级观察，确定性的 0/1 执行次数才是回归门禁。

## 后续实测触发的持久 Frame 订阅片段（2026-08-27）

稳定 Automatic/retained 记录虽已保存 Frame 订阅，旧实现仍在每次命中时把每个 `FrameSubscriber` 追加到
`ArrayList`，派发前又 `toArray()` 复制一次。512 个空回调的单样本总帧为 11.21 μs，对 0 订阅 5.65 μs，说明
必需回调遍历之外还有显著注册簿维护成本。

订阅序列没有 key 商映射，直接是按声明顺序连接的自由幺半群。新增不可变 `FrameSubscriptionSnapshot` 与
build-local registry：空 registry 对一个干净片段 O(1) adopt；新声明或多个片段连接时才惰性物化；最终派发直接
遍历已采用快照。片段创建计数是单调诊断量，512 订阅稳定帧必须精确为 0，避免只凭耗时误判实现是否生效。

修改后五个暖样本的 0/512 订阅中位为 5.81/7.16 μs；相对 0 订阅的增量从修改前单样本 5.57 μs 降至约
1.35 μs，总帧相对原 512 样本降低约 36%。回调仍每帧按原顺序执行，失败构建只清空 build-local registry，
已提交 Automatic/retained 记录继续持有旧快照。

## 后续实测触发的有序 Overlay 商映射（2026-08-27）

Overlay 栈原先为保持 z 序使用单个 `ArrayList`：每个 keyed 注册都从头寻找 owner，事件快照的每一项又线性确认
仍在栈中。`overlay-scale` 的 1k→4k 基线注册为 3.357→48.701 ms，未处理事件为 0.731→10.729 ms，4 倍数据带来
约 14.5/14.7 倍时间，确认两条路径都是二次复杂度而非计时噪声。

新 `OverlayRegistry` 把声明看作保持顺序的自由幺半群，再以“同 owner 最后声明原位覆盖”取商；有序 active 数组
与 owner→index 映射是这个商的规范形。注册与事件成员验证因此为均摊 O(1)，删除后只重索引其右侧后缀。布局提交
进一步保存不可变 `OverlaySnapshot`；空 registry 可 O(1) adopt，只有片段连接、动态追加或事件中关闭才写时物化。
空 overlay 使用 `None`，避免让普通 Element 为该优化付空对象分配。

最终五个暖样本中，1k/4k keyed 注册中位为 49.47/421.51 μs，未处理事件为 24.64/101.91 μs；相对最初 4k
基线分别约改善 115×/105×。4000 overlay 稳定帧从仅有 owner 索引时的单样本 129.78 μs 降至五样本中位
25.51 μs，且稳定 120 帧逐项 fragment replay 精确为 0。测试覆盖原位替换、删除导致的索引位移、派发中删除
跳过旧快照项、绘制中动态追加、retained replay 与跨片段 owner 冲突。

## 后续审计移除的 Automatic 焦点死投影（2026-08-27）

持久 `FocusSnapshot` 落地后，`AutomaticCompositionRecord` 仍保存 `focusableIds`，每次脏重建都递归调用所有输出
Widget 的同名方法；引用审计证明该字段只有构造/替换写入，没有任何读取。这不是兼容层：真正被
Reveal/Lazy/disabled/EventListener 使用的是 Widget/RetainedRecord 自己的局部焦点元数据，automatic 私有记录中的
副本是不可观察的死投影。

新增带副作用的 legacy metadata probe 先证明两次脏构建会错误查询两次，再删除 Record、PendingReplacement、
reconciliation 后处理之间的整条数组流。`focus-scale` 进一步用 10k 自定义输出建立确定性门禁：脏 automatic 构建
的 `focusableIds()` 查询必须精确为 0；真实 10k focusable 注册重建仍约 11.35 ms、`focusNext` 51 ns，稳定焦点图
提交保持 0。时间样本受 Windows 调度影响，没有把不可分辨的差值宣传成收益；确定性结果证明 10k 次虚调用与
短数组分配已从算法中消失。

## 后续实测触发的 EventListener 自适应焦点集合（2026-08-27）

`EventListener(scope: Subtree)` 对键盘、Text 和 IME 事件原先逐项调用 `ctx.hasFocus`。这在单按钮包装中合理，
但 10k 焦点子树的最后命中/未命中基线达到 345.34/204.01 μs，每个按键都重复线性扫描不变数组。

实现保留原 `focusIds` 数组用于透明 Widget 转发，并增加阈值为 8 的自适应成员表示：小集合继续线性查询、没有
HashSet 分配；大集合构造一次索引，事件用当前 public `focusId` 做均摊 O(1) membership。该变换是有限集合的两种
等价表示，不改变声明顺序、重复 key、focused/unfocused 或 listener phase/effect 语义。

修改后同一 10k 场景最后命中为 48 ns、未命中 20 ns，分别约改善 7195×/10200×。`event-scale` 对两者设置
2 μs 上限；测试同时覆盖小数组和大索引的命中/未命中，并断言 `focusableIds()` 仍原样转发。

## 后续反例触发的 EventListener generational 目标（2026-08-27）

性能索引仍暴露一个身份漏洞：监听器内外若声明相同显式 key，全局焦点图按 first-key-wins 选中外部控件，但内部
Listener 的字符串集合也包含该 key，键盘事件会错误进入不拥有焦点的子树。新增 WidgetTestHost 反例先稳定复现
该误路由。

body 型 Listener 现在以构建前后的声明计数截取 `FocusSnapshot.targets`，小片段直接比较 target，大片段建立
`key → FocusTarget` 映射；`UiContext` 用已解析的 focused target 同时比较 Element slot、generation 和 key。
因此同名字符串不再跨所有权边界别名，Automatic 缓存命中仍复用原 target，真实内部焦点保持可达。fluent
`.onEvent` 包装已发射 Widget 时无法重新捕获过去的声明，暂时保留字符串兼容路径，避免伪造 detached owner 或
破坏公开链式 API。10k 兼容基准仍为 372/58 ns并通过 2 μs 门禁；新增正/负用例分别看护内部命中与外部同名拒绝。

## 后续完成的 emission 焦点 facet 与声明身份（2026-08-27）

仅有 Element owner 仍不足以修复 fluent `.onEvent`：同一 automatic scope 内的两个兄弟共享 ElementId。新的
`FocusTarget` 因此加入注册时 `declarationId`；控件自动 identity 是内部身份，`.key()` 只改 public key 并保留它。
目标相等现在是 `(Element generation, declarationId, public key)` 的积，既保留易读 API，又能区分同 scope 同名兄弟。

builder 的 open block 保留最后 emission 与 FocusRegistry 声明日志的 `[start,end)` 区间，modifier 替换继承该区间。
首版曾为每个输出追加 range，`focus-scale` 立即显示 1k 重建中位约 0.78→0.89 ms；实现据此收敛为每 block 一个
last-emission facet。为防 `.key` 重写和 disabled 删除使区间漂移，build-local 声明日志使用位置稳定的稀疏
tombstone；只有首次删除才创建 inactive 集，正常注册仍为单数组热路径。这样 fluent wrapper 可按需取得精确
fragment，没有“猜最近 N 条”的启发式，也不让所有 Widget 承担元数据数组。外部构造后再存储、非紧邻修饰或在
另一 build 中重新 emit 的 Widget 没有可证明区间，明确回退既有字符串兼容语义。

新增反例覆盖同 scope 外部/内部重复 key、显式 rekey 后 identity 保留，以及 disabled tombstone 不复活；body 与
fluent 两种 Listener 均在 Automatic 缓存第二帧保持 owner 精确。全量焦点测试与 10k 事件门禁继续通过。
最终五样本 10k focusable 重建中位为 10.58 ms，低于本轮修改前最近 11.32 ms 单样本；1k 中位约 0.92 ms、较近期
0.78 ms 有小幅开销，换取 fluent 重复 key 的确定性正确性，且未把不同采样口径包装成普遍加速。

## 后续实测触发的 State 无复制通知窗口（2026-08-27）

`State.notify` 原先每次写入先把全部 listener `toArray()`，回调后再反向扫描压缩；这让 UI 依赖追踪、派生状态和
业务观察者共享的高频原语在每次赋值产生一个 O(n) 临时数组。新增独立 `state` 场景先以精确回调数看护工作量，
五个暖样本中 1/256 个观察者的修改前中位分别为 699 ns/11.38 μs。

新模型把监听表视为有序自由幺半群。一次派发只捕获入口长度 `n` 并访问活动投影的前缀；注册是尾部连接，取消
是幂等 tombstone，最外层派发退出后再取保序商。这个模型同时给出可重入语义：新增项不进入当前前缀，却会进入
随后嵌套赋值捕获的新前缀。`notificationDepth` 禁止活动窗口期间移动下标，`finally` 保证回调异常也会恢复深度
并压缩；没有取消时不分配、不复制，也不额外扫描。

修改后同口径五样本中位为 471 ns/2.70 μs，约改善 1.48×/4.21×，256 个观察者的 20000 次写入仍精确执行
512 万次回调。测试另覆盖通知中同时取消/注册、同源嵌套赋值的内外窗口、异常后的 tombstone 清理，以及既有
transaction、`DerivedState` 与线程封闭契约。

## 后续反例触发的 State 观察者异常隔离（2026-08-27）

无复制窗口的 `finally` 能恢复自身结构，却仍保留旧有 fail-fast 行为：若业务 observer 排在
`PhaseStateDependencies` 之前并抛异常，后面的框架 listener 不会收到变化，State 已更新但对应增量 scope 仍可能
保持干净。新增反例在旧实现上稳定得到 304/305，证明这是可见正确性缺陷而非理论担忧。

派发现在记录首个异常、继续按窗口语义调用其余活动观察者，完成最外层 tombstone 压缩后重抛首个异常。错误没有
被吞掉，也不能再饿死依赖失效。抽取异常调用边界并通过 L2 嵌套门禁后，最终五样本正常路径中位为
455 ns/2.78 μs；相对无复制版先前的 471 ns/2.70 μs，单观察者没有可辨认退化，256 个约增加 2.9%（每回调
约 0.3 ns）。相对最初快照复制版仍约改善 1.54×/4.09×，因此接受这项有明确正确性收益的微小开销。

## 后续反测收敛的 DerivedState epoch 证书（2026-08-27）

旧 `DerivedState` 即使稳定命中也每次创建完整 source revision 数组。新增隔离 `derived` 场景用精确 compute 次数
证明缓存确实未重算；五样本修改前 1/256 源中位为 221 ns/27.30 μs。第一版复用双缓冲 revision 向量并未带来
预期收益，256 源后测约 29.55 μs，退化约 8%，因此没有以“零分配”名义保留。

最终实现把内置 State 图的全局写入 epoch 用作否定证书，而非全局失效信号：epoch 相同可证明所有 State-backed
源未写入，直接 O(1) 命中；epoch 不同仍采完整 revision 向量，只在真实源变化时重算。自定义 `Observable`
没有内部证书，始终走精确向量路径。revision 样本只在 compute 成功后提交，异常和 compute 内源自写均由测试
看护；当时 active phase/build 收集器里的缓存命中仍递归登记上游 State，防止查询优化删除依赖边。

数组源在创建时快照，使派生成为固定积上的映射，调用方数组后续变异不再让计算、revision 与 observe 拓扑分叉。
最终五样本 1/256 源稳定读取中位为 144/149 ns，约改善 1.53×/183×；稳定期 compute 精确为 0，逐次失效重算
维持约 0.69 μs。测试覆盖自定义 Observable 回退、Derived/Binding 能力传播、依赖收集重登记与源拓扑快照。

## 后续实测触发的一等 Derived 依赖节点（2026-08-27）

epoch 证书解决了 collector 外的稳定读取，但真实 Full `WidgetTestHost` 反测显示，稳定 1/256 源派生仍分别提交
1/256 条 State 边，五样本重登记中位为 8.29/70.61 μs。compute 精确为 0，故增长来自 collector 的 HashSet、
pending 列表和逐 State 订阅协调，而不是业务计算。

新 `ObservableReadDependency` 允许作用域直接拥有稳定 `DerivedState` 节点。该节点具有进程唯一 identity，边首次
建立时只连接 invalidation-only 上游：State/Binding/嵌套 Derived/自定义 Observable 的变化向下传播脏信号，
绝不在 setter 内执行派生 compute；值仍在下一次读取时按 `capture → compute → commit` 求出。连接部分失败会
逆序回滚，失败 collector 只关闭 staged 边，卸载关闭整棵失效订阅。

直接按实例聚合曾暴露生命周期反例：声明 body 内每次新建的短命 Derived 会令 N 条上游监听每帧拆装。最终采用
寿命自适应正规形——collector 外创建的稳定实例取“单 Derived 边”商，collector 内创建的 State-backed 临时实例
保留可按 State identity 复用的源前沿；自定义 Observable 因没有 State collector 通道始终聚合。首读还跳过了
已有 revision/value 采样会覆盖的重复登记遍历。

最终五样本 1/256 源稳定重登记为 7.48/6.86 μs，边数均为 1；256 源约改善 10.29×。collector 外缓存命中也从
本轮前 155/164 ns 降至 133/138 ns。逐次失效重算从约 0.71 μs 增至 0.79 μs（约 11%、绝对 79 ns），属于为每次
读取识别 active collector 支付的有界成本。内联 256 源派生为 149.23 μs，手工读取为 63.25 μs、边数同为 256；
该剩余差距如实归因于数组拓扑快照和 revision/value 双采样，作为下一轮融合快照的证据，不宣称已消失。

该证据随后触发融合初始快照：全 State-backed 动态源先固定进程写入 epoch，再在同一源序遍历中取得每项
`revision → value`；直接 State 用一个内部 `(value, revision)` 快照把线程归属和 collector 登记合并为一次。
compute 成功后才提交这组前像，因此 getter/compute 内自写仍在下一次拉取被发现，初始异常不会污染缓存；含
自定义 Observable 的图不融合，以保留原有跨源采样顺序。该阶段五样本内联派生/手工读取为 121.50/63.79 μs，
相对倍数由 2.36× 降至 1.90×，派生自身约改善 1.23×。剩余成本主要是公开数组 API 要求的源拓扑快照、values
数组与 revision 向量所有权，而不是重复 State dependency 检查。

后续按剩余差距加入 `deriveStates(Array<State<T>>)`：源拓扑仍在构造时快照，但 value/revision/失效工厂都保留
静态 State 类型，避免逐元素接口擦除。直接增加同名 `derive(Array<State<T>>)` 会令既有
`derive<Int64, Int64>([], ...)` 在仓颉重载解析中产生歧义，故被反例否决；最终采用独立名称，同时让旧的
`derive(Array<Observable<T>>)` 检测运行时全 State 数组并正规化一次，兼容代码也自动获益。最终同口径五样本中位
为兼容入口 99.34 μs、显式专用入口 93.27 μs、手工读取 58.87 μs；相对 121.50 μs 基线改善约 18%/23%，相对
手工倍数为 1.69×/1.58×。稳定外置 256 源派生仍只有 1 条提交边，中位 6.45 μs。测试看护源数组拓扑快照、计算期
自写、旧空数组调用无歧义以及擦除入口的融合语义。

## 后续人体工学触发的受守卫位置状态（2026-08-27）

显式 `rememberState("key")` 让所有局部状态都要求开发者命名，即使其声明固定且从不参与重排；这与 Compose
`remember`、React hook slot 和 SwiftUI 外置 `@State` 存储所利用的位置身份相比，增加了无业务意义的编码与命名
负担。直接按序号复用又有经典反例：在两个同类型槽之前插入条件槽时，类型检查无法发现状态串位。

最终 API 增加 `rememberState { initial }`，但把位置槽视为一个受守卫的有限积：每个 lexical/automatic 作用域在
首次成功构建后提交槽数和路径向量，后续仍挂载的同一作用域若增减槽数，先拒绝整个根事务，再由既有回滚日志移除
本次新状态，旧 UI 与旧状态不被部分替换。动态内容继续使用显式 key、`Keyed` 或 `ForEach`，整个 keyed 子树消失
属于余积分支卸载而非槽漂移。隐式路径在长度编码中加入显式键无法产生的空段，构成不相交的和类型命名空间。

首版为每个 scope 无条件分配形状表，反测使 240 分支强制重建五样本中位从 1.52 ms 退化到 2.02 ms（约 33%），
因此被否决。最终形状采用惰性 `None | 非空映射`，已提交位置路径用稠密向量持久复用。未使用新 API 的同口径恢复
到 1.51 ms；256 个稳定 keyless/显式键状态的五样本中位为 175.71/172.32 μs，约差 2%，每帧初始化都精确为 0。
因此开发者可以在静态结构中省去字符串仪式，而不让既有应用或稳定重建承担显著成本。

位置状态闭环后，反例进一步表明“能留存任意对象”与“反应图知道它是长期对象”不能分开实现：若简单写成
`rememberState<DerivedState<T>>`，开发者会得到多余可写包装；若通用 remember 只缓存对象，派生构造时仍看到 active
collector，便永久选择短命对象的直接 State 前沿，256 源仍提交 256 条边。最终增加通用 `remember<T>`，并以线程
局部、可嵌套且 finally 恢复的构造动态作用域，把工厂内新建 Derived 标记为稳定聚合节点。该标记只影响依赖表示，
不提前读取或计算值。

最终 Full host 五样本中位为：外置 256 源稳定派生 8.73 μs、remembered 派生 10.64 μs、内联专用派生
102.95 μs、手工读取 63.95 μs；remembered 相对内联约快 9.7×，依赖边从 256 降到 1，稳定期工厂/compute 均为
0 次/帧。测试还覆盖任意对象引用身份、同槽类型漂移回滚、工厂异常不提交、remembered Derived 写入后惰性重算与
Keyed 卸载后上游监听归零。Resource 明确排除在隐式清理之外，继续通过 effect 的 setup/cleanup 事务管理。

随后审计 `StateMountBuild` 的常见路径发现，每个自动 scope 即使只读取一个 State，也预分配容量至少 16 的
`dependencySources` HashSet。最终把 build-local 前沿改为自适应集合：不超过 8 条时直接扫描 canonical dependency
数组，第 9 条才建立索引；这是同一有限集合在线性表示与哈希表示间的单调自然变换，不改变提交顺序、订阅对象或
回滚日志。240 个单依赖分支的局部/强制全量纯 build 五样本中位由 209.60/818.44 μs 降至
191.26/745.10 μs，约改善 8.8%/9.0%。

第一次提升仅按当前小集合分配容量，稳定 1k/10k 宽依赖反而从 307.77 μs/2.863 ms 退化到
404.06 μs/3.420 ms。最终让上次已提交依赖宽度充当容量先验，宽场景恢复到 311.76 μs/2.892 ms，约
+1.3%/+1.0% 且处于调度噪声；1k/10k 依赖计数保持精确。阈值测试覆盖第 8/9 条提升、重复读取、10→8 动态删边
和提升后失败回滚，避免用小集合收益掩盖宽图退化。

进一步发现同一 `StateMountBuild` 还无条件分配 state/retained/automatic/effect 四张 visited HashSet。最终让四类声明
分别复用自己的 canonical 有序 key 日志，小于等于 8 项时线性判重，第 9 项才按上次提交宽度提升索引；类别保持为
不相交余积，跨类别同 path 合法、类别内重复仍失败。相对已经优化 dependency 前沿的版本，240 分支局部/全量
纯 build 从 191.26/745.10 μs 进一步降至 178.45/585.77 μs（约 6.7%/21.4%）；相对最初版本累计约改善
14.9%/28.4%。128 静态/外部版本声明从 6.27/49.64 μs 降到 5.26/45.59 μs（约 16.0%/8.1%）。

## 后续统一身份模型触发的 keyless effect（2026-08-27）

状态与普通对象已经能使用受守卫位置槽，但固定 `mountEffect` / `lifecycleEffect` 仍要求开发者发明字符串键，导致
同一声明作用域存在两套人体工学。简单用 `remember<String>` 生成 effect key 会丢失声明种类信息，并可能让
`remember value ↔ effect` 在槽数不变时静默换位。最终把位置形状提升为带标签的依赖积：每项同时保存持久路径与
`RememberedValue + MountEffect + LifecycleEffect` 种类；值槽另由运行时泛型 cast 验证具体类型。种类漂移在 setup
之前失败，槽数漂移在 ownership commit 前失败。

keyless effect 直接把不相交位置路径送入既有 prepare/commit/逆序 cleanup 协议，不复制资源管理实现。固定声明可
写 `mountEffect { ... }` / `lifecycleEffect(revision) { ... }`，动态条件或列表仍必须使用显式 key 与 `Keyed`/
`ForEach`。五样本 128 项静态 keyless/显式键为 4.11/5.13 μs，约改善 20.0%；外部 revision 为
25.20/45.96 μs，约改善 45.2%。组合体执行计数仍分别为静态 0、外部版本 1 次/帧。测试覆盖自动静态采用、revision
替换、跨种类漂移、条件数量漂移回滚、整个 Keyed scope 卸载，以及部分 setup 失败的逆序清理。

## 后续实测触发的有界 build transaction arena（2026-08-27）

依赖与四类声明前沿改为自适应集合后，240 分支 full build 仍会为每个实际执行的 scope 新建一个
`StateMountBuild`、六个 `ArrayList` 和若干闭包；`StateStore` 复用了最外层 journal，但没有复用这些嵌套事务。
这类值只有 prepare/commit/cancel 之间有效，天然适合区域式分配：提交所有权仍在持久 `StateMountScope`，帧内日志
则可在事务结束后整体回收。

第一版把 scratch 直接挂到每个 scope，五样本把 240 分支局部/全量纯 build 做到 154.92/504.30 μs，但 10k 个
只在首次挂载执行的稳定 scope 也会各自永久持有六张空日志，空间复杂度与整棵挂载树绑定。最终改为每个
`StateStore` 最多保留 256 个 cell 的 frame arena；超出上限的宽帧使用临时对象，事务结束后 pooled cell 清空并
解除对子 scope 和捕获 invalidation closure 的引用。任何未 commit/cancel 的新依赖都会阻止 cell 重启，避免以
复用名义吞掉订阅清理错误。

最终编译状态的有界版本五样本中位为局部 145.72 μs、全量 505.74 μs；相对无 arena 的 178.45/585.77 μs 约改善
18.3%/13.7%，与 154.92/504.30 μs 的无界 per-scope scratch 没有可辨认退化，同时取得
`O(min(峰值活跃事务, 256))` 的明确常驻上界。
专项测试看护跨帧 cell 身份复用、日志/分类/shape 游标归零、未回滚依赖拒绝复用和 300→256 的容量截断；原有失败
构建、effect setup、依赖替换与卸载测试继续验证 arena 没有改变事务语义。

## 后续结构审计触发的稀疏 committed facet（2026-08-27）

frame arena 只解决重建期临时对象；每个持久 `StateMountScope` 仍无条件构造四个声明 `ArrayList`、一个依赖
`ArrayList` 和一个依赖 `HashMap`。源码事实意味着 10k 个完全空 scope 也常驻 6 万个集合对象。简单把六者装入一个
可空大对象会让“只读 State 的叶”和“只拥有子 scope 的容器”继续互相承担无关字段，因此最终拆成两个正交和类型：
`None | CommittedMountOwnership` 与 `None | CommittedBuildDependencies`。前者保持 state/retained/automatic/effect
及位置形状、重放分类的单一提交边界；后者保持 canonical dependency 序列及 identity 索引。失败 build 仍只修改
staging，最后一项删除才把已提交 facet 降回 `None`。

240 行真实 automatic 拓扑精确包含 2 个 ownership-only、240 个 dependency-only、0 个并存 scope。旧结构在这
242 个 scope 中有 1452 个集合；新结构只有 488 个集合，加上 242 个 wrapper 共 730 个对象，净减少 722 个
（约 49.7%），集合本身减少约 66.4%。专项反例覆盖空提交不提升、dependency-only 不误建 ownership、最后依赖
关闭并降级、最后 remembered state 删除并降级，以及 32 个 State-reading automatic 叶的卸载监听归零。

最终五样本局部/全量纯 build 原始值为 164.53/508.38 μs，对改造前 145.72/505.74 μs；同期未改算法的两个状态槽
对照显示约 4.4% 整机漂移，归一后局部约增加 8.1%（绝对约 12 μs），全量约改善 3.7%。这是一次明确记录的综合
取舍：局部脏路径仍严格执行 1/240 个 body，约 12 μs CPU 成本换取该拓扑近半常驻对象消失；全量、128 声明重放
和 1k/10k 宽依赖均未退化。若未来真实 heap profiler 表明 wrapper 比集合节省更昂贵，两个 facet 仍可在不改公开
API 与事务语义的前提下替换表示。

后续反测定位到该局部成本的具体来源：`CommittedBuildDependencies` 虽然已惰性存在，内部仍固定带一张 HashMap，
240 个单依赖叶因此各有一个单条目索引。最终表示在 0–8 条边时只保存 canonical 数组并线性查询，第 9 条才提升
identity 索引；提交降回 8 条会释放索引，连续宽图则复用已有容量。这个变化把同场景集合数从 488 进一步降至
248，计入 wrapper 的总对象从 730 降至 490；相对原始 1452 个对象净减约 66.3%。

最终五样本局部/全量 build 为 147.19/498.15 μs，相对固定 HashMap 版 164.53/508.38 μs 改善约 10.5%/2.0%，
也基本回到 facet 前 145.72/505.74 μs 的速度。1k/10k 宽依赖为 224.19 μs/2.163 ms，对固定索引版
216.57 μs/2.396 ms 没有一致退化。第 8/9 条提升、9→8 降级、旧订阅关闭和 dependency-only 叶无索引均由
确定性测试看护；这轮实测说明“稀疏和类型”与“小集合自适应表示”必须一起设计，才能同时取得空间与热路径收益。

## 后续实测触发的惰性分相依赖存储（2026-08-27）

build 依赖收敛后继续审计 measure/layout/paint，发现每个 `PhaseStateDependencies` 固定持有三个 ArrayList、一个
HashMap 和一个 HashSet；每个 retained/automatic render 节点又在构造时创建三个 collector。完全不在 phase 中
读 State 的节点因此也常驻 15 个空集合。最终 collector 本体与失效闭包继续稳定存在，但 committed、pending 和
两个索引全部变成按读提升的 `None | Storage`；0–8 条边扫描数组，第 9 条建立索引，降回 8 条或 0 条时释放。

显式 created journal 也被证明冗余：失败尝试中新边等于 `Pending − Committed`。小集合有 8 项上界，宽集合已有
identity 索引，所以 cancel 可直接求差并关闭新订阅，旧 committed 集合保持不变。空 phase 从 5 个集合降到 0，
单依赖稳定 phase 降到 2，宽稳定 phase 降到 4；一个无 phase State 的持久渲染节点精确减少 15 个集合对象。

改造前五样本中位：96 节点自动命令命中 3.117 μs、24 节点复杂兄弟自动晋升 18.113 μs；改造后低噪声七样本
为 2.628/16.087 μs，约改善 15.7%/11.2%，强制直绘/全量对照约 +1.4%/+0.9%。另一组机器漂移样本用同进程比率
仍显示 direct/cache 由 6.54× 提升到 13.58×、full/auto 由 3.42× 提升到 3.70×。显式 retained hit 一度退化约
8.4%，为空集合提交增加早返回后七样本回到 53.605 μs，对 53.227 μs 基线约 +0.7%。这轮同时得到显著空间收益、
两条自动路径加速和稳定 retained 无实质退化。

## 后续人体工学与复杂度反例触发的 Binding 单快照更新（2026-08-27）

`State.update` 原先不是 `Bindable` 协议的一部分，Binding 用户只能写
`field.value = transform(field.value)`。更隐蔽的是链式 `project` 的 setter 在每层执行“读上级整体→重建→写上级”，
下一层 setter 又重复同样过程；深度 `n` 的字段赋值因而产生三角数级根读取。除了性能，这还让自定义 Bindable
getter 或重入适配器在一次逻辑写中暴露多个模型快照。

新协议把 `update: (A→A)→Unit` 加到 Bindable，并让 Binding 保存可组合 modify。每个 Lens setter 把焦点端态
变换提升到上一级，直到根 State 在一个当前快照上求值并写回一次；这是 endomorphism 在 Lens 组合上的函子式提升，
术语不暴露给应用 API。普通 setter 也走同一通道；根 State 浅绑定保留单读快速路径，自定义 Bindable 的 update
覆写不会被绕过。变换或投影异常发生在根赋值前，因此不会发布半次更新。

五样本 1/8/32 层旧 setter 为 631 ns/3.323 μs/30.769 μs，新 setter 为
604 ns/1.603 μs/4.794 μs；32 层改善约 6.42×。新 `update` 为 504 ns/1.177 μs/3.108 μs，32 层相对旧实现约
改善 9.90×。确定性测试断言 32 层 setter 与 update 均只读/写根一次，嵌套模型的兄弟字段不变、根 revision/通知
只推进一次，异常路径写入数为 0。该改造减少了状态管理样板和推理复杂度，没有创建第二套 Store 或响应图。

## 后续结构审计触发的稀疏语义布局积（2026-08-28）

`ElementLayoutCommit` 已把 overlay 表示为 `None | OverlaySnapshot`，语义侧却仍用 `SemanticFragment([])` 表示缺席；
每个无语义布局边界因此分配一个空对象，并在 replay 时向全局贡献序列追加无效项。最终把布局效果积改为
`Overlay? × SemanticFragment? × EventTopologyΔ`：空区间直接产生 `None`，只有 `Some(fragment)` 参与重放，非空
provider 的原子提交、动态依赖和声明顺序完全不变。

1k/10k 冷空树 layout 五进程中位由 236.4/3242.7 μs 降到 228.0/2702.4 μs，约改善 3.6%/16.7%；10k 冷分配
曲线离散较大，因此更强的确定性证据是空提交贡献数为 0、非空缓存 fragment 重放数为 1。10k 非空首次语义提交/
稳定帧为 14.717 ms/68.785 μs，与改造前 14.807 ms/68.585 μs 同档，没有用空树收益换取可访问控件退化。

同一审计随后消除了 overlay 侧残留的中间表示：注册簿现在直接返回 `None | OverlaySnapshot`，空区间不生成数组，
已 adopted 的完整区间保持快照对象恒等，只有真后缀才复制并执行 last-owner-wins 归一化。因此布局效果积的两个声明
分量都是真正的可选值，而不是“可选快照外再套一个临时数组”。确定性测试覆盖空捕获、suffix 隔离、重复 owner、
对象恒等与零 replay；4k 稳定 overlay 帧五样本中位为 21.23 μs且逐项 replay 精确为 0。冷空树复验方差较大，
不宣称不可复现的额外百分比收益。

## 后续不变量审计触发的 Element 状态和类型（2026-08-28）

空间所有权统一后，`ElementSceneSpace` 仍用 `layoutCommit? + layoutValid` 表示布局 memo，用两个 Size、
`measuredEnvironment? + measureValid` 表示测量 memo。前者的笛卡尔积能构造 `(None, true)`，后者还能构造“环境缺席但
有效”等组合；这些不是业务状态，只是多个字段需要靠每个写点同步维持的证明义务。它们也迫使热读取先查 bool 再解
Option，并让“失效后是否保留旧几何”隐藏在赋值顺序里。

实现改为两个封闭和类型：`MeasureState = None + Snapshot`，
`LayoutState = Absent + Stale(Commit) + Current(Commit)`。`Current → Stale` 明确表示单向失效：旧布局不能 replay，
但继续为 damage、paint bounds 和诊断提供提交前几何；重新布局才产生 `Current(new)`，release 进入 `Absent`。
这是把合法状态子集提升为构造器，而不是在运行时反复验证布尔约束。测量提交直接复用不可变 snapshot，不再平行保存
available/result/environment/valid 四个字段；match 穷尽检查也让未来新增状态必须同步处理所有读取面。

负向测试覆盖“没有 measurement 但存在当前 layout”这一边界：`invalidateMeasure` 必须只把布局降级一次、保留旧范围、
拒绝 stale replay，第二次调用不得推进 revision。原有自写 State、失败测量、事件拓扑保留和代际释放测试继续通过。
同轮五进程观测中，retained revision 命中中位为 51.75 μs（改造前本轮 75.73 μs），revision miss 为
2.382 ms（改造前 2.999 ms）；10k Element-owned 稳定布局为 726 ns（改造前 806 ns）。这些短窗口受调频影响，
只证明没有性能换血式退化；主要收益是删除非法状态和分散同步义务。

## 后续反例触发的事件拓扑所有权状态机（2026-08-28）

测量/布局 typestate 收口后，事件拓扑 owner 仍平行保存 `committed?`、`pending?`、`staged?`。合法语义不仅取决于
三个 Option 的组合，还要求 staged 必须与 committed 或 pending 引用同一对象；失败 replacement 又要同时保留旧读面和
可复用写面。旧发布检查只比较 staged 与提交 topology 的 child count，因此一个同尺寸、已 ready、但由别处创建的对象
能越过 Element 所有权边界：它会被发布为当前 topology，真正 pending 被从字段移除却没有关闭。

新增反例在旧实现中使核心套件精确失败 1 条（462/463）。实现改用七构造器封闭状态机：
`Empty | Cached(p) | Current(c) | CurrentWithCached(c,p) | StagingInitial(p) | StagingCurrent(c) |
StagingReplacement(c,p)`。初次提交、原位更新和 child-count replacement 因而是不同构造器；失败布局只撤销 staging，
不会触碰 committed read face。发布要求 topology 与构造器携带的 staged 对象 `refEq`，拒绝外来值时 owner 状态不变，
外来对象也仍归调用方所有。关闭对七种状态穷尽处理，避免重复关闭或遗失 cached 写面。

状态机实现拆到独立的 `element_event_topology.cj`，空间 facet 只保留状态槽、快照和释放，事件入口再分成 matching、
discard、stable-state staging 与 publish 四类转移，保持单函数低于质量阈值。修复后核心为 463/463；同轮五样本中，
10k Element-owned 稳定布局由 788 降到 772 ns，detached 无界提交 736.8→736.3 μs、有界提交
703.2→687.8 μs。纳秒结果只证明没有退化，所有权反例和生命周期断言才是主要验收证据。

## 后续阶段审计触发的 ChildEventTopology phase 和类型（2026-08-28）

owner 状态机封闭后，拓扑对象内部仍以 `layoutInProgress`、`stagedLayoutReady`、`layoutChanged` 三个 Bool 表示事务。
八种位组合中只有 Idle、Recording(clean/dirty)、Ready(clean/dirty) 五种有意义；其余组合需要 begin、finish、publish、
discard 和 close 的每个写点共同排除。实现将其直接替换为五构造器 `ChildEventTopologyLayoutPhase`，note/commit、publish
各自只接受对应构造器，穷尽 match 成为阶段证明。

这次不只是表示清理：首次布局天然 dirty，note 已发现边界/策略变化后也已 dirty；旧 commit 仍遍历完整 child 数组比较
laid-out 位。新状态一旦进入 `RecordingDirty` 就跳过这些只用于发现变化的比较，继续生成 pending bounds/AABB 后直接形成
`ReadyDirty`。`RecordingClean` 仍保留全量相等证明，不能因优化而冻结删除或隐藏的 child。

新增测试覆盖 begin 前 publish/note、commit 后 note、discard 后 publish，以及 ready 写面被新 begin 替换且只发布最新
container bounds；核心为 465/465。同轮五样本中 10k Element-owned 稳定布局 772→778 ns（约 +0.8%），detached
无界提交 736.3→703.7 μs（约 -4.4%），有界提交 687.8→691.4 μs（约 +0.5%）。两侧微小变化均在短窗口噪声档，
没有用阶段安全换取可辨认的稳定路径退化。

## 后续人体工学触发的异构派生积融合（2026-08-28）

状态 API 已有单/双/三源异构 `derive` 和同类型数组入口，但常见四字段表单必须构造“两源中间派生 + 三源根派生”。
开发者因此要命名无业务含义的节点、决定树形结合顺序，并承担额外 identity、revision tracker 与失效边。把源积
`S₁ × … × Sₙ` 上的映射拆成树不是领域设计，只是固定重载元数不足泄漏到应用代码。

知识库与当前编译器未提供 parameter pack；实现因此保持同一个 `derive` 概念，增加四/五源异构融合重载，动态同类型
源继续使用数组。这个边界也与官方 [Kotlin Flow `combine`](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines.flow/)
提供二至五源异构重载和同类型 Iterable/vararg 的做法一致。四/五源各自只创建一个 `DerivedState`，复用 epoch 否定证书、
事务去重、逆序订阅回滚和 collector 聚合边，不引入 ProductStore 或第二套响应协议。

异构 Int64/Int32/UInt16/Bool/String 测试证明五源在同一 scheduler transaction 修改两个源时只观察一次最终组合值，
关闭 observation 后不再回调。四源同进程五样本中，嵌套 workaround/融合的稳定读取中位为 150/153 ns，处于同档；
每次源失效为 2162/1641 ns，融合改善约 24.1%，执行的派生 compute 节点由 2 精确降为 1。收益同时减少代码、图节点和
失效工作，而不是用方便 API 隐藏额外运行时层。

## 后续一致性审计触发的多源结果商融合（2026-08-28）

单源 `map(..., policy:)` 和 Store selector 已能把结果等价关系融合进源投影，多源却只能写
`derive(...).distinct(policy)`。后者在数学上只是 `q ∘ f`，实现上却创建 `f: S₁×…×Sₙ→T` 与恒等商投影两个
Derived 节点；应用既要选择调用链形式，也为第二个 identity、revision tracker 和失效转发边付费。

固定一至五源现在提供同名 `derive(..., policy:)` named overload，直接构造一个 `DistinctDerivedState`。默认重载、
`.distinct` 和动态数组保持兼容；没有给所有普通节点增加可选 policy 字段。测试覆盖一至五源解析、五源事务内净等价
零通知、跨商类一次最终通知及 observation 关闭。四源同进程五样本中 layered/fused 稳定读取为 157/152 ns，
等价失效为 2160/1688 ns，融合约改善 21.9%，节点从 2 精确降为 1。该改造使编程接口与内部图都表达同一个复合映射。

## 后续光学一致性审计触发的可写结果商与末端 selector 融合（2026-08-28）

`ScopedStore` 已把连续状态投影组合为 `p: Root → Local`，但 `select(f)` 仍从局部 Derived 节点再建一层，执行图没有表达
函数结合律 `f ∘ (q ∘ p) = (f ∘ q) ∘ p`。同时只读 selector 支持结果等价策略，可写 Binding 却要求每个观察者手工
比较字段；这把同一个观察商问题用两套编程方式暴露给应用。

内部 `ScopedModelProjection.select` 现在直接从最近根或不可穿透的商边界构造组合投影；普通 scope + selector 只保留
一个 Derived 节点。公开 `Bindable.project`、`ModelStore.binding`、`ScopedStore.binding` 与 `EffectStore.binding` 均增加
命名 `policy:` 重载：读取、revision、观察与 UI 依赖落到 `A/~`，Lens/Action 写入仍回到唯一根事实。效果型反例证明根
Action 产生等价字段时 Binding 零通知，但 EffectBatch 仍交付；因此观察等价不是业务取消机制。

8 层 scope 五个独立进程中，layered/fused selector 稳定读取中位为 406/170 ns，改善约 58.1%；dispatch 后读取为
1524/1024 ns，改善约 32.8%，Derived 节点从 2 降为 1。确定性测试另覆盖 get/set 与 Lens 两组 overload、兄弟字段抑制、
Action 写回、父商边界不可穿透、单快照 update 和 Effect 不丢失。

## 后续反测触发的运行时 Modifier 平衡积（2026-08-28）

`Modifier.then` 是 `Widget → Widget` 自同态的有序复合；语义满足结合律，但数组左折叠会把输入括号形状直接变成
调用栈形状。最初尝试把所有 Modifier 改成持久连接树或内联/分块混合表示，8192 步虽改善，8/128 步却约退化
1.9–2.4×；额外字段和解释分派污染最常见路径，因此两版均撤销。

最终只新增显式 `Modifier.concat(Array<Modifier>)`：≤8 项线性，宽集合用平衡二分，普通 `then` 零改动。它利用
结合律重括号但绝不换序。五样本预建数组中，128/1024/8192 步稳定应用由 503/4911/117942 ns 降为
419/4127/41381 ns，约改善 16.7%/16.0%/64.9%；8 步保持 29/29 ns。1024 项组合本身 19.23→45.42 μs，需约
33 次复用摊平；8192 项组合 214.35→165.02 μs，已直接改善。测试覆盖空积单位元、单元素对象复用、左右结合顺序、
1024 项 concat 和 8192 项精确执行；独立 `modifier` 微基准保留被否决方案的触发尺度。

Reducer 侧随后独立反测，拒绝复用 Modifier 的阈值：128 项平衡执行退化约 27%，1024 项才改善约 21.3%。最终
513/768 项边界补测仍退化约 38%/41%，因此 `Reducer.concat`/`EffectReducer.concat` 以 1024 为切换点，以下保持原左折叠，以上平衡；1024 项一次组合约多 67 μs，
约 10 次复用摊平。空积、单元素复用、16 项首错短路以及 1024 项模型/效果顺序均有直接测试。

状态等价策略随后增加投影 pullback：应用不再重复写 `p(previous) == p(current)`，而是复用目标空间策略并沿
`p: S→T` 取逆像。测试证明兄弟字段变化被抑制、候选代表元不替换、连续 pullback 与复合投影一致，且底层异常只
传播一次。该组合器完全 opt-in，不给默认 State、selector 或 Binding 增加字段与分派。

策略收益随后也改为可直接测量，而不是从“用了 equality”推断。显式 `diagnoseStateMutationPolicy` 包装器记录比较、
等价/不同结果、异常、累计与最大耗时，提供不可变快照和不影响既有 State 的计数重置；异常在记录失败与耗时后原样
重抛。测试覆盖一次等价、一次不同、重置保持 State 值，以及失败透明性。默认策略和所有未包装路径的对象布局、分支
与时钟读取均未改变，因而诊断能力不向生产热路径征税。

## 后续复杂度反例触发的 Lens endomorphism 正规化（2026-08-28）

逐层 Binding 已有单根快照语义，但预先用 `Lens.then` 组合路径仍保留朴素 `get/set` 递归：深度 `n` 的 setter 会读取
长度 `n-1` 的前缀后再进入前缀 setter，形成三角数级读取。32 层隔离反例的写入/update 一度达到约
26.8/24.1 μs；这意味着框架推荐的可复用路径在深层模型上反而显著慢于逐层 Binding，属于编程接口与执行语义不一致。

Lens 现以内建 `modify: (S,(A→A))→S` 表示焦点 endomorphism 的提升，`then` 以嵌套 modify 组合，使每层只读、重建
一次；公开 `Lens.update`、Lens-backed Binding 和纯 Reducer pullback 共用这条路径。EffectReducer 因 Writer 结果同时
携带效果，保留一次读取与一次重建两条线性遍历，没有用可变捕获或每 Action box 换取名义上的单遍。

五进程中位的朴素/融合 Lens Binding 写入在 1/8/32 层为 739/2416/26843 ns 对 697/1650/4914 ns；update 为
652/2245/24065 ns 对 576/1311/3916 ns，32 层分别改善约 81.7%/83.7%。五项确定性反例精确约束组合 set/update、
Binding、Reducer 为逐层一次，EffectReducer 为两次线性，并验证 transform 单次执行与 Effect 映射不丢失。Reducer
pullback 的 8/32 层朴素/融合五样本中位另为 1830/24314 ns 对 1140/4468 ns，改善约 37.7%/81.6%。

## 后续正确性人体工学触发的可执行代数定律（2026-08-28）

Lens、Prism 与 StateMutationPolicy 的公开契约已经依赖三定律、往返律和等价关系，但应用此前只能重复手写断言；
错误投影或非传递策略通常到 Binding 覆盖兄弟字段、事务错误消去或 selector 抖动时才暴露。将这些约束留在注释中，
与框架降低状态管理思考复杂度的目标矛盾。

新增的 `cui.testing` witness checker 返回逐律不可变结果：Lens 检查 Get-Put、两个 Put-Get 和 Put-Put；Prism 检查
payload 往返及命中 source 往返；策略用三值完整关系矩阵检查确定性、自反、对称和全部传递蕴含。有限 witness 明确
定位为反例搜索而非形式证明，开发者可在代表边界或属性生成值上重复调用。异常保持透明，FeaturePath 直接复用其
Lens/Prism 两侧检查，不引入冗余抽象。

四项测试覆盖合法/非法 Lens、Prism 命中与未命中、非传递但自反对称的关系、状态化非确定策略及用户闭包异常。
全部实现位于测试包，核心状态、执行图和生产帧路径保持零字段、零分支、零时钟开销。

## 后续规模反例触发的 Root 组合正规化（2026-08-28）

焦点持久片段已经把稳定 focus graph 提交降为 0，但 `focus-scale` 的 10k focusable 与同构空节点稳定帧仍为
10.287/9.572 ms，focus/layout 子阶段为 3.902/4.165 ms。阶段计数排除了 body、焦点图和显示列表重放后，
剩余成本定位到 Root 的表示边界：automatic record 缓存 body 的原始 child array，零/一/多子项到
`EmptyView | child | Stack(children)` 的隐式正规化却留在缓存外；多子项根因此每帧重新分配 Stack 并线性扫描。

修复把 Root 看作一个逻辑组合单元：作用域事务内先正规化原始发射序列，再以单元素结果提交 automatic record。
干净帧直接复用同一 render node；脏帧仍通过原子 reconcile 更新内容，所以节点数跨越 0/1/N 时不需要公开 key、
memo 或额外容器。两条测试先后证明干净多子项根的对象身份复用，以及从两子项切到一子项时边界身份稳定、
新内容可见。

修复后五个独立进程的 P50 中位中，1k/10k focusable 稳定帧为 14.646/95.490 μs，10k 空节点为
86.506 μs；10k focusable/空节点 focus-layout 为 0.863/0.950 μs。相对修复前分别约快 108×、111×，
子阶段约快 4522×、4385×；稳定 focus graph 提交仍精确为 0。ScenePatch 单区更新继续只访问 8 个 widget
而非全量 384，稀疏 10k 事件命中仍只访问 1 个候选，automatic 稳定显示列表访问为 0，说明收益来自消除根表示
泄漏，并未把局部更新或输入语义降级成全根边界。

Overlay 规模门禁同时改为校验 handler 总访问数，并把 1k/4k 注册及事件计时窗口分别扩为 80/40 次；时间比例
仍用于发现复杂度回退，精确访问计数负责排除“更快但没有执行协议”的假阳性。这次偶发调频尖峰因此不会被误判为
架构退化，也不会靠放宽 8× 上界掩盖。

## 后续宽依赖反例触发的执行轨迹证书（2026-08-28）

Root 表示泄漏消除后，`state-scale` 成为新的可复现宽路径：一个 scope 每次读取同序 1k/10k State，只修改其中
一个值，五进程中位仍为 233.808 μs/2.310 ms。原实现每次读取都向临时 HashSet 插入 identity、再查询持久
HashMap；提交又扫描旧前沿、复制数组并清空重建索引。body 的求和本来就必须是 `O(n)`，但运行时为证明依赖集合
没变又支付了多轮哈希 `O(n)`。

依赖的公开语义是有限集，可视为以并集为运算的有限 join-semilattice；声明执行却额外提供一个免费的有序 trace。
新事务先冻结 committed frontier 引用，再把读取 trace 与其 canonical sequence 逐项 zip。只要前缀相等，就直接复用
observation；首个差异后永久退回既有自适应集合路径。提交时，“无新订阅 + 去重后基数相等”证明当前集合是旧集合
的等势子集，因此无需关闭、复制或重建索引。顺序只作为证明证书，不成为应用可观察的依赖语义。

两项新测试覆盖 16 源完全稳定轨迹，以及长前缀后的重排和用新 State 等基数替换：前者不得建立临时索引，后者
必须进入哈希回退、保留重排 observation、关闭被替换源并订阅新源。既有删减、重复、失败回滚和 build 中写 State
反例也全部继续通过。

最终五进程中位的 1k/10k 总路径为 186.383 μs/1.740 ms，改善约 20.3%/24.7%；build 为
180.508 μs/1.728 ms，写入/失效为 1.191/2.150 μs，稳定 layout 为 2.358/4.975 μs。无依赖收集的原始
State 读取为 26.458/265.000 μs，明确显示下一层若继续优化，应降低动态 collector 的逐读派发，而不是继续压缩
已接近常数的失效或布局阶段。

试验还否决了“稳定命中只递增 cursor、完全不物化临时序列”的更激进表示：10k 中位由简单 zip 的 1.896 ms
退化到 2.184 ms，截短轨迹还迫使提交阶段补做前缀物化和索引。最终保留简单版本，并在 arena cell 中缓存事务开始
时的 committed facet，综合性能、证明复杂度和回滚可审计性更优。

## 后续动态 State 效应路由与 phase 轨迹证书（2026-08-28）

执行轨迹证书把 build 集合正规化后，原始读取与分相路径显示剩余成本来自逐读动态派发。旧表示把互斥状态分散在
FrameScheduler 的 collection depth、phase ThreadLocal、active StateStore 与 mount-build 栈中；一次已绑定 State
读取在 owner 检查后仍要逐层探测。它等价于用多个可空项的积编码一个实际只有两种构造器的和，既允许无意义组合，
也把架构偶然性放进热路径。

最终把 collector 收敛为 `Mount + Phase` 封闭和。scheduler 直接拥有当前值与嵌套父栈，headless/direct 路径用
ThreadLocal 链式帧；phase 暂时覆盖 mount 并由 `finally` 恢复。State 和 DerivedState 都只调用这个唯一动态 handler。
两个反例证明嵌套 phase 返回后外层继续收集，且内层 phase 抛错、取消新订阅后 mount collector 仍能接收后续读取。
这不是全局可变“当前组件”：scheduler 所有权和线程封闭仍是边界，无 scheduler 帧也按线程隔离。

统一路由的即时五进程对照中，1k/10k build scope 从 187.691 μs/2.072 ms 降至 119.875 μs/1.105 ms，约改善
36.1%/46.7%；刻意每帧替换节点、使 phase committed trace 无法复用的路径从 748.633 μs/5.960 ms 降至
653.941 μs/4.921 ms，约改善 12.6%/17.4%。随后把相同有序证书推广到持久 phase collector：完整同序 trace
O(1) 提交，截短直接关闭后缀，首个重排/替换回到哈希正规化。同进程关闭/开启证书的五进程中位中，稳定节点
1k/10k layout 重收集由 139.091 μs/1.238 ms 降至 92.275 μs/0.935 ms，约改善 33.7%/24.5%。

基准现在同时保留“稳定节点”和“替换节点”两组，避免把对象身份替换主动关闭依赖的成本误算成 collector 退化；
每帧精确读取仍为 1k/10k。专项测试覆盖稳定宽 trace 不建立 transient index、重排/替换回退、失败取消与嵌套恢复。
该设计使用范畴论中和类型/局部效应 handler 的组合纪律，以及有限 join-semilattice 上由执行序提供的可撤销证书；
数学只用于减少非法状态和给出快速路径证明，不进入公开 API 术语。

## 后续反例触发的 phase dependency 多版本提交（2026-08-28）

稳定/替换双曲线把最后一个结构性断点暴露出来：`AutomaticRenderNode.update` 在 child 对象身份变化时先关闭
measure/layout/paint 三组依赖，再把 Scene phase 标为 stale。新 Widget 即使读取完全相同的 State trace，也只能
重新分配 observation 和重建索引；更重要的是，Scene 仍保存上次成功提交，而保护该提交的输入边却已经消失，依赖
生命周期早于结果生命周期结束。

修正后 phase frontier 被定义为“最后一个成功 phase commit 的输入 facet”。composition commit 可以替换 child 并
令 Scene stale，但不销毁该 facet；下一次 phase 收集在独立 pending 写面工作，同序时直接采用旧边，换源时成功后
原子正规化，失败时取消新增边并继续保留旧前沿。节点 close 是最终释放边界。它与 MVCC/双缓冲的纪律相同：旧读面
持续有效，直到新版本完整发布；这里没有复制 State 值，也没有同时执行两棵 Widget 树，只延长最多一份 canonical
dependency frontier 的生命周期。旧 State 在重收集前触发的额外失效是保守且幂等的，不能形成错误 cache hit。

两项集成反例先在旧实现上稳定失败，再验证：三 phase 同源替换期间 listener 数不降为零；失败的新 layout 源不会
污染已提交前沿，下一次成功才从旧源切到新源；替换后尚未执行 phase 就 close 仍会释放保留边。五进程中位中，
1k/10k 替换节点完整帧从 661.558 μs/5.015 ms 降至 101.016 μs/0.866 ms，约改善 84.7%/82.7%，即
6.55×/5.79×；measure/layout 子阶段从 506.150 μs/3.879 ms 降至 97.166 μs/0.859 ms。稳定节点与 build
scope 同期未出现可辨认回归。该结果说明正确的提交所有权不仅简化异常推理，也消除了对象身份导致的订阅抖动。

## 后续真实 GPU 证据触发的物理密度 Auto 超采样（2026-08-28—29）

前述 headless 与局部提交优化收敛后，三样本 Direct3D11 显示套件暴露出新的主导项：1120×720、应用缩放
1.5、实际后备尺度 3.375× 的 planner 场景中，显式 ss2 稳定帧约 10.37 ms，其中 build/layout/semantics/tree
合计约 1.7 ms，而 present 约 8.3 ms；显式 ss1 总计约 3.05 ms，present 约 1.8 ms。也就是说，在高 DPI
后备缓冲上再次做每轴 2x 并没有解决 CPU 增量问题，而是把已足够密的采样格再扩成 4 倍像素。同期
dashboard damage/command 配对中位为 1.018，局部 damage 在这张 GPU 上没有独立收益，因此没有继续扩张
damage 状态或引入更多 raster layer。

渲染内核据此把默认请求从固定 2 改为 `0 = Auto`：以实际物理后备像素/逻辑单位为尺度，低于 2.0 时选 2x，
达到或超过 2.0 时选 1x；显式正数仍严格生效，负数保持旧有 clamp-to-1 兼容。Auto 在 DPI/显示器变化时重新
求值；跨阈值会销毁旧离屏目标、推进 render-command epoch 并使目标尺寸失效，因而不同采样格之间不能错误复用
显示列表。这个选择可理解为在“系统后备密度 × 框架超采样倍率”的乘法作用中取满足采样下界的最小代表：保留
低 DPI 抗锯齿，同时正规化高 DPI 上的重复采样。公开 API 只呈现易懂的 Auto/精确覆盖，不暴露数学术语。

改造后的三轮反向轮换套件共有 98 个 headless 帧用例和 18 个显示用例：前者 98/98 达到 120fps，后者
18/18 满足 60fps P95、16/18 满足 120fps P95。planner 的三样本中位为 ss2 10.680 ms、Auto
3.350 ms、ss1 3.324 ms；同进程 `ss1/ss2` 配对中位 0.315，`Auto/ss1` 为 0.968，后者相对 MAD
0.47%。P95 分别为 12.073/3.985/3.710 ms，Auto 的环境证据明确记录 `direct3d11|1|vsync0`。
因此默认真实帧成本相对固定 ss2 约降 68.6%（约 3.19×），同时显式 ss2 继续作为质量与填充成本对照。
这些数字来自电池供电的单机观测，不充当跨硬件绝对 SLA；策略正确性另由 1.99/2.0 阈值、DPI 往返、显式
覆盖和负值兼容的无窗口测试确定性看护。

后续资源边界审计补上 Auto 的第二维约束。旧策略仅看物理密度，低 DPI 超大输出仍会构造无界 2x target，且
`Int32` 宽高乘法发生在 SDL 能力检查之前。新计划器先取密度候选，再要求 Auto target 不超过 32 Mi 像素，
并在乘法前检查 [`SDL_PROP_RENDERER_MAX_TEXTURE_SIZE_NUMBER`](https://wiki.libsdl.org/SDL3/SDL_GetRendererProperties)；4K 2x 保留，5K/8K Auto 回退直接绘制。显式
正数不受框架预算限制，保持质量/压力覆盖，只在算术或硬件不可能时安全回退。计划变化推进 command epoch，
同尺寸分配失败则记忆到尺寸变化/设备重置，避免每帧分配风暴。

`RenderSamplingStats/Status` 把选择、计划尺寸、RGBA8 字节成本、硬件边长和回退原因提升为只读诊断；查询不访问
GPU。基准记录 `target pixels/bytes/max texture edge` 并门禁四字节像素关系。本机 D3D11 报告边长 16384，
显式 ss2 planner 为 36,741,600 像素/146,966,400B，Auto 为 0B。改造前/后三轮 ss2 中位
10.436/10.504 ms、Auto 2.994/2.988 ms，没有可辨认正常路径性能税。SDL 3.4.12 的 `gpu` renderer 同轮试验
ss2/Auto 中位为 10.765/3.346 ms，分别慢约 3.2%/11.8%，因此再次否决仅切换后端；真正的 SDL_GPU 原生
[MSAA/resolve](https://wiki.libsdl.org/SDL3/SDL_GPUColorTargetInfo) 仍须独立后端原型证明收益后才能进入生产。
最终三轮反向轮换全套件的 planner ss2/Auto/ss1 为 10.600/3.006/3.002 ms，P95 为
11.993/3.632/3.563 ms；106/106 个 headless 场景达到 120fps，19/19 个显示场景满足 60fps P95、18/19
满足 120fps P95，唯一 120fps 压力项仍是显式 ss2。

## 后续并发反例触发的命令图根所有权边界（2026-08-29）

层次化 ScenePatch 已约束 slot 的替换与清空，却没有把同一规则完整提升到命令图的所有公开观察入口。
`RenderCommandBuffer.stats/paintBounds/isReplayable` 和空缓冲 `replay` 可以从错误线程读取或成功；前两者分别
接触可变重放计数与可能调用字体度量的动态边界，因而“Renderer 线程封闭”只在最终绘制调用偶然成立。新增反例
从 worker 依次调用 Buffer 的 7 个与 Slot 的 10 个公开操作，旧实现稳定只有部分抛错，修复后 17/17 均在任何
读写或重放前拒绝，slot revision 和 replay count 保持不变。

实现没有在每个递归节点直接调用公开检查。公开根入口执行一次 `RenderDeviceToken.ensureAccess`，随后进入
`isReplayableValidated` / `paintBoundsValidated` 等包内读面；slot/BVH 只沿已验证路径递归。它等价于把线程所有权
看作命令图遍历所需的一次根证书：证书沿结构态射传递，而不是在每条边重新证明。这样既封闭竞态，也保持
`O(log n + k)` damage 查询，不把安全成本变成 O(n)。同时把 649 行混合文件按冻结边界拆为 383 行的不可变
Buffer/重放核心与 287 行的 Recorder/编译事务；不是为静态规则机械切行，而是让可变写面在 `finish` 后消失，
读面只消费冻结值命令与稳定 slot。

五个独立进程的 headless 复验中位为：96×24 flat/hierarchical 父重建 137.266/20.553 μs（6.68×），稳定
flat/hierarchical 重放 0.714/1.831 μs，96/256/1024 子树单区域 damage 0.150/0.166/0.179 μs；1024 规模
仍没有随节点数四倍线性增长。48 区单区域 patch/强制全树为 0.191/1.691 ms，绘制访问保持 8/384。最终三轮
反向轮换 Direct3D11 套件中，命令重放/强制全量中位为 0.841/1.214 ms，配对比率 0.693；改造前同口径为
0.807/1.201 ms 与 0.679，约 +4.3%/+1.1% 和 +2.1% 的比率变化处于本机进程间量级，命令路径 P95 仍仅
1.011 ms。damage/command 配对为 1.036，再次说明本 GPU 不值得为 damage 扩张复杂度。98 个 headless 帧用例
全部达到 120fps；18 个显示用例全部满足 60fps P95、16 个满足 120fps P95。

## 后续反例触发的 Renderer 总所有权边界与能力域否决（2026-08-29）

命令图根已封闭后，`Renderer` 本身仍有不一致的 public 面：driver/超采样与诊断查询、场景和 viewport/clip
事务、颜色状态、截图，以及 `RenderPass.close/isClosed` 可以从错误线程执行；`fillConvexPolygon` 与
`texturedStrip` 还因“只在录制时复制列表”的专用分支绕开统一 draw 入口。更隐蔽的是 `circle` 直接调用
geometry，位于 `recordCommands` 内时不会报错，却也不会产生任何命令。新增无窗口 worker 反例一次覆盖 34 个
状态/查询入口，配合既有普通绘制、纹理和命令图所有权测试固定边界；旧实现失败，修复后全部在接触状态前拒绝。
独立断言同时要求 `circle` 录制出一条可重放的 `StrokeCircle`。

实现将 owner 检查放在每个 public 根或其统一委托入口；内部组合改用私有 `applyDrawColor`、`clearTarget` 和
`currentClipUnchecked`，所以 begin/clear/draw 不会因为契约补全而重复走 public 守卫。这里没有采用隐式动态
能力域。曾实现 `withRenderAccess` + `ThreadLocal` 原型：600 次短窗 A/B 把 96 个独立 buffer 从
13.007 μs 降到 11.598 μs，看似快约 10.8%；把每侧扩大到 10000 次后结果变为 12.348/12.347 μs，差异消失，
完整 dashboard 还显示 ThreadLocal 查询会伤害高频 Renderer 调用。该原型及基准开关已全部删除。这一反例说明
能力证书只有在语言能静态携带、或单次验证确实替代昂贵工作的情况下才值得进入 API；当前直接 token 比较已经
足够便宜，动态作用域只会增加隐藏状态和异常恢复的思考成本。

最终五进程 headless 复验中位为：96 子树 hierarchical 父重建 16.641 μs，2304 命令稳定重放 1.533 μs，
96/256/1024 子树单区域 damage 为 0.129/0.143/0.168 μs，1024 全重放 18.376 μs。48 区单区域 patch/
强制全树为 0.169/1.639 ms，绘制访问保持 8/384。相对上一轮 1.831 μs 稳定重放与 0.150/0.166/0.179 μs
damage 没有可辨认退化；更快的观测只作为噪声范围，不宣称本次安全修复带来性能收益。
三轮反向轮换 Direct3D11 显示复验中，强制全量/命令重放/damage 中位为 1.220/0.865/0.855 ms，
command/full 配对比率 0.730，damage/command 为 0.964；相对上一轮 1.214/0.841/0.872 ms 的小幅双向变化
仍在进程间噪声范围。98 个 headless 帧用例全部达到 120fps；18 个显示用例全部满足 60fps P95，16 个满足
120fps P95。因此完整所有权边界以确定性反例证明正确性，同时保持既有实机帧预算。

## 后续实测触发的缩放文本 metrics 正规化（2026-08-29）

最新显示报告的两个 120fps 超限项都是显式 ss2 压力对照，但 40 分区全量表单暴露出与像素填充无关的确定性
异常：384000 次度量产生 78000 次真实计算，即每帧 520 个居中标签全部绕过缓存。根因不是 1024 项容量不足，
而是缓存只接受 `scaleX == scaleY == 1`；场景内为了匹配 hinted glyph 的 `pointSize × scaleY` 度量被错误归类为
“罕见且不可缓存”。先加入无窗口反例，旧实现第二次相同 scale 居中仍增加 compute，证明问题不依赖 GPU。

最终实现把 cache value 改解释为栅格器坐标中的原生 metrics，键使用实际字号、样式、字体族和文本；返回时再
分别除以当前横纵 scale。它把变换作用前移到稳定对象，避免为 scaleX 再扩一维 key，也能正确复用
`pointSize 24 @ 1x` 与 `pointSize 12 @ 2x` 的同一原生字体结果。字体注册代数、分代淘汰和线程所有权边界不变。
三种 planner 策略的暖测实算由 9115/33490 降到 8/33490（0.024%），新增 `<1%` 确定性门禁；全量表单为
0/384000。三进程定向 profile 中，绘树中位约改善 3.9%，整帧均值中位约改善 2.8%。三轮反向轮换中 40 分区
ss2 P95 由 9.738 降至 9.265 ms、120fps 超限帧 52→45；18/18 仍满足 60fps，16/18 满足 120fps。后一个数字
没有跨档，因此这里只认缓存计算和连续成本的明确收益，不把系统/GPU 尾延迟包装成已解决。

紧接着的 native text-pass 合并试验也被否决。原型在 Renderer 内保留“当前 SDL 已处于 1:1 文字状态”，直到
geometry、texture、viewport、clip、命令根恢复或场景结束才切回逻辑 scale；异常时仍强制恢复。新计数器确认
40 分区表单的 pass 进入从 78000 降为 54000（30.8%），说明实现确实合并了相邻文字，而非死代码。但三进程
整帧中位约 8.183 ms，相对紧邻的 8.152～8.224 ms 基线只有 ±0.5% 噪声，P95 无稳定收益。为此维护三十余个
状态边界会扩大隐藏状态与错误恢复的乘积空间，综合收益为负；实现、公开诊断、测试和 benchmark 字段已全部删除。
后续文本优化必须减少 draw/raster 工作或在保持 z 序的显式编译 run 中证明收益，不能仅凭 native call 数下降晋级。

## 后续实测触发的普通 ScrollView 保守绘制裁剪（2026-08-29）

被否决的 native 状态合并没有减少任何字体绘制，随后对 40 分区表单的计数审计显示更直接的问题：普通
`ScrollView` 只把 viewport 送给 renderer clip，外层 VStack 仍递归 draw 全部离屏分区。内核现在使
`drawWithinSpatialClip` 同时安装组合 UiContext clip；Stack 记录本次 layout 的子边界，并以
`paintOutset.expand(layoutBounds)` 与当前 paint clip 的严格正面积相交作为进入 draw 的证书。所有子项仍完整
measure/layout 并登记事件与语义；未布局/脱离布局项保守保留。该规则等价于矩形 meet-semilattice 上判断
`Pᵢ ∧ C ≠ ⊥`，嵌套 clip 的结合、交换、幂等性消除了顺序歧义，PaintOutset 则提供阴影和自定义外溢的单调保守边界。

Stack 没有复用 retained event topology 的 committed bounds，而持有与即时实例、本次 layout 同寿命的独立数组；
这是刻意避免跨 facet 的版本耦合。算法仍 O(n) 扫描直接子项，只把递归绘制降到 O(k)；大规模数据仍应使用
LazyColumn/LazyRow 把 build/layout 也窗口化。`Widget.draw` 契约现在明确允许在证明不可见时省略，业务生命周期
必须放在 State/effect/frame subscription。Tooltip 的 dwell 复位已移至总会执行的 layout，作为 draw 副作用审计的
首个具体反例；绘制局部动画离屏暂停是允许且节能的语义。

Direct3D11 显式 ss2 的 40 分区全量表单最终三轮均值中位从最近 8.131 ms 降至 3.883 ms（约 -52.2%），
P95 从 9.265 降至 5.440 ms（约 -41.3%）；150 帧文本 draw 从 78000 降到 4030（-94.8%），仅 1 帧超过
120fps 预算。窗口化版本为 2.239 ms、P95 2.533 ms、4467 次 draw，继续量化全量 build/layout 的剩余成本。
完整显示结果由上一轮 16/18 提升为 17/18 个场景满足 120fps P95，18/18 继续满足 60fps。性能门禁新增确定性
比率：普通路径 draw 不得超过窗口化路径两倍；当前 4030/4467 通过，旧 78000/8073 会失败。测试覆盖完整布局
仍执行、上下视口动态切换、零面积边界、声明外溢以及 draw 抛错后 renderer/UiContext 双重恢复。

## 后续反例触发的自测量 LazyList（2026-08-29）

普通 Stack paint 已局部化后，剩余差距来自全量 build/layout。曾评估直接跳过离屏 child.layout，但当前绝对坐标
同时流入命令、事件 topology、semantics 与 overlay；在缺少统一平移作用和 layout 等变证书时，这会让各 facet 指向
不同几何版本，方案未进入生产代码。可安全解决且直接降低应用复杂度的缺口是：变高虚拟列表仍要求开发者维护每行
高度，而高度本是布局的派生事实。

新增 `LazyList.measured` 的索引与数据重载。未知行先使用一个 `estimatedHeight`；仅 materialized 行执行 intrinsic
measure，成功测完全部可见项后再把稀疏变化批量提交到既有 Fenwick extent 索引。一批 k 项为 O(k log N) 且只写
一次 State；异常发生在提交前。宽度或 `UiEnvironmentKey` 改变时丢弃旧测量、保留结构版本；插入/删除/重排仍由
明确 `revision` 划定结构事务。行根必须在有限宽、无界高约束下给出有限高度，这是比“业务保存每行像素”更自然的
组件契约。

前序 extent 改变时，先在旧几何记录 `(key, withinRow)`，再提交新前缀和，并在同一事务把 offset 映为
`prefixNew(key)+withinRow`。测试先暴露了“提交后才认 anchor”会需要 3 pass 且可能换 key，修正后 row.3 在前序行
50→90 时保持 y=0、offset 150→190，只需 2 pass。估计导致滚动条从无到有的反例则稳定为 3 pass：初始宽度、
扣除 gutter 后重测、最终证明，不越过 shell 的上限。这个协议对应加法幺半群上的稀疏前缀更新和坐标重参数化不变量，
但公开 API 只暴露估计、稳定 key 与 revision。

最终三轮 headless 中 48 区块自测量为 0.214 ms，普通路径 1.354 ms（约 6.3×），固定高度 0.120 ms；约 1.78×
的可见行 CPU 管理上界换掉了业务高度模型。Direct3D11 40 分区 ss2 同轮普通/固定/自测量的均值为
4.137/2.281/2.239 ms，P95 为 5.301/2.650/2.527 ms；自测量相对普通改善约 45.9%/52.3%，与固定高度没有
可辨认退化。measure 计数为 22940 对全量 310030（-92.6%），draw 4030 对固定 4467，字体实算仍为 10。
新增确定性门禁拒绝 measure 超过全量四分之一或 draw 超过固定窗口两倍。完整套件 100/100 个 headless 场景达到
120fps，19/19 个显示场景满足 60fps P95、18/19 满足 120fps。

## 后续反例触发的可观察 Lazy 数据与 extent 迁移（2026-08-29）

自测量上线后的 API 审计发现，数据数组与结构 revision 仍是两个需要应用同步的事实源。四个数据入口
`LazyColumn.of`、`LazyRow.of`、`LazyList.of`、`LazyList.measured` 因此增加 `State<Array<T>>` 重载，
用 State 内部一次 `(value, revision)` 采样驱动原有内核。结构变化只需给 State 赋新数组；Array + revision 保留为
不可观察外部快照的兼容路径。双 Host 常驻、16 段交替的 10k 项稳定帧七样本中，手写双读取与自动快照中位分别为
5519/5469ns（约 0.9% 差异，按噪声处理）；完整三进程的同进程自动/手工比值中位为 1.002、ratio MAD 7.3%，
未观察到易用性抽象税。与 Host 生命周期绑定的初版顺序对照已被拒绝。

另一反例让三行学到 30/40/50px 后在其前插入两个新 key：若 revision 仍清空全缓存，顶部业务对象的前缀会从正确
160px 退回 100px 估计。缓存现在把已测高度看作业务 key 上的稀疏偏函数；新索引到 key 的映射把它拉回新位置，
未知 key 才取估计。稳定 revision 不枚举 key，结构变化且明确提供唯一 key 时才 O(N) 重索引；后续可见补丁仍为
O(k log N)。宽度、环境、估计、间距或 key 策略改变会丢弃该证明。测试固定了稳定帧 0 次全量 key 读取、结构变更
恰好 N 次，以及上述 offset 120→160；旧实现分别会多做扫描或得到 100。

## 后续 phase 反例触发的滚动物化边界（2026-08-29）

显式 ss2 planner 的稳定 profile 把问题分成两层：约 36.7M 像素 target 使 present 持续约 8.7ms，而 CPU build
仍因滚动 offset 每帧触发 composition。D3D12、SDL GPU、OpenGL、Vulkan 与纹理格式候选没有稳定改善前者；因此
保留最稳的 D3D11，并单独修正后者，不把 GPU 压力归咎于声明树。

反例证明 AutomaticRenderNode 的 layout dependency 回调仍调用 composition invalidation，违背“读取位置决定最早
失效相位”。删除这条反向边后，layout/measure State 只使相应 Element Scene facet stale；真实结构输入继续通过
build dependency 失效。该决定与 [Compose phase restart](https://developer.android.com/develop/ui/compose/phases)
以及 [Flutter on-demand/sliver scrolling](https://docs.flutter.dev/ui/layout/scrolling) 的工业经验一致，但实现保持
CUI 单一 Widget API。

LazyColumn/LazyRow 和有可观察 extent 的 LazyList 进一步把连续 offset 与离散 materialized interval 分离。
构建期只采不建依赖的 `(offset, revision)` hint；layout tracked read 复核最新 revision，并在所需窗口不再包含于
当前区间时写内部 generation。宿主随即多做恰好一个稳定化 pass，在 draw/semantics 前补齐条目。数学上这是
`ℝ≥0` 平移作用在一个由 overscan 覆盖量化出的局部常值索引区间上；跨覆盖边界才改变拓扑，迟滞抑制抖动。
无 revision `heightOf` 因无法证明捕获值稳定而留在保守路径。

同 Host 800 帧 A/B 为：增量/全量 body 51/800，增量 pass 851，build 18.37/151.22 μs（8.23×），整帧
213.05/285.32 μs（1.33×）。真实 planner 稳定 build 为约 0.04–0.11 ms，Auto 总帧约 3.00 ms；ss2 仍约
10.49 ms，明确保留为 GPU fill/present 压力对照。`bench/run.py` 同时门禁 body 比率与 `passes = 800 + body`，
避免墙钟噪声或画面陈旧产生假优化。

## 后续定位反例触发的 index/key 双坐标控制器（2026-08-29）

100k 项首次 `scrollToKey` 必须从 `index → key` 函数构造偏逆，12 帧窗口中平均读取 8408 个 key、耗时约
1.38–1.97 ms；调用方已知 index 时，旧接口仍迫使它丢掉这份信息。控制器现在以
`NoTarget | StableKey(String) | ItemIndex(Int64)` 表达互斥目标，并公开 `scrollToIndex`。固定 extent 定位 O(1)，
Fenwick extent O(log N)，稳定 key 首次反向索引仍如实为 O(N) 且之后缓存；重排风险场景继续使用 key。

旧实现还有两个由反例确认的事务缺陷：`jumpTo` 取消 pending key 后仍扫描全量 key 并把结果标 missing；key 回调
抛错前已经提交 controller revision，恢复后不重新发请求就永远不会重试。新协议先完成求值再提交 revision，取消
目标直接走 `NoTarget`。100k 五轮同进程 index/key 绝对中位为 229.10/1808.43 μs，逐轮配对中位 0.126
（index 约快 7.9×）；10k/100k index 均平均只读 75 个物化 key。越界、负数、取消、失败重试和后台线程误用
都有独立反例。

## 决策

更深层更新重构是必要且已被实测验收：当前三样本中，256 区局部更新从 31.83 ms 降至命令缓冲路径 1.99 ms，draw 访问从
256 降到 1，真实窗口结果与全帧逐像素一致。damage 再降到 1.89 ms，但独立收益未过验证阈值，因此不能把
1.89 ms 全部归功于 damage；主要数量级收益来自分相 retained 与 display list。现在最优选择不是继续“大改成
完整保留式 GUI”，而是把当前自动 scope/选择性 render/display-list 层和 damage 回退能力做成可观测底座，再由
边界收益、paint overflow、GPU replay 或 hit-test 的新证据逐项触发下一次设计。这样既保留已证实的收益，也
避开成熟 GUI 框架中 layer 泛滥、raster cache 抖动、错误 damage、动态状态冻结和多套树失配等常见陷阱。

## 后续实测触发的文本与提交优化（2026-08-22）

阶段一、二收口后新增的长文试验再次证明“只看 headless 会漏掉真实后端瓶颈”：20k 文本把完整余串逐行交给
`TTF_MeasureString` 时，Direct3D11 实机出现约 1.7s 长帧；SDL_ttf 返回短前缀并不意味着内部只处理短前缀。
最终实现把测量会话拆成一次 UTF-8 缓冲、边界对齐的 256B 初始 shaping window 和“整窗完全容纳才 4× 扩张”
的探测；上层以 UAX #29 风格字素簇、UAX #14 风格合法断点独立收紧。20k 纯汉字另走 O(lines) 流式路径，
不创建 20k cluster 数组。当前 `bench/results/check.json` 中，headless 20k 冷布局约 0.937 ms、热 LRU 约 0.0065 ms；真实
窗口热缓存均值 0.376 ms，LRU 冷抖动均值 0.826 ms、P95 2.983 ms，两者 60fps 超限均为 0/100。组合附加符、ZWJ emoji、旗帜、
NBSP、CRLF 和 CJK 标点均有专门测试；RichText
也只在完整字素簇边界生成片段。

对应规范与原生契约：[SDL_ttf TTF_MeasureString](https://wiki.libsdl.org/SDL3_ttf/TTF_MeasureString)、
[Unicode UAX #29](https://unicode.org/reports/tr29/) 与 [Unicode UAX #14](https://unicode.org/reports/tr14/)。

该试验同时否定两个常见误区：不能把字体宽度 API 当 Unicode 断行器，也不能用“缓存后很快”掩盖冷路径。
`UiContext` 因此采用 4 MiB 字节预算真 LRU，键使用精确宽度并包含字号、样式、字体注册代数和行数上限；报告
必须同时列冷/热和 hit/miss/eviction。

原语提交则采用更保守的局部优化：只合并录制序列中连续至少四条、同类型同色的 point/rect/fill-rect，任何
clip、颜色、文本、纹理或其他命令都切断批次，绝不按材质跨 z 序排序。当前 Direct3D11 2048 矩形实机均值从
0.925 ms 降至 0.498 ms（1.86 倍），P50 从 0.658 ms 降至 0.196 ms（3.36 倍）；批处理样本仍出现一次调度型长尾，
因此报告必须同时看均值、分位数与超预算计数。圆角 mesh 和纹理未自动合并，因为当前证据不足以抵消 blend、资源生命周期和大缓冲峰值风险。

布局侧只复用同一即时实例上“完全相同 constraint”的 Stack measure→layout 结果；约束变化立即重测，缓存不
跨实例。当前稳定实例的深 12/20 为 0.074/0.140 ms，逐帧重建口径为 0.192/0.419 ms；两种口径始终同时报告，
避免用稳定实例数字冒充完整帧成本。历史基线只在同机器、同构建配置且口径一致时用于回归比较。

## SDL_GPU 原生 MSAA 下界通过、生产迁移暂缓（2026-08-29）

此前 planner 的显式 ss2 在 3780×2430 物理输出上创建 7560×4860 离屏目标；其 36,741,600 个 texel 与
3780×2430×4-sample MSAA 的名义样本数相同。因此新增 Windows 原生隔离探针，交替运行 D3D11
`SDL_Renderer` 2× SSAA 线性缩小和 SDL_GPU/D3D12 4× MSAA，并使用官方标为最低带宽路径的
[`SDL_GPU_STOREOP_RESOLVE`](https://wiki.libsdl.org/SDL3/SDL_GPUColorTargetInfo)。探针固定 SDL 3.4.12
头文件/运行时，显式使用 `IMMEDIATE` present，ABBA/BAAB 各批独立重建设备和交换链，记录 30 帧预热、
180 帧提交分布与最终 GPU 排空；默认三轮。默认 present 曾把 GPU 侧精确锁在 120 Hz 的约 8.33 ms，因口径
不等被拒绝，没有进入结论。

同机两个独立进程、每个后端各六批的结果如下：

| 会话 | D3D11 ss2 完整帧中位 | SDL_GPU msaa4 完整帧中位 | ss2/msaa4 | 提交 P95（ss2/msaa4） |
| --- | ---: | ---: | ---: | ---: |
| 1 | 2.161 ms | 1.612 ms | 1.341× | 2.444 / 2.021 ms |
| 2 | 2.143 ms | 1.581 ms | 1.355× | 2.406 / 1.941 ms |

两次都通过“完整帧至少 1.25× 且 P95 不退化”的预设晋级门槛，时间下降约 25–26%。这否定了“原生 MSAA
在当前硬件必然无益”，但还没有证明生产收益：clear-only 可以触发 fast-clear，尚未包含 CUI 的圆角/描边
几何、clip、alpha blend、纹理、SDL_ttf 表面上传和资源换代。故本轮不把 `Renderer` 切到 SDL_GPU，也不让
应用接触后端开关。

下一阶段只沿现有值语义 `RenderCommand` 边界建立真实场景执行器：把有序命令与 clip/resource 生命周期看作
自由幺半群上的解释器，D3D11 与 SDL_GPU 分别是保持顺序、合成和所有权的两个实现函子；以最终栅格观察和
失败回退验证语义等价，而不是复制第二套 Widget/状态树。先覆盖纯色/mesh/clip，再覆盖纹理与文本 atlas；
同进程重放 planner 命令流，要求像素容差、资源 epoch/关闭/resize/device-loss 反例全部通过，且端到端 P95
至少改善 15% 或绝对减少 1.0 ms。未过门槛就保留当前 D3D11+Auto 方案并删除试验后端。

## SDL_GPU 代表命令流否决生产后端（2026-08-29）

下界晋级后实现了独立但同构的值命令解释器，而没有先污染生产 FFI：同一 IR 含 73 个保持顺序的
material/clip packet、7728 个顶点，覆盖纯色三角网格、圆形边缘、scissor、straight-alpha blend 与模拟
glyph atlas 的线性采样。D3D11 解释器把坐标以 2× scale 画入 SSAA target；SDL_GPU 解释器把同一顶点缓冲
提交给 4× MSAA pipeline，再用 [`SDL_GPU_STOREOP_RESOLVE`](https://wiki.libsdl.org/SDL3/SDL_GPUColorTargetInfo)
直接解析到交换链。两侧都显式 `IMMEDIATE` present，每批独立重建设备、shader、pipeline、buffer、texture
和 window claim。

像素先于性能裁决：计时外从两侧读回 3780×2430 RGBA，非背景覆盖均为 63.8707%，通道 MAE 为 0.0416，
超过 16 灰阶的像素为 0.0528%，差异符合 SSAA/MSAA 边缘滤波；对照侧遗漏 blend 的早期版本曾得到 MAE
11.33 并被门禁拒绝，修正后才允许使用性能数据。由此排除了空帧、错误 alpha 或漏 packet 造成的假快。

两个独立进程、每个后端各六批的结果为：

| 会话 | D3D11 ss2 完整帧中位 | SDL_GPU msaa4 完整帧中位 | ss2/msaa4 | 提交 P95（ss2/msaa4） |
| --- | ---: | ---: | ---: | ---: |
| 1 | 3.570 ms | 3.608 ms | 0.989× | 4.041 / 4.407 ms |
| 2 | 3.578 ms | 3.544 ms | 1.009× | 4.168 / 4.318 ms |

完整帧一轮退化 1.1%、一轮改善 0.9%，只能判为无差异；GPU P95 两轮反而退化约 9.0%/3.6%。640×400
下 GPU 固定命令成本也明显更高。clear-only 的 1.34× 因此只是 resolve/fast-clear 下界，不能推广到真实命令
解释。预设的“至少 1.15× 或绝对 1 ms、P95 不退化、像素验证通过”门槛明确失败。

最终决策是执行上一节的失败分支：不加入生产 SDL_GPU 后端，不扩张仓颉 SDL_GPU FFI，也不复制 Texture、
SDL_ttf atlas、device-loss 和 command epoch 所有权体系。现有 `RenderCommand` 值语义边界继续作为唯一显示列表；
D3D11 + 像素预算 Auto 保持生产实现。两个原生探针作为可删除、非发布的反证装置保留，只有新硬件、SDL 或
驱动使代表场景重新通过同一门槛时才重开后端设计。这个否决减少了状态空间和维护负担，是综合收益最大化，
而不是因“更现代”的 API 名称引入没有用户收益的第二套内核。
