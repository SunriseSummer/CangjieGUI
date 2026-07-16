# CUI 组件手册

本手册逐条列出 CUI 的全部 UI 组件（含布局容器），给出构造签名、参数说明、可用修饰符与用法示例。
所有组件经 `import cui.*` 即可获得。底层几何、颜色、窗口、输入等类型见
[SDL API 参考](../sdl/docs/api-reference.md)，框架整体 API 见 [API 参考](api-reference.md)。

## 一、通用约定

- 声明即构建：在容器的尾随闭包 `{ ... }` 中直接书写子组件，构造函数会把自己登记到当前构建块；
  也可用 `emit(widget)` 登记一个已持有的实例。闭包内可自由使用 `if`/`for` 等控制流。
- 尺寸单位：`Length` 分 `px`（物理像素）、`vp`（虚拟像素）、`fp`（字体像素）。凡接受 `Length` 的
  参数/修饰符都另有 `Float32` 重载，尺寸按 `vp` 解释、字号按 `fp` 解释，例如 `12.vp`、`14.fp`。
- 状态类型：可交互控件的状态参数为 `Bindable<T>`（可传 `State<T>` 或 `Binding<T>`），只读展示控件
  为 `Observable<T>`。
- 标识 `key`/`id`：控件的焦点、按压与局部状态以此为键，均为可选命名参数（缺省按构建顺序自动派生），
  写在内容与状态参数之后；按钮与二态选择控件以链式 `.key(...)` 设定。惰性列表（`LazyColumn`/`LazyGrid`）的容器身份
  参数名为 `id!`，其余控件为 `key!`。仅当身份需跨树形变化保持（控件在容器间移动，或跨结构保留光标/
  滚动状态）时才需显式给定。

### 通用修饰符

以下修饰符对任意组件可用，均返回 `Widget`（可继续链式，但其后不能再接组件专属修饰符）：

| 分类 | 修饰符 |
|---|---|
| 固定/边界尺寸 | `width`、`height`、`minWidth`、`maxWidth`、`minHeight`、`maxHeight`（`Length` 或 `Float32`） |
| 填充 | `fillWidth()`、`fillHeight()` |
| 间距 | `padding(all)`、`padding(horizontal, vertical)`、`padding(left, top, right, bottom)` |
| 表面 | `background(color)`、`background(color, radius)`、`surface(style)` |
| 弹性 | `flex()`、`flex(weight)`（在所在栈的剩余空间中按权重占位） |
| 条件 | `visible(isVisible)`、`enabled(isEnabled)` |

---

## 二、布局容器

### VStack

纵向堆叠子组件。

```cangjie
VStack(spacing!: Length = 8.vp, padding!: LengthInsets = LengthInsets.zero(),
    flexible!: Bool = true) { ... }
```

- spacing!：相邻子项间距。
- padding!：内容四周留白。
- flexible!：是否沿父的主轴填充；默认 `true`（填充），设 `false`（或用 `hug()`）则按内容收缩。

修饰符：`spacing`、`mainAxisAlignment`、`crossAxisAlignment`、`flexible`、`hug`。

```cangjie
VStack {
    Label("标题")
    Label("副标题").muted()
}.spacing(4.vp).hug()
```

### HStack

横向排列子组件。参数、修饰符与 `VStack` 一致（主轴为水平方向）。

```cangjie
HStack(spacing!: Length = 8.vp, padding!: LengthInsets = LengthInsets.zero(),
    flexible!: Bool = true) { ... }
```

修饰符：`spacing`、`mainAxisAlignment`、`crossAxisAlignment`、`flexible`、`hug`。

### ZStack

层叠子组件，后声明者绘制在上层。

```cangjie
ZStack { ... }
```

修饰符：`alignment(Alignment)`——按九宫格方向对齐各层（`TopLeading` 至 `BottomTrailing`）。

### Grid

等宽定列网格，子项按行优先填入。

```cangjie
Grid(columns: Int64) { ... }
```

- columns：列数，小于 1 抛 `IllegalArgumentException`。

修饰符：`spacing(all)`、`spacing(horizontal, vertical)`（`Length` 或 `Float32`）。

```cangjie
Grid(3) {
    metricCard(); metricCard(); metricCard()
}.spacing(12.vp)
```

### FlowRow

横向流式排列，空间不足自动换行。

```cangjie
FlowRow { ... }
```

修饰符：`spacing(all)`、`spacing(horizontal, vertical)`（`Length` 或 `Float32`；后者为行/列间距）。

### Panel

带主题表面（背景、圆角、边框）的容器，承载单个内容块。

```cangjie
Panel(padding!: LengthInsets = LengthInsets(12.vp), style!: ?SurfaceStyle = None,
    flexible!: Bool = true) { ... }
```

- padding!：内容与面板边缘的留白。
- style!：覆盖主题默认表面样式。
- flexible!：是否沿父主轴填充；`hug()` 令其按内容收缩。

修饰符：`contentPadding`（`Length`/`(horizontal, vertical)`/`LengthInsets`/`Insets`）、`style`、`flexible`、`hug`。

### ScrollView

纵向滚动容器，内容超高时可滚动。

```cangjie
ScrollView(key!: ?String = None) { ... }
```

- key!：滚动区身份，缺省按构建序派生，用于跨帧保留滚动偏移。

修饰符：`scrollState(State<Float32>)`——由外部状态接管滚动偏移。

用法：溢出时在右侧预留滚动条轨道（不遮挡内容），滑块可拖动、轨道可翻页、支持滚轮。

