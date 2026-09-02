<!-- kind: how-to; audience: component-author -->

# 验证增量更新与帧行为

## 目标

理解框架默认的增量更新方式，只在确有需要时使用 `RetainedSubtree`，并用 `WidgetTestHost` 验证状态、事件和重建范围。

## 先用默认机制

普通页面直接读取 `State.value` 并声明界面即可。框架会记录构建、测量、布局和绘制期间的状态依赖，在状态变化后只执行
受影响的阶段。稳定子树、局部状态、焦点、浮层和帧订阅都会由运行时维护，应用通常不需要手工设置缓存边界。

大量同类数据应先使用 `LazyColumn`、`LazyRow`、`LazyGrid` 或 `LazyList`。虚拟化减少实际创建的项目数，不能用
`RetainedSubtree` 替代。

## 何时使用 RetainedSubtree

`RetainedSubtree` 是高级控制点，适合下列情况：

- 兼容依赖普通对象或外部快照的旧代码；
- 为框架功能建立增量模式与全量模式的差分测试；
- 诊断结果已经证明，自动依赖跟踪无法覆盖某个外部输入。

只传 `key` 时，框架自动跟踪 `body` 内读取的 `State`。如果输入不是 `State`，或者在进入 `body` 前已经计算完成，
再传递显式 `revision`；输入变化时必须同步增加该版本。`key` 在当前声明作用域内必须稳定且唯一。

`cachePaint: true` 还会记录绘制命令，适合内容稳定、绘制成本高的区域。主题、资源或普通可变字段发生变化时，必须由
`State` 或 `revision` 表达；否则框架不知道何时重新记录。使用续帧、焦点、悬停、按压、拖动、提示、输入法或浮层等动态能力时，
运行时会自动暂时绕过绘制缓存。

## 把副作用放在提交阶段

界面构建可能被跳过、重试或在同一帧内再次执行，因此不要在 builder 中注册监听器、启动监视任务或占用外部资源。
挂载期间只执行一次的工作使用 `mountEffect`；需要随输入替换的工作使用
`lifecycleEffect(key, revision, setup)`。`setup` 返回 `EffectCleanup`，负责释放本次建立的资源。

## 使用无窗口宿主验证

下面的程序连续运行三个无窗口帧：第二帧没有状态变化，保留子树不重建；修改 `count` 后，第三帧只重建一次。该示例可直接编译运行。

```cangjie verify role=complete profile=headless
package docexample

import cui.*

class BuildProbe {
    var builds: Int64 = 0

    func record(): Unit {
        builds++
    }
}

main(): Unit {
    let host = WidgetTestHost()
    let count = State<Int64>(0)
    let probe = BuildProbe()
    let bounds = Rect(0.0, 0.0, 320.0, 120.0)
    let body: () -> Unit = {
        => let _ = RetainedSubtree("summary") {
            probe.record()
            Label("计数：${count.value}")
        }
    }

    let _ = host.frame(bounds, body: body)
    let stable = host.frame(bounds, body: body)
    if (probe.builds != 1) {
        throw IllegalStateException("稳定帧不应重建保留子树")
    }

    count.value = 1
    let changed = host.frame(bounds, body: body)
    if (probe.builds != 2) {
        throw IllegalStateException("依赖变化后应重建一次")
    }

    println("stable=${stable.metrics.totalNs()} ns, changed=${changed.metrics.totalNs()} ns")
}
```

`WidgetTestHost.frame` 的执行顺序与桌面宿主一致：构建和布局、事件事务、必要的绘制前重建、绘制。返回值包含稳定后的控件树、
各阶段耗时和下一帧计划。测试交互时通过 `events` 传入 `UiEvent`；测试快捷键及时间戳时使用 `frameRecords`。

需要确认增量执行没有改变结果时，分别使用默认宿主和
`WidgetTestHost(retainedMode: RetainedTestMode.Full)` 运行相同输入，再比较业务状态、稳定树或最终图像。全量模式用于
正确性对照，不代表正常性能。

## 读取诊断信息

`host.retainedDiagnostics()` 返回最近一次已提交的增量执行图。优先检查结构化字段：

- `scopes`：每个边界的依赖数、命中数、失效原因和绘制命令规模；
- `pendingDamage`：下一帧需要更新的区域；
- `fullDamagePending`：下一帧是否必须全量绘制。

`describe()` 适合写入缺陷报告，自动化测试应直接断言结构化字段。性能测试要先预热，再分别记录稳定帧和失效帧；不要用
单次耗时、Debug 构建或开启垂直同步后的帧率判断优化效果。

仓库级验证可运行：

```text
python .dev/cli.py test examples
python .dev/cli.py test examples --smoke-snapshots
python .dev/cli.py test examples --smoke-snapshots --retained-diff
```

`--retained-diff` 会比较默认增量模式和强制全量模式的快照。局部绘制测试还应同时证明绘制工作减少且最终图像一致。

## 检查清单

- 可观察输入使用 `State`，普通输入才使用显式 `revision`。
- `key` 稳定且在当前作用域内唯一。
- `cachePaint` 内没有未版本化的可变绘制数据。
- builder 不直接创建需要释放的外部资源。
- 事件修改状态后，同一测试帧得到最新界面。
- 增量模式与全量模式输出一致。
- 性能报告同时包含稳定帧和失效帧。

## 常见错误

- 使用时间或对象地址作为 `revision`，导致每帧失效。
- 在 `body` 外读取 `State`，却以为该读取会由边界自动跟踪。
- 用保留子树包住上万行数据，而没有使用虚拟化容器。
- 只比较耗时，没有检查最终状态或图像是否一致。

## 相关 API

[`RetainedSubtree`](../../api/cui/core/RetainedSubtree.md)、
[`RetainedGraphDiagnostics`](../../api/cui/core/RetainedGraphDiagnostics.md)、
[`WidgetTestHost`](../../api/cui/testing/WidgetTestHost.md)、
[`mountEffect` 与 `lifecycleEffect`](../../api/cui/core/functions.md)。
