[cui](../../index.md) › [cui.core](index.md) › EventPhase

# EventPhase

位于 `cui.core` 包的公开枚举

```cangjie
public enum EventPhase {
    | Capture
    | Target
    | Bubble
}
```

- `Capture`：在命中子树处理之前运行，适合策略、审计和手势仲裁。
- `Target`：在显式目标包装边界处理；适合把自定义绘制节点变成事件目标。
- `Bubble`：子树处理之后运行，即使目标已标记 `Handled` 仍可观察，除非路径被停止。

嵌套监听器按外层 Capture → Target/控件 → 内层到外层 Bubble 的顺序执行。

## 另请参阅

- [`EventListener`](EventListener.md)
- [`EventOutcome`](EventOutcome.md)
