# 从组合视图到完整控件：CUI 自定义 UI 组件实战指南

> 本文基于 CUI 0.9.5、仓颉 SDK 1.0.5 与提交 `6ebc650` 的公开 API 和实现撰写，分析日期为 2026-09-01。文章可独立发布，不依赖项目内其他文档或图片。

业务界面不可能只由框架内置控件组成。状态卡片、标签行、图表、流程节点、时间轴、画布和行业专用控件，最终都需要应用自己扩展。

在 CUI 中，“自定义组件”并不等于“马上实现 `Widget`”。更准确的选择顺序是：

| 需求 | 首选方案 | 需要承担的协议 |
|---|---|---|
| 只是重新组合内置控件 | 普通组合函数 | 状态、身份和组件边界 |
| 需要自由绘图，但不需要自定义测量协议 | `CanvasWidget` | 绘制坐标与事件消费 |
| 需要自定义尺寸、布局、命中、焦点或语义 | 实现 `Widget` | measure/layout/draw/handle 完整协议 |
| 需要自定义多子容器、浮层或复杂手势路由 | 先组合现有容器；确有必要再做底层组件 | 子树布局、z 序、焦点、语义和事件拓扑 |

这个选择很重要。组合函数能自动继承内置控件已经做好的键盘、无障碍、主题、事件和缓存协议；直接自绘则意味着这些能力要由组件作者明确补齐。

本文先建立 CUI 的组件模型，再依次实现一个组合组件、一个画布组件和一个具备鼠标、键盘、焦点、无障碍与测试的完整控件。

## 一、先理解一个关键事实：Widget 不是业务状态容器

CUI 的声明式构建会反复产生新的 `Widget` 值。框架可能重建某条脏路径，也可能复用上一版干净子树。因此，自定义组件必须区分两类字段：

```text
可以放在 Widget 实例里                 应放在 State / Store / remembered value 里
───────────────────────────────────    ────────────────────────────────────────
构造参数、回调、样式                     业务选择、输入内容、展开状态
本次 layout 得到的 frame                 动画控制器、缓存控制器、派生状态图
由构造参数直接算出的只读值                跨重建仍要延续的手势或资源状态
```

`frame` 是一个合理的实例字段，因为它只是当前已提交组件的布局结果，供随后的 `draw` 和 `handle` 使用。计数、选中项或正在编辑的内容则不能依赖 Widget 实例寿命。

下面这种写法看似工作，实际上很危险：

```cangjie
class BadCounter <: Widget {
    private var count: Int64 = 0 // 错：下一次声明式重建可能得到全新实例
    // ...
}
```

正确方式是让组件接收 `State`、`Bindable` 或业务动作回调：

```cangjie
class GoodCounter <: Widget {
    private let count: Bindable<Int64>
    // ...
}
```

若状态只属于组件内部，则在声明式作用域中使用 `rememberState`，再把它传给实际控件。稳定控制器、格式化器、`Animator` 或 `DerivedState` 图使用 `remember`；资源的建立与释放使用 `mountEffect` 或 `lifecycleEffect`，不要塞进构造器或 `draw`。

## 二、第一档：优先写组合组件

大多数业务组件都不需要实现 `Widget`。一个调用内置控件并返回 `Unit` 的普通函数，就是声明式组件：

```cangjie
import cui.*

func CounterCard(title: String, count: Bindable<Int64>): Unit {
    Panel {
        HStack {
            VStack {
                Label(title).bold()
                Label("当前值：${count.get()}").muted()
            }.spacing(4.vp).hug()
            Spacer()
            Button("-", {=> count.update({value => max(Int64(0), value - 1)})})
            Button("+", {=> count.update({value => value + 1})}).role(ButtonRole.Primary)
        }.spacing(8.vp).hug()
    }.contentPadding(16.vp, 14.vp).hug()
}

main(): Unit {
    let app = DesktopApp(WindowSpec("组合组件", 520, 260))
    let count = State<Int64>(0)

    app.run {
        VStack {
            CounterCard("重试次数", count)
        }.padding(20.vp)
    }
}
```

这里已经具备完整的声明式能力：

- `count.get()` 在构建期形成状态依赖；
- `Button` 自带按压、键盘焦点和语义动作；
- `Bindable` 让组件既能接收普通 `State`，也能接收大型模型上的 `Binding` 投影；
- 组件没有复制业务事实，只通过传入的读写能力工作。

