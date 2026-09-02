[cui](../../index.md) › [cui.controls](index.md) › Picker

# Picker

位于 `cui.controls` 包的公开类

在一组有限字符串项之间前后切换的紧凑选择器：两端各一枚 ‹ › 按钮、中间显示当前项，切换在两端回绕。适合视图粒度、周期等少量循环选项；要一次看到全部候选项时用弹出式的 [`Dropdown`](Dropdown.md)。

## 声明

```cangjie
public class Picker <: Widget
```

## 继承

`Picker <: Widget` — 实现 [`Widget`](../core/Widget.md) 组件协议。

## 说明

宽度随内容自适应：以最长项的文字宽度加两侧按钮区取自然宽（下限 120 逻辑像素），故选中项变化时控件宽度稳定不跳。当前项文本被裁剪进中间区绘制，过长的应用数据不会画到按钮上或溢出控件面。

`items` 为空时显示“—”，切换无效果；越界的 `selected` 只在显示时按就近端截取。点击两端按钮立即切换并夺取键盘焦点，点击中间区域仅夺焦；聚焦后 ←/→ 同样前后切换，两个方向都在端点回绕。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Picker", 640, 420))
    app.run {
        let scales = ["日视图", "周视图", "月视图"]
        let selected = rememberState<Int64>("selected") {0}
        let picker = Picker(scales, selected)
        // 运行时：点击两侧箭头或聚焦后按方向键，在三个时间尺度之间循环。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(items: Array<String>, selected: Bindable<Int64>, key!: ?String = None)`](#init) | 以候选项与选中下标绑定构造选择器。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(ctx: UiContext, available: Size)`](#measure) | 返回自适应最长项的宽度（下限 120、含两侧按钮区）与 38 逻辑像素高，封顶于可用宽度。 |
| [`layout(_: UiContext, rect: Rect)`](#layout) | 记录控件框架。 |
| [`draw(ctx: UiContext)`](#draw) | 绘制字段面、裁剪进中间区的当前项文本与两侧 ‹ › 按钮；空集合显示“—”。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 点击两端按钮前后切换（回绕）、点击其余区域仅夺焦；聚焦后 ←/→ 切换。 |
| [`focusableId()`](#focusableid) | 返回选择器的焦点标识。 |

## 构造函数

### init

以候选项与选中下标绑定构造选择器。

```cangjie
public init(items: Array<String>, selected: Bindable<Int64>, key!: ?String = None)
```

**参数**

- `items`: `Array<String>` — 候选项；空数组时显示“—”且切换无效果。
- `selected`: [`Bindable`](../core/Bindable.md)`<Int64>` — 选中下标的双向绑定；越界值仅在显示时按就近端截取。
- `key!`: `?String` — 显式焦点标识；默认 `None`，按构建顺序自动派生。

**异常**

- `IllegalArgumentException` — `key` 传入空字符串时。

## 方法

### measure

返回自适应最长项的宽度（下限 120、含两侧按钮区）与 38 逻辑像素高，封顶于可用宽度。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮测量使用的 UI 上下文。
- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 组件请求的尺寸；方法接收 `available` 时，该尺寸在父级给出的可用约束内计算。

### layout

记录控件框架。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func layout(_: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

绘制字段面、裁剪进中间区的当前项文本与两侧 ‹ › 按钮；空集合显示“—”。键盘聚焦时字段面带焦点样式。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

点击两端按钮前后切换（回绕）、点击其余区域仅夺焦；聚焦后 ←/→ 切换。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 是否已消费该事件；`true` 表示调用方不应再继续分发。

### focusableId

返回选择器的焦点标识。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 该控件用于参与键盘焦点导航的标识。

## 另请参阅

- [Dropdown](Dropdown.md) — 弹出完整候选列表的单选控件。
- [SegmentedControl](SegmentedControl.md) — 并排展示全部选项的分段单选。
- [Stepper](Stepper.md) — 同样的前后步进交互，作用于整数值。
