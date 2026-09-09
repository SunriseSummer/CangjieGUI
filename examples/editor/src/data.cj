/*
 * 编辑器示例的种子文本与纯统计函数。
 */
package cui_editor

func seedText(): String {
    let l1 = "# CUI 文本编辑器 🎉"
    let l2 = "用顶部菜单操作本文档：新建、追加日期、追加分隔线、清空。"
    let l3 = "记录检查点只保存在内存；修改后退出会询问是否继续编辑。"
    let l4 = "试试 Emoji 🎉 👩🏽‍💻、组合字符 e\u{0301} 和中文混排；切换自动换行与宽松行距，选区和光标会使用同一套布局。"
    "${l1}\n\n${l2}\n${l3}\n\n${l4}"
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
