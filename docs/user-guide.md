# CUI 使用指南

## 1. 声明式视图与链式配置

CUI 使用仓颉尾随 Lambda 描述视图树。控件构造函数只接收内容、状态、事件等必要信息，布局和外观
通过链式调用逐项配置：

```cangjie
VStack {
    Label("设置").fontSize(FontSizes.TITLE)
    HStack {
        Button("保存", save).role(ButtonRole.Primary).width(120.vp)
        Button("取消", cancel).width(120.vp)
    }.spacing(8.vp)
}.spacing(12.vp).padding(16.vp)
```

`if`、`match`、`for-in` 和普通函数都可直接参与构建。可复用组件通常写成返回 `Unit` 的函数；已有
Widget 实例可用 `emit(widget)` 放入当前构建块。

修饰器按调用顺序形成包装节点，顺序会影响约束、绘制范围和命中区域。例如：

```cangjie
Label("状态").padding(10.vp).background(Color.rgb(235, 240, 255), 8.vp)
Label("状态").background(Color.rgb(235, 240, 255), 8.vp).padding(10.vp)
```

第一种写法的背景包含 padding；第二种写法在背景外增加 padding。该规则适用于所有通用修饰器。

## 2. 尺寸与单位

导入 `LengthUnits`（`cui` 根包已重新导出）后，整数与浮点字面量获得三个单位后缀，
构成带单位的 `Length` 值：

| 单位 | 写法 | 含义 | 解析规则 |
|---|---|---|---|
| 虚拟像素 | `100.vp` | 密度无关的逻辑坐标单位，布局的默认度量 | 原值 |
| 物理像素 | `100.px` | 设备物理像素 | 除以窗口 `scale` |
| 字体像素 | `15.fp` | 跟随用户字体缩放的字号单位 | 乘以 `fontScale` |

```cangjie
Panel {
    Label("正文").fontSize(15.fp)
}.contentPadding(16.vp).width(320.vp)

VStack(spacing: 12.vp, padding: LengthInsets(18.vp)) { ... }
Label("标题").padding(10.vp, 5.vp)          // 水平、垂直
Icon(IconName.Save).iconSize(22.vp)
```

要点：

- `Length` 只携带值与单位，转换发生在布局/绘制阶段，由 `UiContext.resolve` 按当前窗口
  `displayScale` 与应用 `fontScale` 计算，因此同一棵树在不同缩放下无需改代码。
- `1.5.vp`、`(columns * 96).vp` 等浮点与表达式写法同样成立；`Length` 支持 `* / ` 标量运算。
- 四边独立的内边距用 `LengthInsets`：`LengthInsets(all)`、`LengthInsets(horizontal, vertical)`、
  `LengthInsets(top: ..., right: ..., bottom: ..., left: ...)`。
- 所有尺寸修饰器同时保留 `Float32` 重载，裸浮点按 `vp` 解释、字号按 `fp` 解释，
  便于迁移；新代码建议统一书写单位。
- 权重（`flex(2.0)`）、进度（`0.0..1.0`）、缩放因子等无量纲数值仍使用浮点，这不是尺寸。
- `DesktopApp(spec, fontScale: 1.25)` 全局放大 `fp` 尺寸；`app.setMinimumSize(w, h)` 以逻辑
  像素约束窗口最小尺寸，防止布局被挤出屏幕。

## 3. 通用修饰器

所有 `Widget` 都支持：

- 尺寸：`width`、`height`、`minWidth`、`maxWidth`、`minHeight`、`maxHeight`（接受 `Length` 或按 vp 解释的 `Float32`）。
- 填充：`fillWidth`、`fillHeight`。
- 间距：`padding(all)`、`padding(horizontal, vertical)`、`padding(left, top, right, bottom)`。
- 绘制：`background(color)`、`background(color, radius)`、`surface(style)`。
- 布局：`flex()`、`flex(weight)`。
- 条件：`visible(bool)`、`enabled(bool)`。

