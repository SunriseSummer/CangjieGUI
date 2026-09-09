[cui](../../index.md) › [cui.controls](index.md) › TimePicker

# TimePicker

位于 `cui.controls` 包的公开类

带弹出选择面板的时间字段：闭合时显示绑定的 [`TimeOfDay`](TimeOfDay.md)，点击（或聚焦后按 Enter/Space/Down）经交互浮层弹出面板，面板把 24 小时网格与逐分钟编辑器配成一对。绑定值始终是合法的 24 小时制时刻。

## 声明

```cangjie
public class TimePicker <: Widget
```

## 继承

- [`Widget`](../core/Widget.md)

## 说明

面板经交互浮层显示在组件树之上（与 [`Dropdown`](Dropdown.md)/[`DatePicker`](DatePicker.md) 同机制），点击不会被下方控件截走。面板默认显示在字段下方，空间不足时改到上方，并自动调整横向位置以留在视口内。小时一次点击即选；分钟提供三种调节方式：横向滑杆按 `minuteStep` 粗调（两端仍精确对应 00 与 59）、−/+ 按钮逐分钟调节（只在 59↔00 内循环，不改变小时），以及直接键入数字（首位为 6–9 时立即提交；否则第二位提交两位数；Backspace 清除待输入值，Enter 提交，Escape 取消）。

选中小时或分钟即时更新绑定值且面板保持打开（时间需要两部分都定），面板在点击外部、Escape、Enter 或 Tab 时收起。面板打开期间方向键微调时间：Up/Down 加减 1 分钟、Left/Right 加减整小时，全部跨午夜回卷。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("TimePicker", 640, 420))
    app.run {
        let start = rememberState<TimeOfDay>("start") {TimeOfDay(9, 0)}
        let picker = TimePicker(start, minuteStep: 15)
        // 运行时：拖动时、分滑杆或使用按钮调整时间，分钟滑杆按步长吸附。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(selected: Bindable<TimeOfDay>, minuteStep!: Int64 = 5, hour12!: Bool = false, key!: ?String = None)`](#init) | 以时刻绑定构造时间字段。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(ctx: UiContext, available: Size)`](#measure) | 自然宽度至少 132 逻辑像素，并按实际显示文本（含 12 小时制后缀）加 46 单位图标与留白测量，高度适应字号（[`Widget`](../core/Widget.md) 协议）。 |
| [`layout(_: UiContext, rect: Rect)`](#layout) | 记录分配的矩形作为字段的命中与绘制区域（[`Widget`](../core/Widget.md) 协议）。 |
| [`draw(ctx: UiContext)`](#draw) | 绘制闭合字段（当前时刻加时钟图标），面板打开时注册浮层（[`Widget`](../core/Widget.md) 协议）。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 点击字段或聚焦后按 Enter/Space/Down 打开面板（[`Widget`](../core/Widget.md) 协议）。 |
| [`focusableId()`](#focusableid) | 返回字段注册的键盘焦点标识（[`Widget`](../core/Widget.md) 协议）。 |
| [`isFlexible()`](#isflexible) | 恒为 `false`：字段紧贴内容宽度，不参与弹性分配（[`Widget`](../core/Widget.md) 协议）。 |

## 构造函数

### init

以时刻绑定构造时间字段。

```cangjie
public init(selected: Bindable<TimeOfDay>, minuteStep!: Int64 = 5, hour12!: Bool = false, key!: ?String = None)
```

**参数**

- `selected`: [`Bindable`](../core/Bindable.md)`<`[`TimeOfDay`](TimeOfDay.md)`>` — 选定时刻的双向绑定，面板内的每次选择即时写回。
- `minuteStep!`: `Int64` — 分钟滑杆的吸附间隔，限制在 1–60；默认 `5`。只影响滑杆粗调，−/+ 按钮、键入与方向键始终按单分钟移动，任何分钟值都可达。
- `hour12!`: `Bool` — 闭合字段是否用 12 小时制（[`TimeOfDay.format12`](TimeOfDay.md#format12)）显示；默认 `false` 用 24 小时制 `HH:MM`。
- `key!`: `?String` — 稳定标识，须在同一次构建内唯一；默认 `None` 按声明顺序自动派生。

**异常**

- `IllegalArgumentException` — `key` 传入空字符串时。

## 方法

### measure

自然宽度至少 132 逻辑像素，并按实际显示文本（含 12 小时制后缀）加 46 单位图标与留白测量，高度适应字号（[`Widget`](../core/Widget.md) 协议）。自然宽度超出可用空间时收窄到可用宽度。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `available`: `Size` — 父级提供的可用尺寸（逻辑像素）。

**返回值** `Size` — 期望尺寸。

### layout

记录分配的矩形作为字段的命中与绘制区域（[`Widget`](../core/Widget.md) 协议）。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 分配给字段的框架矩形（逻辑像素）。

### draw

绘制闭合字段（当前时刻加时钟图标），面板打开时注册浮层（[`Widget`](../core/Widget.md) 协议）。面板内容与事件都由浮层承接：小时网格、分钟步进器与滑杆在浮层渲染回调里绘制。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 帧服务上下文。

### handle

点击字段或聚焦后按 Enter/Space/Down 打开面板（[`Widget`](../core/Widget.md) 协议）。点击同时夺取键盘焦点；指针悬停时申请交互指针形状。面板打开后的键鼠交互不再走此方法，而由浮层分发（[`UiContext.dispatchOverlay`](../core/UiContext.md#dispatchoverlay)）。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: `UiContext` — 帧服务上下文。
- `event`: `UiEvent` — 本帧派发的输入事件。

**返回值** `Bool` — 本次事件打开了面板时为 `true`。

### focusableId

返回字段注册的键盘焦点标识（[`Widget`](../core/Widget.md) 协议）。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 恒为 `Some`，值为构造时确定的控件标识。

### isFlexible

恒为 `false`：字段紧贴内容宽度，不参与弹性分配（[`Widget`](../core/Widget.md) 协议）。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 恒为 `false`。

## 另请参阅

- [TimeOfDay](TimeOfDay.md) — 绑定的时刻值类型。
- [DatePicker](DatePicker.md) — 同机制的日期选择字段。
- [Dropdown](Dropdown.md) — 同机制的通用下拉选择。
