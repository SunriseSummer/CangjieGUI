[cui](../../index.md) › [cui.controls](index.md) › Badge

# Badge

位于 `cui.controls` 包的公开类

紧凑的状态标签：圆角胶囊底上画同色系文本，纯展示、不响应交互。用于状态、分类、计数与标记；配色由 [`BadgeKind`](BadgeKind.md) 决定，胶囊贴合文本宽度、高度固定 22 逻辑像素。

## 声明

```cangjie
public class Badge <: Widget
```

## 继承

- [`Widget`](../core/Widget.md) — 组件协议（measure/layout/draw/handle 与焦点遍历）。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Badge", 640, 420))
    app.run {
        let status = Badge("已完成", kind: BadgeKind.Success)
        // 运行时：窗口显示成功状态徽标，徽标只展示状态而不接收输入。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(text: String, kind!: BadgeKind)`](#init) | 由文本与语义配色构造徽标。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(ctx: UiContext, _: Size)`](#measure) | 文本宽度加左右各 9 逻辑像素内边距，高度固定 22。 |
| [`layout(_: UiContext, rect: Rect)`](#layout) | 记录分配到的框架。 |
| [`isFlexible()`](#isflexible) | 恒返回 `false`——徽标贴合内容，不参与栈的剩余空间分配。 |
| [`draw(ctx: UiContext)`](#draw) | 画低透明度的同色胶囊底与居中文本。 |
| [`handle(_: UiContext, _: UiEvent)`](#handle) | 恒返回 `false`——徽标纯展示，不消费任何事件。 |

## 构造函数

### init

由文本与语义配色构造徽标。

```cangjie
public init(text: String, kind!: BadgeKind = BadgeKind.Neutral)
```

**参数**

- `text`: `String` — 胶囊内显示的文本。
- `kind!`: `BadgeKind` — 语义配色，见 [`BadgeKind`](BadgeKind.md)。默认 `BadgeKind.Neutral`（中性灰）。

## 方法

### measure

文本宽度加左右各 9 逻辑像素内边距，高度固定 22。忽略可用尺寸（见 [`Widget`](../core/Widget.md)）。

```cangjie
public func measure(ctx: UiContext, _: Size): Size
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮测量使用的 UI 上下文。

**返回值** `Size` — 组件请求的尺寸；方法接收 `available` 时，该尺寸在父级给出的可用约束内计算。

### layout

记录分配到的框架。

```cangjie
public func layout(_: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 父级最终分配给组件的矩形。

### isFlexible

恒返回 `false`——徽标贴合内容，不参与栈的剩余空间分配。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 固定为 `false`，组件按自身请求尺寸参与布局。

### draw

画低透明度的同色胶囊底与居中文本。底与文字同一基色（按 `kind` 取色），底以 alpha 36 软化，明暗主题下均可读。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

恒返回 `false`——徽标纯展示，不消费任何事件。

```cangjie
public func handle(_: UiContext, _: UiEvent): Bool
```

**返回值** `Bool` — 固定为 `false`；该非交互组件不会消费事件。

## 另请参阅

- [BadgeKind](BadgeKind.md) — 徽标的语义配色枚举。
- [Chip](Chip.md) — 外形相近但可交互的过滤标签。
