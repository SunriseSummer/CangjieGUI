[cui](../../index.md) › [cui.core](index.md) › Reveal

# Reveal

位于 `cui.core` 包的公开类

在零与内容自然高度之间缓动过渡的展开/收起容器，切换 `shown` 即让内容滑入滑出。它相当于带动画的条件显示：把任意子树包进 Reveal，改变 `shown` 就得到过渡，不会瞬间出现或消失。

## 声明

```cangjie
public class Reveal <: Widget
```

## 继承

Reveal <: [`Widget`](Widget.md)

## 说明

展开比例保存在按标识键控、跨构建存活的 [`Animator`](Animator.md) 里。子组件始终按完整自然高度布局，绘制时只保留已展开的部分，所以内容从顶部逐步露出，而不是被压扁；动画进行中组件会请求下一帧，静止后不再产生额外开销。`duration`、`easing`、`delay` 只在动画器首次创建时读取——要更换动画参数，请换一个 `key` 以重建动画器；首帧就处于目标状态的 Reveal 会直接稳定，不播放动画。输入跟随可见性：指针事件必须落在已展开区域内；完全收起时不消费事件，也不提供焦点项，但已声明的子树帧订阅仍然存活，显式传入的 `Frame` 也会转发。因此收起不会自动暂停后台轮询；需要暂停时应按状态移除对应订阅。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Reveal", 640, 420))
    app.run {
        let shown = rememberState<Bool>("shown") {false}
        let answer = "可以。展开状态由外部布尔驱动，切换即产生高度过渡。"
        VStack(spacing: 12.vp) {
            Button(if (shown.value) {
                "收起答案"
            } else {
                "展开答案"
            }, {=> shown.value = !shown.value})
            Reveal(shown: shown.value, key: "answer") {
                Label(answer).wrap()
            }
        }
        // 运行时：点击按钮切换展开状态，正文从顶部平滑展开或收起。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 创建展开/收起容器：目标状态、可选的标识与过渡时序，以及内容构建器。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(...)`](#measure) | 报告子组件的自然宽度与"自然高度 × 当前展开分数"。 |
| [`layout(...)`](#layout) | 把子组件按完整自然高度布局在顶部对齐的矩形里，绘制阶段再裁剪。 |
| [`draw(...)`](#draw) | 推进动画，并把子组件裁剪到已展开高度绘制。 |
| [`handle(...)`](#handle) | 帧事件始终转发；指针事件只在落进已展开区域时转发，完全收起时一概不消费。 |
| [`participatesInLayout()`](#participatesinlayout) | 转发子组件是否参与父布局。 |
| [`focusableIds()`](#focusableids) | 完全收起时返回空数组，否则转发子组件的焦点项。 |

## 构造函数

### init

创建展开/收起容器：目标状态、可选的标识与过渡时序，以及内容构建器。时序参数只在动画器首次创建时读取。构造时自动注册进包围它的界面构建函数。

```cangjie
public init(
    shown!: Bool,
    key!: ?String = None,
    duration!: UInt64 = 220,
    easing!: Easing = Easing.EaseInOutQuad,
    delay!: UInt64 = 0,
    content!: () -> Unit
)
```

**参数**

- `shown!`: `Bool` — 目标状态：`true` 向自然高度展开，`false` 向零收起。
- `key!`: `?String` — 动画器的标识；默认 `None`，按构建顺序自动推导；显式给出时须非空（空字符串抛 `IllegalArgumentException`）。换 `key` 会以当前时序参数重建动画器。
- `duration!`: `UInt64` — 过渡时长，毫秒；默认 `220`。
- `easing!`: [`Easing`](Easing.md) — 缓动曲线；默认 `Easing.EaseInOutQuad`。`EaseOutBack` 的中途过冲会被限制在 `[0, 1]`。
- `delay!`: `UInt64` — 每次重定目标后先保持不动的毫秒数，再开始缓动；默认 `0`。给列表逐行递增的 delay 即得交错展开的瀑布。
- `content!`: `() -> Unit` — 界面构建函数，产出被包裹的子树；声明多个组件时自动包进一个垂直栈。

**异常**

- `IllegalArgumentException` — `key` 显式给出且为空字符串时。

## 方法

### measure

报告子组件的自然宽度与"自然高度 × 当前展开分数"。分数取自上一帧绘制推进后的动画器读数，因此报告的高度随动画逐帧变化。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 本轮测量使用的 UI 上下文。
- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 本帧要占据的尺寸；完全收起时高度为 0。

### layout

把子组件按完整自然高度布局在顶部对齐的矩形里，绘制阶段再裁剪。这使内容从顶部拉开而不是随高度压扁。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 本轮布局使用的 UI 上下文。
- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

推进动画，并把子组件裁剪到已展开高度绘制。可见高度不超过本帧分配的高度；不足 0.5 逻辑像素时整体跳过。动画进行中请求下一帧。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

帧事件始终转发；指针事件只在落进已展开区域时转发，完全收起时一概不消费。这防止被隐藏的控件在同一位置继续拦截点击。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 事件被子组件消费时为 `true`。

### participatesInLayout

转发子组件是否参与父布局。

```cangjie
public func participatesInLayout(): Bool
```

**返回值** `Bool` — 子组件的取值。

### focusableIds

完全收起时返回空数组，否则转发子组件的焦点项。键盘可达性与指针输入遵循同一条"跟随可见性"规则，隐藏内容不进入 Tab 遍历。

```cangjie
public func focusableIds(): Array<String>
```

**返回值** `Array<String>` — 可参与 Tab 遍历的焦点标识。

## 另请参阅

- [Animator](Animator.md) — 驱动展开分数的定时缓动器。
- [Easing](Easing.md) — 可选的缓动曲线。
- [Accordion](../controls/Accordion.md) — 建立在同类过渡上的现成折叠面板。
