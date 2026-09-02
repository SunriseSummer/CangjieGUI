[cui](../../index.md) › [cui.core](index.md) › Flexible

# Flexible

位于 `cui.core` 包的公开类

把内容纳入所在栈空间分配的包装组件：按权重分得剩余空间，而非按内容收缩。等权单元自动对齐成列，更重的单元横跨数列。

## 声明

```cangjie
public class Flexible <: Widget
```

## 继承

Flexible <: [`Widget`](Widget.md)

## 说明

弹性分配由所在的 [`VStack`](VStack.md)/[`HStack`](HStack.md) 执行：非弹性子组件先按内容定尺寸，剩余空间按各弹性子组件的权重份额切分；权重为 w 的子组件同时吸收它跨越的 w−1 道间距，因此权重 2 的单元与两个单权重单元加一道间距精确对齐——计算器键盘"0 键跨两列"就靠它。空块 `Flexible {}` 预留一个空白单元，让网格式行在缺项处保持列节奏。

修饰器 `.flex(weight)`（见 [`Widget`](Widget.md)）作用相同，用于把已构造的组件就地纳入弹性分配。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Flexible", 640, 420))
    app.run {
        let bottomRow = HStack(spacing: 10.vp) {
            Flexible(weight: 2.0) {Button("0", {=> ()})}
            Flexible {Button(".", {=> ()})}
            Flexible {Button("=", {=> ()})}
        }
        let zeroKey = Flexible(weight: 2.0) {Button("0", {=> ()})}
        // 运行时：“0”键占两份剩余宽度，其余键各占一份。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(weight!: Float32 = 1.0, body!: () -> Unit)`](#init) | 以权重与界面构建函数块创建弹性包装。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(ctx: UiContext, available: Size)`](#measure) | 把可用空间原样转给内容并返回其测量尺寸。 |
| [`layout(ctx: UiContext, rect: Rect)`](#layout) | 把分到的框架原样转给内容布局。 |
| [`draw(ctx: UiContext)`](#draw) | 绘制内容。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 把事件转发给内容并返回其结果。 |
| [`isFlexible()`](#isflexible) | 恒返回 `true`：包装本身即弹性参与的声明。 |
| [`flexWeight()`](#flexweight) | 返回构造时声明的权重份额。 |
| [`focusableId()`](#focusableid) | 转发内容的单一焦点项 id。 |
| [`focusableIds()`](#focusableids) | 转发内容子树注册的焦点项。 |

## 构造函数

### init

以权重与界面构建函数块创建弹性包装。

```cangjie
public init(weight!: Float32 = 1.0, body!: () -> Unit)
```

**参数**

- `weight!`: `Float32` — 剩余空间的相对份额；默认 `1.0`，负值按 `0.0` 处理（不分得空间）。
- `body!`: `() -> Unit` — 界面构建函数块；空块预留一个空白单元，多个组件自动竖排。

## 方法

### measure

把可用空间原样转给内容并返回其测量尺寸。在栈的弹性遍中，内容以已定的主轴长度被测量。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 当帧上下文。
- `available`: `Size` — 可用空间，逻辑像素。

**返回值** `Size` — 内容的测量尺寸。

### layout

把分到的框架原样转给内容布局。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。
- `rect`: `Rect` — 弹性遍分配给本单元的框架，逻辑像素。

### draw

绘制内容。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。

### handle

把事件转发给内容并返回其结果。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。
- `event`: `UiEvent` — 待处理的输入事件。

**返回值** `Bool` — 内容消费该事件时为 `true`。

### isFlexible

恒返回 `true`：包装本身即弹性参与的声明。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 恒为 `true`。

### flexWeight

返回构造时声明的权重份额。

```cangjie
public func flexWeight(): Float32
```

**返回值** `Float32` — 权重份额，不小于 0。

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

- [VStack](VStack.md) / [HStack](HStack.md) — 执行弹性分配的栈容器。
- [Spacer](Spacer.md) — 测量为零、只吸收剩余空间的空白弹性组件。
- [Widget](Widget.md) — `isFlexible`/`flexWeight` 协议与 `.flex(weight)` 修饰器。
