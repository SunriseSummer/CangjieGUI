/*
 * 编辑器示例的种子文本与纯统计函数。
 */
package cui_editor

func seedText(): String {
    let l1 = "# CUI 菜单栏示例"
    let l2 = "用顶部菜单操作本文档：新建、追加日期、追加分隔线、清空。"
    let l3 = "菜单项带快捷键提示与分隔线；文档为空时，文件菜单里的保存会自动禁用。"
    "${l1}\n\n${l2}\n${l3}"
}

/** 字符数（Unicode 码点），不计换行与回车。 */
func charCount(text: String): Int64 {
    var count = 0
    for (rune in text.toRuneArray()) {
        if (rune != r'\n' && rune != r'\r') {
            count += 1
        }
    }
    count
}

/** 行数：空文本记 0，否则按换行切分计数。 */
func lineCount(text: String): Int64 {
    if (text.isEmpty()) {
        0
    } else {
        text.split("\n").size
    }
}
