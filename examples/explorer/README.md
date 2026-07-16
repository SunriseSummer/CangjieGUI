# explorer：文件浏览器（面包屑）

一个仿资源管理器的文件浏览器，集中演示 `Breadcrumb` 面包屑路径导航：工具栏“上级”按钮与可点段跳回的路径
构成上下两个方向的导航；目录内容按 名称/修改日期/大小 三列展示，整行可点、悬停高亮、单击文件选中，底部
状态栏统计条目并展示选中详情。模拟目录树与导航逻辑都是纯函数。

## 演示要点

- 工具栏：`IconButton` “上级”返回上一级（根目录下置灰）+ `Breadcrumb` 显示 根目录 › … › 当前 的层级路径
- 点路径中任意一段跳回该层（`onSelect(下标)`）；末段是当前位置，强调显示、不可点；超长时中间折叠为省略号
- 目录列表按三列展示：列头行与条目行共享同一组列几何常量（`row.cj`），表头与内容天然对齐；大小列右对齐，
  文件夹展示子项数、文件按 B/KB/MB 格式化（KB 向上取整、MB 一位小数，与资源管理器惯例一致）
- 整行可点的自定义 `EntryRow` 组件：悬停高亮 + 指针手型（`ctx.claimHover`），单击文件夹进入、单击文件选中
  （选中行以强调浅底常显）；名称列裁剪到自身宽度，长名截断不侵入右侧列
- 底部状态栏：条目计数（文件夹/文件分列）与选中文件详情；任何导航都清除选中，状态与目录内容永远一致
- 模拟目录树、沿路径查找、列目录、面包屑分段/导航、大小格式化都是纯函数，与视图无关，便于单测

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | `FsNode` 目录树（含大小/修改日期元数据）、沿路径查找、列目录、面包屑分段与导航、大小格式化 |
| [model.cj](src/model.cj) | `ExplorerModel`：当前路径与选中文件；目录内容、计数、选中详情的派生 |
| [views.cj](src/views.cj) | 标题、工具栏（上级 + 面包屑）、列头 + 条目列表、状态栏 |
| [row.cj](src/row.cj) | 自定义 `EntryRow`/`EntryHeaderRow`：整行点击、悬停高亮、三列几何 |
| [theme.cj](src/theme.cj) | 浅色主题与文件夹/弱化色 |

## 关键实现

### 面包屑与目录列表共享同一份路径

当前路径是唯一数据源；面包屑分段与目录内容都由它派生，点击面包屑截断路径、点文件夹压入路径、“上级”
弹出末段，任何导航都顺带清除选中：

```cangjie
func segments(): Array<String> { pathSegments(path.value) }        // ["根目录", ...path]
func navigateTo(i: Int64): Unit { path.value = pathForSegment(path.value, i); selected.value = "" }
func openFolder(name: String): Unit { path.value = pathInto(path.value, name); selected.value = "" }
func goUp(): Unit { path.value = pathForSegment(path.value, path.value.size - 1); selected.value = "" }
```

`Breadcrumb` 的 `onSelect` 回调收到被点段的下标，直接交给 `navigateTo`，路径随即更新、视图重建。

### 列头与条目行共享列几何

三列的分界由行矩形现算，条目行与列头行走同一套函数，表头与内容不会随窗口宽度错位：

```cangjie
func nameColumnX(frame: Rect): Float32 { frame.x + ENTRY_PAD_X + ENTRY_ICON_SIZE + ENTRY_ICON_GAP }
func modifiedColumnX(frame: Rect): Float32 { frame.right() - ENTRY_PAD_X - COL_SIZE_W - COL_MODIFIED_W }
func sizeColumnRight(frame: Rect): Float32 { frame.right() - ENTRY_PAD_X }
```

## 运行

```powershell
cd examples/explorer
cjpm run
```

单击文件夹逐层进入、单击文件选中查看详情，“上级”或顶部面包屑任意一段跳回。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot explorer.bmp"
```
