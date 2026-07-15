/*
 * 通讯录视图层：标题 + 工具栏、组合框搜索、可排序联系人表格（右键菜单），以及表单与删除两个模态框。
 *
 *  - 表格是主视图；工具栏与右键菜单的编辑/删除都作用于当前选中行
 *  - 搜索用 ComboBox：可键入任意关键字过滤，也可从公司建议里挑
 *  - 表单模态承载真实控件子树，保存按钮按“姓名非空”校验启用；公司字段用对话框内的
 *    ComboBox 演示嵌套浮层——建议列表经浮层栈压在对话框之上
 */
package cui_contacts

import cui.{Button, ButtonRole, ComboBox, ContextMenu, CrossAxisAlignment, FontSizes, HStack, Label, LengthUnits,
    MenuItem, Modal, Panel, Spacer, State, Table, TextField, Tooltip, VStack, ZStack}

func contactsView(model: ContactsModel): Unit {
    // ZStack 把两个模态框叠放在主内容之上；二者都不占布局空间并自行居中。
    ZStack {
        VStack {
            header(model)
            contactList(model)
            statusBar(model)
        }.spacing(14.vp).padding(18.vp)
        formModal(model)
        deleteModal(model)
    }
}

func header(model: ContactsModel): Unit {
    VStack {
        HStack {
            VStack {
                Label("通讯录").fontSize(CONTACTS_TITLE)
                Label("Table 列表、表单对话框与组合框搜索的综合示例").muted().fontSize(FontSizes.CAPTION)
            }.spacing(2.vp).hug()
            Spacer()
            toolbar(model)
        }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
        searchRow(model)
    }.spacing(12.vp).hug()
}

func toolbar(model: ContactsModel): Unit {
    HStack {
        Tooltip(text: "新增联系人") {
            Button("新增", {=> model.startAdd()}).role(ButtonRole.Primary)
        }
        Tooltip(text: "编辑选中联系人") {
            Button("编辑", {=> model.startEdit()}).enabled(hasSelection(model))
        }
        Tooltip(text: "删除选中联系人") {
            Button("删除", {=> model.requestDelete()}, role: ButtonRole.Danger).enabled(hasSelection(model))
        }
    }.spacing(8.vp).hug()
}

func searchRow(model: ContactsModel): Unit {
    HStack {
        Label("搜索").muted().fontSize(FontSizes.CAPTION)
        ComboBox(model.query, companySuggestions()).flex()
    }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

func contactList(model: ContactsModel): Unit {
    // 右键任意行可执行与工具栏相同的编辑/删除操作（同样作用于当前选中行）。
    ContextMenu(items: [
        MenuItem("编辑", {=> model.startEdit()}),
        MenuItem("删除", {=> model.requestDelete()})
    ]) {
        Table(contactColumns(), model.rows(), model.selected)
    }
}

func statusBar(model: ContactsModel): Unit {
    Panel {
        HStack {
            Label(selectionSummary(model)).muted().fontSize(FontSizes.CAPTION)
            Spacer()
            Label("共 ${model.contacts.value.size} 位联系人").muted().fontSize(FontSizes.CAPTION)
        }.crossAxisAlignment(CrossAxisAlignment.Center)
    }.contentPadding(10.vp).hug()
}

func formModal(model: ContactsModel): Unit {
    Modal(model.formOpen) {
        VStack {
            Label(model.editingTitle()).fontSize(CONTACTS_HEADING)
            // 打开表单即聚焦姓名——Modal 会把每帧 Frame 事件转发进对话框子树，autofocus 因此生效；
            // 关闭后其局部状态随裁剪回收，下次打开会再次自动聚焦。
            formField("姓名", "contacts.form.name", model.draftName, autofocus: true)
            // 对话框内的组合框：其建议列表压在对话框浮层之上（浮层栈），输入过滤、点选填入都
            // 与页面级组合框一致；也允许键入建议之外的公司。
            HStack {
                Label("公司").width(56.vp)
                ComboBox(model.draftCompany, companySuggestions(), key: "contacts.form.company").flex()
            }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
            formField("职务", "contacts.form.role", model.draftRole)
            formField("邮箱", "contacts.form.email", model.draftEmail)
            HStack {
                Spacer()
                Button("取消", {=> model.formOpen.value = false})
                Button("保存", {=> model.saveForm()}, role: ButtonRole.Primary).enabled(model.canSave())
            }.spacing(8.vp)
        }.spacing(12.vp).minWidth(360.vp)
    }
}

func formField(label: String, id: String, value: State<String>, autofocus!: Bool = false): Unit {
    HStack {
        Label(label).width(56.vp)
        let field = TextField(value, key: id)
        if (autofocus) {
            let _ = field.autofocus()
        }
        field.flex()
    }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

func deleteModal(model: ContactsModel): Unit {
    Modal(model.confirmDelete) {
        VStack {
            Label("删除这位联系人？").fontSize(CONTACTS_HEADING)
            Label(deletePrompt(model)).muted().fontSize(FontSizes.CAPTION)
            HStack {
                Spacer()
                Button("取消", {=> model.confirmDelete.value = false})
                Button("删除", {=> model.deleteSelected()}, role: ButtonRole.Danger)
            }.spacing(8.vp)
        }.spacing(14.vp).minWidth(280.vp)
    }
}

func hasSelection(model: ContactsModel): Bool {
    match (model.selectedContact()) {
        case Some(_) => true
        case None => false
    }
}

func selectionSummary(model: ContactsModel): String {
    match (model.selectedContact()) {
        case Some(contact) => "${contact.name} · ${contact.company} · ${contact.role}"
        case None => "未选择联系人 · 点击一行查看，或右键编辑/删除"
    }
}

func deletePrompt(model: ContactsModel): String {
    match (model.selectedContact()) {
        case Some(contact) => "「${contact.name}」将被移除，此操作不可撤销。"
        case None => "此操作不可撤销。"
    }
}