### 组合函数应该返回 Unit 还是 Widget

两种方式都能使用，但意图不同：

- 返回 `Unit`：表示函数负责向当前声明块发射一个或多个控件，最适合页面片段和复合业务组件；
- 返回 `Widget`：适合调用方还要对最终单个节点继续链式修饰，例如 `card(...).shadow(...)`。

若返回 `Widget`，函数体应明确只产生并返回一个最终节点。不要一边产生多个兄弟，一边把其中一个当成组件根返回，否则调用方看到的返回值与实际声明子树会不一致。

### 内部局部状态怎样保存

```cangjie
func ExpandableCard(id: String, title: String, body: () -> Unit): Unit {
    Keyed(id) {
        let expanded = rememberState<Bool>("expanded") {false}
        Panel {
            VStack {
                Button(if (expanded.value) {"收起 ${title}"} else {"展开 ${title}"}, {
                    => expanded.value = !expanded.value
                })
                if (expanded.value) {
                    body()
                }
            }.spacing(8.vp).hug()
        }.contentPadding(14.vp, 12.vp).hug()
    }
}
```

`Keyed(id)` 把局部状态放入稳定身份作用域。组件出现在可插入、删除或重排的列表中时，必须使用业务 id，而不是当前数组下标：

```cangjie
ForEach(tasks, key: {task => task.id}) {task =>
    ExpandableCard(task.id, task.title) {
        Label(task.description).wrap()
    }
}
```

位置身份适合固定结构；业务身份适合动态集合。把列表位置当身份，会让“第二行的展开状态”在第一行删除后错误地转移到原第三行。

## 三、第二档：自由绘图优先用 CanvasWidget

图表、示波器、画板或节点编辑器需要直接调用渲染器，但未必需要一套新的尺寸协议。此时 `CanvasWidget` 更轻：

```cangjie
import cui.*

func MarkerCanvas(): Unit {
    let markerX = rememberState<Float32>("marker-x") {120.0}
    let markerY = rememberState<Float32>("marker-y") {90.0}

    CanvasWidget(
        {
            renderer, frame =>
                renderer.strokeLine(
                    frame.x + 12.0,
                    frame.centerY(),
                    frame.right() - 12.0,
                    frame.centerY(),
                    Pen(width: 2.0, color: Color.rgb(80, 110, 160))
                )
                renderer.fillCircle(markerX.value, markerY.value, 7.0, Color.rgb(238, 106, 70))
        },
        onEvent: {
            event, frame =>
                match (event) {
                    case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                        if (frame.contains(x, y)) {
                            markerX.value = x
                            markerY.value = y
                            return true
                        }
                    case _ => ()
                }
                false
        }
    ).semantics(
        Semantics(label: "可点击的数据标记画布", role: SemanticsRole.Image),
        key: "marker-canvas"
    )
}
```

这段代码有三个容易忽略的细节。

第一，`frame` 使用的是窗口逻辑坐标，不是以 `(0, 0)` 开始的局部坐标。所有绘制和命中判断都应从传入矩形出发。

第二，`Renderer` 只属于当前绘制回调。不能把它保存到模型、交给后台线程或跨帧继续使用。

第三，只消费真正属于画布的事件。若回调对所有 `MouseDown`、`MouseUp` 都返回 `true`，画布后方或旁边的按钮可能永远收不到完整按压协议。

### 拖动手势要区分“结束内部状态”和“消费事件”

画笔拖出画布后松开，组件仍应结束已经开始的笔迹；但一个从未在画布开始的外部 `MouseUp` 不应被吞掉：

```cangjie
case UiEvent.MouseUp(MouseButton.Left, x, y) =>
    let wasDrawing = model.endStroke()
    if (wasDrawing || frame.contains(x, y)) {
        return true
    }
```

这条规则可以概括为：组件内部状态机必须闭合，事件所有权必须尽量小。

## 四、第三档：实现完整 Widget

当组件需要自己的首选尺寸、键盘焦点、精确命中或无障碍动作时，直接实现 `Widget`。

它只有四个必选方法：

```cangjie
public interface Widget {
    func measure(ctx: UiContext, available: Size): Size
    func layout(ctx: UiContext, rect: Rect): Unit
    func draw(ctx: UiContext): Unit
    func handle(ctx: UiContext, event: UiEvent): Bool
}
```

