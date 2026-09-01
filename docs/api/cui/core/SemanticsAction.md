[cui](../../index.md) › [cui.core](index.md) › SemanticsAction

# SemanticsAction

平台无关的无障碍动作枚举：`Activate`、`Focus`、`Increment`、`Decrement` 和携带字符串的 `SetValue(String)`。平台适配器或测试通过 [`UiContext.performSemanticsAction`](UiContext.md#performsemanticsaction) 请求动作，控件仍复用鼠标/键盘对应的同一状态操作。
