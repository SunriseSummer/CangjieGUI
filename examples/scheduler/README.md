# scheduler：会议排期（时间选择器）

一个会议排期界面，集中演示 `TimePicker` 时间选择：时/分网格选时、方向键微调、跨午夜环绕，配合
`DatePicker` 与派生时长校验，把会议按 (日期, 开始时间) 排入日程。

## 演示要点

- `TimePicker` 弹出时/分网格：全部 24 小时 + 按 `minuteStep`（默认 5）间隔的分钟；点小时或分钟即实时更新，浮层保持打开
- 浮层内键盘：上/下按一个 `minuteStep` 增减、左/右按整小时增减，均跨午夜环绕；外点/Esc/Enter/Tab 关闭
- 开始/结束用两个 `TimePicker`，与 `DatePicker` 并排；时长由 `TimeOfDay.totalMinutes()` 之差实时算出，无效时红字提示
- “添加到日程”仅在时长有效且主题非空时可用；已排会议按 (日期, 开始时间) 升序排列
- 时长、排序键、时间段文案都是 `TimeOfDay`/`CalendarDate` 的纯函数，与视图无关，便于单测

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | `Meeting` 类型、时长计算、时间段文案、按 (日期, 开始) 排序 |
| [model.cj](src/model.cj) | `SchedulerModel`：表单字段、时长派生、可用性校验、添加 |
| [views.cj](src/views.cj) | 表单（主题/日期/开始/结束/时长/添加）与已排日程列表 |
| [theme.cj](src/theme.cj) | 浅色主题与无效时长的警示色 |

## 关键实现

### 时长是开始/结束时间的纯函数

时长由两个 `TimeOfDay` 的分钟数之差算出，同一函数同时驱动时长提示与“添加”可用性：

```cangjie
func meetingDurationMinutes(start: TimeOfDay, end: TimeOfDay): Int64 {
    let span = end.totalMinutes() - start.totalMinutes()
    if (span > 0) { span } else { 0 } // 结束不晚于开始记 0（无效）
}
```

### 添加后按时间排序

新会议追加后按 (日期, 开始时间) 升序返回新数组，视图直接渲染，无需缓存：

```cangjie
func meetingLess(a: Meeting, b: Meeting): Bool {
    let byDate = a.date.compareTo(b.date)
    if (byDate != 0) { return byDate < 0 }
    a.start.compareTo(b.start) < 0
}
```

## 运行

```powershell
cd examples/scheduler
cjpm run
```

点“开始/结束”时间框弹出时/分网格选时，时长实时更新；填好主题点“添加到日程”排入列表。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot scheduler.bmp"
```
