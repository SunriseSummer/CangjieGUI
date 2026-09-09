[cui](../../index.md) › [cui.desktop](index.md) › CloseRequest

# CloseRequest

由 DesktopApp 创建的一次关闭请求，应用不能自行构造。只能在 UI 线程读取或完成；处理器可以保留它，等待模态确认或后台保存结果。

```cangjie
public class CloseRequest
public func isPending(): Bool
public func accept(): Unit
public func cancel(): Unit
```

- `isPending()`：请求是否仍等待决定。
- `accept()`：接受关闭，进入正常资源清理。
- `cancel()`：取消这次关闭，允许后续重新请求。

第一次决定生效，重复决定无操作。应用停止或处理器异常后，请求失效；此后完成请求不会关闭其它窗口。后台保存完成后应通过 `app.post` 回到 UI 线程处理结果，投递被拒绝时不要直接从后台调用请求。

参见 [DesktopApp](DesktopApp.md)、[生命周期指南](../../../guide/how-to/desktop-lifecycle.md)。
