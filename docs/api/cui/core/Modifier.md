[cui](../../index.md) › [cui.core](index.md) › Modifier

# Modifier

位于 `cui.core` 包的公开类

可复用的 `Widget → Widget` 变换。`Modifier()` 不做任何修改，`then` 按源码顺序组合，因此样式包可以独立声明、
测试和复用，也不会引入新的组件生命周期。

```cangjie
public class Modifier
```

## 核心方法

```cangjie
public init()
public func applyTo(widget: Widget): Widget
public func then(next: Modifier): Modifier
public static func custom(transform: (Widget) -> Widget): Modifier
public static func concat(values: Array<Modifier>): Modifier
```

## 内置工厂

```cangjie
public static func width(value: Length): Modifier
public static func height(value: Length): Modifier
public static func fillWidth(): Modifier
public static func fillHeight(): Modifier
public static func padding(value: Length): Modifier
public static func surface(value: SurfaceStyle): Modifier
public static func background(color: Color): Modifier
public static func background(color: Color, radius: Length): Modifier
public static func paintOutset(value: Float32): Modifier
public static func paintOutset(value: PaintOutset): Modifier
public static func flex(weight!: Float32 = 1.0): Modifier
public static func visible(value: Bool): Modifier
public static func enabled(value: Bool): Modifier
public static func semantics(properties: Semantics): Modifier
public static func semantics(properties: Semantics, key!: String): Modifier
public static func onEvent(
    phase!: EventPhase = EventPhase.Bubble,
    scope!: EventScope = EventScope.Subtree,
    handler!: (UiContext, UiEvent) -> EventOutcome
): Modifier
```

组合顺序与 Widget 链式调用一致。例如，可先组合 16 vp 内边距和圆角背景，再通过 `Panel` 的 `.modifier(card)` 应用。

`Modifier().then(m)` 与 `m.then(Modifier())` 的结果都等同于 `m`；`(a.then(b)).then(c)` 等同于
`a.then(b.then(c))`。`custom` 变换仍须遵守 Widget 发射和包装约定。

`concat` 用于调用方已经持有运行时 Modifier 数组的场景，例如主题 token、插件或字段描述动态产生样式。它在调用时
按数组顺序构造同一个组合，空数组返回不做修改的 Modifier，单元素直接复用；不超过 8 项保持线性组合，更宽数组使用
平衡调用树，降低复用时的最大调用深度。它只改变组合方式，不交换、去重或延迟任何步骤；小型静态样式继续使用
`then` 最直接。

事件工厂签名与 [`Widget.onEvent`](Widget.md#onevent) 相同，可把组件策略复用成设计系统行为包；事件效果由 [`EventOutcome`](EventOutcome.md) 组合，Modifier 的源码顺序仍决定监听器的嵌套顺序。
