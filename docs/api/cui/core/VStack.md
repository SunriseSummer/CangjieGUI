[cui](../../index.md) › [cui.core](index.md) › VStack

# VStack

位于 `cui.core` 包的公开类

沿垂直主轴排布子组件的弹性栈容器：以尾随 lambda 声明子组件，间距、主轴/交叉轴对齐与弹性参与可链式配置。弹性子组件（见 [`Flexible`](Flexible.md)）按权重分享剩余高度，其余子组件按内容高度排列。

## 声明

```cangjie
public class VStack <: Widget
```

## 继承

VStack <: [`Widget`](Widget.md)

## 说明

布局分两步。`measure` 报告内容尺寸：垂直方向为各参与子组件高度之和加间距与内边距（不限制在可用空间，溢出由滚动容器接手），水平方向取最宽子组件。`layout` 三遍完成、每个子组件恰测量一次：先测非弹性子组件，再把剩余高度按 `flexWeight` 份额分给弹性子组件——权重为 w 的子组件同时吸收它跨越的 w−1 道间距，权重 2 的单元因此与两个单权重单元加一道间距精确对齐——最后按对齐放置。默认主轴对齐 `Start`、交叉轴对齐 `Stretch`（见 [`MainAxisAlignment`](MainAxisAlignment.md) 与 [`CrossAxisAlignment`](CrossAxisAlignment.md)）。