底层另有 `ScrollBar(dragId: String)` 辅助类（`press`/`drag`/`dragging` 方法），供自定义可滚动控件复用滚动条的命中与拖动逻辑；其横向对应物为 `HScrollBar(dragId: String)`（同一组方法，作用于横轴，`LazyRow` 的底部滚动条即由它驱动）。二者都不是可直接置入树的组件。

### SplitView

分栏容器：以可拖动的分隔条在两个窗格间分配空间，横向（并排，竖直分隔条）或纵向（上下，水平分隔条）。
可嵌套以构成多区布局（如导航｜编辑｜信息）。

```cangjie
SplitView(axis!: Axis = Axis.Horizontal, ratio!: ?Bindable<Float32> = None, initialRatio!: Float32 = 0.5,
    minFirst!: Float32 = 96.0, minSecond!: Float32 = 96.0, dividerThickness!: Float32 = 8.0,
    key!: ?String = None, first!: () -> Unit, second!: () -> Unit)
```

- axis!：分栏方向。`Horizontal` 左右分栏、拖动分隔条左右调整；`Vertical` 上下分栏、上下调整。
- ratio!：第一窗格占内容（除去分隔条厚度）的比例（0~1）；缺省由视图身份内部保留（`initialRatio` 为初值），
  传入 `Bindable<Float32>` 则由外部持有以便持久化或联动。
- minFirst! / minSecond!：两窗格各自的最小逻辑像素；拖动到此即止。容器太小容纳不下两个最小值时，
  自动退化为按比例分配，任一窗格都不会塌缩为零。
- dividerThickness!：分隔条厚度（逻辑像素）。
- key!：视图身份，缺省按构建序派生。
- first! / second!：两个窗格各为独立的构建块，块内可声明任意多个组件（自动纵向堆叠），无需再包容器。

分隔条是位于两窗格之间的键盘焦点停靠点：聚焦后沿分栏轴的方向键微调（横向 Left/Right、纵向 Up/Down），
悬停或拖动时请求对应的横向/纵向调整光标。

```cangjie
SplitView(axis: Axis.Horizontal, ratio: model.sidebarRatio, minFirst: 170.0, minSecond: 360.0,
    first: {=> navigator() }) {=> editor() }
```

### Accordion

折叠面板：若干可展开/收起的分区，各有可点击的标题（带展开箭头）与展开时显示的内容体。适合设置分组、
FAQ、属性检查器。`single` 为真时展开一个分区自动收起其它（手风琴），否则各分区独立开合。

```cangjie
Accordion(sections: Array<AccordionSection>, single!: Bool = false,
    expanded!: ?State<HashSet<Int64>> = None, initiallyExpanded!: Array<Int64> = [], key!: ?String = None)
```

- sections：各分区（标题 + 内容体构建块）。
- single!：是否单开（手风琴模式）。
- expanded!：可选外部展开集（一组已展开分区下标）；缺省由视图身份内部保留。
- initiallyExpanded!：初始展开的分区下标（仅内部保留时作初值）。
- key!：可选身份，缺省按构建序派生。

每个分区标题是键盘焦点停靠点：聚焦后 Enter/Space 展开收起，`Tab` 遍历标题与展开体内的控件。仅展开的
分区体会被构建，故收起分区的局部状态在重新展开时重置。

### AccordionSection

`Accordion` 的一个分区：标题与其展开时构建的内容体（尾随闭包）。

```cangjie
AccordionSection("外观") {=> appearanceBody() }
```

### Spacer

弹性空白，在栈的主轴上撑开剩余空间（例如把其后的组件推到另一端）。

```cangjie
Spacer()
```

无修饰符。

### Flexible

权重包装容器：让其内容按 `weight` 占据所在栈的剩余空间。新代码可直接用通用修饰符 `.flex(weight)`。

```cangjie
Flexible(weight!: Float32 = 1.0) { ... }
```

---

## 三、集合与惰性列表

### LazyColumn

定高行的纵向惰性列表：只物化视口附近的行，成本恒为一屏，适合超长列表。

```cangjie
LazyColumn(count: Int64, itemHeight: Float32, spacing!: Float32 = 0.0,
    scroll!: ?State<Float32> = None, key!: ?((Int64) -> String) = None,
    id!: ?String = None) { i => ... }
```

- count：行总数。
- itemHeight：每行高度（vp）。
- spacing!：行间距。
- scroll!：外部滚动状态（缺省则内部按身份保留偏移）。
- key!：由行索引生成稳定键，令行的局部状态随数据项迁移。
- id!：列表身份（缺省按构建序派生）。
- 尾随闭包：`i => 行内容`，按行索引构建。

静态工厂（数据驱动，免去 `count` 与 `data[i]` 回查）：

```cangjie
LazyColumn.of<T>(data: Array<T>, itemHeight: Float32, spacing!: Float32 = 0.0,
    scroll!: ?State<Float32> = None, key!: ?((T) -> String) = None,
    id!: ?String = None) { item => ... }
```

```cangjie
LazyColumn.of(users, 56.0, key: {u => "u${u.id}"}, id: "users") { u => userRow(u) }
```

### LazyRow

定宽列的横向惰性列表：`LazyColumn` 的横向对应物，只物化视口附近的列，成本恒为一屏，适合超长横向条
（日期带、封面墙、时间轴）。鼠标滚轮横向滚动，内容溢出时底部出现滚动条。

```cangjie
LazyRow(count: Int64, itemWidth: Float32, spacing!: Float32 = 0.0,
    scroll!: ?State<Float32> = None, key!: ?((Int64) -> String) = None,
    id!: ?String = None) { i => ... }
```

