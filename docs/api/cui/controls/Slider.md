[cui](../../index.md) › [cui.controls](index.md) › Slider

# Slider

位于 `cui.controls` 包的公开类

拖动圆钮在闭区间内取值的滑杆，双向绑定 `Bindable<Float32>`：按下即跳到指针处并开始拖拽，`step` 为正时值吸附到 `lower + k·step` 的离散刻度，为 0（默认）则连续取值。

## 声明

```cangjie
public class Slider <: Widget
```

## 继承

`Slider <: Widget` — 实现 [`Widget`](../core/Widget.md) 组件协议。

## 说明

构造参数与 `.range()` 都会排序上下界。范围端点和跨度必须有限；Slider 的步长也必须有限，否则抛出 `IllegalArgumentException`。动态数据中的 NaN 按下界处理，无穷值夹到边界；绘制不会为了纠正数据而写回 State。极小正步长采用浮点舍入，避免转整数溢出。

写入前的规范化恒为“先夹进范围，离散滑杆再四舍五入吸附到最近刻度、吸附结果仍夹回范围”；连续滑杆（`step` 为 0 或负）只做范围限制，起始值原样保留。构造时只有离散滑杆会吸附初值；[`range`](#range) 与 [`step`](#step) 的规范化仅在值确实变化时写回绑定，重新构建不会产生无效通知。

拖拽会话由 [`UiContext`](../core/UiContext.md) 的拖拽协议维持：按下后指针移出控件仍持续跟随，直到松开。聚焦后 ←/→ 按键盘步长增减——离散滑杆用 `step`，连续滑杆用范围的 1/100。轨道两端各缩进 8 逻辑像素，指针位置按轨道有效长度换算比例。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Slider", 640, 420))
    app.run {
        let volume = rememberState<Float32>("volume") {20.0}
        let slider = Slider(volume, lower: 0.0, upper: 100.0, step: 5.0)
        // 运行时：拖动滑块或用方向键按 5 调整音量，值始终保持在 0 到 100。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 以实数绑定、可选范围与步长构造滑杆。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`range(lower: Float32, upper: Float32)`](#range) | 设置滑杆控制的闭区间范围并规范化当前值。 |
| [`step(step: Float32)`](#step) | 设置取值步长；0 让滑杆保持连续。 |
| [`measure(_: UiContext, available: Size)`](#measure) | 宽度为 `min(可用宽, 180)`，高度为 `max(38, 有效文字行高 + 12)` 逻辑像素。 |
| [`layout(_: UiContext, rect: Rect)`](#layout) | 记录控件框架。 |
| [`draw(ctx: UiContext)`](#draw) | 绘制轨道、已填充段与强调色描边的圆钮。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 按下跳到指针处并开始拖拽会话，拖动与松开持续更新；聚焦后 ←/→ 按键盘步长增减。 |
| [`focusableId()`](#focusableid) | 返回滑杆的焦点标识。 |

## 构造函数

### init

以实数绑定、可选范围与步长构造滑杆。构造时只有离散滑杆（`step` 为正）会吸附初值，连续滑杆保持初值不动。

```cangjie
public init(value: Bindable<Float32>, key!: ?String = None, lower!: Float32 = 0.0, upper!: Float32 = 1.0, step!: Float32 = 0.0)
```

**参数**

- `value`: [`Bindable`](../core/Bindable.md)`<Float32>` — 滑杆值的双向绑定。
- `key!`: `?String` — 显式焦点标识；默认 `None`，按构建顺序自动派生。
- `lower!`: `Float32` — 范围下界；默认 `0.0`。
- `upper!`: `Float32` — 范围上界；默认 `1.0`。
- `step!`: `Float32` — 取值步长；默认 `0.0` 连续取值，正数吸附到 `lower + k·step`，负数按 0 计。

**异常**

- `IllegalArgumentException` — `key` 为空，范围端点或跨度非有限，或步长非有限时。

## 方法

### range

设置滑杆控制的闭区间范围并规范化当前值。两端传反时自动互换；仅在规范化改变值时写回绑定，避免重新构建时的无效通知。

```cangjie
public func range(lower: Float32, upper: Float32): Slider
```

**参数**

- `lower`: `Float32` — 范围下界（含）。
- `upper`: `Float32` — 范围上界（含）。

**返回值** `Slider` — 返回自身以便链式调用。

### step

设置取值步长；0 让滑杆保持连续。值吸附到 `lower + k·step` 的刻度并立即规范化当前值；与 [`Stepper`](Stepper.md) 的 `step` 语义平行，滑杆与步进器能以同一方式表达离散范围。

```cangjie
public func step(step: Float32): Slider
```

**参数**

- `step`: `Float32` — 取值步长；0 或负数让滑杆连续。

**返回值** `Slider` — 返回自身以便链式调用。

### measure

宽度为 `min(可用宽, 180)`，高度为 `max(38, 有效文字行高 + 12)` 逻辑像素。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

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

绘制轨道、已填充段与强调色描边的圆钮。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

按下跳到指针处并开始拖拽会话，拖动与松开持续更新；聚焦后 ←/→ 按键盘步长增减。拖拽期间指针移出控件仍持续跟随。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 是否已消费该事件；`true` 表示调用方不应再继续分发。

### focusableId

返回滑杆的焦点标识。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 该控件用于参与键盘焦点导航的标识。

## 另请参阅

- [Stepper](Stepper.md) — 按钮步进的整数值编辑器，`step` 语义与本控件平行。
- [ProgressBar](ProgressBar.md) — 同一几何形态的只读进度显示。
