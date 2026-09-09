# command_palette：命令面板

一个键盘驱动的模糊命令启动器（类似编辑器的 Ctrl+P），集中演示多项交互能力：
自动聚焦搜索、派生结果列表，以及“焦点在搜索框、方向键操控列表”的经典命令面板交互。

## 演示要点

- `TextField.autofocus()`：面板一出现就聚焦搜索框，打开即可键入
- 应用级键盘路由：`↑/↓/回车` 为何要在应用根部（`EventHandler`）拦截，而非依赖列表自身聚焦
- 结果列表是查询的纯函数（`filterCommands`），无需缓存；`State.observe` 在查询变化时归零高亮
- `DerivedState`（`query.map`）派生结果条数
- 大小写不敏感的中英文混合匹配（中文按标题、英文按 `keywords` 别名）
- 深色浮层主题的配色令牌组织

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口：窗口、最小尺寸 |
| [data.cj](src/data.cj) | `Command` 与命令目录、`filterCommands` 匹配 |
| [model.cj](src/model.cj) | `PaletteModel`：查询/高亮/记录、派生条数、归零观察者、执行逻辑 |
| [views.cj](src/views.cj) | 搜索框、结果列表、提示栏、执行记录，以及根部键盘路由 |
| [theme.cj](src/theme.cj) | 深色主题与字号令牌 |

## 关键实现

### 焦点在搜索框，方向键操控列表

命令面板的核心机制是始终在搜索框输入，同时用方向键在结果间移动、回车执行。若依赖 `ListView`
自身的键盘导航，就需先把焦点从搜索框移到列表，破坏“边输入边选择”的体验。因此在应用根部拦截：

```cangjie
func handlePaletteKeys(event: UiEvent, model: PaletteModel): Bool {
    match (event) {
        case UiEvent.KeyDown(Key.Up, _) => model.moveSelection(-1); true
        case UiEvent.KeyDown(Key.Down, _) => model.moveSelection(1); true
        case UiEvent.KeyDown(Key.Enter, _) => model.runSelected(); true
        case _ => false   // 打字、Left/Right、Ctrl+Z 照常落到聚焦的搜索框
    }
}
```

`EventHandler` 的 `onEvent` 先于子树运行，返回 `true` 即消费该事件；因此 `↑/↓/回车` 不会到达
搜索框，其余按键（含撤销）照常交给搜索框处理。

### 结果是查询的纯函数

模型不缓存结果列表：`results()` 每次都由当前 `query` 实时计算。高亮索引在查询变化时归零，
保证键入后总是选中最匹配的首项：

```cangjie
this.queryObservation = this.query.observe({_, _ => selection.value = 0})
```

### 中英文混合匹配

每条命令带一组小写英文别名，匹配时对标题按原样、对别名按小写，因此中文标题也能被英文关键词命中：

```cangjie
command.title.toAsciiLower().contains(needle) || command.keywords.contains(needle)
```

## 运行

```powershell
cd examples/command_palette
cjpm run
```

打开后直接键入（如“保存”“undo”“zoom”）筛选，`↑/↓` 选择，回车执行，执行结果累积在下方记录中。
支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot palette.bmp"
```

## 练习与验收

增加一条带英文别名的命令，验证中文、别名、方向键和回车路径。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