- count：列总数；itemWidth：每列宽度（vp）；spacing!：列间距。
- scroll! / key! / id!：同 `LazyColumn`（滚动状态、稳定列键、列表身份）。
- 尾随闭包：`i => 列内容`，按列索引构建。

静态工厂（数据驱动）：

```cangjie
LazyRow.of<T>(data: Array<T>, itemWidth: Float32, spacing!: Float32 = 0.0,
    scroll!: ?State<Float32> = None, key!: ?((T) -> String) = None,
    id!: ?String = None) { item => ... }
```

### LazyList

变高行的纵向惰性列表：`LazyColumn` 的变高对应物，每行高度由 `heightOf(index)` 给出，适合行高随内容变化
的场景（聊天气泡、评论、图文卡片）。行偏移是高度的累加和、可见窗口由二分定位，故只构建可见行，偏移计算
是一次对高度值的轻量遍历。

```cangjie
LazyList(count: Int64, heightOf: (Int64) -> Float32, spacing!: Float32 = 0.0,
    scroll!: ?State<Float32> = None, key!: ?((Int64) -> String) = None,
    id!: ?String = None) { i => ... }
```

- count：行总数；heightOf：由行索引取该行高度，须 O(1)（取存好的或估算的高度，勿当场量文本），
  且要与该行实际绘制高度吻合，否则会重叠或留隙。
- spacing! / scroll! / key! / id!：同 `LazyColumn`。
- 尾随闭包：`i => 行内容`，按行索引构建。

静态工厂（数据驱动，高度由每项抽取）：

```cangjie
LazyList.of<T>(data: Array<T>, heightOf: (T) -> Float32, spacing!: Float32 = 0.0,
    scroll!: ?State<Float32> = None, key!: ?((T) -> String) = None,
    id!: ?String = None) { item => ... }
```

### LazyGrid

数据驱动、按行窗口化的等宽网格（一行是一个 `Grid` 骑在 `LazyColumn` 上），单元格可为任意组件。

```cangjie
LazyGrid<T>(data: Array<T>, columns: Int64, itemHeight: Float32,
    spacing!: Float32 = 0.0, columnSpacing!: Float32 = 0.0,
    scroll!: ?State<Float32> = None, id!: ?String = None) { item => ... }
```

- columns：列数；columnSpacing! 为列间距，spacing! 为行间距。
- 尾随闭包：`item => 单元格内容`。

### ReorderableList

可拖动重排的定高列表：每行左侧有拖动手柄，按住手柄上下拖动即改变顺序——拖动时其它行让开、被拖行悬浮，
松手回调 `onMove(from, to)` 由调用方对自己的数据施加移动，下一帧显示新序。行是普通组件，手柄以外的按压
落到行内容（其自身的控件照常工作），行身份随 `key` 迁移。适合完整可见的中小列表。

```cangjie
ReorderableList(count: Int64, rowHeight: Float32, onMove: (Int64, Int64) -> Unit,
    spacing!: Float32 = 6.0, key!: ?((Int64) -> String) = None, id!: ?String = None) { i => ... }
```

- count：行数；rowHeight：定高（vp）；onMove：`(from, to)` 提交回调，调用方据此重排数据。
- spacing! / key! / id!：行间距、稳定行键、列表身份。
- 尾随闭包：`i => 行内容`。

静态工厂（数据驱动，`onMove` 收到数组下标）：

```cangjie
ReorderableList.of<T>(data: Array<T>, rowHeight: Float32, onMove: (Int64, Int64) -> Unit,
    spacing!: Float32 = 6.0, key!: ?((T) -> String) = None, id!: ?String = None) { item => ... }
```

### ForEach

按业务键为每个数据项建立带稳定身份的 `Keyed` 子树，插入/删除不扰动其余项的局部状态。

```cangjie
ForEach<T>(items: Iterable<T>, key!: (T) -> String) { item => ... }
```

```cangjie
ForEach(tasks, key: {t => "task.${t.id}"}) { t => taskCard(t) }
```

### ForEachIndexed

按位置命名的变体，仅适用于不重排的集合。

```cangjie
ForEachIndexed<T>(items: Iterable<T>) { index, item => ... }
```

### Keyed

为子树建立稳定命名空间，令其中 `rememberState` 的局部状态在重建间保留、并随身份隔离。

```cangjie
Keyed(key: String) { ... }
```

```cangjie
Keyed("note.${note.id}") {
    let draft = rememberState<String>("draft") {note.body}
    TextArea(draft, key: "note.body")
}
```

---

## 四、展示组件

### Label

文本标签。单行超宽自动省略号截断；`maxLines(n)` 换行至 n 行（末行截断），`wrap()` 不限行数。

```cangjie
Label(text: String, muted!: Bool = false, align!: TextAlign = TextAlign.Leading,
    color!: ?Color = None, fontSize!: Length = Length(FontSizes.BODY, LengthUnit.Fp))
```

- text：文本内容。
- muted!：是否用次要文字色。
- align!：水平对齐（`Leading`/`Center`/`Trailing`）。
- color!：覆盖文字色。
- fontSize!：字号。

修饰符：`muted()`、`muted(Bool)`、`textAlign(TextAlign)`、`foregroundColor(Color)`、`fontSize(Length | Float32)`、`maxLines(Int64)`（须大于 0）、`wrap()`。

### RichText

内联样式文本：由若干 `RichSpan`（着色文本段与内联图标）拼成一行，超宽自动换行到多行。文本段共享同一
字号、以颜色区分（渲染层无粗斜体、无逐段基线度量），图标随文流动。是 `Label`（单一样式）的多样式、
图文混排对应物。

```cangjie
RichText(spans: Array<RichSpan>, fontSize!: Length = Length(FontSizes.BODY, LengthUnit.Fp))
```

