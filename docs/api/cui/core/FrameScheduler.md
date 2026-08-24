[cui.core](index.md) › FrameScheduler

# FrameScheduler

```cangjie
public class FrameScheduler
```

每个应用独立的状态失效协调器。它把同一输入、回调或批处理中的多次状态写合并为一次代数推进，并以原子所有权声明保证并发首次访问只有一个 UI 线程成功，避免数据竞争、线程标识复用和多个窗口相互污染脏帧判断。

该类型的调度操作为 `protected`，主要供自定义桌面宿主复用；普通应用通过 [`DesktopApp.batch`](../desktop/DesktopApp.md#batch) 与 [`DesktopApp.post`](../desktop/DesktopApp.md#post) 使用事务和跨线程投递。
