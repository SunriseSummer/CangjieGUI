[cui](../../index.md) › cui.core

# cui.core

```cangjie
import cui.core.*
```

UI 核心包：提供 [`Widget`](Widget.md) 接口和链式修饰器、栈/网格/流式/层叠/滚动/按需创建的布局容器、按钮与文本等基础控件、状态与双向绑定、动画、主题、每帧上下文 [`UiContext`](UiContext.md)，以及浮层和焦点处理。`cui.controls`、`cui.text`、`cui.media` 的控件都建立在本包之上。

## 类型

**类**

| 类型 | 说明 |
|---|---|
| [`AccessibilityUpdate`](AccessibilityUpdate.md) | 稳定布局提交后送给无障碍 adapter 的 revisioned 原子 patch。 |
| [`Animator`](Animator.md) | 按固定时长与 [`Easing`](Easing.md) 曲线把数值从当前位置补间到目标的动画器——CSS transition 与 SwiftUI/Compose `.animation(...)` 背后的模型。 |
| [`AutomaticScopeDiagnostics`](AutomaticScopeDiagnostics.md) | 自动作用域的依赖/脏来源、body/layout/paint 命中、命令预算与退避诊断。 |
| [`Binding`](Binding.md) | 指向另一个可绑定值中某个字段的双向绑定，用 Bindable.project 创建。 |
| [`Button`](Button.md) | 带按主题显示的背景与边框与居中标题的按压按钮，在按钮内部按下并松开时触发 `onClick`。 |
| [`DiagnosedStateMutationPolicy`](DiagnosedStateMutationPolicy.md) | 显式记录等价策略抑制收益、失败与比较耗时的包装器。 |
| [`DerivedState`](DerivedState.md) | 由一个或多个源计算出的缓存只读状态，可选按结果等价类过滤下游失效。 |
| [`Divider`](Divider.md) | 分隔内容的 1 逻辑像素发丝线，走向由 `axis` 指定、长度由父栈拉伸铺满。 |
| [`EffectCleanup`](EffectCleanup.md) | 把 cleanup 闭包适配为可重试、幂等的 effect Resource。 |
| [`EffectReducer`](EffectReducer.md) | 纯计算下一模型与有序领域效果描述的 reducer。 |
| [`EffectStore`](EffectStore.md) | 提交模型后显式交付惰性效果批次的单向 Store。 |
| [`EventHandler`](EventHandler.md) | 在子树收到事件之前先把每个事件交给回调的透明包装组件，回调返回 `true` 即消费该事件。 |
| [`EventListener`](EventListener.md) | 以捕获、目标或冒泡阶段观察命中子树，并返回可组合的处理/停止效果。 |
| [`Flexible`](Flexible.md) | 把内容纳入所在栈空间分配的包装组件：按权重分得剩余空间，而非按内容收缩。 |
| [`FlowRow`](FlowRow.md) | 把子组件从左到右排布、放不下时自动换到内容高度新行的流式容器。 |
| [`FrameSchedule`](FrameSchedule.md) | 组件发出的立即或定时下一帧请求快照，供宿主精确等待事件和截止时间。 |
| [`FrameScheduler`](FrameScheduler.md) | 每应用独立的状态失效代数、事务合并与 UI 线程归属协调器。 |
| [`FrameHandler`](FrameHandler.md) | 每渲染帧调用一次回调并自动请求续帧的透明包装组件，是时间驱动动画与帧内轮询的挂载点。 |
| [`Grid`](Grid.md) | 把子组件排进固定列数、等宽单元格的网格容器，行高取本行最高的单元格。 |
| [`HScrollBar`](HScrollBar.md) | [`ScrollBar`](ScrollBar.md) 的水平镜像：为沿 x 轴滚动的表面提供同样的滑块拖拽与轨道分页控制器。 |
| [`HStack`](HStack.md) | 沿水平主轴排布子组件的弹性栈容器：以尾随 lambda 声明子组件，间距、主轴/交叉轴对齐与弹性参与可链式配置。 |
| [`Icon`](Icon.md) | 以方形边长绘制的非交互矢量图标，默认 18 vp、取主题文字色。 |
| [`IconButton`](IconButton.md) | 以图标为面、可选带文字标签的按钮，激活方式与 [`Button`](Button.md) 完全相同。 |
| [`Keyed`](Keyed.md) | 给子树赋予稳定声明式标识的透明包装组件：其下的局部状态键与控件交互标识都以该键为命名空间。 |
| [`Label`](Label.md) | 单行或多行文本组件：默认单行、溢出以省略号截断，字体样式经链式构建器就地配置。 |
| [`Lens`](Lens.md) | 从整体值到局部值的可组合双向投影，可由 Bindable.project 转成控件 Binding。 |
| [`ModelStore`](ModelStore.md) | 以强类型 Action 和纯 Reducer 驱动单一应用模型。 |
| [`LazyColumn`](LazyColumn.md) | 只构建视口附近行的定行高垂直滚动列表，构建、布局与绘制均为 O(可见) 而非 O(行数)。 |
| [`LazyList`](LazyList.md) | 可由高度模型或可见行自测量驱动的变高惰性垂直列表。 |
| [`LazyListExtents`](LazyListExtents.md) | Fenwick 可变行高模型，单行更新与前缀定位为 O(log N)。 |
| [`LazyRow`](LazyRow.md) | 只构建视口附近列的定列宽水平滚动条带，是 [`LazyColumn`](LazyColumn.md) 的水平对应物。 |
| [`LazyScrollAlignment`](LazyScrollAlignment.md) | 按稳定 key 定位时的起边、居中、末边或最近边对齐。 |
| [`LazyViewportController`](LazyViewportController.md) | 持有惰性视口偏移并按当前索引或稳定 key 定位条目。 |
| [`Overlay`](Overlay.md) | 浮在整棵组件树之上的交互浮层：下拉弹出面板、菜单或对话框。 |
| [`Panel`](Panel.md) | 带主题表面与内容内边距的卡片式容器，是划分界面区块的基础构件。 |
| [`PaintOutset`](PaintOutset.md) | 布局矩形之外可组合的保守绘制溢出。 |
| [`Portal`](Portal.md) | 把真实 Widget 子树声明到应用浮层平面而不占声明位置的版面。 |
| [`Pulse`](Pulse.md) | 永动的循环时间线——骨架屏微光、呼吸状态点、加载脉冲。 |
| [`Reducer`](Reducer.md) | 把 Action 纯解释为模型变化，并支持顺序组合与 Lens pullback。 |
| [`Reveal`](Reveal.md) | 在零与内容自然高度之间缓动过渡的展开/收起容器，切换 `shown` 即让内容滑入滑出。 |
| [`RetainedGraphDiagnostics`](RetainedGraphDiagnostics.md) | 已提交 retained 执行图、effect 和失败 cleanup 的确定性诊断快照。 |
| [`RetainedSubtree`](RetainedSubtree.md) | 显式 retained 高级边界；普通 UI 已由框架自动建立组合作用域。 |
| [`ScrollBar`](ScrollBar.md) | 供滚动容器内部复用的垂直滚动条拖拽控制器，把命中滚动条的按下与移动转发给它，即得一致的滑块拖拽与轨道分页行为。 |
| [`ScrollView`](ScrollView.md) | 裁剪显示、支持滚轮与拖动滚动条的垂直滚动视口，滚动位置按稳定标识跨帧保留。 |
| [`ScopedStore`](ScopedStore.md) | 隐藏根模型与根 Action、仍共享单一根事实的特征局部 Store。 |
| [`Semantics`](Semantics.md) | 平台无关的无障碍标签、角色、值与状态。 |
| [`SemanticsSnapshot`](SemanticsSnapshot.md) | 不可变、按 id 索引的已提交语义树。 |
| [`SemanticsNode`](SemanticsNode.md) | 带稳定 id、布局边界和可执行动作的已解析无障碍节点。 |
| [`Spacer`](Spacer.md) | 测量为零并吸收所在栈剩余空间的空白弹性组件，把兄弟组件推向两端。 |
| [`Spacing`](Spacing.md) | 4 像素栅格上的间距尺度：七档命名间隔，以虚拟像素的 Length 值表达。 |
| [`Radii`](Radii.md) | 圆角半径尺度，虚拟像素：小档给标签与输入框、中档给卡片、大档给醒目表面，pill 收成全圆头。 |
| [`Motion`](Motion.md) | 动效令牌：三档标准动画时长（毫秒）与四条角色化缓动曲线，与 Animator、Spring 搭配使用。 |
| [`Modifier`](Modifier.md) | 满足恒等与结合律、可组合复用的 Widget 变换。 |
| [`Spring`](Spring.md) | 跨帧把数值弹性逼近目标的弹簧-阻尼器。 |
| [`State`](State.md) | 可写的单一数据源可观察状态：事务外立即通知，事务内合并为前值到最终值的一次通知。 |
| [`StateObservation`](StateObservation.md) | 由 Observable.observe 返回的可取消的观察句柄：持有它就持续收到回调，close() 后不再收到。 |
| [`StateStore`](StateStore.md) | 跨声明式重建保留显式键控局部状态的容器：一次完整构建未访问的条目会被移除，与视图卸载语义一致。 |
| [`Tooltip`](Tooltip.md) | 为任意控件包上悬停提示：指针在子组件上驻留 500 毫秒后，提示文本被绘制在整棵组件树之上；其余时刻是完全透明的包装。 |
| [`UiContext`](UiContext.md) | 每帧传给全部组件回调的服务枢纽：渲染器与主题、指针与帧状态，以及焦点、悬停、按下、拖拽、提示与浮层等共享交互协议。 |
| [`VStack`](VStack.md) | 沿垂直主轴排布子组件的弹性栈容器：以尾随 lambda 声明子组件，间距、主轴/交叉轴对齐与弹性参与可链式配置。 |
| [`ZStack`](ZStack.md) | 把子组件按声明顺序自底向顶叠放、并在同一框架内对齐的层叠容器。 |