- spans：样式段数组；fontSize! 所有文本段共享的字号。

修饰符：`fontSize(Length | Float32)`。单行时按内容收缩（便于行内嵌入），换行后填满宽度。

### RichSpan

`RichText` 的一段：着色文本或内联图标。由工厂构造。

```cangjie
RichSpan.text(text: String, color!: ?Color = None) // 默认或指定颜色的文本段
RichSpan.muted(text: String)                        // 次要（弱化）文字色
RichSpan.icon(icon: IconName, color!: ?Color = None) // 内联图标，按行高取尺寸
```

### Icon

矢量图标，来自内置 `IconName` 图标集。

```cangjie
Icon(icon: IconName, size!: Length = ICON_DEFAULT_SIZE.vp, color!: ?Color = None)
```

- icon：图标名。
- size!：图标边长；color! 覆盖描边/填充色。

修饰符：`iconSize(Length | Float32)`、`foregroundColor(Color)`。

### Divider

分隔线。

```cangjie
Divider(axis!: Axis = Axis.Horizontal, color!: ?Color = None)
```

- axis!：方向（`Horizontal`/`Vertical`）。
- color!：线色。

修饰符：`axis(Axis)`、`foregroundColor(Color)`；`color(Color)` 为已弃用别名。

### StepIndicator

横向步骤条：多步流程（结账、引导、向导）的进度指示。一排编号节点由连接线相连，`current` 之前的步为已完成
（实心并打勾）、`current` 高亮、之后的步置灰；每步标签在节点下方。以展示为主——`current` 由流程自身的
上一步/下一步驱动；传 `onSelect` 可让已到达的步骤（下标 ≤ current）可点击，以跳回某个已完成的步骤。

```cangjie
StepIndicator(steps: Array<String>, current: Int64, onSelect!: ?(Int64) -> Unit = None, key!: ?String = None)
```

- steps：各步标签；current：当前步下标（0 起）。
- onSelect!：可选，点击某步回调（仅对下标 ≤ current 的已达步骤触发）；可点节点悬停显示交互光标。
- key!：可选身份（用于悬停光标协议；缺省按构建顺序自动派生）。

### Pagination

分页导航：为长列表、表格、搜索结果等分页内容提供页码切换。一排页码按钮夹在上一页/下一页箭头之间，始终显示
首页与末页、当前页附近 `window` 个页码，中间的空缺以省略号折叠。点页码跳到该页，箭头步进一页并在两端自动禁用。
`current` 是 0 起的当前页，双向绑定、显示为 1 起。总页数变化（如过滤后）时，把绑定的页码重置为 0 即可回到首页。

```cangjie
Pagination(pageCount: Int64, current: Bindable<Int64>, window!: Int64 = 1, key!: ?String = None)
```

- pageCount：总页数（至少 1）；current：当前页（0 起），双向绑定。
- window!：当前页两侧各显示的页码数（默认 1，即当前页 ± 1）。
- key!：可选身份（用于悬停光标协议；缺省按构建顺序自动派生）。可点的页码与未禁用的箭头悬停显示交互光标。

### Breadcrumb

面包屑路径导航：一排以 chevron 分隔的层级段（如 首页 › 文档 › 项目）。末段是当前位置，强调显示、不可点；
其前各段是链接，点击回调 `onSelect(下标)`。设了 `maxItems` 且路径更长时，中间折叠为省略号，保留首段与末尾若干段。
不传 `onSelect` 即为纯展示。

```cangjie
Breadcrumb(segments: Array<String>, onSelect!: ?(Int64) -> Unit = None, maxItems!: Int64 = 0, key!: ?String = None)
```

- segments：各层级名（末项为当前位置）；onSelect!：点击某段回调（仅对非末段的链接触发）。
- maxItems!：最多显示的实际段数（0 = 全显示）；超出时中间折叠为省略号。

### Badge

状态徽标：圆角药丸形，柔和底色 + 同色文字，纯展示。用于状态、分类、计数、标签等。颜色由 `kind` 决定：
`Neutral`（中性，随主题 mutedText）、`Accent`（主题强调）、`Danger`（随主题 danger）、`Info`/`Success`/`Warning`
（固定语义蓝/绿/黄）。徽标按文字宽度自适应。

```cangjie
Badge(text: String, kind!: BadgeKind = BadgeKind.Neutral)
```

- text：徽标文字；kind!：语义色，`BadgeKind` 取 `Neutral`/`Accent`/`Info`/`Success`/`Warning`/`Danger`。

### Chip

可选过滤标签：圆角药丸，绑定 `Bindable<Bool>`。点击（或聚焦后 Space/Enter）切换选中；选中时以强调色填充，
未选中为描边字段。常成排用作切换式过滤器。

```cangjie
Chip(text: String, selected: Bindable<Bool>, key!: ?String = None)
```

- text：标签文字；selected：绑定的选中态（双向）；key! 可选身份。

### ImageView

图片视图。解码纹理由按路径键控的共享缓存持有（含失败负缓存），可逐帧内联声明。

```cangjie
ImageView(path: String, fit!: ImageFit = ImageFit.Contain, preferredWidth!: ?Length = None,
    preferredHeight!: Length = 96.vp)
```

- path：图片文件路径。
- fit!：缩放方式，`ImageFit` 取 `Stretch`（拉伸）、`Contain`（完整容纳）、`Cover`（铺满裁剪）。
- preferredWidth! / preferredHeight!：期望尺寸。

修饰符：`fit(ImageFit)`。

相关函数：`invalidateImage(path)` 使单个路径失效并下帧重载；`clearImageCache()` 清空全部缓存。