但“能编译”与“像内置控件一样完整”之间，还隔着身份、焦点、语义、绘制边界和事件消费等协议。下面实现一个五级评分控件。

## 五、完整实例：可访问的 LevelMeter

目标行为：

- 点击某一格设置 1～5 级；
- 左右、上下方向键调整；Home 清零，End 设为最大值；
- 可通过 Tab 聚焦，并绘制统一焦点环；
- 悬停时预览即将选择的等级；
- 向无障碍系统暴露 Slider 角色、当前值与增减动作；
- 组件值由外部 `Bindable<Int64>` 托管。

### 完整实现

```cangjie
import cui.*

private let LEVEL_COUNT: Int64 = 5
private let LEVEL_STEP: Float32 = 30.0
private let LEVEL_H: Float32 = 28.0
private let LEVEL_GAP: Float32 = 4.0

class LevelMeter <: Widget {
    private let label: String
    private let value: Bindable<Int64>
    private let id: String
    private var frame = Rect.zero()

    init(label: String, value: Bindable<Int64>, identity: String) {
        this.label = label
        this.value = value
        // 分配声明身份并登记到 Tab 焦点顺序；动态列表外层仍应使用 Keyed/ForEach。
        this.id = focusableControlIdentity("LevelMeter:${identity}")
        // 每个具体 Widget 构造器都要把自己发射到当前声明块，而且只发射一次。
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        let preferredW = Float32(LEVEL_COUNT) * LEVEL_STEP
        Size(min(available.w, preferredW), min(available.h, LEVEL_H))
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect

        // 自绘像素不会自动进入无障碍树；复杂控件在 layout 中登记边界和动作。
        ctx.registerSemantics(
            SemanticsNode(
                id,
                Semantics(
                    label: label,
                    role: SemanticsRole.Slider,
                    value: "${clampedValue()} / ${LEVEL_COUNT}",
                    hint: "使用方向键调整等级"
                ),
                rect,
                actions: [
                    SemanticsAction.Focus,
                    SemanticsAction.Increment,
                    SemanticsAction.Decrement
                ]
            ),
            perform: {
                action => match (action) {
                    case SemanticsAction.Focus =>
                        ctx.focus(id, viaKeyboard: true)
                        true
                    case SemanticsAction.Increment => setRelative(1)
                    case SemanticsAction.Decrement => setRelative(-1)
                    case _ => false
                }
            }
        )
    }

    public func draw(ctx: UiContext): Unit {
        let hovered = hoveredLevel(ctx)
        let shown = if (hovered > 0) {hovered} else {clampedValue()}

        for (index in 0..LEVEL_COUNT) {
            let box = levelRect(index)
            let level = index + 1
            let fill = if (level <= shown) {
                ctx.theme.accent
            } else {
                ctx.theme.field
            }
            ctx.renderer.fillRoundedRect(box, 6.0, fill)
        }

        if (ctx.showFocusRing(id)) {
            drawFocusRing(ctx, frame, 8.0)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        // 悬停只申请指针样式，不消费 MouseMove。
        claimHoverIfInside(ctx, event, frame, id, CursorShape.Interactive)

        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    let level = levelAt(x)
                    if (level > 0) {
                        ctx.focus(id)
                        value.value = level
                        return true
                    }
                }
            case UiEvent.KeyDown(Key.Left, _) => return adjustIfFocused(ctx, -1)
            case UiEvent.KeyDown(Key.Down, _) => return adjustIfFocused(ctx, -1)
            case UiEvent.KeyDown(Key.Right, _) => return adjustIfFocused(ctx, 1)
            case UiEvent.KeyDown(Key.Up, _) => return adjustIfFocused(ctx, 1)
            case UiEvent.KeyDown(Key.Home, _) => return setIfFocused(ctx, 0)
            case UiEvent.KeyDown(Key.End, _) => return setIfFocused(ctx, LEVEL_COUNT)
            case _ => ()
        }
        false
    }

    // 让 .enabled(false)、焦点遍历和默认 focus-ring 绘制边界识别本控件。
    public func focusableId(): ?String {
        Some(id)
    }

    // 只有在所有指针逻辑都严格受 frame 限制时才能这样声明。
    public func pointerEventScope(): PointerEventScope {
        PointerEventScope.LayoutBounds
    }

    private func levelRect(index: Int64): Rect {
        let step = actualStep()
        let x = frame.x + Float32(index) * step + LEVEL_GAP / 2.0
        Rect(x, frame.y + LEVEL_GAP / 2.0, max(0.0, step - LEVEL_GAP), max(0.0, frame.h - LEVEL_GAP))
    }

    private func levelAt(x: Float32): Int64 {
        if (x < frame.x || x >= frame.right()) {
            return 0
        }
        let step = actualStep()
        if (step <= 0.0) {
            return 0
        }
        let level = Int64((x - frame.x) / step) + 1
        min(LEVEL_COUNT, max(Int64(1), level))
    }

    // 父容器沿交叉轴拉伸时，绘制和命中都按实际 frame 均分，不使用另一套几何。
    private func actualStep(): Float32 {
        if (frame.w > 0.0) {frame.w / Float32(LEVEL_COUNT)} else {LEVEL_STEP}
    }

    private func hoveredLevel(ctx: UiContext): Int64 {
        if (!ctx.isHovered(id) || !frame.contains(ctx.mouseX, ctx.mouseY)) {
            return 0
        }
        levelAt(ctx.mouseX)
    }

    private func clampedValue(): Int64 {
        min(LEVEL_COUNT, max(Int64(0), value.get()))
    }

    private func setRelative(delta: Int64): Bool {
        value.value = min(LEVEL_COUNT, max(Int64(0), clampedValue() + delta))
        true
    }

    private func adjustIfFocused(ctx: UiContext, delta: Int64): Bool {
        if (!ctx.hasFocus(id)) {
            return false
        }
        setRelative(delta)
    }

    private func setIfFocused(ctx: UiContext, next: Int64): Bool {
        if (!ctx.hasFocus(id)) {
            return false
        }
        value.value = next
        true
    }
}
```

