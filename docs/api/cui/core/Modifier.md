[cui](../../index.md) › [cui.core](index.md) › Modifier

# Modifier

`cui.core` 包中的 public class

可复用的 `Widget → Widget` 变换。`Modifier()` 是恒等变换，`then` 按源码顺序组合且满足结合律，因此样式包可独立声明、测试和复用，不引入组件实例生命周期。

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

内建工厂包括 `width`、`height`、`fillWidth`、`fillHeight`、`padding`、`surface`、`background`、`paintOutset`、`flex`、`visible`、`enabled`、`semantics` 和分相 `onEvent`。组合顺序与链式调用一致：

```cangjie
let card = Modifier
    .padding(16.vp)
    .then(Modifier.background(Color.rgb(245, 247, 250), 12.vp))

Panel {Label("内容")}.modifier(card)
```

代数定律：`Modifier().then(m)` 与 `m.then(Modifier())` 在观察上都等价于 `m`；`(a.then(b)).then(c)` 等价于 `a.then(b.then(c))`。`custom` 变换仍须遵守 Widget 发射/包装约定。

`concat` 用于调用方已经持有运行时 Modifier 数组的场景，例如主题 token、插件或字段描述动态产生样式。它在调用时
按数组顺序构造同一个有序积，空数组返回恒等变换，单元素直接复用；不超过 8 项保持线性组合，更宽数组利用结合律
构造平衡调用树，降低复用时的最大调用深度。它只改变括号，不交换、去重或延迟任何步骤；小型静态样式继续使用
`then` 最直接。

事件工厂签名与 [`Widget.onEvent`](Widget.md#onevent) 相同，可把组件策略复用成设计系统行为包；事件效果由 [`EventOutcome`](EventOutcome.md) 组合，Modifier 的源码顺序仍决定监听器的嵌套顺序。
