[cui](../../index.md) › [cui.desktop](index.md) › AccessibilityFailureOperation

# AccessibilityFailureOperation

`cui.desktop` 包中的 public enum

标识无障碍失败发生的边界操作。

```cangjie
public enum AccessibilityFailureOperation {
    | Update
    | DrainActions
    | ReportFailure
}
```

- `Update`：提交 revisioned 语义快照或增量。
- `DrainActions`：把原生线程排队的动作带回 UI 线程。
- `ReportFailure`：调用应用故障回调。