栈自身默认参与父容器的弹性分配（填满分到的高度）；[`flexible(false)`](#flexible) 或 [`hug()`](#hug) 让它按内容收缩，适合应当"正好包住内容"的卡片或工具栏。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("VStack", 640, 420))
    app.run {
        let sidebar = VStack(spacing: 12.vp) {
            Label("收件箱").height(40.0)
            Label("已加星标").height(40.0)
            Label("已归档").height(40.0)
        }
        // 运行时：三个导航项按 12 虚拟像素间距从上到下排列。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 以命名参数与界面构建函数块创建垂直栈。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`spacing(...)`](#spacing) | 设置相邻子组件之间的间距。 |
| [`mainAxisAlignment(value: MainAxisAlignment)`](#mainaxisalignment) | 设置主轴（垂直方向）有剩余空间时子组件的排布方式。 |
| [`crossAxisAlignment(value: CrossAxisAlignment)`](#crossaxisalignment) | 设置子组件在水平交叉轴上的对齐方式。 |
| [`flexible(value: Bool)`](#flexible) | 控制本栈自身是否参与父容器的弹性分配。 |
| [`hug()`](#hug) | 让本栈沿父容器主轴按内容收缩，即 `flexible(false)` 的语义化写法。 |
| [`measure(ctx: UiContext, available: Size)`](#measure) | 测量内容尺寸：垂直方向为各参与子组件高度之和加间距与内边距，水平方向取最宽子组件。 |
| [`layout(ctx: UiContext, rect: Rect)`](#layout) | 三遍布局：先测非弹性子组件，再按权重分配剩余高度，最后按对齐放置。 |
| [`draw(ctx: UiContext)`](#draw) | 按声明顺序绘制子组件。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 把事件派发给子组件并返回是否被消费。 |
| [`isFlexible()`](#isflexible) | 返回本栈是否参与父容器的弹性分配。 |
| [`focusableIds()`](#focusableids) | 按声明顺序串联全部子组件注册的焦点项。 |

## 构造函数

### init

以命名参数与界面构建函数块创建垂直栈。

```cangjie
public init(
    spacing!: Length = vpLength(CUI_GAP),
    padding!: LengthInsets = LengthInsets.zero(),
    flexible!: Bool = true,
    body!: () -> Unit
)
```

**参数**

- `spacing!`: [`Length`](Length.md) — 相邻子组件的间距；默认值为 `vpLength(CUI_GAP)`，当前即 8 虚拟像素。
- `padding!`: [`LengthInsets`](LengthInsets.md) — 栈内容四周的内边距；默认值为 `LengthInsets.zero()`，即四边均无内边距。
- `flexible!`: `Bool` — 本栈是否参与父容器的弹性分配；默认 `true`（填满分到的高度）。
- `body!`: `() -> Unit` — 界面构建函数块；块内构造的组件按声明顺序成为子组件，普通的 `for`/`if` 控制流可直接使用。

## 方法

### spacing

设置相邻子组件之间的间距。不带单位的 `Float32` 重载按虚拟像素解释。

```cangjie
public func spacing(value: Length): VStack
```

```cangjie
public func spacing(value: Float32): VStack
```

**参数**

- `value`: `Length` / `Float32` — 新的间距，如 `12.vp`；负值按 0 处理。

**返回值** `VStack` — 本栈自身，用于链式调用。

### mainAxisAlignment

设置主轴（垂直方向）有剩余空间时子组件的排布方式。

```cangjie
public func mainAxisAlignment(value: MainAxisAlignment): VStack
```

**参数**

- `value`: `MainAxisAlignment` — 排布方式；默认 `Start`。

**返回值** `VStack` — 本栈自身，用于链式调用。

### crossAxisAlignment

设置子组件在水平交叉轴上的对齐方式。

```cangjie
public func crossAxisAlignment(value: CrossAxisAlignment): VStack
```

**参数**

- `value`: `CrossAxisAlignment` — 对齐方式；默认 `Stretch`，允许拉伸的子组件填满栈宽。

**返回值** `VStack` — 本栈自身，用于链式调用。

### flexible

控制本栈自身是否参与父容器的弹性分配。

```cangjie
public func flexible(value: Bool): VStack
```

**参数**

- `value`: `Bool` — `true` 填满父容器分到的主轴空间（默认行为）；`false` 按内容收缩。

**返回值** `VStack` — 本栈自身，用于链式调用。

### hug

让本栈沿父容器主轴按内容收缩，即 `flexible(false)` 的语义化写法。适合应当正好与内容一样高的卡片或工具栏。

```cangjie
public func hug(): VStack
```

**返回值** `VStack` — 本栈自身，用于链式调用。

### measure

测量内容尺寸：垂直方向为各参与子组件高度之和加间距与内边距，水平方向取最宽子组件。结果不限制在 `available`，超出即溢出。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 当帧上下文，用于长度换算。
- `available`: `Size` — 可用空间，逻辑像素。

**返回值** `Size` — 内容的首选尺寸。

### layout

三遍布局：先测非弹性子组件，再按权重分配剩余高度，最后按对齐放置。每个参与子组件恰好测量一次。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。
- `rect`: `Rect` — 分配给本栈的框架，逻辑像素。

### draw

按声明顺序绘制子组件。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。

### handle

把事件按声明逆序交给子组件，遇到返回 `true` 的组件后停止。显式传入的 `Frame` 事件会广播给全部子组件并返回 `false`；桌面应用的正常帧回调使用独立订阅。对于声明了 [`PointerEventScope.LayoutBounds`](PointerEventScope.md) 的子树，指针事件可以跳过明显不相交的区域；活动手势仍采用保守路由。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。
- `event`: `UiEvent` — 待处理的输入事件。

**返回值** `Bool` — 某个子组件消费该事件时为 `true`。

### isFlexible

返回本栈是否参与父容器的弹性分配。由构造参数 `flexible!` 与 [`flexible`](#flexible)/[`hug`](#hug) 链式配置决定，默认 `true`。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 参与弹性分配时为 `true`。

### focusableIds

按声明顺序串联全部子组件注册的焦点项。键盘 Tab 遍历与 `.enabled(false)` 摘除整棵子树都依赖它。

```cangjie
public func focusableIds(): Array<String>
```

**返回值** `Array<String>` — 子树内全部焦点项 id。

## 另请参阅

- [HStack](HStack.md) — 水平方向的对应栈容器。
- [Flexible](Flexible.md) — 按权重参与本栈空间分配的包装组件。
- [Spacer](Spacer.md) — 吸收剩余空间、把相邻子组件推开的空白弹性组件。
- [ZStack](ZStack.md) — 层叠而非排列的容器。
