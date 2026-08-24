<!-- kind: how-to; audience: component-author -->

# 保留昂贵子树并建立帧级测试

## 目标

普通 UI 先直接使用 `State` 和声明式 builder，由框架自动完成脏路径、复杂边界晋升、显示列表与
damage。只有兼容旧代码、构造框架 A/B 实验，或诊断确认自动策略无法观察普通外部输入时，才使用
`RetainedSubtree` 显式覆盖边界；用 `WidgetTestHost` 验证同帧状态一致性、事件和每阶段成本。

## 先选择正确边界

虚拟列表仍是大量同类数据的首选；它把工作量从 O(总行数) 降到 O(可见行数)。不要先用手工 retained
掩盖缺少虚拟化或错误状态边界。当前自动策略会识别单根、宽/分支复杂且稳定的仪表盘、说明区和自绘区；
显式保留子树适合框架开发与外部不可观察 revision 的兜底，而不是应用的默认“性能开关”。

首选 key-only 重载：body 内实际读取的 `State.value` / `revision` 会自动登记，动态分支重建后旧依赖也会
解除。命中后控件事件、`rememberState`、焦点、浮层仍存活；普通绘制仍会执行。

```cangjie
RetainedSubtree("summary") {
    summaryDashboard(model.snapshot.value)
}
```

自动追踪的边界是框架正在执行的 phase：body 外预先求值再捕获不会被看见，普通不可观察值也没有写入通知。
此时使用 revision 重载。自定义 Widget 在 measure/layout 中直接读取 State 会登记为对应依赖；开启
`cachePaint` 时 draw 读取也会使命令缓冲失效。普通 draw 每帧本来就会执行，不需要建立 paint 跳过依赖。

```cangjie
let snapshot = service.snapshot() // 普通值，不是 State
RetainedSubtree("summary", snapshot.revision) {
    summaryDashboard(snapshot)
}
```

`cachePaint: true` 会在首次绘制时录制透明的值命令 display list，后续不再执行子树 draw，而按原 z 序重放；
它不截取祖先背景，也不会给每个边界分配 GPU layer。draw 内 State 会自动失效，revision 还要覆盖主题、资源
和其他不可观察视觉状态。调用 `UiContext` 的续帧、焦点/悬停/按压/拖拽、tooltip、IME 或 overlay 动态协议时，
框架会绕过当前及祖先缓存并在 diagnostics 写明原因。直接读取自定义可变字段无法被侦测，须改用 State/revision
或关闭 `cachePaint`。动态旁路采用 32→64→128→256 帧指数退避，期间直接绘制但仍收集 paint State；任何
State/revision/几何失效都会立即解除退避，所以不要用手工计数器替代框架策略。

```cangjie
RetainedSubtree("map", mapRevision.value, cachePaint: true) {
    mapCanvas(snapshot)
}
```

桌面运行时还会把 retained State 失效合并为 damage，只重放相交边界。仅纯状态、小区域、无输入/动画/浮层的
帧会尝试局部更新；root phase 依赖、区域超过视口 70%、窗口变化或后端无法保留目标时自动全帧。内置阴影按
布局框外扩 16 逻辑像素；绘制越界更多的自定义 Canvas 应扩大布局边界或关闭缓存。可用
`--cui-disable-retained-damage` 做仅关闭 damage 的 A/B，用 `--cui-force-full-retained` 做整个 retained 路径的
正确性参照。

## 把副作用交给提交生命周期

builder 可能执行、跳过、失败或为了同帧稳定化重复执行，不能在其中直接注册监听器、启动 watcher 或占用外部
资源。挂载期不随输入变化时用 `mountEffect`；需要随输入替换时显式传 revision 给 `lifecycleEffect`：

```cangjie
RetainedSubtree("project") {
    lifecycleEffect("watcher", project.revision) {
        watcher.start(project.value)
        EffectCleanup({=> watcher.stop()})
    }
    projectView(project.value)
}
```

setup 只在完整根构建体成功后执行。revision 替换会先建立新 Resource，成功后再关闭旧值；setup 失败保留旧
effect，已准备的兄弟 effect 逆序回滚。cleanup 抛错不会阻止其余兄弟清理，失败 Resource 会保留待下次重试，
首个异常仍向宿主抛出。setup 是提交回调，不能在其中调用 `rememberState`、effect 或继续声明 UI。

## 用真实帧顺序测试

`WidgetTestHost` 是无窗口宿主，保留局部状态，并按桌面循环的顺序执行：构建/布局 → 事件事务 →
必要时重建/布局 → 绘制。指针位置、悬停 settle、未认领点击清焦点、按压/拖拽收尾和浮层优先级也与
桌面宿主一致。它比直接调用单个 `handle` 更适合集成断言，也会返回分阶段纳秒数、文本度量、稳定化
次数以及 `result.schedule` 中的下一帧计划。