尺寸始终受父级可用空间约束。`visible(false)` 会退出测量、布局、绘制和事件分发，不会留下相邻
间距；`enabled(false)` 保留布局并抑制输入。

## 4. 状态模型

### 4.1 可观察抽象

状态体系由两个接口组织：

- `Observable<T>`：可读可观察 —— `get()`、`revision`、`observe`、`map`。
- `Bindable<T> <: Observable<T>`：在此之上可写 —— `value` 属性、`project`。

`State<T>` 实现 `Bindable`，是可写的单一事实源；`DerivedState<T>` 实现 `Observable`，
是从其他状态计算出的只读值。展示型控件（如 `ProgressBar`）接受 `Observable`，
交互控件（如 `Switch`、`TextField`）接受 `Bindable`，因此两者可以互换使用。

### 4.2 共享状态

```cangjie
let count = State<Int64>(0)

app.run {
    HStack {
        Label("计数：${count.value}")
        Button("增加", {=> count.update({value => value + 1})})
    }
}
```

每次赋值都会增加 `revision`。`observe` 同步通知 `(旧值, 新值)`，返回的 `StateObservation` 实现
`Resource`，调用 `close` 后不再接收通知。观察回调和 UI 状态修改应位于 UI 线程。
当 `T` 可判等时，`setIfChanged(next)` 仅在值变化时赋值并返回是否触发了通知。

状态应提升到所有读写者的最低共同祖先；向下传状态，向上传事件。复杂界面可把一组相关状态和 UI
逻辑收拢到普通模型类中，避免多个控件各自维护同一业务事实。

### 4.3 派生状态

`derive` 与 `map` 从一个或多个状态计算只读值，结果带缓存：仅当来源 `revision` 变化时才重新
计算，适合放在每帧重建的视图里，也适合收拢在模型类中：

```cangjie
let tasks = State<Array<Task>>(seed())
let filter = State<Int64>(0)

let countText = derive(tasks, filter, {list, f => "${filterTasks(list, f).size} 项"})
let percent = completed.map<String>({value => "${Int64(value * 100.0)}%"})

Label(countText.value)          // 直接读取，卡片与计数永不脱节
ProgressBar(completed)
```

`derive` 有一到三个来源的定长重载；来源为动态数量的同型状态时，用
`derive(sources: Array<Observable<A>>, {values => ...})` 聚合任意多个（如汇总一组计数器）。
`DerivedState.observe` 仅在被观察期间订阅上游，不会在每帧构建中泄漏监听器。

### 4.4 双向绑定投影

`project` 把大模型状态的一个分量投影成独立的 `Bindable`，读写都落回源状态：

```cangjie
let profile = State<Profile>(Profile("林", true))
let name = profile.project<String>(
    get: {p => p.name},
    set: {p, next => Profile(next, p.subscribed)}
)
TextField(name, key: "profile.name")   // 编辑姓名即更新整个 profile
```

### 4.5 局部状态与身份

根构建闭包每帧执行。仅属于局部子树的状态可使用 `rememberState`：

```cangjie
Keyed("task:${task.id}") {
    let expanded = rememberState<Bool>("expanded") { false }
    taskCard(task, expanded)
}
```

- 同一 scope 内的 key 必须唯一且类型稳定，重复或换型会抛出 `IllegalStateException`。
- `Keyed` 使用显式业务身份隔离重复组件，不应使用会随排序变化的位置作为 key。
- 成功构建后未再次访问的局部状态会被清理；重新挂载时使用初始值。
- `TextField`、`TextArea`、`ScrollView` 会基于稳定 ID 保留隐式光标或滚动状态；也可链式传入外部状态。

### 4.6 列表与身份

`ForEach` 为集合中的每个条目建立以业务键命名的 `Keyed` 子树，插入、删除或重排时局部状态
跟随条目而不是位置：

```cangjie
ForEach(tasks, key: {task => "task.${task.id}"}) {
    task => taskCard(task)
}
```

