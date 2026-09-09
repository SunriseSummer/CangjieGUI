/*
 * 文件动作：新建、保存与载入。
 *
 * “新建”不再弹系统 MessageBox 确认——同步弹窗会阻塞事件循环，
 * 与打开/保存对话框“发起请求 -> 帧内轮询”的异步模式自相矛盾。
 * 改为置起 confirmingNew 状态，由视图层的应用内确认条完成交互。
 */
package cui_notepad

import std.fs.File
import std.fs.Path
import cui.{FileSystem, FileSystemEntryType}

// 只有相对最近一次成功保存／载入存在修改时才确认；干净文档可直接新建。
func newFile(model: NotepadModel): Unit {
    if (model.dirty.value) {
        model.confirmingNew.value = true
        return
    }
    resetBuffer(model)
}

// 确认条的“丢弃并新建”：先收起确认条，再清空缓冲区。
func confirmDiscardAndNew(model: NotepadModel): Unit {
    model.confirmingNew.value = false
    resetBuffer(model)
}

// 确认条的“取消”：只收起确认条，文档内容保持原样。
func cancelNewFile(model: NotepadModel): Unit {
    model.confirmingNew.value = false
}

private func resetBuffer(model: NotepadModel): Unit {
    model.body.value = ""
    // 光标与锚点一起归零：只动光标会留下跨越全文的幻影选区（见 NotepadModel 注释）。
    model.bodyCursor.value = 0
    model.bodyAnchor.value = 0
    model.currentPath.value = ""
    model.bodyScroll.value = 0.0
    model.markSaved()
    model.status.value = "已新建空白文档"
}

func saveCurrentFile(model: NotepadModel, fallbackPath: String): Unit {
    // 尚未打开过文件时保存到应用偏好目录的默认路径，避免每次保存都弹对话框。
    let target = if (model.currentPath.value.size > 0) {
        model.currentPath.value
    } else {
        fallbackPath
    }
    saveFileToPath(model, target, "文件已保存")
}

func saveFileToPath(model: NotepadModel, path: String, message: String): Unit {
    try {
        File.writeTo(Path(path), model.body.value.toArray())
        model.currentPath.value = path
        model.markSaved()
        model.status.value = message
    } catch (e: Exception) {
        model.status.value = "无法保存文件"
    }
}

func loadDroppedFile(model: NotepadModel, path: String): Unit {
    // 拖入的可能是目录或已被移走的文件，先确认是普通文件再读取。
    if (!fileExists(path)) {
        model.status.value = "拖入的文件不存在"
        return
    }
    loadFile(model, path, "已载入拖入的文件")
}

func loadFile(model: NotepadModel, path: String, message: String): Unit {
    try {
        model.body.value = String.fromUtf8(File.readFrom(Path(path)))
        // 光标与锚点一起移到文末：只动光标会让新文档呈现从旧锚点到文末的幻影选区，
        // 下一次键入会直接吞掉这段内容。
        model.bodyCursor.value = model.body.value.size
        model.bodyAnchor.value = model.body.value.size
        model.currentPath.value = path
        model.bodyScroll.value = 0.0
        model.markSaved()
        model.status.value = message
    } catch (e: Exception) {
        model.status.value = "无法读取文件"
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