### 使用方式

```cangjie
main(): Unit {
    let app = DesktopApp(WindowSpec("自定义评分控件", 520, 260))
    let quality = State<Int64>(3)

    app.run {
        VStack {
            Label("服务质量").bold()
            LevelMeter("服务质量", quality, "service-quality")
            Label("已选择 ${quality.value} 级").muted()
        }.spacing(10.vp).padding(20.vp).hug()
    }
}
```

这里使用受控组件模式：`LevelMeter` 只解释交互并写回 `Bindable`，真正的值属于调用方。调用方可以传 `State`，也可以传大型模型的 `Binding` 投影；组件不需要知道模型长什么样。

## 六、四个阶段分别应该做什么

### 1. measure：回答“我想要多大”

`measure(ctx, available)` 返回首选尺寸，不是最终位置。常见规则：

- 固定尺寸也要尽量裁到 `available`；
- 文本测量使用当前 `ctx.renderer` 和 `ctx.resolve(...)`，不要缓存一个永久 DPI 结果；
- 不要在这里写 State、启动任务或注册外部资源；
- 容器需要在这里测量孩子，但最终坐标留到 layout；
- 在 measure 中读取 State，会把该 State 连接到 Measure 阶段，变化时测量缓存失效。

如果状态只改变颜色，却在 `measure` 中被读取，框架只能保守地重新测量。把读取推迟到 `draw`，就可以只失效 Paint。

### 2. layout：接受最终矩形并发布几何

`layout(ctx, rect)` 中通常做三件事：

1. 保存 `frame`；
2. 若有孩子，为每个孩子分配最终矩形；
3. 注册与几何相关的 semantics、overlay 或输入锚点。

布局可能因窗口变化、字体环境变化或状态失效而重试，所以它必须是可重放的。不要在 layout 中做“只执行一次”的资源初始化。

`LevelMeter` 在 layout 中读取当前值生成无障碍 value，因此评分变化也会使布局语义片段更新。这个范围比纯绘制略粗，但能保证辅助技术得到同步值；计算应保持便宜。

### 3. draw：只描述本帧像素

`draw(ctx)` 应把已提交状态画出来：

- 使用 layout 保存的 `frame`；
- 绘制坐标是逻辑绝对坐标；
- 内容需要裁剪时正确配对 `pushClip` / `popClip`；
- 不要在 draw 中写业务 State，否则可能形成“绘制 → 写状态 → 下一帧 → 再绘制”的循环；
- 只在尚未静止的动画中请求下一帧。

State 在 draw 中读取时，CUI 会把依赖登记到 Paint 阶段。只变颜色或进度的控件由此可以跳过 build、measure 和 layout。

