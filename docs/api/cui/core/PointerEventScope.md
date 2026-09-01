[cui](../../index.md) › [cui.core](index.md) › PointerEventScope

# PointerEventScope

`cui.core` 包中的 public enum

声明 Widget 子树是否可能观察父容器分配矩形之外的指针事件。默认兼容值不会改变既有自定义组件；只有能够证明边界约束的子树才应选择布局范围。

```cangjie
public enum PointerEventScope {
    | Unbounded
    | LayoutBounds
}
```

- `Unbounded`：兼容默认值。父容器必须保留该子树的路由机会，适合全局手势、跨边界协调或尚未声明命中契约的自定义 Widget。
- `LayoutBounds`：子树的全部指针处理都局限在父容器分配的矩形内。`VStack`、`HStack`、`Grid`、`FlowRow` 和 `ZStack` 可用有序 AABB 树剪掉不相交的 z 序片段。

活动按压或拖拽期间，框架绕过空间剪枝，保证移出原矩形后的 MouseMove/MouseUp 仍到达捕获方。完全重叠的候选仍按逆 z 序逐个执行：如果最深节点才消费，Ω(n) 是事件语义本身，而不是索引缺陷。

自定义组件可覆盖 [`Widget.pointerEventScope`](Widget.md#pointereventscope)，也可在实例上使用 [`pointerEventsWithinLayout`](Widget.md#pointereventswithinlayout) 修饰器。错误声明可能跳过矩形之外本应执行的处理器。

## 另请参阅

- [`Widget`](Widget.md)
- [`EventScope`](EventScope.md)
- [焦点、事件与浮层](../../../guide/concepts/focus-events-and-overlays.md)
