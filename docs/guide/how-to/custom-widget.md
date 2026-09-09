<!-- kind: how-to; audience: component-author -->

[CUI 指南](../index.md) › 自定义 Widget

# 实现完整自定义 Widget

## 目标

实现一个可复用的等级选择器。它会像内建控件一样参与布局、链式修饰、指针事件、键盘焦点和无障碍操作，而不只是绘制一块画布。

如果需求只涉及自由绘制和简单指针回调，优先使用 [`CanvasWidget`](custom-canvas.md)。只有组件需要自定义尺寸、完整输入协议或容器行为时，才直接实现 `Widget`。

## 组件协议

一个具体组件必须完成五件事：

1. 构造时调用一次 `emit(this)`，加入当前声明块。
2. `measure` 在父级约束内返回首选尺寸。
3. `layout` 保存最终矩形，并登记依赖几何的语义信息。
4. `draw` 根据已提交状态绘制，不在绘制阶段修改业务状态。
5. `handle` 只在真正处理事件时返回 `true`。

组件实例可能随所属声明重新创建。需要跨构建保留的值应由调用方通过 `State`、`Binding` 或 Store 持有；实例字段适合保存构造参数和本次布局矩形。

## 完整示例

```cangjie verify role=complete profile=gui-visual
package docexample

import cui.*

class LevelPicker <: Widget {
    private static let COUNT: Int64 = 5
    private let label: String
    private let value: Bindable<Int64>
    private let id: String
    private var frame = Rect.zero()

    init(label: String, value: Bindable<Int64>, key: String) {
        this.label = label
        this.value = value
        id = focusableControlIdentity("LevelPicker:${key}")
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(available.w, 240.0), min(available.h, 40.0))
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        ctx.registerSemantics(
            SemanticsNode(
                id,
                Semantics(
                    label: label,
                    role: SemanticsRole.Slider,
                    value: "${current()} / ${COUNT}",
                    hint: "使用左右方向键调整等级"
                ),
                rect,
                actions: [
                    SemanticsAction.Focus,
                    SemanticsAction.Increment,
                    SemanticsAction.Decrement
                ]
            ),
            perform: {action =>
                match (action) {
                    case SemanticsAction.Focus =>
                        ctx.focus(id, viaKeyboard: true)
                        true
                    case SemanticsAction.Increment => change(1)
                    case SemanticsAction.Decrement => change(-1)
                    case _ => false
                }
            }
        )
    }

    public func draw(ctx: UiContext): Unit {
        let step = frame.w / Float32(COUNT)
        for (index in 0..COUNT) {
            let level = index + 1
            let box = Rect(
                frame.x + Float32(index) * step + 2.0,
                frame.y + 4.0,
                max(0.0, step - 4.0),
                max(0.0, frame.h - 8.0)
            )
            let color = if (level <= current()) {ctx.theme.accent} else {ctx.theme.field}
            ctx.renderer.fillRoundedRect(box, 6.0, color)
        }
        if (ctx.showFocusRing(id)) {
            drawFocusRing(ctx, frame, 8.0)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        claimHoverIfInside(ctx, event, frame, id, CursorShape.Interactive)
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y) && frame.w > 0.0) {
                    ctx.focus(id)
                    let selected = Int64((x - frame.x) / (frame.w / Float32(COUNT))) + 1
                    value.value = min(COUNT, max(Int64(1), selected))
                    return true
                }
            case UiEvent.KeyDown(Key.Left, _) =>
                if (ctx.hasFocus(id)) { return change(-1) }
            case UiEvent.KeyDown(Key.Right, _) =>
                if (ctx.hasFocus(id)) { return change(1) }
            case _ => ()
        }
        false
    }

    public func focusableId(): ?String {
        Some(id)
    }

    public func pointerEventScope(): PointerEventScope {
        PointerEventScope.LayoutBounds
    }

    private func current(): Int64 {
        min(COUNT, max(Int64(1), value.get()))
    }

    private func change(delta: Int64): Bool {
        value.value = min(COUNT, max(Int64(1), current() + delta))
        true
    }
}

main(): Unit {
    let app = DesktopApp(WindowSpec("自定义组件", 420, 220))
    app.run {
        let level = rememberState<Int64>("level") {3}
        VStack(spacing: 12.vp) {
            Label("服务质量：${level.value} 级")
            LevelPicker("服务质量", level, "quality").fillWidth()
        }.padding(20.vp)
    }
}
```

## 关键设计

### 状态由调用方持有

`LevelPicker` 接收 `Bindable<Int64>`，因此既能连接普通 `State`，也能连接大型模型的字段 `Binding`。组件不复制业务值，重建后也不会丢失选择。

### 绘制与命中使用同一矩形

`layout` 保存的 `frame` 同时用于绘制和命中测试。组件被放进带内边距、滚动或分栏的容器后，坐标仍保持一致。

### 多种输入复用同一动作

鼠标、方向键和无障碍增减动作最终都调用同一套数值更新逻辑。这样不会出现鼠标和键盘行为不同步的问题。

### 只消费属于自己的事件

指针按下必须位于 `frame` 内；按键必须在组件持有焦点时才消费。`claimHoverIfInside` 只申请悬停样式，不会阻止其他组件继续接收移动事件。

### 边界声明必须真实

示例中的所有指针逻辑都受 `frame` 限制，因此可以返回 `PointerEventScope.LayoutBounds`，让父容器跳过明显无关的事件。如果组件需要在矩形外观察手势，不要声明这个优化。

## 容器组件

业务复合组件通常用现有容器组合即可，例如用 `Panel`、`VStack` 和 `HStack` 组成带标题的编辑区。只有布局算法本身无法由现有容器表达时，才需要实现底层容器。

自定义容器除了四个必选方法，还必须正确处理子组件收集、约束传递、布局顺序、绘制层级、事件反向派发、焦点列表、绘制外溢和脱离布局节点。它属于框架级扩展，应为每个阶段分别编写测试。

## 检查清单

- 构造器是否恰好调用一次 `emit(this)`？
- `measure` 是否尊重 `available`？
- `draw` 和 `handle` 是否使用 `layout` 提交的同一矩形？
- 跨构建数据是否由 `State`、Binding 或 Store 持有？
- 事件是否只在实际处理后返回 `true`？
- 是否支持合理的 Tab、键盘和无障碍操作？
- 绘制超出布局矩形时，是否通过 `paintOutset` 声明最大范围？
- 动画停止后，是否停止请求下一帧？
- 只有在能够证明边界时，才声明 `PointerEventScope.LayoutBounds`？

## 测试建议

使用 [`WidgetTestHost`](../../api/cui/testing/WidgetTestHost.md) 验证小尺寸和正常尺寸测量、非原点布局、内外命中、键盘焦点、禁用状态、语义节点与动作。视觉组件还应比较默认增量模式和强制全量模式的最终像素，确保缓存没有掩盖依赖遗漏。

## 相关 API

- [`Widget`](../../api/cui/core/Widget.md) — 完整组件协议和链式修饰器。
- [`UiContext`](../../api/cui/core/UiContext.md) — 焦点、悬停、拖拽、语义和帧调度。
- [`emit`](../../api/cui/core/functions.md#emit) — 把组件加入当前声明块。
- [`CanvasWidget`](../../api/cui/media/CanvasWidget.md) — 只需要自由绘制时的轻量入口。
