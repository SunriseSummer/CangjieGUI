package cui_notepad

import cui.{Button, ButtonRole, Checkbox, CrossAxisAlignment, DesktopApp, Divider, EventHandler}
import cui.{Flexible, FlowRow, FontWeight, HStack, Icon, IconSource, Label, LengthInsets, LengthUnits}
import cui.{Panel, Spacer, TextArea, TextInputStyle, TextStyle, Tooltip, VStack}

func notepadView(model: NotepadModel, app: DesktopApp, documentPath: String): Unit {
    subscribeNotepadDialogs(model)
    EventHandler(onEvent: {ctx, event => handleNotepadEvent(ctx, event, model, app, documentPath)}) {
        VStack {
            HStack {
                Icon(IconSource("assets/icons/document.svg")).iconSize(NOTEPAD_ICON).foregroundColor(NOTEPAD_ACCENT)
                VStack {
                    Label("记事本").fontSize(NOTEPAD_TITLE).fontWeight(FontWeight.semiBold)
                    Label("简洁记录，从容保存").muted().fontSize(NOTEPAD_COMMAND)
                }.spacing(3.vp).hug()
                Spacer()
                Button("保存文件", {=> saveCurrentFile(model, documentPath)})
                    .key("notepad-save")
                    .role(ButtonRole.Primary)
                    .fontSize(NOTEPAD_PRIMARY)
            }.spacing(NOTEPAD_GAP).crossAxisAlignment(CrossAxisAlignment.Center).hug()
            Panel {
                VStack {
                    documentHeading(model)
                    Divider()
                    toolbar(model, app, documentPath)
                    if (model.confirmingNew.value) {
                        confirmNewBar(model)
                    }
                    let editor = TextArea(model.body, key: "notepad-document", scroll: model.bodyScroll,
                        cursor: model.bodyCursor, anchor: model.bodyAnchor, editable: !model.readOnly.value)
                        .style(
                            TextInputStyle(padding: LengthInsets(10.vp), lineHeight: NOTEPAD_LINE_HEIGHT,
                                surface: notepadPaper()))
                        .placeholder("写下第一行文字…")
                    Divider()
                    HStack {
                        Button("复制全文", {=> copyAll(model.body, model.status)})
                            .key("notepad-copy-all")
                            .enabled(!model.body.value.isEmpty())
                        Button("粘贴", {=> reportPaste(model, editor.paste())})
                            .key("notepad-paste")
                            .enabled(!model.readOnly.value)
                        Spacer()
                        Label("UTF-8").muted().fontSize(NOTEPAD_CAPTION)
                    }.spacing(4.vp).hug().textStyle(TextStyle(fontSize: NOTEPAD_COMMAND))
                }.spacing(8.vp)
            }.contentPadding(NOTEPAD_CARD_INSET).style(toolbarSurface()).flex()
            statusBar(model)
        }.spacing(NOTEPAD_SECTION_GAP).padding(NOTEPAD_PAGE_INSET)
    }
}

private func documentHeading(model: NotepadModel): Unit {
    HStack {
        Flexible {
            Tooltip(text: model.currentPath.value) {
                Label(documentName(model)).fontSize(NOTEPAD_DOCUMENT_TITLE).fontWeight(FontWeight.semiBold)
            }
        }
        Label(if (model.dirty.value) {
            "未保存修改"
        } else if (model.currentPath.value.isEmpty()) {
            "空白文档"
        } else {
            "已保存"
        }).fontSize(NOTEPAD_CAPTION).foregroundColor(NOTEPAD_ACCENT)
    }.spacing(NOTEPAD_GAP).crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

func toolbar(model: NotepadModel, app: DesktopApp, documentPath: String): Unit {
    FlowRow {
        Button("新建", {=> newFile(model)}).key("notepad-new")
        Button("打开", {=> openFile(model, app)}).key("notepad-open")
        Button("另存为", {=> saveFileAs(model, app, documentPath)}).key("notepad-save-as")
        Checkbox("只读", model.readOnly)
    }.spacing(8.vp).textStyle(TextStyle(fontSize: NOTEPAD_COMMAND))
}

func confirmNewBar(model: NotepadModel): Unit {
    Panel {
        VStack {
            Label("当前修改尚未保存，是否新建空白文档？").wrap().fontSize(NOTEPAD_PRIMARY)
            FlowRow {
                Button("继续编辑", {=> cancelNewFile(model)}).key("notepad-cancel-new")
                Button("丢弃并新建", {=> confirmDiscardAndNew(model)}).role(ButtonRole.Danger)
            }.spacing(8.vp).textStyle(TextStyle(fontSize: NOTEPAD_COMMAND))
        }.spacing(6.vp).hug()
    }.contentPadding(NOTEPAD_GAP).style(confirmBarSurface()).hug()
}

private func reportPaste(model: NotepadModel, changed: Bool): Unit {
    model.status.value = if (changed) {
        "已粘贴"
    } else {
        "没有可粘贴的文本，或剪贴板不可用"
    }
}

func statusBar(model: NotepadModel): Unit {
    HStack {
        Flexible {Label(model.status.value).muted().fontSize(NOTEPAD_CAPTION)}
        Label(model.stats.value).muted().fontSize(NOTEPAD_CAPTION)
    }.spacing(NOTEPAD_GAP).hug()
}

func documentName(model: NotepadModel): String {
    let path = model.currentPath.value
    if (path.isEmpty()) {
        return "未命名文档"
    }
    let parts = path.replace("\\", "/").split("/")
    parts[parts.size - 1]
}
