package cui_editor

import cui.{Button, ButtonRole, Checkbox, CrossAxisAlignment, Divider, Flexible, FlowRow, FontWeight}
import cui.{HStack, Icon, IconSource, Label, LengthInsets, LengthUnits, Menu, MenuBar, MenuItem, Modal}
import cui.{Panel, Spacer, TextArea, TextInputStyle, TextStyle, VStack}

// Presentation stays in the view; document/checkpoint state stays in EditorModel.
func editorView(model: EditorModel): Unit {
    VStack {
        editorHeader(model)
        editorPanel(model)
        statusBar(model)
    }.spacing(10.vp).padding(16.vp)
    closeConfirmation(model)
}

private func editorHeader(model: EditorModel): Unit {
    HStack {
        Icon(IconSource("assets/icons/document.svg")).iconSize(24.vp).foregroundColor(EDITOR_ACCENT)
        Flexible {
            VStack {
                Label("写作空间").fontSize(20.fp).fontWeight(FontWeight.semiBold)
                Label("让想法有处安放").muted().fontSize(11.fp)
            }.spacing(3.vp).hug()
        }
        Button("记录检查点", {=> model.save()}).key("editor-checkpoint").role(ButtonRole.Primary).fontSize(13.fp)
    }.spacing(12.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

func editorPanel(model: EditorModel): Unit {
    Panel {
        VStack {
            HStack {
                Label("灵感草稿").fontSize(15.fp).fontWeight(FontWeight.semiBold)
                Spacer()
                Label(if (model.dirty.value) {
                    "有未记录修改"
                } else {
                    "已记录检查点"
                }).foregroundColor(EDITOR_ACCENT).fontSize(11.fp)
            }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
            Divider()
            MenuBar(buildMenus(model)).textStyle(TextStyle(fontSize: 12.fp))
            FlowRow {
                Checkbox("自动换行", model.wrapLines)
                Checkbox("宽松行距", model.spaciousLines)
                Checkbox("光标常亮", model.steadyCaret)
                Checkbox("只读", model.readOnly)
            }.spacing(8.vp).textStyle(TextStyle(fontSize: 12.fp))
            let editor = TextArea(model.text, key: "document", editable: !model.readOnly.value)
                .wrap(value: model.wrapLines.value)
                .placeholder("从第一句话开始…")
                .style(
                    TextInputStyle(lineHeight: if (model.spaciousLines.value) {
                        38.fp
                    } else {
                        28.fp
                    }, padding: LengthInsets(8.vp), surface: editorPaper(),
                        cursorBlinkIntervalMs: if (model.steadyCaret.value) {
                            UInt64(0)
                        } else {
                            UInt64(530)
                        }))
            editor.textStyle(TextStyle(fontSize: 18.fp))
            Divider()
            editingActions(model, editor)
        }.spacing(6.vp)
    }.contentPadding(12.vp).style(editorCard()).flex()
}

// Commands use this mounted editor, retaining selection and undo grouping.
private func editingActions(model: EditorModel, editor: TextArea): Unit {
    let selected = !editor.selectedText().isEmpty()
    FlowRow {
        Button("全选", {=> editor.selectAll()}).key("editor-select-all")
        Button("复制", {=> reportCommand(model, editor.copy(), "复制")}).key("editor-copy").enabled(selected)
        Button("剪切", {=> reportCommand(model, editor.cut(), "剪切")})
            .key("editor-cut")
            .enabled(!model.readOnly.value && selected)
        Button("粘贴", {=> reportCommand(model, editor.paste(), "粘贴")})
            .key("editor-paste")
            .enabled(!model.readOnly.value)
        Button("撤销", {=> editor.undo()}).key("editor-undo").enabled(editor.canUndo())
        Button("重做", {=> editor.redo()}).key("editor-redo").enabled(editor.canRedo())
    }.spacing(2.vp).textStyle(TextStyle(fontSize: 12.fp))
}

private func reportCommand(model: EditorModel, changed: Bool, name: String): Unit {
    model.status.value = if (changed) {
        "已${name}"
    } else {
        "${name}未执行，请检查选区或剪贴板"
    }
}

func buildMenus(model: EditorModel): Array<Menu> {
    [
        Menu("文档",
            [MenuItem("新建草稿", {=> model.newDoc()}), MenuItem("记录检查点", {=> model.save()}), MenuItem.separator(),
                MenuItem("退出", {=> model.quit()})]),
        Menu("插入", [MenuItem("今天的日期", {=> model.appendDate()}), MenuItem("分隔线", {=> model.appendRule()})]),
        Menu("更多",
            [MenuItem("清空草稿", {=> model.clear()}, enabled: !model.isEmpty()),
                MenuItem("关于此示例", {=> model.about()})])
    ]
}

private func closeConfirmation(model: EditorModel): Unit {
    Modal(model.closePresented, initialFocus: "close-cancel", dismissOnBackdrop: false,
        onDismiss: {=> model.cancelClose()}) {
        VStack {
            Label("保留这次修改？").fontSize(19.fp)
            Label("检查点只保存在内存中，退出后不会生成文件。").muted().wrap().fontSize(13.fp)
            FlowRow {
                Button("记录后退出", {=> model.acceptClose(checkpointFirst: true)}).role(ButtonRole.Primary)
                Button("放弃修改", {=> model.acceptClose()})
                Button("继续编辑", {=> model.cancelClose()}).key("close-cancel")
            }.spacing(8.vp).textStyle(TextStyle(fontSize: 13.fp))
        }.spacing(14.vp)
    }
}

func statusBar(model: EditorModel): Unit {
    HStack {
        Flexible {Label(model.status.value).muted().fontSize(11.fp)}
        Label("${model.lines.value} 行  ·  ${model.chars.value} 字").muted().fontSize(11.fp)
    }.spacing(12.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
}
