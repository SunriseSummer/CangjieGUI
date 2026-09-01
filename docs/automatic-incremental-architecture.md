# 自动增量 UI 架构

本文记录 CangjieGUI 从“每个显示帧重新执行整个声明体”演进到自动增量执行的设计约束、
当前实现和后续阶段。目标是让普通应用只描述 UI 和读写 `State`；组件跳过、脏集裁剪、缓存和
damage 都由框架决定。`RetainedSubtree` 只保留为兼容和底层实验接口，不是常规性能指南。

## 设计不变量

1. **正确性优先于命中率。** 自动缓存不得使闭包捕获值、焦点顺序、事件处理、overlay、
   `rememberState` 或生命周期资源停留在旧版本。
2. **状态是可见变化的入口。** 会影响 UI 的可变数据使用 `State`；后台结果通过
   `DesktopApp.post` 回到 UI 线程后写入 `State`。普通变量既不产生依赖边，也不能独立唤醒
   空闲事件循环。
3. **一次提交可回滚。** 新依赖、挂载身份、effect 和缓存输出先进入构建事务；完整根构建成功
   后才替换已提交图，异常不能留下半棵新树。
4. **最小安全重启集。** 同一批变化只执行覆盖全部脏节点、且不含祖先支配冗余的作用域集合；
   干净兄弟不执行声明体。
5. **阶段脏度单向传播。** Build 变化可影响 Measure、Layout、Paint；Layout 变化可影响 Paint，
   反向传播必须有明确依赖证据，不能用一个全局 `dirty` 位退化为全树工作。
6. **有界自适应。** 缓存必须受内存预算、收益估计和滞回控制；命中率低或含动态协议的子树应
   自动旁路，不能让“缓存一切”变成内存和录制开销陷阱。

## 状态通知的有序代数与无复制派发

`State` 的观察者不是无序集合，而是按注册顺序连接的序列。令当前序列为 `L`、活动位投影为 `α`；一次通知
在入口只捕获 `n = |L|`，随后遍历 `α(L[0,n))`。注册是序列连接 `L · [listener]`，因此不会倒流进入已经开始的
窗口；取消是活动位上的幂等操作，尚未到达的项会被跳过。若回调嵌套写入同一 State，内层通知重新捕获当前
`|L|`，所以能看到外层回调刚注册的观察者。

实现用 `notificationDepth` 保持所有活动窗口的下标稳定：通知中取消只写 tombstone，最外层退出后才取活动项
的保序商并物理压缩；无取消的常见路径只有一次线性遍历，既不复制数组，也不做第二遍压缩扫描。`finally`
保证用户回调抛异常时深度与 tombstone 仍能收敛。派发还捕获首个回调异常、继续送达其余活动观察者，最后再
重抛；业务错误因此不能阻断后置的框架依赖失效。五个暖样本中，直接写入带 1/256 个观察者的同一 State，
中位数由 699 ns/11.38 μs 降至最终 455 ns/2.78 μs，分别约改善 1.54×/4.09×；每个样本都精确核对回调总数。

事务层把同一原则提升到跨源 worklist。State 通知与去重的 Derived continuation 构成有序工作序列 `W`；一次
派发产生的新写入追加回 `W`，源通知始终先于下一条 continuation 排空，因此系统迭代到无毛刺不动点。异常不再
控制工作表是否前进，而是进入左偏的 `First<Exception>` 累积：`None` 是单位元，首个 `Some(error)` 吸收后续错误。
到达不动点后才报告该首错；队列不变量损坏和超过 100000 次派发的非收敛环仍立即终止。观察者里的嵌套 batch
加入当前 worklist，不递归 flush，从而保持一个外层原子边界。

实现把失败槽放在 FrameScheduler 上复用，正常通知仍返回 `Unit`，只有 catch 才写槽；flush 结束只读取一次，避免
为了罕见异常给每个 listener 构造错误值。5000 个“首源抛错 + 63 个后续 State”事务的五样本中位为
30.422 μs/事务，精确报告 5000 次异常并送达 315000 次后续回调。自动组合反例同时证明：修复前后续可见 State
虽已写入，body 仍因依赖通知被截断而保持假干净；修复后下一帧必定重建。正常单写事务最终复验为默认/结构策略
654/668 ns，相对上一切面的 641/637 ns 观察到约 +2.0%/+4.9%（绝对 13/31 ns）；两写默认/结构路径为
931/947 ns，净零事务后的完整帧仍为 6231/3945 ns。该小幅微基准成本换取跨源依赖正确性，后续继续以长窗口
监测，不用异常语义换取假快。

Derived observation 的 continuation 也从瞬时工作项迁到观察句柄所有权。原实现每次首次 defer 都创建
`DeferredStateObserverAction(identity, notify)`；现在 observation 建立时创建一次不可变 `(identity, action)`，
各事务只把同一引用加入 worklist。identity set 仍负责一批内去重；派发前先移除 identity，因此回调重入写源时
同一 continuation 可以安全地再次入队。它是一个稳定的效应箭头，而队列只保存调度位置，不再复制箭头本身。

新增长窗口以 25 万次单观察事务和 2 万次 32 观察者事务精确核对回调数。五样本中位由
1.243 μs/17.878 μs 变为 1.241 μs/17.188 μs：单节点持平，32 节点改善约 3.9%；更确定的收益是第二个窗口
把 640000 个瞬时 action 创建降为 observation 建立时的 32 个长期节点，减少 GC 长尾而不改变不动点顺序。

### State-owned 事务通知槽

事务原先为每个首次写入的 State 新建一个 `TypedPendingStateNotification<T>`。调度器虽然只允许同一 identity 有一条
pending segment，对象所有权却仍放在瞬时队列，重复 batch 会反复创建相同 `source + T` 形状。当前把一个可空槽
下沉到 State 生命周期：第一次真正需要类型擦除通知时惰性创建，之后只替换 `previous: T` 与端点比较位。默认且
无观察者的动画 State 仍不创建槽；代价是每个 State 增加一个可空引用。

这条协议可看成 identity 上的线性段所有权：pending source set 证明一个 State 同时至多有一个未派发段；派发先从
集合移除，再把 `previous` 与比较位复制到局部值后调用用户代码。观察者若重入写同一 State，便可立即在同一对象上
准备下一段，而当前调用继续消费已经复制的旧端点。端点策略抛错、事务首错排空和 `State<?T>` 都有反例测试；
跨事务对象身份测试则确定性证明没有再次创建槽。

首版把泛型旧值保存成 `Option<T>` 以显式表示 Idle/Pending，实测被否决：默认/结构单写由基线 665/671 ns 升至
737/758 ns，64 State 异常排空由 30.252 升至 36.417 μs，仅 32 State 宽事务约改善 0.7%。原因是每次 prepare/
dispatch 的泛型 Option 包装、匹配成本超过当前分配器的短命对象成本。改为直接保存可变 `T`、由 scheduler set
承担 pending 证明后，五样本中位为：单写 645/668 ns，净零 821/841 ns，净变化 881/936 ns，32 State 合并
6.389 μs，异常排空 30.004 μs。相对基线，主要单 State 路径改善约 0.4–5.1%，结构净零和宽事务约 +1–2%；综合
考虑确定性零重复创建与 GC 长尾，保留直接 `T` 版本，并把 Option 版本作为“更显式状态机不一定更快”的实测反例。

## 派生状态的 epoch 证书与精确回退

一个 `DerivedState` 可视为固定源积 `S₁ × … × Sₙ` 上的纯映射。数组重载在构造时快照源序列，使这个积的对象
与投影固定；要改变依赖拓扑就构造新的派生实例，避免外部可变数组把缓存和订阅指向不同源。缓存提交使用
`capture → compute → commit` 两阶段协议：计算异常不提交 revision，计算中源自写也会令下一次读取重新求值。

当前仓颉没有可用于该 API 的 parameter pack，因此固定异构积提供一至五源重载，同类型动态积继续使用数组入口；这与
[Kotlin Flow `combine`](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines.flow/)
的一至五异构重载加同类型集合入口相同。四/五源不是语法糖式嵌套：它们直接构造一个 revision tracker、一组失效边和
一个 compute 节点。四源同进程五样本中，稳定读取的嵌套/融合中位为 150/153 ns；单源失效为
2162/1641 ns，融合约改善 24.1%，每次参与计算的派生节点从 2 精确降到 1。

结果商也遵守同一融合原则。固定一至五源的 `derive(..., policy:)` 直接构造 `DistinctDerivedState`，而不是先建普通
派生再用 `.distinct` 包一层恒等投影；epoch、revision 前像、上游订阅和商映射 `q: T → T/~` 位于同一个节点。
四源五样本中，layered/fused 的稳定读取为 157/152 ns，等价失效为 2160/1688 ns，融合改善约 21.9%，派生节点
从 2 降为 1。动态数组继续使用 `.distinct`，保留其 State-backed 首次 value/revision 合并采样。

对完全由内置 `State`/`Binding`/`DerivedState` 组成的图，进程 State 写入 epoch 是一个精确的否定证书：epoch
相同蕴含所有源 revision 均未变化，因此收集器外可 O(1) 返回缓存；epoch 不同只表示“可能变化”，仍比较完整
revision 向量，不能把无关 State 写入误作派生变化。自定义 `Observable` 无此证明能力时始终走精确向量路径。
在 build/measure/layout/paint 依赖图中，collector 外创建的稳定派生成为一个一等惰性节点：作用域只保存一条
直接边，节点的 invalidation-only 订阅递归连接声明源；源写入只标脏，不执行 `compute`。collector 内创建的
State-backed 临时派生没有跨帧身份，若强行聚合会每次拆装整组监听器，因此自适应保留按 State identity 可复用的
源前沿。自定义 `Observable` 无直接 State 边可登记，始终通过 `observe` 聚合，修复旧 collector 对它提交 0 边的
失效缺口。连接中途失败会逆序回滚，失败收集和卸载关闭全部边。

五样本基线中，1/256 源稳定读取为 221 ns/27.30 μs。首版双缓冲向量使 256 源反而升至约 29.55 μs，因而被
后测否决；当前分层证书加廉价 collector 活动门的最终 1/256 源稳定读取为 133/138 ns，相对原始值约改善
1.66×/198×，稳定期重算精确为 0。逐次失效重算由上一阶段约 0.71 μs 变为 0.79 μs（约 +11%、绝对约 79 ns），
换取下面宽依赖收集的数量级收益。

真实 Full `WidgetTestHost` 中，稳定 1/256 源派生的依赖重登记五样本中位由 8.29/70.61 μs、1/256 条边变为
7.48/6.86 μs、均为 1 条边；256 源改善约 10.29×。内联临时派生仍精确提交 1/256 条 State 源边，256 源中位
原为 149.23 μs，对同口径手工读取 63.25 μs。后续把全 State-backed 初始 revision/value 合并为一次源序遍历，
直接 State 以一次 ownership/dependency 检查取得同刻二元快照；该阶段五样本为 121.50/63.79 μs，派生相对手工
从约 2.36× 收敛到 1.90×。随后加入 `deriveStates(Array<State<T>>)` 静态专用路径，并让既有
`derive(Array<Observable<T>>)` 在构造时把运行时全 State 的源积正规化一次，避免每次源访问的接口擦除。最终同口径
五样本中位为：兼容擦除入口 99.34 μs、显式专用入口 93.27 μs、手工读取 58.87 μs；相对融合阶段分别改善约
18%/23%，派生与手工之比收敛到 1.69×/1.58×。空数组仍由原 `derive` 无歧义解析；自定义 Observable 保留原
“全部 revision → 全部 value”顺序；拓扑快照、自写、初始异常重试、无关写入和采样顺序均有反例。

稳定派生随后增加可选的结果商映射。默认节点仍把上游 revision 解释为“可能变化”并完全惰性传播；显式
`StateMutationPolicy<T>` 的节点在有订阅边时计算纯投影，把结果送入商映射 `q: T → T/~`，只有商类变化才推进
自身 revision 和下游失效。无人订阅时仍为拉取缓存，不支付主动比较。订阅安装先进入 derived-read 深度，再完成
初始 refresh 和上游连接，防止初始化读取递归登记自身或泄漏为额外 State 边；比较/计算异常不提交捕获向量，保持
后续重试。多个订阅者各保存已见的节点 revision，因此首个订阅者完成全局缓存刷新后，其余订阅者仍各收到一次变化。

首版把可选策略字段和分支直接放进所有 `DerivedState`；同源码临时 A/B 中，默认每次失效重算的 7 样本中位为
905 ns，对关闭策略分支的 861 ns 约增加 5.1%。最终改为包内 `DistinctDerivedState` 专用子类：普通节点恢复原始
字段布局和无分支提交，只有重算点保留一次提交动态分派；默认重算中位为 866 ns，相对无分支对照约 +0.6%。
公开构造仍关闭，`open` 只用于内核特化，不形成应用侧继承协议。

240 个 selector 读取同一根 `ModelStore`、每次只改一个数组字段的五进程中位：普通可能失效使 240 个分支体执行，
最终同机负载下完整 headless 帧为 3.461 ms、build 为 1.929 ms；结果等价 selector 仍执行 240 个廉价投影比较，
但只让 1 个分支体执行，完整帧为 1.982 ms（改善约 42.7%），build 为 0.386 ms（改善约 80.0%，约 5.0×）。
较安静窗口的绝对值整体约低 2.7×而配对比率相近，因此判断以同进程比率和 240/1 确定性计数为主。这不是把 O(N)
订阅分发伪装成 O(1)：收益来自用 O(N) 小投影替代 O(N) 声明重建；更大或更昂贵模型仍应按特征拆 Store。

## 第一阶段：自动组合图（已实现）

每个框架 builder body（`Root`、`VStack`、`Panel`、`HStack`、`Keyed` 等）对应一个持久化
`AutomaticCompositionRecord`。记录保存上次提交的 child array、焦点序列、帧订阅和独立
`StateMountScope`。开发者仍写原来的 UI：

```cangjie
VStack {
    Label("${profile.value.name}")
    Panel { accountDetails(profile.value) }
}
```

读取 `State` 时，框架建立有向依赖边 `State -> Scope`。设本批发生变化的状态集合为 `ΔS`，
直接脏作用域为：

```text
D0 = { c | 存在 s ∈ ΔS，使 (s -> c) 属于依赖图 }
```

框架向祖先传播“后代脏”以保证能到达这些节点，但区分两种原因：

- `selfDirty`：作用域自身读取的状态变化；其局部变量或闭包捕获可能改变，执行该 body 时保守
  刷新其自动后代。
- `descendantDirty`：只有后代读取的状态变化；执行祖先只用于到达脏路径，干净兄弟 body 直接
  复用。

因此安全重启前沿可写成脏集中的祖先反链：

```text
R = { c ∈ D | D 中不存在支配 c 且需要全后代刷新的祖先 }
```

实现不会先构造昂贵的全图拓扑排序；挂载树已提供祖先关系，失效时沿父链标记，构建时按
`selfDirty/descendantDirty` 做常数时间判定。一次状态写的标记成本为作用域深度 `O(h)`，
一次增量构建的成本接近脏路径和必要兄弟壳节点之和，而不是全 UI 节点数。

根作用域还必须缓存**组合后的逻辑根**，而不是只缓存 body 发射的原始序列。设有序声明序列为
`W*`，框架的隐式根正规化为 `q([])=EmptyView`、`q([w])=w`、`q([w₀,…,wₙ])=Stack(W*)`。
旧路径把 `W*` 放进 automatic record，却在记录外每帧重新计算 `q`；多子项稳定树虽然没有执行 body，
仍会新建 `Stack` 并扫描整个序列，实际复杂度保持 `O(|W*|)`。现在 Root 的记录输出恒为单元素
`[q(W*)]`，干净采用直接复用同一 automatic render node，稳定构建和 layout 入口为 `O(1)`；脏路径仍在
暂存事务中重新计算 `q` 并 reconcile 到原边界，因此零/一/多子项切换不会冻结旧内容，也不会改变公开 builder 语义。

这个边界可理解为先把“自由有序声明序列”取到框架的规范代表元，再缓存代表元；缓存若放在正规化之前，
等价声明在执行表示上仍不等价。确定性反例分别约束干净多子项根的对象身份复用，以及脏更新从多子项变为
单子项时边界身份不变而内容正确提交。

