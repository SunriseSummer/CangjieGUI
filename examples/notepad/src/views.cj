/*
 * 记事本视图层：工具栏、“新建”确认条、正文编辑区与状态栏。
 *
 *  - “新建”确认条渲染在工具栏下方，代替会阻塞事件循环的系统弹窗；
 *    只在等待用户决定时出现，交互与打开/保存的异步模式保持一致
 *  - 状态栏的文件路径包在 Flexible 里：独占剩余宽度并自动省略号截断，
 *    行数/字节统计因此永远不会被长路径挤出窗口
 *  - 尺寸一律使用 vp/fp 单位；按钮与复选框依赖框架自动分配的构建期唯一标识
 */
package cui_notepad

import cui.{Axis, Button, ButtonRole, Checkbox, DesktopApp, Divider, EventHandler, Flexible, FontSizes, HStack,
    IconButton, IconName, Label, LengthUnits, Panel, Spacer, TextAlign, TextArea, Tooltip, VStack}

func notepadView(model: NotepadModel, app: DesktopApp, documentPath: String): Unit {
    EventHandler(onEvent: {event => handleNotepadEvent(event, model, app, documentPath)}) {
        VStack {
            toolbar(model, app, documentPath)
            if (model.confirmingNew.value) {
                confirmNewBar(model)
            }
            // editable 是构造参数（而非修饰符）：TextArea 在构造时即决定是否注册 Tab 焦点，
            // 因此只读编辑器不会进入焦点遍历序列。
            TextArea(
                "notepad.body",
                model.body,
                scroll: Some(model.bodyScroll),
                cursor: Some(model.bodyCursor),
                anchor: Some(model.bodyAnchor),
                editable: !model.readOnly.value
            )
            statusBar(model)
        }.spacing(10.vp).padding(14.vp)
    }
}

func toolbar(model: NotepadModel, app: DesktopApp, documentPath: String): Unit {
    Panel {
        HStack {
            Tooltip(text: "新建文档 · Ctrl+N") {
                IconButton(IconName.NewDocument) {
                    => newFile(model)
                }.label("新建")
            }
            Tooltip(text: "打开文件 · Ctrl+O") {
                IconButton(IconName.OpenFolder) {
                    => openFile(model, app)
                }.label("打开")
            }
            Divider().axis(Axis.Vertical)
            Tooltip(text: "保存 · Ctrl+S") {
                IconButton(IconName.Save) {
                    => saveCurrentFile(model, documentPath)
                }.label("保存").role(ButtonRole.Primary)
            }
            Tooltip(text: "另存为 · Ctrl+Shift+S") {
                IconButton(IconName.SaveAs) {
                    => saveFileAs(model, app, documentPath)
                }.label("另存为")
            }
            Divider().axis(Axis.Vertical)
            Tooltip(text: "复制全文") {
                IconButton(IconName.Copy) {
                    => copyAll(model.body, model.status)
                }.label("复制")
            }
            Tooltip(text: "在光标处粘贴") {
                IconButton(IconName.Paste) {
                    => pasteClipboard(model.body, model.bodyCursor, model.bodyAnchor, model.status)
                }.label("粘贴").enabled(!model.readOnly.value)
            }
            Spacer()
            Checkbox("只读", model.readOnly)
        }
    }.contentPadding(10.vp).style(toolbarSurface()).hug()
}

/*
 * “新建”确认条。不用系统 MessageBox 的原因：它同步阻塞事件循环，
 * 会让 FrameHandler 里打开/保存对话框的帧内轮询停摆；应用内确认条
 * 则完全由状态驱动，界面持续响应，用户也能先浏览正文再做决定。
 */
func confirmNewBar(model: NotepadModel): Unit {
    Panel {
        HStack {
            Label("当前内容尚未保存，确认丢弃并新建？")
            Spacer()
            Button("丢弃并新建", {=> confirmDiscardAndNew(model)}).role(ButtonRole.Danger)
            Button("取消", {=> cancelNewFile(model)})
        }.spacing(10.vp)
    }.contentPadding(12.vp, 8.vp).style(confirmBarSurface()).hug()
}

// 状态栏的所有内容都由模型状态派生，自身不存副本，因此不可能与文档脱节。
func statusBar(model: NotepadModel): Unit {
    HStack {
        Label(model.status.value).muted().fontSize(FontSizes.CAPTION)
        // 路径放进 Flexible：占据剩余宽度，过长时由 Label 单行自动省略号截断，
        // 右侧的行数/字节统计因此始终可见；路径靠右对齐以贴近统计信息。
        Flexible {
            Label(documentName(model)).muted().fontSize(FontSizes.CAPTION).textAlign(TextAlign.Trailing)
        }
        Label(model.stats.value).muted().fontSize(FontSizes.CAPTION)
    }.hug()
}

func documentName(model: NotepadModel): String {
    if (model.currentPath.value.size > 0) {
        model.currentPath.value
    } else {
        "未保存文档"
    }
}