仅在条目不会重排时才可使用按位置命名的 `ForEachIndexed`。

## 5. 布局规则

CUI 遵循单向布局协商：父级给出可用空间，子项返回期望尺寸，父级决定最终位置。控件不能越过父级
约束任意扩张；需要占满空间时显式使用 `fillWidth`、`fillHeight` 或 `flex`。

### 5.1 线性栈

`VStack` 与 `HStack` 提供：

- `.spacing(value)`：相邻子项间距（`Length` 或按 vp 解释的 `Float32`）。
- `.mainAxisAlignment(...)`：`Start`、`Center`、`End`、`SpaceBetween`、`SpaceAround`、`SpaceEvenly`。
- `.crossAxisAlignment(...)`：`Start`、`Center`、`End`、`Stretch`。
- `.flexible(bool)`：是否参与父栈剩余空间分配。

```cangjie
HStack {
    Button("左", left).flex()
    Button("中", center).flex(2.0)
    Button("右", right).flex()
}.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Center)
```

`Flexible` 仍可用于带构建块的兼容写法；新代码通常直接对任意 Widget 调用 `.flex(weight)`。

### 5.2 组合容器

- `ZStack`：按声明顺序从后向前绘制，事件反向命中；`.alignment` 设置二维对齐。
- `Grid(columns)`：固定等宽列、内容高度行；`.spacing` 设置行列间距。
- `FlowRow`：从左到右布局，空间不足时自动换行。
- `ScrollView`（可选 `key`）：垂直裁剪滚动视口，滚轮命中受视口限制；`.scrollState` 可接管偏移。
  内容超出高度时自动为滚动条预留右侧轨道，滚动条不会覆盖内容；裁剪采用栈式管理，
  内部的文本框、画布等自带裁剪的控件不会破坏视口边界。滚动条滑块可直接拖动（拖动时
  高亮），点击轨道空白处按方向翻页；拖动记录抓取点，不会跳变。
- `Panel`：主题面板；`.contentPadding`、`.style`、`.flexible` 配置内部布局。

## 6. 文字、按钮与图标

```cangjie
Label("警告")
    .muted(false)
    .textAlign(TextAlign.Center)
    .foregroundColor(Color.rgb(190, 55, 70))
    .fontSize(FontSizes.TITLE)

Label("可能很长的说明文字……").maxLines(2)   // 在可用宽度内换行，超出部分省略

Button("删除", remove)
    .role(ButtonRole.Danger)
    .width(120.vp)
```

单行 `Label` 超出可用宽度时自动以省略号截断，不会绘制到边界之外；`.maxLines(n)` 允许换行到
n 行，`.wrap()` 不限行数。换行优先落在空格处，CJK 文本可在任意字符处断行。

`Button`、`IconButton` 和二态选择控件在主鼠标键释放且指针仍位于控件内时激活，并支持焦点后的
Enter/Space。控件默认按声明顺序获得构建期唯一的交互身份，同名按钮、成对图标按钮无需额外配置
即可各自响应；仅当身份需要跨树形变化保持（例如按钮在容器间移动）时才用 `.key` 显式指定。

焦点遵循桌面惯例：一次鼠标按下要么把焦点移交给认领它的控件，要么清除当前焦点——点击空白
或不可聚焦区域会让文本框失焦并恢复常规样式。取得焦点的按钮显示强调色描边，提示 Enter/Space
的作用目标；`UiContext.clearFocus()` 可编程清除焦点。

