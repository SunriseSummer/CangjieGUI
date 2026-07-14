# CUI API 参考

本文记录 `cui` 根包重新导出的 GUI API。几何、渲染、窗口、事件、对话框、输入和系统能力见
[SDL API 参考](../sdl/docs/api-reference.md)。

## 1. 尺寸单位

| 类型/API | 说明 |
|---|---|
| `LengthUnit` | `Px`（物理像素）、`Vp`（虚拟像素）、`Fp`（字体像素）；`symbol()` 返回后缀名 |
| `Length` | 值 + 单位；`Length(value, unit)`、`Length.zero()`、`* Float32`、`/ Float32`、`toString` |
| `LengthUnits` | 字面量后缀接口：导入后 `Int64`/`Float64` 获得 `.px`、`.vp`、`.fp` 属性 |
| `LengthInsets` | 四边长度：`(all)`、`(horizontal, vertical)`、`(top:, right:, bottom:, left:)`、`zero()`、`of(Insets)` |

解析规则（`UiContext.resolve`）：`vp` 原值；`px` 除以 `displayScale`；`fp` 乘以 `fontScale`。
所有接受 `Length` 的修饰器同时提供 `Float32` 重载：尺寸按 `vp` 解释，字号按 `fp` 解释。

## 2. `Widget`

自定义控件实现以下协议：

| 方法 | 默认值/说明 |
|---|---|
| `measure(ctx, available): Size` | 在父级可用空间内返回期望尺寸 |
| `layout(ctx, rect): Unit` | 接收父级确定的最终矩形 |
| `draw(ctx): Unit` | 使用 `UiContext.renderer` 绘制 |
| `handle(ctx, event): Bool` | 返回事件是否已消费 |
| `isFlexible(): Bool` | 默认 `false` |
| `flexWeight(): Float32` | 默认 `1.0` |
| `acceptsStretch(axis): Bool` | 默认 `true`；显式最大/固定尺寸修饰器会拒绝对应轴拉伸 |
| `participatesInLayout(): Bool` | 默认 `true`；`visible(false)` 返回 `false` |

通用链式修饰器均返回 `Widget`（尺寸参数为 `Length`，另有按 vp 解释的 `Float32` 重载）：

| 分类 | API |
|---|---|
| 固定/边界尺寸 | `width`、`height`、`minWidth`、`maxWidth`、`minHeight`、`maxHeight` |
| 填充 | `fillWidth()`、`fillHeight()` |
| 间距 | `padding(all)`、`padding(horizontal, vertical)`、`padding(left, top, right, bottom)` |
| 表面 | `background(color)`、`background(color, radius)`、`surface(style)` |
| 弹性 | `flex()`、`flex(weight)` |
| 条件 | `visible(isVisible)`、`enabled(isEnabled)` |

`emit(widget)` 把已有实例登记到当前构建块；块外调用不产生登记行为。

## 3. 状态与身份

### 可观察接口

| 接口 | 成员 |
|---|---|
| `Observable<T>` | `get(): T`、`revision: UInt64`、`observe((T, T) -> Unit): StateObservation<T>`、`map<U>(transform): DerivedState<U>` |
| `Bindable<T> <: Observable<T>` | `value: T`（可读写属性）、`project<U>(get:, set:): Binding<U>` |

### `State<T>`（实现 `Bindable<T>`）

| API | 说明 |
|---|---|
| `State(value)` | 创建状态 |
| `value: T` | 可读写属性；每次写入增加修订号并同步通知观察者 |
| `revision: UInt64` | 只读修订号，极端溢出时回绕为 0 |
| `update((T) -> T)` | 函数式更新 |
| `observe((T, T) -> Unit): StateObservation<T>` | 观察后续写入；参数为旧值、新值 |
| `setIfChanged(next): Bool` | 仅 `T <: Equatable<T>`；值不同才赋值，返回是否触发通知 |

`StateObservation<T>` 实现 `Resource`，提供 `isClosed`、`close`。

### 派生与绑定

