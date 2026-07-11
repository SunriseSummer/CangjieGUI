/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui_notepad

import cui.Clipboard
import cui.CuiException
import cui.State
import cui.TextEditState

func copyAll(body: State<String>, status: State<String>): Unit {
    try {
        Clipboard.setText(body.value)
        status.value = "Copied buffer"
    } catch (e: CuiException) {
        status.value = "Copy unavailable"
    }
}

func pasteClipboard(body: State<String>, cursor: State<Int64>, status: State<String>): Unit {
    try {
        let text = Clipboard.getText()
        if (text.size <= 0) {
            status.value = "Clipboard is empty"
            return
        }
        TextEditState(body, cursor: Some(cursor)).insert(text)
        status.value = "Pasted clipboard"
    } catch (e: CuiException) {
        status.value = "Paste unavailable"
    }
}
