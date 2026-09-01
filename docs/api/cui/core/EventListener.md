[cui](../../index.md) › [cui.core](index.md) › EventListener

# EventListener

`cui.core` 包中的 public class

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

指针事件以本包装最近一次 layout 的矩形命中；键盘、文本和 IME 事件以子树焦点项命中。body 构造形式会捕获带 Element generation 的焦点目标，所以监听器内外相同 public key 不会互相冒充；焦点项不超过 8 个时直接顺序比较，较大子树自动建立成员索引。拖动期间的移动/释放继续沿已开始的路径传播。窗口级事件在局部 scope 中也可观察；合成 Frame 脉搏仍由显式帧订阅系统处理，不进入可停止的输入传播。

## 示例

```cangjie
EventListener(phase: EventPhase.Capture, onEvent: {_, event =>
    audit(event)
    EventOutcome.Continue
}) {
    EventListener(phase: EventPhase.Bubble, onEvent: {_, event =>
        updateGesture(event)
        EventOutcome.Handled
    }) {
        Button("保存", {=> save()})
    }
}
```

`Handled` 使事件不再落到后方兄弟，但仍允许同一路径的后续阶段运行；`StopPropagation` 停止路径但不额外标记业务处理；`Consume` 同时应用两者。

单个刚声明的组件也可直接写 `.onEvent(phase: ..., handler: ...)`；builder 的 last-emission facet 会把它的 owner-preserving 焦点片段转交给透明包装，并可通过 [`Modifier.onEvent`](Modifier.md) 进入可复用管线。非紧邻修饰或在另一 build 中重新 emit 的 stored Widget 没有可证明的本次声明区间，此时保留 public focus id 兼容语义。

## 转发契约

`measure`、`layout`、`draw`、flex、stretch、可见布局、Portal 脱离布局和焦点项均透明转发给子树。`handle` 是唯一增加语义的方法。

## 另请参阅

- [`EventOutcome`](EventOutcome.md) — 传播效果的四元素代数。
- [`EventHandler`](EventHandler.md) — Bool 消费式兼容包装。
- [焦点、事件与浮层](../../../guide/concepts/focus-events-and-overlays.md) — 路由、焦点和 Portal 的组合方式。