### 4. handle：只消费属于自己的事件

`handle` 的返回值不是“我看见了事件”，而是“事件已经由我处理完，不应继续交给身后的节点”。

推荐顺序是：

```text
更新 hover 申请
  → 判断事件种类
  → 做命中测试或焦点检查
  → 调用统一业务动作
  → 只有真正处理时返回 true
```

后声明、绘制在上方的组件通常先收到输入。一旦它返回 `true`，后方组件便不会再收到该事件。因此无条件消费鼠标事件是自定义控件最常见的交互缺陷之一。

## 七、焦点、悬停、按压与拖拽不要各造一套状态

CUI 已经在 `UiContext` 中维护通用交互状态：

- `focusableControlIdentity`：构建期分配身份并登记 Tab 顺序；
- `ctx.focus` / `ctx.hasFocus` / `ctx.showFocusRing`：焦点和 focus-visible；
- `claimHoverIfInside` / `ctx.isHovered`：悬停仲裁与指针形状；
- `ctx.press` / `ctx.isPressed` / `ctx.clearPress`：按压所有权；
- `ctx.beginDrag` / `ctx.isDragging` / `ctx.dragGrab` / `ctx.clearDrag`：跨帧拖拽所有权。

这些状态放在应用级上下文而不是 Widget 字段中，是因为 Widget 可能在按下与移动之间被重建。若把 `dragging = true` 存在控件实例里，下一次事件可能到达一个全新的 `dragging = false` 实例。

对简单点击，最好复用内置 `Button`；确需自写时，至少保证：

- 按下时命中才取得焦点或按压所有权；
- 松开时检查是否仍属于同一手势；
- 键盘 Enter/Space 与鼠标调用同一个动作；
- 焦点环只在 `showFocusRing(id)` 时绘制，而不是任何焦点都显示；
- `focusableId()` 返回同一个 id，使 `.enabled(false)` 能把控件移出 Tab 顺序。

## 八、身份：固定结构靠位置，动态结构靠业务 key

`focusableControlIdentity("LevelMeter:quality")` 的基名只是身份的一部分。框架还会结合当前声明作用域和同名出现顺序，避免两个相同控件抢占同一个焦点或按压槽。

这在结构稳定时足够。若组件位于可重排列表，应在外层使用稳定 key：

```cangjie
ForEach(metrics, key: {metric => metric.id}) {metric =>
    LevelMeter(metric.title, metric.level, metric.id)
}
```

需要避免的 key 包括：

- 当前数组下标；
- 会随标题翻译而变化的显示文本；
- 每次构建重新生成的随机值；
- 不同兄弟之间可能重复的业务字段。

一个好 key 应稳定、非空、同级唯一，并且表达“这还是不是原来那个业务对象”。

## 九、绘制超出布局边界时必须声明 PaintOutset

阴影、光晕、粗描边和拖拽预览经常画到 `frame` 外。如果不声明，滚动裁剪、局部 damage 或 retained 命令跳过可能把外溢部分切掉。

可在组件上覆盖：

```cangjie
public func paintOutset(): PaintOutset {
    PaintOutset.all(10.0)
}
```

也可以由调用方链式声明：

```cangjie
GlowChart(model).paintOutset(10.0)
```

返回值必须保守覆盖真实最大外溢，但也不要无限放大。声明过小会产生残影或裁剪，声明过大会扩大 damage 和绘制候选区域。

可聚焦叶节点的默认实现已经为标准焦点环预留 4 个逻辑像素；只有自定义效果超出这个范围时才需额外覆盖。

## 十、PointerEventScope 是性能承诺，不是绘制裁剪

自定义 Widget 默认返回 `PointerEventScope.Unbounded`。这表示它可能观察布局矩形外的指针事件，父容器不能仅按 bounds 把它剪掉。

若组件的每一条指针逻辑都严格检查同一个布局矩形，可以返回 `LayoutBounds`，让多子容器建立空间索引：

```cangjie
public func pointerEventScope(): PointerEventScope {
    PointerEventScope.LayoutBounds
}
```

或对现有节点调用：

```cangjie
CustomLeaf(...).pointerEventsWithinLayout()
```

