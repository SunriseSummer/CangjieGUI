[cui](../../index.md) › [cui.core](index.md) › Divider

# Divider

位于 `cui.core` 包的公开类

分隔内容的 1 逻辑像素发丝线，走向由 `axis` 指定、长度由父栈拉伸铺满。颜色默认取 [`Theme`](Theme.md) 的面板边缘色（`panelEdge`）。

## 声明

```cangjie
public class Divider <: Widget
```

## 继承

Divider <: [`Widget`](Widget.md)

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Divider", 640, 420))
    app.run {
        let rule = Divider()
        let side = Divider(axis: Axis.Vertical)
        let _ = VStack {
            Label("通用")
            Divider()
            Label("关于")
        }
        // 运行时：窗口同时展示水平与竖直分隔线在内容区中的方向差异。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 创建分隔线：可选的方向与颜色。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`axis(value: Axis)`](#axis) | 设置分隔线方向。 |
| [`foregroundColor(value: Color)`](#foregroundcolor) | 覆盖主题的分隔线颜色。 |
| [`color(value: Color)`](#color) | `foregroundColor` 的旧名别名。 |
| [`measure(...)`](#measure) | 只贡献 1 逻辑像素的厚度：水平线报 `Size(0, 1)`、垂直线报 `Size(1, 0)`，线的长度交给父栈拉伸。 |
| [`layout(...)`](#layout) | 记录分配的帧矩形。 |
| [`draw(...)`](#draw) | 在帧内绘制 1 逻辑像素粗的线。 |
| [`handle(...)`](#handle) | 恒返回 `false`：分隔线不交互。 |

## 构造函数

### init

创建分隔线：可选的方向与颜色。构造时自动注册进包围它的界面构建函数。

```cangjie
public init(axis!: Axis = Axis.Horizontal, color!: ?Color = None)
```

**参数**

- `axis!`: [`Axis`](Axis.md) — 分隔线方向；默认 `Axis.Horizontal`（水平线）。
- `color!`: `?Color` — 线的颜色；默认 `None`，使用主题的面板边缘色。

## 方法

### axis

设置分隔线方向。返回 `this` 便于链式调用。

```cangjie
public func axis(value: Axis): Divider
```

**参数**

- `value`: [`Axis`](Axis.md) — `Horizontal` 或 `Vertical`。

**返回值** `Divider` — `this`。

### foregroundColor

覆盖主题的分隔线颜色。命名与 [`Label`](Label.md) / [`Icon`](Icon.md) 的 `foregroundColor` 保持一致。返回 `this` 便于链式调用。

```cangjie
public func foregroundColor(value: Color): Divider
```

**参数**

- `value`: `Color` — 线的颜色。

**返回值** `Divider` — `this`。

### color

**Deprecated:** 改用 [`foregroundColor`](#foregroundcolor)；保留此别名只为既有调用点继续工作。

`foregroundColor` 的旧名别名。返回 `this` 便于链式调用。

```cangjie
public func color(value: Color): Divider
```

**参数**

- `value`: `Color` — 线的颜色。

**返回值** `Divider` — `this`。

### measure

只贡献 1 逻辑像素的厚度：水平线报 `Size(0, 1)`、垂直线报 `Size(1, 0)`，线的长度交给父栈拉伸。

```cangjie
public func measure(_: UiContext, _: Size): Size
```

**返回值** `Size` — 分隔线的固有尺寸。

### layout

记录分配的帧矩形。

```cangjie
public func layout(_: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

在帧内绘制 1 逻辑像素粗的线。水平线横贯整宽并在帧内垂直居中；垂直线水平居中且上下各内缩 4 逻辑像素。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

恒返回 `false`：分隔线不交互。

```cangjie
public func handle(_: UiContext, _: UiEvent): Bool
```

**返回值** `Bool` — 恒为 `false`。

## 另请参阅

- [Spacer](Spacer.md) — 用空白而非线条分隔内容。
- [Theme](Theme.md) — 提供默认分隔线颜色的主题。
