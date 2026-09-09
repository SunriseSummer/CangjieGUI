package cui_notepad

import cui.{Clipboard, SdlException, State}

// Whole-document export is explicit; interactive paste uses TextArea.paste() and its undo history.
func copyAll(body: State<String>, status: State<String>): Unit {
    try {
        Clipboard.setText(body.value)
        status.value = "已复制全文"
    } catch (_: SdlException) {
        status.value = "无法访问剪贴板"
    }
}
