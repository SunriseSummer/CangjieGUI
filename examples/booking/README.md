# booking：酒店预订

一张实时结算的预订表单，集中演示 `DatePicker` 日期选择器与 `CalendarDate` 日期运算：入住、退房两个
日期驱动晚数、单价、合计与有效性校验，编辑即刻联动。

## 演示要点

- `DatePicker` 闭合态显示所绑定的 `CalendarDate`，点击/Enter/Space/Down 弹出月历浮层（下方放不下翻到上方）
- 浮层内点选某日即选中并关闭；表头箭头翻月；外点或 Esc 关闭
- 键盘：方向键移动高亮日（越月自动翻页），Home/End 上/下翻月，Enter 确认高亮日
- 晚数取 `checkOut.compareTo(checkIn)`——`compareTo` 返回两日相差的天数，恰是晚数；据此“退房须晚于入住”
  退化为“晚数为正”，无需另写日期比较
- 房型 `SegmentedControl`、人数 `Stepper` 与日期一起，经 `derive` 派生晚数、单价、合计与 `isValid`
- 无效（退房不晚于入住）时摘要转为警示、确认按钮禁用；确认写入回执，任一字段再编辑即作废回执
- `mountEffect` 将四个 `State.observe` 句柄交给视图声明周期管理：构建成功后安装，卸载时自动取消
- 今日日期在入口 `main` 读取后传入模型（而非模型内部读时钟），使模型逻辑可用固定日期确定性地测试

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口；读取今日并注入模型 |
| [data.cj](src/data.cj) | 房型价目、两日期间晚数、金额格式化等纯函数 |
| [model.cj](src/model.cj) | `BookingModel`：日期/房型/人数状态，派生晚数/单价/合计/有效性，确认与回执作废 |
| [views.cj](src/views.cj) | 录入表单、实时结算摘要、确认回执 |
| [theme.cj](src/theme.cj) | 米色纸面 + 松绿强调色主题与色彩令牌 |

## 关键实现

### 晚数即天数差

`CalendarDate.compareTo` 返回两个日期相差的天数，因此入住到退房的晚数、以及“退房是否晚于入住”都由它一并得出：

```cangjie
func nightsBetween(checkIn: CalendarDate, checkOut: CalendarDate): Int64 {
    checkOut.compareTo(checkIn) // 正数为晚数，非正表示退房不晚于入住
}
```

晚数、单价、合计、有效性都是 `derive` 的结果，四个输入任一改变都会即时重算并反映到摘要与确认按钮的启用状态。

### 今日由入口注入

模型不在内部读时钟，而是接收入口传入的 `today`：

```cangjie
// main.cj
let model = BookingModel(CalendarDate.today())
```

这样默认入住/退房日期虽随真实“今天”变化，模型逻辑却能在测试里以固定日期确定性地构造与断言。

### 回执随编辑作废

确认后写入一段回执文案；为避免它与随后的新选择不一致，视图用 `State.observe`
监听四个输入，任一改变即清空回执。观察句柄是需要关闭的 `Resource`，所以由
`mountEffect` 在根构建成功后安装并随视图卸载自动取消：

```cangjie
mountEffect("invalidate-receipt/check-in", {=>
    model.checkIn.observe({_, _ => model.invalidateConfirmation()})
})
```

这避免了丢弃 `observe` 返回值造成的隐式泄漏，也使模型不会在 UI 离场后继续被陈旧回调修改。

## 运行

```powershell
cd examples/booking
cjpm run
```

点击日期字段弹出月历，点选或用方向键选择日期；改动房型、人数，观察摘要与合计实时更新；日期无效时确认
按钮禁用。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot booking.bmp"
```

## 练习与验收

增加最长入住天数校验，确认摘要、按钮和确认回执使用同一规则。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
