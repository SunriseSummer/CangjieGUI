[cui](../../index.md) › [cui.controls](index.md) › Rating

# Rating

位于 `cui.controls` 包的公开类

以一排实心/空心圆点输入 0…`count` 整数评分的控件：实心圆点表示当前评分，其余为空心，默认五点。点击圆点把评分设为对应数值，再点当前评分可清零；`readonly` 为 `true` 时只显示评分，不接受输入。

## 声明

```cangjie
public class Rating <: Widget
```

## 继承

`Rating <: Widget` — 实现 [`Widget`](../core/Widget.md) 组件协议。

## 说明

指针交互：点击第 n 个圆点把评分设为 n（一基），点击恰为当前评分的圆点则清零——同一手势即可撤销误评；悬停时按指针位置预览填充数，移开即回落到已提交值。键盘交互：聚焦后 ←/↓ 减一、→/↑ 加一，Home 清零、End 拉满，全部夹在 0…`count`。

传入 `readonly` 后控件变为纯显示：不注册焦点项、不响应任何输入、悬停也不再预览。需要逐行编辑评分数组时，可用 `ratings.project(...)` 创建指向单个评分的 [`Binding`](../core/Binding.md)。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Rating", 640, 420))
    app.run {
        let stars = rememberState<Int64>("stars") {0}
        let rating = Rating(stars)
        // 运行时：点击星位设置评分，再点当前星位可清零；方向键也能调整。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 以评分绑定、点数与只读开关构造评分控件。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(_: UiContext, _: Size)`](#measure) | 恒返回 (count−1)×24+16 逻辑像素宽、24 高的固定尺寸，忽略可用空间。 |
| [`layout(_: UiContext, rect: Rect)`](#layout) | 记录控件框架。 |
| [`isFlexible()`](#isflexible) | 恒为 `false`——点排保持固有宽度，不参与弹性分配。 |
| [`focusableId()`](#focusableid) | 交互模式返回焦点标识；`readonly` 时返回 `None`，不进入 Tab 遍历。 |
| [`draw(ctx: UiContext)`](#draw) | 实心圆点画到评分处、其余空心；悬停时按指针预览填充，键盘聚焦画焦点环。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 点击圆点设置或清零评分并夺焦，←/↓/→/↑ 增减、Home 清零、End 拉满；`readonly` 时忽略一切输入。 |

## 构造函数

### init

以评分绑定、点数与只读开关构造评分控件。

```cangjie
public init(value: Bindable<Int64>, count!: Int64 = 5, readonly!: Bool = false, key!: ?String = None)
```

**参数**

- `value`: [`Bindable`](../core/Bindable.md)`<Int64>` — 评分的双向绑定，取值 0…`count`。
- `count!`: `Int64` — 圆点数；默认 `5`，下限 1。
- `readonly!`: `Bool` — 为 `true` 时纯显示：不注册焦点、不响应输入；默认 `false`。
- `key!`: `?String` — 显式焦点标识；默认 `None`，按构建顺序自动派生。

**异常**

- `IllegalArgumentException` — `key` 传入空字符串时。

## 方法

### measure

恒返回 (count−1)×24+16 逻辑像素宽、24 高的固定尺寸，忽略可用空间。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func measure(_: UiContext, _: Size): Size
```

**返回值** `Size` — 组件请求的尺寸；方法接收 `available` 时，该尺寸在父级给出的可用约束内计算。

### layout

记录控件框架。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func layout(_: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 父级最终分配给组件的矩形。

### isFlexible

恒为 `false`——点排保持固有宽度，不参与弹性分配。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 固定为 `false`，组件按自身请求尺寸参与布局。

### focusableId

交互模式返回焦点标识；`readonly` 时返回 `None`，不进入 Tab 遍历。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 可编辑时返回参与键盘焦点导航的标识；只读时返回 `None`。

### draw

实心圆点画到评分处、其余空心；悬停时按指针预览填充，键盘聚焦画焦点环。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

点击圆点设置或清零评分并夺焦，←/↓/→/↑ 增减、Home 清零、End 拉满；`readonly` 时忽略一切输入。点击恰为当前评分的圆点清零，其余点击把评分设到点击位置（一基）。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 是否已消费该事件；`true` 表示调用方不应再继续分发。

## 另请参阅

- [Binding](../core/Binding.md) — 为数组中的单个评分创建可供本控件使用的双向绑定。
- [Stepper](Stepper.md) — 通用整数值输入。