### 身份与列表

内置 builder 使用“父作用域 + 语义种类 + 同类声明序号”形成自动身份，不同容器不会因条件
切换而误别名。可插入、删除或重排的重复项目继续使用 `ForEach(items, key: ...)`；key 是数据
身份语义，不是性能开关。自动作用域位于 `Keyed` 路径下，所以局部状态和缓存随项目移动。

局部声明同样分为位置积与显式键余积。固定结构中的 `remember`、`rememberState`、keyless `mountEffect` 和
`lifecycleEffect` 在 lexical/automatic 作用域中形成有序有限积；首次成功提交后，槽数、值类型与声明种类必须保持，形状漂移会在任何 ownership 修改和 effect setup 前使完整
根构建回滚。条件、循环和重排内容进入 `Keyed`/`ForEach` 的独立命名空间，或直接使用显式 key。位置路径采用
显式 key 无法构造的空段作为和类型标签，因此两种身份不会碰撞；已提交路径向量持久复用，稳定重建不再逐槽拼接
字符串。形状同时保存 `RememberedValue + MountEffect + LifecycleEffect` 和标签，防止同槽跨种类别名。形状表是
惰性的 `None | 非空映射`，没有 keyless 声明的现有 scope 不分配表。

反测曾否决“每个 scope 总是分配形状 HashMap”的首版：240 分支强制重建五样本中位从 1.52 ms 升到 2.02 ms，
约退化 33%。惰性表示与路径向量落地后，同口径为 1.51 ms（噪声内）；256 个稳定 keyless/显式字符串键槽为
175.71/172.32 μs，仅约 2% 差异，且每帧初始化均为 0。五个语义反例覆盖稳定复用、显式/隐式命名空间分离、
`ForEach` 重排、同类型条件槽漂移回滚、整个 `Keyed` 子树卸载重挂和失败插入回滚。

位置槽随后推广为通用 `remember<T>`，不再迫使控制器、格式化器、动画器或派生图先包装成可写 State。工厂执行期
由线程局部动态作用域标记“此对象将获得稳定挂载身份”；其中创建的 `DerivedState` 因而选择长期聚合正规形，而非
仅依据“当前正在 build”误判为短命节点。工厂结束后标记严格恢复，普通内联派生仍采用可复用的直接 State 前沿。
remembered 值和 State 共用同一位置/显式键和类型检查、插入日志、形状提交及卸载规则；任意 Resource 不做隐式
析构，继续由 `mountEffect`/`lifecycleEffect` 明确所有权。

256 源 Full host 五样本中位：外置稳定派生 8.73 μs、`remember { deriveStates(...) }` 10.64 μs、每帧内联
`deriveStates` 102.95 μs、手工读取 63.95 μs。remembered 版本相对内联约快 9.7×，提交边由 256 降到 1，compute
和工厂在稳定期都精确为 0 次/帧；相对手工移出 build 只增加约 1.9 μs 的位置查找与挂载验证成本。

build-local 依赖前沿也采用自适应有限集合表示。常见 scope 只有 0–1 条直接边，前 8 个唯一 identity 直接扫描已经
存在的 canonical dependency 数组，不另分配 HashSet；第 9 条边才单调提升为哈希索引。提升容量使用上次成功提交的
依赖宽度作为持久图先验，并至少覆盖当前小前沿的两倍。这样“小集合无哈希分配”和“稳定宽集合不重复扩容”同时成立，
提交、动态删边和失败回滚仍只消费同一个规范依赖序列。

同进程五样本的纯 build 相位中，240 个单依赖分支的局部更新由 209.60 降至 191.26 μs（约改善 8.8%），强制
全重建由 818.44 降至 745.10 μs（约改善 9.0%）。首版提升只按当前 8 项预分配，曾令 1k/10k 宽依赖从
307.77 μs/2.863 ms 退化到 404.06 μs/3.420 ms，因而被反测否决；加入提交宽度先验后恢复为
311.76 μs/2.892 ms（约 +1.3%/+1.0%，噪声量级），依赖数仍精确为 1k/10k。

宽前沿随后不再每次都从有序读取轨迹重新证明同一个集合。令上次提交的规范依赖序列为 `C`，本次 body 的去重
读取轨迹为 `T`；依赖语义本身是 identity 有限集，在并集下满足交换、结合与幂等，但声明执行还天然给出顺序。
新 collector 先逐项 zip `T` 与事务开始时快照的 `C`：前缀相等时直接复用对应 observation，不分配临时 HashSet、
也不查询持久 HashMap；第一个不匹配点以后单调进入原通用集合路径，所以重复、重排、插入和删除仍完整正规化。
若提交时没有新 observation 且 `|T|=|C|`，由于 `T` 已去重且每一项都取自 `C`，即可由子集加等势推出
`T=C`，直接保留持久数组和索引；否则仍逐项关闭差集并原子替换前沿。

这一优化把稳定执行轨迹当作集合等价的证书，而没有错误地把依赖顺序提升为公开语义。五个独立进程中，1k/10k
单作用域“局部写 + 重建”中位由 233.808 μs/2.310 ms 降到 186.383 μs/1.740 ms，约改善 20.3%/24.7%；
最终 build 分相为 180.508 μs/1.728 ms，写入/失效只有 1.191/2.150 μs。10k 无依赖收集的原始 State 读取仍为
0.265 ms，表明剩余成本主要是逐值进入动态 collector，而不是通知或 layout。红测试覆盖完全相同的 16 源轨迹，
并补测长前缀后的重排及等基数替换，防止快速证书吞掉真实边变化。

曾试验只保存 prefix cursor、命中时连临时依赖数组也不物化；同口径 10k 中位反而从 1.896 升到 2.184 ms，且
截短轨迹还需要额外物化/索引回退证明。该表示已撤销，避免用更复杂的状态机换取负收益。

同一 build 事务原先还为 state/retained/automatic/effect 四类声明各创建一个 visited HashSet，即使叶 scope 四类都为
空。它们现在各自复用已有的有序 canonical key 日志：0–8 项线性判重，第 9 项才建立独立索引，容量同样采用对应
已提交日志宽度。四个余积分支的索引彼此独立，所以相同底层 path 可合法地同时命名状态、effect 和子 scope；每类
内部的重复仍在写入日志前失败。相对上一段已经自适应 dependency 的版本，240 分支局部/全量纯 build 又从
191.26/745.10 μs 降至 178.45/585.77 μs，追加改善约 6.7%/21.4%；相对最初全 HashSet 版本累计改善约
14.9%/28.4%。128 个静态声明重放由 6.27 降至 5.26 μs，外部版本声明由 49.64 降至 45.59 μs，约改善
16.0%/8.1%。

上述自适应集合消除了 HashSet，却仍暴露一个更基础的分配事实：每个实际重建的 scope 都新建一个
`StateMountBuild` 及其六个小日志。最终实现把这些 build-local staging 对象放入每个 `StateStore` 自己的有界
frame arena；逻辑事务在完整提交或回滚后清空，下一帧复用物理 cell，而已提交 key、依赖和形状仍只存在
`StateMountScope`，因此 arena 不是第二份状态缓存。cell 复用前会拒绝尚未 commit/cancel 的新依赖，释放时还把
scope 与 invalidation closure 重置到 root/no-op，不能让 arena 意外延长已卸载子树寿命。

直接给每个持久 scope 永久附一套 scratch 的首版虽然把 240 分支局部/全量 build 做到 154.92/504.30 μs，却会让
10k 个只在首次挂载执行的稳定 scope 常驻约六万张空日志。最终 arena 只保留 256 个 cell，超出部分仍是帧内临时
对象，常驻空间因此为 `O(min(峰值活跃事务, 256))`，而非 `O(挂载 scope 数)`。最终编译状态的五样本中位为
145.72/505.74 μs，相对无 arena 的 178.45/585.77 μs 改善约 18.3%/13.7%，与无界 per-scope scratch 同属一个
噪声量级，却换回确定的内存上界。单测同时断言跨帧对象身份复用、所有声明日志与分类位归零、未回滚依赖拒绝复用，以及 300 个并发事务
只保留 256 个 arena cell。

持久 scope 本身随后采用相同的稀疏原则。旧 `StateMountScope` 在构造时固定创建 state/retained/automatic/effect
四张所有权日志，以及 build dependency 的数组和 HashMap；一个从不拥有声明、也不读取 State 的 scope 仍产生六个
集合对象。新正规形可写成
`Scope = Identity × DirtyState × (1 + Ownership) × (1 + BuildDependencies)`：`1` 是无需分配的空对象，两个
`Some` 分支分别保存四类声明的原子提交积和依赖数组/索引。声明所有权与依赖保持独立，因为大量叶 body 只读 State，
而容器 body 只拥有子 scope；把六个集合重新塞进一个“大 facet”会破坏这种稀疏性。

240 行场景的确定性分布为 2 个 ownership-only scope、240 个 dependency-only scope、0 个并存 scope。旧布局为
242 × 6 = 1452 个集合；新布局实际持有 8 个 ownership 集合和 480 个 dependency 集合，减少 964 个集合对象
（约 66.4%）。计入 242 个 facet wrapper 后，总对象仍由 1452 降至 730，净减 722 个（约 49.7%）。最后一条声明
或依赖消失时，提交会在关闭旧订阅后把对应 facet 降回 `None`，所以动态空 scope 也能回收常驻结构，而不只是首次
构造更轻。

最终五样本原始局部/全量 build 为 164.53/508.38 μs，对稀疏化前 145.72/505.74 μs；同期两个未改变算法的
keyless/显式状态槽对照整体慢约 4.4%，按该机器因子归一后局部约增加 8.1%（绝对约 12 μs），全量约改善 3.7%。
接受这个局部微成本的依据是常驻对象近半减少、全量路径没有实质退化，且局部 build 仍只执行 1/240 个 body；
没有把内存收益伪装成所有工况都加速。1k/10k 单 scope State 重建五样本为 216.57 μs/2.396 ms，低于此前
311.76 μs/2.892 ms，宽依赖 facet 未出现容量或查询退化。

上述首版仍在每个 dependency-only facet 中固定创建 HashMap，等于 240 个单 State 叶各自保留一张单条目索引；
这也解释了稀疏化后局部路径没有同步变快。最终让 committed dependency 使用与 build-local 前沿相同的自适应有限集：
0–8 条边直接扫描 canonical 数组，第 9 条才建立 identity→dependency 索引；提交缩回 8 条时降级并释放索引。
宽图的 HashMap 在连续宽提交间 clear 后复用容量，失败 build 不接触已提交表示。

240 行场景因此再移除 240 张 HashMap：集合对象由稀疏首版 488 降至 248；计入 wrapper 后总对象由 730 降至
490，相对原始 1452 净减 962 个（约 66.3%），集合本身减少约 82.9%。最终五样本局部/全量 build 为
147.19/498.15 μs：相对固定 HashMap 版 164.53/508.38 μs 改善约 10.5%/2.0%，相对 facet 前
145.72/505.74 μs 为约 +1.0%/-1.5%，局部微成本基本收回。1k/10k 宽图为 224.19 μs/2.163 ms，对固定索引版
216.57 μs/2.396 ms 分别约 +3.5%/-9.7%，没有把小图收益转成宽图退化。测试精确看护第 8/9 条升降级、动态删边
关闭订阅，以及所有 32 个 State-reading automatic 叶均无 committed HashMap。

同一个原则随后覆盖 measure/layout/paint。旧 `PhaseStateDependencies` 在构造时固定创建 committed 数组/HashMap、
pending 数组/HashSet 和 created 数组；每个 retained 或 automatic render 节点又固定拥有三个 phase collector，
所以即使没有任何 phase 读取 State，一个节点也常驻 15 个空集合。新表示保留三个 collector 身份和各自失效闭包，
内部存储则全部从 `None` 起步：第一次真实读取才创建 committed/pending 数组，0–8 条边线性查找，第 9 条才提升
两个索引；phase 重新变空时全部降回 `None`。

失败回滚不再维护第三张 created 日志。新建边恰好是集合差 `Pending − Committed`；小集合差最多扫描 8 项，宽
集合差由 committed 索引判定，因此 cancel 可精确关闭新边而不复制真相。最终空 phase 从 5 个集合降到 0，单依赖
稳定 phase 从 5 个降到 2，宽稳定 phase 从 5 个降到 4；一个完全无 phase State 的渲染节点直接减少 15 个集合。
测试覆盖从未读取、单边稳定复用、8→9→8 提升/降级、失败保留旧边并关闭新边，以及重新变空后全部存储释放。

低噪声同机 A/B 中，96 节点自动命令命中由 3.117 降到 2.628 μs（约改善 15.7%），24 节点复杂兄弟自动晋升由
18.113 降到 16.087 μs（约改善 11.2%）；各自强制对照为 +1.4%/+0.9%，处于调度噪声。后续七样本的同进程
`direct/cache` 中位比由 6.54× 提升到 13.58×，`full/auto` 由 3.42× 提升到 3.70×。显式 retained hit 首版曾由
53.227 升到 57.713 μs；为空 committed/pending 加常数时间提交短路后回到 53.605 μs（约 +0.7%），没有用空间收益
掩盖稳定命中退化。

状态写接口也按同一“一个规范提交”原则收敛。旧链式 `a.project(...).project(...)` setter 在每层先读取上级 Binding，
再调用上级 setter；深度 `n` 的一次字段写因此产生约 `1+…+n` 次根模型读取。`Bindable.update(A→A)` 现在是一等
端态变换，Binding 把它经 Lens setter 逐层提升为根模型上的一个 `S→S`，最终只执行一次根 read-modify-write。
直接赋值也复用这条 modify 通道；确定为根 `State` 的浅投影在创建时选择等价的单读快速闭包，自定义 Bindable 仍
保留其 update 覆写语义。

五样本中，1/8/32 层旧 setter 为 631 ns/3.323 μs/30.769 μs；新 setter 为
604 ns/1.603 μs/4.794 μs，32 层约改善 6.42×，1 层还约快 4.3%。显式 `Binding.update` 为
504 ns/1.177 μs/3.108 μs，32 层相对旧 setter 约改善 9.90×。测试以 32 层计数 Bindable 证明 setter/update
都只读根一次、写根一次，并覆盖嵌套模型兄弟字段保留、根观察者单次通知和 transform 异常零写回。

后续反例发现，上述修复只正规化了“逐层构造 Binding”，没有正规化“先用 `Lens.then` 组合再投影”。朴素 Lens 只保存
`get/set`；第 `n` 层 `set` 必须先执行长度 `n-1` 的完整 `get`，再递归执行前缀 `set`，故读取次数满足三角数增长。
现在 Lens 还保存焦点 endomorphism 的提升 `modify: (S, (A→A))→S`，组合定义为
`modify(l.then(r), s, h) = modify(l, s, a ↦ modify(r, a, h))`。这正是 optic 对端态变换的组合解释：从外到内每层
读取一次、从内到外每层重建一次。`set` 复用该通道，Lens-backed Binding 保留它而不退化回独立 `get/set`；纯
Reducer pullback 也直接把局部 reducer 作为 endomorphism 提升。EffectReducer 必须同时取得效果批次，允许两次线性
遍历，但同样不再出现二次前缀展开。

同进程五样本中，1/8/32 层朴素/融合 Lens Binding 写入中位为 739/2416/26843 ns 对
697/1650/4914 ns，分别改善约 5.7%/31.7%/81.7%；`update` 为 652/2245/24065 ns 对
576/1311/3916 ns，改善约 11.7%/41.6%/83.7%。32 层融合 Lens 相对逐层 Binding 的写入 5698 ns 还快约
13.8%，update 的 3916/3287 ns 则保留约 19.1% 的一等 optic 间接调用成本，不以零成本抽象虚报。确定性测试按
32 层精确计数 get/set/transform，并覆盖 Binding、Reducer、EffectReducer 与效果顺序。隔离 Reducer pullback 的
8/32 层朴素/融合中位为 1830/24314 ns 对 1140/4468 ns，改善约 37.7%/81.6%；一层对照受同机调度噪声影响，
不据此宣称浅路径收益。

