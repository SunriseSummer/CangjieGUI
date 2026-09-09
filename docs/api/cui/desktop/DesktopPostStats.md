[cui](../../index.md) › [cui.desktop](index.md) › DesktopPostStats

# DesktopPostStats

`DesktopApp.postStats()` 返回的只读快照，无公开构造器。计数从应用创建开始累计。

```cangjie
public struct DesktopPostStats
```

| 字段 | 类型 | 含义 |
|---|---|---|
| `pending` | `Int64` | 已接收、尚未开始执行的动作数，不含正在执行的动作 |
| `highWatermark` | `Int64` | 等待队列历史峰值 |
| `rejected` | `UInt64` | 队列满或停止后被拒绝的投递次数 |
| `wakeFailures` | `UInt64` | 已接收动作但 SDL 唤醒失败的次数 |

高水位持续接近容量时，应合并更新、降低生产速率或在业务层重试。增大容量不能解决长时间阻塞的 UI 回调。
