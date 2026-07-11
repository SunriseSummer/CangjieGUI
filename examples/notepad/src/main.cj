/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
/*
 * CUI example: a plain-text editor.
 *
 * What it demonstrates:
 *  - an editor shell: grouped toolbar, filling text area, and a status bar that
 *    derives its line/byte counts from the document State every frame
 *  - native desktop integration: file open/save dialogs, message boxes, clipboard,
 *    drag-and-drop, and Ctrl-key shortcuts via a top-level EventHandler
 *  - a Checkbox bound to State that actually changes behaviour (read-only mode)
 */
package cui_notepad

import cui.AppMetadata
import cui.AppMetadataType
import cui.ApplicationPaths
import cui.Axis
import cui.ButtonRole
import cui.Checkbox
import cui.Color
import cui.DesktopApp
import cui.Divider
import cui.EventHandler
import cui.FileDialogRequest
import cui.FontSizes
import cui.FrameHandler
import cui.HStack
import cui.IconButton
import cui.IconName
import cui.Insets
import cui.Key
import cui.Keyboard
import cui.Label
import cui.Panel
import cui.Spacer
import cui.State
import cui.SdlHint
import cui.SdlHintSetting
import cui.SurfaceStyle
import cui.TextArea
import cui.Theme
import cui.UiEvent
import cui.VStack
import cui.WindowSpec

class NotepadModel {
    let body = State<String>("欢迎使用 CUI 记事本。\n中文与 English 均使用系统 UI 字体清晰显示。")
    let bodyCursor = State<Int64>(body.value.size)
    let bodyScroll = State<Float32>(0.0)
    let currentPath = State<String>("")
    let status = State<String>("就绪")
    let readOnly = State<Bool>(false)
    let openDialog = State<?FileDialogRequest>(None<FileDialogRequest>)
    let saveDialog = State<?FileDialogRequest>(None<FileDialogRequest>)
}

main(): Int64 {
    let model = NotepadModel()
    let app = DesktopApp(WindowSpec("CUI 记事本", 900, 580, scale: 1.5), metadata: Some(notepadMetadata()),
        hints: notepadHints(), theme: notepadTheme())
    let documentPath = ApplicationPaths.preferencePath("CUI", "Notepad") + "notepad.txt"
    app.run {
        FrameHandler(
            onFrame: {
                _ =>
                    pollOpenDialog(model)
                    pollSaveDialog(model)
            }
        ) {
            notepadView(model, app, documentPath)
        }
    }
    return 0
}

func notepadMetadata(): AppMetadata {
    var metadata = AppMetadata(
        name: Some("CUI Notepad"),
        version: Some("0.1.0"),
        identifier: Some("dev.cui.examples.notepad")
    )
    metadata.creator = Some("CUI Examples")
    metadata.appType = Some(AppMetadataType.Application)
    metadata
}

func notepadHints(): Array<SdlHintSetting> {
    [
        SdlHintSetting(SdlHint.AppName, "CUI Notepad"),
        SdlHintSetting(SdlHint.AppId, "dev.cui.examples.notepad"),
        SdlHintSetting(SdlHint.WindowsCloseOnAltF4, "1")
    ]
}

func notepadTheme(): Theme {
    Theme(
        Color.rgb(238, 244, 248),
        Color.rgb(255, 255, 255),
        Color.rgb(201, 213, 222),
        Color.rgb(25, 34, 43),
        Color.rgb(92, 106, 119),
        Color.rgb(34, 132, 127),
        Color.rgb(255, 255, 255),
        Color.rgb(196, 59, 76),
        Color.rgb(250, 252, 253),
        Color.rgb(229, 245, 243),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(214, 241, 238),
        shadow: Color.rgba(11, 31, 45, 26),
        radius: 16.0,
        controlRadius: 11.0
    )
}