### CanvasWidget

自定义绘制区域，直接以 `Renderer` 在给定矩形内绘制，并可处理该区域事件。

```cangjie
CanvasWidget(onDraw: (Renderer, Rect) -> Unit, onEvent!: (UiEvent, Rect) -> Bool = {_, _ => false})
```

- onDraw：绘制回调，参数为渲染器与本控件矩形。
- onEvent!：事件回调，返回是否消费。

修饰符：`onEvent((UiEvent, Rect) -> Bool)`。

---

## 五、按钮

### Button

文字按钮。鼠标释放或聚焦后 Enter/Space 触发，具备主题化的悬停与按压反馈。

```cangjie
Button(title: String, onClick: () -> Unit, role!: ButtonRole = ButtonRole.Normal,
    style!: ?SurfaceStyle = None, fontSize!: Length = Length(FontSizes.CONTROL, LengthUnit.Fp))
```

- title：按钮文字。
- onClick：点击回调。
- role!：语义配色（`Normal`/`Primary`/`Danger`）。
- style!：覆盖表面样式；fontSize! 文字字号。

修饰符：`key(String)`、`role(ButtonRole)`、`style(SurfaceStyle)`、`fontSize(Length | Float32)`。

```cangjie
Button("保存", {=> model.save()}).role(ButtonRole.Primary)
```

### IconButton

图标按钮，可选附带文字标签；触发与反馈同 `Button`。

```cangjie
IconButton(icon: IconName, label!: ?String = None, role!: ButtonRole = ButtonRole.Normal,
    style!: ?SurfaceStyle = None, onClick!: () -> Unit)
```

- icon：图标名；label! 可选文字；role!/style! 同 `Button`；onClick! 点击回调。

修饰符：`key(String)`、`label(String)`、`role(ButtonRole)`、`style(SurfaceStyle)`。

---

## 六、开关与选择控件

### Switch

二态开关。鼠标释放或聚焦后 Enter/Space 切换，附滑块弹簧动画。

```cangjie
Switch(label: String, checked: Bindable<Bool>)
```

- label：说明文字；checked 绑定的开关状态。

修饰符：`key(String)`。

### Checkbox

复选框。鼠标释放或 Enter/Space 切换，附勾选缩放动画。

```cangjie
Checkbox(label: String, checked: Bindable<Bool>)
```

修饰符：`key(String)`。

### RadioButton

单选项。多个实例共享同一 `Bindable<Int64>`，各自代表一个 `value`。

```cangjie
RadioButton(label: String, selected: Bindable<Int64>, value: Int64)
```

- label：说明文字；selected 共享选中值；value 本项代表的取值。

修饰符：`key(String)`。

```cangjie
RadioButton("从容", priority, 0)
RadioButton("平衡", priority, 1)
RadioButton("冲刺", priority, 2)
```

### SegmentedControl

分段单选。选中指示器弹簧滑动到新段；`Tab` 聚焦后 Left/Right 切换（端点钳制）。

```cangjie
SegmentedControl(items: Array<String>, selected: Bindable<Int64>, key!: ?String = None)
```

- items：各段文字；selected 选中索引；key! 可选身份（缺省按构建序派生）。

### Picker

循环选择器。点击前/后半区或 Left/Right 循环切换；宽度按最长选项自适应，切换不抖动。

```cangjie
Picker(items: Array<String>, selected: Bindable<Int64>, key!: ?String = None)
```

- items：选项；selected 选中索引；key! 可选身份（缺省按构建序派生）。

### Dropdown

下拉选择。点击/Enter 打开，列表浮于树上（下方放不下翻到上方）；选中/外点/Esc 关闭，上下键移动高亮；长列表在弹层内部滚动。

```cangjie
Dropdown(items: Array<String>, selected: Bindable<Int64>, key!: ?String = None)
```

- items：选项；selected 选中索引；key! 可选身份。

### DatePicker

日期选择器。闭合态显示所绑定的日期，点击/Enter/Space/Down 弹出月历浮层（下方放不下翻到上方）；
点选某日即选中并关闭，表头箭头翻月，外点/Esc 关闭。

```cangjie
DatePicker(selected: Bindable<CalendarDate>, key!: ?String = None)
```

- selected：绑定的日期（`CalendarDate`）；key! 可选身份（缺省按构建序派生）。

浮层内键盘：方向键移动高亮日（越月自动翻页），Home/End 上/下翻月，Enter/Space 确认高亮日，Esc 关闭。
绑定值恒为合法日期（见 `CalendarDate`）。

### CalendarDate

一个只含年、月、日的日历日（无时间、无时区），是 `DatePicker` 绑定的值类型。构造即归一：月钳到
1–12、日钳到当月天数，故不会产生 2 月 30 日之类的非法日期。日历运算（闰年、月长、星期、加日/加月）
直接按公历计算、纯函数且确定，仅 `today()` 读系统时钟。

```cangjie
CalendarDate(year: Int64, month: Int64, day: Int64)
```

方法：`today()`（静态，取今日）、`daysInMonth()`、`weekdayIndex()`（0=周日..6=周六）、
`firstWeekdayIndex()`、`withDay(d)`、`addingMonths(delta)`（加月并钳日）、`addingDays(delta)`（精确加日、跨月跨年）、
`iso()`（`YYYY-MM-DD`）、`compareTo(other)`（返回两日相差天数）、`==`/`!=`。

### TimePicker

