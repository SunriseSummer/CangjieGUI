[cui](../../index.md) › cui.controls

# cui.controls

```cangjie
import cui.controls.*
```

建立在 `cui.core` 之上的成品控件。它们已经处理常见的主题、焦点、键盘、状态绑定和无障碍行为。需求能由这些控件组合完成时，应优先组合；需要新尺寸或交互协议时再实现自定义 `Widget`。

## 选择与输入

| 类型 | 说明 |
|---|---|
| [`Checkbox`](Checkbox.md) | 绑定布尔值的勾选框。 |
| [`Switch`](Switch.md) | 绑定布尔值的开关。 |
| [`RadioButton`](RadioButton.md) | 共享整数绑定的一组互斥选项。 |
| [`Chip`](Chip.md) | 可选中的紧凑标签。 |
| [`SegmentedControl`](SegmentedControl.md) | 横向等宽的单选分段控件。 |
| [`Dropdown`](Dropdown.md) | 从下拉列表中选择一个字符串选项。 |
| [`Picker`](Picker.md) | 使用前后按钮在有限选项间切换。 |
| [`Slider`](Slider.md) | 在浮点区间内连续或按步长取值。 |
| [`Stepper`](Stepper.md) | 使用减、增按钮编辑整数值。 |
| [`Rating`](Rating.md) | 输入 0 到指定数量的整数评分。 |
| [`DatePicker`](DatePicker.md) | 通过月历浮层编辑日期。 |
| [`CalendarDate`](CalendarDate.md) | 不含时刻和时区的日历日期值。 |
| [`TimePicker`](TimePicker.md) | 通过浮层编辑小时和分钟。 |
| [`TimeOfDay`](TimeOfDay.md) | 不含日期和时区的一天内时刻。 |

## 导航与界面结构

| 类型 | 说明 |
|---|---|
| [`Breadcrumb`](Breadcrumb.md) | 显示层级路径并允许返回上级。 |
| [`Pagination`](Pagination.md) | 在长结果集中切换页码。 |
| [`TabView`](TabView.md) | 顶部页签和单个活动内容页。 |
| [`StepIndicator`](StepIndicator.md) | 显示多步流程的当前进度。 |
| [`Accordion`](Accordion.md) | 纵向排列可展开、收起的分区。 |
| [`AccordionSection`](AccordionSection.md) | Accordion 的标题与内容构建描述。 |
| [`SplitView`](SplitView.md) | 使用可拖动分隔条调整两个区域。 |
| [`ReorderableList`](ReorderableList.md) | 通过拖动手柄报告列表项目移动。 |

## 数据与内容展示

| 类型 | 说明 |
|---|---|
| [`ListView`](ListView.md) | 可滚动、支持键盘的单选字符串列表。 |
| [`Table`](Table.md) | 固定表头、可排序、只绘制可见行的数据表。 |
| [`TableColumn`](TableColumn.md) | 字符串矩阵表格的列定义。 |
| [`DataColumn`](DataColumn.md) | `Table.of` 使用的类型化列定义。 |
| [`TreeView`](TreeView.md) | 可展开、收起的层级列表。 |
| [`TreeNode`](TreeNode.md) | TreeView 的稳定 ID、标签、图标和子节点数据。 |
| [`RichText`](RichText.md) | 支持多样式片段和自动换行的富文本。 |
| [`RichSpan`](RichSpan.md) | RichText 中的一段文字或行内图标。 |
| [`Badge`](Badge.md) | 显示类别或状态的紧凑标签。 |
| [`BadgeKind`](BadgeKind.md) | Badge 的中性、强调或状态配色。 |
| [`ProgressBar`](ProgressBar.md) | 水平进度条。 |
| [`ProgressRing`](ProgressRing.md) | 环形进度指示。 |

## 菜单、浮层与反馈

| 类型 | 说明 |
|---|---|
| [`MenuBar`](MenuBar.md) | 桌面应用顶部菜单栏。 |
| [`Menu`](Menu.md) | 一个顶级菜单的标题和条目。 |
| [`MenuItem`](MenuItem.md) | 菜单动作、快捷键提示或分隔线。 |
| [`ContextMenu`](ContextMenu.md) | 为任意内容添加右键菜单。 |
| [`Modal`](Modal.md) | 阻止背景交互的模态对话框。 |
| [`Toaster`](Toaster.md) | 管理有时限的 Toast 消息。 |
| [`ToastLayer`](ToastLayer.md) | 在视口右下角绘制 Toast 并推进计时。 |
| [`ToastKind`](ToastKind.md) | Toast 的信息、成功、警告或错误类别。 |