键盘焦点遍历：`Tab` 依声明顺序在可聚焦控件间前移、`Shift+Tab` 后移，到达两端自动环绕；
无焦点时 `Tab` 进入首个控件、`Shift+Tab` 进入末个控件。可聚焦控件（按钮、文本框、开关、
复选框、单选、滑块、选择器、步进器）在构建期自动登记进遍历环，无需手工维护 Tab 顺序；
只读 `TextArea` 不作为编辑停靠点，不参与遍历。遍历由外壳统一处理，不会被聚焦控件吞掉，
因此聚焦的文本框中按 `Tab` 也会移动焦点而非插入制表符。`UiContext.focusNext()` /
`focusPrevious()` 亦可编程驱动。`.enabled(false)` 的子树同时离开遍历环——`Tab` 不会停在无法激活
的控件上；禁用可作用于任意粒度：单个控件、一行 `HStack` 表单或整个面板（子树全部焦点停靠点经
`focusableIds()` 一并摘除）。同理，`TabView` 中非活动页面的停靠点不入环——隐藏页收不到事件，
停在那里只会是死角；切换页签后下一帧自动恢复。

焦点环只在**键盘聚焦**时显示（`:focus-visible` 惯例）：`Tab` 遍历或 `autofocus` 到达的控件绘制
强调色描边，而鼠标点击虽然同样获得焦点，却不留下这圈描边——避免点击后到处是聚焦轮廓的视觉噪声。
这只影响描边是否绘制；选区、光标、方向键等行为一律以“是否聚焦”为准，与聚焦来源无关。**每个**可聚焦
控件都画这圈描边——文本框、列表、表格、下拉、选择器、步进器围住整框，按钮、图标按钮、复选框、单选、
开关则由统一的强调色外扩描边环住控件本体（含实心的主要/危险按钮，其焦点此前不可见）——因此键盘
逐一走查表单时，焦点落在哪个控件一目了然。

指针悬停反馈：指针停在可交互控件上时，控件请求相应的系统光标形状——按钮、开关、滑块等
呈手形（`Interactive`），可编辑文本区呈工字形（`Text`），其余区域回落到窗口静止光标
（`Default`）。悬停在每次鼠标移动时单次结算，视觉层叠中最顶层的控件胜出。应用可用
`DesktopApp.useBaseCursor(SystemCursor)` 设定静止光标（例如画布用十字光标），悬停形状仍会
正确叠加在其之上。内置控件在 `handle` 中认领形状；自定义 `Widget` 在指针落入自身边界时调用公开的
`ctx.claimHover(id, CursorShape.Interactive)` 即可同样接入（内置控件使用的 `claimHoverIfInside`
是框架内部助手，不属于应用 API）。

`Icon` 支持 `.iconSize`、`.foregroundColor`；`IconButton` 支持 `.label`、`.role`、`.style`、`.key`；
`Divider` 支持 `.axis`、`.color`。

## 7. 选择、导航与数值控件

```cangjie
let enabled = State<Bool>(true)
let mode = State<Int64>(0)
let volume = State<Float32>(0.5)
let quantity = State<Int64>(3)

VStack {
    Checkbox("启用", enabled)
    Switch("桌面通知", enabled)
    RadioButton("标准", mode, 0)
    RadioButton("专业", mode, 1)
    Picker(["浅色", "深色", "系统"], mode, key: "theme")
    Stepper(quantity, key: "quantity").range(1, 20).step(1)
    Slider(volume, key: "volume").range(0.0, 1.0)
    ProgressBar(volume).range(0.0, 1.0)
}
```

这些控件接受任何 `Bindable`（`ProgressBar` 接受 `Observable`），因此既可以传 `State`，
也可以传 `project` 投影或 `map` 派生的值。`SegmentedControl` 适合少量并列选项，`TabView` 的
body 按标签顺序声明页面——两者都是焦点停靠点：`Tab` 聚焦后 `Left`/`Right` 切换选中段/页签
（端点钳制），键盘到达时绘制焦点环；`TabView` 的页签条停靠点排在页内控件之前，与视觉顺序一致。
`ListView` 保存选中索引并支持外部滚动状态，可用 `Tab` 聚焦、方向键（↑/↓/Home/End）移动选择并
自动把选中行滚入可视区，聚焦时显示强调边框。`Picker` 是紧凑的前后选择控件，空数据时保持安全占位。