时间选择器。闭合态显示所绑定的时间，点击/Enter/Space/Down 弹出浮层（下方放不下翻到上方）；浮层上半为 24 小时网格，
一点选时；下半为逐分钟编辑区，粗细三档：水平滑杆粗调（按 `minuteStep` 吸附，轨道两端恒为 00 与 59）、−/+ 按钮
逐分钟微调（在小时内环绕，59 → 00 不进位）、数值框快速键入（点框或直接敲数字：首位 6–9 立即生效，两位数补齐即生效，
Backspace 清除待定位，Enter 提交、Esc 放弃）。选时或调分即实时更新绑定值并保持浮层打开（选一个时间需时、分两步），
故外点（先提交待定输入）/Esc/Enter/Tab 关闭。

```cangjie
TimePicker(selected: Bindable<TimeOfDay>, minuteStep!: Int64 = 5, hour12!: Bool = false, key!: ?String = None)
```

- selected：绑定的时间（`TimeOfDay`）；minuteStep!：滑杆粗调吸附间隔（默认 5，钳到 1–60）——步进、键入与方向键
  始终逐分钟，任何分钟都可达；hour12!：闭合态是否用 12 小时制显示；key! 可选身份。

浮层内键盘：上/下逐分钟增减，左/右按整小时增减（均跨午夜环绕），数字键直接键入分钟，Enter/Space/Esc/Tab 关闭
（有待定输入时 Enter/Space 先提交、Esc 先放弃，浮层保持打开）。绑定值恒为合法 24 小时时间（见 `TimeOfDay`）。

### TimeOfDay

一个只含时（0–23）、分（0–59）的时刻（无日期、无时区），是 `TimePicker` 绑定的值类型。构造即归一：
自午夜起的总分钟对一天取模落到 0–1439，故跨午夜的运算干净环绕，不会产生 24:00 或 10:75 之类的非法时刻。
运算为纯整数分钟数、与平台时钟无关，仅 `now()` 读系统时钟。

```cangjie
TimeOfDay(hour: Int64, minute: Int64)
```

方法：`now()`（静态，取当前时刻）、`totalMinutes()`（自午夜起分钟数）、`withHour(h)`、`withMinute(m)`、
`addingMinutes(delta)`/`addingHours(delta)`（跨午夜环绕）、`format()`（24 小时 `HH:MM`）、
`format12()`（12 小时含 AM/PM）、`compareTo(other)`（返回相差分钟）、`==`/`!=`。

---

## 七、数值控件

### Slider

滑杆。拖动或聚焦后 Left/Right 调值。

```cangjie
Slider(value: Bindable<Float32>, key!: ?String = None, lower!: Float32 = 0.0,
    upper!: Float32 = 1.0, step!: Float32 = 0.0)
```

- value：绑定值；key! 可选身份。
- lower! / upper!：取值范围。
- step!：步长；大于 0 时数值吸附到 `lower + k*step` 刻度（离散滑杆），默认 0 为连续。

修饰符：`range(lower, upper)`、`step(Float32)`。

```cangjie
Slider(vol, key: "volume", lower: 0.0, upper: 1.0, step: 0.05)
```

### Stepper

步进器。加减按钮调整整数值；宽度按数值内容自适应。

```cangjie
Stepper(value: Bindable<Int64>, key!: ?String = None, lower!: Int64 = Int64.Min,
    upper!: Int64 = Int64.Max, step!: Int64 = 1)
```

- value：绑定值；key! 可选身份。
- lower! / upper!：范围（构造时即夹紧初值）。
- step!：步长，须大于 0，否则抛 `IllegalArgumentException`。

修饰符：`range(lower, upper)`、`step(Int64)`。

### ProgressBar

进度条（只读展示）。自带居中百分比与填充滑动动画。

```cangjie
ProgressBar(value: Observable<Float32>, lower!: Float32 = 0.0, upper!: Float32 = 1.0)
```

- value：进度来源；lower! / upper! 取值范围。

修饰符：`range(lower, upper)`。

### ProgressRing

环形进度（只读展示）：一圈轨道 + 从顶部顺时针扫到 `value`（0…1 分数，越界钳回）的弧，环心可显示百分比。
弧是圆角折线，任意尺寸都平滑，是线性 `ProgressBar` 的圆形对应物。

```cangjie
ProgressRing(value: Float32, diameter!: Float32 = 72.0, thickness!: Float32 = 8.0, showLabel!: Bool = true)
```

- value：完成度分数（0…1，自动钳定）；diameter!：环直径；thickness!：环粗；showLabel!：是否显示环心百分比。

### Rating

评分控件。一排圆点，填充到当前分、其后置空，绑定 0…count 的整数分（默认 5 点）。默认可交互：点某点评到该位，
再点当前分清除为 0，悬停预览填充；聚焦后方向键增减（左/下减、右/上加），Home 清零、End 满分。传 `readonly`
则为纯展示，不取焦点、不响应输入。

```cangjie
Rating(value: Bindable<Int64>, count!: Int64 = 5, readonly!: Bool = false, key!: ?String = None)
```

- value：绑定的分值（0…count）；count!：点数（默认 5）；readonly!：是否只读展示；key! 可选身份。

---

## 八、文本输入

外部状态（滚动、光标、锚点）均为可选命名参数；持有 `cursor!` 时应连同 `anchor!` 一并持有并成对改写，
否则会残留幻影选区。只读（`editable: false`）忽略编辑、不参与 Tab 遍历，仍可选择与复制。

### TextField

单行文本框。Shift 扩选、拖选、Ctrl+A/C/X/V、撤销/重做（Ctrl+Z/Y）；光标始终水平滚入可见。

```cangjie
TextField(text: Bindable<String>, key!: ?String = None, cursor!: ?State<Int64> = None,
    anchor!: ?State<Int64> = None, editable!: Bool = true)
```

