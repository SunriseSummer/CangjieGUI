[cui](../../index.md) › [cui.text](index.md) › TextClipboard

# TextClipboard

纯文本剪贴板适配器。TextField、TextArea 默认使用共享的 `system` 实例，也可注入自己的读写函数，用于自定义宿主和确定性测试。

```cangjie
public class TextClipboard
public static let system: TextClipboard
public init(read!: () -> String = {=> Clipboard.getText()},
    write!: (String) -> Unit = {value => Clipboard.setText(value)})
public func readText(): ?String
public func writeText(value: String): Bool
```

`readText` 返回 `Some(文本)`，包括表示无可用文本的 `Some("")`；平台失败或包含 NUL 时返回 `None`。`writeText` 成功返回 `true`；包含 NUL 时先拒绝，不调用宿主写入函数。

读写函数抛出的 `SdlException`、`IllegalArgumentException` 转换为失败结果；其它异常继续传播，便于暴露宿主实现错误。系统后端沿用 SDL 的 UI 线程与桌面会话约束；二进制数据使用上游 `Clipboard.setData`。

```cangjie verify
package docexample

import cui.{State, TextClipboard, TextField}

main(): Unit {
    let buffer = State<String>("")
    let clipboard = TextClipboard(read: {=> buffer.value}, write: {value => buffer.value = value})
    let field = TextField(State<String>("仓颉 e\u{0301}"), clipboard: clipboard)
    field.selectAll()
    if (field.copy()) { println(buffer.value) }
}
```

控件的 `copy`、`cut`、`paste` 会检查结果：写入失败不剪切，读取失败或空剪贴板不删除选区。详见 [文本编辑指南](../../../guide/how-to/text-editing.md)。
