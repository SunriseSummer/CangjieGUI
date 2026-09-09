[cui](../../index.md) › [cui.controls](index.md) › Stepper

# Stepper

位于 `cui.controls` 包的公开类

带减/增按钮与键盘支持的整数值编辑器：两端 −/+ 各步进一次，值始终夹在闭区间内。范围与步长既可在构造时给出，也可链式调用 [`range`](#range) 与 [`step`](#step) 配置。

## 声明

```cangjie
public class Stepper <: Widget
```

## 继承

`Stepper <: Widget` — 实现 [`Widget`](../core/Widget.md) 组件协议。

## 说明

构造与 [`range`](#range) 都会立即把绑定值夹入闭区间，且仅在限制确实改变值时写回——链式配置每帧随树重建执行，无变化的写入会白白通知绑定状态的全部观察者。`lower` 与 `upper` 传反时自动互换。

步进使用饱和算术：值临近 `Int64` 极值时先钉在极值再夹回范围，一次步进不会上溢或下溢。宽度随当前数字自适应（值区下限 40 逻辑像素），一两位数字时保持稳定。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Stepper", 640, 420))
    app.run {
        let guests = rememberState<Int64>("guests") {2}
        let stepper = Stepper(guests, lower: 1, upper: 9, step: 2)
        // 运行时：点击减号或加号按 2 调整人数，值始终保持在 1 到 9。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 以整数绑定、可选范围与步长构造步进器。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`range(lower: Int64, upper: Int64)`](#range) | 设置闭区间范围并立即限制当前值。 |
| [`step(value: Int64)`](#step) | 设置正数步长。 |
| [`measure(ctx: UiContext, available: Size)`](#measure) | 返回自适应当前数字的宽度（值区下限 40，加两个 36 宽按钮），高度为 `max(38, 有效文字行高 + 12)` 逻辑像素。 |
| [`layout(_: UiContext, rect: Rect)`](#layout) | 记录控件框架。 |
| [`draw(ctx: UiContext)`](#draw) | 绘制字段面与 −、当前值、+ 三个区。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 点击 −/+ 区步进并夺焦；聚焦后 ←/↓ 减、→/↑ 增，步进饱和于 `Int64` 极值并夹回范围。 |
| [`focusableId()`](#focusableid) | 返回步进器的焦点标识。 |

## 构造函数

### init

以整数绑定、可选范围与步长构造步进器。构造即把绑定值夹入范围（仅在值确实变化时写回）。

```cangjie
public init(
    value: Bindable<Int64>,
    key!: ?String = None,
    lower!: Int64 = Int64.Min,
    upper!: Int64 = Int64.Max,
    step!: Int64 = 1
)
```

**参数**

- `value`: [`Bindable`](../core/Bindable.md)`<Int64>` — 编辑的整数值的双向绑定。
- `key!`: `?String` — 显式焦点标识；默认 `None`，按构建顺序自动派生。
- `lower!`: `Int64` — 范围下界；默认 `Int64.Min` 不设下限。与 `upper` 传反时自动互换。
- `upper!`: `Int64` — 范围上界；默认 `Int64.Max` 不设上限。
- `step!`: `Int64` — 每次步进的增量，须为正；默认 `1`。

**异常**

- `IllegalArgumentException` — `step` 不为正，或 `key` 传入空字符串时。

## 方法

### range

设置闭区间范围并立即限制当前值。两端传反时自动互换；仅在限制改变值时写回绑定，避免重新构建时的无效通知。

```cangjie
public func range(lower: Int64, upper: Int64): Stepper
```

**参数**

- `lower`: `Int64` — 范围下界（含）。
- `upper`: `Int64` — 范围上界（含）。

**返回值** `Stepper` — 返回自身以便链式调用。

### step

设置正数步长。

```cangjie
public func step(value: Int64): Stepper
```

**参数**

- `value`: `Int64` — 每次步进的增量，须为正。

**返回值** `Stepper` — 返回自身以便链式调用。

**异常**

- `IllegalArgumentException` — `value` 不为正时。

### measure

返回自适应当前数字的宽度（值区下限 40，加两个 36 宽按钮），高度为 `max(38, 有效文字行高 + 12)` 逻辑像素。[`Widget`](../core/Widget.md) 协议方法。

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

绘制字段面与 −、当前值、+ 三个区。键盘聚焦时字段面带焦点样式。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

点击 −/+ 区步进并夺焦；聚焦后 ←/↓ 减、→/↑ 增，步进饱和于 `Int64` 极值并夹回范围。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 是否已消费该事件；`true` 表示调用方不应再继续分发。

### focusableId

返回步进器的焦点标识。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 该控件用于参与键盘焦点导航的标识。

## 另请参阅

- [Slider](Slider.md) — 连续或离散实数值的拖动输入，`step` 语义与本控件平行。
- [Picker](Picker.md) — 同样的前后步进交互，作用于字符串候选项。
