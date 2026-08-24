[cui](../../index.md) › [cui.core](index.md) › UiContext

# UiContext

`cui.core` 包中的 public class

渲染帧中传给实际执行组件回调的服务枢纽：渲染器与主题、指针与帧状态，以及焦点、悬停、按下、拖拽、提示与浮层等共享交互协议。整个应用只有一个实例，跨帧存续——普通组件值会随构建更新，retained 边界又可能复用实例，因此需要稳定、统一协调的交互状态保存在这里，而不依赖某个 Widget 的偶然寿命。

## 声明

```cangjie
public class UiContext
```

## 说明

公开方法主要分为“申请”和“查询”两类：组件在 `handle`/`draw` 中申请焦点、悬停、按下或拖动状态，也可以登记浮层和提示；随后查询自己是否持有相应状态，以决定如何绘制。派发前后的重置与结果应用、每帧清空浮层、读取续帧请求等宿主侧操作是 `protected` 成员，由桌面应用对象（[`DesktopApp`](../desktop/DesktopApp.md) 或自定义宿主）在模块内调用，不属于公开 API，因此本页不列出。

这些交互统一使用字符串 `id` 标识控件；标识可按构建顺序自动生成，也可用显式键固定。每次指针移动只有一个控件获得悬停状态：事件从视觉最上层开始派发，第一个申请生效。焦点还区分“持有焦点”和“显示焦点环”：指针点击取得焦点时不画环，通过 Tab 或自动聚焦取得焦点时才画环，符合桌面端的 `:focus-visible` 惯例。

