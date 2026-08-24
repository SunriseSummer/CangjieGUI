# notepad：记事本

一个中文记事本，演示桌面应用的完整外围能力：异步文件对话框、应用内确认条、剪贴板、
文件拖放、快捷键，以及由文本状态派生的统计栏。

## 演示要点

- 文件对话框的“发起请求、帧内轮询”异步模式，事件循环永不阻塞
- “新建”确认为何不用系统弹窗，而是状态驱动的应用内确认条
- `map` 派生文档统计（“| N 行 | M 字节 | UTF-8”），状态栏与内容始终同步
- 长路径在状态栏中用 `Flexible` 与自动省略号安全展示
- `EventHandler` 从 `UiContext.eventModifiers()` 读取事件时刻快照并分发文件级 Ctrl/Cmd 快捷键；
  `Ctrl+A/C/X/V` 下放给聚焦的 `TextArea`，由框架内建的多行选区
  剪贴板处理（选区复制与剪切、光标处粘贴、全选），工具栏“复制”按钮则显式复制全文
- `Ctrl+Z` 撤销、`Ctrl+Y`/`Ctrl+Shift+Z` 重做：由 `TextArea` 内建的时间合并撤销历史提供，
  连续键入整组回退，无需应用维护任何编辑历史
- 工具栏图标按钮用 `Tooltip` 包裹：悬停停留后显示动作说明与快捷键（如“保存 · Ctrl+S”）

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [model.cj](src/model.cj) | `NotepadModel`：缓冲区、路径、只读开关、确认条开关、派生统计 |
| [views.cj](src/views.cj) | 工具栏、确认条、编辑区、状态栏 |
| [dialogs.cj](src/dialogs.cj) | 打开/保存对话框的发起与逐帧轮询 |
| [file_actions.cj](src/file_actions.cj) | 新建/保存/加载与拖放落盘 |
| [clipboard_actions.cj](src/clipboard_actions.cj) | 复制/粘贴 |
| [shortcuts.cj](src/shortcuts.cj) | 文件级快捷键（Ctrl+N/O/S）；Ctrl+A/C/X/V 交由编辑区自身选区剪贴板处理 |
| [theme.cj](src/theme.cj) | 主题、元数据、SDL 提示与确认条警示表面 |

## 关键实现

### 应用内确认条（不阻塞事件循环）

系统 `showMessageBox` 是同步调用，弹出期间整个窗口停止刷新，与本应用“对话框帧内轮询”
的并发模型冲突。“新建”改为置起一个状态，由视图渲染警示条完成交互：

```cangjie
func newFile(model: NotepadModel): Unit {
    if (model.body.value.isEmpty()) { ... 直接新建 ... }
    model.confirmingNew.value = true      // 只是亮出确认条
}
```

视图中 `if (model.confirmingNew.value)` 渲染一条警示 Panel，“丢弃并新建”（Danger 角色）
与“取消”分别调用 `confirmDiscardAndNew` 与 `cancelNewFile`。

### 异步文件对话框

`app.openFileDialog()` 返回 `FileDialogRequest`；`dialogs.cj` 把未完成的请求存入模型，
每帧轮询 `isDone()`，完成后读取结果并清除，期间界面完全可交互。

### 派生统计栏

```cangjie
this.stats = this.body.map<String>({text => ... 行数与字节数 ...})
```

编辑任何字符，状态栏的“| N 行 | M 字节 | UTF-8”随下一帧自动更新，无需手工同步。

### 长路径不挤压统计

状态栏右侧路径 Label 包在 `Flexible` 中：独占剩余宽度、超宽自动省略号，
行数、字节数、编码标签始终可见。

## 运行

```powershell
cd examples/notepad
cjpm run
```

支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot notepad.bmp"
```