```cangjie
let host = WidgetTestHost()
let result = host.frame(
    Rect(0.0, 0.0, 640.0, 420.0),
    events: [UiEvent.KeyDown(Key.Enter, false)]
) {
    appView(model)
}

@Expect(model.submitted.value)
@Expect(result.metrics.stabilizationPasses, Int64(2))
@Expect(!result.schedule.hasPending())
```

需要定位意外重建或依赖过宽时，在帧后读取结构化执行图：

```cangjie
let graph = host.retainedDiagnostics()
for (scope in graph.scopes) {
    println("${scope.path}: ${scope.lastInvalidationReason}")
}
```

`scope.stats` 含 build/measure/layout/paint 依赖数、命中数、绘制命令数和估算字节，以及录制探测、动态旁路、
退避直绘与剩余退避帧；四个 dirty 字段说明下一次
不能命中的阶段，`scope.bounds`、`graph.pendingDamage` 与 `graph.fullDamagePending` 解释下一帧更新范围。
`graph.describe()` 可直接附到缺陷报告，但自动化断言应优先使用结构化字段。

怀疑自动依赖遗漏时，用相同输入分别跑默认宿主与
`WidgetTestHost(retainedMode: RetainedTestMode.Full)`，比较业务状态、稳定树摘要、帧计划与渲染结果。
Full 模式会故意关闭 retained 命中，只是正确性参照，不是性能对照组。

微基准先预热，再分别测 revision 命中与逐帧变化。仓库内 `bench/micro` 已包含同一 24 区块内容页的
A/B；`bench/phase3_probe.py` 还比较 full-tree、自动 retained、命令重放和 damage，用 `python bench/run.py`
生成普通报告。不要把单次运行、Debug 构建或开启垂直同步的帧率当优化证据。

局部绘制必须同时验证“少画了”和“结果相同”。`WidgetTestHost(renderer: window.renderer)` 可接真实 Renderer；
先取 `scope.bounds`，用 `frame(..., damage: Some(bounds))` 更新一块，再以相同最终 State 做一次全帧，断言文本/
命令绘制次数下降且两张 BMP 为 0 像素差。仓库的 desktop lifecycle fixture 就采用这套协议。

## 端到端看护

examples 同时是公开 API 的真实消费者。运行：

```text
python .devtools/test_examples.py
python .devtools/test_examples.py --smoke-snapshots
python .devtools/test_examples.py --smoke-snapshots --retained-diff
```

前者测试全部示例，后者真实开窗覆盖自绘、嵌套浮层、虚拟表格、文本编辑、密集表单和后台任务，并把
逐用例结果写到 `examples/.e2e-results/report.json`。视觉基线可再传 `--baseline <BMP目录>`；
`--retained-diff` 会为同一用例生成独立的全量执行快照，并与增量结果做容差内像素比较。

## 验收

- 自动 State 输入变化时重建、稳定帧命中；普通输入由 revision 推进并重建。
- `cacheStats()` 的依赖数符合预期，自动失效次数不会随同一事务内的多次写入重复增长。
- 保留区卸载后，其中的 `rememberState`、effect 与绘制命令被释放。
- 命令命中帧不执行子树 draw；局部 damage 帧减少相交外绘制且与同状态全帧逐像素一致。
- 事件写状态时，同一测试帧的最终构建读到新值。
- 性能报告同时保留命中与失效对照，不只展示较快的一侧。

## 常见错误

- 用墙钟或可变对象地址充当 revision：缓存会无意义地每帧失效。
- 在 body 外预先读取 State，却误以为会自动追踪：该边界只能观察 body 执行期间的读取。
- 把主题单例、普通可变对象等非 State 输入当作自动依赖：它们仍需显式 revision。
- 在 `cachePaint` 内直接读取未版本化的自定义可变字段：框架无法知道何时重录。
- 自定义 Canvas 绘制到布局框外 16 像素以远：局部 damage 可能覆盖不到旧像素，应扩大边界或关闭缓存。
- 用保留子树包住上万行而不虚拟化：首次构建和失效帧仍是 O(总行数)。

## 相关 API

[`RetainedSubtree`](../../api/cui/core/RetainedSubtree.md)、
[`RetainedGraphDiagnostics`](../../api/cui/core/RetainedGraphDiagnostics.md)、
[`EffectCleanup`](../../api/cui/core/EffectCleanup.md)、
[`WidgetTestHost`](../../api/cui/testing/WidgetTestHost.md)、
[`DesktopApp`](../../api/cui/desktop/DesktopApp.md)。
