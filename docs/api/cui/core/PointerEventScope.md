[cui](../../index.md) › [cui.core](index.md) › PointerEventScope

# PointerEventScope

位于 `cui.core` 包的公开枚举

声明 Widget 子树是否可能观察父容器分配矩形之外的指针事件。默认兼容值不会改变既有自定义组件；只有能够证明边界约束的子树才应选择布局范围。

```cangjie
public enum PointerEventScope {
    | Unbounded
    | LayoutBounds
}
```

- `Unbounded`：兼容默认值。父容器必须保留该子树的路由机会，适合全局手势、跨边界协调或尚未声明命中契约的自定义 Widget。
- `LayoutBounds`：子树只处理父容器分配矩形内的指针事件。`VStack`、`HStack`、`Grid`、`FlowRow` 和 `ZStack`
  可以跳过与指针位置不相交的子树。

按压或拖动期间，框架不会按布局矩形跳过事件，保证移出原区域后的 `MouseMove` 和 `MouseUp` 仍到达开始交互的组件。
完全重叠的候选仍按从上到下的显示顺序处理，直到事件被消费。

自定义组件可覆盖 [`Widget.pointerEventScope`](Widget.md#pointereventscope)，也可在实例上使用 [`pointerEventsWithinLayout`](Widget.md#pointereventswithinlayout) 修饰器。错误声明可能跳过矩形之外本应执行的处理器。

## 另请参阅

- [`Widget`](Widget.md)
- [`EventScope`](EventScope.md)
- [焦点、事件与浮层](../../../guide/concepts/focus-events-and-overlays.md)
