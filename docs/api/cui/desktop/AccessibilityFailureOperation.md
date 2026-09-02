[cui](../../index.md) › [cui.desktop](index.md) › AccessibilityFailureOperation

# AccessibilityFailureOperation

位于 `cui.desktop` 包的公开枚举

标识无障碍失败发生的边界操作。

```cangjie
public enum AccessibilityFailureOperation {
    | Update
    | DrainActions
    | ReportFailure
}
```

- `Update`：提交带版本号的语义快照或增量。
- `DrainActions`：把原生线程排队的动作带回 UI 线程。
- `ReportFailure`：调用应用故障回调。
