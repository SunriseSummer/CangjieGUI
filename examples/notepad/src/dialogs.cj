/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui_notepad

import cui.DesktopApp
import cui.FileDialogFilter
import cui.FileDialogOptions
import cui.FileDialogRequest
import cui.FileDialogResult
import cui.State

func openFile(model: NotepadModel, app: DesktopApp): Unit {
    if (hasPendingDialog(model.openDialog) || hasPendingDialog(model.saveDialog)) {
        model.status.value = "File dialog already active"
        return
    }
    model.openDialog.value = Some(app.openFileDialog(options: notepadDialogOptions()))
    model.status.value = "Choose a file..."
}

func saveFileAs(model: NotepadModel, app: DesktopApp, fallbackPath: String): Unit {
    if (hasPendingDialog(model.openDialog) || hasPendingDialog(model.saveDialog)) {
        model.status.value = "File dialog already active"
        return
    }
    model.saveDialog.value = Some(
        app.saveFileDialog(options: notepadDialogOptions(defaultLocation: defaultSaveLocation(model, fallbackPath))))
    model.status.value = "Choose a save location..."
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
            model.status.value = "Open canceled"
        case FileDialogResult.FileDialogFailed(message) =>
            clearDialog(model.openDialog)
            model.status.value = dialogFailureMessage("Open", message)
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
            model.status.value = "Save canceled"
        case FileDialogResult.FileDialogFailed(message) =>
            clearDialog(model.saveDialog)
            model.status.value = dialogFailureMessage("Save", message)
        case FileDialogResult.FileDialogSelected(paths, _) =>
            clearDialog(model.saveDialog)
            saveSelectedFile(paths, model)
    }
}

private func notepadDialogOptions(defaultLocation!: ?String = None): FileDialogOptions {
    FileDialogOptions(
        filters: [
            FileDialogFilter("Text files", "txt;md;log"),
            FileDialogFilter("All files", "*")
        ],
        defaultLocation: defaultLocation
    )
}

private func loadSelectedFile(
    paths: Array<String>,
    model: NotepadModel
): Unit {
    if (paths.size <= 0) {
        model.status.value = "Open canceled"
        return
    }
    loadFile(model, paths[0], "Loaded selected file")
}

private func saveSelectedFile(paths: Array<String>, model: NotepadModel): Unit {
    if (paths.size <= 0) {
        model.status.value = "Save canceled"
        return
    }
    saveFileToPath(model, paths[0], "Saved selected file")
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
        "${action} dialog failed"
    } else {
        "${action} dialog failed: ${message}"
    }
}

private func defaultSaveLocation(model: NotepadModel, fallbackPath: String): ?String {
    if (model.currentPath.value.size > 0) {
        Some(model.currentPath.value)
    } else {
        Some(fallbackPath)
    }
}
