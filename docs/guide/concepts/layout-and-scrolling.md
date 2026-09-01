[CUI 指南](../index.md) › 布局与滚动

# 布局约束、滚动与虚拟化

## 先用一句话说明

父容器把可用空间分配给子控件，滚动容器保存观看位置，虚拟化容器进一步只构建当前视口附近的数据项。

这三个问题容易混淆：排列关系决定谁在上、下、左、右；滚动解决内容超过视口；虚拟化解决项目很多时的构建成本。一个长列表可能同时需要排列、滚动和虚拟化，但它们不是同一个开关。

## 为什么重要

在固定窗口里看起来正常的界面，缩小后可能溢出，放大后可能只挤在角落。把所有控件塞进 `VStack` 再加固定宽高，只是碰巧适合某个尺寸。理解约束后，你能用 `Flexible`、`Spacer` 和容器对齐表达关系，而不是为每台设备调整像素。

滚动也不是“任何内容多就包一层”。`ScrollView` 适合一个普通子树超出视口；上千行数据若全部先构建，再滚动，内存和布局成本仍随总量增长。`LazyColumn`/`LazyRow`/`LazyList` 等虚拟容器根据视口构建附近项目。稳定业务 key 仍是必要信息；变高列表可由 `LazyList.measured` 自动学习可见行高度，不必在业务模型里复制布局状态。

## 工作模型

测量阶段，父容器给子控件约束，子控件报告希望占用的尺寸；布局阶段，父容器给每个子控件确定位置。`VStack` 累积高度，`HStack` 累积宽度，`Grid` 按列/行分配，`SplitView` 在两个区域间保留可调比例。伸缩权重表达剩余空间如何分配。

长度使用逻辑单位 `vp`，字体使用 `fp`。它们帮助界面适应显示缩放，但不会自动解决信息架构；一行放不下的五个业务区块仍应重组，而不是只缩小字体。

`ScrollView` 持有滚动偏移并裁剪绘制；普通子树仍会被构建。固定高列表可用 `LazyColumn`，横向项目可用 `LazyRow`，变高消息列表优先用 `LazyList.measured`；已有缓存高度或外部测高管线时再用 `LazyList.of`/`LazyListExtents`。网格画廊使用 `LazyGrid`。自测量的估计值只决定未知区域的初始几何，行进入预取区后由真实测量替换，并以稳定 key 修正锚点。

Lazy 列表进一步区分连续几何与离散拓扑：滚动偏移在已物化区间内变化时只重跑 layout/draw，不重新执行行声明；视口加预取首次越过区间边界，才在同一帧稳定化事务中物化下一组条目。应用无需选择优化开关，但变高 `heightOf` 若没有可观察数据源，就应提供 `revision`；否则框架为兼容任意闭包变化而保守重建。

## 选择与取舍

- **VStack/HStack**：一维阅读顺序明确，项目数量少到中等。
- **Grid**：二维对齐或表单字段需要共享列几何；不要用它模拟任意定位。
- **FlowRow**：标签/筛选项按可用宽度换行，项目高度大致一致。
- **ScrollView**：一个普通内容树超出视口，总节点数仍可接受。
- **Lazy 系列**：大量数据项，只需构建视口附近；需要稳定 id，尺寸可固定、外部提供或由 `LazyList.measured` 自动学习。
- **SplitView**：两个工作区的比例需要用户拖动调整并保留。

先按语义选择主容器，再决定伸缩和滚动。为桌面工作区使用嵌套分栏是合理的；为三行表单使用分栏会增加不必要交互。

## 应用这个模型

设置页可以用外层 `ScrollView` 包裹 `VStack`，让窗口变小时字段可达；数据表主从界面用 `SplitView` 分开表格和详情；聊天历史使用 `LazyList`，输入栏保留在滚动区域外。三者都“内容很多”，但约束和用户目标不同。

下面的结构把“会增长的内容”和“始终可达的主要操作”分开。只有字段区滚动，保存按钮留在外层：

```cangjie role=contrast
VStack {
    ScrollView {
        VStack {
            Label("账户")
            TextField(name)
            Checkbox("接收通知", notifications)
        }.spacing(12.vp)
    }.flex()
    Button("保存", {=> save()}).role(ButtonRole.Primary)
}
```

动态列表还需要数据身份。项目的选择、展开或编辑状态应跟随稳定 id，而不是数组位置；排序后第 0 行不一定还是同一条数据。稳定键只保护仍在构建树中的身份：虚拟行滚出视口后会被卸载，行内状态也会清理。需要跨滚动保留的状态应提升到以业务 id 为键的模型。布局负责位置，状态模型负责身份。

下面的跟踪片段把选择放在列表外层，并让每行用业务 id 建立身份。滚出视口时行控件可以卸载，`selectedId` 仍存在；重新滚回或排序后，按钮文字仍由相同 id 判断：

```cangjie role=trace
let selectedId = rememberState<String>("tasks.selected") {""}
LazyColumn.of(tasks.value, 44.0, key: {task => task.id}) {
    task => Button(
        if (selectedId.value == task.id) {"已选：${task.title}"} else {task.title},
        {=> selectedId.value = task.id}
    )
}
```

## 常见误解

- **“加 ScrollView 就能优化大列表。”** 它提供滚动，不一定减少构建节点。
- **“固定像素能保证对齐。”** 它只保证某个尺寸下对齐，窗口和字体缩放会暴露问题。
- **“数组索引是稳定 id。”** 插入、排序和过滤后索引会指向另一项目。
- **“所有剩余空间都应该 Spacer 吃掉。”** 先明确哪个区域应伸缩；滥用 Spacer 会让关联内容分离。
- **“自测量意味着完全没有估计。”** 未出现的行仍需一个便宜先验；估计影响初始滚动条，不会锁死真实行高。

## 相关 API

- [`VStack`](../../api/cui/core/VStack.md)、[`HStack`](../../api/cui/core/HStack.md)、[`Grid`](../../api/cui/core/Grid.md) — 基础排列。
- [`ScrollView`](../../api/cui/core/ScrollView.md)、[`LazyColumn`](../../api/cui/core/LazyColumn.md) 与 [`LazyList`](../../api/cui/core/LazyList.md) — 普通滚动、定高和自测量虚拟列表。
- [`SplitView`](../../api/cui/controls/SplitView.md) — 可调双区域工作区。
- [`Keyed`](../../api/cui/core/Keyed.md) — 数据身份作用域。

## 下一步

先读[尺寸单位与修饰器顺序](modifiers-and-units.md)，再进入具体布局任务。

在[选择布局容器](../how-to/choose-layout.md)中把内容关系映射到具体容器，再到[构建数据列表](../how-to/data-list.md)处理稳定身份与动态数据。
