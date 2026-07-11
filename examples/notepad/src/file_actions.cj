/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui_notepad

import std.fs.File
import std.fs.Path
import cui.CuiException
import cui.FileSystem
import cui.FileSystemEntryType
import cui.MessageBoxButton
import cui.MessageBoxButtonOrder
import cui.MessageBoxKind
import cui.MessageBoxOptions
import cui.State
import cui.showMessageBox

func newFile(model: NotepadModel): Unit {
    if (model.body.value.size > 0 && !confirmNewFile(model.status)) {
        return
    }
    model.body.value = ""
    model.bodyCursor.value = 0
    model.currentPath.value = ""
    model.status.value = "New buffer"
}

func confirmNewFile(status: State<String>): Bool {
    var options = MessageBoxOptions("Discard current note?", "The current buffer has text. Start a new note?")
    options.kind = MessageBoxKind.Warning
    options.buttonOrder = MessageBoxButtonOrder.LeftToRight
    options.buttons = [
        MessageBoxButton("Start New", id: 1, returnKeyDefault: true),
        MessageBoxButton("Cancel", id: 0, escapeKeyDefault: true)
    ]

    try {
        showMessageBox(options) == 1
    } catch (e: CuiException) {
        status.value = "Confirmation unavailable"
        false
    }
}

func saveCurrentFile(model: NotepadModel, fallbackPath: String): Unit {
    let target = if (model.currentPath.value.size > 0) {
        model.currentPath.value
    } else {
        fallbackPath
    }
    saveFileToPath(model, target, "Saved file")
}

func saveFileToPath(model: NotepadModel, path: String, message: String): Unit {
    try {
        File.writeTo(Path(path), model.body.value.toArray())
        model.currentPath.value = path
        model.status.value = message
    } catch (e: Exception) {
        model.status.value = "Could not save file"
    }
}

func loadDroppedFile(model: NotepadModel, path: String): Unit {
    if (!fileExists(path)) {
        model.status.value = "Dropped file does not exist"
        return
    }
    loadFile(model, path, "Loaded dropped file")
}

func loadFile(model: NotepadModel, path: String, message: String): Unit {
    try {
        model.body.value = String.fromUtf8(File.readFrom(Path(path)))
        model.bodyCursor.value = model.body.value.size
        model.currentPath.value = path
        model.status.value = message
    } catch (e: Exception) {
        model.status.value = "Could not read file"
    }
}

func fileExists(path: String): Bool {
    match (FileSystem.pathInfo(path)) {
        case Some(info) => isFile(info.entryType)
        case None => false
    }
}

func isFile(entryType: FileSystemEntryType): Bool {
    match (entryType) {
        case FileSystemEntryType.File => true
        case _ => false
    }
}