错误声明会造成真实事件丢失。例如组件希望在矩形外收到全局松开、跨边界手势协调或弹出层命中，却声称 `LayoutBounds`，父容器便可能合法地跳过它。活动拖拽捕获会走保守路径，但不能用它掩盖错误契约。

## 十一、动画与时间：只在需要时续帧

CUI 的桌面循环会在静止时停止渲染。自定义动画不能假设 `draw` 永远以刷新率自动调用。

最简单的方式是使用 `Animator`、`Spring` 或 `Pulse`，在 `draw` 中取得当帧值；它们未静止时会请求下一帧：

```cangjie
public func draw(ctx: UiContext): Unit {
    let x = animator.animate(ctx, target: targetX)
    ctx.renderer.fillCircle(x, frame.centerY(), 8.0, ctx.theme.accent)
}
```

自定义定时逻辑使用：

```cangjie
ctx.requestFrame()                    // 尽快再绘制一帧
ctx.requestFrameAt(nextDeadlineMs)    // 到绝对时钟 deadline 再唤醒
```

注意：

- 动画控制器要放在模型或 `remember` 中，不能每次构建重新创建；
- 动画静止后不要继续无条件 `requestFrame()`；
- `FrameHandler` / `subscribeFrame` 适合确实需要逐帧回调的组件，但持续订阅意味着窗口不能空闲归零；
- 倒计时、光标闪烁这类稀疏变化优先使用 deadline，而不是烧满所有刷新帧。

## 十二、无障碍：像素不会自动变成控件

自绘按钮即使看起来像按钮，读屏也只会看到一片没有意义的像素。自定义组件至少要考虑：

- 稳定 id；
- `SemanticsRole`；
- 可读 label、value、hint；
- enabled、selected、checked 等状态；
- Activate、Focus、Increment、Decrement、SetValue 等动作；
- 与视觉控件一致的 bounds。

纯展示图表可用 `.semantics(...)` 修饰器：

```cangjie
CanvasWidget({renderer, frame => drawTrend(renderer, frame)})
    .semantics(
        Semantics(label: "最近七天订单趋势", role: SemanticsRole.Image),
        key: "orders-trend"
    )
```

交互控件则像 `LevelMeter` 一样，在 layout 中使用 `ctx.registerSemantics`，把无障碍动作路由到与鼠标、键盘相同的状态更新函数。不要为读屏再复制一套业务逻辑。

## 十三、需要子组件时，优先组合而不是手写容器

自定义多子容器比自定义叶控件复杂得多。除了对子组件调用四阶段方法，还要处理：

- 构建块如何收集孩子；
- measure 约束怎样向下传递；
- layout 顺序与最终几何；
- draw z 序与 clip；
- handle 的逆序派发和消费停止；
- 所有子树焦点 id 的转发；
- `paintOutset` 的聚合；
- `pointerEventScope` 的保守合成；
- 隐藏节点、脱离布局节点和 overlay；
- retained 布局提交中的语义与事件拓扑。

因此，业务项目要做“带标题和内容的卡片”“带前后缀的输入行”“两栏检查器”，应使用 `Panel`、`VStack`、`HStack`、`ZStack`、`Grid`、`FlowRow`、`Portal` 等现有容器组合。

只有新的布局算法本身就是产品能力，例如时间轴避让、节点图自动布局或专用工业画布，才值得实现底层容器。此时应把它当成框架级组件开发，而不是普通页面封装，并为每个阶段单独测试。

## 十四、如何测试自定义 Widget

不要只截图。视觉正确不代表命中、焦点、键盘、语义和按需帧都正确。

`WidgetTestHost` 可以无头运行与真实桌面相同的构建、布局、事件、状态稳定和绘制协议。下面的测试覆盖指针、键盘和无障碍动作：

```cangjie
@Test
func levelMeterSupportsPointerKeyboardAndSemantics(): Unit {
    let host = WidgetTestHost()
    let value = State<Int64>(1)
    let rect = Rect(0.0, 0.0, 180.0, 40.0)
    let body: () -> Unit = {=> LevelMeter("质量", value, "quality")}

    // 点击第三格后取得焦点，再由右方向键加一。
    let _ = host.frame(rect, events: [
        UiEvent.MouseDown(MouseButton.Left, 90.0, 20.0),
        UiEvent.KeyDown(Key.Right, false)
    ], body: body)
    @Expect(value.value, Int64(4))

    // 无障碍动作复用同一套增减逻辑。
    let nodes = host.context.semanticsSnapshot()
    @Expect(nodes.size, Int64(1))
    @Expect(host.context.performSemanticsAction(nodes[0].id, SemanticsAction.Decrement))
    @Expect(value.value, Int64(3))
}
```

