<!-- kind: how-to; audience: desktop-app-developer -->

# 构建树形导航与详情区

## 目标

用稳定路径 id 构建可展开、可选择、可键盘导航的树，并让详情区按 id 取数据。完成约需 15 分钟。

## 适用场景

文件浏览器、设置分类、项目导航和层级资源选择适合 `TreeView`。若数据没有父子关系，只需要一维选择，应继续使用列表或表格。

## 准备工作

为每个节点确定不会随排序改变的 id。文件树可以先统一路径分隔符、去掉多余的 `.` 后再把相对路径作为 id；业务分类可以使用数据库 id。标签允许重名，id 不允许重名；`selected` 保存 id，空串表示未选择。

先把数据转换为不含窗口对象的普通树结构，并决定根节点、初始展开节点和空选择时详情显示什么。目录扫描可能很慢，应先准备一小份静态树验证键盘操作，再接入后台扫描结果。若要保存工作区，同时规划展开集合和滚动位置的持久化边界。

## 操作步骤

### 1. 明确初始展开与选择

`initiallyExpanded` 只负责第一次出现时的展开状态。若需要保存工作区，下次启动时恢复展开集合，应通过外部状态接管，而不是每帧重写初始值。

### 2. 运行完整树视图

```cangjie verify role=complete profile=gui-visual
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("项目导航", 700, 440))
    app.run {
        let selected = rememberState<String>("selected-path") {"docs/guide.md"}
        HStack(spacing: 16.vp) {
            TreeView(
                [
                    TreeNode(
                        "docs",
                        "docs",
                        children: [
                            TreeNode("docs/guide.md", "guide.md"),
                            TreeNode("docs/api.md", "api.md")
                        ]
                    ),
                    TreeNode("src", "src", children: [TreeNode("src/main.cj", "main.cj")]),
                    TreeNode("README.md", "README.md")
                ],
                selected,
                initiallyExpanded: ["docs", "src"]
            ).width(260.vp)
            Panel {
                VStack(spacing: 10.vp) {
                    Label("当前条目").muted()
                    Label(if (selected.value.isEmpty()) {
                        "未选择"
                    } else {
                        selected.value
                    }).bold()
                    Label("详情数据应按这个路径 id 查询，而不是按可见行号。").wrap()
                }.padding(18.vp)
            }.flex()
        }.padding(16.vp)
    }
}
```

### 3. 接入真实数据

把每个文件条目递归转换为 `TreeNode(entry.relativePath, entry.name, children: ...)`。

扫描目录应在后台完成，UI 帧只接收已经构造好的普通数据。所有入口必须用同一条路径整理规则，例如统一 `/` 与 `\\`；否则 `docs/guide.md` 和 `docs\\guide.md` 会被当成两个节点。

## 确认结果

聚焦树后，用 Up/Down 移动，Right 展开或进入子节点，Left 折叠或返回父节点，Home/End 跳到可见首尾。选择变化时右侧立即显示对应 id。折叠父节点再展开，选择不能悄悄改成同名的另一节点。

再插入一个与现有文件同名、但路径不同的节点。两个标签可以相同，选择详情必须显示各自完整 id。把已选节点从新数据中删除时，模型要明确清空或选择邻近项；树控件不应替应用猜测业务回退策略。

## 常见错误

- 使用标签作 id：两个 `index.md` 会互相覆盖。
- 保存可见行号：展开任一目录后详情就错位。
- 在界面线程递归扫描大目录：窗口会冻结。
- 在树外拦截方向键：控件内建键盘导航无法工作。

## 相关 API

[TreeView](../../api/cui/controls/TreeView.md)、[TreeNode](../../api/cui/controls/TreeNode.md)、[SplitView](../../api/cui/controls/SplitView.md)。

## 下一步

需要编辑所选文件时继续[文本编辑与菜单](text-editing-and-menus.md)。
