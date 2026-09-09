/*
 * CUI 示例：纯文本记事本。
 *
 * 演示内容：
 *  - 编辑器外壳：分组工具栏、填满剩余空间的正文编辑区、内容全部由状态派生的状态栏
 *  - 桌面原生集成：文件打开/保存对话框、剪贴板、拖放文件与 Ctrl 快捷键
 *  - 应用内“新建”确认条：以异步状态驱动的警示条代替会阻塞事件循环的系统弹窗
 *  - 行数/字节统计由 DerivedState 从正文派生，永不与文档内容脱节
 */
package cui_notepad

import cui.{ApplicationPaths, DesktopApp, WindowSpec}

main(): Int64 {
    let model = NotepadModel()
    let app = DesktopApp(WindowSpec("CUI 记事本", 900, 580, scale: 1.0), metadata: Some(notepadMetadata()),
        hints: notepadHints(), theme: notepadTheme())
    // 布局按 640x460 的设计下限编写；限定窗口最小尺寸，避免工具栏与状态栏被挤出可视区。
    app.setMinimumSize(640, 460)
    let documentPath = ApplicationPaths.preferencePath("CUI", "Notepad") + "notepad.txt"
    app.run {
        notepadView(model, app, documentPath)
    }
    return 0
}
