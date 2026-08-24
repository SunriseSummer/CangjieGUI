/*
 * CUI 示例：通讯录（CRM）。
 *
 * 一个小而完整的商用增删改查界面，综合演示近期落地的控件如何协作：可排序 `Table` 主列表、
 * `ComboBox` 搜索、`ContextMenu` 行操作、两个 `Modal`（表单录入与删除确认）承载真实控件子树，
 * 以及“姓名非空才可保存”的表单校验与随选择启用的工具栏按钮。
 */
package cui_contacts

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = ContactsModel()
    let app = DesktopApp(WindowSpec("CUI 通讯录", 820, 640, scale: 1.0), theme: contactsTheme())
    app.setMinimumSize(680, 520)
    app.run {
        contactsView(model)
    }
    return 0
}