| API | 说明 |
|---|---|
| `derive(a, compute)` / `derive(a, b, compute)` / `derive(a, b, c, compute)` / `derive(sources: Array<Observable<A>>, compute)` | 从一至三个 `Observable`（或任意多个同型来源的数组）计算 `DerivedState<T>` |
| `DerivedState<T>` | 只读、带缓存：仅当来源 `revision` 变化时重新计算；实现 `Observable<T>`，另有 `value` 属性 |
| `Binding<T>` | `project` 产物；实现 `Bindable<T>`，读写均委托给源状态 |

### 局部状态

| API | 说明 |
|---|---|
| `rememberState<T>(key, initial): State<T>` | 在当前构建与身份 scope 中保留状态 |
| `Keyed(key) { ... }` | 为子树建立稳定命名空间 |
| `ForEach(items, key: (T) -> String) { item => ... }` | 每个条目一个 `Keyed` 子树，身份跟随业务键 |
| `ForEachIndexed(items) { index, item => ... }` | 按位置命名的变体，仅适用于不重排的集合 |
| `StateStore.remember` | 显式状态存储访问；重复 key 或 key 换型抛 `IllegalStateException` |
| `StateStore.clear` | 清空全部保留状态 |

`rememberState` 仅能在 `DesktopApp` 根视图构建或框架测试构建中使用；块外调用抛
`IllegalStateException`。空 key 抛 `IllegalArgumentException`。

控件的交互身份（焦点、按压）默认在每次构建中按声明顺序自动唯一化，并受 `Keyed` 命名空间
隔离；`.id(...)` 仅在身份需要跨树形变化保持时使用。

## 4. 上下文与枚举

`UiContext` 公开渲染器、主题、焦点/悬停/拖动/按压 ID、鼠标状态、关闭标志、`FrameInfo`，以及
`displayScale`、`fontScale` 两个缩放因子。方法包括：`requestClose`、`hasFocus`、`focus`、
`clearFocus`、`focusNext`、`focusPrevious`、`isHovered`、`claimHover(id, CursorShape)`、`beginDrag`、
`isDragging`、`clearDrag`、`press`、`isPressed`、`clearPress`、`resolve(Length): Float32`、
`resolve(LengthInsets): Insets`。

指针悬停：控件在 `handle` 中经 `claimHover` 请求一种
`CursorShape`（`Default` / `Interactive` / `Text`）；内置控件统一通过框架内部助手
`claimHoverIfInside` 调用它（该助手不对应用导出，自定义控件直接用 `claimHover`）。外壳在每次鼠标移动时结算最顶层的认领，并
把对应形状映射为 SDL 系统光标；`DesktopApp.useBaseCursor(SystemCursor)` 设定无人认领时的静止
光标。`isHovered(id)` 供绘制态使用（如按钮悬停浅高亮）。

焦点遵循“按下即结算”：一次主键按下后，若没有控件调用 `focus` 认领焦点，当前焦点被清除
（点击空白使文本框失焦）。该结算由 `DesktopApp` 在每次 MouseDown 分发后执行。

多次点击：`clickCount`（1 单击 / 2 双击 / 3 三击）由外壳在每次左键按下前经 `recordPress`
按时间（400ms）与距离（4px）阈值识别，控件在处理该次按下时读取。文本框据此实现双击选词、
三击选行，此原语对任意控件通用。

动画：`Spring(value, stiffness=210, damping=24)` 是弹簧-阻尼数值原语——`target(v)` 设定目标、
`tick(deltaMs)` 每帧推进、`value` 读取、`animate(target:, deltaMs:)` 把“设目标+推进+读值”合成
一步、`reset(v)` 无动画瞬置、`settled()` 判稳。控件在 `draw` 中按 `ctx.frame.deltaMs` 推进并读取，
适配逐帧重绘；到达目标后精确停住，空闲零开销。`Switch`（滑块/轨道色）、`Checkbox`（勾选缩放）、
`RadioButton`（圆点缩放）、`ProgressBar`（填充滑动）均以此实现状态切换的平滑过渡。
`Color.lerp(other, t)` 在两色间按 `t∈[0,1]` 线性插值（用于随动画过渡颜色）。