`ScrollView`、`TextArea`、`ListView` 的滚动条滑块均可直接拖动（拖动时高亮，记录抓取点不跳变），
点击轨道空白处按方向翻页；三者共用同一 `ScrollBar` 拖动控制器与几何函数，行为完全一致。

`Table(columns, rows, selected, key)` 是多列数据表：`TableColumn(title, width, numeric)` 定义列，
`rows` 是按列索引的字符串单元格。表头固定、表体窗口化滚动（只绘制可见行，长表也不变慢）；点击列头
按该列排序、再次点击反向，数值列（`numeric: true`）右对齐并按数值而非字典序排序（`88` 排在 `100` 前）。
选择以**原始行索引**存储，故排序改变显示顺序时高亮仍跟随同一行；`Tab` 聚焦后 `↑/↓/Home/End` 在显示
顺序里移动选择并滚入视区。适合服务器列表、记录表等后台数据网格：

```cangjie
Table([
    TableColumn("主机名", 180.0),
    TableColumn("连接数", 120.0, numeric: true)
], model.rows, model.selected, key: "fleet.table").flex()
```

列可通过 `cell` 回调接管单元格绘制（进度条、色块、徽标），排序仍按字符串值进行——显示与排序键解耦。
回调收到原始行索引、单元格字符串与单元格矩形，在表格画好行底/选中并裁剪之后只负责内容；它仅绘制、
不接收事件，行点击照常选中：

```cangjie
TableColumn("CPU %", 100.0, numeric: true, cell: {ctx, _, value, cell =>
    drawLoadBar(ctx, value, cell) // 自绘负载条；"87" 仍按数值参与排序
})
```

数据强类型时，`Table.of(data, columns, selected, key)` 免去手搭字符串矩阵：`data` 是 `Array<T>`，
每个 `DataColumn<T>(title, width, numeric)` 以尾随抽取器从行取出单元格串（同时用于显示与排序），
列头与取值就近成对；排序、选择与字符串形一致。抽取器逐帧运行，故超大且持续重绘的表仍宜用预建矩阵
的原始形：

```cangjie
Table.of(model.servers, [
    DataColumn("主机名", 180.0)                { s => s.host },
    DataColumn("连接数", 120.0, numeric: true)  { s => "${s.connections}" }
], model.selected, key: "fleet.table").flex()
```

`ScrollView { VStack { ... } }` 会构建、布局、绘制全部子节点，内容越多越慢。列表很长时改用惰性虚拟化
容器，只物化视口附近的行，每帧成本恒为一屏。`LazyColumn(count, itemHeight) { index => 行(index) }`
是定高行、按索引惰性构建的纵向列表；数据驱动时用 `LazyColumn.of(data, itemHeight, key) { item => 行(item) }`
——传入数据与行构建器，免去 `data.size` 与 `data[i]` 回查，`key` 令每行局部状态随项（而非槽位）走。
行高为逻辑像素，须等于（或不小于）行的自然高度，否则按行裁剪截断，适合稳定定高、不因宽度回流的行：

```cangjie
LazyColumn.of(model.notes, 72.0, key: {n => n.id}, id: "notes") { note => noteRow(note) }
```

`LazyGrid(data, columns, itemHeight, spacing, columnSpacing) { item => 单元格 }` 是数据驱动、按行
窗口化的等宽网格：`data` 铺成 `columns` 等宽列，一行是一个 `Grid`，骑在纵向 `LazyColumn` 上，无需单独的
横向滚动；单元格可为任意控件（不限字符串），适合卡片墙、图库（见 `examples/gallery`）：

```cangjie
LazyGrid(photos, 4, 180.0, spacing: 14.0, columnSpacing: 14.0, id: "gallery") { photo => photoCard(photo) }
```

