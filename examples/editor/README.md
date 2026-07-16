# editor：菜单栏编辑器

一个由应用菜单栏驱动的文本编辑器，集中演示 `MenuBar`：多个顶层菜单、快捷键提示、分隔线，以及随文档
状态动态启用/禁用的菜单项。菜单动作作用于模型，`TextArea` 绑定正文，改动即刻可见。

## 演示要点

- `MenuBar` 横排文件/编辑/帮助三个顶层菜单，点击标题展开其下拉（浮于正文之上）
- 菜单打开时，指针滑过其他标题即切换菜单（经典菜单栏手感）；点当前标题收起、外点或 Esc 关闭
- 菜单项带右对齐快捷键提示（`shortcut`，仅展示）、`MenuItem.separator()` 分隔线
- 动态启用/禁用：菜单每帧由模型构建，“保存/清空”在文档为空时自动置灰（`enabled: !isEmpty`）
- 键盘：`Tab` 聚焦菜单栏后 `←→` 移动标题、`Enter/Space/↓` 打开；打开后 `↑↓` 移动高亮（跳过分隔线与禁用项）、
  `←→` 切换菜单、`Enter` 执行、`Esc` 关闭
- 动作作用于模型：新建/清空改写正文，追加日期（复用 `CalendarDate.today().iso()`）/分隔线在末尾追加，
  打开/保存/退出/关于更新状态栏；`TextArea` 双向绑定 `model.text`，菜单改动即刻反映到编辑区
- 状态栏显示上次动作与由 `map` 派生的实时行数、字数

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | 种子文本、字符数（按码点、去换行）与行数纯函数 |
| [model.cj](src/model.cj) | `EditorModel`：正文、状态、派生行数/字数，菜单动作方法 |
| [views.cj](src/views.cj) | 菜单构建（含动态禁用）、菜单栏、编辑区、状态栏 |
| [theme.cj](src/theme.cj) | 浅灰底 + 靛蓝强调色主题 |

## 关键实现

### 菜单每帧构建，禁用状态实时

`MenuBar` 接收一个 `Array<Menu>`，示例在视图里每帧从模型构建它，于是菜单项的启用与否随模型即时变化：

```cangjie
let hasText = !model.isEmpty()
Menu("文件", [
    MenuItem("保存", {=> model.save()}, shortcut: "Ctrl+S", enabled: hasText),
    MenuItem.separator(),
    MenuItem("退出", {=> model.quit()}, shortcut: "Ctrl+Q")
])
```

菜单栏自身的打开/高亮状态按其身份跨帧保留，因此每帧重建菜单数据不会丢失交互状态。

### 与 ContextMenu 共享菜单基础设施

`MenuBar` 与 `ContextMenu` 使用同一个 `MenuItem` 类型和同一套弹层渲染、命中、导航逻辑（标签、快捷键、
分隔线、禁用置灰、跳过不可选中项）。因此两处菜单外观与手感一致，新增能力一处受益、两处生效。

## 运行

```powershell
cd examples/editor
cjpm run
```

点击顶部菜单标题展开，选择项执行；清空文档后再看文件菜单，“保存/清空”会置灰。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot editor.bmp"
```