- text：绑定文本；key! 可选身份。
- cursor! / anchor!：可选的外部光标与选区锚点。
- editable!：是否可编辑。

修饰符：`autofocus()`。方法：`undo()`、`redo()`。

### TextArea

多行文本区。多行选区、Shift+↑↓ 跨行扩选、拖选、Ctrl+A/C/X/V、撤销/重做；编辑后光标行滚入视口。

```cangjie
TextArea(text: Bindable<String>, key!: ?String = None, scroll!: ?State<Float32> = None,
    cursor!: ?State<Int64> = None, anchor!: ?State<Int64> = None, editable!: Bool = true)
```

- text：绑定文本；key! 可选身份。
- scroll!：可选外部滚动状态；cursor! / anchor! 同上；editable! 是否可编辑。

修饰符：`autofocus()`。方法：`undo()`、`redo()`。

### ComboBox

可编辑下拉：内嵌完整编辑的 `TextField` + 建议列表浮层。键入过滤（无匹配显示占位），点击/回车填入，自由文本亦保留；长建议列表在弹层内部滚动。

```cangjie
ComboBox(text: Bindable<String>, options: Array<String>, key!: ?String = None)
```

- text：绑定文本（可自由输入）；options 建议项；key! 可选身份。

---

## 九、列表、表格与标签页

### ListView

字符串单选列表。点击选择、滚轮滚动，`Tab` 聚焦 + 方向键导航；选择变化即滚入可视区。

```cangjie
ListView(items: Array<String>, selected: Bindable<Int64>, scroll!: ?State<Float32> = None,
    key!: ?String = None)
```

- items：条目文字；selected 选中索引。
- scroll!：可选外部滚动状态（缺省按身份保留偏移）；key! 可选身份。

修饰符：`scrollState(State<Float32>)`。

### TreeView

层级列表，带展开/折叠——文件浏览器、大纲、导航树。以 `TreeNode` 根节点描述层级，视图把当前展开的节点
扁平成行并窗口化（只绘制视口附近行，大树成本恒为一屏）。

```cangjie
TreeView(roots: Array<TreeNode>, selected: Bindable<String>, scroll!: ?State<Float32> = None,
    expanded!: ?State<HashSet<String>> = None, initiallyExpanded!: Array<String> = [], key!: ?String = None)
```

- roots：树的根节点数组。
- selected：选中的节点 id（用稳定 id 而非行索引——展开/折叠会移动其后所有行）；空串表示未选中。
- scroll!：可选外部滚动状态（缺省按身份保留偏移）。
- expanded!：可选外部展开集（一组已展开的节点 id）；缺省由视图身份内部保留。
- initiallyExpanded!：初始展开的节点 id（仅在内部保留展开集时作为初值）。
- key!：可选身份，缺省按构建序派生。

键盘（聚焦后）：↑↓ 在可见行间移动、Home/End 到两端、→ 展开折叠节点并步入、← 折叠展开节点并步出到父级、
空格/Enter 切换当前节点。点击行选中、点击箭头切换展开。

### TreeNode

`TreeView` 的节点：稳定 `id`、显示 `label`、可选前导 `icon` 与 `children`。id 须全树唯一（视图以其为键管理展开与选择）。

```cangjie
TreeNode(id: String, label: String, children!: Array<TreeNode> = [], icon!: ?IconName = None)
```

```cangjie
TreeView(roots, selected, initiallyExpanded: ["src", "src/core"])
```

### Table

多列数据表。固定表头、窗口化滚动；点击列头排序（再次反向，数值列按数值），行选择存原始行索引故排序后跟随；`Tab` + 方向键/Home/End 导航。

```cangjie
Table(columns: Array<TableColumn>, rows: Array<Array<String>>, selected: Bindable<Int64>,
    key!: ?String = None)
```

- columns：列定义；rows 按列索引的单元格字符串矩阵；selected 选中的原始行索引；key! 可选身份。

强类型工厂（以抽取器从行取值，免搭字符串矩阵）：

```cangjie
Table.of<T>(data: Array<T>, columns: Array<DataColumn<T>>, selected: Bindable<Int64>, key!: ?String = None)
```

### TableColumn

`Table` 的列定义。

```cangjie
TableColumn(title: String, width: Float32, numeric!: Bool = false,
    cell!: ?(UiContext, Int64, String, Rect) -> Unit = None)
```

- title：列头文字；width 列宽（vp）。
- numeric!：数值列右对齐并按数值排序（否则按 UTF-8 字节序）。
- cell!：可选自定义单元格绘制回调（参数为上下文、原始行索引、单元格串、单元格矩形）；仅绘制内容，排序仍按字符串值与 `numeric` 规则。

### DataColumn

`Table.of` 的强类型列定义，`value` 抽取器把行映射为单元格字符串。

```cangjie
DataColumn<T>(title: String, width: Float32, numeric!: Bool = false,
    cell!: ?(UiContext, Int64, String, Rect) -> Unit = None, value!: (T) -> String)
```

- 其余同 `TableColumn`；value! 为从行 `T` 取该列显示值的抽取器。

```cangjie
Table.of(users, [
    DataColumn("姓名", 160.0) {u => u.name},
    DataColumn("年龄", 80.0, numeric: true) {u => "${u.age}"}
], selectedRow, key: "users")
```

### TabView

标签页容器。页面按标签顺序声明；活动标签指示器弹簧滑动；页签条为焦点停靠点，聚焦后 Left/Right 切换。

```cangjie
TabView(labels: Array<String>, selected: Bindable<Int64>, key!: ?String = None) { pages }
```

