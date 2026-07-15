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

底层另有 `ScrollBar(dragId: String)` 辅助类（`press`/`drag`/`dragging` 方法），供自定义可滚动控件复用滚动条的命中与拖动逻辑；它不是可直接置入树的组件。

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

### LazyGrid

数据驱动、按行窗口化的等宽网格（一行是一个 `Grid` 骑在 `LazyColumn` 上），单元格可为任意组件。

```cangjie
LazyGrid<T>(data: Array<T>, columns: Int64, itemHeight: Float32,
    spacing!: Float32 = 0.0, columnSpacing!: Float32 = 0.0,
    scroll!: ?State<Float32> = None, id!: ?String = None) { item => ... }
```

- columns：列数；columnSpacing! 为列间距，spacing! 为行间距。
- 尾随闭包：`item => 单元格内容`。

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

`Dropdown`/`ComboBox` 弹出列表、`ContextMenu` 菜单、`Modal` 对话框均由浮层栈承载，可嵌套（对话框内可再开下拉）。

### Tooltip

提示气泡。悬停约 500ms 后在树上层绘制；透明包裹，不改变布局与事件。

```cangjie
Tooltip(text!: String) { ... }
```

- text!：提示文字；尾随闭包为被包裹的内容。

### ContextMenu

右键菜单。为子内容附加右键菜单，指针处弹出，选中运行动作并关闭、外点/Esc 取消、方向键与悬停移动高亮。

```cangjie
ContextMenu(items!: Array<MenuItem>) { ... }
```

- items!：菜单项；尾随闭包为附加菜单的内容。

### MenuItem

`ContextMenu` 的菜单项。

```cangjie
MenuItem(label: String, action: () -> Unit)
```

- label：条目文字；action 选中时执行。

### Modal

模态对话框。`presented` 为真时暗化背景 + 居中面板，承载真实控件子树；拦截全部输入，`Tab` 在对话框内循环（焦点陷阱）；外点/Esc 关闭。

```cangjie
Modal(presented: Bindable<Bool>, onDismiss!: ?() -> Unit = None) { ... }
```

- presented：是否呈现（绑定）。
- onDismiss!：关闭回调；尾随闭包为对话框内容（仅呈现时构建）。

---

## 十一、事件与帧包装器

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
