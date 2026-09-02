[cui.core](index.md) › FrameScheduler

# FrameScheduler

```cangjie
public class FrameScheduler {
    public init()
}
```

每个应用使用一个状态更新调度器。它把同一输入事件、回调或 `batch` 中的多次状态写合并为一次提交：先通知直接变化的
`State`，再运行去重后的派生观察者；观察者产生的新写入继续在本次事务中处理，直到没有新变化。观察者中嵌套的
`batch` 会加入当前事务，不会递归派发。

观察者或状态策略抛错时，调度器记住第一个异常，同时完成已经排队的其他通知，最后再报告错误。只有内部状态损坏或更新
无法在安全上限内稳定时才会立即终止。

带 [`StateMutationPolicy`](StateMutationPolicy.md) 的状态会比较事务开始值与结束值；两端等价时不通知，也不安排空帧。
默认 `State` 仍把每次赋值视为变化。状态首次进入应用时会绑定 UI 线程和调度器；同一状态不能同时由多个窗口或线程修改。

该类型的调度操作为 `protected`，主要供自定义桌面宿主复用；普通应用通过 [`DesktopApp.batch`](../desktop/DesktopApp.md#batch) 与 [`DesktopApp.post`](../desktop/DesktopApp.md#post) 使用事务和跨线程投递。