建议至少覆盖下面这些类别：

1. `measure` 在很小、正常和很大 available 下都满足约束；
2. layout 不在原点时，绘制与命中仍使用正确绝对坐标；
3. 内部与外部指针事件的返回值；
4. 按下后拖出、拖入、松开的手势闭合；
5. Tab、Shift+Tab、Enter、Space、方向键路径；
6. `.enabled(false)`、`.visible(false)` 后焦点和事件行为；
7. semantics 的 label、role、value、bounds 与动作；
8. State 改变后同一帧绘制的是新值；
9. 动画静止后没有残留帧请求；
10. retained 增量模式与强制全量模式的可见结果一致。

## 十五、最常见的十个错误

### 1. 忘记 emit(this)

实例虽然构造成功，却没有进入当前声明块，最终界面里看不到它。每个具体 Widget 构造器只调用一次 `emit(this)`。

### 2. 把业务状态放实例字段

一次重建后状态回到初值。实例字段只保存输入和当前布局缓存，业务事实进入 State/Store。

### 3. measure 无视 available

组件返回无限或超约束尺寸，父布局只能溢出、裁剪或产生错误滚动范围。

### 4. 在 draw 中修改 State

绘制成为状态生产者，容易形成连续无效帧甚至稳定化循环。

### 5. 所有鼠标事件都返回 true

后方兄弟或相邻控件拿不到完整事件协议，最典型现象是按钮按下有反馈但永远不触发。

### 6. 只支持鼠标

控件无法由 Tab、键盘或辅助技术使用。交互组件应把多种输入映射到同一业务动作。

### 7. 自绘文字却不提供 Semantics

视觉上有标签，读屏看到的仍是空白。

### 8. 用数组下标作为动态列表身份

重排后局部状态、焦点或动画跟错业务对象。

### 9. 绘制外溢却不声明 paintOutset

阴影、光晕或焦点环在局部刷新和滚动裁剪下残缺。

### 10. 每帧永久 requestFrame

静态窗口失去按需渲染优势，CPU/GPU 在没有可见变化时仍持续工作。

## 十六、一份实用的组件评审清单

提交一个自定义组件前，可以逐项回答：

### 状态与身份

- 跨重建数据是否全部在 State、Store、remember 或 UiContext 协议中？
- 动态集合是否使用稳定业务 key？
- 控件 id 是否稳定且同级唯一？

### 布局与绘制

- measure 是否尊重 available？
- draw 和 handle 是否使用同一个 layout frame？
- State 是否在最晚的正确阶段读取？
- clip 是否成对？绘制外溢是否声明 PaintOutset？

### 事件与焦点

- 只消费真正处理的事件吗？
- 拖出边界后，手势状态能否正常结束？
- 是否支持 Tab 和合理的键盘操作？
- `.enabled(false)` 后是否离开焦点顺序并停止响应？

### 无障碍

- 自绘内容是否有正确角色、标签、值和边界？
- 无障碍动作是否复用同一个业务动作？
- 只读、禁用、选中和选中值是否准确？

### 性能与生命周期

- 是否误把颜色变化升级成 build/measure 依赖？
- 静止后是否停止请求帧？
- 资源是否由 effect 管理，而不是构造器或 draw？
- 是否只在能证明边界时声明 `LayoutBounds`？

## 结语：自定义组件首先是一份协议实现

CUI 把扩展入口做得很小：四个必选方法和一次 `emit(this)`，就能让应用定义的新类型进入声明式布局。但一个成熟控件的完整性不只体现在“画出来了”。

真正可靠的自定义组件还应同时满足：

```text
状态可持续
  + 身份稳定
  + 测量受约束
  + 绘制与命中一致
  + 事件所有权清楚
  + 键盘与焦点可达
  + 无障碍动作完整
  + 动画按需续帧
  + 增量阶段读取准确
```

最实用的原则是：能组合就组合，需要自由像素时用 `CanvasWidget`，只有当尺寸、布局或交互协议本身需要创新时，才实现完整 `Widget`。这样既能保留 CUI 的声明式表达力，也不会无意中放弃内置控件已经提供的正确性与增量渲染能力。
