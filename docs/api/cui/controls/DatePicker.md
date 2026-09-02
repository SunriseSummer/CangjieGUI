[cui](../../index.md) › [cui.controls](index.md) › DatePicker

# DatePicker

位于 `cui.controls` 包的公开类

日期字段：点击弹出月历浮层，双向绑定一个 `Bindable<CalendarDate>`。闭合时显示当前绑定的日期，月历经交互浮层浮到组件树之上——点击不会被下方控件截走；点一天即选中并关闭。

## 声明

```cangjie
public class DatePicker <: Widget
```

## 继承

- [`Widget`](../core/Widget.md) — 组件协议（measure/layout/draw/handle 与焦点遍历）。

## 说明

月历打开后：表头箭头翻页月份；方向键移动高亮日（跨过月界会自动翻页视图），Home/End 直接翻上/下一月，Enter 或 Space 提交高亮日，Escape 或点击月历外关闭，Tab 关闭并继续焦点遍历。浏览中的月份可以偏离选中日期所在月，重新打开时回到选中日期。今天以强调色软底标出。

月历默认显示在字段下方，空间不足时改到上方；水平方向会自动调整，保证整个月历留在视口内。绑定值始终是合法日期（构造时即会限制范围，见 [`CalendarDate`](CalendarDate.md)），下游代码不会见到 2 月 30 日。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("DatePicker", 640, 420))
    app.run {
        let checkIn = rememberState<CalendarDate>("checkIn") {CalendarDate(2026, 7, 15)}
        VStack(spacing: 12.vp) {
            DatePicker(checkIn)
            Label("入住日期：${checkIn.value.iso()}").muted()
        }.padding(24.0)
        // 运行时：点击日期字段打开月历，可用方向键移动并按 Enter 提交日期。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(selected: Bindable<CalendarDate>, key!: ?String)`](#init) | 由日期绑定构造日期字段。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(_: UiContext, available: Size)`](#measure) | 宽为可用宽与 176 逻辑像素的较小者，高固定 38。 |
| [`layout(_: UiContext, rect: Rect)`](#layout) | 记录分配到的框架。 |
| [`draw(ctx: UiContext)`](#draw) | 画字段（当前日期文本与日历图标）；打开时把月历注册为交互浮层。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 点击字段打开月历；聚焦时 Enter/Space/↓ 同效。 |
| [`focusableId()`](#focusableid) | 返回本控件的焦点 id。 |
| [`isFlexible()`](#isflexible) | 恒返回 `false`——字段保持固有宽度，不参与栈的剩余空间分配。 |

## 构造函数

### init

由日期绑定构造日期字段。

```cangjie
public init(selected: Bindable<CalendarDate>, key!: ?String = None)
```

**参数**

- `selected`: `Bindable<CalendarDate>` — 双向绑定的选中日期；打开月历时视图定位到它所在月。
- `key!`: `?String` — 显式控件标识（同时标识浮层注册）；空串抛 `IllegalArgumentException`。默认 `None`，按构建顺序自动派生。

## 方法

### measure

宽为可用宽与 176 逻辑像素的较小者，高固定 38。字段自身贴合固有尺寸（见 [`Widget`](../core/Widget.md)）。

```cangjie
public func measure(_: UiContext, available: Size): Size
```

**参数**

- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 组件请求的尺寸；方法接收 `available` 时，该尺寸在父级给出的可用约束内计算。

### layout

记录分配到的框架。

```cangjie
public func layout(_: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

画字段（当前日期文本与日历图标）；打开时把月历注册为交互浮层。字段文本形如"2026 年 7 月 15 日"，聚焦或打开时底面进入活跃态。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

点击字段打开月历；聚焦时 Enter/Space/↓ 同效。月历内部的键鼠交互由浮层处理（见"说明"）。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 是否已消费该事件；`true` 表示调用方不应再继续分发。

### focusableId

返回本控件的焦点 id。构造时已注册为焦点项（见 [`Widget`](../core/Widget.md)）。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 该控件用于参与键盘焦点导航的标识。

### isFlexible

恒返回 `false`——字段保持固有宽度，不参与栈的剩余空间分配。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 固定为 `false`，组件按自身请求尺寸参与布局。

## 另请参阅

- [CalendarDate](CalendarDate.md) — 绑定的日历日值类型。
- [TimePicker](TimePicker.md) — 一天内时刻的选择字段。
- [Dropdown](Dropdown.md) — 同为浮层弹出的下拉选择。