[`resolve`](#resolve) 把带单位的长度（`vp`/`px`/`fp`）换算为逻辑像素；[`requestFrame`](#requestframe) 让按时间推进的动画在按需渲染模式下继续更新——如果不请求下一帧，空闲窗口会停止渲染，动画也会暂停。低层协议测试可用无窗口渲染器和默认主题构造上下文；普通 GUI 程序仍应由 [`DesktopApp`](../desktop/DesktopApp.md) 驱动。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())

    // 长度换算：px 除以显示缩放，fp 乘以字体缩放，vp 原样
    ctx.displayScale = 2.0
    ctx.fontScale = 1.25
    let borderWidth = Int64(ctx.resolve(32.px))
    let bodyFont = Int64(ctx.resolve(16.fp))
    println("32px -> ${borderWidth} 逻辑像素，16fp -> ${bodyFont} 逻辑像素")
    // 输出: 32px -> 16 逻辑像素，16fp -> 20 逻辑像素

    // 焦点协议：键盘到达的焦点才显示焦点环
    ctx.focus("editor.save", viaKeyboard: true)
    let focused = ctx.hasFocus("editor.save")
    let ring = ctx.showFocusRing("editor.save")
    println("聚焦: ${focused}，焦点环: ${ring}")
    // 输出: 聚焦: true，焦点环: true

    // 按下与拖拽所有权：id 独占，直到显式清除
    ctx.press("editor.save")
    ctx.beginDrag("sidebar.splitter", grab: 6.0)
    let pressing = ctx.isPressed("editor.save")
    let dragging = ctx.isDragging("sidebar.splitter")
    let grabOffset = Int64(ctx.dragGrab())
    println("按下: ${pressing}，拖拽: ${dragging}，抓取点 ${grabOffset}")
    // 输出: 按下: true，拖拽: true，抓取点 6
    ctx.clearPress()
    ctx.clearDrag()

    // 浮层栈：登记、计数、按 owner 移除
    ctx.setOverlay(Overlay(handleEvent: {_, _ => true}, render: {_ => ()}, owner: "menu"))
    println("浮层数: ${ctx.overlayCount()}")
    // 输出: 浮层数: 1
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(renderer: Renderer, theme: Theme)`](#init) | 以渲染器与主题创建上下文。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`resolve(...)`](#resolve) | 把带单位的长度换算为逻辑像素。 |
| `eventMetadata()` / `eventModifiers()` | 当前派发事件的时间、窗口、物理/逻辑键和事件时刻修饰键快照。 |
| `setImeComposition(...)` / `imeComposition(id)` | 保存并读取聚焦控件的未提交 IME pre-edit。 |
| `setImeCandidates(...)` / `imeCandidates(id)` | 保存可选的 IME 候选快照。 |
| `clearImeComposition()` | 在提交、blur 或窗口失焦时清理 pre-edit 与候选。 |
| [`paragraphCacheStats()`](#paragraphcachestats) | 返回跨帧段落布局 LRU 的命中、容量与淘汰快照。 |
| [`resetParagraphCacheStats()`](#resetparagraphcachestats) | 清零段落缓存计数而不丢弃缓存内容。 |
| [`requestClose()`](#requestclose) | 请求退出应用：置位 `shouldClose`，宿主据此结束主循环。 |
| [`requestFrame()`](#requestframe) | 请求在无输入、无状态变化时也渲染下一帧。 |
| [`focusNext()`](#focusnext) | 把键盘焦点移到焦点环中的下一个控件，到末尾时回绕。 |
| [`focusPrevious()`](#focusprevious) | 把键盘焦点移到焦点环中的上一个控件，到开头时回绕。 |
| [`hasFocus(id: String)`](#hasfocus) | 返回 `id` 是否持有键盘焦点。 |
| [`showFocusRing(id: String)`](#showfocusring) | 返回 `id` 是否应绘制焦点环：须持有焦点且焦点最后一次由键盘移动。 |
| [`focus(id: String, viaKeyboard!: Bool)`](#focus) | 把键盘焦点交给 `id`。 |
| [`clearFocus()`](#clearfocus) | 清除所有控件的键盘焦点并隐藏焦点环。 |
| [`claimHover(id: String, shape: CursorShape)`](#claimhover) | 为 `id` 申请本次指针移动的悬停状态与指针形状；第一个申请生效。 |
| [`isHovered(id: String)`](#ishovered) | 返回 `id` 是否是指针当前悬停的控件。 |
| [`showTooltip(text: String, rect: Rect)`](#showtooltip) | 登记一条提示，本帧绘制在树上方并锚定于 `rect`。 |
| [`clearTooltip()`](#cleartooltip) | 清除待绘制的提示；宿主在每帧绘制前调用。 |
| [`setTextInputAnchor(rect: Rect)`](#settextinputanchor) | 报告聚焦文本控件本帧的插入符矩形，用于锚定 IME 候选窗。 |
| [`clearTextInputAnchor()`](#cleartextinputanchor) | 清除已报告的插入符锚点；宿主在每帧绘制前调用。 |
| [`textInputAnchorRect()`](#textinputanchorrect) | 返回本帧 `draw` 期间报告的插入符矩形；无聚焦文本控件时为 `None`。 |
| [`setOverlay(overlay: Overlay)`](#setoverlay) | 登记一个交互浮层到已开浮层之上；同 `owner` 重复登记时原位替换。 |
| [`removeOverlay(owner: String)`](#removeoverlay) | 移除登记在 `owner` 名下的浮层，栈中其余浮层保持打开。 |
| [`clearActiveOverlay()`](#clearactiveoverlay) | 移除全部已开浮层；宿主在每帧树重新登记前调用。 |
| [`hasOverlay()`](#hasoverlay) | 返回当前是否有交互浮层打开。 |
| [`overlayCount()`](#overlaycount) | 返回当前打开的交互浮层数量；对话框加其内弹出菜单计两层。 |
| [`dispatchOverlay(event: UiEvent)`](#dispatchoverlay) | 把事件自顶向下提供给已开浮层，返回是否被某层消费。 |
| [`drawActiveOverlay()`](#drawactiveoverlay) | 在树绘制之后自底向顶绘制已开浮层；自定义宿主每帧调用一次。 |
| [`beginDrag(id: String, grab!: Float32)`](#begindrag) | 把 `id` 标记为活动拖拽所有者并记录抓取点偏移。 |
| [`dragGrab()`](#draggrab) | 返回 `beginDrag` 记录的抓取点偏移；仅在该拖拽存续期间有意义。 |
| [`isDragging(id: String)`](#isdragging) | 返回 `id` 是否是活动拖拽的所有者。 |
| [`clearDrag()`](#cleardrag) | 结束活动拖拽并把抓取点偏移清零。 |
| [`press(id: String)`](#press) | 把 `id` 标记为按下，直到主键释放。 |
| [`isPressed(id: String)`](#ispressed) | 返回 `id` 是否持有活动的主键按下。 |
| [`clearPress()`](#clearpress) | 清除活动的主键按下。 |

**字段**

| 成员 | 说明 |
|---|---|
| [`renderer`](#renderer) | 全部绘制所经由的渲染器。 |
| [`theme`](#theme) | 当前配色主题，控件绘制取色的唯一来源。 |
| [`focusId`](#focusid) | 当前持有键盘焦点的控件 id；空串表示无焦点。 |
| [`focusRingVisible`](#focusringvisible) | 聚焦控件是否应绘制焦点环：焦点最后一次由键盘移动时为 `true`。 |
| [`hoverId`](#hoverid) | 指针当前悬停的控件 id；空串表示无悬停。 |
| [`dragId`](#dragid) | 活动拖拽所有者的控件 id；空串表示无拖拽。 |
| [`pressedId`](#pressedid) | 持有活动主键按下的控件 id；空串表示无按下。 |
| [`tooltipText`](#tooltiptext) | 本帧要绘制在树上方的提示文本；空串表示本帧无提示。 |
| [`tooltipAnchor`](#tooltipanchor) | 本帧提示的锚点矩形，即触发提示的控件边界。 |
| [`mouseX`](#mousex) | 指针当前的 x 坐标，逻辑像素。 |
| [`mouseY`](#mousey) | 指针当前的 y 坐标，逻辑像素。 |
| [`leftMouseDown`](#leftmousedown) | 主键（左键）当前是否处于按住状态。 |
| [`shouldClose`](#shouldclose) | 应用是否已请求退出主循环。 |
| [`frame`](#frame) | 本帧的时间信息：总流逝毫秒与帧间隔毫秒。 |
| [`viewportWidth`](#viewportwidth) | 绘制表面的逻辑宽度；浮层用它把弹出内容限制在窗口内。 |
| [`viewportHeight`](#viewportheight) | 绘制表面的逻辑高度；浮层用它把弹出内容限制在窗口内。 |
| [`displayScale`](#displayscale) | 每虚拟像素对应的物理像素数，取自窗口内容缩放。 |
| [`fontScale`](#fontscale) | 作用于 `fp` 长度的用户字体缩放；`1.0` 时 `fp` 与 `vp` 等值。 |
| [`clickCount`](#clickcount) | 当前主键按下是连击的第几次：1 单击、2 双击、3 三击。 |

## 构造函数

### init

以渲染器与主题创建上下文。无头渲染器加默认主题即可在无窗口环境驱动布局、事件与纯逻辑协议。

```cangjie
public init(renderer: Renderer, theme: Theme)
```

**参数**

- `renderer`: `Renderer` — 全部绘制经由的渲染器；测试与文档示例用 `Renderer.headless()`。
- `theme`: [`Theme`](Theme.md) — 控件取色的主题，如 `Theme.light()` / `Theme.dark()`。

## 方法

### eventMetadata / eventModifiers

返回宿主为当前 `UiEventRecord` 安装的事件时刻快照。键盘快捷键和 Shift+Tab 必须使用 `eventModifiers()`，避免事件排队到下一帧后查询全局键盘状态而得到错误结果；直接调用 widget 的纯逻辑测试默认得到空快照。

### IME composition

`setImeComposition` 保存 pre-edit 文本及 IME 选择范围，但不写入应用的 `Bindable<String>`；`TextInput` 到达时才提交。状态按聚焦控件 id 隔离，焦点变化、窗口失焦和 commit 会清理。`imeComposition` 供文本控件绘制未提交文本及下划线，`imeCandidates` 供自定义候选 UI/诊断。

### paragraphCacheStats

返回 [`ParagraphCacheStats`](ParagraphCacheStats.md)。缓存由整个 `UiContext` 共享，能穿过每帧 `Label` 实例重建；默认按约 4 MiB 字节预算执行真 LRU，而非按条目数限制。键覆盖精确宽度、字号、样式、字体/注册表代数和行数上限。

```cangjie
public func paragraphCacheStats(): ParagraphCacheStats
```

### resetParagraphCacheStats

清零命中、未命中和淘汰累计值，但保留缓存内容，便于在预热后单独采样稳定窗口。

```cangjie
public func resetParagraphCacheStats(): Unit
```

### resolve

把带单位的长度换算为逻辑像素。`vp` 原样返回，`px` 除以 [`displayScale`](#displayscale)，`fp` 乘以 [`fontScale`](#fontscale)；`LengthInsets` 重载逐边换算并把负值截为 0。

```cangjie
public func resolve(length: Length): Float32
```

```cangjie
public func resolve(insets: LengthInsets): Insets
```

**参数**

- `length`: [`Length`](Length.md) — 待换算的带单位长度。
- `insets`: [`LengthInsets`](LengthInsets.md) — 待换算的四边内边距。

**返回值** `Float32` / `Insets` — 逻辑像素值；内边距重载保证每边不小于 0。

### requestClose

请求退出应用：置位 `shouldClose`，宿主据此结束主循环。

```cangjie
public func requestClose(): Unit
```

### requestFrame

请求在无输入、无状态变化时也渲染下一帧。按帧时钟动画的组件（闪烁的插入符、旋转指示、倒计时）在 `handle` 或 `draw` 里调用它；不调用则桌面循环在屏幕空闲时跳帧，动画随之冻结。宿主每渲染一帧读取并清除该请求，因此需要每帧重新提出——[`FrameHandler`](FrameHandler.md) 替它包的子树自动做这件事。

```cangjie
public func requestFrame(): Unit
```

### focusNext

把键盘焦点移到焦点环中的下一个控件，到末尾时回绕。无焦点时进入第一个控件；焦点 id 已不在环中（树形状变化）时视作环外、从头进入。经此移动的焦点显示焦点环。焦点环由最近一次构建按声明顺序收集，键盘遍历始终反映屏幕上现有的控件。

```cangjie
public func focusNext(): Unit
```

### focusPrevious

把键盘焦点移到焦点环中的上一个控件，到开头时回绕。无焦点时进入最后一个控件，与 Shift+Tab 进窗的方向一致；经此移动的焦点显示焦点环。

```cangjie
public func focusPrevious(): Unit
```

### hasFocus

返回 `id` 是否持有键盘焦点。控件在 `handle` 里用它决定是否响应 Enter/Space 等激活键。

```cangjie
public func hasFocus(id: String): Bool
```

**参数**

- `id`: `String` — 控件的交互标识。

**返回值** `Bool` — `id` 即当前焦点时为 `true`。

### showFocusRing

返回 `id` 是否应绘制焦点环：须持有焦点且焦点最后一次由键盘移动。指针按下取得的焦点不带环，即桌面 `:focus-visible` 惯例——点击不该留下键盘式轮廓。行为（激活、插入符、方向键）只看 [`hasFocus`](#hasfocus)，仅焦点环受此门控。

```cangjie
public func showFocusRing(id: String): Bool
```

**参数**

- `id`: `String` — 控件的交互标识。

**返回值** `Bool` — 应绘制焦点环时为 `true`。

### focus

把键盘焦点交给 `id`。在 MouseDown 派发期间调用时，表示该控件已经处理了焦点；如果派发结束后没有控件这样做，宿主会清空焦点，实现点击空白处失焦的桌面惯例。

```cangjie
public func focus(id: String, viaKeyboard!: Bool = false): Unit
```

**参数**

- `id`: `String` — 接收焦点的控件标识。
- `viaKeyboard!`: `Bool` — 标记焦点经键盘（Tab、自动聚焦）到达，决定是否显示焦点环；默认 `false`（指针按下，无环）。

### clearFocus

清除所有控件的键盘焦点并隐藏焦点环。

```cangjie
public func clearFocus(): Unit
```

### claimHover

为 `id` 申请本次指针移动的悬停状态与指针形状；第一个申请生效。事件从视觉最上层开始派发，因此重叠时由最上层控件决定指针形状；宿主在 MouseMove 派发前后重置并应用申请结果。控件通常通过工具函数 [`claimHoverIfInside`](functions.md#claimhoverifinside)，在指针进入自身区域时调用。

```cangjie
public func claimHover(id: String, shape: CursorShape): Unit
```

**参数**

- `id`: `String` — 申请悬停的控件标识。
- `shape`: [`CursorShape`](CursorShape.md) — 期望的指针形状；事件派发结束后由宿主应用。

### isHovered

返回 `id` 是否是指针当前悬停的控件。

```cangjie
public func isHovered(id: String): Bool
```

**参数**

- `id`: `String` — 控件的交互标识。

**返回值** `Bool` — `id` 即当前悬停赢家时为 `true`。

### showTooltip

登记一条提示，本帧绘制在树上方并锚定于 `rect`。单槽位：后登记者覆盖前者；持续悬停的控件每帧重新登记（见 [`Tooltip`](Tooltip.md)）。

```cangjie
public func showTooltip(text: String, rect: Rect): Unit
```

**参数**

- `text`: `String` — 提示文本。
- `rect`: `Rect` — 锚点矩形（触发提示的控件边界），逻辑像素。

### clearTooltip

清除待绘制的提示；宿主在每帧绘制前调用。

```cangjie
public func clearTooltip(): Unit
```

### setTextInputAnchor

报告聚焦文本控件本帧的插入符矩形，用于锚定 IME 候选窗。宿主把变化转发给窗口，输入法候选窗因此跟随插入符移动，而不是停在屏幕角落。

```cangjie
public func setTextInputAnchor(rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 插入符矩形，逻辑像素。

### clearTextInputAnchor

清除已报告的插入符锚点；宿主在每帧绘制前调用。

```cangjie
public func clearTextInputAnchor(): Unit
```

### textInputAnchorRect

返回本帧 `draw` 期间报告的插入符矩形；无聚焦文本控件时为 `None`。

```cangjie
public func textInputAnchorRect(): ?Rect
```

**返回值** `?Rect` — 插入符矩形，逻辑像素。

### setOverlay

登记一个交互浮层到已开浮层之上；同 `owner` 重复登记时原位替换。替换保持原有的 z 位置，打开中的控件因此每帧重复登记也不会越级。

```cangjie
public func setOverlay(overlay: Overlay): Unit
```

**参数**

- `overlay`: [`Overlay`](Overlay.md) — 待登记的浮层；`owner` 为空串时总是追加、不可替换。

### removeOverlay

移除登记在 `owner` 名下的浮层，栈中其余浮层保持打开。关闭中的弹出层恰好移除自己的登记、绝不动其下的对话框；`owner` 为空串时不做任何事。

```cangjie
public func removeOverlay(owner: String): Unit
```

**参数**

- `owner`: `String` — 目标浮层的跨帧标识。

### clearActiveOverlay

移除全部已开浮层；宿主在每帧树重新登记前调用。

```cangjie
public func clearActiveOverlay(): Unit
```

### hasOverlay

返回当前是否有交互浮层打开。

```cangjie
public func hasOverlay(): Bool
```

**返回值** `Bool` — 浮层栈非空时为 `true`。

### overlayCount

返回当前打开的交互浮层数量；对话框加其内弹出菜单计两层。

```cangjie
public func overlayCount(): Int64
```

**返回值** `Int64` — 已开浮层数，不小于 0。

### dispatchOverlay

把事件自顶向下提供给已开浮层，返回是否被某层消费。未消费的层让事件落往下一层——模态层对一切返回 `true`，事件永远不会穿过对话框进入背后的树。公开给自定义宿主（不限于 `DesktopApp`）路由事件；派发走栈快照，处理器可在派发中途安全关闭浮层。

```cangjie
public func dispatchOverlay(event: UiEvent): Bool
```

**参数**

- `event`: `UiEvent` — 待派发的输入事件。

**返回值** `Bool` — 某层浮层消费该事件时为 `true`。

### drawActiveOverlay

在树绘制之后自底向顶绘制已开浮层；自定义宿主每帧调用一次。绘制某层时新登记的浮层（对话框体内展开的下拉）在同一帧内被拾起并画在其上。

```cangjie
public func drawActiveOverlay(): Unit
```

### beginDrag

把 `id` 标记为活动拖拽所有者并记录抓取点偏移。抓取点保存在上下文而非组件里：组件树每帧重建，实例字段撑不到下一帧的 MouseMove。

```cangjie
public func beginDrag(id: String, grab!: Float32 = 0.0): Unit
```

**参数**

- `id`: `String` — 拖拽所有者的控件标识。
- `grab!`: `Float32` — 指针在被拖拽部件内的偏移（如指针 y 减滑块顶），默认 `0.0`；后续帧经 [`dragGrab`](#draggrab) 读回，拖拽保持在拾起处、不向指针跳变。

### dragGrab

返回 `beginDrag` 记录的抓取点偏移；仅在该拖拽存续期间有意义。

```cangjie
public func dragGrab(): Float32
```

**返回值** `Float32` — 抓取点偏移，逻辑像素。

### isDragging

返回 `id` 是否是活动拖拽的所有者。

```cangjie
public func isDragging(id: String): Bool
```

**参数**

- `id`: `String` — 控件的交互标识。

**返回值** `Bool` — `id` 即活动拖拽所有者时为 `true`。

### clearDrag

结束活动拖拽并把抓取点偏移清零。

```cangjie
public func clearDrag(): Unit
```

### press

把 `id` 标记为按下，直到主键释放。按钮类控件以此绘制按下态，并在释放时核对"按下与释放是否同一控件"再触发点击。

```cangjie
public func press(id: String): Unit
```

**参数**

- `id`: `String` — 按下所有者的控件标识。

### isPressed

返回 `id` 是否持有活动的主键按下。

```cangjie
public func isPressed(id: String): Bool
```

**参数**

- `id`: `String` — 控件的交互标识。

**返回值** `Bool` — `id` 即按下所有者时为 `true`。

### clearPress

清除活动的主键按下。

```cangjie
public func clearPress(): Unit
```

## 字段

### renderer

全部绘制所经由的渲染器。`let` 字段，构造时注入；无头渲染器让同一套组件代码在无窗口环境运行。

```cangjie
public let renderer: Renderer
```

### theme

当前配色主题，控件绘制取色的唯一来源。`let` 字段，构造时注入；见 [`Theme`](Theme.md)。

```cangjie
public let theme: Theme
```

### focusId

当前持有键盘焦点的控件 id；空串表示无焦点。`var` 字段，通常经 [`focus`](#focus)/[`clearFocus`](#clearfocus)/焦点遍历写入——直接赋值不会更新焦点环可见性。

```cangjie
public var focusId: String = ""
```

### focusRingVisible

聚焦控件是否应绘制焦点环：焦点最后一次由键盘移动时为 `true`。`var` 字段；行为（激活、插入符、方向键）只看 `focusId`，仅焦点环受它门控。

```cangjie
public var focusRingVisible: Bool = false
```

### hoverId

指针当前悬停的控件 id；空串表示无悬停。`var` 字段，由宿主在每次 MouseMove 派发后根据申请结果写入；控件通过 [`isHovered`](#ishovered) 读取它并绘制悬停状态。

```cangjie
public var hoverId: String = ""
```

### dragId

活动拖拽所有者的控件 id；空串表示无拖拽。`var` 字段，经 [`beginDrag`](#begindrag)/[`clearDrag`](#cleardrag) 写入；滚动视口据它判断是否指针捕获。

```cangjie
public var dragId: String = ""
```

### pressedId

持有活动主键按下的控件 id；空串表示无按下。`var` 字段，经 [`press`](#press)/[`clearPress`](#clearpress) 写入。

```cangjie
public var pressedId: String = ""
```

### tooltipText

本帧要绘制在树上方的提示文本；空串表示本帧无提示。`var` 字段，经 [`showTooltip`](#showtooltip)/[`clearTooltip`](#cleartooltip) 写入，宿主在树之后据它绘制。

```cangjie
public var tooltipText: String = ""
```

### tooltipAnchor

本帧提示的锚点矩形，即触发提示的控件边界。`var` 字段，随 [`showTooltip`](#showtooltip) 一起写入。

```cangjie
public var tooltipAnchor: Rect = Rect.zero()
```

### mouseX

指针当前的 x 坐标，逻辑像素。`var` 字段，宿主随指针事件更新；控件在无事件的 `draw` 里也能读到指针位置。

```cangjie
public var mouseX: Float32 = 0.0
```

### mouseY

指针当前的 y 坐标，逻辑像素。`var` 字段，宿主随指针事件更新。

```cangjie
public var mouseY: Float32 = 0.0
```

### leftMouseDown

主键（左键）当前是否处于按住状态。`var` 字段，宿主随按下/释放事件更新；拖拽控制器据它判断拖拽是否仍在进行。

```cangjie
public var leftMouseDown: Bool = false
```

### shouldClose

应用是否已请求退出主循环。`var` 字段，[`requestClose`](#requestclose) 置位，宿主查询到即结束循环。

```cangjie
public var shouldClose: Bool = false
```

### frame

本帧的时间信息：总流逝毫秒与帧间隔毫秒。`var` 字段，宿主每帧写入；连击判定与时间驱动动画都以它为时钟。

```cangjie
public var frame: FrameInfo = FrameInfo(UInt64(0), UInt64(0))
```

### viewportWidth

绘制表面的逻辑宽度；浮层用它把弹出内容限制在窗口内。`var` 字段，宿主随窗口尺寸写入。

```cangjie
public var viewportWidth: Float32 = 0.0
```

### viewportHeight

绘制表面的逻辑高度；浮层用它把弹出内容限制在窗口内。`var` 字段，宿主随窗口尺寸写入。

```cangjie
public var viewportHeight: Float32 = 0.0
```

### displayScale

每虚拟像素对应的物理像素数，取自窗口内容缩放。`var` 字段，默认 `1.0`；[`resolve`](#resolve) 用它换算 `px` 长度。

```cangjie
public var displayScale: Float32 = 1.0
```

### fontScale

作用于 `fp` 长度的用户字体缩放；`1.0` 时 `fp` 与 `vp` 等值。`var` 字段，调大它即放大全部以 `fp` 声明的字号，排版随无障碍设置走。

```cangjie
public var fontScale: Float32 = 1.0
```

### clickCount

当前主键按下是连击的第几次：1 单击、2 双击、3 三击。`var` 字段，宿主在每次左键 MouseDown 派发前按时间与位置就近判定写入，控件在处理按下时读取；不限于文本控件，任何组件都可响应双击。

```cangjie
public var clickCount: Int64 = 1
```

## 另请参阅

- [Widget](Widget.md) — 消费上下文的组件协议（`measure`/`layout`/`draw`/`handle`）。
- [Overlay](Overlay.md) — 浮层栈中登记的交互浮层。
- [CursorShape](CursorShape.md) — 悬停申请携带的指针形状。
- [Theme](Theme.md) — 构造时注入的配色主题。
- [Length](Length.md) — `resolve` 换算的带单位长度。
- [DesktopApp](../desktop/DesktopApp.md) — 驱动全部协议括号调用的桌面应用对象。
