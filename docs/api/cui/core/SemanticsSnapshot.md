[cui](../../index.md) › [cui.core](index.md) › SemanticsSnapshot

# SemanticsSnapshot

最近一次稳定布局事务提交的不可变、按 id 建索引的语义快照。

```cangjie
public class SemanticsSnapshot {
    public let revision: UInt64
    public let nodes: Array<SemanticsNode>
    public let focusedId: String
    public func node(id: String): ?SemanticsNode
    public func nodeAt(x: Float32, y: Float32): ?SemanticsNode
    public func parent(id: String): ?SemanticsNode
    public func previousSibling(id: String): ?SemanticsNode
    public func nextSibling(id: String): ?SemanticsNode
    public func firstChild(id: String): ?SemanticsNode
    public func lastChild(id: String): ?SemanticsNode
    public func firstRootChild(): ?SemanticsNode
    public func lastRootChild(): ?SemanticsNode
    public func parentIndexAt(index: Int64): Int64
}
```

`nodes` 保持声明和布局顺序。id 重复时，最后一次声明覆盖节点内容和动作目标，但节点仍位于该 id 首次出现的位置。
`node(id)` 按 id 快速查询；`nodeAt` 使用 [`SemanticsNode.visibleBounds`](SemanticsNode.md)，忽略零面积节点，并返回
命中位置上显示层级最高的节点。快照及其索引不可变；界面结构未变化时会直接复用上次结果。

`focusedId` 和节点属性在同一事务中提交，不会出现新焦点与旧节点树混用。父子和兄弟导航会跳过没有语义信息的中间组件。
`parentIndexAt` 供平台无障碍桥按数组索引查询父节点；根节点、越界索引或无父节点都返回 `-1`。