- labels：各标签文字；selected 选中标签；key! 可选身份。
- 尾随闭包：按顺序声明与标签一一对应的页面。

---

## 十、浮层

`Dropdown`/`ComboBox` 弹出列表、`DatePicker` 月历、`ContextMenu`/`MenuBar` 菜单、`Modal` 对话框均由浮层栈承载，可嵌套（对话框内可再开下拉）。

### Tooltip

提示气泡。悬停约 500ms 后在树上层绘制；透明包裹，不改变布局与事件。

```cangjie
Tooltip(text!: String) { ... }
```

- text!：提示文字；尾随闭包为被包裹的内容。

### Toaster 与 ToastLayer

瞬态通知（Toast）。`Toaster` 是应用级控制器，从任意处 `show` 一条通知；在树中放一个 `ToastLayer(toaster)`
负责在右下角自底向上堆叠渲染、计时、滑入与淡出。`ToastLayer` 不占布局空间、不吞事件，并在有通知时驱动
帧刷新（时间动画所需），故置于根 `ZStack` 末层即浮于内容之上。

```cangjie
let toaster = Toaster()
toaster.show("已保存", kind: ToastKind.Success, durationMs: 3200)

ZStack {
    appContent()
    ToastLayer(toaster)
}
```

- `Toaster.show(message, kind!: ToastKind = Info, durationMs!: UInt64 = 3200)`：弹一条通知。
- `ToastKind`：`Info`/`Success`/`Warning`/`Error`，决定左侧强调条颜色。
- `ToastLayer(toaster)`：渲染与计时；每帧按 `FrameInfo.deltaMs` 老化通知、到期移除。

### ContextMenu

右键菜单。为子内容附加右键菜单，指针处弹出，选中运行动作并关闭、外点/Esc 取消、方向键与悬停移动高亮
（跳过分隔线与禁用项）。菜单项可带快捷键提示、禁用或为分隔线。

```cangjie
ContextMenu(items!: Array<MenuItem>, key!: ?String = None) { ... }
```

- items!：菜单项；尾随闭包为附加菜单的内容。
- key!：可选身份。缺省按构建顺序派生；当兄弟结构会动态增减时传入固定 key，保证打开状态与弹出位置不串位。

### MenuBar

应用菜单栏。横向排列若干顶层标题，点击展开其下拉菜单（浮于树上）；菜单打开时指针滑过其他标题即切换，
选中项运行动作并关闭、外点/Esc 关闭。是键盘焦点停靠点：聚焦后 Left/Right 移动标题、Enter/Space/Down
打开；打开后 Up/Down 移动高亮（跳过分隔线与禁用项）、Left/Right 切换菜单、Enter/Space 执行。

```cangjie
MenuBar(menus: Array<Menu>, key!: ?String = None)
```

- menus：顶层菜单数组；key! 可选身份（缺省按构建序派生）。

### Menu

`MenuBar` 的一个顶层菜单：标题与其下拉的菜单项。

```cangjie
Menu(title: String, items: Array<MenuItem>)
```

### MenuItem

`ContextMenu` 与 `MenuBar` 共用的菜单项：文字、选中动作，可选右对齐快捷键提示与禁用标志；
`MenuItem.separator()` 构造一条不可选中的分隔线。

```cangjie
MenuItem(label: String, action: () -> Unit, shortcut!: String = "", enabled!: Bool = true)
MenuItem.separator()
```

- label：条目文字；action 选中时执行。
- shortcut!：右对齐的快捷键提示文字（仅展示，不绑定实际按键）。
- enabled!：为 `false` 时置灰、不可高亮、不执行（可随状态动态传入）。

### Modal

模态对话框。`presented` 为真时暗化背景 + 居中面板，承载真实控件子树；拦截全部输入，`Tab` 在对话框内循环（焦点陷阱）；外点/Esc 关闭。

```cangjie
Modal(presented: Bindable<Bool>, onDismiss!: ?() -> Unit = None) { ... }
```

- presented：是否呈现（绑定）。
- onDismiss!：关闭回调；尾随闭包为对话框内容（仅呈现时构建）。

---

## 十一、事件、帧与动画

### EventHandler

在子树之前截获事件。

```cangjie
EventHandler(onEvent!: (UiEvent) -> Bool) { ... }
```

- onEvent!：事件回调，返回是否消费（消费则不再下发子树）；尾随闭包为被包裹内容。

### FrameHandler

接收每帧的 `FrameInfo`（用于自定义动画或逐帧逻辑）。

```cangjie
FrameHandler(onFrame!: (FrameInfo) -> Unit) { ... }
```

- onFrame!：每帧回调；尾随闭包为被包裹内容。

### Spring

弹簧动画原语（非组件，控件过渡的底层驱动）。持有一个朝目标收敛的浮点值，按临界阻尼弹簧步进，
开关、勾选、单选、进度、分段等控件的过渡都由它实现；自定义控件可复用同一原语。

```cangjie
Spring(value: Float32, stiffness!: Float32 = 210.0, damping!: Float32 = 24.0)
```

- value：初始值；stiffness! / damping!：弹簧刚度与阻尼（默认为控件过渡调校的临界阻尼组合）。

方法：`animate(ctx, target!)` 为绘制期一步到位的常用形式——重定目标、按本帧时长步进，未收敛时自动
`ctx.requestFrame()` 保证脏帧循环不冻结动画，返回新值；`animate(target!, deltaMs!)` 为无 ctx 的手动步进；
`target(value)` 重定目标、`reset(value)` 立即就位、`tick(deltaMs)` 仅步进、`settled()` 是否已收敛；
`value` 属性读取当前值。
