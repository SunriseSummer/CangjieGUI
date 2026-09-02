[cui](../../index.md) › [cui.core](index.md) › EventListener

# EventListener

位于 `cui.core` 包的公开类

以捕获、目标或冒泡阶段观察一个几何/焦点命中的子树，并用可组合 [`EventOutcome`](EventOutcome.md) 返回处理效果。旧 [`EventHandler`](EventHandler.md) 仍适合简单的“先于子树、Bool 消费”兼容场景；新交互、手势和组件级快捷键优先使用本类型。

## 声明

```cangjie
public class EventListener <: Widget
```

## 构造函数

```cangjie
public init(
    phase!: EventPhase = EventPhase.Bubble,
    scope!: EventScope = EventScope.Subtree,
    onEvent!: (UiContext, UiEvent) -> EventOutcome,
    body!: () -> Unit
)
```

**参数**

- `phase!`: [`EventPhase`](EventPhase.md) — 在子树之前捕获、目标边界处处理，或在子树之后冒泡。
- `scope!`: [`EventScope`](EventScope.md) — 默认只观察几何/焦点命中本子树的事件；`Global` 用于应用级快捷键。
- `onEvent!`: `(UiContext, UiEvent) -> EventOutcome` — 返回独立的“已处理”和“停止传播”效果。
- `body!`: `() -> Unit` — 被监听的真实 Widget 子树。

指针事件按监听器最近一次布局矩形命中；键盘、文本和输入法事件按子树焦点命中。框架会保留焦点目标的内部身份，因此不同
子树即使使用相同的公开 key，也不会收到彼此的事件。拖动开始后，后续移动和释放仍沿原路径传播。窗口级事件也可由局部
监听器观察；帧更新由帧订阅系统处理，不参与这套可停止的输入传播。

## 使用方式

外层监听器可在 `Capture` 阶段记录事件并返回 `Continue`，内层监听器再在 `Bubble` 阶段更新手势并返回 `Handled`。
将 `Button` 放在内层 `body` 中，就能按捕获、目标、冒泡顺序处理同一路径。

`Handled` 使事件不再落到后方兄弟，但仍允许同一路径的后续阶段运行；`StopPropagation` 停止路径但不额外标记业务处理；`Consume` 同时应用两者。

单个组件也可在声明后紧接 `.onEvent(phase: ..., handler: ...)`，或通过 [`Modifier.onEvent`](Modifier.md) 复用事件配置。
紧邻调用时，包装器能保留该次声明的焦点身份；若保存组件后再跨构建复用，只能按公开焦点 key 匹配。

## 转发契约

`measure`、`layout`、`draw`、flex、stretch、可见布局、Portal 脱离布局和焦点项均透明转发给子树。`handle` 是唯一增加语义的方法。

## 另请参阅

- [`EventOutcome`](EventOutcome.md) — 事件处理与停止传播的组合结果。
- [`EventHandler`](EventHandler.md) — Bool 消费式兼容包装。
- [焦点、事件与浮层](../../../guide/concepts/focus-events-and-overlays.md) — 路由、焦点和 Portal 的组合方式。