键盘焦点遍历：可聚焦控件在构建期按声明顺序登记进“焦点环”，`DesktopApp` 每帧构建后经
`adoptFocusRing` 采纳，并在收到 `Tab`（`Shift+Tab` 反向）时调用 `focusNext` / `focusPrevious`
环形移动焦点；`Tab` 由外壳消费，不下发给聚焦控件。只读 `TextArea` 不登记。`focusNext` /
`focusPrevious` 也可由应用直接调用（例如自定义快捷键或分步向导）。

焦点环仅在键盘聚焦时绘制：`UiContext` 记 `focusRingVisible`，`Tab` 遍历与 `focus(id, viaKeyboard: true)`
（`autofocus` 用）置真、指针 `focus(id)` 与 `clearFocus` 置假；控件用 `showFocusRing(id)`（聚焦且经键盘
到达）而非 `hasFocus(id)` 决定是否画描边。行为逻辑仍用 `hasFocus`，不受聚焦来源影响。

| 枚举 | 成员 |
|---|---|
| `Axis` | `Horizontal`、`Vertical` |
| `ButtonRole` | `Normal`、`Primary`、`Danger` |
| `TextAlign` | `Leading`、`Center`、`Trailing` |
| `MainAxisAlignment` | `Start`、`Center`、`End`、`SpaceBetween`、`SpaceAround`、`SpaceEvenly` |
| `CrossAxisAlignment` | `Start`、`Center`、`End`、`Stretch` |
| `Alignment` | 九宫格方向：`TopLeading` 至 `BottomTrailing` |
| `LengthUnit` | `Px`、`Vp`、`Fp` |

## 5. 主题

`Theme` 包含背景、面板、边框、主/次文字、强调、危险、输入区域、阴影与圆角。常用方法：

- `Theme.light()`、`Theme.dark()`。
- `panelSurface()`、`raisedSurface()`。
- `fieldSurface(active)`、`buttonSurface(role)`、`selectedSurface()`。

## 6. 布局与容器

| 类型 | 必要构造信息 | 链式 API/行为 |
|---|---|---|
| `VStack` | `body`（可选 `spacing: Length`、`padding: LengthInsets`） | `spacing`、`mainAxisAlignment`、`crossAxisAlignment`、`flexible`、`hug` |
| `HStack` | 同上 | 同上 |
| `ZStack` | `body` | `alignment`；后声明的子项绘制在上层 |
| `Grid` | `columns`、`body` | `spacing(all)`、`spacing(horizontal, vertical)`；列数小于 1 抛异常 |
| `FlowRow` | `body` | `spacing`；空间不足自动换行 |
| `ScrollView` | `id`、`body` | 垂直滚动；`scrollState` 接管偏移；溢出时为滚动条预留轨道，不遮挡内容；滑块可拖动、轨道可翻页 |
| `Panel` | `body`（可选 `padding: LengthInsets`） | `contentPadding`、`style`、`flexible`、`hug` |
| `Tooltip` | `text`、`body` | 悬停约 500ms 后在树上层绘制提示气泡；透明包裹，不改变布局/事件 |
| `Dropdown` | `id`、`items`、`selected` | 下拉选择：点击/Enter 打开，弹出列表浮于树上（下方放不下翻到上方）；选中/外点/Esc 关闭，上下键移动高亮。长列表在弹层内部滚动：滚轮、可拖动滑块、方向键揭示高亮，打开时选中行滚入视野 |
| `ContextMenu` | `items`、`body` | 为子控件附加右键菜单：指针处弹出，选中运行动作并关闭、外点/Esc 取消、方向键与悬停移动高亮；透明包裹，仅拦截子区域内右键 |
| `Modal` | `presented`、`body`（可选 `onDismiss`） | 模态对话框：`presented` 为真时暗化背景+居中面板，承载真实控件子树；拦截全部输入，`Tab` 在对话框内循环（焦点陷阱），每帧 Frame 转发进子树（`autofocus` 可用）；外点/Esc 关闭；对话框内可再开 `Dropdown`/`ComboBox`/`ContextMenu`（弹层经浮层栈压在面板之上，逐层关闭）；零尺寸、仅呈现时构建 `body`，置于根部 `ZStack` |
| `Flexible` | `body` | 兼容的权重包装容器，新代码可用 `.flex` |
| `Spacer` | 无 | 弹性空白 |