`Tooltip(text: "...") { 控件 }` 为任意控件添加悬停提示：指针在控件上停留约半秒后，提示气泡
绘制在整棵树之上（锚定控件下方，越界时翻到上方并钳制在窗口内）。它是透明包裹层，不改变布局
与事件；移开指针即隐藏。适合为图标按钮补充文字说明或快捷键提示。

`Dropdown(items, selected)` 是真正的下拉选择：闭合态显示当前项与下拉箭头，点击或 `Enter`/`Space`/`↓`
打开；弹出列表浮于整棵树之上（下方放不下整个列表时翻到上方）。点击某项选中并关闭，
点击列表外或按 `Esc` 关闭，`↑`/`↓` 移动高亮。列表高于上下两侧可用空间时在弹层**内部滚动**：
滚轮滚动、右缘滑块可拖动、方向键移动高亮时自动滚入视野，打开时选中行即滚至可见（长列表居中）。
弹出列表由**交互式浮层**承载——它先于树接收事件，故列表点击不会被下方控件截走；这套浮层机制
（`Overlay` + `UiContext.setOverlay`）也可用于菜单等。

`ComboBox(text, options)` 是可编辑下拉（组合框）：它内嵌一个 `TextField`（因此继承完整的文本编辑——
光标、选区、撤销、剪贴板），并配一个建议列表浮层。键入即按输入过滤建议，点击某项或按回车填入该项，
`↓` 打开列表、`↑`/`↓` 移动高亮、`Esc` 关闭；长建议列表与 `Dropdown` 一样在弹层内部滚动（滚轮、
可拖动滑块、高亮自动滚入视野）。与 `Dropdown` 的区别在于值是**自由文本**——不在候选里的
输入也会保留，适合“可选可填”的字段（城市、标签、搜索）。

`ContextMenu(items) { body }` 为任意控件附加右键菜单：在子区域按下右键即在指针处弹出菜单，
选中项运行其动作并关闭，点击别处或按 `Esc` 取消，`↑`/`↓` 与鼠标移动移动高亮、`Enter` 运行高亮项。
它是透明包裹器——布局、绘制与其余事件都转交子控件，仅拦截落在子区域内的右键。菜单同样浮于整棵树
之上（复用 `Dropdown` 的交互式浮层），按最长项自动定宽、超出窗口时向左/上收拢。菜单条目 `MenuItem(label, action)`
适合承载工具栏之外的次级动作：

```cangjie
ContextMenu(items: [
    MenuItem("新建笔记", {=> model.addNote()}),
    MenuItem("复制笔记", {=> model.duplicateSelected()}),
    MenuItem("删除笔记", {=> model.confirmDelete.value = true})
]) {
    Panel { ListView(model.titles(), model.selected) }
}
```

`Modal(presented) { body }` 是模态对话框：`presented` 为真时在暗化背景之上居中一个面板。与提示、下拉、
右键菜单不同，模态**承载真实控件子树**——`body` 里的按钮、文本框等都是正常控件，布局在面板内、事件经
浮层路由给它们。它拦截一切输入（背景不可交互）：`Tab`/`Shift+Tab` 只在对话框自己的可聚焦控件间循环
（焦点陷阱，不会逃逸到背景），每帧 `Frame` 事件会转发进子树（`autofocus` 等定时行为在对话框内照常
生效）；点击面板外或按 `Esc` 关闭；仅在呈现时构建 `body`（隐藏的对话框不占空间、不注册可聚焦项）。
它自身零尺寸，放进根部 `ZStack` 即可对视口居中，隐藏时完全不影响下方布局。浮层可嵌套：对话框内的
`Dropdown`/`ComboBox`/`ContextMenu` 照常可用——其弹出列表经**浮层栈**压在对话框之上绘制并优先
接收事件，`Esc` 与外点逐层关闭（先弹出列表、后对话框）。适合确认危险操作、表单录入等：