**结构体**

| 类型 | 说明 |
|---|---|
| [`Corners`](Corners.md) | 背景四角的独立圆角半径，即 CSS 四值 `border-radius` 模型，按左上、右上、右下、左下排列。 |
| [`EffectBatch`](EffectBatch.md) | 可 O(1) 拼接、按序解释的不可变领域效果批次。 |
| [`EntityTable`](EntityTable.md) | 正规化模型使用的 ID 键控分层持久实体表。 |
| [`EntityTableStats`](EntityTableStats.md) | 实体表容量、占用与哈希碰撞诊断。 |
| [`EntityUpdate`](EntityUpdate.md) | 一个实体 ID 与纯自变换组成的有序批量补丁。 |
| [`FeaturePath`](FeaturePath.md) | 把状态 Lens 与 Action Prism 绑定成可组合特征边界。 |
| [`Gradient`](Gradient.md) | 圆角背景用的双色线性渐变填充，默认自上而下、`vertical` 为 false 时自左向右。 |
| [`IdentifiedAction`](IdentifiedAction.md) | 一个稳定元素 ID 与其局部 Action 的值对。 |
| [`IdentifiedArray`](IdentifiedArray.md) | 以分块持久顺序存储和唯一 ID 索引支持重复子特征。 |
| [`Length`](Length.md) | 带显式单位的一维尺寸，写作 `100.px`、`24.vp` 或 `15.fp`。 |
| [`LengthInsets`](LengthInsets.md) | 四边各自携带单位的间距，供 padding 类 API 使用，布局时解析为逻辑像素的 `Insets`。 |
| [`ParagraphCacheStats`](ParagraphCacheStats.md) | 跨即时树重建的段落布局 LRU 命中、容量与淘汰诊断。 |
| [`Prism`](Prism.md) | 可组合地提取和嵌入一个 Action/和类型分支。 |
| [`RetainedScopeDiagnostics`](RetainedScopeDiagnostics.md) | 一个 retained scope 的身份、直接所有权、dirty 原因和分相统计。 |
| [`Shadow`](Shadow.md) | 可配置的组件阴影，包含水平/垂直偏移、模糊、扩散和颜色，作用类似 CSS `box-shadow`。 |
| [`Theme`](Theme.md) | 组件共用的外观设置：按用途提供背景、面板、输入框、文字、强调色和危险色，并保存统一的圆角与描边宽度（逻辑像素）。 |
| [`Transition`](Transition.md) | 一次纯归约得到的下一模型与惰性效果批次。 |
| [`RetainedSubtreeStats`](RetainedSubtreeStats.md) | 保留边界累计的分相依赖/命中、自动失效、命令数和估算字节。 |
| [`StateMutationPolicyDiagnostics`](StateMutationPolicyDiagnostics.md) | 状态等价策略比较、结果、失败与耗时的不可变诊断快照。 |

