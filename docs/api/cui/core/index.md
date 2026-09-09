[cui](../../index.md) › cui.core

# cui.core

```cangjie
import cui.core.*
```

`cui.core` 定义 CUI 的基础协议：组件如何构建、布局、绘制和处理事件，状态如何驱动更新，以及主题、动画、无障碍和测试诊断如何接入。成品控件位于 `cui.controls`、`cui.text` 和 `cui.media`。

## 建议先读

| 目标 | 入口 |
|---|---|
| 编写界面 | [`Widget`](Widget.md)、[`VStack`](VStack.md)、[`HStack`](HStack.md)、[`Modifier`](Modifier.md) |
| 管理状态 | [`State`](State.md)、[`Bindable`](Bindable.md)、[`DerivedState`](DerivedState.md)、[`rememberState`](functions.md#rememberstate) |
| 处理事件 | [`EventListener`](EventListener.md)、[`EventOutcome`](EventOutcome.md)、[`UiContext`](UiContext.md) |
| 编写自定义组件 | [`Widget`](Widget.md)、[`emit`](functions.md#emit)、[`focusableControlIdentity`](functions.md#focusablecontrolidentity) |
| 管理大型应用 | [`ModelStore`](ModelStore.md)、[`Reducer`](Reducer.md)、[`ScopedStore`](ScopedStore.md) |
| 排查增量更新 | [`RetainedGraphDiagnostics`](RetainedGraphDiagnostics.md)、[`AutomaticScopeDiagnostics`](AutomaticScopeDiagnostics.md) |

## 组件与布局

| 类型 | 说明 |
|---|---|
| [`Widget`](Widget.md) | 所有组件实现的测量、布局、绘制和事件协议。 |
| [`Modifier`](Modifier.md) | 可组合、可复用的组件修饰器。 |
| [`UiContext`](UiContext.md) | 组件访问渲染、主题、输入、焦点、浮层和帧调度的上下文。 |
| [`UiAggregateException`](UiAggregateException.md) | 保留一次操作中所有原始异常及发生顺序。 |
| [`VStack`](VStack.md) / [`HStack`](HStack.md) | 纵向或横向排列子组件。 |
| [`ZStack`](ZStack.md) | 按声明顺序叠放子组件。 |
| [`Grid`](Grid.md) | 固定列数、等宽单元格的网格。 |
| [`FlowRow`](FlowRow.md) | 从左到右排列，空间不足时换行。 |
| [`Flexible`](Flexible.md) | 让内容按权重参与栈的剩余空间分配。 |
| [`Spacer`](Spacer.md) | 吸收栈中的剩余空间。 |
| [`Panel`](Panel.md) | 带主题背景和内边距的内容容器。 |
| [`Label`](Label.md) | 单行或多行文本。 |
| [`Button`](Button.md) | 文字按钮；媒体图标按钮位于 cui.media。 |
| [`Divider`](Divider.md) | 水平或垂直分隔线。 |
| [`ScrollView`](ScrollView.md) | 可滚动、会裁剪内容的垂直视口。 |
| [`ScrollBar`](ScrollBar.md) / [`HScrollBar`](HScrollBar.md) | 可供自定义滚动容器复用的滚动条控制器。 |
| [`LazyColumn`](LazyColumn.md) / [`LazyRow`](LazyRow.md) | 只创建视口附近项目的定尺寸列表。 |
| [`LazyList`](LazyList.md) | 支持可变行高的虚拟列表。 |
| [`LazyListExtents`](LazyListExtents.md) | 为可变行高列表维护高度与位置索引。 |
| [`LazyViewportController`](LazyViewportController.md) | 按索引或稳定键控制虚拟列表位置。 |
| [`LazyScrollAlignment`](LazyScrollAlignment.md) | 项目滚入视口时的对齐方式。 |
| [`Keyed`](Keyed.md) | 为动态子树提供稳定身份。 |
| [`Overlay`](Overlay.md) | 在整棵界面树上方显示交互内容。 |
| [`Portal`](Portal.md) | 把组件声明到浮层，不占当前位置的布局空间。 |
| [`Tooltip`](Tooltip.md) | 为组件添加悬停提示。 |
| [`Reveal`](Reveal.md) | 在隐藏与自然高度之间做展开、收起动画。 |

## 状态与应用数据流

| 类型 | 说明 |
|---|---|
| [`Observable`](Observable.md) | 可读取、可观察的值。 |
| [`Bindable`](Bindable.md) | 可读取、可写入、可观察的值。 |
| [`State`](State.md) | CUI 的基础可写状态。 |
| [`Binding`](Binding.md) | 指向另一可绑定值局部字段的双向绑定。 |
| [`DerivedState`](DerivedState.md) | 从一个或多个状态计算并缓存的只读值。 |
| [`StateObservation`](StateObservation.md) | 可关闭的状态观察句柄。 |
| [`StateStore`](StateStore.md) | 在声明式重建之间保留局部状态和值。 |
| [`StateMutationPolicy`](StateMutationPolicy.md) | 判断两次状态值在观察意义上是否相同。 |
| [`DiagnosedStateMutationPolicy`](DiagnosedStateMutationPolicy.md) | 为状态比较策略记录诊断数据。 |
| [`StateMutationPolicyDiagnostics`](StateMutationPolicyDiagnostics.md) | 状态比较次数、结果、失败和耗时快照。 |
| [`Lens`](Lens.md) | 从整体模型读写局部字段的双向投影。 |
| [`Prism`](Prism.md) | 从动作联合类型中提取或嵌入某一分支。 |
| [`FeaturePath`](FeaturePath.md) | 把模型投影与动作分支组合成特征边界。 |
| [`Reducer`](Reducer.md) | 根据动作纯计算下一模型。 |
| [`ModelStore`](ModelStore.md) | 保存模型并通过强类型动作更新它。 |
| [`ScopedStore`](ScopedStore.md) | 只向子功能暴露局部模型和局部动作。 |
| [`EffectReducer`](EffectReducer.md) | 同时返回下一模型和待执行效果描述。 |
| [`EffectStore`](EffectStore.md) | 提交模型后把效果批次交给应用处理。 |
| [`EffectBatch`](EffectBatch.md) | 保持顺序、可高效连接的效果集合。 |
| [`Transition`](Transition.md) | 一次归约产生的模型与效果批次。 |
| [`EffectCleanup`](EffectCleanup.md) | 把清理函数包装成可关闭资源。 |
| [`IdentifiedArray`](IdentifiedArray.md) | 按稳定 ID 索引并保持显示顺序的持久集合。 |
| [`IdentifiedAction`](IdentifiedAction.md) | 稳定 ID 与局部动作的组合。 |
| [`EntityTable`](EntityTable.md) | 按 ID 保存实体的持久映射。 |
| [`EntityUpdate`](EntityUpdate.md) | 对指定实体执行的一次纯更新。 |
| [`EntityTableStats`](EntityTableStats.md) | 实体表容量与哈希碰撞诊断。 |
| [`MissingFeaturePolicy`](MissingFeaturePolicy.md) | 局部状态缺失时选择报错或忽略动作。 |

## 事件、焦点与无障碍

| 类型 | 说明 |
|---|---|
| [`EventListener`](EventListener.md) | 在捕获、目标或冒泡阶段处理事件。 |
| [`EventHandler`](EventHandler.md) | 使用布尔返回值、先于子树处理事件的兼容接口。 |
| [`EventPhase`](EventPhase.md) | 捕获、目标和冒泡三个事件阶段。 |
| [`EventScope`](EventScope.md) | 监听命中子树的事件，或显式监听全局事件。 |
| [`EventOutcome`](EventOutcome.md) | 分别表示是否已处理、是否停止传播。 |
| [`PointerEventScope`](PointerEventScope.md) | 声明指针处理是否只发生在布局矩形内。 |
| [`CursorShape`](CursorShape.md) | 控件悬停时申请的指针形状。 |
| [`ImeComposition`](ImeComposition.md) | 输入法尚未提交的预编辑文本与选区。 |
| [`ImeCandidates`](ImeCandidates.md) | 输入法候选项、当前下标与排列方向。 |
| [`Semantics`](Semantics.md) | 平台无关的无障碍属性。 |
| [`SemanticsRole`](SemanticsRole.md) | 文本、按钮、输入框等无障碍角色。 |
| [`SemanticsAction`](SemanticsAction.md) | 激活、聚焦、增减和设值等无障碍动作。 |
| [`SemanticsNode`](SemanticsNode.md) | 已绑定稳定标识、边界和动作的无障碍节点。 |
| [`SemanticsSnapshot`](SemanticsSnapshot.md) | 已提交语义树的不可变快照。 |
| [`SemanticsChange`](SemanticsChange.md) | 语义树的一次新增、移除、更新或移动。 |
| [`AccessibilityUpdate`](AccessibilityUpdate.md) | 带版本号的一批无障碍树变更。 |
| [`AccessibilityAdapter`](AccessibilityAdapter.md) | 原生无障碍桥或外部检查工具实现的更新接口。 |

## 尺寸、样式与动画

| 类型 | 说明 |
|---|---|
| [`Length`](Length.md) / [`LengthUnit`](LengthUnit.md) | 带 `px`、`vp` 或 `fp` 单位的尺寸。 |
| [`LengthInsets`](LengthInsets.md) | 四边可以分别指定单位的间距。 |
| [`LengthUnits`](LengthUnits.md) | 为数值提供 `.px`、`.vp`、`.fp` 后缀。 |
| [`Axis`](Axis.md) | 水平或垂直方向。 |
| [`Alignment`](Alignment.md) | 二维对齐方式。 |
| [`MainAxisAlignment`](MainAxisAlignment.md) | 栈在主轴上的排列方式。 |
| [`CrossAxisAlignment`](CrossAxisAlignment.md) | 栈在交叉轴上的排列方式。 |
| [`TextAlign`](TextAlign.md) | 文本在可用宽度内的水平对齐方式。 |
| [`ButtonRole`](ButtonRole.md) | 普通、主要或危险按钮的语义角色。 |
| [`Theme`](Theme.md) | 控件共用的语义颜色和基础外观。 |
| [`Gradient`](Gradient.md) | 双色线性渐变。 |
| [`Corners`](Corners.md) | 四个角各自的圆角半径。 |
| [`Shadow`](Shadow.md) | 阴影偏移、模糊、扩散和颜色。 |
| [`PaintOutset`](PaintOutset.md) | 组件可能绘制到布局矩形外的距离。 |
| [`Spacing`](Spacing.md) / [`Radii`](Radii.md) / [`Motion`](Motion.md) | 内建间距、圆角和动效令牌。 |
| [`Easing`](Easing.md) | 动画进度曲线。 |
| [`Animator`](Animator.md) | 在固定时长内把数值平滑移动到目标。 |
| [`Spring`](Spring.md) | 使用弹簧和阻尼推进数值。 |
| [`Pulse`](Pulse.md) | 持续循环的时间线。 |
| [`FrameHandler`](FrameHandler.md) | 在每个实际渲染帧运行回调并请求续帧。 |
| [`FrameSchedule`](FrameSchedule.md) | 下一帧的立即请求或定时截止信息。 |
| [`FrameScheduler`](FrameScheduler.md) | 管理应用状态失效、事务和 UI 线程归属。 |

## 增量更新与诊断

| 类型 | 说明 |
|---|---|
| [`RetainedSubtree`](RetainedSubtree.md) | 显式保留子树的高级接口；普通界面通常无需使用。 |
| [`RetainedSubtreeStats`](RetainedSubtreeStats.md) | 显式保留边界的命中、失效与缓存统计。 |
| [`RetainedGraphDiagnostics`](RetainedGraphDiagnostics.md) | 最近一次已提交增量执行图的诊断快照。 |
| [`RetainedScopeDiagnostics`](RetainedScopeDiagnostics.md) | 一个增量作用域的身份、失效原因和分阶段统计。 |
| [`AutomaticScopeDiagnostics`](AutomaticScopeDiagnostics.md) | 自动作用域的依赖、命中、绘制命令预算和退避信息。 |
| [`ParagraphCacheStats`](ParagraphCacheStats.md) | 文本段落布局缓存的容量、命中与淘汰统计。 |

## 包级函数

### 状态、身份与生命周期

| 函数 | 说明 |
|---|---|
| [`remember`](functions.md#remember) | 在稳定声明位置保留一个值。 |
| [`rememberState`](functions.md#rememberstate) | 在稳定声明位置保留一个 `State`。 |
| [`derive`](functions.md#derive) | 从一个或多个可观察值创建派生状态。 |
| [`deriveStates`](functions.md#derivestates) | 从同类型 `State` 数组创建派生状态。 |
| [`stateMutationPolicy`](functions.md#statemutationpolicy) | 用比较函数创建状态等价策略。 |
| [`structuralEqualityPolicy`](functions.md#structuralequalitypolicy) | 使用 `==` 跳过相等写入。 |
| [`neverEqualPolicy`](functions.md#neverequalpolicy) | 把每次赋值都视为变化。 |
| [`diagnoseStateMutationPolicy`](functions.md#diagnosestatemutationpolicy) | 为状态等价策略增加诊断。 |
| [`currentStateGeneration`](functions.md#currentstategeneration) | 返回进程级状态写入计数，仅用于兼容诊断。 |
| [`mountEffect`](functions.md#mounteffect) | 在声明身份挂载一次可清理资源。 |
| [`lifecycleEffect`](functions.md#lifecycleeffect) | 在版本变化时替换可清理资源。 |

### 构建、布局与自定义组件

| 函数 | 说明 |
|---|---|
| [`emit`](functions.md#emit) | 把已有组件加入当前构建块。 |
| [`ForEach`](functions.md#foreach) | 按稳定业务键声明重复子树。 |
| [`ForEachIndexed`](functions.md#foreachindexed) | 按位置声明不会重排的重复子树。 |
| [`LazyGrid`](functions.md#lazygrid) | 用虚拟列表组成固定列数的网格。 |
| [`focusableControlIdentity`](functions.md#focusablecontrolidentity) | 为自定义控件分配身份并加入 Tab 顺序。 |
| [`claimHoverIfInside`](functions.md#claimhoverifinside) | 在指针位于控件内时申请悬停与光标。 |
| [`drawFocusRing`](functions.md#drawfocusring) | 绘制与内建控件一致的键盘焦点环。 |
| [`subscribeFrame`](functions.md#subscribeframe) | 为自定义组件登记逐帧回调。 |
| [`broadcastEvent`](functions.md#broadcastevent) | 向组件广播不可消费的宿主事件。 |

### Reducer 组合

| 函数 | 说明 |
|---|---|
| [`optionalReducer`](functions.md#optionalreducer) | 把局部 reducer 应用于可选状态。 |
| [`identifiedReducer`](functions.md#identifiedreducer) | 按稳定 ID 把局部 reducer 应用于有序集合。 |
| [`identifiedBatchReducer`](functions.md#identifiedbatchreducer) | 在一个事务中按顺序处理多项集合动作。 |
| [`entityReducer`](functions.md#entityreducer) | 按 ID 把局部 reducer 应用于实体表。 |
| [`entityBatchReducer`](functions.md#entitybatchreducer) | 在一个事务中按顺序处理多项实体动作。 |

## 外部类型扩展

- [`Int64` 的 `LengthUnits` 实现](extensions.md#int64-的-lengthunits-实现)
- [`Float64` 的 `LengthUnits` 实现](extensions.md#float64-的-lengthunits-实现)

## 字体继承

- [`TextStyle`](TextStyle.md)：子树的字体族、字号与样式默认值。