## Action 对模型的代数作用

大型特征的开发者接口新增 `Reducer<Model, Action>` 与 `ModelStore<Model, Action>`。它取三类成熟实践的交集：
[Elm Architecture](https://guide.elm-lang.org/architecture/) 的 Model/Msg/update 闭环、
[Redux 官方指南](https://redux.js.org/style-guide/) 的纯 reducer、最小事实与 selector，以及
[Composable Architecture Reducer](https://pointfreeco.github.io/swift-composable-architecture/1.10.0/documentation/composablearchitecture/reducers/)
的 State/Action/Reducer 特征组合；没有把特定语言的中间件、全局单例或副作用运行时搬进内核。

固定 Action `a` 时，纯 reducer 给出模型自同态 `rₐ: M → M`；Action 序列的自由幺半群 `A*` 通过左折叠作用在
`M` 上，空序列是恒等，序列连接对应端态变换组合。`dispatchAll` 正是该作用的一次规范解释：在一个根快照上按序
折叠，任一步异常则零写回，成功后只提交一个 State revision。`Reducer.then` 让多个 reducer 对同一事件顺序响应，
函数组合保证结合律；`pullback` 通过满足三定律的 Lens 把局部自同态提升到根模型，并用 `RootAction → ?Action`
表达未命中特征时的恒等变换。

`ModelStore` 自身只实现 `Observable<Model>`，故界面不能取得绕过 Action 的根 setter。`select` 直接产生现有
`DerivedState`，不复制派生事实；action-driven Binding 把候选字段值注入 Action，读取与观察仍投影同一个模型。
需要隔离无关 Action 时，`select(..., policy:)` 复用上述结果商节点，而不是另建字段 State 或要求开发者手工同步；
其 `Binding.update` 在一个根快照上完成 selector、焦点变换、Action 构造和 reducer，只写根一次。文件、网络、
时钟和后台任务留在外部动作层，完成结果经 UI 线程重新成为 Action；局部 UI 状态仍归 `rememberState`。

读取等价边界也扩展到可写光学投影。React Redux 的官方 [`useSelector` equalityFn](https://react-redux.js.org/api/hooks#equality-comparisons-and-updates)
和 Compose 的 [`derivedStateOf`](https://developer.android.com/develop/ui/compose/side-effects#derivedstateof) 都用“输入变化频率高于
界面真正关心的结果变化频率”解释商映射；CUI 进一步让 `Bindable.project` 与各 Store 的 `binding(..., policy:)` 在读取侧
复用同一 `DistinctDerivedState`，但 Lens setter、Action、Effect 仍走原写入态射。也就是说，观察商 `q: A → A/~` 不拥有
写权限，不能吞 reducer 或效果，只能决定 revision、观察通知和依赖失效是否跨类。

只有 reducer `pullback` 时，更新逻辑已经局部化，视图运行时却仍持有根 `ModelStore<RootModel, RootAction>`，必须重复
根 selector 与 Action 包装。新增 `ScopedStore<LocalModel, LocalAction>` 补齐这个缺口，方向与
[Composable Architecture 的 Store scoping](https://pointfreeco.github.io/swift-composable-architecture/1.0.0/documentation/composablearchitecture/store/)
一致：状态投影 `p: RootModel → LocalModel`，Action 提升 `i: LocalAction → RootAction`。子视图只接触局部领域，
但读取、观察、Binding 和派发仍落到唯一根 State/reducer；这把 Redux 所说的
[按 state slice 组合 reducer](https://redux.js.org/usage/structuring-reducers/splitting-reducer-logic)从纯函数组织延伸到视图依赖边界。

从范畴角度，一个特征边界是二元变换 `(p, i)`；继续 scope 用 `(q ∘ p, i ∘ j)` 组合，恒等投影/Action 是单位，
函数结合律保证任意括号方式得到同一状态读取和 Action 路由。因此深层 scope 无需知道根类型。与 reducer pullback
配对时，根 Action 提取 `e: RootAction → ?LocalAction` 还应满足 `e(i(a)) = Some(a)`；非特征根 Action 应映为
`None`。框架不能替任意业务闭包证明这些等式，测试以组合 Lens 读取和 Action 往返验证边界。

局部 Action 提升唯一扩展成自由幺半群同态 `i*: LocalAction* → RootAction*`，保持空序列与连接；因此
`ScopedStore.dispatchAll` 可以先组合所有层的提升，再用根 Store 的左折叠解释一次。内部把序列表示成接受消费者的
producer（Church encoding），各层只包装一次 producer，不为每层物化 Action 数组；reducer 异常时隔离的 fold 不会
写回。状态侧普通嵌套投影会函数组合并融合到一个 Derived 节点，避免根更新后逐层刷新缓存；显式等价策略把 `p`
因子分解到商空间 `LocalModel/~`，成为不可穿透的语义边界，后续投影以该商节点为新根继续融合。

五个独立进程样本中，单 action dispatch 相对直接 `State.update` 的中位数为 550/458 ns，增加约 92 ns（20.1%），换取强类型
Action 边界和集中可测试规则；这条单动作路径不是零成本抽象。32 个 Action 逐次事务 dispatch 为 8.413 μs，
`dispatchAll` 单快照折叠为 2.895 μs，约改善 2.91×；两者都只通知 20000 次，但 revision 从 640000 降为 20000。空序列、Reducer.then
结合律、Lens pullback、selector、action Binding 单快照、领域等价策略和中途异常零提交均有确定性测试。

ScopedStore 最终五个独立进程中位显示：根 ModelStore 单 Action 为 1.585 μs，1/8/32 层纯 Action 提升为
1.686/1.814/2.754 μs。1/8/32 层稳定局部读取为 538/499/496 ns，没有随深度增长；派发后首次局部读取为
2.921/3.679/6.123 μs。初版 8/32 层对应路径为 13.402/49.058 μs，投影融合约降低 72.5%/87.5%，同时保留
显式商边界。根以及 1/8/32 层的 32 Action 折叠为 7.581/14.543/22.291/46.716 μs。深层路径必须执行每个 Action
的 32 次业务提升，不能伪称常数时间，但相对 32 次深层逐次派发的约 88.1 μs 仍减少约 47%，且 revision 为
20000 而非 640000。测试另覆盖无关根 Action 不重建
局部 UI 分支、32 层融合、兄弟模型保留、单快照 Binding 和异常零提交。结论是 scope 应对应少量真实特征边界，不应
堆叠恒等层；实现保留批量融合，因为它在最坏深度仍有明确事务与时间收益。

末端 selector 也必须遵守同一组合律。原 `scoped.select(f)` 实际构造 `root → scope-node → selector-node`，把已组合的
`p` 又物化成中间响应节点；现在 projection 保存的根与商边界直接生成 `f ∘ p`，只在显式等价边界后重新起图。8 层
同进程五样本中，显式 `scoped.map(f)`/融合 `scoped.select(f)` 的稳定读取中位为 406/170 ns，改善约 58.1%；dispatch
后读取为 1524/1024 ns，改善约 32.8%，参与的 Derived 节点从 2 降为 1。默认 scope、既有 policy 边界和 Action 路由
语义均未改变。

后续又试验把 Action 侧也改造成与状态投影同形的动态 `ScopedActionRoute`：每层只保留一个组合后的
`LocalAction → RootAction` 和根 sink，理论上可消除批量 producer/acceptor 链。当前工具链却不能把接口派发和异构
组合闭包充分单态化。五进程中位中，1/8/32 层单 Action 从 498/595/875 ns 变为 524/687/1225 ns，32 层退化约
40.0%；32 Action 的 1/8/32 层从 3992/8516/22650 ns 变为 3811/9631/31965 ns，深层退化约 41.1%。该生产改动
已完整撤销，只保留 `scoped-store` 隔离基准。结论不是放弃 Action 组合律，而是在缺少编译期 case-path/宏单态化
之前，现有静态闭包链比额外的运行时投影对象更合适。

## Lens × Prism 的特征路径

仅有状态 Lens 仍留下一个人为一致性条件：局部 reducer 的 `RootAction → ?Action` 提取和局部 Store 的
`Action → RootAction` 提升分别手写，类型系统无法证明它们指向同一个和类型分支。业界的
[Swift Case Paths](https://github.com/pointfreeco/swift-case-paths) 已把 enum case 做成可提取、可嵌入、可组合的一等路径；
[Profunctor Optics](https://www.cs.ox.ac.uk/people/jeremy.gibbons/publications/poptics.pdf) 则给出 Lens、Prism 及组合的统一
理论。CUI 采用较小的具体表示，不把高阶 profunctor 编码暴露给仓颉调用者：

- `Prism<S,A>` 保存 `extract: S → Option<A>` 与 `embed: A → S`，要求 `extract(embed(a)) = Some(a)`；
- `FeaturePath<R,RA,M,A> = Lens<R,M> × Prism<RA,A>`；
- `then` 在积范畴中逐分量组合，因此恒等与结合律分别来自 Lens 和 Prism；
- child reducer 的 `pullback(path)` 与根 Store 的 `scope(path)` 消费同一个值，消除两套路由漂移。

第一版公开抽象采用 class，并让新重载转发到旧的闭包重载。O2 五进程中位显示 reducer 手写/路径为 133/165 ns，
固定增加约 32 ns。实现随后改为不可变 struct，并在组合根捕获 Prism 底层闭包，避免每次 Action 再经过包装方法；
最终 reducer 为 120/152 ns，绝对差仍约 32 ns，说明剩余成本来自把 case 路由保存为一等闭包后的当前工具链间接调用，
不是可继续删除的转发层。相同实验中 Store scope 为 988/920 ns，未出现退化。GUI 通常每秒只有数十到数千领域 Action，
32 ns 不进入帧预算，却换来 reducer/Store 路由一致、路径复用和可单测定律，因此接受这项 opt-in 成本；旧闭包重载仍
保留给极端热路径。未来若仓颉宏和生成代码能把 enum case 路由单态化，可在不改变 Prism/FeaturePath 语义的前提下
消除这部分间接调用。

确定性测试覆盖 Prism 的 embed-extract、其他 case 返回 None、路径状态/Action 同步组合、同一路径驱动 reducer 与
Store、批量单提交，以及 Effect 只在匹配 case 上映射。可选与重复状态不是总 Lens，因此继续分别使用下一节的
`ifPresent`/`forEach`，但其 Action 参数也接受 Prism。

数学定律若只写在文档里，仍会把最难的正确性责任留给每个应用重新翻译。`cui.testing` 因此把三组义务变成
deterministic witness checker：Lens 返回 Get-Put/Put-Get/Put-Put 三项结果；Prism 区分
`extract ∘ embed = id` 与命中分支上的 `embed ∘ extract = id`；StateMutationPolicy 在三个值上缓存完整 `3×3`
关系矩阵、重复九次比较检查样本确定性，再枚举 27 个传递蕴含。它们不声称有限样本构成证明，而是把合法性转成
可由边界样本或属性生成器搜索的反例。用户闭包异常原样传播，测试失败不会被伪装成某条定律的 `false`。

检查器只位于 `cui.testing`，不改变 Lens、Prism、State、selector 或渲染对象布局。`FeaturePath` 的积结构无需再造
第四套定律：分别检查 `path.state` 与 `path.action`，其逐分量组合律便继承两侧结果。

## Option 函子与带身份仿射遍历

弹窗、详情和导航目的地常由 `Option<ChildModel>` 表达，重复行则是按业务 ID 区分的同构 child。手写根 reducer 会反复
解包 Option、扫描数组、复制并回写，还容易让 parent 先关闭/删除状态后 child 才收到同一 Action。CUI 的
`ifPresent`/`forEach` 采用 [TCA 对可选与 IdentifiedArray reducer 的组合顺序](https://pointfreeco.github.io/swift-composable-architecture/0.44.0/documentation/composablearchitecture/reducerprotocol/foreach%28_%3Aaction%3A_%3Afile%3Afileid%3Aline%3A%29/)
作为行为参照：固定 child→parent，因此 child 的最终模型和效果先产生，parent 再决定移除。

对固定 Action 的端态变换 `r: M → M`，`MissingFeaturePolicy.Ignore` 对应 Option 函子的映射
`Option(r): Option<M> → Option<M>`：`Some` 应用 `r`，`None` 保持 `None`。默认 Reject 在该映射外加诊断守卫，
让“状态已消失但 Action 仍到达”成为显式失败；只有领域确认允许迟到结果时才选 Ignore。当前仓颉 1.0.5 把返回
`Reducer<?M,A>` 的泛型成员递归单态化为无限实例，因此改变容器类型的 lift 落为顶层 `optionalReducer`；返回父类型
不变的 `ifPresent` 仍保持流式成员 API，没有用运行时类型擦除绕开编译器。

集合侧的 `IdentifiedAction<ID,A>` 与唯一 ID 索引选择零或一个 child，是一个仿射遍历而非位置 Lens：目标至多一个，
重复 ID 会破坏唯一焦点律，child 更新 ID 会破坏 Put-Get，因此 `IdentifiedArray` 在构造和更新边界分别拒绝两者。
缺失 ID 使用同一 Reject/Ignore 代数。关系模型更复杂时仍应遵循
[Redux 的正规化 state shape](https://redux.js.org/usage/structuring-reducers/normalizing-state-shape)，按 ID 存独立实体表；
本容器专注于同时需要稳定身份与显示顺序的 UI 子特征。

首版 `IdentifiedArray` 使用完整 Array + HashMap，查找虽为期望 O(1)，更新仍复制 O(N) 数组；五进程中位相对手写
线性扫描在 16/1024/10000 项为 386/4930/59015 ns，对照 88/3511/38404 ns，全部更慢，故否决。最终顺序存储改为
32 元素分块持久向量：更新共享 ID 索引与未改变块，只复制外层块表和一个块，约 `O(N/32 + 32)`；≤32 项稳态不保留
HashMap。最终五进程中位，16 项为 1128 ns 对手写 100 ns，换取唯一身份不变量但有约 1.03 μs 小集合税；
1024/2048/4096/8192/10000 项为 935/1422/2701/3795/4080 ns，对照
1823/8119/15706/33074/37198 ns，分别改善约 48.7%/82.5%/82.8%/88.5%/89.0%。因此普通十几项且不需要
Action 路由时仍用 Array；重复特征或中大型有序模型使用 IdentifiedArray。

一次把小集合查找改写成嵌套 Iterable 循环的实验使 16 项中位进一步恶化到 4630 ns，说明当前工具链迭代器成本高于
直接索引中的除法；该版本已回退。Option lift 为 93 ns，对等手写 match 的 56 ns 增加 37 ns。重复 ID、身份改变、
缺失拒绝/忽略、分块边界、旧版本不变、child-first 删除/关闭以及 Effect child→parent 顺序均由确定性测试覆盖。

### 稳定积上的有序批遍历

单元素分块更新仍不等于批量高效。对 `k` 个 `IdentifiedAction` 逐次调用 `identifiedReducer`，每次都复制长度约
`N/32` 的外层 chunk 表和一个 chunk，总成本包含 `k × O(N/32 + 32)`。显式批 Action 不插入、删除或重排，并在每次
child 归约后检查 ID 不变，因此初始偏映射 `position: ID ⇀ Index` 对整个遍历稳定。最终
`identifiedBatchReducer`/`forEachBatch` 复用同一位置索引，只复制一次外层表，并让写集像
`ID → chunk(position(ID))` 的像那样，每个触及 chunk 最多复制一次；同一 ID 的后续 Action 读取会话内前一端态。
这是保持显示顺序的仿射遍历，不是把集合降格成无序实体表。

阈值没有照搬 EntityTable。首版让 ≤8 Action 逐次执行，在 10000 项/4 Action 上中位约 36–39 μs，而 chunk 会话
只需约 7–8 μs；外层表复制从第二次 Action 起已经超过会话固定成本，因此最终只为 singleton 保留与
`identifiedReducer` 等价的专门路径，两个及以上进入会话。最终 O2 五进程中位（逐次/批次）为：16 项/4 Action
3817/3261 ns，1024 项/4 Action 3700/3084 ns；10000 项/1 Action 2492/2384 ns、4 Action 25952/7240 ns、
8 Action 36434/10440 ns、16 Action 72519/15891 ns、32 Action 138565/24966 ns、128 Action
327175/86375 ns；100000 项/32 Action 1063767/67941 ns。对应 10000 项/32 Action 约改善 82.0%（5.55×），
100000 项/32 Action 约改善 93.6%（15.7×）。三 chunk 写集、非交换重复 ID、晚到缺失、身份改变、旧版本、批末
parent 可见性及 child effects→parent effect 顺序均有确定性测试。

## 正规化偏映射与持久实体目录

有序重复特征仍不能解决关系模型中的事实重复。若 Post 内嵌 User、Comment 又内嵌同一个 User，一次改名必须重建所有
路径，还可能留下不一致副本。[Redux 的正规化模型](https://redux.js.org/usage/structuring-reducers/normalizing-state-shape)
把实体集合视为有限偏映射 `T: ID ⇀ Entity`，关系和显示顺序只保存 ID。CUI 新增 `EntityTable<ID,Entity>` 与
`entityReducer`/`forEntity`，让该表示保持 reducer 的值语义、缺失策略和 child→parent 顺序。

直接把标准 HashMap 放进不可变模型并在每次 Action 上 clone 会把更新重新变成 O(N)。实现参考
[Bagwell 的 Ideal Hash Trees](https://lampwww.epfl.ch/papers/idealhashtrees.pdf) 逐段使用 hash 位选择高分支路径的思想，
但针对仓颉 1.0.5 的数组和泛型成本采用更小的三层 32 路目录，而没有照搬 bitmap/递归 HAMT：hash 低位选择
region/page/bucket，bucket 只处理完整碰撞；更新复制顶层 region 引用表、一个 region、一个 page 和一个小 bucket，
其余实体和旧版本结构共享。插入跨越负载 6 时重建到目标负载 4；删除不自动缩容，避免增删抖动。`diagnostics()` 暴露
占用 bucket、最大碰撞链和顶层 region 数，使坏 Hashable 不再只是隐藏退化。

性能试验也改变了内部布局。首版只存 Entity，在命中 bucket 时调用 ID 投影。为了减少读取闭包，先试验每元素
`(ID,Entity)` 泛型 entry；读取反而由约 276–320 ns 恶化到 347–455 ns。随后试验 ID/Entity 平行数组，更新改善约
10–13%，但读取恶化约 11–28% 且永久多保存一份 ID，因此两版都否决，保留 entity-only bucket。原生可变 HashMap
读取仍明显更便宜；持久表的收益目标是不可变更新、异常原子性和历史共享，而不是取代所有局部缓存。读密集 UI 应把
热实体投影为 `DerivedState`，让一次 table 查询服务多次 build 读取；十几项模型继续用 Array/HashMap。

重复 ID、更新改 ID、负 hash、完整 hash 碰撞、扩容前后旧版本、缺失/失败零修改、child-first 删除与 Effect 顺序均有
确定性测试。最终 O2 五进程中位更新结果如下（线性数组 / clone HashMap / EntityTable）：16 项为
55/190/935 ns，确认小集合不应使用持久表；1024 项为 1903/27242/1437 ns，持久表已分别改善约 24.5%/94.7%；
10000 项为 24035/204038/1589 ns，改善约 93.4%/99.2%；100000 项为
312991/2593418/2044 ns，改善约 99.3%/99.9%。

轮转步长 7919 的读取基准覆盖整个 ID 空间，避免只读前缀或固定键被优化：16/1024/10000/100000 项的线性数组读取为
20/858/8533/89865 ns，EntityTable 为 270/349/365/585 ns；从 1024 项开始已优于线性关系查找，100000 项改善约
99.3%。原生可变 HashMap 为 3/4/5/19 ns，说明不可变结构共享不是免费午餐，也支持“热实体 selector 缓存、局部
可变索引继续用 HashMap”的边界，而不是用一个容器统治所有状态。

### 有序实体补丁与不可逃逸批会话

一次领域动作经常同时更新多条正规化事实。令 `EntityUpdate<ID,E> = ID × (E → E)`；批次是它的有限有序列，解释为
`EntityTable` 上偏自同态的顺序折叠。同一 ID 上先出现 `f`、后出现 `g` 时严格得到 `g ∘ f`，而不是假设更新可交换；
空列是恒等，连接批次与函数复合都满足结合律。任一 ID 缺失进入 `Option` 的失败支，变换抛错或破坏 ID 不变量则拒绝
提交，因此源版本与可见结果之间不存在半提交状态。开发者只构造 `EntityUpdate` 并调用 `updatingAll`，不管理锁、事务
对象或可变 builder。

实现借鉴 [Clojure 官方 transient 设计](https://clojure.org/reference/transients) 的受控局部可变原则：先从持久值建立
高效编辑窗口，再返回持久值；但 CUI 把边界进一步收窄为未导出的 `EntityTableUpdateSession`，会话不能逃逸、不能被
保存或跨线程共享。它只克隆一次顶层目录，并以“区域布尔位 + 每 region 的 32 位 page mask + 每 page 的 32 位 bucket
mask”记录写集；追踪结构与目录拓扑同构，触及节点最多复制一次，旧表仍只读共享。最初使用三张 HashMap 记录写集，
小批固定成本过高，已由位图方案取代。

批策略由实测选择而非暴露给调用者：位图会话在 10000 项、8 更新时仍比逐次路径慢约 5%，16 更新开始快约 10%，
因此当前 ≤8 更新保持逐次路径复制，≥9 自动进入会话。最终 O2 五进程中位的配对结果（逐次 / `updatingAll`）为：
10000 项 1 更新 2358/2240 ns、4 更新 10039/9455 ns；这两组实际走等价单次/逐次算法，差值只作为测量噪声，不宣称
算法收益。10000 项 32 更新为 70421/66025 ns（约快 6.2%），128 更新为 376355/236584 ns（约快 37.1%）；
100000 项 32 更新为 94379/67647 ns（约快 28.3%）。顺序复合、重复 ID、缺失原子性、变换异常、ID 不变量、完整 hash
碰撞与旧版本不变均由确定性测试覆盖。

### 批量仿射遍历进入 reducer

仅有容器 API 仍会把优化责任泄漏给业务层：开发者若已持有 `IdentifiedAction<ID,A>`，还得手工把每个 Action 包成
`EntityUpdate` 才能获得批会话收益。CUI 因而增加 `entityBatchReducer` 与父级 `forEntities`：一个显式
`Array<IdentifiedAction<ID,A>>` 被解释为有序仿射遍历，child reducer 提供 `(E,A) → E`，同一 ID 的 Action 仍按序
作用；纯版本产生至多一个表版本，Writer 版本同时按原序连接 effects，完整 child 批次之后 parent 才运行一次。
Reject 在缺失、异常或改 ID 时没有模型/效果结果，Ignore 只跳过缺失项。

这里刻意没有把任意 `ModelStore.dispatchAll` 自动融合。按照
[Redux 官方 Style Guide](https://redux.js.org/style-guide/)，一个 Action 可以作为领域事件被多个 reducer 响应；对
`r.then(p)` 的动作列 `[a,b]`，原语义是 `r(a);p(a);r(b);p(b)`，重排为 `r(a);r(b);p(a);p(b)` 一般不等价。
显式批 Action 则把语义改为“整个 child traversal→一次 parent”，与
[Composable Architecture 的 identified forEach](https://pointfreeco.github.io/swift-composable-architecture/0.44.0/documentation/composablearchitecture/reducerprotocol/foreach%28_%3Aaction%3A_%3Afile%3Afileid%3Aline%3A%29/)
固定 child→parent 次序的理由一致，同时把批边界留在领域模型中而不是藏进 Store 调度器。

首版为每个 Action 分配捕获闭包并装进 `ArrayList<EntityUpdate>`；虽然定律测试通过，五进程中位却在 10000 项/
128 Action 上由逐次 340373 ns 退化到 385922 ns（约慢 13.4%），因此否决。最终让未导出的批会话直接接收 Action
与一个共享解释器，≤8 Action 另走无中间集合的逐次快路。最终 O2 五进程中位（逐次 `entityReducer` /
`entityBatchReducer`）为：10000 项 4 Action 10883/9137 ns，32 Action 61646/55623 ns（约快 9.8%），128 Action
298904/210681 ns（约快 29.5%）；100000 项 32 Action 72801/66030 ns（约快 9.3%）。非交换重复 ID、Reject/Ignore、
旧版本、child 批末 parent 可见性和全部 child effects→parent effect 顺序均由确定性测试覆盖。

## Writer 变换与显式效果解释

只有模型自同态仍不足以表达真实应用的文件、网络、时钟与随机数边界。最终接口采用
[Elm Commands](https://guide.elm-lang.org/effects/) 的“程序只产生命令值”、
[Composable Architecture Effect](https://pointfreeco.github.io/swift-composable-architecture/1.9.0/documentation/composablearchitecture/testing/)
的 reducer 可测试效果，以及 [Redux 官方副作用边界](https://redux.js.org/usage/side-effects-approaches) 的 reducer 禁止
外部可见副作用；但没有把任何特定异步运行时或中间件管线搬进 GUI 核心。

令应用效果描述集合为 `E`，其有序自由幺半群为 `E*`。`Transition<M,E> = M × E*`，EffectReducer 的固定 Action
归约是 Writer 形态 `M → M × E*`：`then` 把前一模型喂给后一 reducer，并用幺半群乘法连接效果；单位是空批次，
结合律来自状态线程化与 `E*` 连接的结合律。`pullback` 用 Lens 提升模型，用 Action 投影选择特征，再以
`Effect → RootEffect` 函子映射效果空间。

`EffectBatch` 最初尝试递归值枚举，4096 层测试持续占用 CPU，说明当前工具链会在构造/复制中放大递归值成本，
该版本被否决。最终内部使用不可变引用节点：非空 `then` 只分配一个左右引用节点，空批次直接返回另一侧；
`forEach` 用显式 ArrayList 工作栈按序展开，4096 层约 4.6 ms 且无调用栈递归。输入数组在批次构造时快照。

首版 EffectStore 还尝试把解释器和同步 `send(Action)` 放进内核，并分别试验游标 ArrayList、ArrayDeque 与直接活动
分支；确定性重入用例均无法收敛。与其隐藏线程、递归、取消和背压语义，最终删除自动反馈运行时：`dispatch` 返回
惰性批次，或由显式 `handleEffects` 在提交后接走；Binding 因返回 `Unit` 而强制要求 handler。Reducer/策略在提交前
失败时零效果；模型 revision 已提交而观察者失败时，handler 重载仍交付一次批次再报告首错；handler 自身失败不回滚
已提交模型。后台结果继续通过 `DesktopApp.post` 成为新 Action。

生产 UI 若在每个按钮和 Binding 重复 `handleEffects`，解释器能力会泄漏进所有特征签名。`EffectStore.connect(h)`
现在把 handler 在应用组合根部分应用一次，返回普通 `ScopedStore<Model, Action>`；其后状态/Action 可以继续 scope，
而 `Effect` 类型被边界消去。它满足可测试等式 `connect(h).dispatch(a) ≃ dispatch(a, handleEffects: h)`，批量版本
同样保持模型、效果顺序、提交 revision 和失败优先级；空序列两边都不调用 `h`。这与 Elm 把 Command 交给运行时、
TCA 由 Store 在 reducer 后执行 Effect 的目标相近，但 CUI 仍要求应用显式提供解释器，不内建任务系统。

首版 connect 直接套用通用 scope 投影和 producer：零效果单 Action 为 4.772 μs，32 Action 为 37.373 μs，分别
接近显式 handler 的两倍，实测否决。最终增加两个不改变语义的特化：identity 连接直接复用根 Observable，第一次
真实 state projection 才建立 Derived 节点；根门面的数组批次直接走 EffectStore 原生折叠，只有 Action 类型提升
时才进入 producer。最终五进程中位中，显式 handler/connect 单 Action 为 2.361/2.442 μs，门面只增加约 81 ns
（3.4%）；稳定门面读取 468 ns。直接/connect 的 32 Action 折叠为 18.279/17.626 μs，处于同档；两侧效果均为
640000、回调与 revision 均为 20000。普通未连接 EffectStore 不承担门面字段或分支成本。

最终五进程同机中位：25 万次零效果单动作的 EffectStore/ModelStore 为 1834/1729 ns，opt-in 成本约 105 ns
（6.1%），普通 ModelStore 完全不承担该成本。32 个各自产生一个效果的 Action 逐次 dispatch 为 37.110 μs，
单模型提交的 `dispatchAll` 为 18.198 μs，改善约 2.04×；两侧都交付 640000 个效果、通知 20000 次，revision
从 640000 降到 20000。幺半群单位/结合律、深链非递归展开、Reducer 组合/pullback、批量异常零提交、提交前后失败
边界、Binding 显式交付、connect 等价路径、局部 scope、空批零 handler 与批中失败零提交均有确定性测试。

后续把 Writer fold 的稀疏性单独纳入实验。把多个子批次提前遍历并压成一个数组叶，虽然减少了树节点，却把
32/128 effect 批次从 6155/19843 ns 反向推到 10158/34631 ns；只收集不可变根引用的序列节点仍为
7064/22035 ns。两版均因重复遍历、数组写入或间接访问成本而撤销。最终只应用自由幺半群的单位元消去：fold 在
看到空 `EffectBatch` 时不调用 `then`，非空批次仍使用原 O(1) 持久连接。五进程中位中，32 个无 effect Action
从 4889 降到 4405 ns，改善约 9.9%；32 effect 直接/connect 为 6189/5713 ns，128 effect 为 20276 ns，分别相对
6155/5907/19843 ns 约 +0.6%/-3.3%/+2.2%。该取舍改善常见的“多数 Action 只改模型”路径，不改变
非空 effect 的惰性、顺序或提交失败边界；32 个无 effect Action 仍提交一次并向显式 handler 交付一次空单位元。

effect API 因而也提供 keyless 重载。它不通过“生成一个看似唯一的字符串”绕过协议，而是直接使用上述不相交的
位置路径进入原有 prepare → ownership commit → cleanup 事务；显式键重载保持完全兼容。128 项五样本中，keyless
静态声明为 4.11 μs，对显式键 5.13 μs 约改善 20.0%；keyless 外部 revision 为 25.20 μs，对显式键
45.96 μs 约改善 45.2%。两种静态路径组合体执行均为 0 次/帧，两种外部版本均为 1 次/帧，收益来自持久路径向量
而不是错误冻结声明。

### 保守边界

- `mountEffect` 与只带 key 的 `RetainedSubtree` 是可持久采用的静态声明；其存在不再阻止干净自动父作用域命中。
  body 读取的 State 仍沿挂载树标脏，条件分支改变时会重新执行父作用域并完成 effect/retained 卸载。
- 带显式 revision 的 `lifecycleEffect` / `RetainedSubtree` 仍要求自动父作用域被访问，因为 revision 可能来自
  框架不可观察的普通字段、主题 epoch 或外部资源。这个兼容路径不会被静态声明优化冻结。
- 声明的重放要求映射到布尔半格 `{静态 ≤ 外部版本}`，一个作用域按 OR 结合；build-local 结果只随完整根构建
  原子提交。失败构建、分支从外部版本切回静态、卸载与重挂载都不会留下过期分类。
- `--cui-force-full-retained` 和 `RetainedTestMode.Full` 同时禁用手工与自动命中，用于差分验证，
  不面向生产业务代码。
- 直接使用底层 `StateStore/buildRoot` 的事务单测保持原始执行语义；`DesktopApp` 和
  `WidgetTestHost` 才启用自动图。

## 第二阶段：选择性持久渲染节点（已实现）

根输出始终进入一个持久 `AutomaticRenderNode`。非根作用域不会一律包装；框架只把“单根输出且
结构复杂”的作用域自动晋升为持久边界。结构分数同时看后代作用域总量和最大分支宽度，并沿组合
事务传播：宽而昂贵的 panel/card/页面区可以晋升，24 层但每层只有一个廉价子节点的链不会产生
24 层代理。这个选择来自实测约束——无差别给每个声明节点包装代理会使本项目压力场景的绝对
帧成本明显上升。

持久 proxy 只保存最近 child、分相 State 依赖和选择性 paint 预算；constraints、测量结果、布局几何、
overlay/semantics replay 与显示列表均由其代际 Element scene 持有，proxy 与 Element 不再各存一份真相：

- 清洁帧在约束、矩形、祖先可见域和 UI 环境不变时直接复用 measure/layout，layout 命中会重放 overlay 与
  semantics fragment；
- promoted 复杂兄弟在另一分支更新时保持原节点，父壳虽被重新创建，也不会穿透边界重复布局；
- Measure State 变化使 Measure→Layout→Paint 失效；Layout State 变化使 Layout→Paint 失效；
  为防短命容器内部缓存保留旧值，当前根节点会保守重建对应组合路径；
- 事件始终转发到最近一次成功提交的 child。新输出和节点更新在完整根构建成功后统一 commit，
  构建异常不会把事件或绘制切到半棵新树；
- 节点失效向持久父节点传播，所以嵌套 display list 不会在子节点变化后继续重放旧命令。
- 显式 `RetainedSubtree` 内部的 Measure/Layout/Paint State 失效也会桥接到最近的自动渲染边界；
  子树先清理自己的 Element scene slot，持有该稳定引用的自动祖先会在绘制前验证失败并重录，避免两套
  命令所有权或旧画面。

当前仍不把所有 Widget 都改造成永久对象。脏路径上的轻量容器壳可以重新实例化，持久节点只放在
能摊薄代理成本的位置；独立 Element 层先以兼容桥方式进入，而不是预先支付全树虚调用和内存成本。

### 统一 Element 身份兼容桥（已实现）

每个自动组合或显式 retained 挂载现在拥有应用级 `ElementId(slot, generation)`，由单一
`ElementArena` 管理父子拓扑。路径字符串只用于协调时查找；挂载后各子系统携带代数句柄，槽位复用会
推进 generation，旧引用不能误命中新节点。`AutomaticCompositionRecord`、`RetainedRecord` 和
`StateMountScope` 暂时作为同一 Element 的兼容 facet 引用，不复制 phase/lifecycle 状态；后续迁移可逐项
把字段搬入 facet，而不再创造第四套身份。

Arena 新增项进入根构建事务日志：完整提交后才成为稳定拓扑，失败构建按子到父顺序释放；正常卸载也
拒绝先释放仍有孩子的父节点。单测覆盖陈旧句柄、拓扑顺序、facet 一致性和失败回滚。稳定缓存命中不查询
Arena 的路径表，因此没有把局部帧热路径改成全树协调。

语义输出使用同样的增量思想：每个持久布局边界在 Element-owned `ElementLayoutCommit` 中保存
`None | SemanticFragment`。`None` 精确表示该边界没有语义输出；非空 fragment 的组合是保持
声明顺序的结合运算；稳定布局事务完成后才归一化并以稳定 id 合并覆盖，生成单调 revision 与
Added/Removed/Updated/Moved patch。`SemanticsSnapshot.node` 和动作目标均由 HashMap 索引；稳定 fragment 序列
只比较顶层引用身份，不重新扁平化。语义 provider 的 State 读取拥有独立 phase dependency：值变化会请求下一帧
并更新 patch，却不把动态 checked/value 错绑成 layout 依赖。layout key 含 `UiContext` generation，故 fragment
中的失效闭包不会跨上下文复用；旧上下文卸载也不能关闭新上下文仍在使用的 provider dependency。

早期表示即使没有任何 provider，也会构造 `SemanticFragment([])`，并在缓存重放时把空对象加入全局贡献序列。
后续稀疏化让 `semanticFragmentIfAnyFrom` 在空区间直接返回 `None`，布局提交只重放 `Some(fragment)`；普通视觉
Element 因此不分配 fragment、不增长贡献表，也无需在归一化时遍历空叶。这与
[WAI-ARIA Accessibility Tree](https://www.w3.org/TR/wai-aria-1.3/#accessibility_tree) 只为应暴露对象创建可访问对象的
边界一致，而不是用一个“空可访问对象”代表缺席。五进程冷空树中，1k/10k 首次 layout 中位由
236.4/3242.7 μs 降到 228.0/2702.4 μs，约改善 3.6%/16.7%；10k 样本受 Windows 调度与 GC 影响离散较大，
确定性门禁同时断言空提交贡献数保持 0、非空缓存 fragment 仍精确重放一个贡献。10k 非空首次提交和稳定语义帧
复验为 14.717 ms/68.785 μs，与紧邻改造前有效样本中位 14.807 ms/68.585 μs 同档。

`AccessibilityAdapter` 得到完整快照加最小 change-set；其 `AccessibilityUpdate.performAction` 总是查询最新提交
索引，旧 update 不会持有已卸载 Widget 回调。语义提交同时建立保持声明顺序的 AABB union 树，`nodeAt` 右子树
优先并使用与 ScrollView/LazyList/Reveal clip 相交后的 `visibleBounds`；完整 `bounds` 仍保留给平台属性。事件和
语义索引共享同一个有序空间聚合代数，但各自保留不同的叶语义与热遍历。

桌面 adapter fan-out 不采用异常单子式的“首错短路”。原生 provider、应用观察器和故障回调构成独立效果乘积：
一次 revision 会尝试全部存活分支，拒绝只熔断对应分量，并把 `(source, operation, revision, cause)` 写入可拉取
诊断；可选 UI 线程回调提供即时观察，回调失败也只移除回调。每个分量保存自己的 revision cursor，所以后来
安装的观察器得到当前 snapshot replay，而已同步原生桥不会收到重复 bootstrap。外部观察器初始 replay 的异常
仍同步抛回安装调用者，保持公开错误契约，同时原生桥继续存活。

每个已提交节点还记录其代际 Element owner，并挂入该 Element 的 `ElementSpaceFacet`；焦点表同步建立 key→target
和 key→index 映射，所以 Tab 移动、target 查询和 `focusedSemanticsNode` 不再扫描线性数组。同字符串 key 被新一代
Element 复用时，owner 校验阻止旧焦点解析到新节点。

10k 节点单机基线中，最早声明动作由 81.9 μs 降至三样本中位数 45 ns，重复快照由 2.10 ms 降至 5 ns；10k
稀疏点查询由线性 17.89 μs 降至 138 ns（约 130x），已聚焦语义查询为 40 ns。10k 稳定语义/同构空节点帧为
68.73/66.41 μs，说明查询收益没有转移为稳定帧 O(n) 成本。绝对门禁要求动作、快照、点查询和焦点查询低于
2 μs、稳定语义帧额外成本低于 10 μs。Element-owned 原子布局提交后的最终串行五样本复验为首次提交
20.94 ms、稳定语义帧 71.75 μs，对照空节点 71.56 μs，未把正确性收益转成稳定帧全树成本。

平台桥必须遵守各系统原生对象协议，而不是把语义数组伪装成“已支持无障碍”。Windows 桌面后端已通过
`WM_GETOBJECT` 暴露 `IRawElementProviderFragmentRoot`，实现 fragment/point/focus 导航、Invoke/Value/Toggle
pattern 和属性/结构事件。它从 SDL Window properties 解析 HWND，以 window subclass 接入消息；COM 线程只读
共享不可变快照，动作经有界队列与 SDL 用户事件回到 UI 事务，绝不把原生回调直接带入仓颉 GC。

provider 身份是单调 token，不复用已删除 id；关闭时恢复 subclass、断开 provider 并释放 COM。10k 树稳定帧
5 样本 P50 为 0.1 μs且不推进原生 revision，独立进程 UIAutomation 属性查询 P50 为 0.104 ms，Invoke 完整
往返为 22.783 ms。SDL 的 HWND property 与用户事件接口见
[`SDL_GetWindowProperties`](https://wiki.libsdl.org/SDL3/SDL_GetWindowProperties) 和
[`SDL_PushEvent`](https://wiki.libsdl.org/SDL3/SDL_PushEvent)。其它平台复用同一 semantics/adapter 内核，原生
provider 仍按各自对象协议逐平台实现。

DLL 运行时加载先验证 ABI version 以及 `CuiUiaNode`/`CuiUiaChange` 的 size/alignment 指纹；任一不匹配就卸载并
返回无原生 provider 的安全降级，旧二进制不会被同名符号误判为兼容。

语义 diff 不能只比较归一化数组位置。可访问树是 Element 树按“有语义输出”做的商：无标签中间对象被收缩，
节点即使保持相同扁平索引，也可能改变商树中的父态射。`ElementArena` 因此维护 O(1) 结构 revision；稳定语义
快路把它与 fragment 引用、provider dirty 和焦点共同作为提交键。结构变化时重新投影父索引，并按父语义 id
判断 `Moved`；仅重挂接时 `oldIndex == newIndex` 是合法结构 patch。该修复不创建第二棵可变语义树，10k 稳定帧
五个独立进程中位为 72.05 μs，同构空树为 77.92 μs，没有可辨认附加成本。

### 焦点身份与事件效果代数（已实现）

公开 control key 保留可读性，内核焦点环实际保存 `(ElementId generation, key)`。同一个 retained/automatic
挂载命中时 owner 不变；卸载和 slot 复用推进 generation，即使新控件恰好使用相同字符串也不能继承旧
焦点或 IME 所有权。缓存记录重放完整 owner，而不是在调用者作用域重新解释字符串；重复显式 key 仍按
首次声明形成一个 Tab stop，禁用其中一个声明不会误删另一个 owner 的焦点项。

焦点构建输出进一步收敛为不可变 `FocusSnapshot`。原始声明序列是按声明顺序连接的自由幺半群，snapshot 同时
缓存 first-key-wins 的 Tab 顺序；Automatic/retained 记录保存片段身份。空 build registry 可 O(1) 采用干净根片段，
`UiContext` 看到相同 snapshot 身份时保留已有顺序与两张 key 索引，只做常数时间焦点所有权同步。局部脏构建把
干净片段与新声明交错时才惰性物化；`.key` 重写、禁用移除和跨片段重复 key 仍执行原来的声明序语义。这样查询与
提交都不要求应用开发者维护焦点 revision 或手工注册缓存。

`AutomaticCompositionRecord` 只保存这一个规范焦点片段，不再额外递归调用每个 child 的 legacy
`focusableIds()` 并保存一个从未读取的字符串数组。后者仍保留在 Widget/RetainedSubtree/Reveal/Lazy 的局部裁剪与
旧式自定义组件兼容面；删除仅发生在 automatic record 的死投影上。因此 Tab 声明、disabled/hidden 注销和局部
键盘事件目标没有被合并成一种含混协议，同时 10k 脏 automatic 构建的 legacy 元数据查询由 10k 精确降为 0。

Frame 订阅使用同一持久片段原则，但不做焦点式去重：订阅声明按顺序构成自由幺半群，
`FrameSubscriptionSnapshot` 保存其不可变数组。空 registry 对干净 Automatic/retained 根片段直接 O(1) 采用，
只有局部脏片段与其它声明连接时才物化；派发直接遍历最终快照，不再先逐项重放到 `ArrayList`、再复制为第二个
数组。回调本身仍严格每帧、按声明顺序执行，因此优化只消除注册簿维护成本，不改变动画和调度语义。

新 `EventListener` 把路由分成 Capture/Target/Bubble，传播结果是二位效果 `(handled, stopped)` 的四元素
join-semilattice。合并就是逐位 OR，因此 `Continue` 为恒等元，且满足结合、交换、幂等；容器、手势和业务
监听器无需依赖脆弱的 Bool 优先级。每个原生离散事件开始时清空一次传播效果，事务提交后再协调下一事件，
不会把停止标记泄漏到后续输入。现有 `Widget.handle -> Bool` 被保留为兼容默认动作桥。

局部 `EventListener` 的键盘/Text/IME 目标仍由其透明转发的 `focusableIds` 定义，但成员表示自适应：不超过 8 项
直接线性比较，避免常见单控件监听器分配集合；更大子树在构造时建立 `HashSet`，事件目标查询均摊 O(1)。该索引
只改变同一字符串集合的表示，不改变重复 key、公开 focusId 或 retained owner 兼容语义。10k 最后命中/未命中由
345/204 μs 降至 48/20 ns，并以 2 μs 作为跨机器门禁。

body 型 `EventListener` 在构建子树前后截取 `FocusSnapshot`；每个 open build block 只保存最后 emission 的声明日志
区间，使紧随声明的 fluent `.onEvent` 获得同一 owner-preserving fragment，而不是给所有 Widget 附加元数据数组。焦点目标比较
`FocusTarget(ElementId generation, declarationId, public key)`：`.key()` 只改 public key，保留注册时自动身份，
所以同一 automatic scope 内的同名兄弟也不别名。FocusRegistry 的 build-local 声明日志以 tombstone 表示
disabled/hidden 删除，稀疏 tombstone 只在首次删除时分配，位置不因修饰器变化而漂移；非最后 emission 或 stored
Widget 没有可证明的本次声明区间时才回退字符串兼容语义。

## 第三阶段：自适应显示列表（已实现）

普通 UI 无需声明 `cachePaint`。持久节点先直接绘制两个观察帧；稳定候选随后录制 Renderer 的
透明值命令。当前策略接纳不少于 24 条直接命令，或包含稳定子 scene 引用，且本层不超过 8 MiB 的候选；
后者避免把“1 条引用代表大型子树”误判成廉价叶子。普通小树拒绝后等待 64 帧再
探测，避免“为了省几次函数调用先录一遍”的负收益。命中时不再进入 widget draw，只按原 z 序
重放命令。

每个 `State` 绘制读取都保留订阅，变化时命令立即失效。hover、focus、press、drag、tooltip、
IME、overlay、续帧或定时帧等会改变副作用/交互结果的协议由 `UiContext` 自动标记为 dynamic：
本次录制不缓存，并按 32→64→128→256 帧指数退避；几何或 State 变化会允许重新评估。

自动命令缓存同时受每个应用 32 MiB 的全局预算约束。新候选超过预算时淘汰最近最少使用的旧
缓存；节点卸载、输出/几何/设备 epoch 变化都会释放预算。缓存保存值和显式资源句柄，不保存
任意业务闭包，也不创建离屏 GPU layer，因此不会冻结捕获环境或引入透明度合成语义。

## 第四阶段：自动 damage（已实现）

Build/Measure/Layout/Paint 失效从源作用域向上寻找最近的自动晋升边界，并用旧 paint/layout
bounds（含阴影安全余量）登记 damage；布局后再登记新边界，两者取并集。多个变化继续合并，
覆盖视口 70% 以上、区域为空、后端不支持保留像素、根依赖或没有可信边界时回退全帧。
若路径先遇到显式 `RetainedSubtree`，由它的精确边界负责，自动根不会再次登记整窗；输出壳替换
只失效阶段/命令缓存，不重复扩大已经由状态源登记的区域。

局部帧不会被误收成“完整根 display list”；相交的命令缓冲才重放，未知绘制仍由后端 clip 保证
像素正确。damage 只裁剪提交和可证明安全的缓存重放，不改变构建、事件或布局语义。

这里必须区分“渐进基础设施已具备”和“收益门禁已完成”。实验曾在每个线性 Stack 的 layout 结果上
建立单调 `SceneSpanIndex`，把候选查询从 `O(n)` 降为 `O(log n + k)`；但短命 Stack 的 frame 数组增加
分配/GC 抖动，而 dirty command buffer 的录制与 replay 仍是主成本，七样本没有稳定达到 1.50x 门槛。
同步 record-and-draw tee 与延迟 batch 编译同样未过门槛。两项实验均已完整撤销，不让理论复杂度改善
掩盖绝对成本退化。后续层次化 ScenePatch 因而从持久 Element 和命令所有权入手，而不是继续给短命 Widget
或现有单矩形 clip 堆启发式分支。

## 第五阶段：Element-owned 层次化 ScenePatch（持续纵向迁移）

自动渲染节点现在是其组合 Element 的代际场景槽：`SceneNodeId(ElementId, slot, generation)`。Element 释放前
必须先释放场景节点；槽位复用推进 generation，失败构建只回收本次 staged 节点，不能破坏已提交场景。
几何和内容各自推进 revision，`AutomaticScopeDiagnostics.sceneRevision` 提供只读证据。

显式 `RetainedSubtree` 也已迁入同一 scene/space 所有权：`RetainedRecord` 不再另存 layout rect、paint bounds、
overlay/semantics fragment 或第二份 `RenderCommandBuffer` 引用，Automatic 侧也只从 scene slot 查询提交事实。
布局缓存键统一为 `(layout bounds, visible bounds, declared paint bounds, UiEnvironment generation)`；祖先 clip 或
上下文改变会重算语义，纯稳定命中仍为 O(1)。
显式 retained 首次在父录制中发布的是一个 `ReplaySlot`，关闭后旧父缓冲确定性不可重放。

测量 memo 随后也进入同一个 Element scene。Automatic proxy 与显式 `RetainedRecord` 不再各自保存
`available/result/valid` 三元组；命中键是 offered `Size` 与一个 frame-stable UI 环境 generation 的乘积。
该 generation 是 `UiContext` 身份（固定 renderer/theme）、display/font scale 以及每帧字体注册表快照的
interned 代表：任一坐标变化都得到新代数值，而热命中只比较一个 `UInt64`。字体注册只在帧边界采样，使同一
measure→layout 事务不会观察混合环境；scale setter 则立即推进 generation。环境 miss 遵守
Measure→Layout→Paint 单向失效，旧/新 damage 都会登记；失败测量保留旧提交，测量期间写 State 的结果不会
发布。Stack、Label 与 RichText 的实例内 memo 使用同一环境键，因此外层 Element miss 不会被内层旧缓存抵消。
`ElementSceneSpaceSnapshot` 同时暴露不可变的 `ElementMeasureSnapshot`；成功替换只推进一次 space revision，
显式失效发布空 measurement，失败计算则完全不改变旧快照。

内部状态不再用彼此独立的 nullable 字段和有效位重复表达同一事实。测量 memo 直接是
`None + ElementMeasureSnapshot`；布局 memo 是和类型
`Absent + Stale(ElementLayoutCommit) + Current(ElementLayoutCommit)`。`Stale` 保留旧几何供 damage、环境差分和诊断使用，
但类型分支禁止 replay；只有 `Current` 能命中。测量发布/失效把 `Current(c)` 原子变成 `Stale(c)`，成功布局再提升为
`Current(c')`，释放则回到 `Absent`。旧表示 `Option<Commit> × Bool` 有四个组合却只有三个合法状态，测量侧还同时保存
零值 Size、可选环境和有效位；和类型把非法组合从内存与代码审查空间中删除，所有读取都必须穷尽合法状态。

布局提交随后采用同一所有权协议。一个不可变 `ElementLayoutCommit` 是
`Geometry × UiEnvironment × OverlaySnapshot? × SemanticFragment? × EventTopologyΔ` 的积，其中 overlay 序列与 fragment
按声明序结合，`EventTopologyΔ = Preserve + Replace(Topology) + Clear` 显式表达路由索引的三种提交动作。只有布局
State 依赖收集稳定后，整个积才一次替换旧值。测量发布/失效会在同一 Element revision 内把当前布局降为 stale；
自写 State 或异常尝试不会发布临时几何、语义或事件路由。UI 环境 miss 即使几何相同也清除 paint commands，
因为 DPI、字体、Theme/Renderer 或上下文身份可能改变绘制与 provider 生命周期。

其中 `OverlaySnapshot?` 不再在稳定 replay 时逐项调用 `setOverlay`。提交先把非空声明后缀归一化为不可变
`OverlaySnapshot`：顺序保持不变，同 owner 使用 last-write-wins 原位替换；owner→index 是该商映射的缓存。
空 active registry 对一个干净片段 O(1) adopt；随后捕获整个 adopted 区间会直接返回同一快照，只有捕获真后缀、
多个片段连接、动态绘制追加或派发中删除时才复制/写时物化。捕获先判空，普通 Element 直接得到 `None`，不先构造
临时空数组再做第二次归一化。事件仍遍历快照，并用 owner 索引验证处理器
执行期间未被上层移除；空 owner 的兼容声明保留按对象身份线性校验。

旧实现上五条针对性断言分别复现 Automatic/retained 的未提交几何污染、两条跨 Context provider 失效丢失及
环境变化后旧 paint command 重放；最终 5 个新增用例和 Element snapshot 扩展均通过。最终串行五样本 retained
hit 中位 63.92 μs（此前 64.51 μs），miss 3.264 ms（此前 3.264 ms）；自动增量仍保持局部分支 1/240、稳定兄弟
layout 访问 0/24 和缓存绘制访问 0/96。

后端新增稳定 `RenderCommandSlot`。父显示列表录制子缓存时只保存一个槽引用，而不是把子命令、纹理和批次重新
复制进父列表；子缓冲保持不可变，通过 slot 原子替换。完整重放先递归验证 Renderer/epoch/resource/子槽，任一
失效都在绘制前整体返回 false；damage 重放则先完整验证相交前沿，区外失效子树不会阻塞本次局部提交。验证通过
后所有子列表共享根的一次 clip 保存，仍保持原 z 序。slot 永久绑定 Renderer 和所属线程，直接/传递引用环、
跨 Renderer 替换和错误线程访问均被拒绝。线程封闭在每个公开根入口检查一次；递归验证调用 internal validated
路径，避免安全检查随 slot 数量线性复制。命令内核本身也按冻结边界拆成录制/编译写面与不可变缓冲/重放读面，
前者在 `finish` 后不逃逸，后者不再混入批次构造状态。

后续审计把同一所有权契约提升到 `Renderer` 的完整 public 状态面：场景事务、viewport/clip、颜色与缩放、
无头查询、文本诊断以及 `RenderPass.close/isClosed` 都在读写前验证 owner。几何叶继续经统一录制入口验证；
`fillConvexPolygon`/`texturedStrip` 的可变列表专用分支也显式补齐边界。内部清屏、颜色应用和 clip 查询使用
不逃逸的私有 helper，避免一个已验证 public 操作在组合实现里重复检查。`circle` 改为委托 `strokeCircle`，因此
不仅继承所有权，也真正参与命令录制；此前它在 recorder 内会直接走 headless geometry 而丢失命令。

当一个已稳定子树再次失效时，它保留“曾通过缓存门禁”的证据并立即重录，不再重新等待两帧 warmup；新节点、
动态协议或过小/过大候选仍按原策略预热/退避。这样稀疏更新节点能重新发布 patch，干净兄弟只登记槽引用，
不会进入 widget draw。

第二个纵切面把每个 Element 布局边界（含框架 16 px 阴影余量）配置为 slot 身份上不可变的保守 replay bound；
几何变化会换新 slot，使旧祖先永久失效而不可能复活为过期索引。录制完成时，连续 slot run 按声明/z 序构建持久
BVH；缺少稳定边界时安全回退线性查询。查询与相交前沿验证共享这棵树，复杂度由全 slot 扫描降为典型的
`O(log n + k)`，左右递归仍保持绘制顺序。

最新同进程三样本中，96 个子树、每树 24 条命令的父列表重建中位数从 113.80 μs 降为 14.65 μs（约 7.77x），
父命令从 2304 条变为 96 个引用。稳定重放从 0.533 μs 增为 1.481 μs，即约 0.95 μs 的绝对间接成本；96/256/1024
子树的单区域 damage 分别为 0.105/0.136/0.122 μs，而 1024 子树的全重放为 17.65 μs。加入索引前的同机
1024 线性查询为 19.65 μs，索引后约快 161x。48 区普通 Widget 的单区域更新为 382.39 μs，强制全树为
2.502 ms（约 6.54x），绘制叶访问从 384 精确降到该区域的 8。

这仍是纵切面而非终点：dirty patch 已能在命令拓扑内直接定位相交前沿；事件侧新增了布局所有的有序 AABB
子树索引，但只剪枝显式证明为 `PointerEventScope.LayoutBounds` 的叶，`Unbounded` 兼容叶和活动捕获保持原路由。
10k 稀疏最深命中由 71.08 μs、10000 次访问降到最终三样本中位 0.560 μs、1 次访问；10k 完全重叠最深命中仍访问 10000 次，
因为任意 handler 都可能消费，Ω(n) 是语义下界。索引是 contiguous z-run 上 AABB union 的结合聚合，右子树先行
保持逆 z 序；全兼容容器不构建索引，直接走旧线性循环。子矩形和边界契约未变时，后续 layout 事务复用已提交
节点；10k 稳定布局的无界/有界中位为 638.23/652.03 μs，索引校验增加 13.8 μs（约 2.2%）。语义提交已经按
代际 owner 进入 Element 空间 facet，且事件/语义共享有序 AABB 聚合。

后续空间所有权纵切面把 Scene 节点的 layout/visible/paint bounds 从命令对象迁到同一 `ElementSpaceFacet`；Scene
只保留命令槽与内容 revision。每次成功几何更新产生新的不可变 `ElementSceneSpaceSnapshot`，slot release 与
Element generation 共同拒绝陈旧快照反向写入。`SpatialClip` 把语义/输入的精确可见域与允许跨滚动轴阴影余量的
paint 域组成二元值，嵌套组合是逐分量矩形交的 meet-semilattice。ScrollView、LazyColumn/Row/List 和 Reveal
在布局、事件与绘制阶段重用同一值；绘制栈用 `try/finally` 保证异常也恢复父 clip。

固定 cross-axis 余量随后被 `PaintOutset(left, top, right, bottom)` 取代。四分量 join 是结合、交换、幂等的
上半格，矩形扩张是非对称 Minkowski dilation；shadow 自动推导，Canvas 可显式声明。容器只在构建时聚合一次，
Scroll/Lazy/Reveal 保持滚动轴精确，Scene replay、Element paint bounds 与 retained damage 消费同一个域。
10k 强制全量同构树的大非对称值相对零值 P50 增加约 4–8%（50–100 μs），稳定 retained 命中不遍历子树；
48 区 ScenePatch 单区域/全树复验为 0.291/2.931 ms，仍保持约 10.1x 收益。

自动布局缓存键同时包含祖先可见 clip 与 UI 环境；因此 child rect 不变但 viewport 或 Context 改变时会重算
semantic fragment，而不会错误重放旧 `visibleBounds` 或跨 Context 失效闭包；纯 paint clearance 变化又不会
无谓失效 layout/commands。同进程迁移前后三样本中，
96 子树层次父列表重建为 14.86/14.84 μs，1024 子树单区域 damage 为 121/122 ns，48 区单区域 Widget patch 为
402.74/385.00 μs；稳定层次重放为 1.479/1.469 μs。10k 语义复验中稳定语义/空节点帧为 68.08/70.30 μs，
索引点查询与焦点查询为 150/46 ns，仍明显低于门禁。

通用多子事件拓扑随后也进入同一个 Scene space slot。只有当前 AutomaticRenderNode 直接包装的 Widget 才能绑定，
未晋升嵌套容器继续使用 detached topology，避免共享最近祖先身份。`ChildEventTopology` 用 committed/pending 双缓冲
把 dispatch 读面与 layout 写面隔开：detached 容器在 `commitLayout` 后立即交换；Element-owned 容器只产生 ready
buffer，再随 `ElementLayoutCommit.Replace` 原子提升。相同 child count 的失败布局、状态自写和异常因此也继续路由旧
AABB 树；稳定更新为普通叶子则通过 `Clear` 与新几何一起生效。Scene release 或 generation 复用会关闭 topology，
陈旧引用在事务入口、查询和 dispatch 处被拒绝。`ElementSceneSpaceSnapshot` 因此同时携带 layout/visible/paint 与
event topology revision，形成单一代际空间提交视图。

owner 侧随后也从三张可选引用收敛为封闭事务状态机：
`Empty + Cached(p) + Current(c) + CurrentWithCached(c,p) + StagingInitial(p) + StagingCurrent(c) +
StagingReplacement(c,p)`。构造器区分读面、可复用失败写面和本次 staging，撤销只沿对应边回到稳定态；不再由
`committed?/pending?/staged?` 的组合与隐含对象别名共同表达阶段。`Replace(t)` 现在必须满足 `refEq(t, staged)`，child count
相同不再被当作所有权证明：来自另一个 Element 的 ready topology 会在交换缓冲前被拒绝，旧提交和外部对象均不被修改。
状态机按职责独立于空间 facet，热入口只做“命中已 staging”或“撤销后从稳定态选择”两步。

`ChildEventTopology` 内部的布局事务也不再由 `layoutInProgress/stagedLayoutReady/layoutChanged` 三个布尔值协同。
阶段是 `Idle + RecordingClean + RecordingDirty + ReadyClean + ReadyDirty`：note/commit 只能消费 Recording，publish
只能消费 Ready，discard/close 统一回到 Idle；在 Ready 上重新 begin 会显式开始一份替换写面。首次布局和任何已发现
差异的布局进入 RecordingDirty，后续不再扫描 committed/pending 数组来重复证明“确实变化”，但仍完整写 pending 数据并
重建需要的 AABB。稳定 clean 路径继续逐项证明无变化，才能安全复用已提交索引。

初次所有权迁移前后七/三样本对照中，10k 稀疏命中为 614/594 ns，完全重叠最深命中为 68.03/68.21 μs，最上层
命中为 358/340 ns。进一步把拓扑纳入原子布局提交后的最终五个完整样本中位为 650 ns、67.08 μs、292 ns；10k
Element-owned 稳定布局为 858 ns，detached 逐帧 P50 的无界/有界提交为 632.4/639.6 μs。双缓冲首版曾在稳定帧
无条件重建索引并触发门禁，恢复“无变化短路”后附加 P50 约 7.2 μs。门禁仍使用逐帧最近秩 P50；在真实 GPU 与
大重叠场景证明收益前仍不增加 raster layer。owner 状态机改造前/后的同轮五进程中位为：10k Element-owned 稳定
布局 788/772 ns，detached 无界提交 736.8/736.3 μs，有界提交 703.2/687.8 μs，未观察到安全性收益导致的退化。
内部 phase 和类型落地后的同轮复验为 778 ns、703.7 μs、691.4 μs，仍处于原量级。

本次显式 retained 迁移前三样本中位为：稳定 revision 命中 70.67→69.39 μs（约改善 1.8%），每帧 revision
变化 3.137→3.152 ms（约 +0.5%，噪声量级）。自动 display list 仍为 3.30 μs 对直绘 56.90 μs；最新 48 区
ScenePatch 单区域/强制全树为 0.309/2.570 ms，访问数保持 8/384。

测量所有权迁移的最终隔离五样本中位为：retained revision 命中 64.51 μs（迁移前最近 69.45 μs，约改善 7.1%），
revision 每帧变化 3.264 ms（迁移前最近 3.190 ms，约 +2.3%）。自动复杂兄弟的稳定 layout 访问仍为 0/24，
自动显示列表仍为 0/96 次 widget draw。深层布局基准同时修正为先执行根 measure，并把每个独立计时窗口延长到
约 100 ms 以上，避免原先 5–20 ms 短样本把 Windows 调度/GC 抖动误判为单数字百分比回归。

## State 读取效应的封闭和与有序证书

State 读取收集不再由 scheduler 深度、phase ThreadLocal、active store 与 mount 栈这组可空状态的笛卡尔积共同表达。
合法接收者本来就只有两类，内核因此改为封闭和 `StateReadCollector = Mount(StateMountBuild) +
Phase(PhaseStateDependencies)`：一个读取恰好路由到一个构建作用域或一个执行阶段，不可表示“同时属于两者”或
“深度有效但接收者缺失”。这相当于把动态 State 读取解释成一个只有两个 handler 的局部效应，而不是让 State
逐次探测多套环境。

有 FrameScheduler 时，scheduler 直接持有当前 collector 与显式父栈；无 scheduler 的直接/headless 构建使用
ThreadLocal 链式帧。嵌套 phase 可以暂时覆盖 mount，`finally` 无论正常或异常都恢复父 collector；DerivedState
的聚合读也沿同一 handler 路由。已绑定 State 在一次 owner-thread 检查后直接询问所属 scheduler，不再依次读取
全局函数、phase ThreadLocal、active store 和 mount 栈。跨线程写入、scheduler 转移和事务边界没有放宽。

Phase collector 进一步复用 build collector 的有限半格证明：公开依赖仍是 identity 的有限集合，但稳定执行免费
给出有序 trace。当前 trace 与 committed canonical frontier 逐项相等时直接复用 observation；首个差异单调切换
到自适应集合正规化。完整等序且等长时提交不扫描、复制或重建索引；截短前缀直接关闭 committed 后缀；重排、
重复、插入和替换进入通用回退。顺序只是优化证书，不改变应用可观察语义。

效果边界也不再藏在布尔短路右侧。`reuseCommittedPrefix` 会推进 pending frontier，`AutomaticPaintBudget.admit`
会更新 LRU、字节账本并可能淘汰其它节点；两者现在先完成纯前置判定，再进入显式 `if` 效果分支。动态 State
读取仍只在语义相关路径发生，不能为消除告警而无条件求值；反过来，同一绘制内必然共享的值先取一致快照：
DatePicker 的月份、焦点由每个有效日单元反复读取收敛为每个网格恰好三次 State 读取，TimePicker 的编辑状态/
缓冲与 Tooltip 的悬停起点也各只读取一次，菜单 hover 不再重复解析当前 items。`G.EXP.03` 从 54 降到 39；剩余
项均经逐处复核为纯谓词或刻意的动态依赖/快速失败。五样本 AC 复验中 headless/frame 的 18 个稳定材料项域因子
为 1.008、0 回归，三组配对因子为 1.01/1.05/1.04，说明可审计性改进没有转化为可辨认性能损失。

同进程禁用/启用 phase 前缀的五个独立进程中位为：稳定节点每帧重收集 1k State 时 139.091→92.275 μs
（约 -33.7%），10k 时 1.238→0.935 ms（约 -24.5%）。统一动态路由前后、使用每帧替换节点以刻意排除前缀
复用的五进程中位为 748.633→653.941 μs 与 5.960→4.921 ms（约 -12.6%/-17.4%）；build scope 同口径为
187.691→119.875 μs 与 2.072→1.105 ms（约 -36.1%/-46.7%）。精确读取计数始终为 1k/10k；异常嵌套、
稳定 trace、重排和替换由独立测试看护。

AutomaticRenderNode 的 child 替换随后也遵守同一个提交边界。phase dependency frontier 描述的是上一次成功
measure/layout/paint 的输入边，而不是构建期间产生的临时 Widget 对象；因此 composition commit 只把对应 Scene
结果标为 stale，不再提前关闭三组 observation。新 phase 成功时，`PhaseStateDependencies` 以 trace 证书复用或
原子换成新前沿；新 phase 抛错时只关闭本次新增边，上一提交的前沿与 Scene commit 一同保留；节点真正 close 时
无论是否发生过重收集都释放全部 observation。这是多版本提交纪律：读面始终指向最后一个完整版本，替换尝试只在
成功后发布，而不是把“Widget 对象已换”误当成“旧提交已不存在”。

该所有权修正使逐帧替换节点也能消费稳定 trace。五个独立进程中位中，1k/10k 完整替换帧从
661.558 μs/5.015 ms 降至 101.016 μs/0.866 ms，约改善 84.7%/82.7%（6.55×/5.79×）；其中
measure/layout 子阶段从 506.150 μs/3.879 ms 降至 97.166 μs/0.859 ms。稳定节点同期为
104.291 μs/0.989 ms，build scope 为 117.408 μs/1.013 ms，均未观察到可辨认退化。测试分别覆盖三 phase
同源订阅不抖动、失败换源回滚、成功换源以及替换后尚未执行 phase 就卸载仍释放旧前沿。

## 局部状态的商映射式变更语义

状态策略可视为在值域 `T` 上选择观察等价关系 `~`，界面实际响应的是商集 `T/~` 中的类别变化，而不是每一次
对象赋值。`structuralEqualityPolicy` 给出通常的结构等价；`stateMutationPolicy` 允许用稳定标识或领域投影定义
等价类。setter 在替换存储、推进 revision、通知观察者和标脏之前完成比较，因此被判等的写入不会进入后续增量图。
这不是把业务校验藏进框架：比较必须是快速、确定、无副作用的等价关系；若被忽略字段仍需要独立显示，应拆分
State，使信息边界与观察边界一致。

策略现在还支持沿纯投影 pullback。若 `~` 是 `T` 上的等价关系、`f: S → T`，则 `s₁ ~f s₂` 当且仅当
`f(s₁) ~ f(s₂)`；连续 pullback 由函数结合律正规化为同一逆像关系。它减少手写双参数比较，但不缓存投影，也不
改变异常：每次比较各求值前后投影一次，任一失败仍由既有 State/事务错误边界处理。

“存在商映射”不等于“商映射值得”：昂贵比较若只偶尔命中，可能比它截断的增量工作更贵。为此内核提供完全显式的
`DiagnosedStateMutationPolicy`，在目标策略外记录比较总数、等价/不同结果、失败、累计与最大耗时，并以不可变快照
读取或独立重置。异常路径在 `finally` 中完成计时后原样重抛，因此诊断不改变策略代数或事务错误边界。普通 State、
selector、Binding 和派生节点不含诊断字段、分支或时钟读取；只有被显式包装的策略支付观测成本。

策略现在可直接用于 keyless 或 keyed `rememberState`，无需先手工创建 State 再用 `remember` 包装。策略和初值都
是挂载时配置：后续声明式重建沿身份取回原 State，不动态替换策略，因而不会让同一状态的等价关系随帧漂移。
默认重载仍接受每次赋值，保持既有事件式语义与源码兼容。

同机五次独立运行、每次 50 万次等值写入的中位数为：默认 306 ns/次，结构策略 247 ns/次，闭包策略
226 ns/次，分别降低约 19% 和 26%。确定性计数比纳秒值更关键：默认路径 revision 增加 500000，两个判等路径
均为 0，因此其后的观察通知、派生失效与帧调度也全部被截断。

事务语义随后也提升到同一个商空间。把一次 batch 对某个 State 的写入看成路径
`x₀ → x₁ → … → xₙ`，提交只观察商映射 `q: T → T/~` 下的端点差分；若 `q(x₀) = q(xₙ)`，中间游程仍真实
执行并推进各次 revision，但不向观察者、派生图或帧调度泄漏。默认 State 没有额外商关系，继续保留“赋值即事件”
的兼容语义。这样事务合并不再只是少通知几次，而是把一条命令的可观察效果正规化为净变化，开发者无需手工在
每个 action 末尾判断“是否又恢复原值”。

实现把首次旧值和“是否需要端点复查”的证明保存在各 FrameScheduler 自己的类型擦除 pending frontier 中，不写回
共享 State；稀疏事务沿用 HashSet 去重，连续重复写命中最后通知，只有多 State 交错重复才惰性建立 HashMap。
单次有效写入已经由 setter 证明两端不等价，提交复用该证明，不重复调用用户策略。只有同一 State 在一批中被接受
两次以上时，才比较最初与最终等价类。其他观察者异常不会提前清空 frontier，而是记录首错并继续稳定；
端点比较本身失败同样因写入已经提交而保守推进 generation，再在不动点后把异常交还调用方，避免错误策略造成陈旧界面。
同线程应用仍可在旧调度器空闲后顺序接管 State，但旧事务活动时拒绝嵌套转交，防止两个商映射提交边界交叉。

最终把每个独立窗口延长到 100 ms 以上后的同机五次中位数：25 万个带观察者的净零事务为默认/结构策略
797/808 ns，约 +1.4%，通知数由 250000 降为 0；单写净变化为 641/637 ns，约 -0.6%，说明证明复用把常见路径
保持在噪声量级。两写且净变化的事务为 847/928 ns，约 +9.6%，这是额外端点比较的显式成本。用最小自动组合
body 连同随后完整 headless 帧测量，30000 个净零事务的中位数由 6456 降为 4166 ns/帧，约改善 35.5%，body
访问由 30000 降为 0。该取舍只由显式策略启用，并用必要的多写比较换取通知、派生失效和真实构建前沿的整体消除。

## Modifier 自由幺半群的自适应重括号

`Modifier` 的元素是 `Widget → Widget` 自同态，`then` 是有序复合，恒等 Modifier 是单位元。结合律允许改变括号而
不改变源码顺序、包装层或事件嵌套，因此运行时数组无需被固定成左深调用树。新增 `Modifier.concat(Array<Modifier>)`
在调用时消费既有顺序：空/单元素遵守单位元，≤8 项保持线性最小路径，更宽集合递归二分成平衡积，把最大调用深度
从 O(n) 降为 O(log n)。普通链式 `then` 的表示和热路径完全不变。

这里先反测了两个更激进的内部方案。全量持久连接树虽使 8192 步稳定应用改善约 33%，却让 8/128 步退化约
2.4×/2.2×；“1024 步内联 + 长链分块”仍使常见稳定路径约退化 1.9–2.1×，两者均完整撤销。最终显式 concat
五样本中，预建数组的左结合/平衡稳定应用中位为：8 步 29/29 ns、128 步 503/419 ns、1024 步 4911/4127 ns、
8192 步 117942/41381 ns；后三者约改善 16.7%、16.0%、64.9%。同一预建数组的“组合并应用”中位为
105/115 ns、2363/2217 ns、19230/45419 ns、214352/165016 ns。1024 项一次构造较慢，但复用约 33 次即可由
每次约 0.78 μs 的稳定收益摊平；8192 项构造和复用均改善。该 API 面向主题 token、插件和描述表生成的可复用宽
集合，不鼓励把普通静态三五步链数组化。

同一实验不能直接复制阈值到业务 reducer。`Reducer.then` 与 `EffectReducer.then` 也形成保持声明顺序的幺半群：单位元
分别是模型恒等、以及“模型恒等 + 空效果”，首错吸收后续工作。新增两类 `concat`，但 128 项五样本平衡 reduce
比左结合 3794→4824 ns、退化约 27%；1024 项则由 33289→26206 ns，改善约 21.3%。因此 reducer 的自适应阈值不是
Modifier 的 8。边界补测中，513/768 项平衡执行仍分别退化约 38%/41%，因此阈值设为 1023，从 1024 项才切换；常见模块数量继续走原线性结构。1024 项平衡组合一次多约 67 μs，约 10 次归约
由每次约 7.1 μs 收益摊平。效果版本的确定性测试同时证明 1024 个效果仍严格按序，异常分支后的 reducer 不运行。

## 物理采样预算的密度正规化

增量 CPU 工作已经缩到局部以后，真实窗口的主成本可能转移到 GPU present；此时继续优化 Widget 遍历并不能
减少整张离屏纹理的像素数。渲染内核因此把 `WindowSpec.supersample = 0` 定义为 Auto 请求：以“每逻辑单位的
物理后备像素数”为统一尺度，低于 2 时用 2x 补足，高于或等于 2 时用 1x，显式正数仍是精确覆盖。窗口跨显示器
或 DPI 改变而越过阈值时，旧目标被释放、命令 epoch 递增，下一帧在新密度上重建；不会把不同采样格的显示列表
误当作同一版本复用。

这可视为对两个采样变换（系统后备密度与框架离屏倍率）的乘法作用取一个满足下界的最小代表，而不是无条件复合：
在低 DPI 上保留几何抗锯齿，在高 DPI 上避免已有物理样本再乘 2 导致每帧约 4 倍像素。阈值和策略属于内核，应用
仍只声明逻辑尺寸；需要可复现实验、像素风或固定质量时才显式指定 1/2。真实 D3D11 的 `planner_scroll` 同进程
`ss2 → Auto → ss1` 对照与 `@@BENCH_ENV` 最终倍数共同看护该策略，避免只凭 headless CPU 数字调 GPU 路径。

密度正规化仍留下一个资源反例：低 DPI 的 5K/8K 输出会继续选择 2x，旧实现直接以 `Int32` 计算
`outW * factor`，既可能先溢出，也可能在硬件拒绝前尝试 225 MiB 乃至更大的 RGBA8 target。现在 Auto 的
候选还必须落在 32 Mi 像素预算内，并在乘法前满足 SDL renderer 报告的最大纹理边长；4K 2x 的 33.18M 像素
仍保留，5K 2x 的 58.98M 像素回退 1x。显式正数不受框架像素预算限制，只受算术与硬件可表示性约束，继续是
精确质量/压力旋钮。尺寸或 DPI 使选择改变时，旧 target 与命令 epoch 一起换代；同尺寸原生分配失败会记忆，
避免逐帧重试造成资源抖动。

这把策略从单一全序阈值提升为约束集合上的可行域：密度给出质量下界，像素/纹理上界给出资源理想，内核选择
可行域内成本最小的代表。公开面不要求应用理解该数学结构；`renderSamplingStats()` 直接给出请求/选择倍率、
target 尺寸、RGBA8 字节估算、硬件边长和回退原因。基准同步记录 pixels/bytes/max-edge，并以
`bytes = 4 × pixels` 的确定性门禁防止诊断漂移。D3D11 改造前/后三轮 planner ss2 中位为
10.436/10.504 ms（+0.65%，噪声量级），Auto 为 2.994/2.988 ms；正常尺寸未观察到可辨认性能税。
最终三轮反向轮换全套件中 planner ss2/Auto/ss1 为 10.600/3.006/3.002 ms，P95 为
11.993/3.632/3.563 ms；106/106 个 headless 场景达到 120fps，19/19 个显示场景满足 60fps P95、18/19
满足 120fps P95，唯一压力项仍是刻意绕过 Auto 预算的显式 ss2。

## 缩放文本度量的栅格空间正规化

最新显示计数揭示另一个坐标层错位：布局期在 scale 1 的度量可以命中缓存，但场景内 `textCenter` 为匹配真实
hinting 会按 `pointSize × scaleY` 测量；旧缓存只接纳 scale 1，导致高 DPI、应用缩放和超采样下每个居中标签
每帧都重新进入 SDL_ttf。40 分区全量表单因此在 384000 次测量中产生 78000 次实算，恰好每帧 520 次。

缓存现在保存字体栅格器空间中的原生 metrics：键使用实际栅格字号、样式、字体族和文本；命中后才分别除以
`scaleX/scaleY` 回到逻辑空间。这是对缩放作用选择稳定中间对象，而不是把整个变换笛卡尔积塞入 key：相同纵向
栅格尺寸可共享原生结果，横向缩放只影响映回，非均匀变换也不混淆。字体 revision 继续整体失效相关 cache，
两代容量边界不变，公开 API 无新增优化开关。

无窗口反例先证明 scale 2 重复居中只实算一次、scale 3 产生新项、回到 scale 2 再次命中。真实 planner 在
三种采样策略下都由 9115/33490 次实算降为 8/33490（0.024%，来自滚入视口的新文本）；40 分区全量表单降为
0/384000。三进程定向 profile 的绘树中位约从 3.44 降到 3.30 ms，整帧均值中位从 8.386 降到 8.152 ms，
约改善 3.9%/2.8%。最终反向轮换套件中该表单 P95 从 9.738 降到 9.265 ms，120fps 超限帧从 52 降到 45；
仍未跨过 8.33 ms，所以总结果如实保持 18/18 个显示场景满足 60fps、16/18 满足 120fps。性能门禁新增暖测
窗口实算低于请求 1% 的确定性契约，避免墙钟噪声掩盖缓存旁路复发。

随后试验了把缩放文字的 1:1 SDL scale/clip 状态延迟到下一条非文本命令再恢复，使相邻文字共享一个 native
text pass。诊断证明状态进入由 78000 降到 54000（每帧 520→360，减少 30.8%），但三进程整帧中位约
8.183 ms，与试验前 8.152～8.224 ms 的观测落在 ±0.5% 噪声内，P95 也没有稳定改善。该方案却要求所有
geometry、texture、viewport、clip、命令栈恢复和异常路径共同维护一个隐藏设备状态；这会把局部文字实现变成
全 Renderer 的时序协议。原型、计数 API、测试和基准字段因此全部撤销，只保留当前每次文字绘制显式恢复的
异常安全边界。状态转换次数下降不是用户价值的充分统计量；必须继续寻找能减少字体绘制、像素或提交本身的方案。

## 普通滚动容器的保守绘制裁剪

缩放文字缓存修正后，40 分区全量表单仍在每帧访问全部 520 个文本绘制点；GPU clip 虽然阻止像素越过视口，
却发生在 Widget 已经递归执行之后。普通 `ScrollView + VStack/HStack` 因此只有结果裁剪，没有工作裁剪。内核
现在让 paint 阶段也继承与 layout/semantics 共用的组合 `SpatialClip`。Stack 保存本次 layout 精确分配给每个
直接子项的瞬时边界，令 `Pᵢ = paintOutsetᵢ.expand(Bᵢ)`；仅当 `Pᵢ ∩ C` 有严格正面积时进入该子树的 `draw`。
未布局和不参与布局的节点仍保守绘制，避免 Portal/overlay 一类零空间节点被误删。

这里的数学对象不是公开 API，而是一个可审计证明：clip 在矩形交上形成 meet-semilattice，嵌套容器只需取 meet；
空 meet 是“不会贡献像素”的充分证书。`PaintOutset` 是把布局边界送到保守绘制边界的单调扩张；阴影、描边和自定义
halo 只要声明真实外溢就不会被裁掉。边界恰好相接的交集面积为零，可以安全跳过。Stack 使用和即时实例同寿命的独立
layout 数组，没有借用 retained event topology 的已提交读面，因而不会把事件索引、绘制时序和 Element 版本绑成
一个隐式一致性协议。下一次 layout 会覆盖证书；异常路径由 `finally` 同时恢复 renderer clip 和 UiContext clip。

该优化不改变 measure、layout、焦点、事件或语义访问，仍是 O(n) 检查直接子项、O(k) 绘制相交子树；超大数据集
继续用 LazyColumn/LazyRow 获得 build/layout 的 O(k) 窗口化。公开 `Widget.draw` 契约相应明确为可在确定不可见时
省略：业务生命周期使用 State/effect/显式 frame subscription，不能把 draw 当唯一时钟。绘制局部动画可以在离屏时
暂停。Tooltip 给出了反例修正：滚动使锚点离开指针时由仍会执行的 layout 复位 dwell，不能依赖可能被省略的 draw。

Direct3D11、640×720、显式 ss2 的 40 分区全量表单中，文本绘制计数从 78000 降至 4030（150 帧，约 -94.8%）。
最终三轮反向轮换的均值中位为 3.883 ms，相对最近 8.131 ms 改善约 52.2%；P95 从 9.265 降至 5.440 ms
（约 -41.3%），仅 1/150 帧超过 120fps 预算。窗口化版本为 2.239 ms、P95 2.533 ms，说明剩余差距来自
全量 build/layout，而不是 paint。完整结果从上一轮 18/18 个显示场景满足 60fps、16/18 满足 120fps，提升为
18/18 与 17/18；唯一 120fps 压力项仍是显式 ss2 planner。确定性门禁要求 40 分区普通路径的 draw 计数不超过
窗口化路径两倍；当前 4030/4467 通过，旧 78000/8073 稳定失败，避免墙钟噪声掩盖遍历回归。

## 自测量虚拟化与稀疏 extent 精化

普通 Stack 的下一步不能直接“离屏就跳过 layout”。当前 Widget 使用绝对坐标，layout 还原子提交事件索引、语义和
overlay；没有命令、语义、事件共同的平移作用与等变证书时，只跳一棵树会制造坐标版本分裂。该原型方向因此在写入
生产实现前被反例否决。真正的开发者负担来自另一处：既有 `LazyList` 虽能 O(log N) 查询变高行，却要求业务维护
`heightOf`、缓存高度或 `LazyListExtents`，把派生布局事实复制进应用状态。

`LazyList.measured` 现在只接收一个初始估计和普通行 builder。内部把未知 extent 向量初始化为常量先验；进入预取
窗口的行在有限宽、无界高约束下报告 intrinsic height，框架先完成整批测量，再以稀疏点补丁写 Fenwick 加法索引。
若一批有 k 个变化，更新为 O(k log N)，只发布一次 State 失效；任一用户 measure 抛错时尚未改索引，不会提交半批
几何。相同宽度和 `UiEnvironmentKey` 下，AutomaticRenderNode 的 measure 依赖/缓存继续生效；宽度、字体或显示环境
变化会把旧测量统一退回估计，但不伪造结构变化。

锚定顺序是该协议的关键。发布稀疏补丁前，viewport 在旧前缀和上记录 `(stableKey, withinRow)`；补丁完成后立即把
scroll 重投影为 `newPrefix(key) + withinRow`，extent signal 与 offset 在同一布局事务中发布。若反过来先更新前缀再
识别顶部行，前序行变高会把 anchor 悄悄换成另一 key，并多出一次稳定化 pass。反例固定了 50→90 的前序行变化后
row.3 仍位于 y=0，offset 150→190，整帧只需 2 pass。初始估计错误导致滚动条车道出现/消失时，最多依次经历
初始宽度、车道宽度和稳定证明 3 pass，恰好落在 shell 的有界稳定化协议内。

这里可以把 Fenwick 索引看成非负 extent 在加法幺半群上的前缀函子，测量是从“未知行取估计代表”到“可见行取精确
代表”的单调知识精化；稳定 key/行内偏移是不随这种坐标重参数化改变的观察量。数学只用于确定提交顺序与复杂度，
公开 API 仍是 `LazyList.measured(data, estimatedHeight:, key:)`，不要求开发者理解树状数组或锚定证明。

最终三轮 headless 中，48 区块自测量为 0.214 ms，对普通 1.354 ms 快 6.3×；固定高度 LazyColumn 为
0.120 ms，自测量为其约 1.78×，这是换取零逐行高度状态的显式 CPU 上界。真实 Direct3D11 的 40 分区 ss2
同轮均值/P95 为：普通 4.137/5.301 ms、固定高度 2.281/2.650 ms、自测量 2.239/2.527 ms。自测量相对
普通路径约改善 45.9%/52.3%，与固定高度没有可辨认退化。确定性计数更强：measure 请求 22940 对普通
310030（-92.6%），draw 为 4030，对固定路径 4467，字体实算仍为 10。门禁要求自测量 measure 少于全量
四分之一，且 draw 不超过固定窗口两倍。完整套件 100/100 个 headless 场景达到 120fps；19/19 个显示场景满足
60fps P95、18/19 满足 120fps，唯一压力项仍是显式 ss2 planner。

## 可观察集合快照与按 key 重索引

最初的自测量入口仍把一个本应单一的结构事实拆成 `Array<T>` 与 `revision` 两个调用方参数。开发者既要在每次
插入/删除/重排时更新二者，又可能读取到值和版本不对应的组合。`LazyColumn.of`、`LazyRow.of`、
`LazyList.of` 与 `LazyList.measured` 现均提供 `State<Array<T>>` 重载；内部调用 State 的单次
`(value, revision)` 快照，并把这一前像传给原有 Array 内核。不可观察数据仍可使用显式 revision 的兼容形态，
但普通应用不再维护第二个事实源。数组必须以 State 赋值替换，原地变异不会虚构一次可观察提交。

结构变更以前会清空所有已学 extent。现在测量缓存保存稀疏偏映射 `h: K ⇀ ℝ⁺`，新结构给出索引到业务身份的
映射 `p: I → K`；重建 extent 向量就是沿 `p` 拉回 `h`：`(p* h)(i) = h(p(i))`，未定义处取估计值。
这不是把范畴论名词暴露给 API，而是用重索引律明确“不变量属于业务对象，不属于数组槽位”。同一 revision 的恒等
态完全不求值 `p`；只有结构 revision 改变且显式提供唯一 key 时扫描 N 个 key，稳定帧仍为窗口工作。已测 m 个
key 的附加空间为 O(m)，结构事务 O(N)，之后可见 k 行的稀疏更新仍为 O(k log N)。宽度、字体/显示环境、估计、
间距或 key 策略变化会清除映射，防止在不同测量对象之间错误拉回。

确定性测试证明首次准备与同版本稳定帧均读取 0 个全量 key，结构版本变化时恰好读取 N 个；端到端反例让
k0/k1/k2 学到 30/40/50px，再在其前插入两个估计为 20px 的新 key，顶部 k3 的 offset 精确从 120 变为 160。
旧清空策略会得到 100，因此测试不是同高估计下的弱等价。双 Host 常驻、16 段交替的 10k 项稳定帧七样本中，
应用手写 `snapshot + revision` 中位为 5519ns，State 重载为 5469ns；差异约 0.9%，按噪声处理。完整三进程
套件使用同进程逐样本比值消去共同漂移，自动/手工中位为 1.002、ratio MAD 7.3%，同样只证明易用性改进没有
可辨认性能税。未平衡的早期对照曾出现与 Host 生命周期绑定的 2× 漂移，因而被基准设计反例拒绝。

## 滚动连续作用与离散物化拓扑

新的瓶颈证据来自 planner 的阶段 profile。窗口化列表仍在每个滚动帧的 composition 中读取 offset，于是虽然只构建
一屏条目，声明体仍被连续重跑。更底层的反例是 AutomaticRenderNode 已把 State 读取登记为 measure/layout
依赖，但依赖失效回调又把 composition scope 标脏；相位图记录正确，执行策略却退化成 build→layout→draw 全链。

内核现在遵守严格的“读取相位决定最早重启相位”：measure/layout State 变化只失效节点对应的 Scene facet 并传播
必要的父级几何失效，不再反向污染 composition。结构 State 仍由 build collector 直接标脏。这与
[Jetpack Compose 的 phased state reads](https://developer.android.com/develop/ui/compose/phases)一致：高频 offset
在 placement/layout 读取时可以跳过 composition；也与 Flutter 的
[on-demand scrolling 与 sliver](https://docs.flutter.dev/ui/layout/scrolling)实践同向，但 CUI 没有把 sliver 协议
暴露成另一套应用编程模型。

对 LazyColumn/LazyRow 以及有可观察 extent 版本的 LazyList，令滚动位置空间为 `S = ℝ≥0`，当前物化索引区间为
`M ⊂ ℤ`。布局是 `S` 对已物化几何的平移作用 `τs`；需要的窗口 `D(s)` 由 viewport、extent 与方向预取给出。
只要 `D(s) ⊆ M`，滚动只执行 `τs`，composition 的离散拓扑不变；首次出现 `D(s) ⊄ M` 时，内部单调 generation
信号触发一次 build，把 `M` 换成包含 `D(s)` 的新区间。可把它看成由预取开集覆盖诱导的局部常值量化：连续状态
只在跨覆盖边界时改变离散对象。overscan 提供迟滞，避免边界附近每像素抖动重建。

构建期读取 offset 使用不登记 build 依赖的 phase hint，但它不是正确性来源。Widget 保存 hint 的 State revision；
layout 进行正常的 tracked read，revision 不同就用最新 offset 更新平移。若最新窗口越界，generation 是真正的 build
依赖，宿主在绘制和语义提交前完成稳定化重建。因此协议是“投机种子 + 受跟踪验证 + 同帧修复”，而不是弱一致缓存。
controller 请求、数据 revision、extent revision、自测量提交仍是结构或几何 build 输入。无 revision 的兼容
`heightOf` 闭包无法证明高度稳定，故保守保留随滚动重建；框架不以性能名义改变其可观察语义。

确定性 A/B 使用相同场景、相同 Host 和 800 个 24px 滚动帧：Incremental 只执行 51 次列表 body，Full 精确
执行 800 次；稳定化总数为 `800 + 51 = 851`，证明每个物化边界只增加一个修复 pass。build 均值
151.22→18.37 μs（8.23×），完整 headless 帧 285.32→213.05 μs（1.33×）。真实 Direct3D11 planner 的稳定
build 降到约 0.04–0.11 ms；Auto 仍约 3.00 ms。显式 ss2 仍约 10.49 ms，因为 1120×720 逻辑窗口在
3.375× backing 上再做 2× target 约为 7560×4860、36.7M 像素，主要成本仍在 GPU present。D3D12、SDL GPU、
OpenGL、Vulkan 与纹理格式候选均未给出稳定收益，故没有用后端切换掩盖这一独立压力项。

复杂度从“每 F 帧做 F 次 O(k) build”变为“O(B·k) build + O(F·k) layout/draw”，其中 B 是物化边界穿越数、
通常远小于 F，k 是视口加预取条目数；内存仍为 O(k)。墙钟比例进入同进程 paired report，`51/800/851`
进入确定性 contract，任何重新把 offset 读回 build 或一次边界多次稳定化的回归都会直接失败。

## 定位目标的和类型与信息保持

物化相位拆分后，100k 项 `scrollToKey` 扩展性探针仍有约 1.38–1.97 ms 的首请求成本。原因不是窗口构建，而是
列表公开 `key: I → K`，按 key 定位必须求它在当前结构上的偏逆 `K ⇀ I`；在没有额外证明时只能扫描 O(N) 后缓存
反向表。旧 API 即使调用方已经持有 `i ∈ I`，也只能先编码为 key，再让框架把信息逆回 index，产生不必要工作与
心智负担。

`LazyViewportController` 现在把待处理目标建模为代数和 `1 + K + I`：`NoTarget | StableKey(K) | ItemIndex(I)`，
对应绝对像素 jump、稳定身份定位和当前槽位定位。它不是用空字符串或负数复用字段，因此“取消请求”“key 请求”
和“index 请求”是互斥且穷尽的状态。`scrollToIndex` 对固定 extent 直接 O(1) 取 top，对 Fenwick 变高 extent
O(log N) 取前缀；只有 `scrollToKey` 首次需要 O(N) 建逆，结构版本稳定后也复用为 O(1)。这与
[Compose LazyListState 的 requestScrollToItem/scrollToItem](https://developer.android.com/reference/kotlin/androidx/compose/foundation/lazy/LazyListState)
把 index 作为一级导航坐标的实践一致，同时保留 CUI 跨重排 key 语义。

请求消费也改为事务提交：controller revision 只在目标解析、所有用户 key 回调与几何求值成功后写入 viewport
memory。异常使旧 revision 保持未消费，下一帧可重试；`jumpTo` 把目标改为 `NoTarget` 并恢复成功状态，处理 pending
revision 时不再错误构造 key 索引。负 index 在控制器边界拒绝，非负越界值由已挂载 viewport 根据当前 count 标记
missing，因而请求与数据提交之间的竞态有明确定义。

五轮同进程 100k 项、每轮 12 次随机导航中，index/key 绝对中位为 229.10/1808.43 μs/帧，逐轮配对比值
中位为 0.126（index 约快 7.9×）；10k/100k index 均精确为平均 75 次可见 key 访问，而 key 路径分别为
575/8408。确定性门禁要求 index 两个规模都不超过 128 次、100k 不得随总量放大，并要求冷 key 路径确实暴露
全量逆表成本，避免基准被意外预热后失去辨别力。线程所有权检查包含在这组最终数字中。

## 为什么不要求开发者选择优化开关

常规代码只需要：可见可变事实放在 `State`，可重排列表提供稳定 key，资源放在生命周期 effect。
组合命中、节点晋升、显示列表、退避、预算和 damage 都是内部策略，可在不改应用代码的情况下
继续调参或替换。`RetainedSubtree` 留作兼容、框架实验和诊断对照，不再是应用获得合理性能的
前置条件；`--cui-force-full-retained` 则保留为语义/性能差分参照。

## 验证方法

- 单元测试验证依赖边动态更新、自身/后代脏传播、干净兄弟跳过、父捕获刷新、策略事务净零归约、
  提交异常后的证明清理、事务回滚和诊断。
- `WidgetTestHost` 在 Incremental/Full 两种模式运行相同 UI，比较焦点、事件、文本计数、布局和
  snapshot。
- 自动专项看护包括：240 分支只执行 1 个脏 body、深廉价链不批量晋升、复杂兄弟 layout 访问
  归零、静态声明稳定帧执行 0 次而外部版本声明执行 1 次、稳定绘制不再进入 widget draw、dynamic 协议退避、
  LRU 预算淘汰、512 个稳定 Frame 订阅片段创建为 0 和局部 damage 边界。
- `examples` 继续作为端到端用例；截图差分使用同一字体、显示比例和渲染后端元数据。
- 性能门禁同时看绝对帧预算、同机域归一化、样本 MAD 和成对 A/B 比率，环境不匹配时只给
  observational 结论，不制造假回归。
