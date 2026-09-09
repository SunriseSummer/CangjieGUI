[cui](../../index.md) › cui.desktop

# cui.desktop

```cangjie
import cui.desktop.*
```

桌面应用包。[`DesktopApp`](DesktopApp.md) 拥有 SDL 窗口和按需帧循环，负责事件、状态事务、增量更新、资源清理与 UI 线程边界。它还提供后台动作投递、系统文件对话框、基础光标、无障碍故障隔离和最小窗口尺寸。

应用空闲时会阻塞等待，不持续占用渲染资源。`--snapshot`、`--profile` 和增量/全量对照开关用于测试与排错。

## 类型

**类**

| 类型 | 说明 |
|---|---|
| [`AccessibilityFailure`](AccessibilityFailure.md) | 一个原生桥、外部观察器或故障回调被隔离后的结构化诊断。 |
| [`DesktopApp`](DesktopApp.md) | 拥有 SDL 窗口，按依赖执行必要的构建、布局、事件和绘制工作。 |

**枚举**

| 类型 | 说明 |
|---|---|
| [`AccessibilityFailureSource`](AccessibilityFailureSource.md) | 无障碍失败来源。 |
| [`AccessibilityFailureOperation`](AccessibilityFailureOperation.md) | 无障碍失败发生的边界操作。 |

| 新增类型 | 说明 |
|---|---|
| [CloseRequest](CloseRequest.md) | 可接受或取消的未决关闭请求。 |
| [DesktopPostStats](DesktopPostStats.md) | 后台动作队列的只读诊断快照。 |