func notepadView(model: NotepadModel, app: DesktopApp, documentPath: String): Unit {
    EventHandler(onEvent: {event => handleNotepadEvent(event, model, app, documentPath)}) {
        VStack(spacing: 10.0, padding: Insets(14.0)) {
            toolbar(model, app, documentPath)
            TextArea("notepad.body", model.body, scroll: Some(model.bodyScroll), cursor: Some(model.bodyCursor),
                editable: !model.readOnly.value)
            statusBar(model)
        }
    }
}

func toolbar(model: NotepadModel, app: DesktopApp, documentPath: String): Unit {
    Panel(padding: Insets(10.0), style: Some(toolbarSurface()), flexible: false) {
        HStack {
            IconButton(IconName.NewDocument, label: Some("新建")) {
                => newFile(model)
            }
            IconButton(IconName.OpenFolder, label: Some("打开")) {
                => openFile(model, app)
            }
            Divider(axis: Axis.Vertical)
            IconButton(IconName.Save, label: Some("保存"), role: ButtonRole.Primary) {
                => saveCurrentFile(model, documentPath)
            }
            IconButton(IconName.SaveAs, label: Some("另存为")) {
                => saveFileAs(model, app, documentPath)
            }
            Divider(axis: Axis.Vertical)
            IconButton(IconName.Copy, label: Some("复制")) {
                => copyAll(model.body, model.status)
            }
            IconButton(IconName.Paste, label: Some("粘贴")) {
                => pasteClipboard(model.body, model.bodyCursor, model.status)
            }
            Spacer()
            Checkbox("只读", model.readOnly)
        }
    }
}

// The status bar derives everything it shows from model State — nothing here is
// stored, so it can never drift out of sync with the document.
func statusBar(model: NotepadModel): Unit {
    HStack(flexible: false) {
        Label(model.status.value, muted: true, fontSize: FontSizes.CAPTION)
        Spacer()
        Label(documentName(model), muted: true, fontSize: FontSizes.CAPTION)
        Label(documentStats(model.body.value), muted: true, fontSize: FontSizes.CAPTION)
    }
}

func documentName(model: NotepadModel): String {
    if (model.currentPath.value.size > 0) {
        model.currentPath.value
    } else {
        "未保存文档"
    }
}

func documentStats(text: String): String {
    "| ${text.split("\n").size} 行 | ${text.size} 字节 | UTF-8"
}

func toolbarSurface(): SurfaceStyle {
    SurfaceStyle(
        Color.rgb(255, 255, 255),
        border: Color.rgb(205, 218, 226),
        radius: 16.0,
        borderWidth: 1.0,
        shadow: Color.rgba(20, 44, 56, 24),
        shadowOffsetY: 2.0
    )
}

func handleNotepadEvent(
    event: UiEvent,
    model: NotepadModel,
    app: DesktopApp,
    documentPath: String
): Bool {
    match (event) {
        case UiEvent.KeyDown(Key.Letter(value), _) => handleShortcut(value, model, app, documentPath)
        case UiEvent.DropFile(path, _, _) =>
            loadDroppedFile(model, path)
            true
        case _ => false
    }
}

func handleShortcut(
    key: UInt8,
    model: NotepadModel,
    app: DesktopApp,
    documentPath: String
): Bool {
    let modifiers = Keyboard.modifiers()
    if (!modifiers.command) {
        return false
    }
    if (key == UInt8(78)) {
        newFile(model)
        return true
    }
    if (key == UInt8(79)) {
        openFile(model, app)
        return true
    }
    if (key == UInt8(83)) {
        if (modifiers.shift) {
            saveFileAs(model, app, documentPath)
        } else {
            saveCurrentFile(model, documentPath)
        }
        return true
    }
    if (key == UInt8(67)) {
        copyAll(model.body, model.status)
        return true
    }
    if (key == UInt8(86)) {
        pasteClipboard(model.body, model.bodyCursor, model.status)
        return true
    }
    false
}