容器（`VStack`/`HStack`/`Panel`）默认 `flexible: true`，即沿父的主轴填充可用空间。`hug()` 是
`flexible(false)` 的语义化别名——沿父主轴按内容收缩（而非填充），用于卡片、工具栏等应恰好包住内容的
容器；跨轴仍按 `crossAxisAlignment` 拉伸。实践中收缩远多于填充，`hug()` 令这一常见意图一目了然。

`ContextMenu` 的条目为 `MenuItem(label: String, action: () -> Unit)`。`Dropdown` 弹出列表、
`ContextMenu` 菜单与 `Modal` 对话框都由**浮层栈**承载：控件在 `draw` 中经
`UiContext.setOverlay(Overlay(handleEvent:, render:, owner:))` 登记一层浮层（登记顺序即 z 序，
同 `owner` 重复登记原位替换），关闭时以 `removeOverlay(owner)` 精确撤下自己那一层；外壳在派发树
事件前先调用 `UiContext.dispatchOverlay`（自栈顶向下，某层消费即止）、在树绘制后调用
`drawActiveOverlay`（自栈底向上，绘制期间新登记的浮层同帧画在其上）、每帧开始以
`clearActiveOverlay` 清栈，`overlayCount()` 返回当前打开的浮层数。浮层因此可嵌套——对话框内的
下拉列表压在对话框之上。自定义控件可复用这套机制实现弹出层。

## 7. 基础控件

| 类型 | 必要构造信息 | 链式 API |
|---|---|---|
| `Label` | `text` | `muted()`、`muted(bool)`、`textAlign`、`foregroundColor`、`fontSize`、`maxLines(n)`、`wrap()` |
| `Button` | `title`、`onClick` | `id`、`role`、`style`、`fontSize` |
| `Icon` | `IconName` | `iconSize`、`foregroundColor` |
| `IconButton` | `IconName`、`onClick` | `id`、`label`、`role`、`style` |
| `Divider` | 无 | `axis`、`color` |

单行 `Label` 超宽时自动省略号截断；`maxLines(n)` 换行至 n 行（末行截断），`wrap()` 不限行数，
`maxLines` 参数必须大于 0。Button 与 IconButton 在鼠标释放时激活，支持取得焦点后的
Enter/Space，悬停与按压有主题化的视觉反馈。

## 8. 选择、导航和数值控件

交互控件的状态参数为 `Bindable<T>`（可传 `State`、`Binding`），展示控件为 `Observable<T>`。

