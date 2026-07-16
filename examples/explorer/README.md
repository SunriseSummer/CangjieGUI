# explorer：文件浏览器（面包屑）

一个模拟文件浏览器，集中演示 `Breadcrumb` 面包屑路径导航：顶部路径可点段跳回、超长自动折叠，
配合可进入的目录列表，构成完整的上下导航。模拟目录树与导航逻辑都是纯函数。

## 演示要点

- `Breadcrumb` 显示 根目录 › … › 当前 的层级路径，段间以 chevron 分隔（strokeLine 绘制，避开字体缺字）
- 点路径中任意一段跳回该层（`onSelect(下标)`）；末段是当前位置，强调显示、不可点
- 路径过长时（`maxItems`）中间折叠为省略号，保留首段与末尾若干段
- 下方列出当前目录：文件夹可点进入（压入路径），文件为静态行；文件夹在前、文件在后
- 模拟目录树、沿路径查找、列目录、面包屑分段/导航都是纯函数，与视图无关，便于单测

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | `FsNode` 目录树、沿路径查找、列目录、面包屑分段与导航（均为纯函数） |
| [model.cj](src/model.cj) | `ExplorerModel`：当前路径；目录内容与面包屑分段的派生 |
| [views.cj](src/views.cj) | 标题、面包屑、当前目录列表（文件夹行/文件行） |
| [theme.cj](src/theme.cj) | 浅色主题与文件夹/弱化色 |

## 关键实现

### 面包屑与目录列表共享同一份路径

当前路径是唯一数据源；面包屑分段与目录内容都由它派生，点击面包屑截断路径、点文件夹压入路径：

```cangjie
func segments(): Array<String> { pathSegments(path.value) }        // ["根目录", ...path]
func navigateTo(i: Int64): Unit { path.value = pathForSegment(path.value, i) } // 截断到第 i 段
func openFolder(name: String): Unit { path.value = pathInto(path.value, name) } // 压入子文件夹
```

`Breadcrumb` 的 `onSelect` 回调收到被点段的下标，直接交给 `navigateTo`，路径随即更新、视图重建。

## 运行

```powershell
cd examples/explorer
cjpm run
```

点文件夹逐层进入，点顶部面包屑任意一段跳回。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot explorer.bmp"
```
