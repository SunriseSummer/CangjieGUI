# calendar：月历

一个紫色主题的月历应用，演示状态驱动导航、派生标题与七列网格节奏，以及用 `Surface`
在运行时生成图片资产。

## 演示要点

- 星期表头与日格共享同一套七列 `flex` 节奏，保证逐行严格对齐
- 年与月是两个 `State`，箭头改写状态后相关声明在本帧稳定化时重新构建
- `derive` 派生标题：仅在年或月变化时才重新拼接字符串
- 无 label 的成对 `IconButton` 依靠构建期唯一身份各自响应，无需手写 `.id`
- 用 `Surface` 逐像素生成 PNG 徽标并交给 `ImageView` 展示：`ImageView` 逐帧内联声明即可，
  解码纹理由按路径键控的共享缓存持有，无需提升实例或 `manage`

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口：生成徽标、创建模型与窗口 |
| [model.cj](src/model.cj) | `CalendarModel`：年/月/选中日状态、派生标题、月份进退与周行展开算法 |
| [views.cj](src/views.cj) | 视图：标题栏、月历页、日程页 |
| [theme.cj](src/theme.cj) | 紫色主题与“今天”高亮、日程卡片表面 |
| [badge.cj](src/badge.cj) | 徽标像素绘制与 PNG 保存 |

## 关键实现

### 七列节奏：表头与日格同构

表头的七个 `Label` 和每周的七个日格都以 `.flex()` 参与等权分配，空白格用
`Spacer().flex()` 占位，因此首尾两周与表头始终逐列对齐：

完整分支见 [dayCell](src/views.cj)：月外格用 `Spacer().flex()` 占位，有效日期用同权重按钮。

### 派生标题

标题依赖年与月两个来源，用 `derive` 收拢到模型中；视图直接读 `model.title.value`，
其余时间命中缓存不重算：

```cangjie
this.title = derive(this.year, this.month, {y, m => "${y} 年 ${MONTH_NAMES[m - 1]}"})
```

### 月份进退与选中日夹紧

`shiftMonth` 用循环处理任意跨度的跨年进退位，并把选中日夹紧到目标月的实际天数内
（例如从 3 月 31 日切到 4 月会落在 4 月 30 日）：

月份与选中日的更新见 [CalendarModel.shiftMonth](src/model.cj)。

### 成对箭头按钮的身份

左右箭头都是无 label 的 `IconButton`。框架按声明顺序为它们生成互不相同的构建期身份，
两者分别设置“上个月”“下个月”的无障碍名称；动态重排按钮时应使用稳定 key。

### 周行展开算法

`monthWeeks` 先算出当月 1 号的星期索引，再按 `(首日偏移 + 天数 + 6) / 7` 生成恰好
需要的行数，行内用 0 标记月份之外的格子。

## 运行

```powershell
cd examples/calendar
cjpm run
```

支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot calendar.bmp"
```

月份切换按钮使用 `cui.symbols.chevron_left` 与 `cui.symbols.chevron_right`，无需两枚外部 SVG；标题徽标在启动时生成 `cui-calendar-badge.png`，并以 `.size(40.vp, 30.vp).decodeSize(120, 90)` 展示。

## 练习与验收

从 31 日切到较短月份，确认选中日被限制在有效范围。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