**接口**

| 类型 | 说明 |
|---|---|
| [`AccessibilityAdapter`](AccessibilityAdapter.md) | 原生无障碍桥或语义工具实现的增量 push 接口。 |
| [`Bindable`](Bindable.md) | 可读、可写并能通知变化的值。 |
| [`LengthUnits`](LengthUnits.md) | 为数值字面量提供 `.px`/`.vp`/`.fp` 长度后缀的接口。 |
| [`Observable`](Observable.md) | 可读、可观察值的抽象：读取当前值、暴露修订号、订阅变更，并可 map 出派生状态。 |
| [`StateMutationPolicy`](StateMutationPolicy.md) | 定义 State 变化或派生结果的观察等价关系。 |
| [`Widget`](Widget.md) | 所有组件共同实现的立即模式契约：每帧参与测量、布局、绘制与事件处理，并自带尺寸、内边距、表面、阴影、弹性、可见性等整套链式修饰器。 |

**枚举**

| 类型 | 说明 |
|---|---|
| [`Alignment`](Alignment.md) | 九宫格式的二维对齐，供 [`ZStack`](ZStack.md) 这类把子组件放进同一框架的容器定位不拉伸的子组件。 |
| [`Axis`](Axis.md) | 布局方向轴：水平或垂直。 |
| [`ButtonRole`](ButtonRole.md) | 按钮的语义角色：常规、主要或危险，决定主题为按钮生成的表面配色。 |
| [`CrossAxisAlignment`](CrossAxisAlignment.md) | 栈在交叉轴上放置子组件的策略：靠端、居中或拉伸填满。 |
| [`CursorShape`](CursorShape.md) | 控件在指针悬停期间申请的语义指针形状，由宿主映射为各平台的原生光标。 |
| [`Easing`](Easing.md) | 把 `[0, 1]` 内的动画进度映射为缓动后进度的时序曲线。 |
| [`EventOutcome`](EventOutcome.md) | 事件的继续、已处理、停止传播或完全消费结果；组合构成四元素 join-semilattice。 |
| [`EventPhase`](EventPhase.md) | 命中路径上的捕获、目标和冒泡阶段。 |
| [`EventScope`](EventScope.md) | 监听器只命中本子树或观察全局路由。 |
| [`PointerEventScope`](PointerEventScope.md) | 子树的指针处理是兼容无界，还是可证明局限于父容器分配的布局矩形。 |
| [`LengthUnit`](LengthUnit.md) | 长度值的单位：物理像素 `Px`、虚拟像素 `Vp` 或随用户字体缩放的字体像素 `Fp`。 |
| [`MainAxisAlignment`](MainAxisAlignment.md) | 栈沿主轴分配剩余空间的策略：靠端、居中或三种等分间隔。 |
| [`MissingFeaturePolicy`](MissingFeaturePolicy.md) | 子 Action 没有对应可选/keyed 状态时拒绝或显式忽略。 |
| [`SemanticsAction`](SemanticsAction.md) | 无障碍适配器可请求的激活、聚焦、增减或设值动作。 |
| [`SemanticsChange`](SemanticsChange.md) | 语义节点的新增、移除、更新或顺序移动。 |
| [`SemanticsRole`](SemanticsRole.md) | 控件映射到原生无障碍 API 前使用的平台无关角色。 |
| [`TextAlign`](TextAlign.md) | 文本在所分配框架内的水平对齐方式：行首、居中或行尾。 |

