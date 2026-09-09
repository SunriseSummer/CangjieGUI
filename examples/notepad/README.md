# notepad：记事本

青绿主题的文件编辑示例。页头提供主要动作“保存文件”，纸面内部使用紧凑文件工具栏，
正文和编辑命令分区；文件名、修改状态与字节统计随文档更新。实际读写 UTF-8 文件。

## 演示要点

- `TextArea` 负责选区、光标、输入法、剪贴板与撤销；工具栏粘贴调用同一个编辑器的 `paste()`。
- “复制全文”明确复制整个缓冲区；键盘复制／剪切只处理当前选区。
- `dirty` 从正文与最近成功保存／载入的副本派生。修改后再撤回原文，状态自动恢复干净。
- 有未保存修改时，新建先展示应用内确认条；干净文档可直接新建。
- 对话框只在请求未结束时注册帧订阅，并约每 50 ms 请求一次检查；空闲时无对话框轮询。
- 文件名从路径提取，完整路径由 `Tooltip` 展示；状态文案用 `Flexible`，避免挤压统计。

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 桌面窗口、偏好目录与运行入口 |
| [model.cj](src/model.cj) | 正文、选区、文件路径、修改状态与派生统计 |
| [views.cj](src/views.cj) | 页头、工具栏、确认条、纸面与状态栏 |
| [dialogs.cj](src/dialogs.cj) | 异步对话框请求、按需订阅与结果处理 |
| [file_actions.cj](src/file_actions.cj) | 新建、保存、载入与拖放文件处理 |
| [clipboard_actions.cj](src/clipboard_actions.cj) | 显式复制全文 |
| [shortcuts.cj](src/shortcuts.cj) | 文件级快捷键；编辑快捷键交给 TextArea |
| [theme.cj](src/theme.cj) | 主题、表面、应用元数据与 SDL 提示 |

## 关键实现

### 编辑命令保留历史

```cangjie
let editor = TextArea(model.body, key: "notepad-document",
    cursor: model.bodyCursor, anchor: model.bodyAnchor, editable: !model.readOnly.value)
Button("粘贴", {=> editor.paste(); ()}).enabled(!model.readOnly.value)
```

粘贴使用当前选区，可通过 Ctrl+Z 撤销。外部加载或新建属于文档替换，需同步设置光标、锚点与滚动位置；
不要用手工拼接字符串实现工具栏粘贴，否则会绕过编辑命令与历史。

### 按需处理对话框

`subscribeNotepadDialogs(model)` 在同一构建作用域内检查请求状态。只有存在请求时才调用
`subscribeFrame`，通过 `FileDialogRequest.result()` 处理待完成、取消、失败与选中文件。
结果处理后清除请求，下一次构建移除订阅。文档控件不放进条件创建的 `FrameHandler`，
因此打开对话框不会改变正文子树身份。

### 保存状态与失败路径

写入成功后才更新路径并调用 `markSaved()`，同时收起已失效的新建确认；写入／读取失败保留正文、旧路径和修改标记。
首次保存使用应用偏好目录中的默认路径，“另存为”允许选择位置。只读约束限制正文编辑，
不阻止应用载入或切换文档。本例的新建确认不等同于完整的多文档防丢失流程；
系统关闭确认的教学示例见 [editor](../editor/README.md)。

## 运行与验证

```powershell
cd examples/notepad
cjpm test
cjpm run
cjpm run --run-args "--snapshot notepad.bmp"
```

文件快捷键：Ctrl/Cmd+N 新建、O 打开、S 保存、Shift+S 另存为；修饰键读取事件时刻快照。
编辑区使用标准选择、复制、剪切、粘贴和撤销／重做快捷键。
自动化回归覆盖文件往返、失败后保留修改、回到原文后恢复干净状态、新建确认、路径提取及空闲订阅数。

## 练习与验收

打开并修改一个测试文件，另存后重新读取，验证正文一致。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