| 类型 | 构造函数 | 补充 API/行为 |
|---|---|---|
| `Checkbox` | `Checkbox(label, Bindable<Bool>)` | `id`；鼠标释放或 Enter/Space 切换 |
| `Switch` | `Switch(label, Bindable<Bool>)` | `id`；二态开关 |
| `RadioButton` | `RadioButton(label, selected, value)` | `id`；多个实例共享同一 `Bindable<Int64>` |
| `Picker` | `Picker(id, items, selected)` | 点击前后区域或 Left/Right 循环选择；宽度按最长选项自适应（切换选项不抖动） |
| `Stepper` | `Stepper(id, Bindable<Int64>, lower!, upper!, step!)` | 范围/步长可经构造参或链式 `range(lower, upper)`、`step(value)` 设置（构造参对齐 Slider/ProgressBar）；宽度按数值内容自适应（一至两位数稳定） |
| `SegmentedControl` | `SegmentedControl(items, selected, id!: ?String = None)` | 分段单选；选中指示器弹簧滑动到新段；`Tab` 聚焦后 Left/Right 切换（端点钳制）；`id` 可选，缺省按构建序自动派生 |
| `TabView` | `TabView(labels, selected, id!: ?String = None) { pages }` | 页面按标签顺序声明；活动标签指示器弹簧滑动；页签条为焦点停靠点（先于页内控件），聚焦后 Left/Right 切换页签；`id` 可选 |
| `ListView` | `ListView(items, selected, scroll!: ?State<Float32> = None, id!: ?String = None)` | `scrollState`；点击选择、滚轮滚动，`Tab` 聚焦 + 方向键导航；选择变化即滚入可视区（含应用层改选），无外部滚动态时偏移按身份保留；滑块可拖动；`id` 可选，给定则身份稳定可寻址 |
| `Table` | `Table(id, columns, rows, selected)` / `Table.of(id, data, columns, selected)` | 多列数据表：固定表头、窗口化滚动；点击列头排序（再次反向、数值列按数值），行选择存原始行索引故排序后跟随，`Tab` + 方向键/Home/End 导航；悬停保持默认箭头光标 |
| `LazyColumn` | `LazyColumn(id, count, itemHeight) { i => 行 }` / `LazyColumn.of(id, data, itemHeight, key!) { item => 行 }` | 定高行、按索引或数据惰性构建的纵向列表：只物化视口附近的行，成本恒为一屏；数据形免去 `count` 与 `data[i]` 回查，`key` 令行局部状态随项走 |
| `LazyGrid` | `LazyGrid(id, data, columns, itemHeight, spacing!, columnSpacing!) { item => 单元格 }` | 数据驱动、按行窗口化的等宽网格；一行是一个 `Grid` 骑在 `LazyColumn` 上，单元格可为任意控件 |
| `ProgressBar` | `ProgressBar(Observable<Float32>)` | `range(lower, upper)` |
| `Slider` | `Slider(id, Bindable<Float32>, lower!, upper!, step!)` | 连续或离散：`step` 大于 0 时数值吸附到 `lower + k*step` 的刻度（默认 0 为连续）；范围与步长可经构造参或链式 `range(lower, upper)`、`step(value)` 设置（对齐 Stepper）；拖动和 Left/Right |

`Stepper.step` 的值必须大于 0，否则抛 `IllegalArgumentException`。数值控件会安全处理反向范围和
越界输入。

`Table` 的列为 `TableColumn(title, width, numeric!: Bool = false, cell!: ?(UiContext, Int64, String,
Rect) -> Unit = None)`，行为 `Array<Array<String>>`（按列索引的单元格）。`numeric` 列右对齐并按数值
排序（`88 < 100`），文本列左对齐按 UTF-8 字节序。排序为每帧稳定归并排序，始终反映最新单元格值；
超大数据集应在模型侧预排序、以无激活排序列的方式传入。`cell` 为可选的**自定义单元格绘制回调**
（进度条、色块、徽标）：参数依次为上下文、原始行索引、单元格字符串值与单元格矩形；表格先绘制行底
与选中高亮并把回调裁剪在单元格内，回调只负责内容。排序仍按字符串值与 `numeric` 规则进行——显示与
排序键解耦（“87%” 可画成负载条、仍按 87 排序）。回调仅绘制，不接收事件；行点击照常选中。

数据强类型时用 `Table.of(id, data: Array<T>, columns: Array<DataColumn<T>>, selected)`：
`DataColumn<T>(title, width, numeric!, cell!) { row => 单元格串 }` 以抽取器从行取值，免去手搭字符串矩阵，
列头与取值就近成对；内部映射为字符串矩阵后走同一 `Table`，排序/选择一致。抽取器逐帧运行，超大且持续
重绘的表仍宜用预建矩阵的原始形。

## 9. 文本

| 类型 | 构造函数 | 链式 API/行为 |
|---|---|---|
| `TextField` | `TextField(id, text, cursor!: ?State<Int64> = None, anchor!: ?State<Int64> = None, editable!: Bool = true)` | `autofocus`；单行 UTF-8 编辑；Shift 扩选、拖选、Ctrl+A/C/X/V；`undo`/`redo`（Ctrl+Z/Y）；只读（`editable: false`）忽略编辑、不参与 Tab 遍历，仍可选择/复制 |
| `TextArea` | `TextArea(id, text, scroll!: ?State<Float32> = None, cursor!: ?State<Int64> = None, anchor!: ?State<Int64> = None, editable!: Bool = true)` | `autofocus`；多行选区、Shift+↑↓ 跨行扩选、拖选、Ctrl+A/C/X/V；`undo`/`redo`（Ctrl+Z/Y）；只读区（`editable: false`）不参与 Tab 遍历 |
| `ComboBox` | `ComboBox(id, text: Bindable<String>, options)` | 可编辑下拉：内嵌 `TextField`（完整编辑）+ 建议列表浮层；键入过滤（无匹配显示“—”占位）、点击/回车填入，自由文本亦保留。长建议列表在弹层内部滚动：滚轮、可拖动滑块、方向键揭示高亮 |

