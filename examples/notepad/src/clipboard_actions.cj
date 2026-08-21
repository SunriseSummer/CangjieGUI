/*
 * 剪贴板动作：整篇复制与光标处粘贴。
 * 系统剪贴板可能不可用（如无桌面环境），失败时只更新状态栏提示，不中断应用。
 */
package cui_notepad

import cui.{Clipboard, SdlException, State, TextEditState}

func copyAll(body: State<String>, status: State<String>): Unit {
    try {
        Clipboard.setText(body.value)
        status.value = "已复制到剪贴板"
    } catch (e: SdlException) {
        status.value = "无法访问剪贴板"
    }
}

func pasteClipboard(body: State<String>, cursor: State<Int64>, anchor: State<Int64>, status: State<String>): Unit {
    try {
        let text = Clipboard.getText()
        if (text.size <= 0) {
            status.value = "剪贴板为空"
            return
        }
        // 经 TextEditState 在光标处插入。锚点与光标同源传入：插入后两者一起落到
        // 内容末尾，编辑区不会残留幻影选区。
        TextEditState(body, cursor: Some(cursor), anchor: Some(anchor)).insert(text)
        status.value = "已粘贴剪贴板内容"
    } catch (e: SdlException) {
        status.value = "无法读取剪贴板"
    }
}
