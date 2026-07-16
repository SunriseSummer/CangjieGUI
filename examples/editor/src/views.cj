/*
 * 编辑器视图层：顶部 `MenuBar` + 编辑区 + 状态栏。
 *
 *  - 菜单每帧由模型构建，故“保存/清空”能随文档是否为空动态启用/禁用，菜单项带快捷键提示与分隔线。
 *  - 菜单动作作用于模型，`TextArea` 双向绑定正文，改动即刻可见；状态栏显示上次动作与实时行数/字数。
 *  - 菜单栏可点击展开、菜单间悬停切换，也可 Tab 聚焦后用方向键导航（← → 换菜单，↑ ↓ 选项，Enter 执行）。
 */
package cui_editor

import cui.{CrossAxisAlignment, FontSizes, HStack, Label, LengthUnits, Menu, MenuBar, MenuItem, Panel, Spacer,
    TextArea, VStack}

func editorView(model: EditorModel): Unit {
    VStack {
        MenuBar(buildMenus(model))
        contentArea(model)
    }.spacing(0.vp)
}

// 菜单每帧重建，菜单项状态（此处为仅在有文本时启用保存/清空）随模型实时更新。
func buildMenus(model: EditorModel): Array<Menu> {
    let hasText = !model.isEmpty()
    [
        Menu("文件", [
            MenuItem("新建", {=> model.newDoc()}, shortcut: "Ctrl+N"),
            MenuItem("打开…", {=> model.open()}, shortcut: "Ctrl+O"),
            MenuItem("保存", {=> model.save()}, shortcut: "Ctrl+S", enabled: hasText),
            MenuItem.separator(),
            MenuItem("退出", {=> model.quit()}, shortcut: "Ctrl+Q")
        ]),
        Menu("编辑", [
            MenuItem("追加日期", {=> model.appendDate()}, shortcut: "Ctrl+D"),
            MenuItem("追加分隔线", {=> model.appendRule()}),
            MenuItem.separator(),
            MenuItem("清空", {=> model.clear()}, enabled: hasText)
        ]),
        Menu("帮助", [MenuItem("关于", {=> model.about()})])
    ]
}

func contentArea(model: EditorModel): Unit {
    VStack {
        editorPanel(model)
        statusBar(model)
    }.spacing(10.vp).padding(14.vp)
}

func editorPanel(model: EditorModel): Unit {
    Panel {
        TextArea(model.text)
    }.contentPadding(12.vp).flex()
}

func statusBar(model: EditorModel): Unit {
    HStack {
        Label(model.status.value).muted().fontSize(FontSizes.CAPTION)
        Spacer()
        Label("${model.lines.value} 行 · ${model.chars.value} 字").muted().fontSize(FontSizes.CAPTION)
    }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
}
