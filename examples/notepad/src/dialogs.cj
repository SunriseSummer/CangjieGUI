/*
 * 文件对话框：打开与另存为。
 *
 * 系统对话框是异步的：请求存入状态后才注册帧订阅，并约每 50 ms 请求下一帧。
 * 完成／取消后释放请求与订阅，空闲文档不会因文件对话框逻辑持续刷新。
 */
package cui_notepad

import cui.{DesktopApp, FileDialogFilter, FileDialogOptions, FileDialogRequest, FileDialogResult, State, subscribeFrame}

private let DIALOG_POLL_MS: UInt64 = UInt64(50)

// Conditional subscription keeps the document subtree stable and allows idle caret rendering.
func subscribeNotepadDialogs(model: NotepadModel): Unit {
    if (model.hasDialog()) {
        subscribeFrame(
            {
                ctx, _ =>
                    pollOpenDialog(model)
                    pollSaveDialog(model)
                    if (model.hasDialog()) {
                        ctx.requestFrameAt(ctx.frame.elapsedMs + DIALOG_POLL_MS)
                    }
            }
        )
    }
}

func openFile(model: NotepadModel, app: DesktopApp): Unit {
    // 同一时刻只允许一个系统对话框，避免两份结果互相覆盖。
    if (hasPendingDialog(model.openDialog) || hasPendingDialog(model.saveDialog)) {
        model.status.value = "文件对话框已打开"
        return
    }
    model.openDialog.value = Some(app.openFileDialog(options: notepadDialogOptions()))
    model.status.value = "请选择要打开的文件..."
}

func saveFileAs(model: NotepadModel, app: DesktopApp, fallbackPath: String): Unit {
    if (hasPendingDialog(model.openDialog) || hasPendingDialog(model.saveDialog)) {
        model.status.value = "文件对话框已打开"
        return
    }
    model.saveDialog.value = Some(
        app.saveFileDialog(options: notepadDialogOptions(defaultLocation: defaultSaveLocation(model, fallbackPath))))
    model.status.value = "请选择保存位置..."
}

func pollOpenDialog(model: NotepadModel): Unit {
    match (model.openDialog.value) {
        case Some(request) => handleOpenDialogResult(request, model)
        case None => ()
    }
}

func pollSaveDialog(model: NotepadModel): Unit {
    match (model.saveDialog.value) {
        case Some(request) => handleSaveDialogResult(request, model)
        case None => ()
    }
}

private func handleOpenDialogResult(
    request: FileDialogRequest,
    model: NotepadModel
): Unit {
    match (request.result()) {
        case FileDialogResult.FileDialogPending => ()
        case FileDialogResult.FileDialogCanceled =>
            clearDialog(model.openDialog)
            model.status.value = "已取消打开"
        case FileDialogResult.FileDialogFailed(message) =>
            clearDialog(model.openDialog)
            model.status.value = dialogFailureMessage("打开", message)
        case FileDialogResult.FileDialogSelected(paths, _) =>
            clearDialog(model.openDialog)
            loadSelectedFile(paths, model)
    }
}

private func handleSaveDialogResult(
    request: FileDialogRequest,
    model: NotepadModel
): Unit {
    match (request.result()) {
        case FileDialogResult.FileDialogPending => ()
        case FileDialogResult.FileDialogCanceled =>
            clearDialog(model.saveDialog)
            model.status.value = "已取消保存"
        case FileDialogResult.FileDialogFailed(message) =>
            clearDialog(model.saveDialog)
            model.status.value = dialogFailureMessage("保存", message)
        case FileDialogResult.FileDialogSelected(paths, _) =>
            clearDialog(model.saveDialog)
            saveSelectedFile(paths, model)
    }
}

private func notepadDialogOptions(defaultLocation!: ?String = None): FileDialogOptions {
    FileDialogOptions(
        filters: [
            FileDialogFilter("文本文件", "txt;md;log"),
            FileDialogFilter("所有文件", "*")
        ],
        defaultLocation: defaultLocation
    )
}

private func loadSelectedFile(
    paths: Array<String>,
    model: NotepadModel
): Unit {
    if (paths.size <= 0) {
        model.status.value = "已取消打开"
        return
    }
    loadFile(model, paths[0], "已打开所选文件")
}

private func saveSelectedFile(paths: Array<String>, model: NotepadModel): Unit {
    if (paths.size <= 0) {
        model.status.value = "已取消保存"
        return
    }
    saveFileToPath(model, paths[0], "已保存到所选位置")
}

private func hasPendingDialog(dialog: State<?FileDialogRequest>): Bool {
    match (dialog.value) {
        case Some(request) => !request.isDone()
        case None => false
    }
}

private func clearDialog(dialog: State<?FileDialogRequest>): Unit {
    dialog.value = None<FileDialogRequest>
}

private func dialogFailureMessage(action: String, message: String): String {
    if (message.size <= 0) {
        "${action}对话框失败"
    } else {
        "${action}对话框失败：${message}"
    }
}

private func defaultSaveLocation(model: NotepadModel, fallbackPath: String): ?String {
    // 已有文件路径时默认覆盖原位置；否则落到应用偏好目录的默认文件。
    if (model.currentPath.value.size > 0) {
        Some(model.currentPath.value)
    } else {
        Some(fallbackPath)
    }
}
