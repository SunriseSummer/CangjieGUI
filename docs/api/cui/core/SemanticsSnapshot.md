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

`nodes` 保持声明/布局顺序；重复 id 的最后声明覆盖节点内容和动作目标，同时保留该 id 首次出现的位置。
`node(id)` 为平均 O(1)。`nodeAt` 在提交期建立的有序 AABB union 树中按逆声明/z 序返回视觉最上层节点，使用
[`SemanticsNode.visibleBounds`](SemanticsNode.md) 并忽略零面积节点，典型复杂度为 `O(log n + k)`。快照和索引均
不可变；稳定 retained fragment 的重复快照直接返回已提交数组，不重新扁平化整棵树。

`focusedId` 与节点属性在同一事务中提交，不会暴露新焦点配旧树。导航方法使用提交期从代际 Element 所有权投影
出的父子/兄弟索引，平均 O(1)；没有语义的中间 Element 会被收缩到最近语义祖先。`parentIndexAt` 是平台桥的
零字符串查找入口：根、越界或无父节点均返回 `-1`，其索引对应 `nodes` 的稳定声明顺序。
