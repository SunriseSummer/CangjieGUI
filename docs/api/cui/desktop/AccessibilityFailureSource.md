[cui](../../index.md) › [cui.desktop](index.md) › AccessibilityFailureSource

# AccessibilityFailureSource

位于 `cui.desktop` 包的公开枚举

标识被独立隔离的无障碍效果分支。

```cangjie
public enum AccessibilityFailureSource {
    | NativeBridge
    | ExternalAdapter
    | FailureHandler
}
```

- `NativeBridge`：操作系统原生 provider。
- `ExternalAdapter`：应用通过 `setAccessibilityAdapter` 安装的观察器。
- `FailureHandler`：应用安装的故障通知回调；该回调抛异常时会自动卸载，但原始分支仍按既定策略隔离。
