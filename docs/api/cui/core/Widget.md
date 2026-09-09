[cui](../../index.md) › [cui.core](index.md) › Widget

# Widget

位于 `cui.core` 包的公开接口

所有组件共同实现的协议。自定义组件实现 `measure`、`layout`、`draw` 和 `handle` 四个方法后，就能使用内建布局、修饰器和事件系统。需要焦点、无障碍、动画或容器能力时，再按需实现可选协议或调用 `UiContext` 接口。

## 声明

```cangjie
public interface Widget
```

## 说明

**更新。** CUI 根据 `State` 的实际读取记录，只重新执行受影响的声明和阶段。空闲窗口不会持续构建。组件实例不应保存跨构建业务状态；这类数据放进 [`State`](State.md)、Binding 或 Store。框架会自动缓存适合保留的声明和绘制工作，普通组件无需手工使用 [`RetainedSubtree`](RetainedSubtree.md)。逐帧逻辑通过 [`FrameHandler`](FrameHandler.md) 或 [`subscribeFrame`](functions.md#subscribeframe) 登记，不通过 `handle` 广播。

**声明。** 具体组件的构造函数调用一次 [`emit(this)`](functions.md#emit)，把自己加入当前构建块。块外构造时 `emit` 不做任何事；已有组件可以在块内通过 `emit(widget)` 显式放置。

**修饰器。** `width`、`padding`、`background` 等方法返回包装后的组件。每一步都会包住前面的结果，因此顺序会改变尺寸和
绘制范围：先 `padding` 再 `background`，背景包含内边距；顺序相反时，背景只覆盖原内容区域。

**可选协议。** [`isFlexible`](#isflexible) 和 [`flexWeight`](#flexweight) 控制剩余空间分配；[`acceptsStretch`](#acceptsstretch) 控制交叉轴拉伸；[`participatesInLayout`](#participatesinlayout) 决定是否占位；[`focusableId`](#focusableid) 和 [`focusableIds`](#focusableids) 提供 Tab 顺序。这些方法都有默认实现。

**环境变化。** 窗口缩放、字体缩放、主题、渲染器或字体注册变化时，框架会自动使相关测量、布局和绘制缓存失效。自定义组件不需要订阅这些变化或清理框架缓存。`measure` 和 `layout` 可能重试，因此不得在其中执行一次性副作用。

## 示例

```cangjie verify
package docexample

import cui.*

// 最小自定义组件：固定尺寸的点击计数格
class TapCounter <: Widget {
    private let taps: State<Int64>
    private var frame = Rect.zero()

    init(taps: State<Int64>) {
        this.taps = taps
        emit(this) // 登记进外层构建块；块外构造时是无操作
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(88.0, 32.0)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect // 记住框架，供 draw 与命中测试使用
    }

    public func draw(ctx: UiContext): Unit {
        ctx.renderer.fill(frame, ctx.theme.accent)
    }

    public func handle(_: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    taps.value = taps.value + 1
                    return true
                }
            case _ => ()
        }
        false
    }
}

main(): Unit {
    // 无头上下文驱动一帧：测量 → 布局 → 绘制 → 事件
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let taps = State<Int64>(0)
    let counter = TapCounter(taps)
    let size = counter.measure(ctx, Size(400.0, 300.0))
    counter.layout(ctx, Rect(0.0, 0.0, size.w, size.h))
    counter.draw(ctx)
    let consumed = counter.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 10.0, 10.0))
    println("事件已消费 ${consumed}，累计点击 ${taps.value} 次")
    // 输出: 事件已消费 true，累计点击 1 次
}
```

## 成员概览

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(ctx: UiContext, available: Size)`](#measure) | 在 `available` 约束内计算并返回组件的首选尺寸。 |
| [`layout(ctx: UiContext, rect: Rect)`](#layout) | 把最终布局矩形 `rect` 分配给组件。 |
| [`draw(ctx: UiContext)`](#draw) | 用 `ctx` 的渲染器绘制组件。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 处理一条输入事件并返回是否已消费。 |
| [`pointerEventScope()`](#pointereventscope) | 声明子树是否可能观察布局矩形之外的指针事件。 |
| [`paintOutset()`](#paintoutset) | 声明布局矩形之外的保守绘制域。 |
| [`isFlexible()`](#isflexible) | 报告组件是否参与所在栈的剩余空间分配。 |
| [`flexWeight()`](#flexweight) | 报告弹性组件分享剩余空间的相对权重。 |
| [`acceptsStretch(_: Axis)`](#acceptsstretch) | 报告栈可否沿指定轴把组件拉伸到超过测量尺寸。 |
| [`participatesInLayout()`](#participatesinlayout) | 报告该节点是否在父布局中占据位置。 |
| [`needsDetachedLayout()`](#needsdetachedlayout) | 不占版面时是否仍需一次零矩形 layout 以登记 Portal 类副作用。 |
| [`focusableId()`](#focusableid) | 返回组件构建期注册的键盘焦点 id，不可聚焦时为 `None`。 |
| [`focusableIds()`](#focusableids) | 返回组件子树按声明顺序注册的全部键盘焦点 id。 |
| [`width(...)`](#width) | 把组件约束到恰好 `value` 宽。 |
| [`height(...)`](#height) | 把组件约束到恰好 `value` 高。 |
| [`minWidth(...)`](#minwidth) | 阻止组件测量得比 `value` 更窄。 |
| [`maxWidth(...)`](#maxwidth) | 阻止组件测量得比 `value` 更宽。 |
| [`minHeight(...)`](#minheight) | 阻止组件测量得比 `value` 更矮。 |
| [`maxHeight(...)`](#maxheight) | 阻止组件测量得比 `value` 更高。 |
| [`fillWidth()`](#fillwidth) | 让组件占满父容器提供的全部宽度。 |
| [`fillHeight()`](#fillheight) | 让组件占满父容器提供的全部高度。 |
| [`padding(...)`](#padding) | 在组件四周添加内边距。 |
| [`background(...)`](#background) | 在组件身后垫一层实色圆角背景。 |
| [`surface(style: SurfaceStyle)`](#surface) | 在组件身后绘制一套完整的表面样式。 |
| [`gradientBackground(...)`](#gradientbackground) | 在组件身后填充两色线性渐变背景。 |
| [`shadow(...)`](#shadow) | 在组件身后投下柔和阴影。 |
| [`paintOutset(...)`](#paintoutset) | 为自定义绘制声明等边或非对称 overflow。 |
| [`border(...)`](#border) | 在组件的填充与内容之上描一圈圆角边框。 |
| [`dashedBorder(...)`](#dashedborder) | 在组件的填充与内容之上描一圈虚线圆角边框。 |
| [`flex(...)`](#flex) | 让组件按权重分享所在栈的剩余空间。 |
| [`visible(isVisible: Bool)`](#visible) | 控制组件是否参与布局、绘制与事件派发。 |
| [`enabled(isEnabled: Bool)`](#enabled) | 保留组件的布局与绘制、按 `isEnabled` 屏蔽其输入。 |
| [`semantics(properties: Semantics, ...)`](#semantics) | 为子树添加平台无关的无障碍属性。 |
| [`modifier(value: Modifier)`](#modifier) | 应用一个可复用的修饰器组合。 |
| [`pointerEventsWithinLayout()`](#pointereventswithinlayout) | 证明自定义子树的指针处理局限在布局矩形内，以启用空间剪枝。 |

## 方法

### measure

在 `available` 约束内计算并返回组件的首选尺寸。每帧由宿主或父容器在布局前调用；容器在此递归测量子组件，文本组件在此量宽与换行。

```cangjie
func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 每帧服务枢纽，提供渲染器、主题与单位解析。
- `available`: `Size` — 父容器提供的可用空间，逻辑像素。

**返回值** `Size` — 首选尺寸，逻辑像素；惯例上各实现把结果限制在 `available` 之内。

### layout

把最终布局矩形 `rect` 分配给组件。组件在这里记下位置，供 `draw` 绘制和 `handle` 判断指针是否落在控件内；容器也在这里放置子组件。每帧在测量之后调用。

```cangjie
func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 每帧服务枢纽。
- `rect`: `Rect` — 分配给组件的框架，逻辑像素。

### draw

用 `ctx` 的渲染器绘制组件。每帧在布局之后调用；无头渲染器下所有绘制都是无操作，布局与事件逻辑照常运转。

```cangjie
func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 持有渲染器与主题。

### handle

处理一条输入事件并返回是否已消费。容器通常按声明逆序派发，后声明、绘制在上层的组件先收到；组件返回 `true` 后，事件不再交给后方节点。逐帧回调由 `FrameHandler` 或 `subscribeFrame` 单独登记，不应依赖 `handle` 广播。

```cangjie
func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 焦点、悬停、按压、拖拽等交互协议的入口。
- `event`: `UiEvent` — 本条输入事件。

**返回值** `Bool` — `true` 表示事件已消费，停止继续派发。

### pointerEventScope

声明子树是否可能观察父容器分配矩形之外的指针事件。默认 `Unbounded` 采用保守路由；只有全部后代处理器都检查同一布局矩形时，才返回 `LayoutBounds`。父容器可以据此跳过明显不相交的子树。活动按压或拖拽仍会回到手势所有者。

```cangjie
func pointerEventScope(): PointerEventScope
```

**返回值** [`PointerEventScope`](PointerEventScope.md) — 默认实现返回 `Unbounded`。

### paintOutset

返回组件在布局矩形四边之外可能绘制的最大距离。默认非焦点组件为零；可聚焦组件会为标准焦点环预留空间。滚动裁剪和局部重绘使用该范围，避免阴影、光晕或粗描边被截断。

```cangjie
func paintOutset(): PaintOutset
```

自定义 Canvas/特效也可用 fluent wrapper 声明，不改变测量尺寸：

```cangjie
func paintOutset(value: Float32): Widget
func paintOutset(value: PaintOutset): Widget
```

### isFlexible

报告组件是否参与所在栈的剩余空间分配。默认 `false`——组件按测量尺寸贴合内容；弹性组件改为分得剩余空间的一份，用 [`Flexible`](Flexible.md) 包装或 [`flex`](#flex) 修饰器开启。

```cangjie
func isFlexible(): Bool
```

**返回值** `Bool` — 默认实现返回 `false`。

### flexWeight

报告弹性组件分享剩余空间的相对权重。仅当 `isFlexible()` 为 `true` 时被读取，剩余空间按各弹性子组件的权重占比分配。

```cangjie
func flexWeight(): Float32
```

**返回值** `Float32` — 默认实现返回 `1.0`。

### acceptsStretch

报告栈可否沿指定轴把组件拉伸到超过测量尺寸。[`CrossAxisAlignment`](CrossAxisAlignment.md) 的 `Stretch` 与 [`ZStack`](ZStack.md) 据此决定填满还是按测量尺寸放置；`width`/`maxWidth`（及高度对应）修饰器在被约束的轴上代答 `false`。

```cangjie
func acceptsStretch(_: Axis): Bool
```

**参数**

- `_`: [`Axis`](Axis.md) — 被询问的轴；默认实现不区分轴。

**返回值** `Bool` — 默认实现返回 `true`。

### participatesInLayout

报告该节点是否在父布局中占据位置。返回 `false` 的节点既不占位也不计入栈的间距——`visible(false)` 的包装节点与 Toast 通知层这类画在树外、不占版面的组件属于此类。

```cangjie
func participatesInLayout(): Bool
```

**返回值** `Bool` — 默认实现返回 `true`。

### needsDetachedLayout

当 `participatesInLayout()` 为 `false` 时，是否仍需父容器调用一次 `layout(ctx, Rect.zero())`。默认 `false`；[`Portal`](Portal.md) 返回 `true`，用 placement 自行计算绝对矩形并登记浮层。透明包装器必须转发该值，`visible(false)` 则阻断它。

```cangjie
func needsDetachedLayout(): Bool
```

**返回值** `Bool` — 默认实现返回 `false`。

### focusableId

返回组件构建期注册的键盘焦点 id，不可聚焦时为 `None`。单子包装器转发子组件的 id；多控件容器返回 `None`，它们的焦点项经 [`focusableIds`](#focusableids) 汇总。

```cangjie
func focusableId(): ?String
```

**返回值** `?String` — 默认实现返回 `None`。

### focusableIds

返回组件子树按声明顺序注册的全部键盘焦点 id。默认实现由 [`focusableId`](#focusableid) 派生（0 或 1 个），容器拼接各子组件的列表；`visible(false)` 与 `enabled(false)` 用它把整棵子树移出焦点遍历。

```cangjie
func focusableIds(): Array<String>
```

**返回值** `Array<String>` — 声明顺序的焦点 id 列表，可为空。

### width

把组件约束到恰好 `value` 宽。测量与布局仍受父容器可用宽度限制；被约束的水平轴对栈报告拒绝拉伸。

```cangjie
func width(value: Length): Widget
```

```cangjie
func width(value: Float32): Widget
```

**参数**

- `value`: [`Length`](Length.md) 或 `Float32` — 目标宽度；`Float32` 重载按虚拟像素解释，解析结果限制在非负。

**返回值** `Widget` — 包装后的新节点，供继续链式调用。

### height

把组件约束到恰好 `value` 高。测量与布局仍受父容器可用高度限制；被约束的垂直轴对栈报告拒绝拉伸。

```cangjie
func height(value: Length): Widget
```

```cangjie
func height(value: Float32): Widget
```

**参数**

- `value`: [`Length`](Length.md) 或 `Float32` — 目标高度；`Float32` 重载按虚拟像素解释，解析结果限制在非负。

**返回值** `Widget` — 包装后的新节点，供继续链式调用。

### minWidth

阻止组件测量得比 `value` 更窄。下限仍不超过可用宽度，组件可以比 `value` 更宽。

```cangjie
func minWidth(value: Length): Widget
```

```cangjie
func minWidth(value: Float32): Widget
```

**参数**

- `value`: [`Length`](Length.md) 或 `Float32` — 宽度下限；`Float32` 重载按虚拟像素解释。

**返回值** `Widget` — 包装后的新节点，供继续链式调用。

### maxWidth

阻止组件测量得比 `value` 更宽。上限同时约束子组件的测量输入；被约束的水平轴对栈报告拒绝拉伸。

```cangjie
func maxWidth(value: Length): Widget
```

```cangjie
func maxWidth(value: Float32): Widget
```

**参数**

- `value`: [`Length`](Length.md) 或 `Float32` — 宽度上限；`Float32` 重载按虚拟像素解释。

**返回值** `Widget` — 包装后的新节点，供继续链式调用。

### minHeight

阻止组件测量得比 `value` 更矮。下限仍不超过可用高度，组件可以比 `value` 更高。

```cangjie
func minHeight(value: Length): Widget
```

```cangjie
func minHeight(value: Float32): Widget
```

**参数**

- `value`: [`Length`](Length.md) 或 `Float32` — 高度下限；`Float32` 重载按虚拟像素解释。

**返回值** `Widget` — 包装后的新节点，供继续链式调用。

### maxHeight

阻止组件测量得比 `value` 更高。上限同时约束子组件的测量输入；被约束的垂直轴对栈报告拒绝拉伸。

```cangjie
func maxHeight(value: Length): Widget
```

```cangjie
func maxHeight(value: Float32): Widget
```

**参数**

- `value`: [`Length`](Length.md) 或 `Float32` — 高度上限；`Float32` 重载按虚拟像素解释。

**返回值** `Widget` — 包装后的新节点，供继续链式调用。

### fillWidth

让组件占满父容器提供的全部宽度。测量直接报告可用宽度，水平轴主动接受拉伸。

```cangjie
func fillWidth(): Widget
```

**返回值** `Widget` — 包装后的新节点，供继续链式调用。

### fillHeight

让组件占满父容器提供的全部高度。测量直接报告可用高度，垂直轴主动接受拉伸。

```cangjie
func fillHeight(): Widget
```

**返回值** `Widget` — 包装后的新节点，供继续链式调用。

### padding

在组件四周添加内边距。等边、水平/垂直、四边独立三种形态各有 [`Length`](Length.md) 与 `Float32`（虚拟像素）两个重载；内边距计入组件的测量尺寸，解析时每边限制在非负。修饰链顺序敏感：`.background` 写在 `.padding` 之后才会连边距一起着色。

```cangjie
func padding(all: Length): Widget
```

```cangjie
func padding(all: Float32): Widget
```

```cangjie
func padding(horizontal: Length, vertical: Length): Widget
```

```cangjie
func padding(horizontal: Float32, vertical: Float32): Widget
```

```cangjie
func padding(left: Length, top: Length, right: Length, bottom: Length): Widget
```

```cangjie
func padding(left: Float32, top: Float32, right: Float32, bottom: Float32): Widget
```

**参数**

- `all`: `Length` / `Float32` — 同时应用到四边的间距。
- `horizontal`、`vertical`: `Length` / `Float32` — 左右两边与上下两边的间距。
- `left`、`top`、`right`、`bottom`: `Length` / `Float32` — 各边间距。

**返回值** `Widget` — 包装后的新节点，供继续链式调用。

### background

在组件身后垫一层实色圆角背景。单参数重载绘制无圆角的实色面；`radius` 重载指定统一圆角（`Float32` 为虚拟像素，解析后限制在非负）；`corners!` 重载给四角独立半径（见 [`Corners`](Corners.md)），用于聊天气泡、上圆角标签页与贴边面板。背景画在子组件之前，垫在内容底层。

```cangjie
func background(color: Color): Widget
```

```cangjie
func background(color: Color, radius: Length): Widget
```

```cangjie
func background(color: Color, radius: Float32): Widget
```

```cangjie
func background(color: Color, corners!: Corners): Widget
```

**参数**

- `color`: `Color` — 背景填充色。
- `radius`: [`Length`](Length.md) 或 `Float32` — 统一圆角半径，`Float32` 按虚拟像素。
- `corners!`: [`Corners`](Corners.md) — 四角独立的圆角半径，虚拟像素。

**返回值** `Widget` — 包装后的新节点，供继续链式调用。

### surface

在组件身后绘制一套完整的表面样式。`SurfaceStyle` 同时包含填充、边框、圆角与阴影，[`Theme`](Theme.md) 的 `panelSurface()`/`buttonSurface(role)` 等预设都返回此类型。需要整套外观时使用它；只需背景色时使用 [`background`](#background)。

```cangjie
func surface(style: SurfaceStyle): Widget
```

**参数**

- `style`: `SurfaceStyle` — 要绘制的完整表面描述。

**返回值** `Widget` — 包装后的新节点，供继续链式调用。

### gradientBackground

在组件身后填充两色线性渐变背景。方向与两端颜色由 [`Gradient`](Gradient.md) 描述；`radius` 重载附加统一圆角（`Float32` 为虚拟像素），无 `radius` 的重载按直角绘制。

```cangjie
func gradientBackground(gradient: Gradient): Widget
```

```cangjie
func gradientBackground(gradient: Gradient, radius: Length): Widget
```

```cangjie
func gradientBackground(gradient: Gradient, radius: Float32): Widget
```

**参数**

- `gradient`: [`Gradient`](Gradient.md) — 两色线性渐变的起止颜色与方向。
- `radius`: [`Length`](Length.md) 或 `Float32` — 圆角半径，`Float32` 按虚拟像素。

**返回值** `Widget` — 包装后的新节点，供继续链式调用。

### shadow

在组件身后投下柔和阴影。光晕画在子组件之前（垫在其后），所以要接在圆角 `background` 之后链入，并把 `radius!` 设成相同的圆角让阴影贴角。数组重载按数组顺序绘制多层（先画的最深），[`Shadow`](Shadow.md) 的 `keyAmbient(level)` 提供 Material 式"方向光 + 环境光"双层组合。

```cangjie
func shadow(value: Shadow): Widget
```

```cangjie
func shadow(value: Shadow, radius!: Length): Widget
```

```cangjie
func shadow(value: Shadow, radius!: Float32): Widget
```

```cangjie
func shadow(layers: Array<Shadow>): Widget
```

```cangjie
func shadow(layers: Array<Shadow>, radius!: Length): Widget
```

```cangjie
func shadow(layers: Array<Shadow>, radius!: Float32): Widget
```

阴影 modifier 会从 offset、blur 与 spread 自动推导非对称 [`PaintOutset`](PaintOutset.md)，无需应用手写余量。

**参数**

- `value`: [`Shadow`](Shadow.md) — 单层阴影描述（偏移、模糊、扩散、颜色）。
- `layers`: `Array<Shadow>` — 多层阴影，按数组顺序绘制，先画的最深。
- `radius!`: [`Length`](Length.md) 或 `Float32` — 阴影跟随的圆角半径，`Float32` 按虚拟像素；不带 `radius!` 的重载按直角绘制。

**返回值** `Widget` — 包装后的新节点，供继续链式调用。

### border

在组件的填充与内容之上描一圈圆角边框。单参数重载线宽 1 逻辑像素；`width!` 限制在非负；`radius!` 指定圆角（`Float32` 为虚拟像素）。描边中心线落在框架边缘向内半个线宽处；完全透明的颜色或零线宽直接跳过绘制。

```cangjie
func border(color: Color): Widget
```

```cangjie
func border(color: Color, width!: Float32): Widget
```

```cangjie
func border(color: Color, width!: Float32, radius!: Length): Widget
```

```cangjie
func border(color: Color, width!: Float32, radius!: Float32): Widget
```

**参数**

- `color`: `Color` — 边框颜色；完全透明时不绘制。
- `width!`: `Float32` — 线宽，限制在非负；单参数重载固定为 `1.0`。
- `radius!`: [`Length`](Length.md) 或 `Float32` — 圆角半径，`Float32` 按虚拟像素；缺省按直角绘制。

**返回值** `Widget` — 包装后的新节点，供继续链式调用。

### dashedBorder

在组件的填充与内容之上描一圈虚线圆角边框。默认线宽 `1.5`、实段 `6`、间隔 `4`（虚拟像素）；全参数重载逐项配置，线宽、实段与间隔都限制在非负。虚线沿圆角周边等距行进，适合拖放区与占位卡。

```cangjie
func dashedBorder(color: Color): Widget
```

```cangjie
func dashedBorder(color: Color, radius!: Float32): Widget
```

```cangjie
func dashedBorder(color: Color, width!: Float32, radius!: Float32, dash!: Float32, gap!: Float32): Widget
```

**参数**

- `color`: `Color` — 边框颜色；完全透明时不绘制。
- `radius!`: `Float32` — 圆角半径，虚拟像素；缺省按直角绘制。
- `width!`: `Float32` — 线宽，限制在非负；前两个重载固定为 `1.5`。
- `dash!`、`gap!`: `Float32` — 实段与间隔长度，限制在非负；前两个重载固定为 `6.0` 与 `4.0`。

**返回值** `Widget` — 包装后的新节点，供继续链式调用。

### flex

让组件按权重分享所在栈的剩余空间。无参数重载权重为 1；`weight` 限制在非负，权重越大分得越多。效果与 [`Flexible`](Flexible.md) 包装一致：弹性组件拿到的是分得的空间，而不是自己的测量尺寸。

```cangjie
func flex(): Widget
```

```cangjie
func flex(weight: Float32): Widget
```

**参数**

- `weight`: `Float32` — 相对权重，限制在非负；无参数重载为 `1.0`。

**返回值** `Widget` — 包装后的新节点，供继续链式调用。

### visible

控制组件是否参与布局、绘制与事件派发。`visible(false)` 的子树测量为零、不占位、不绘制、不收事件，其焦点项同时被移出焦点遍历——留在遍历顺序里的隐藏控件会成为看不见的死角；`visible(true)` 保留子树原有的布局、绘制、事件和焦点行为。

```cangjie
func visible(isVisible: Bool): Widget
```

**参数**

- `isVisible`: `Bool` — `false` 时整棵子树从布局、绘制、事件与焦点遍历中移除。

**返回值** `Widget` — 包装后的新节点，供继续链式调用。

### enabled

保留组件的布局与绘制、按 `isEnabled` 屏蔽其输入。`enabled(false)` 的子树同时退出焦点遍历（只会忽略 Enter/空格的焦点项是死角），绘制后蒙上半透明背景罩示意禁用；帧事件 `UiEvent.Frame` 仍然放行，内部的帧钩子在禁用期间继续计时。可作用于单个控件，也可作用于整行表单或整块面板。

```cangjie
func enabled(isEnabled: Bool): Widget
```

**参数**

- `isEnabled`: `Bool` — `false` 时子树保留版面但不再响应输入。

**返回值** `Widget` — 包装后的新节点，供继续链式调用。

### modifier

应用一个可复用 [`Modifier`](Modifier.md) 管线。它与直接链式调用保持相同顺序语义，适合设计系统令牌组合或多个页面共享的样式包。

```cangjie
func modifier(value: Modifier): Widget
```

**参数**

- `value`: [`Modifier`](Modifier.md) — 按源码顺序应用的可复用组件变换管线。

**返回值** `Widget` — 应用完整管线后的新节点。

### onEvent

给当前组件添加捕获、目标或冒泡监听器。默认只观察指针或焦点命中本子树的事件；在组件声明后立即调用时，框架会保留
该次声明的内部焦点身份，因此不同子树使用相同的公开 key 也不会互相收到事件。应用级快捷键应显式使用
`EventScope.Global`。

```cangjie
func onEvent(handler!: (UiContext, UiEvent) -> EventOutcome): Widget
func onEvent(phase!: EventPhase, handler!: (UiContext, UiEvent) -> EventOutcome): Widget
func onEvent(phase!: EventPhase, scope!: EventScope, handler!: (UiContext, UiEvent) -> EventOutcome): Widget
```

**参数**

- `phase!`: [`EventPhase`](EventPhase.md) — 监听所在的传播阶段；省略时为 Bubble。
- `scope!`: [`EventScope`](EventScope.md) — 子树命中或全局路由；省略时为 Subtree。
- `handler!`: `(UiContext, UiEvent) -> EventOutcome` — 返回可组合的传播效果。

**返回值** `Widget` — 事件监听包装后的节点。

### pointerEventsWithinLayout

把自定义子树显式标记为只观察其布局矩形内的指针事件，使索引化栈、网格、流式和层叠容器能够跳过空间上不相交的子树。该方法是性能契约而非裁剪器：它不会阻止子组件直接收到手工调用的事件，也不会改变绘制 clip；声明方必须保证自身 `handle` 和全部后代遵守边界。活动捕获期间仍全量路由。

```cangjie
func pointerEventsWithinLayout(): Widget
```

**返回值** `Widget` — 带有 [`PointerEventScope.LayoutBounds`](PointerEventScope.md) 契约的包装节点。

### semantics

为子树添加平台无关的无障碍属性。无 key 重载优先复用单一焦点 id，否则按声明位置生成稳定 id；需要穿越结构重排时传显式 `key`。禁用或隐藏外层修饰器会同步影响语义可用性。内建 Button、Label、Checkbox、TextField 已自动生成基础语义，自定义控件再使用本方法。

```cangjie
func semantics(properties: Semantics): Widget
func semantics(properties: Semantics, key!: String): Widget
```

无障碍信息会在布局稳定后作为一个整体提交。结构未变化时，后续
[`UiContext.semanticsSnapshot`](UiContext.md#semanticssnapshot) 查询直接复用缓存结果。

**参数**

- `properties`: [`Semantics`](Semantics.md) — 标签、角色、值和状态。
- `key!`: `String` — 可选显式重载的稳定语义 id，不能为空。

**返回值** `Widget` — 包装后的新节点，供继续链式调用。

## 数值字重与变量轴

独立设置时保留其它继承样式。

```cangjie
func fontWeight(value: FontWeight): Widget
func fontVariations(value: FontVariations): Widget
```

## 另请参阅

- [emit](functions.md#emit) — 构造函数登记子组件的声明收集机制。
- [UiContext](UiContext.md) — 四个核心方法共同的每帧服务枢纽。
- [EventListener](EventListener.md) — `onEvent` 使用的分相事件传播包装。
- [State](State.md) — 跨帧存活的状态容器。
- [Flexible](Flexible.md) — 弹性协议的包装容器。

### textStyle

```cangjie
func textStyle(value: TextStyle): Widget
```

为整个子树设置继承字体、字号和样式，覆盖所有控件阶段及其浮层回调。嵌套样式只覆盖已设置字段，控件/富文本片段的显式设置优先。
