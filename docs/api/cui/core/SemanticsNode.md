[cui](../../index.md) › [cui.core](index.md) › SemanticsNode

# SemanticsNode

位于 `cui.core` 包的公开类

一个已解析的无障碍节点，包含稳定字符串 id、[`Semantics`](Semantics.md) 属性、布局边界、可见边界和支持的 [`SemanticsAction`](SemanticsAction.md) 列表。

```cangjie
public class SemanticsNode
```

```cangjie
public init(
    id: String,
    properties: Semantics,
    bounds: Rect,
    actions!: Array<SemanticsAction> = [],
    visibleBounds!: ?Rect = None
)
```

`bounds` 是控件未裁剪的布局边界；`visibleBounds` 是与祖先 viewport/reveal clip 相交后的可见边界，省略时等于
`bounds`。点查询只使用正面积的 `visibleBounds`，但平台仍可读取原始 `bounds` 表达完整几何。

`id` 为空时抛出 `IllegalArgumentException`。应用通常从 [`UiContext.semanticsSnapshot`](UiContext.md#semanticssnapshot) 读取节点，而不是直接构造；自定义 Widget 可在 `layout` 中构造并注册。
