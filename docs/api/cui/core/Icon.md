[cui](../../index.md) › [cui.core](index.md) › Icon

# Icon

位于 `cui.core` 包的公开类

以方形边长绘制的非交互矢量图标，默认 18 vp、取主题文字色。图标名来自 sdl 的 `IconName`；颜色可用 [`foregroundColor`](#foregroundcolor) 覆盖。需要可点击的图标时用 [`IconButton`](IconButton.md)。

## 声明

```cangjie
public class Icon <: Widget
```

## 继承

Icon <: [`Widget`](Widget.md)

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Icon", 640, 420))
    app.run {
        let save = Icon(IconName.Save)
        let refresh = Icon(IconName.Refresh).iconSize(24.0).foregroundColor(Color.rgb(30, 144, 255))
        // 运行时：窗口显示默认保存图标与放大着色后的刷新图标。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 创建矢量图标：图标名，以及可选的边长与颜色。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`iconSize(value: Length)`](#iconsize) | 设置方形图标边长。 |
| [`iconSize(value: Float32)`](#iconsize) | 设置方形图标边长。 |
| [`foregroundColor(value: Color)`](#foregroundcolor) | 覆盖主题推导的图标颜色。 |
| [`measure(...)`](#measure) | 返回解析后的方形边长（下限 1 逻辑像素），忽略可用空间。 |
| [`layout(...)`](#layout) | 记录分配的帧矩形。 |
| [`draw(...)`](#draw) | 在帧中央按解析后的边长绘制矢量图标。 |
| [`handle(...)`](#handle) | 恒返回 `false`：图标不交互。 |

## 构造函数

### init

创建矢量图标：图标名，以及可选的边长与颜色。构造时自动注册进包围它的界面构建函数。

```cangjie
public init(icon: IconName, size!: Length = Length(ICON_DEFAULT_SIZE, LengthUnit.Vp), color!: ?Color = None)
```

**参数**

- `icon`: `IconName` — sdl 提供的矢量图标名（语义权威：sdl 模块文档）。
- `size!`: [`Length`](Length.md) — 方形边长；默认 `Length(ICON_DEFAULT_SIZE, LengthUnit.Vp)`（18 vp）。
- `color!`: `?Color` — 图标颜色；默认 `None`，使用主题文字色。

## 方法

### iconSize

设置方形图标边长。`Float32` 重载按 vp（逻辑像素）解释，`Length` 形式可写 `.iconSize(22.vp)`。返回 `this` 便于链式调用。

```cangjie
public func iconSize(value: Length): Icon
```

```cangjie
public func iconSize(value: Float32): Icon
```

**参数**

- `value`: [`Length`](Length.md) 或 `Float32` — 新边长；`Float32` 形式等价于 `Length(value, LengthUnit.Vp)`。

**返回值** `Icon` — `this`。

### foregroundColor

覆盖主题推导的图标颜色。返回 `this` 便于链式调用。

```cangjie
public func foregroundColor(value: Color): Icon
```

**参数**

- `value`: `Color` — 图标颜色。

**返回值** `Icon` — `this`。

### measure

返回解析后的方形边长（下限 1 逻辑像素），忽略可用空间。

```cangjie
public func measure(ctx: UiContext, _: Size): Size
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 本轮测量使用的 UI 上下文。

**返回值** `Size` — 宽高相等的方形尺寸。

### layout

记录分配的帧矩形。

```cangjie
public func layout(_: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

在帧中央按解析后的边长绘制矢量图标。帧比图标大时四周留白居中。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

恒返回 `false`：图标不交互。

```cangjie
public func handle(_: UiContext, _: UiEvent): Bool
```

**返回值** `Bool` — 恒为 `false`。

## 另请参阅

- [IconButton](IconButton.md) — 可点击、可聚焦的图标按钮。
- [Label](Label.md) — 文本组件，同样的 `foregroundColor` 命名约定。
