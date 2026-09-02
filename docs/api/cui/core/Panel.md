[cui](../../index.md) › [cui.core](index.md) › Panel

# Panel

位于 `cui.core` 包的公开类

带主题表面与内容内边距的卡片式容器，是划分界面区块的基础构件。表面取自当前主题的面板样式，可整体覆盖；内容默认四周留 12 虚拟像素内边距。

## 声明

```cangjie
public class Panel <: Widget
```

## 继承

Panel <: [`Widget`](Widget.md)

## 说明

面板是内容四周的"尺寸镶边"：测量为内容尺寸加内边距，事件原样穿透给内容，弹性权重也由内容决定（[`flexWeight`](#flexweight) 转发内容声明的份额）。是否参与弹性分配取二者合取：须自身开启（构造参数或 [`flexible`](#flexible)）且内容也弹性参与，任何一方收缩即整体按内容收缩。

表面绘制在内容之下：未设自定义样式时使用 [`Theme`](Theme.md) 的面板表面（底色、描边、圆角随主题走），`style` 覆盖后与主题脱钩。面板可嵌套，常与 [`VStack`](VStack.md)/[`HStack`](HStack.md) 组合出卡片内的行列结构。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Panel", 640, 420))
    app.run {
        let card = Panel {
            Label("本周焦点").width(200.0).height(100.0)
        }
        // 运行时：窗口显示带主题表面和默认内边距的卡片。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 以内边距、可选表面样式与界面构建函数块创建面板。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`contentPadding(...)`](#contentpadding) | 设置面板表面与内容之间的内边距。 |
| [`style(value: SurfaceStyle)`](#style) | 以给定表面样式覆盖主题面板表面。 |
| [`flexible(value: Bool)`](#flexible) | 控制面板是否参与所在栈的弹性分配。 |
| [`hug()`](#hug) | 让面板沿所在栈主轴按内容收缩，即 `flexible(false)` 的语义化写法。 |
| [`measure(ctx: UiContext, available: Size)`](#measure) | 测量为内容尺寸加四周内边距，限制在可用空间。 |
| [`layout(ctx: UiContext, rect: Rect)`](#layout) | 记录自身框架，把内容布局在按内边距内缩后的区域。 |
| [`draw(ctx: UiContext)`](#draw) | 先绘制面板表面（自定义样式或主题面板表面），再绘制内容。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 把事件原样转发给内容并返回其结果。 |
| [`isFlexible()`](#isflexible) | 返回面板是否参与弹性分配：须自身开启且内容也弹性参与。 |
| [`flexWeight()`](#flexweight) | 转发内容声明的权重：面板是内容的尺寸镶边，份额由内容决定。 |
| [`focusableId()`](#focusableid) | 转发内容的单一焦点项 id。 |
| [`focusableIds()`](#focusableids) | 转发内容子树注册的焦点项。 |

## 构造函数

### init

以内边距、可选表面样式与界面构建函数块创建面板。

```cangjie
public init(
    padding!: LengthInsets = LengthInsets(vpLength(12.0)),
    style!: ?SurfaceStyle = None,
    flexible!: Bool = true,
    body!: () -> Unit
)
```

**参数**

- `padding!`: [`LengthInsets`](LengthInsets.md) — 表面与内容之间的内边距；默认值为 `LengthInsets(vpLength(12.0))`，即四周各 12 虚拟像素。
- `style!`: `?SurfaceStyle` — 自定义表面样式；默认 `None`，使用主题面板表面。
- `flexible!`: `Bool` — 面板是否参与所在栈的弹性分配；默认 `true`（还须内容也弹性参与）。
- `body!`: `() -> Unit` — 界面构建函数块；块内声明多个组件时自动竖排为一个子树。

## 方法

### contentPadding

设置面板表面与内容之间的内边距。四个重载按精度递增：四周等值、水平/垂直分设、逐边分设、以及直接采用已解析的逻辑像素值。

```cangjie
public func contentPadding(all: Length): Panel
```

```cangjie
public func contentPadding(horizontal: Length, vertical: Length): Panel
```

```cangjie
public func contentPadding(value: LengthInsets): Panel
```

```cangjie
public func contentPadding(value: Insets): Panel
```

**参数**

- `all`: [`Length`](Length.md) — 四周同值的内边距，如 `16.vp`。
- `horizontal` / `vertical`: `Length` — 左右与上下分设的内边距。
- `value`: `LengthInsets` / `Insets` — 逐边内边距；`Insets` 重载把已解析的逻辑像素按 `vp` 采用。

**返回值** `Panel` — 本面板自身，用于链式调用。

### style

以给定表面样式覆盖主题面板表面。

```cangjie
public func style(value: SurfaceStyle): Panel
```

**参数**

- `value`: `SurfaceStyle` — 完整的表面样式（底色、描边、圆角等），覆盖后不再随主题变化。

**返回值** `Panel` — 本面板自身，用于链式调用。

### flexible

控制面板是否参与所在栈的弹性分配。

```cangjie
public func flexible(value: Bool): Panel
```

**参数**

- `value`: `Bool` — `true` 参与（默认行为，还须内容也弹性参与）；`false` 按内容收缩。

**返回值** `Panel` — 本面板自身，用于链式调用。

### hug

让面板沿所在栈主轴按内容收缩，即 `flexible(false)` 的语义化写法。

```cangjie
public func hug(): Panel
```

**返回值** `Panel` — 本面板自身，用于链式调用。

### measure

测量为内容尺寸加四周内边距，限制在可用空间。内容以扣除内边距后的内区被测量。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 当帧上下文，用于内边距换算。
- `available`: `Size` — 可用空间，逻辑像素。

**返回值** `Size` — 面板的首选尺寸，不超过 `available`。

### layout

记录自身框架，把内容布局在按内边距内缩后的区域。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。
- `rect`: `Rect` — 分配给面板的框架，逻辑像素。

### draw

先绘制面板表面（自定义样式或主题面板表面），再绘制内容。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。

### handle

把事件原样转发给内容并返回其结果。面板表面本身不消费任何事件。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。
- `event`: `UiEvent` — 待处理的输入事件。

**返回值** `Bool` — 内容消费该事件时为 `true`。

### isFlexible

返回面板是否参与弹性分配：须自身开启且内容也弹性参与。包一个按内容收缩的子树时，面板整体也按内容收缩。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 参与弹性分配时为 `true`。

### flexWeight

转发内容声明的权重：面板是内容的尺寸镶边，份额由内容决定。

```cangjie
public func flexWeight(): Float32
```

**返回值** `Float32` — 内容的权重份额。

### focusableId

转发内容的单一焦点项 id。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 内容的焦点项 id，内容不可聚焦时为 `None`。

### focusableIds

转发内容子树注册的焦点项。

```cangjie
public func focusableIds(): Array<String>
```

**返回值** `Array<String>` — 内容子树内全部焦点项 id，按声明顺序。

## 另请参阅

- [Theme](Theme.md) — 默认面板表面的来源。
- [VStack](VStack.md) / [HStack](HStack.md) — 常与面板嵌套的栈容器。
- [Widget](Widget.md) — `.surface(style)`/`.background(color)` 修饰器：给任意组件加表面的轻量替代。
