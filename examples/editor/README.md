# editor：写作空间

以纸面为中心的文本编辑器：页头突出“记录检查点”，文档菜单、视图选项和编辑命令分区，
降低外围操作的视觉重量。集中演示 `MenuBar`、`TextArea`、修改状态与可取消的关闭确认。
检查点仅在当前会话内有效，不写入文件。

## 演示要点

- `MenuBar` 横排文档／插入／更多三个顶层菜单，点击标题展开下拉（浮于正文之上）
- 菜单打开时，指针滑过其他标题即切换菜单（经典菜单栏手感）；点当前标题收起、外点或 Esc 关闭
- 使用 `MenuItem.separator()` 分隔线；示例不展示尚未实现的应用快捷键提示
- 动态启用/禁用：菜单从当前模型构建，“清空草稿”在文档为空时自动置灰
- 键盘：`Tab` 聚焦菜单栏后 `←→` 移动标题、`Enter/Space/↓` 打开；打开后 `↑↓` 移动高亮（跳过分隔线与禁用项）、
  `←→` 切换菜单、`Enter` 执行、`Esc` 关闭
- 动作作用于模型：新建/清空改写正文，追加日期（复用 `CalendarDate.today().iso()`）/分隔线在末尾追加，
  关于更新状态栏；记录检查点更新内存副本，退出经过可取消确认；`TextArea` 双向绑定 `model.text`，菜单改动即刻反映到编辑区
- 状态栏显示上次动作与由 `map` 派生的实时行数、字数
- 底部工具栏提供全选、复制、剪切、粘贴、撤销／重做；只读与换行等设置放在上方。命令操作当前选区，按钮取得焦点后仍有效
- 提供自动换行／宽松行距切换和 Emoji 种子文字；关闭软换行时长行横向跟随光标；Shift 点击扩展选区，Ctrl + 左右键／退格／Delete 按词段操作，上下移动记住像素列

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | 种子文本、字符数（按码点、去换行）与行数纯函数 |
| [model.cj](src/model.cj) | `EditorModel`：正文、状态、派生行数/字数，菜单动作方法 |
| [views.cj](src/views.cj) | 菜单构建（含动态禁用）、菜单栏、编辑区、状态栏 |
| [theme.cj](src/theme.cj) | 浅灰底 + 靛蓝强调色主题 |

## 关键实现

### 从当前状态构建菜单

`MenuBar` 接收一个 `Array<Menu>`，视图从模型构建它，菜单项启用状态随模型变化：

```cangjie
let hasText = !model.isEmpty()
Menu("文档", [
    MenuItem("记录检查点", {=> model.save()}),
    MenuItem("清空", {=> model.clear()}, enabled: hasText),
    MenuItem.separator(),
    MenuItem("退出", {=> model.quit()})
])
```

菜单栏的打开／高亮状态按其身份跨帧保留，重建菜单数据不会丢失交互状态。

### 与 ContextMenu 共享菜单基础设施

`MenuBar` 与 `ContextMenu` 使用同一个 `MenuItem` 类型和同一套弹层渲染、命中、导航逻辑（标签、快捷键、
分隔线、禁用置灰、跳过不可选中项）。因此两处菜单外观与手感一致，新增能力一处受益、两处生效。

## 运行

工具栏直接使用控件命令，无需自行处理 UTF-8 偏移和剪贴板异常：

```cangjie
VStack {
    let editor = TextArea(model.text, key: "document", editable: !model.readOnly.value)
    HStack {
        Button("全选", {=> editor.selectAll()})
        Button("复制", {=>
            model.status.value = if (editor.copy()) { "已复制" } else { "没有选区或剪贴板不可用" }
        })
        Button("撤销", {=> editor.undo()}).enabled(editor.canUndo())
    }.hug()
}
```

编辑区的标准快捷键由 TextArea 处理；MenuItem 的 `shortcut` 仍只是菜单提示。模型里的新建、追加等操作直接写入正文，会重置旧编辑历史；需要可撤销的应用编辑可使用 `editor.replaceSelection(...)`。只读约束限制控件编辑，不阻止应用切换文档。

组合字符与 emoji 按完整字素选择和删除；剪切仅在成功复制后删除，空／失败剪贴板保留选区。更多规则见 [文本编辑指南](../../docs/guide/how-to/text-editing.md)。

```powershell
cd examples/editor
cjpm run
```

点击文档卡片中的菜单标题展开；清空文档后，“更多”菜单中的“清空草稿”会置灰。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot editor.bmp"
```


### 关闭确认

系统关窗与菜单退出都经过 `DesktopApp.setCloseRequestHandler`。正文相对内存检查点有修改时，Modal 默认聚焦“继续编辑”；可以记录检查点后退出、放弃或取消，点击背景不会误关。这里的检查点只保存在内存，**没有写入文件**。实际文件应用应在保存成功后调用 `CloseRequest.accept()`，保存失败时保留确认界面或取消请求。详见[生命周期指南](../../docs/guide/how-to/desktop-lifecycle.md)。

### 编辑器样式与 Emoji

正文使用 `.wrap(value: model.wrapLines.value)`、`.placeholder(...)` 和 `.style(TextInputStyle(lineHeight: ..., padding: ...))`；字体为 18 fp，普通行高 28 fp、宽松行高 38 fp。字体、行高和内边距共同参与排版与交互，无需手算光标位置。关闭软换行再打开不会改变文档或撤销历史。

“常亮光标”演示 `cursorBlinkIntervalMs: UInt64(0)`；默认每 530 ms 切换亮／暗。光标围绕字体参考墨迹中心对齐，可通过 `cursorHeight` 独立设置高度。多行选区默认止于实际内容（包含真实空格），空行显示窄条；需要铺满行尾时使用 `selectionWidth: TextSelectionWidth.Viewport`。

按住鼠标拖选至编辑区外并保持指针静止，可持续滚动选择；松开或到达文档边界后停止。关闭换行后也可横向拖选长行。空闲闪烁复用既有布局，在支持保留场景目标的后端只更新光标附近像素；选中正文和 IME 预编辑不会产生无效闪烁。

输入法可直接提交 🎉 等 Emoji，默认按需使用系统后备字体。组合字符和 Emoji ZWJ 整簇移动、选择与删除；具体图形取决于系统字体版本。试验 Home／End、PageUp／PageDown、Shift 选区，再使用工具栏复制／撤销。新建空文档可看到占位提示；开启只读仍可选择／复制，但不会激活输入法。更多外观及单行提交示例见[文本编辑指南](../../docs/guide/how-to/text-editing.md)。

同行 Emoji 按实际字体片段基线与正文对齐，不需要在应用层手工上移；切换行距不会改变 Emoji 相对正文的位置。见[混排与输入规则](../../docs/guide/how-to/text-editing.md)。

种子文字中的 `👩🏽‍💻` 是一个组合表情；在支持它的系统字体下，应显示一个程序员，而不是额外的头像。可选中它，在行尾连续粘贴并撤销，检查每组外观一致、光标一次跨过一组。要体验独立选择，可输入 `👩🏽 💻`。自动换行和字号／行距设置都保留原始文本。

## 练习与验收

修改正文后分别继续编辑、记录检查点和放弃退出，检查 dirty 与关闭状态。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
