/*
 * CUI 示例：主从式笔记。
 *
 * 演示主从结构的最优实践：`notes.project` 把编辑器双向绑定到选中笔记，编辑器 id 含笔记 id 实现
 * 按笔记独立的光标与撤销历史。综合演示 ListView 键盘导航、TextArea 选区/撤销、Tooltip 与派生统计。
 */
package cui_notes

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = NotesModel()
    let app = DesktopApp(WindowSpec("CUI 笔记", 860, 620, scale: 1.0), theme: notesTheme())
    app.setMinimumSize(640, 480)
    app.run {
        notesView(model)
    }
    return 0
}
