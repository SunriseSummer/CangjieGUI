[cui](../../index.md) › [cui.controls](index.md) › TreeView

# TreeView

位于 `cui.controls` 包的公开类

带展开/折叠的层级列表——文件浏览器、大纲、导航树。节点由 [`TreeNode`](TreeNode.md) 根数组描述；视图把当前展开的节点摊平成行，只绘制视口附近的行（大树也只花一屏的代价），用户点行选中、点箭头或用键盘揭示层级。

## 声明

```cangjie
public class TreeView <: Widget
```

## 继承

- [`Widget`](../core/Widget.md)

## 说明

选中以节点 id 为键（而非行号——展开与折叠会移动其下所有行），`selected` 绑定持有选中节点的 id，空串表示无选中；选中变化时（含从外部写入绑定）该行滚入可视区。展开集由控件的稳定标识跨构建保留：用 `initiallyExpanded` 设置初始展开的节点，或经 `expanded` 由外部持有以便持久化或协同。行高为 `max(28, 有效文字行高 + 8)` 逻辑像素；内容装得下时滚轮留给外层滚动容器（无死区）。切换展开会更新可观察状态，宿主在绘制前完成必要的重建与布局，使行结构和命中区域一致。

聚焦后的键盘导航：Up/Down 在可见行间移动，Home/End 跳到两端，Right 展开折叠节点、已展开则步入第一个子行，Left 折叠展开节点、否则步出到父行，Enter/Space 切换当前节点的展开。点击行选中它；点击行首箭头切换展开。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("TreeView", 640, 420))
    app.run {
        let selected = rememberState<String>("selected") {""}
        let tree = TreeView(
            [
                TreeNode(
                    "docs",
                    "docs",
                    children: [
                        TreeNode("docs/guide.md", "guide.md"),
                        TreeNode("docs/api.md", "api.md")
                    ]
                ),
                TreeNode("README.md", "README.md")
            ],
            selected,
            initiallyExpanded: ["docs"]
        )
        // 运行时：展开目录并选择文件，方向键按当前可见行顺序移动。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 以节点根数组与选中 id 绑定构造树视图。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`scrollState(value: State<Float32>)`](#scrollstate) | 改用外部持有的滚动偏移，便于恢复与协同。 |
| [`measure(_: UiContext, available: Size)`](#measure) | 占满全部可用尺寸（[`Widget`](../core/Widget.md) 协议）。 |
| [`layout(_: UiContext, rect: Rect)`](#layout) | 记录分配的矩形作为视口与命中的基准（[`Widget`](../core/Widget.md) 协议）。 |
| [`draw(ctx: UiContext)`](#draw) | 只绘制视口附近的可见行，并按需滚入新选中的行（[`Widget`](../core/Widget.md) 协议）。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 处理行点击、箭头切换、滚动与键盘导航（[`Widget`](../core/Widget.md) 协议）。 |
| [`isFlexible()`](#isflexible) | 恒为 `true`：参与父栈的剩余空间分配（[`Widget`](../core/Widget.md) 协议）。 |
| [`focusableId()`](#focusableid) | 返回控件注册的键盘焦点标识（[`Widget`](../core/Widget.md) 协议）。 |

## 构造函数

### init

以节点根数组与选中 id 绑定构造树视图。

```cangjie
public init(
    roots: Array<TreeNode>,
    selected: Bindable<String>,
    scroll!: ?State<Float32> = None,
    expanded!: ?State<HashSet<String>> = None,
    initiallyExpanded!: Array<String> = [],
    key!: ?String = None
)
```

**参数**

- `roots`: `Array<`[`TreeNode`](TreeNode.md)`>` — 顶层节点，按数组顺序展示；节点 id 须全树唯一。
- `selected`: [`Bindable`](../core/Bindable.md)`<String>` — 选中节点 id 的双向绑定，空串表示无选中；写入不存在的 id 即无选中行。
- `scroll!`: `?`[`State`](../core/State.md)`<Float32>` — 外部持有的滚动偏移（逻辑像素）；默认 `None` 由视图标识内部保留。
- `expanded!`: `?State<HashSet<String>>` — 外部持有的展开 id 集；默认 `None` 由视图标识内部保留。传入后 `initiallyExpanded` 不生效。
- `initiallyExpanded!`: `Array<String>` — 内部保留展开集时的初始展开 id；默认 `[]` 全部折叠。
- `key!`: `?String` — 稳定标识，须在同一次构建内唯一；默认 `None` 按声明顺序自动派生，需要跨结构变化保留滚动/展开/选中或外部协同时传入。

**异常**

- `IllegalArgumentException` — `key` 传入空字符串时。

## 方法

### scrollState

改用外部持有的滚动偏移，便于恢复与协同。与构造参数 `scroll` 等效的链式写法，返回自身。

```cangjie
public func scrollState(value: State<Float32>): TreeView
```

**参数**

- `value`: `State<Float32>` — 外部持有的滚动偏移（逻辑像素）。

**返回值** `TreeView` — 自身，便于链式声明。

### measure

占满全部可用尺寸（[`Widget`](../core/Widget.md) 协议）。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `available`: `Size` — 父级提供的可用尺寸（逻辑像素）。

**返回值** `Size` — 与 `available` 相同。

### layout

记录分配的矩形作为视口与命中的基准（[`Widget`](../core/Widget.md) 协议）。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 分配给控件的框架矩形（逻辑像素）。

### draw

只绘制视口附近的可见行，并按需滚入新选中的行（[`Widget`](../core/Widget.md) 协议）。滚动偏移越界时先限制在有效范围；选中自上一帧起变化时（含外部写入）以最小滚动量把选中行带进可视区，普通滚动不受影响。行内容为缩进、展开箭头（有子节点时）、可选图标与标签，选中行整行强调底；内容溢出视口时右缘画滚动条。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 帧服务上下文。

### handle

处理行点击、箭头切换、滚动与键盘导航（[`Widget`](../core/Widget.md) 协议）。左键按下先给滚动条（拖拽滑块或按轨道翻页），再按行命中：落在箭头列且有子节点时切换展开，否则选中该行；点击同时夺取键盘焦点。滚轮只在内容溢出时消费；聚焦后 Up/Down/Home/End/Right/Left/Enter/Space 按类型摘要所述导航。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: `UiContext` — 帧服务上下文。
- `event`: `UiEvent` — 本帧派发的输入事件。

**返回值** `Bool` — 点击、滚动或键盘导航被消费时为 `true`。

### isFlexible

恒为 `true`：参与父栈的剩余空间分配（[`Widget`](../core/Widget.md) 协议）。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 恒为 `true`。

### focusableId

返回控件注册的键盘焦点标识（[`Widget`](../core/Widget.md) 协议）。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 恒为 `Some`，值为构造时确定的控件标识。

## 另请参阅

- [TreeNode](TreeNode.md) — 树的节点数据。
- [ListView](ListView.md) — 扁平列表选择控件。
- [SplitView](SplitView.md) — 常与树搭配的分栏布局（见 `examples/file_explorer`）。
