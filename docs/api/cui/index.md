[cui](../index.md) › cui

# cui

```cangjie
import cui.*
```

统一导入入口：本包自身不定义类型或函数，而是重新导出 sdl 模块和全部 CUI 子包。sdl 提供几何、颜色、渲染、图像、窗口、输入与桌面系统能力；CUI 子包提供组件、布局、控件、文本、媒体和桌面应用。应用只需 `import cui.*` 即可使用这些 API。

## 再导出

以下符号定义于本模块各子包，在此再导出；详情见各定义包的文档页。

**来自 [`cui.core`](core/index.md)**

| 符号 | 说明 |
|---|---|
| [`Alignment`](core/Alignment.md) | 九宫格式的二维对齐，供 `ZStack` 这类把子组件放进同一框架的容器定位不拉伸的子组件。 |
| [`Animator`](core/Animator.md) | 按固定时长与 `Easing` 曲线把数值从当前位置补间到目标的动画器——CSS transition 与 SwiftUI/Compose `.animation(...)` 背后的模型。 |
| [`Axis`](core/Axis.md) | 布局方向轴：水平或垂直。 |
| [`Bindable`](core/Bindable.md) | 可读、可写并能通知变化的值。 |
| [`Binding`](core/Binding.md) | 指向另一个可绑定值中某个字段的双向绑定，用 Bindable.project 创建。 |
| [`Button`](core/Button.md) | 带按主题显示的背景与边框与居中标题的按压按钮，在按钮内部按下并松开时触发 `onClick`。 |
| [`ButtonRole`](core/ButtonRole.md) | 按钮的语义角色：常规、主要或危险，决定主题为按钮生成的表面配色。 |
| [`broadcastEvent`](core/functions.md#broadcastevent) | 派发不可消费的广播阶段并有意丢弃组件返回值；普通输入不得使用。 |
| [`claimHoverIfInside`](core/functions.md#claimhoverifinside) | 当 MouseMove 落在 `frame` 内时，为 `id` 申请悬停状态和指定的指针形状。 |
| [`Corners`](core/Corners.md) | 背景四角的独立圆角半径，即 CSS 四值 `border-radius` 模型，按左上、右上、右下、左下排列。 |
| [`CrossAxisAlignment`](core/CrossAxisAlignment.md) | 栈在交叉轴上放置子组件的策略：靠端、居中或拉伸填满。 |
| [`CursorShape`](core/CursorShape.md) | 控件在指针悬停期间申请的语义指针形状，由宿主映射为各平台的原生光标。 |
| [`derive`](core/functions.md#derive) | 返回从一到多个源计算出的只读派生状态。 |
| [`DerivedState`](core/DerivedState.md) | 由一个或多个源计算出的只读可观察状态，用 derive 或 Observable.map 创建。 |
| [`Divider`](core/Divider.md) | 分隔内容的 1 逻辑像素发丝线，走向由 `axis` 指定、长度由父栈拉伸铺满。 |
| [`drawFocusRing`](core/functions.md#drawfocusring) | 绘制键盘焦点环：贴着控件的强调色圆角描边，画在边界外 2 像素处，读作独立于控件自身边缘的光晕。 |
| [`Easing`](core/Easing.md) | 把 `[0, 1]` 内的动画进度映射为缓动后进度的时序曲线。 |
| [`EffectCleanup`](core/EffectCleanup.md) | 把 cleanup 闭包适配为可重试、幂等的 effect Resource。 |
| [`emit`](core/functions.md#emit) | 把新构造的组件注册进最内层打开的构建块。 |
| [`EventHandler`](core/EventHandler.md) | 在子树收到事件之前先把每个事件交给回调的透明包装组件，回调返回 `true` 即消费该事件。 |
| [`Flexible`](core/Flexible.md) | 把内容纳入所在栈空间分配的包装组件：按权重分得剩余空间，而非按内容收缩。 |
| [`FlowRow`](core/FlowRow.md) | 把子组件从左到右排布、放不下时自动换到内容高度新行的流式容器。 |
| [`focusableControlIdentity`](core/functions.md#focusablecontrolidentity) | 一步完成按构建顺序分配标识并注册为焦点项。 |
| [`ForEach`](core/functions.md#foreach) | 为每个数据项声明一棵键控子树。 |
| [`ForEachIndexed`](core/functions.md#foreachindexed) | 以位置为标识、为每个数据项声明一棵键控子树。 |
| [`FrameHandler`](core/FrameHandler.md) | 每渲染帧调用一次回调并自动请求续帧的透明包装组件，是时间驱动动画与帧内轮询的挂载点。 |
| [`Gradient`](core/Gradient.md) | 圆角背景用的双色线性渐变填充，默认自上而下、`vertical` 为 false 时自左向右。 |
| [`Grid`](core/Grid.md) | 把子组件排进固定列数、等宽单元格的网格容器，行高取本行最高的单元格。 |
| [`HScrollBar`](core/HScrollBar.md) | `ScrollBar` 的水平镜像：为沿 x 轴滚动的表面提供同样的滑块拖拽与轨道分页控制器。 |
| [`HStack`](core/HStack.md) | 沿水平主轴排布子组件的弹性栈容器：以尾随 lambda 声明子组件，间距、主轴/交叉轴对齐与弹性参与可链式配置。 |
| [`Icon`](core/Icon.md) | 以方形边长绘制的非交互矢量图标，默认 18 vp、取主题文字色。 |
| [`IconButton`](core/IconButton.md) | 以图标为面、可选带文字标签的按钮，激活方式与 `Button` 完全相同。 |
| [`Keyed`](core/Keyed.md) | 给子树赋予稳定声明式标识的透明包装组件：其下的局部状态键与控件交互标识都以该键为命名空间。 |
| [`Label`](core/Label.md) | 单行或多行文本组件：默认单行、溢出以省略号截断，字体样式经链式构建器就地配置。 |
| [`LazyColumn`](core/LazyColumn.md) | 只构建视口附近行的定行高垂直滚动列表，构建、布局与绘制均为 O(可见) 而非 O(行数)。 |
| [`LazyGrid`](core/functions.md#lazygrid) | 垂直滚动的虚拟化网格：`data` 排成 `columns` 等宽列并按行开窗，海量均匀单元格（照片墙、卡片网格）只花一屏的成本。 |
| [`LazyList`](core/LazyList.md) | 行高由 `heightOf` 逐行给定的惰性垂直滚动列表，是 `LazyColumn` 的变高对应物。 |
| [`LazyListExtents`](core/LazyListExtents.md) | Fenwick 可变行高模型，支持 O(log N) 单行更新。 |
| [`LazyRow`](core/LazyRow.md) | 只构建视口附近列的定列宽水平滚动条带，是 `LazyColumn` 的水平对应物。 |
| [`LazyScrollAlignment`](core/LazyScrollAlignment.md) | 惰性视口按 key 定位的对齐方式。 |
| [`LazyViewportController`](core/LazyViewportController.md) | 按稳定 key 控制惰性视口滚动。 |
| [`Length`](core/Length.md) | 带显式单位的一维尺寸，写作 `100.px`、`24.vp` 或 `15.fp`。 |
| [`LengthInsets`](core/LengthInsets.md) | 四边各自携带单位的间距，供 padding 类 API 使用，布局时解析为逻辑像素的 `Insets`。 |
| [`LengthUnit`](core/LengthUnit.md) | 长度值的单位：物理像素 `Px`、虚拟像素 `Vp` 或随用户字体缩放的字体像素 `Fp`。 |
| [`LengthUnits`](core/LengthUnits.md) | 为数值字面量提供 `.px`/`.vp`/`.fp` 长度后缀的接口。 |
| [`MainAxisAlignment`](core/MainAxisAlignment.md) | 栈沿主轴分配剩余空间的策略：靠端、居中或三种等分间隔。 |
| [`Motion`](core/Motion.md) | 动效令牌：三档标准动画时长（毫秒）与四条角色化缓动曲线，与 Animator、Spring 搭配使用。 |
| [`mountEffect`](core/functions.md#mounteffect) | 在当前声明身份成功提交后挂载一次 Resource。 |
| [`Observable`](core/Observable.md) | 可读、可观察值的抽象：读取当前值、暴露修订号、订阅变更，并可 map 出派生状态。 |
| [`Overlay`](core/Overlay.md) | 浮在整棵组件树之上的交互浮层：下拉弹出面板、菜单或对话框。 |
| [`Panel`](core/Panel.md) | 带主题表面与内容内边距的卡片式容器，是划分界面区块的基础构件。 |
| [`ParagraphCacheStats`](core/ParagraphCacheStats.md) | 跨即时树重建的段落布局 LRU 命中、容量与淘汰诊断。 |
| [`Pulse`](core/Pulse.md) | 永动的循环时间线——骨架屏微光、呼吸状态点、加载脉冲。 |
| [`Radii`](core/Radii.md) | 圆角半径尺度，虚拟像素：小档给标签与输入框、中档给卡片、大档给醒目表面，pill 收成全圆头。 |
| [`lifecycleEffect`](core/functions.md#lifecycleeffect) | 按显式 revision 事务替换和清理 Resource effect。 |
| [`rememberState`](core/functions.md#rememberstate) | 返回由活动 `DesktopApp` 构建保留的局部状态。 |
| [`subscribeFrame`](core/functions.md#subscribeframe) | 为自定义 Widget 显式登记逐帧回调。 |
| [`Reveal`](core/Reveal.md) | 在零与内容自然高度之间缓动过渡的展开/收起容器，切换 `shown` 即让内容滑入滑出。 |
| [`RetainedGraphDiagnostics`](core/RetainedGraphDiagnostics.md) | 已提交 retained 执行图、effect 和失败 cleanup 的确定性诊断快照。 |
| [`RetainedScopeDiagnostics`](core/RetainedScopeDiagnostics.md) | 一个 retained scope 的身份、直接所有权、dirty 原因和分相统计。 |
| [`RetainedSubtree`](core/RetainedSubtree.md) | 自动跟踪 build/measure/layout/缓存 paint 的 State 读取，复用稳定子树和可选透明绘制命令。 |
| [`RetainedSubtreeStats`](core/RetainedSubtreeStats.md) | 保留边界累计的分相依赖/命中、自动失效、命令数和估算字节。 |
| [`ScrollBar`](core/ScrollBar.md) | 供滚动容器内部复用的垂直滚动条拖拽控制器，把命中滚动条的按下与移动转发给它，即得一致的滑块拖拽与轨道分页行为。 |
| [`ScrollView`](core/ScrollView.md) | 裁剪显示、支持滚轮与拖动滚动条的垂直滚动视口，滚动位置按稳定标识跨帧保留。 |
| [`Shadow`](core/Shadow.md) | 可配置的组件阴影，包含水平/垂直偏移、模糊、扩散和颜色，作用类似 CSS `box-shadow`。 |
| [`Spacer`](core/Spacer.md) | 测量为零并吸收所在栈剩余空间的空白弹性组件，把兄弟组件推向两端。 |
| [`Spacing`](core/Spacing.md) | 4 像素栅格上的间距尺度：七档命名间隔，以虚拟像素的 Length 值表达。 |
| [`Spring`](core/Spring.md) | 跨帧把数值弹性逼近目标的弹簧-阻尼器。 |
| [`State`](core/State.md) | 可写的单一数据源可观察状态：对 value 赋值会推进修订号，并在调用线程上同步通知全部观察者。 |
| [`StateObservation`](core/StateObservation.md) | 由 Observable.observe 返回的可取消的观察句柄：持有它就持续收到回调，close() 后不再收到。 |
| [`StateStore`](core/StateStore.md) | 跨声明式重建保留显式键控局部状态的容器：一次完整构建未访问的条目会被移除，与视图卸载语义一致。 |
| [`TextAlign`](core/TextAlign.md) | 文本在所分配框架内的水平对齐方式：行首、居中或行尾。 |
| [`Theme`](core/Theme.md) | 组件共用的外观设置：按用途提供背景、面板、输入框、文字、强调色和危险色，并保存统一的圆角与描边宽度（逻辑像素）。 |
| [`Tooltip`](core/Tooltip.md) | 为任意控件包上悬停提示：指针在子组件上驻留 500 毫秒后，提示文本被绘制在整棵组件树之上；其余时刻是完全透明的包装。 |
| [`UiContext`](core/UiContext.md) | 每帧传给全部组件回调的服务枢纽：渲染器与主题、指针与帧状态，以及焦点、悬停、按下、拖拽、提示与浮层等共享交互协议。 |
| [`VStack`](core/VStack.md) | 沿垂直主轴排布子组件的弹性栈容器：以尾随 lambda 声明子组件，间距、主轴/交叉轴对齐与弹性参与可链式配置。 |
| [`Widget`](core/Widget.md) | 所有组件共同实现的立即模式契约：每帧参与测量、布局、绘制与事件处理，并自带尺寸、内边距、表面、阴影、弹性、可见性等整套链式修饰器。 |
| [`ZStack`](core/ZStack.md) | 把子组件按声明顺序自底向顶叠放、并在同一框架内对齐的层叠容器。 |

**来自 [`cui.controls`](controls/index.md)**

| 符号 | 说明 |
|---|---|
| [`Accordion`](controls/Accordion.md) | 可折叠分区的竖向堆叠：每个分区一条可点击的标题与一个展开时才构建的正文。 |
| [`AccordionSection`](controls/AccordionSection.md) | `Accordion` 折叠面板的一个分区描述：标题文本加正文的界面构建函数。 |
| [`Badge`](controls/Badge.md) | 紧凑的状态标签：圆角胶囊底上画同色系文本，纯展示、不响应交互。 |
| [`BadgeKind`](controls/BadgeKind.md) | `Badge` 徽标的语义配色：中性、主题强调色，或信息/成功/警告/危险四种状态色。 |
| [`Breadcrumb`](controls/Breadcrumb.md) | 面包屑路径：以箭头分隔的一行层级段（如 首页 › 文档 › 项目），末段为当前位置、前段可点击返回上级路径。 |
| [`CalendarDate`](controls/CalendarDate.md) | 一个日历日——年、月（1–12）、日（1–31），不含时刻与时区。 |
| [`Checkbox`](controls/Checkbox.md) | 带文本标签的勾选框，双向绑定一个 `Bindable<Bool>`。 |
| [`Chip`](controls/Chip.md) | 可选中的过滤标签：绑定 `Bindable<Bool>` 的圆角胶囊，点击（或聚焦后 Space/Enter）即切换选中。 |
| [`ContextMenu`](controls/ContextMenu.md) | 给任意子内容包上右键上下文菜单的透明包装组件。 |
| [`DataColumn`](controls/DataColumn.md) | Table.of 的类型化列定义：表头、列宽、数值标记与从行数据 T 抽取单元格文本的 value 抽取器。 |
| [`DatePicker`](controls/DatePicker.md) | 日期字段：点击弹出月历浮层，双向绑定一个 `Bindable<CalendarDate>`。 |
| [`Dropdown`](controls/Dropdown.md) | 下拉选择框：闭合时显示当前项，展开时把选项列表浮到组件树之上，双向绑定选中下标 `Bindable<Int64>`。 |
| [`ListView`](controls/ListView.md) | 单选字符串列表：可滚动的行列表，点击或键盘移动选择，双向绑定选中下标 `Bindable<Int64>`。 |
| [`Menu`](controls/Menu.md) | `MenuBar` 菜单栏的一个顶级菜单描述：标题加其下拉包含的菜单项。 |
| [`MenuBar`](controls/MenuBar.md) | 应用菜单栏：一行水平排列的菜单标题，点击标题即在其正下方弹出下拉菜单，菜单打开时指针掠过其他标题即切换过去。 |
| [`MenuItem`](controls/MenuItem.md) | 菜单中的一个条目：标签、选中时执行的动作、可选的右对齐快捷键提示与可用标记。 |
| [`Modal`](controls/Modal.md) | 模态对话框：`presented` 为真时把 `body` 子树布局在一块对视口居中的面板里，经浮层浮于整棵界面树之上并压暗背景，事件一律不再落到背景树。 |
| [`Pagination`](controls/Pagination.md) | 长分页内容（搜索结果、表格、商品目录）的页码导航条：上一页/下一页箭头夹着一段窗口化页码——恒含首末页与当前页两侧的邻页，其间空缺折叠为省略号。 |
| [`Picker`](controls/Picker.md) | 在一组有限字符串项之间前后切换的紧凑选择器：两端各一枚 ‹ › 按钮、中间显示当前项，切换在两端回绕。 |
| [`ProgressBar`](controls/ProgressBar.md) | 把可观察数值显示为水平填充条的只读进度指示，中央叠加百分比标签。 |
| [`ProgressRing`](controls/ProgressRing.md) | 环形进度指示：淡色轨道整环上，自 12 点方向顺时针扫出与 `value`（0…1 比例，越界截断）相当的前景弧，中心可叠加取整百分比。 |
| [`RadioButton`](controls/RadioButton.md) | 整数值互斥选择组中的一个选项：同组各项共享一个 `Bindable<Int64>`，激活任一项即把共享值设为该项的 `value`。 |
| [`Rating`](controls/Rating.md) | 以一排实心/空心圆点输入 0…`count` 整数评分的控件：实心圆点表示当前评分，其余为空心，默认五点。 |
| [`ReorderableList`](controls/ReorderableList.md) | 行高固定、可拖拽重排的垂直列表：每行左侧带握点手柄，按住手柄拖动即抬起该行随指针移动、其余行让位露出落点，松手调用 onMove(from, to) 提交——列表只报告移动，数据始终由调用方持有并自行重排。 |
| [`RichSpan`](controls/RichSpan.md) | RichText 中的一段带样式行内片段：一段文本或一枚行内图标，可逐段配色、加粗、斜体、加装饰线、换字体、调字号、垫高亮底或挂点击动作。 |
| [`RichText`](controls/RichText.md) | 行内多样式文本组件：把一串 RichSpan（配色、加粗、变字号的文本段与行内图标）排在同一行内，超出可用宽度自动换行到任意多行。 |
| [`SegmentedControl`](controls/SegmentedControl.md) | 把互斥选项排成一行等宽段、由滑动指示块标记当前选中的单选控件。 |
| [`Slider`](controls/Slider.md) | 拖动圆钮在闭区间内取值的滑杆，双向绑定 `Bindable<Float32>`：按下即跳到指针处并开始拖拽，`step` 为正时值吸附到 `lower + k·step` 的离散刻度，为 0（默认）则连续取值。 |
| [`SplitView`](controls/SplitView.md) | 用一根可拖动分隔条把空间分给两个窗格的容器，让用户在侧栏与文档、列表与详情之间自行调配空间。 |
| [`StepIndicator`](controls/StepIndicator.md) | 多步流程（结账、引导、向导）的横向步骤进度条：编号节点由连接线串起，`current` 之前的步骤实心打勾、当前步高亮、其后置灰。 |
| [`Stepper`](controls/Stepper.md) | 带减/增按钮与键盘支持的整数值编辑器：两端 −/+ 各步进一次，值始终夹在闭区间内。 |
| [`Switch`](controls/Switch.md) | 绑定布尔状态的桌面开关：滑轨带圆钮，点击（或聚焦后 Enter/Space）取反 `checked`，圆钮以弹簧动画滑向新位置。 |
| [`Table`](controls/Table.md) | 多列、可排序的数据表格：固定表头、窗口化滚动的正文与单行选择。 |
| [`TableColumn`](controls/TableColumn.md) | Table 数据表格的一列定义：表头标题、固定像素宽度与是否数值列。 |
| [`TabView`](controls/TabView.md) | 顶部页签条加整页内容区的页签容器，同一时刻只有选中页参与布局、绘制与事件。 |
| [`TimeOfDay`](controls/TimeOfDay.md) | 表示一天内的时刻，只有小时（0–23）和分钟（0–59），不含日期与时区；`TimePicker` 用它保存选中时间。 |
| [`TimePicker`](controls/TimePicker.md) | 带弹出选择面板的时间字段：闭合时显示绑定的 `TimeOfDay`，点击（或聚焦后按 Enter/Space/Down）经交互浮层弹出面板，面板把 24 小时网格与逐分钟编辑器配成一对。 |
| [`Toaster`](controls/Toaster.md) | 瞬态 Toast 通知的调度器：保存当前仍在显示的通知及各自的剩余时间，从任意处调用 `show` 即可加入一条消息。 |
| [`ToastKind`](controls/ToastKind.md) | Toast 通知的类别，决定通知卡片左侧强调条的颜色。 |
| [`ToastLayer`](controls/ToastLayer.md) | 把一个 `Toaster` 的通知渲染到视口右下角并驱动其时钟的浮层组件。 |
| [`TreeNode`](controls/TreeNode.md) | `TreeView` 的一个节点：稳定的 `id`、显示用的 `label`、可选的前置 `icon` 与子节点数组，纯数据、构造后不可变。 |
| [`TreeView`](controls/TreeView.md) | 带展开/折叠的层级列表——文件浏览器、大纲、导航树。 |

**来自 [`cui.text`](text/index.md)**

| 符号 | 说明 |
|---|---|
| [`ComboBox`](text/ComboBox.md) | 可输入的下拉组合框：在内嵌单行编辑框上浮出建议列表，输入即过滤；绑定文本就是控件的值，自由输入即使不匹配任何选项也被保留。 |
| [`TextArea`](text/TextArea.md) | 多行文本编辑控件：把编辑写回绑定的 `Bindable<String>`，带垂直滚动与右缘滚动条，行间导航按字节列对齐。 |
| [`TextEditState`](text/TextEditState.md) | 有光标的文本框与文本域共享的文本编辑模型：文本绑定、光标与选择锚点，以及在这三者上实现的全部编辑操作（插入/删除、按字符/行/整体移动与扩展选择、词与行选择）。 |
| [`TextField`](text/TextField.md) | 单行文本编辑控件：把输入写回绑定的 `Bindable<String>`，按桌面惯例提供点选拖选、双击选词、Ctrl 快捷键、分组撤销与光标水平跟随。 |

**来自 [`cui.media`](media/index.md)**

| 符号 | 说明 |
|---|---|
| [`CanvasWidget`](media/CanvasWidget.md) | 自由绘制表面：弹性填满分得的空间、画主题输入底色、裁剪到框，然后把原始 `Renderer` 与框矩形交给 `onDraw`——坐标是绝对的，绘制方从矩形偏移、不从零点起。 |
| [`clearImageCache`](media/functions.md#clearimagecache) | 清空图像缓存并关闭每个缓存纹理；图像在下一次绘制时重载。 |
| [`ImageFit`](media/ImageFit.md) | 图像像素装进分配框的方式，供 `ImageView` 使用：拉伸填满、等比包含或等比覆盖。 |
| [`ImageView`](media/ImageView.md) | 显示从文件加载的图像。 |
| [`invalidateImage`](media/functions.md#invalidateimage) | 丢弃 `path` 的缓存纹理（并关闭它）；下一次绘制从磁盘重载。 |

**来自 [`cui.desktop`](desktop/index.md)**

| 符号 | 说明 |
|---|---|
| [`DesktopApp`](desktop/DesktopApp.md) | 桌面应用对象：拥有 SDL 窗口并运行按需帧循环；分相 State 依赖与 retained scope 可跳过未变构建、布局和绘制命令。 |

**来自 [`cui.testing`](testing/index.md)**

| 符号 | 说明 |
|---|---|
| [`RetainedTestMode`](testing/RetainedTestMode.md) | 测试宿主的增量或强制全量 retained 执行模式。 |
| [`WidgetTestHost`](testing/WidgetTestHost.md) | 按桌面帧事务运行构建、布局、指针/焦点事件、一致性重建与绘制的确定性无窗口宿主。 |
| [`TestFrameResult`](testing/TestFrameResult.md) | 一帧产生的稳定组件树、指标与下一帧计划。 |
| [`TestFrameMetrics`](testing/TestFrameMetrics.md) | 构建/布局/事件/绘制耗时、稳定化、文本和浮层探针。 |

## 再导出（外部模块 sdl）

以下符号定义于 **sdl 模块**（本文档范围之外），由伞包再导出以便应用单一导入。每个分组标题都链接到同版本 SDL API 的包索引；在这里按符号确认可直接导入的名称，再从对应包索引进入类型页查看精确声明和成员。本节不计入 CUI 手册的覆盖率。

**来自 [`sdl`](https://github.com/SunriseSummer/CangjieSDL/blob/main/docs/api/sdl/index.md)**

| 符号 | 说明 |
|---|---|
| `clampF32` | 把值限制在闭区间 [`low`, `high`]。 |
| `Color` | 8 位通道的 RGBA 颜色。 |
| `SdlException` | 本模块统一抛出的异常类型：SDL 调用失败、参数非法或资源已关闭时携带描述信息抛出。 |
| `drawIcon` | 在给定矩形内以圆头粗描边绘制一枚内置矢量图标。 |
| `EventKeyModifiers` | 随键盘事件复制的修饰键快照，延迟派发仍保持事件发生时语义。 |
| `Fonts` | 进程级注册表，把应用字体名映射到字体文件路径，类似 CSS 的 `@font-face` 表。 |
| `FontSizes` | 渲染器与应用共用的标准字号常量集合（点值）。 |
| `FontStyle` | 叠加在基础 UI 字体上的文本样式：字重、倾斜与两种线条修饰。 |
| `FrameInfo` | 以毫秒计的帧计时信息：`elapsedMs` 为 SDL 初始化以来的总时长，`deltaMs` 为距上一帧的间隔。 |
| `IconName` | 内置矢量图标的名称，交给 `drawIcon` 在 24 单位网格上以圆头粗描边绘制。 |
| `ImageFileFormat` | `Surface` 能读写的图像文件格式。 |
| `imageFormatFromPath` | 按扩展名推断图像文件格式：`.png` / `.PNG` 为 PNG，其余一律为 BMP。 |
| `Insets` | 逻辑像素下的四边间距——内边距、外边距、留白。 |
| `Key` | 解码后的键盘按键：字母/数字优先采用布局相关逻辑 keycode，导航/功能键按物理 scancode 回退。 |
| `MouseButton` | 解码后的鼠标按键；左/中/右之外的按键以 `RawCode` 携带 SDL 的按键码到达。 |
| `Pen` | 一次描边的描述：线条/轮廓的宽度与颜色。 |
| `Point` | 逻辑像素坐标系中的一个位置——布局、事件与绘制共用的坐标空间。 |
| `Rect` | 逻辑像素下的轴对齐矩形——原点 `x`/`y` 加宽高 `w`/`h`，用于布局框、命中测试与裁剪。 |
| `RenderCommandBuffer` | Renderer 录制的不可变透明绘制命令，可校验资源/epoch 后按原 z 序重放。 |
| `RenderCommandBufferStats` | 命令缓冲的命令、clip、资源、估算内存与重放次数诊断。 |
| `RenderPass` | 异常安全、幂等关闭的场景资源，确保恢复 render target、scale 与 clip。 |
| `Renderer` | 窗口的二维绘制入口：绘制图形、文字和图片，并设置绘制区域与裁剪范围。 |
| `sdlRevision` | 返回 SDL 构建的修订串；SDL 未提供时为空串。 |
| `sdlVersion` | 返回链接到的 SDL 版本号（SDL_GetVersion 的数值编码）。 |
| `SdlWindow` | 与自己的渲染器成对创建、成对关闭的 SDL 窗口。 |
| `SdlEventPump` | 多窗口进程级单一事件消费者，按事件 window id 使用目标窗口尺度并路由。 |
| `Size` | 逻辑像素下的宽高尺寸，用于窗口尺寸查询与布局测量的返回值。 |
| `Surface` | CPU 侧的 RGBA 像素缓冲，包装 SDL_Surface：可新建、从 BMP/PNG 文件加载、逐像素写入并存回 BMP 文件。 |
| `SurfaceStyle` | 一块圆角面板的外观描述：填充色、边框色与宽度、圆角半径、阴影色与垂直偏移。 |
| `TextFitResult` | 文本前缀适配的逻辑宽度与 UTF-8 字节长度。 |
| `TextHitResult` | shaping cluster 命中的 UTF-8 插入边界与几何快照。 |
| `TextMeasureSession` | 为同一字符串复用 UTF-8 缓冲与字体的范围/前缀测量资源。 |
| `Texture` | GPU 侧图像资源，由渲染器创建（`loadTexture` / `textureFromSurface`），经 `Renderer.texture` / `textureRotated` / `texturedStrip` 绘制。 |
| `TextureBlendMode` | 纹理绘制时与目标像素的混合方式，对应 SDL 的 SDL_BLENDMODE_*。 |
| `TextureFlip` | 旋转绘制纹理时的镜像方式，作为 `TextureRenderOptions` 的一项传入 `Renderer.textureRotated`。 |
| `TextureRenderOptions` | `Renderer.textureRotated` 的可选项集合：源区域裁剪、旋转中心与镜像方式。 |
| `UiEvent` | 解码后的 SDL 输入事件，按到达顺序交给应用处理。 |
| `UiEventMetadata` | SDL 事件的时间戳、窗口 id、物理/逻辑键和事件时修饰键快照。 |
| `UiEventRecord` | 一个 UiEvent 及其稳定事件时元数据。 |
| `WindowAspectRatio` | 窗口宽高比约束的上下界，由 `SdlWindow.aspectRatio` 返回。 |
| `WindowBorderSize` | 窗口装饰（标题栏与边框）在四个方向占用的像素数，由 `SdlWindow.borderSize` 返回。 |
| `WindowFlags` | 窗口状态标志位快照：把 SDL 的 64 位标志掩码展开为逐项布尔字段，同时保留原始掩码。 |
| `WindowFlash` | 任务栏/窗口闪烁请求的方式，传给 `SdlWindow.flash`。 |
| `WindowDisplayMetrics` | 内容缩放、像素密度、总渲染尺度与 SDL 显示缩放的动态快照。 |
| `WindowPosition` | 窗口左上角在屏幕坐标系中的位置，由 `SdlWindow.position` 返回。 |
| `WindowProgressState` | 原生任务栏进度指示的状态（Windows 任务栏按钮的进度条），经 `SdlWindow.setProgressState` 设置。 |
| `WindowSpec` | 创建窗口时的一次性选项：标题、逻辑尺寸、DPI 与缩放行为、垂直同步和渲染器的超采样倍数。 |

**来自 [`sdl.dialogs`](https://github.com/SunriseSummer/CangjieSDL/blob/main/docs/api/sdl/dialogs/index.md)**

| 符号 | 说明 |
|---|---|
| `FileDialogFilter` | 文件对话框的一条类型过滤器：显示名加分号分隔的扩展名模式（SDL 语法，如 `"png;jpg"`，`"*"` 匹配全部）。 |
| `FileDialogOptions` | 发起文件对话框时的选项：类型过滤器、初始目录与是否允许多选。 |
| `FileDialogRequest` | 一次进行中的文件对话框请求的句柄。 |
| `FileDialogResult` | 一次文件对话框请求的状态：进行中、被取消、已选中或失败。 |
| `FileDialogs` | 用于打开系统的“打开文件”“保存文件”和“选择文件夹”窗口。 |
| `MessageBoxButton` | 消息框中的一个按钮：标签、返回给调用方的编号，以及是否绑定回车/Esc 快捷键。 |
| `MessageBoxButtonOrder` | 消息框按钮的排列方向。 |
| `MessageBoxColor` | 消息框配色中的一项 RGB 颜色（无 alpha——原生消息框不支持透明）。 |
| `MessageBoxColorScheme` | 消息框的整套配色：背景、文字、按钮边框、按钮底色与选中按钮。 |
| `MessageBoxKind` | 消息框的严重级别，决定原生对话框的图标样式。 |
| `MessageBoxOptions` | 自定义消息框的完整描述：标题、正文、级别、按钮列表、按钮方向与可选配色。 |
| `showMessageBox` | 按 `MessageBoxOptions` 弹出自定义按钮的原生消息框，返回用户点击的按钮编号。 |
| `showSimpleMessageBox` | 弹出只有一个"确定"按钮的原生消息框，用户关闭后返回。 |

**来自 [`sdl.displays`](https://github.com/SunriseSummer/CangjieSDL/blob/main/docs/api/sdl/displays/index.md)**

| 符号 | 说明 |
|---|---|
| `allDisplayInfos` | 枚举全部显示器并逐台查询聚合信息。 |
| `closestFullscreenDisplayMode` | 在指定显示器上查找与请求最接近的全屏显示模式；没有可用模式时为 `None`。 |
| `DisplayGeometry` | 显示器的几何信息：完整边界、去除任务栏等系统区域后的可用边界，以及系统建议的内容缩放。 |
| `displayIds` | 枚举当前连接的全部显示器编号。 |
| `DisplayInfo` | 一台显示器的聚合信息：编号、名称、几何、朝向与显示模式。 |
| `displayInfo` | 返回指定编号显示器的聚合信息。 |
| `displayInfoForPoint` | 返回包含指定桌面坐标点的显示器信息。 |
| `displayInfoForRect` | 返回与指定桌面坐标矩形重叠最多的显示器信息。 |
| `DisplayMode` | 一种显示模式：分辨率、像素密度与刷新率。 |
| `DisplayModes` | 显示器的桌面显示模式与当前显示模式；SDL 无法提供时对应项为 `None`。 |
| `DisplayOrientation` | 显示器的朝向。 |
| `DisplayOrientations` | 显示器的自然朝向与当前朝向的组合。 |
| `fullscreenDisplayModes` | 枚举指定显示器支持的全屏显示模式。 |
| `FullscreenModeRequest` | 查找最接近的全屏显示模式时的期望参数：目标分辨率、刷新率与是否考虑高像素密度模式。 |
| `primaryDisplayInfo` | 返回主显示器的聚合信息。 |

**来自 [`sdl.input`](https://github.com/SunriseSummer/CangjieSDL/blob/main/docs/api/sdl/input/index.md)**

| 符号 | 说明 |
|---|---|
| `Clipboard` | SDL3 剪贴板的主线程访问入口：普通文本、主选择文本（X11 的选中即复制），以及带 MIME 类型的二进制数据。 |
| `ClipboardData` | 二进制剪贴板载荷与向其他桌面应用报出的 MIME 类型的组合，供 `Clipboard.setData` 批量提交。 |
| `Cursor` | 一个原生鼠标光标对象，加上光标显隐的静态控制。 |
| `Keyboard` | 键盘的轮询式查询入口，当前提供修饰键状态。 |
| `KeyModifiers` | 某一时刻的修饰键状态：把 SDL 修饰键掩码展开为逐项布尔字段，左右同键合并（左 Shift 或右 Shift 都算 `shift`），另有跨平台的 `command` 便捷位（Ctrl 或 GUI 键任一按下）。 |
| `Mouse` | 鼠标的轮询式查询与捕获控制。 |
| `MouseState` | 某一时刻的鼠标快照：指针位置（已按窗口缩放折算为逻辑像素）、左中右三键的按下状态与原始按键掩码。 |
| `SystemCursor` | 操作系统内置的光标形状，交给 `Cursor.system` 创建对应的原生光标。 |

**来自 [`sdl.system`](https://github.com/SunriseSummer/CangjieSDL/blob/main/docs/api/sdl/system/index.md)**

| 符号 | 说明 |
|---|---|
| `ApplicationMetadata` | 应用元数据的写入与查询入口。 |
| `ApplicationPaths` | 应用相关目录的查询入口：可执行文件所在目录、当前目录、按组织/应用名生成的应用偏好（配置）目录，以及标准用户目录。 |
| `AppMetadata` | 应用元数据的一揽子描述：名称、版本、标识符、开发者、版权、主页与类别，全部可选。 |
| `AppMetadataProperty` | 可单独读写的应用元数据属性名；`CustomMetadataProperty` 携带任意 SDL 属性名。 |
| `AppMetadataType` | 应用类别元数据的取值：普通应用、游戏、媒体播放器，或自定义字符串。 |
| `ClockFormat` | 系统区域偏好的时钟显示格式（12 小时制或 24 小时制）；SDL 报告未识别的编码时以 `UnknownClockFormat` 携带原始值。 |
| `CpuInfo` | CPU 与内存能力快照：核心数、缓存行、内存与页大小，以及各 SIMD 指令集的可用性。 |
| `cpuInfo` | 查询 CPU 与内存能力快照：核心数、缓存行、内存、页大小与各 SIMD 指令集可用性。 |
| `DateFormat` | 系统区域偏好的日期字段顺序；SDL 报告未识别的编码时以 `UnknownDateFormat` 携带原始值。 |
| `DateTimeLocalePreferences` | 系统区域的日期时间显示偏好：日期字段顺序与时钟显示格式（12 小时制或 24 小时制）。 |
| `DateTimeParts` | 拆解后的日历时间：年月日、时分秒、纳秒、星期与 UTC 偏移。 |
| `FileSystem` | SDL 文件系统操作的入口：建目录、删除、改名、复制、查询与通配枚举。 |
| `FileSystemEntryType` | 文件系统条目的种类，出现在 `PathInfo.entryType` 中。 |
| `HintPriority` | 设置 SDL hint 时的优先级；高优先级覆盖低优先级已写入的值。 |
| `openUrl` | 请求操作系统用默认处理程序打开 URL（`https://` 开浏览器，`file://` 开文件管理器等）。 |
| `PathInfo` | 一个路径的元信息：条目种类、字节大小与创建/修改/访问三组时间戳（SDL 时间，纳秒）。 |
| `PerformanceClock` | 单调高精度计时：毫秒/纳秒计时、性能计数器与高精度延时。 |
| `platformName` | 返回运行平台的名称（如 `"Windows"`、`"Linux"`、`"macOS"`）；SDL 未返回时为 `"Unknown"`。 |
| `PowerInfo` | 电源信息快照：供电状态、剩余秒数与剩余百分比；系统无法给出的项为 `None`。 |
| `powerInfo` | 查询电源信息：供电状态、剩余秒数与剩余百分比（不可知的项为 `None`）。 |
| `PowerState` | 设备的供电状态，出现在 `PowerInfo.state` 中。 |
| `SdlHint` | 常用 SDL hint 的名称；`CustomHint` 携带任意 SDL hint 名。 |
| `SdlHints` | SDL hint 的读写入口。 |
| `SdlHintSetting` | 一条完整的 hint 设置：hint 名、值与优先级，供 `SdlHints.apply` 批量应用。 |
| `Time` | 系统实时钟与日历换算：读取当前时间（1970-01-01 UTC 起算的纳秒），在纳秒时间戳与 `DateTimeParts` 之间互转，查询每月天数、一年中的第几天和星期，以及与 Windows FILETIME 互转。 |
| `UserFolder` | 操作系统的标准用户目录，交给 `ApplicationPaths.userFolder` 解析为具体路径。 |
| `Weekday` | 星期几，周日起算，由 `Time.dayOfWeek` 与 `DateTimeParts.dayOfWeek` 使用。 |
| `WindowsFileTime` | Windows FILETIME 的高低 32 位组合（1601-01-01 起算的 100 纳秒滴答），与 SDL 时间互转时使用。 |

## 子包

| 包 | 说明 |
|---|---|
| [`cui.core`](core/index.md) | UI 核心：组件与修饰器、布局容器、基础控件、状态、动画、主题、每帧上下文、浮层和焦点。 |
| [`cui.controls`](controls/index.md) | 成品控件库：选择与数值输入、下拉与菜单、导航、数据展示、模态、Toast、折叠面板、分栏与可重排列表。 |
| [`cui.text`](text/index.md) | 文本编辑控件：单行 TextField、多行 TextArea、带建议的 ComboBox 与共享编辑模型 TextEditState。 |
| [`cui.media`](media/index.md) | 图像与自绘：文件图像视图 ImageView（进程级纹理缓存）与自由绘制表面 CanvasWidget。 |
| [`cui.desktop`](desktop/index.md) | 桌面应用对象：DesktopApp 拥有窗口与渲染循环，驱动构建-布局-绘制-事件分发。 |
