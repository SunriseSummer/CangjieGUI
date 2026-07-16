# file_explorer：文件浏览器

一个经典的“左树 + 右详情”资源管理器，集中演示 `TreeView` 层级列表控件，并复用上一组件 `SplitView`
把界面分成可拖动的左右两栏，示范组件间的组合。左树展示的正是本项目的目录结构。

## 演示要点

- `TreeView` 以 `TreeNode` 根节点描述层级：展开/折叠、按深度缩进、文件夹与文件用不同图标区分
- 只把当前展开的节点扁平成行并窗口化——只绘制视口附近的行，大树成本恒为一屏
- 选择以节点 id 为准（而非行索引，因展开/折叠会移动其后所有行）；`selected` 绑定保存选中 id
- 点击行选中、点击箭头切换展开；`Tab` 聚焦后 `↑↓` 移动、`Home/End` 到两端、`→` 展开并步入、
  `←` 折叠并步出到父级、空格/Enter 切换当前节点，选中项始终滚入可视区
- 展开集由视图身份内部保留（`initiallyExpanded` 给初值），也可通过 `expanded` 外部持有
- 用 `SplitView` 分出左右两栏（导航｜详情），右栏详情由选中节点 id 从索引查得，路径面包屑直接由 id 拆分得到

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | `TreeNode` 目录树种子、`FileInfo`、id→元信息索引、路径与扩展名等纯函数 |
| [model.cj](src/model.cj) | `ExplorerModel`：目录树、元信息索引、选中项、初始展开集 |
| [views.cj](src/views.cj) | `SplitView` 左右分栏、左树 `TreeView`、右侧详情面板 |
| [theme.cj](src/theme.cj) | 中性冷灰 + 青蓝强调色主题与字号令牌 |

## 关键实现

### id 即路径

每个节点的 id 取其完整路径、label 取末段名。这个约定让两处派生变得平凡：详情面板按选中 id 从
一次遍历建成的 `HashMap` 索引查得元信息，路径面包屑直接由 id 拆分 `"/"` 得到，无需在树上回溯父链。

```cangjie
folder("CangjieGUI/src/core", [ file("CangjieGUI/src/core/widget.cj"), ... ])
```

### 选择以 id 为键

树的可见行随展开/折叠不断增删，行索引并不稳定，因此 `TreeView` 的选中项是节点 id：

```cangjie
TreeView(model.roots, model.selected, initiallyExpanded: model.initiallyExpanded)
```

选中项变化时视图把该行滚入可视区；`selected` 是普通 `State<String>`，右栏据此查询与展示，单向数据流。

### 与 SplitView 组合

左树与右详情由 `SplitView` 分隔，边界可拖动、可键盘微调。两个组件各自独立，组合起来就是一个完整的
资源管理器骨架——这也是对上一迭代 `SplitView` 的端到端复用验证。

## 运行

```powershell
cd examples/file_explorer
cjpm run
```

点击箭头展开/折叠目录、点击文件查看右侧详情；或 `Tab` 聚焦左树后用方向键与空格导航，拖动中间分隔条
调整左右比例。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot explorer.bmp"
```