**外部类型扩展**

| 类型 | 说明 |
|---|---|
| [`Int64 (extension)`](extensions.md#int64-的-lengthunits-实现) | 整数字面量的 `.px`/`.vp`/`.fp` 长度后缀。 |
| [`Float64 (extension)`](extensions.md#float64-的-lengthunits-实现) | 浮点字面量的 `.px`/`.vp`/`.fp` 长度后缀。 |

## 函数

| 函数 | 说明 |
|---|---|
| [`derive`](functions.md#derive) | 返回从一到多个源计算出的只读派生状态。 |
| [`deriveStates`](functions.md#derivestates) | 从 `State` 数组构造静态专用的只读派生状态。 |
| [`identifiedReducer`](functions.md#identifiedreducer) | 把 reducer 提升到按稳定 ID 路由的持久集合。 |
| [`identifiedBatchReducer`](functions.md#identifiedbatchreducer) | 把有序 child Action 批次归约为至多一个持久集合版本。 |
| [`entityReducer`](functions.md#entityreducer) | 把 reducer 提升到按 ID 路由的正规化实体表。 |
| [`entityBatchReducer`](functions.md#entitybatchreducer) | 把有序实体 Action 批次归约为至多一个持久表版本。 |
| [`optionalReducer`](functions.md#optionalreducer) | 把 reducer 提升到带显式缺失策略的 Option 状态。 |
| [`ForEach`](functions.md#foreach) | 为每个数据项声明一棵键控子树。 |
| [`ForEachIndexed`](functions.md#foreachindexed) | 以位置为标识、为每个数据项声明一棵键控子树。 |
| [`LazyGrid`](functions.md#lazygrid) | 垂直滚动的虚拟化网格：`data` 排成 `columns` 等宽列并按行开窗，海量均匀单元格（照片墙、卡片网格）只花一屏的成本。 |
| [`currentStateGeneration`](functions.md#currentstategeneration) | 兼容诊断用的进程级原子状态写代数。 |
| [`lifecycleEffect`](functions.md#lifecycleeffect) | 按显式 revision 事务替换和清理 Resource effect。 |
| [`mountEffect`](functions.md#mounteffect) | 在当前声明身份成功提交后挂载一次 Resource。 |
| [`diagnoseStateMutationPolicy`](functions.md#diagnosestatemutationpolicy) | 显式包装状态等价策略并记录抑制收益、失败与耗时。 |
| [`neverEqualPolicy`](functions.md#neverequalpolicy) | 返回接受每次 State 赋值的兼容策略。 |
| [`rememberState`](functions.md#rememberstate) | 返回由活动 [`DesktopApp`](../desktop/DesktopApp.md) 构建保留的局部状态。 |
| [`remember`](functions.md#remember) | 在活动构建中保留任意稳定值或对象。 |
| [`stateMutationPolicy`](functions.md#statemutationpolicy) | 从观察等价闭包构造 State 变更策略。 |
| [`structuralEqualityPolicy`](functions.md#structuralequalitypolicy) | 返回以 `==` 抑制 State 相等写入的策略。 |
| [`subscribeFrame`](functions.md#subscribeframe) | 为自定义 Widget 显式登记逐帧回调，避免合成 Frame 全树广播。 |
| [`broadcastEvent`](functions.md#broadcastevent) | 派发不可消费的广播阶段并有意丢弃组件返回值；普通输入不得使用。 |
| [`drawFocusRing`](functions.md#drawfocusring) | 绘制键盘焦点环：贴着控件的强调色圆角描边，画在边界外 2 像素处，读作独立于控件自身边缘的光晕。 |
| [`emit`](functions.md#emit) | 把新构造的组件注册进最内层打开的构建块。 |
| [`focusableControlIdentity`](functions.md#focusablecontrolidentity) | 一步完成按构建顺序分配标识并注册为焦点项。 |
| [`claimHoverIfInside`](functions.md#claimhoverifinside) | 当 MouseMove 落在 `frame` 内时，为 `id` 申请悬停状态和指定的指针形状。 |
