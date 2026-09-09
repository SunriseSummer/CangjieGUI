# contacts：通讯录（CRM）

一个小而完整的增删改查界面，把多个控件组合到一个真实场景中：可排序 `Table` 主列表、
`ComboBox` 搜索、`ContextMenu` 行操作、两个 `Modal`（录入表单与删除确认）承载真实控件子树，以及
随选择与输入变化的按钮启用与禁用。它既是这些特性的端到端集成测试，也是一份最佳实践参考。

## 演示要点

- 主从式增删改查的状态编排：联系人列表、选中行、搜索词、两组对话框标志与一组“草稿”字段
- 用 `Table` 呈现过滤后的可见列表；搜索变化时用 `State.observe` 清空选择，避免索引指向被过滤掉的行
- `ComboBox` 作搜索框：可键入任意关键字，也可从公司建议中选取
- `Modal` 承载表单子树：`TextField` 编辑草稿，打开即自动聚焦姓名字段（`autofocus` 依赖 Modal 的
  Frame 转发在对话框内生效），`Tab` 在表单控件间循环（焦点陷阱）；`.enabled(canSave())` 让“保存”
  按钮在姓名非空前禁用（表单校验）
- 对话框内嵌套浮层：表单的“公司”字段是 `Modal` 中的 `ComboBox`，建议列表经浮层栈压在对话框
  之上，键入过滤与点选填入照常，`Esc` 先关列表再关对话框
- `ContextMenu` 与工具栏共享同一组作用于选中行的编辑与删除动作；删除走确认 `Modal`
- 编辑不改原对象，而是编辑草稿，保存时整体替换该联系人；单一数据源，取消即丢弃

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口：模型、窗口与最小尺寸 |
| [data.cj](src/data.cj) | `Contact` 值、表格列、种子数据与公司建议 |
| [model.cj](src/model.cj) | `ContactsModel`：过滤、增改删、草稿与对话框状态 |
| [views.cj](src/views.cj) | 标题栏、工具栏、搜索、表格、表单与删除两个模态框 |
| [theme.cj](src/theme.cj) | 浅色靛蓝主题与字号令牌 |

## 关键实现

### 草稿式表单，保存才写回

表单不直接改联系人，而是编辑一组草稿 `State`。保存时按 id 整体替换（或新增），取消即丢弃：

```cangjie
func saveForm(): Unit {
    if (!canSave()) { return }              // 姓名为空则不保存
    if (editingId < 0) { appendContact(...) } else { replaceContact(...) }
    formOpen.value = false
}
```

“保存”按钮由 `canSave()` 驱动禁用，是最基础的表单校验：

```cangjie
Button("保存", {=> model.saveForm()}, role: ButtonRole.Primary).enabled(model.canSave())
```

### 过滤即清空选择

`Table` 展示的是过滤后的可见列表，`selected` 是可见列表中的行索引。搜索词一变，旧索引就可能指向
另一位（或已被过滤掉的）联系人，因此用观察器把选择设为 `-1`（未选择）：

```cangjie
this.queryObservation = this.query.observe({_, _ => selectionState.value = -1})
```

### 模态承载真实控件，浮层可嵌套

表单与删除确认都是 `Modal`：它托管的不是手绘内容，而是真实的 `TextField`/`Button` 子树，在暗化
背景之上居中，事件被隔离在对话框内。右键菜单与工具栏则复用同一组作用于选中行的动作。

表单的“公司”字段演示对话框内的嵌套浮层：

```cangjie
Modal(model.formOpen) {
    // ...
    ComboBox(model.draftCompany, companySuggestions(), key: "contacts.form.company").flex()
}
```

组合框的建议列表在对话框内容布局时登记到浮层栈顶，同帧画在面板之上、优先接收事件；选中或 `Esc`
只关闭列表本身，对话框保持打开。页面级与对话框级的组合框行为完全一致，无需任何适配代码。

## 运行

```powershell
cd examples/contacts
cjpm run
```

点击行选中，通过工具栏或右键编辑与删除，新增打开空表单；在搜索框键入关键字过滤。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot contacts.bmp"
```

## 练习与验收

修改联系人后取消，再重新打开，确认未提交草稿没有覆盖原记录。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
