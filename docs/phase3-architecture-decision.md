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
  校验 renderer、resource 和 epoch，失败不会半画；嵌套录制按原 z 序扁平化，异常后恢复调用方 clip。
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
4. 持久节点观察稳定性和命令规模后自动保存透明 Renderer value display list；动态协议退避，dirty scope
   重录，资源/epoch 变化安全失效，全局 32 MiB LRU 防止缓存无界；
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
   和 phase3 比例门禁；在 Windows 多个 SDL driver 及 Linux/macOS CI 建立 capability/回退矩阵。damage 未达到
   独立收益阈值且未证明跨后端一致前，不扩大 partial 条件，也不围绕它继续加层级或空间索引。
2. **持续校准已经自动化的边界策略。** 当前以单根、后代总量和最大分支宽度形成确定性候选，明确拒绝“每节点
   一层代理”和深廉价链；诊断输出 layout/paint 命中、command bytes、录制/拒绝/dynamic bypass 与 LRU 淘汰。
   后续只在 examples/bench 证明误升或漏升时调整阈值，应用代码不感知策略变化。
3. **把固定 16px 扩展演进为显式 paint bounds。** 当前值覆盖框架阴影；若复杂 Canvas/特效实验出现更大越界，
   引入 `paintOutset`/`paintBounds` 契约并做 debug 可视化，而不是不断增大全局 damage。该变更应由越界像素用例
   先证明需求。
4. **raster cache 仅作为二级、可撤销优化。** 只有真实 GPU profiler 证明“稳定复杂命令反复 replay”仍占预算，
   才按命令成本、稳定帧数和面积提升到纹理；必须有 LRU/显存上限、DPI/字体/资源 epoch 失效、透明混合测试和
   thrash 降级。当前无头数据不能证明需要它。
5. **hit-test/语义索引继续待证。** 增加 1k/10k 节点、深层 clip、重叠 overlay、drag capture 和键盘焦点场景；
   只有事件耗时真实越过预算才维护空间索引，避免陈旧几何、capture 路径和 accessibility 顺序三套事实源。

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
