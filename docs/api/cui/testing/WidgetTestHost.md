[cui](../../index.md) › [cui.testing](index.md) › WidgetTestHost

# WidgetTestHost

确定性无窗口测试宿主。它保留 `rememberState`/`RetainedSubtree` 身份，并执行与 `DesktopApp` 相同的
“构建布局 → 指针/焦点/浮层事件事务 → 必要时绘制前重建 → 绘制”顺序。

```cangjie
public class WidgetTestHost {
    public let context: UiContext

    public init(theme!: Theme = Theme.light(), displayScale!: Float32 = 1.0,
        fontScale!: Float32 = 1.0,
        retainedMode!: RetainedTestMode = RetainedTestMode.Incremental,
        renderer!: Renderer = Renderer.headless())
    public func frame(rect: Rect, elapsedMs!: UInt64 = 0, deltaMs!: UInt64 = 0,
        events!: Array<UiEvent> = [], damage!: ?Rect = None, body!: () -> Unit): TestFrameResult
    public func frameRecords(rect: Rect, elapsedMs!: UInt64 = 0, deltaMs!: UInt64 = 0,
        events!: Array<UiEventRecord> = [], damage!: ?Rect = None, body!: () -> Unit): TestFrameResult
    public func retainedDiagnostics(): RetainedGraphDiagnostics
    public func batch(action: () -> Unit): Unit
    public func reset(): Unit
}
```

`frame` 返回稳定树、分阶段指标和当帧消费的立即/截止时间计划；`batch` 合并测试中的多次状态写；
`reset` 卸载全部局部/保留状态，并清空焦点、悬停、按压、拖拽、浮层、关闭标记和遗留帧请求。
宿主不创建 SDL 窗口，适合单元、集成和 headless 性能测试；GPU、字体光栅与呈现性能仍应由显示基准验证。`frameRecords` 与 `frame` 执行同一事务，但允许注入 timestamp/window/key/modifier 元数据，用于稳定测试 Ctrl/Command/Shift 快捷键与延迟派发；测试不再依赖机器当前全局键盘状态。
`retainedDiagnostics` 不运行新帧，返回最近一次已提交执行图的结构化快照和稳定文本摘要。

默认 Renderer 为 headless；传入真实 `SdlWindow.renderer` 可让同一宿主执行字体、命令重放与像素级 E2E。
`damage: Some(rect)` 请求局部帧：Renderer 能保留目标时只绘制与区域相交的干净 retained 边界，否则安全回退
全帧。测试应把局部结果与相同最终 State 的全帧截图比较，同时断言绘制计数确实下降；只比较耗时或截图之一都
不能证明优化正确且生效。

`retainedMode: RetainedTestMode.Full` 强制执行每个 retained 声明体及其阶段，用来把最终树、帧计划、
交互状态或截图与默认增量模式做差分。Full 模式故意禁用命中，因此不能用于代表正常运行性能。