```cangjie
ZStack {
    appContent(model)
    Modal(model.confirmDelete) {
        VStack {
            Label("删除这条笔记？").fontSize(FontSizes.TITLE)
            Label("删除后无法恢复。").muted().fontSize(FontSizes.CAPTION)
            HStack {
                Spacer()
                Button("取消", {=> model.confirmDelete.value = false})
                Button("删除", {=> model.deleteSelected(); model.confirmDelete.value = false}, role: ButtonRole.Danger)
            }.spacing(8.vp)
        }.spacing(14.vp).minWidth(240.vp)
    }
}
```

控件的状态切换由弹簧动画平滑过渡，而非瞬间跳变：`Switch` 滑块滑动、`Checkbox` 勾选从中心放大、
`RadioButton` 圆点长出、`ProgressBar` 填充与百分比一起滑向目标值，`SegmentedControl` 与 `TabView` 的
选中指示器滑到新段/标签。动画由 `Spring` 原语驱动：
它是一个弹簧-阻尼数值，在 `draw` 中按帧间隔 `tick`、读取 `value`——渲染循环即动画时钟，无需独立的
动画定时器；控件用 `animate(ctx, target:)` 把“设目标+推进+读值”合成一步，并在动画未停住时请求下一帧，
使空闲跳帧的帧循环不致把过渡跳没。`Spring`
在到达目标后精确停住，空闲时零开销；初始化在当前值即“已停住”，因此静态首帧不产生动画（快照稳定）。
这一原语可用于任意平滑过渡，不限于上述控件。

## 8. 文本输入

```cangjie
let title = State<String>("")
let body = State<String>("")
let bodyScroll = State<Float32>(0.0)
let bodyCursor = State<Int64>(0)
let bodyAnchor = State<Int64>(0)

VStack {
    TextField(title, key: "title")
    TextArea(body, key: "body", scroll: Some(bodyScroll), cursor: Some(bodyCursor), anchor: Some(bodyAnchor))
}
```

`key`（可选）同时参与焦点和隐式状态身份，给定时须稳定且唯一，缺省则按构建顺序自动派生。外部状态
均为可选构造参数；持有光标就必须连同
锚点一起持有并**成对改写**（例如载入文件后把两者一起移到文末）——只改光标会残留一段用户从未
选择的“幻影选区”，下一次键入会直接替换它覆盖的内容。`TextEditState` 按 UTF-8 字符边界执行插入、删除、
左右移动、行首行尾与上下行移动。是否可编辑由构造参数 `editable` 决定（默认 `true`）：只读 `TextArea`
不登记进 Tab 遍历、不显示焦点环，但仍允许滚动和光标导航。

插入光标与字形行等高对齐、按标准节奏闪烁；点击定位使用与绘制一致的真实文本测量，比例字体与
中文文本都会落在最近的字符边界。超出可视宽度的内容被裁剪在控件表面之内。聚焦的文本控件每帧向
系统上报光标矩形（`SDL_SetTextInputArea`），因此**输入法候选窗跟随插入光标**出现在输入位置附近，
而不是屏幕角落；光标随键入、点击或滚动移动时候选窗同步跟随。

文本选区：`TextField` 与 `TextArea` 均支持完整的选区操作——按住 `Shift` 配合方向键、`Home`/`End`
扩展选区（`TextArea` 另支持 `Shift+↑`/`Shift+↓` 按列跨行扩展），鼠标按下拖动框选，`Ctrl+A` 全选。
选中后键入或粘贴会替换选区，`Backspace`/`Delete` 删除选区，`Ctrl+C`/`Ctrl+X`/`Ctrl+V` 复制、剪切、
粘贴（剪贴板不可用时静默降级；粘贴的多行文本在单行 `TextField` 中折叠为空格，`TextArea` 中保留
换行）。选区高亮以半透明强调色绘制在文字之下；`TextArea` 的多行选区中，被选中的换行使该行高亮
延伸至视口右缘，呈现常见的整行选中效果。选区与光标坐标均使用真实字形测量，比例字体与中文一致
精确。选区语义位于共享的 `TextEditState`，`anchor` 与 `cursor` 重合即无选区，因此从不选择的只读
文本区行为保持不变（只读态仍可选择与复制，但不可剪切或粘贴）。