外部状态（滚动、光标、锚点）均为可选命名参数；持有 `cursor!` 就应连同 `anchor!` 一并持有并
**成对改写**——只改光标会残留“幻影选区”，下一次键入会替换它覆盖的内容。

光标跟随：`TextField` 水平滑动文本窗口使光标始终可见（绘制、选区与命中测试共享同一偏移）；
`TextArea` 在键盘编辑、导航与撤销后把光标行滚入视口。撤销合并除 500ms 时间窗外，在光标跳转
（点击/方向键）处即时断组。

插入光标与字形行等高、闪烁周期约 1.06 秒；点击定位按真实文本测量落在最近字符边界；
超宽内容裁剪于控件表面内。`TextEditState(text, cursor=None, anchor=None)` 或 `TextEditState(value)` 提供：

- `normalizeCursor`、`moveTo`、`extendTo`。
- `insert`、`backspace`、`deleteForward`（均替换/删除当前选区）。
- `moveLeft`、`moveRight`、`moveToStart`、`moveToEnd`（折叠选区）。
- `extendLeft`、`extendRight`、`extendToStart`、`extendToEnd`（保持锚点扩选）。
- `moveToLineStart`、`moveToLineEnd`、`moveLineUp`、`moveLineDown`（折叠）。
- `extendToLineStart`、`extendToLineEnd`、`extendLineUp`、`extendLineDown`（按列跨行扩选）。
- 选区：`hasSelection`、`selectionStart`、`selectionEnd`、`selectedText`、`selectAll`、`deleteSelection`、`clearSelection`。
- `selectWordAt(position)`（双击选词，按字符类归并）、`selectLineAt(position)`（三击选行，含行尾换行）。

选区语义位于 `anchor`/`cursor` 之间，二者重合即无选区；不传 `anchor` 的控件（只读文本区）沿用原光标行为。

## 10. 媒体与事件包装器

- `CanvasWidget(onDraw).onEvent(handler)`：自定义绘制和事件区域。
- `ImageView(path).fit(ImageFit)`：`Stretch`、`Contain`、`Cover`；`preferredWidth`/`preferredHeight`
  为 `Length`。解码纹理由**按路径键控的共享缓存**持有（负缓存记住失败的加载），因此可像其他控件
  一样逐帧内联声明；`invalidateImage(path)` 使单个路径失效并在下帧重载（覆盖图片文件后调用），
  `clearImageCache()` 清空全部。仍实现 `Resource` 以兼容旧的提升 + `manage` 写法（`close` 仅
  停用该视图，纹理归缓存所有）。
- `EventHandler(onEvent) { ... }`：在子树前截获事件。
- `FrameHandler(onFrame) { ... }`：接收每帧 `FrameInfo`。

## 11. `DesktopApp`

```cangjie
DesktopApp(spec, theme: Theme.light(), frameDelay: UInt32(16), fontScale: 1.0, metadata: None, hints: [])
```

| 方法 | 说明 |
|---|---|
| `run(body)` | 启动逐帧构建、布局、事件和绘制循环 |
| `manage(resource)` | 托管资源，退出时逆序关闭 |
| `setMinimumSize(width, height)` | 以逻辑像素约束窗口最小尺寸 |
| `clearRememberedState()` | 清空局部状态存储 |
| `openFileDialog`、`saveFileDialog`、`openFolderDialog` | 创建异步文件对话框请求 |

`fontScale` 作用于全部 `fp` 尺寸；`WindowSpec.scale` 决定 `px` 与 `vp` 的换算。

底层重新导出类型与方法的完整定义见 [SDL API 参考](../sdl/docs/api-reference.md)。
