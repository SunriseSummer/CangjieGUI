/* 主从笔记布局：稳定的笔记身份、单一正文绑定、可键盘操作的列表与确认框。 */
package cui_notes

import cui.{Button, ButtonRole, ContextMenu, CrossAxisAlignment, Divider, Flexible, FontWeight, HStack}
import cui.{Icon, IconSource, Label, LengthInsets, LengthUnits, ListView, MenuItem, Modal, Panel}
import cui.{Spacer, TextArea, TextInputStyle, VStack, ZStack}

func notesView(model: NotesModel): Unit {
    ZStack {
        VStack {
            appHeader(model)
            HStack {
                sidebar(model)
                editorArea(model)
            }.spacing(14.vp)
            Label("当前会话内保存 · Tab 聚焦列表，方向键切换笔记").fontSize(11.fp).muted()
        }.spacing(14.vp).padding(20.vp)
        deleteConfirmModal(model)
    }
}

func appHeader(model: NotesModel): Unit {
    HStack {
        Icon(IconSource("assets/icons/document.svg")).iconSize(24.vp).foregroundColor(NOTES_ACCENT)
        Flexible {
            VStack {
                Label("我的笔记").fontSize(22.fp).fontWeight(FontWeight.semiBold)
                Label("记录日常，也收藏灵感").fontSize(12.fp).muted()
            }.spacing(3.vp).hug()
        }
        Button("新建笔记", {=> model.addNote()}, role: ButtonRole.Primary).fontSize(13.fp).key("notes-new")
    }.spacing(12.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

func sidebar(model: NotesModel): Unit {
    let hasNote = !model.notes.value.isEmpty()
    ContextMenu(
        items: [
            MenuItem("新建笔记", {=> model.addNote()}),
            MenuItem("复制笔记", {=> model.duplicateSelected()}, enabled: hasNote),
            MenuItem("删除笔记", {=> model.confirmDelete.value = true}, enabled: hasNote)
        ]
    ) {
        Panel {
            VStack {
                HStack {
                    Label("全部笔记").fontSize(12.fp).muted()
                    Spacer()
                    Label("${model.notes.value.size}").fontSize(12.fp).muted()
                }.hug()
                Divider()
                ListView(model.titles(), model.selected, key: "notes-list")
            }.spacing(12.vp)
        }.style(notesCard()).contentPadding(12.vp).hug().width(190.vp)
    }
}

func editorArea(model: NotesModel): Unit {
    Panel {
        VStack {
            if (model.notes.value.isEmpty()) {
                Spacer()
                VStack {
                    Icon(IconSource("assets/icons/document.svg")).iconSize(32.vp).foregroundColor(NOTES_ACCENT)
                    Label("还没有笔记").fontSize(18.fp)
                    Label("点击“新建笔记”，写下第一句话。").fontSize(12.fp).muted()
                }.spacing(14.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
                Spacer()
            } else {
                HStack {
                    Flexible {Label(noteTitle(model.body.value)).fontSize(15.fp).fontWeight(FontWeight.semiBold)}
                    Button("删除笔记", {=> model.confirmDelete.value = true}).fontSize(12.fp).key("notes-delete")
                }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
                Divider()
                TextArea(model.body, key: model.editorId())
                    .placeholder("写下值得记住的事…")
                    .style(TextInputStyle(surface: notesPaper(), padding: LengthInsets(8.vp), lineHeight: 28.fp))
                Divider()
                Label(model.stats.value).fontSize(11.fp).muted()
            }
        }.spacing(12.vp)
    }.style(notesCard()).contentPadding(16.vp).flex()
}

func deleteConfirmModal(model: NotesModel): Unit {
    Modal(model.confirmDelete, dismissOnBackdrop: false, initialFocus: "notes-delete-cancel") {
        VStack {
            Label("删除这条笔记？").fontSize(19.fp).fontWeight(FontWeight.semiBold)
            Label("删除后无法恢复。").fontSize(13.fp).muted()
            HStack {
                Spacer()
                Button("保留笔记", {=> model.confirmDelete.value = false}).fontSize(13.fp).key("notes-delete-cancel")
                Button(
                    "删除",
                    {
                        =>
                            model.deleteSelected()
                            model.confirmDelete.value = false
                    },
                    role: ButtonRole.Danger
                ).fontSize(13.fp).key("notes-delete-confirm")
            }.spacing(8.vp).hug()
        }.spacing(16.vp).minWidth(260.vp)
    }
}
