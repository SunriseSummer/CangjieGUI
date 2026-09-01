[cui.core](index.md) › FrameScheduler

# FrameScheduler

```cangjie
public class FrameScheduler
```

每个应用独立的状态失效协调器。它把同一输入、回调或批处理中的多次状态写合并为一次代数推进，并把直接状态通知与派生观察者分层稳定：先排空源通知，再执行去重的派生观察者，观察者产生的新写入继续进入同一事务，直到不动点。观察者或端点策略失败时保留最先发生的异常，但仍继续其他 State、Derived continuation 和失败前产生的新写入；稳定后统一报告，确保依赖失效不会被业务错误饿死。只有内部队列不变量损坏或超过收敛上限才立即终止。观察者中嵌套的 batch 加入当前 flush，不递归派发。

带显式 [`StateMutationPolicy`](StateMutationPolicy.md) 的 State 在提交时比较事务首尾；同一等价类中的净零路径不通知、不推进应用 generation。端点证明保存在本调度器的 pending frontier；稀疏事务用集合与最后项快路，多 State 交错重复时才建立索引。类型擦除通知槽由对应 State 惰性持有并跨事务复用，调度器仍独占每个 pending segment。默认 State 仍把赋值视作事件，保持既有行为。端点策略失败时已提交写入会保守推进 generation。原子所有权声明保证并发首次访问只有一个 UI 线程成功，避免数据竞争、线程标识复用和多个窗口相互污染脏帧判断。同线程 State 只能在旧调度器空闲时顺序转交，不能跨尚未提交的嵌套应用事务。

该类型的调度操作为 `protected`，主要供自定义桌面宿主复用；普通应用通过 [`DesktopApp.batch`](../desktop/DesktopApp.md#batch) 与 [`DesktopApp.post`](../desktop/DesktopApp.md#post) 使用事务和跨线程投递。
