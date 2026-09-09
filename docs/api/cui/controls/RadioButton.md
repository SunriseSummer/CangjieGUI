[cui](../../index.md) › [cui.controls](index.md) › RadioButton

# RadioButton

位于 `cui.controls` 包的公开类

整数值互斥选择组中的一个选项：同组各项共享一个 `Bindable<Int64>`，激活任一项即把共享值设为该项的 `value`。选中态画为外圈强调色加内点，内点以弹簧动画放大入场。

## 声明

```cangjie
public class RadioButton <: Widget
```

## 继承

`RadioButton <: Widget` — 实现 [`Widget`](../core/Widget.md) 组件协议。

## 说明

一组单选按钮没有容器——把若干 `RadioButton` 指向同一个 [`Bindable`](../core/Bindable.md)`<Int64>`、各自携带不同的 `value` 即成一组；共享值等于哪个 `value`，哪一项就呈现选中。每一项都是独立的键盘焦点项，聚焦后 Enter/Space 选中该项（组内没有方向键导航）。

内点缩放与外圈颜色共用同一只 [`Spring`](../core/Spring.md)，跨构建保留并以当前状态起步，静态首帧即已稳定。指针交互采用按下-释放语义：释放仍落在控件内才选中。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("RadioButton", 640, 420))
    app.run {
        let quality = rememberState<Int64>("quality") {0}
        let draft = RadioButton("草稿画质", quality, 0)
        let fine = RadioButton("精细画质", quality, 1)
        // 运行时：点击任一画质选项，两个单选按钮共享的绑定值只选中一项。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(label: String, selected: Bindable<Int64>, value: Int64)`](#init) | 以标签、组内共享绑定与本项代表值构造单选项。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`key(value: String)`](#key) | 设置显式焦点与按下状态标识；默认标识按构建顺序唯一。 |
| [`measure(ctx: UiContext, available: Size)`](#measure) | 返回标签宽加 34 逻辑像素圆点区的宽度（封顶于可用宽度），高度为 `max(38, 有效文字行高 + 12)`。 |
| [`layout(_: UiContext, rect: Rect)`](#layout) | 记录控件框架。 |
| [`draw(ctx: UiContext)`](#draw) | 绘制外圈（选中渐变为强调色）、按弹簧比例放大的内点、标签与键盘焦点环。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 按下并在控件内松开时把共享的 `selected` 设为本项 `value`；聚焦后 Enter/Space 同效。 |
| [`focusableId()`](#focusableid) | 返回本选项的焦点标识——组内每一项都是独立焦点项。 |

## 构造函数

### init

以标签、组内共享绑定与本项代表值构造单选项。

```cangjie
public init(label: String, selected: Bindable<Int64>, value: Int64)
```

**参数**

- `label`: `String` — 画在圆点右侧的选项文字。
- `selected`: [`Bindable`](../core/Bindable.md)`<Int64>` — 组内共享的选中值双向绑定。
- `value`: `Int64` — 本项代表的整数值；共享值等于它时本项呈现选中。

## 方法

### key

设置显式焦点与按下状态标识；默认标识按构建顺序唯一。当标识必须跨树形变化存活时才需要显式指定。

```cangjie
public func key(value: String): RadioButton
```

**参数**

- `value`: `String` — 新的控件标识，须非空。

**返回值** `RadioButton` — 返回自身以便链式调用。

**异常**

- `IllegalArgumentException` — `value` 为空字符串时。

### measure

返回标签宽加 34 逻辑像素圆点区的宽度（封顶于可用宽度），高度为 `max(38, 有效文字行高 + 12)`。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮测量使用的 UI 上下文。
- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 组件请求的尺寸；方法接收 `available` 时，该尺寸在父级给出的可用约束内计算。

### layout

记录控件框架。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func layout(_: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

绘制外圈（选中渐变为强调色）、按弹簧比例放大的内点、标签与键盘焦点环。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

按下并在控件内松开时把共享的 `selected` 设为本项 `value`；聚焦后 Enter/Space 同效。按下即获得焦点与按压，释放在控件外则取消。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 是否已消费该事件；`true` 表示调用方不应再继续分发。

### focusableId

返回本选项的焦点标识——组内每一项都是独立焦点项。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 该控件用于参与键盘焦点导航的标识。

## 另请参阅

- [SegmentedControl](SegmentedControl.md) — 并排胶囊形式的互斥选择，同样绑定 `Bindable<Int64>`。
- [Picker](Picker.md) — 前后切换式的紧凑单选。
- [Switch](Switch.md) — 二值开关。