双击选中光标处的词、三击选中整行（含行尾换行）。词的判定按字符类归并——ASCII 字母数字与下划线、
以及非 ASCII 字符（如中文）算作词字符，连续空白与连续标点各自成段。点击计数由 `UiContext`
统一识别（400ms、4px 阈值内递增，最多三击后归位），是可复用的通用原语，任意控件都能据此响应
双击，不限于文本。

`TextField.autofocus()` 让搜索框、对话框首个输入框在首帧自动获得键盘焦点，打开即可键入；
聚焦为一次性，其后由用户操作决定。

`TextField` 与 `TextArea` 支持撤销/重做：`Ctrl+Z` 撤销、`Ctrl+Y` 或 `Ctrl+Shift+Z` 重做。
连续快速编辑（500ms 内）合并为一个撤销步，停顿后另起一步，因此撤销按“词/句”而非逐字符回退；
光标跳转（点击或方向键）也会立即另起一步，一次撤销不会跨越两个编辑位置。一次未改变文本的操作
（如行首退格）不产生多余撤销步。撤销历史随控件保留，也可通过控件的
`undo()`/`redo()` 方法编程驱动（例如工具栏撤销按钮）。

光标始终保持可见：`TextField` 在值超出可视宽度时水平滑动文本窗口跟随光标（命中测试与选区同步
偏移），`TextArea` 在键盘编辑、导航与撤销后把光标所在行滚入视口——在长文档末尾持续键入不会“盲打”。

## 9. 事件、画布与图像

`EventHandler` 在子树前接收 `UiEvent`；返回 `true` 表示消费。`FrameHandler` 每帧接收 `FrameInfo`。

```cangjie
CanvasWidget({renderer, rect => drawScene(renderer, rect)})
    .onEvent({event, rect => handleSceneEvent(event, rect)})
```

自定义画布处理指针事件时，凡是“按下开始、松开结束”的手势都必须检查事件坐标是否落在自己的
`rect` 内，画布外的事件返回 `false` 放行，否则会吞掉同窗口其他控件的手势收尾。

`ImageView(path).fit(ImageFit.Contain)` 像其他控件一样**逐帧内联声明**即可：解码后的纹理由按路径
键控的共享缓存持有，重建只花一次查表、不触碰磁盘；加载失败也会被记住，不会每帧重试。覆盖图片
文件后调用 `invalidateImage(path)` 让下一帧重载（`clearImageCache()` 清空全部）。尺寸建议使用通用
`width`/`height` 修饰器。其余实现 `Resource` 的长期资源交给 `DesktopApp.manage`，临时资源使用
try-with-resources 或显式 `close`。

## 10. 后台任务与桌面能力

UI 构建、布局、事件和绘制位于同一线程。文件扫描、系统命令、网络请求等耗时工作应由 `spawn`
执行，以 `Mutex`、原子对象或并发容器把不可变结果交回 `FrameHandler`；后台闭包必须自行
try/catch，把失败信息与成功结果走同一条回传通道，避免忙碌标志被异常卡死。文件对话框返回异步
`FileDialogRequest`，不得在 UI 线程同步等待。

## 11. 快照与视觉验证

`DesktopApp` 识别 `--snapshot <path.bmp>`，稳定绘制若干帧后保存 BMP 并退出。cjpm 1.0.5 使用
`--run-args` 传递应用参数：

```powershell
cjpm run --run-args "--snapshot output.bmp"
```

`contacts`、`planner` 与 `data_board` 是新布局、状态和控件的综合端到端示例；`contacts` 把
`Table`、`ComboBox`、`Modal`、`ContextMenu` 组合成一个增删改查界面，`data_board` 额外演示了
`derive` 派生计数与 `ForEach` 列表身份。
