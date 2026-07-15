/*
 * 笔记视图层：顶部标题与工具栏、左侧笔记列表、右侧编辑器与统计。
 *
 *  - 侧栏 ListView 可 Tab 聚焦、方向键切换笔记，选中项驱动右侧编辑器
 *  - 编辑器是绑定到选中笔记正文的 TextArea，自带选区/撤销；id 含笔记 id 故状态按笔记独立
 *  - 工具栏图标按钮用 Tooltip 补充说明
 */
package cui_notes

import cui.{Button, ButtonRole, ContextMenu, CrossAxisAlignment, FontSizes, HStack, IconButton, IconName, Label,
    LengthUnits, ListView, MenuItem, Modal, Panel, Spacer, TextArea, Tooltip, VStack, ZStack}

func notesView(model: NotesModel): Unit {
    // ZStack 把删除确认模态框叠放在主内容之上；模态框不占布局空间且相对视口自行居中，
    // 因此隐藏时对下方布局没有任何影响。
    ZStack {
        VStack {
            appHeader(model)
            HStack {
                sidebar(model)
                editorArea(model)
            }.spacing(14.vp)
        }.spacing(14.vp).padding(18.vp)
        deleteConfirmModal(model)
    }
}

// 破坏性操作需经模态确认：右键菜单只负责唤起确认框，最终由对话框按钮执行或取消。
func deleteConfirmModal(model: NotesModel): Unit {
    Modal(model.confirmDelete) {
        VStack {
            Label("删除这条笔记？").fontSize(FontSizes.TITLE)
            Label("删除后无法恢复。").muted().fontSize(FontSizes.CAPTION)
            HStack {
                Spacer()
                Button("取消", {=> model.confirmDelete.value = false})
                Button(
                    "删除",
                    {
                        =>
                        model.deleteSelected()
                        model.confirmDelete.value = false
                    },
                    role: ButtonRole.Danger
                )
            }.spacing(8.vp)
        }.spacing(14.vp).minWidth(240.vp)
    }
}

func appHeader(model: NotesModel): Unit {
    HStack {
        VStack {
            Label("笔记").fontSize(NOTES_TITLE)
            Label("左侧方向键切换，右侧编辑（Ctrl+Z 撤销）").muted().fontSize(FontSizes.CAPTION)
        }.spacing(2.vp).hug()
        Spacer()
        toolbar(model)
    }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

func toolbar(model: NotesModel): Unit {
    HStack {
        Tooltip(text: "新建笔记") {
            IconButton(IconName.NewDocument) {
                => model.addNote()
            }.label("新建")
        }
        Tooltip(text: "删除当前笔记") {
            IconButton(IconName.Trash) {
                => model.confirmDelete.value = true
            }.label("删除").role(ButtonRole.Danger)
        }
    }.spacing(8.vp).hug()
}

func sidebar(model: NotesModel): Unit {
    // 在列表任意位置右键即可在指针处弹出菜单。“复制笔记”仅在此处提供，
    // 演示上下文菜单可承载常驻工具栏之外的操作。
    ContextMenu(items: [
        MenuItem("新建笔记", {=> model.addNote()}),
        MenuItem("复制笔记", {=> model.duplicateSelected()}),
        MenuItem("删除笔记", {=> model.confirmDelete.value = true})
    ]) {
        Panel {
            ListView(model.titles(), model.selected)
        }.contentPadding(6.vp).hug().width(220.vp)
    }
}

func editorArea(model: NotesModel): Unit {
    Panel {
        VStack {
            if (model.notes.value.isEmpty()) {
                Label("还没有笔记。点击“新建”开始。").muted()
            }
            if (!model.notes.value.isEmpty()) {
                TextArea(model.body, key: model.editorId())
            }
            Label(model.stats.value).muted().fontSize(FontSizes.CAPTION)
        }.spacing(10.vp)
    }.contentPadding(14.vp).flex()
}
