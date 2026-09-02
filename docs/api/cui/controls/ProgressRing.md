[cui](../../index.md) › [cui.controls](index.md) › ProgressRing

# ProgressRing

位于 `cui.controls` 包的公开类

环形进度指示：淡色轨道整环上，自 12 点方向顺时针扫出与 `value`（0…1 比例，越界截断）相当的前景弧，中心可叠加取整百分比。纯显示控件，是线性 [`ProgressBar`](ProgressBar.md) 的环形互补。

## 声明

```cangjie
public class ProgressRing <: Widget
```

## 继承

`ProgressRing <: Widget` — 实现 [`Widget`](../core/Widget.md) 组件协议。

## 说明

弧从顶部起顺时针推进：0.25 停在 3 点钟、0.5 停在正下方、1.0 回到顶部合成整环；弧是圆头折线，任何尺寸下都平滑，分段数随比例缩放、短弧不过度细分。中心标签就近取整到百分点——恰为 0.7 的值显示 70%，不会因浮点表示略小而截成 69%。

`value` 是普通 `Float32` 而非可观察值：环形指示每帧随声明式树重建，直接传入当帧比例即可（示例见 examples/goals、examples/pomodoro）。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("ProgressRing", 640, 420))
    app.run {
        let ring = ProgressRing(0.7, diameter: 96.0, thickness: 10.0)
        let tiny = ProgressRing(0.3, diameter: 10.0)
        // 运行时：窗口同时显示普通直径与最小直径约束下的环形进度。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 以完成比例与可选几何参数构造圆环。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(_: UiContext, _: Size)`](#measure) | 恒返回直径×直径的正方形尺寸，忽略可用空间。 |
| [`layout(_: UiContext, rect: Rect)`](#layout) | 记录控件框架。 |
| [`isFlexible()`](#isflexible) | 恒为 `false`——圆环保持固有直径，不参与弹性分配。 |
| [`draw(ctx: UiContext)`](#draw) | 画淡色轨道整环，再自顶顺时针描出比例弧，可选叠加中心百分比。 |
| [`handle(_: UiContext, _: UiEvent)`](#handle) | 恒返回 `false`——圆环纯显示，不消费任何事件。 |

## 构造函数

### init

以完成比例与可选几何参数构造圆环。

```cangjie
public init(value: Float32, diameter!: Float32 = 72.0, thickness!: Float32 = 8.0, showLabel!: Bool = true)
```

**参数**

- `value`: `Float32` — 完成比例 0…1；越界值在绘制时截断。
- `diameter!`: `Float32` — 圆环外径，逻辑像素；默认 `72.0`，下限 24。
- `thickness!`: `Float32` — 环线粗细，逻辑像素；默认 `8.0`，下限 2。
- `showLabel!`: `Bool` — 是否在中心显示取整百分比；默认 `true`，环内另叠内容（如倒计时文字）时传 `false`。

## 方法

### measure

恒返回直径×直径的正方形尺寸，忽略可用空间。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func measure(_: UiContext, _: Size): Size
```

**返回值** `Size` — 组件请求的尺寸；方法接收 `available` 时，该尺寸在父级给出的可用约束内计算。

### layout

记录控件框架。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func layout(_: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 父级最终分配给组件的矩形。

### isFlexible

恒为 `false`——圆环保持固有直径，不参与弹性分配。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 固定为 `false`，组件按自身请求尺寸参与布局。

### draw

画淡色轨道整环，再自顶顺时针描出比例弧，可选叠加中心百分比。标签就近取整到百分点。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

恒返回 `false`——圆环纯显示，不消费任何事件。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func handle(_: UiContext, _: UiEvent): Bool
```

**返回值** `Bool` — 固定为 `false`；该非交互组件不会消费事件。

## 另请参阅

- [ProgressBar](ProgressBar.md) — 线性进度指示，值来源为可观察值并带弹簧动画。
- [ZStack](../core/ZStack.md) — 在环中心叠放自定义内容的常用容器。
