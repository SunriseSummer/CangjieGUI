[cui](../../index.md) › [cui.controls](index.md) › ProgressBar

# ProgressBar

位于 `cui.controls` 包的公开类

把可观察数值显示为水平填充条的只读进度指示，中央叠加百分比标签。值来源是 [`Observable`](../core/Observable.md)`<Float32>`——[`State`](../core/State.md) 与派生状态皆可驱动；环形变体见 [`ProgressRing`](ProgressRing.md)。

## 声明

```cangjie
public class ProgressBar <: Widget
```

## 继承

`ProgressBar <: Widget` — 实现 [`Widget`](../core/Widget.md) 组件协议。

## 说明

显示前先用 `(value − lower) / (upper − lower)` 把数值换算成 0…1 的比例，并限制在这个范围内。`upper` 与 `lower` 相等时使用一个极小的正跨度，避免除零。填充条和百分比标签共用同一个 [`Spring`](../core/Spring.md)：数值变化时一起平滑移动；即使弹簧短暂越过目标，绘制结果仍限制在 0…1，不会超出控件或显示 −0%/101%。弹簧状态会跨界面重建保留，首帧直接显示当前比例。

进度条纯显示，不参与焦点遍历、不消费任何事件。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("ProgressBar", 640, 420))
    app.run {
        let uploaded = rememberState<Float32>("uploaded") {30.0}
        let bar = ProgressBar(uploaded, lower: 0.0, upper: 120.0)
        // 运行时：窗口显示 30/120 的确定进度条，状态变化时填充平滑过渡。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(value: Observable<Float32>, lower!: Float32 = 0.0, upper!: Float32 = 1.0)`](#init) | 以数值来源与可选范围构造进度条。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`range(lower: Float32, upper: Float32)`](#range) | 设置进度条代表的闭区间范围。 |
| [`measure(_: UiContext, available: Size)`](#measure) | 返回 min(可用宽, 180) × 28 逻辑像素。 |
| [`layout(_: UiContext, rect: Rect)`](#layout) | 记录控件框架。 |
| [`draw(ctx: UiContext)`](#draw) | 画字段底、按弹簧动画比例填充强调色条，中央叠加取整百分比。 |
| [`handle(_: UiContext, _: UiEvent)`](#handle) | 恒返回 `false`——进度条纯显示，不消费任何事件。 |

## 构造函数

### init

以数值来源与可选范围构造进度条。

```cangjie
public init(value: Observable<Float32>, lower!: Float32 = 0.0, upper!: Float32 = 1.0)
```

**参数**

- `value`: [`Observable`](../core/Observable.md)`<Float32>` — 展示的数值来源，只读即可。
- `lower!`: `Float32` — 范围下界；默认 `0.0`。
- `upper!`: `Float32` — 范围上界；默认 `1.0`，与 `lower` 一起定义 0% 与 100% 的位置。

## 方法

### range

设置进度条代表的闭区间范围。两端传反时自动互换。

```cangjie
public func range(lower: Float32, upper: Float32): ProgressBar
```

**参数**

- `lower`: `Float32` — 范围下界（含）。
- `upper`: `Float32` — 范围上界（含）。

**返回值** `ProgressBar` — 返回自身以便链式调用。

### measure

返回 min(可用宽, 180) × 28 逻辑像素。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func measure(_: UiContext, available: Size): Size
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

画字段底、按弹簧动画比例填充强调色条，中央叠加取整百分比。动画比例截在 0…1，过冲不外溢。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

恒返回 `false`——进度条纯显示，不消费任何事件。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func handle(_: UiContext, _: UiEvent): Bool
```

**返回值** `Bool` — 固定为 `false`；该非交互组件不会消费事件。

## 另请参阅

- [ProgressRing](ProgressRing.md) — 环形进度指示。
- [Slider](Slider.md) — 同一几何形态的可输入版本。
