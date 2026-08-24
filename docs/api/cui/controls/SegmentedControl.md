[cui](../../index.md) › [cui.controls](index.md) › SegmentedControl

# SegmentedControl

`cui.controls` 包中的 public class

把互斥选项排成一行等宽段、由滑动指示块标记当前选中的单选控件。点击任一段即切换并更新绑定下标；控件是一个焦点项，聚焦后 Left/Right 步进选中。

## 声明

```cangjie
public class SegmentedControl <: Widget
```

## 继承

- [`Widget`](../core/Widget.md)

## 说明

选中指示块由 [`Spring`](../core/Spring.md) 弹簧动画滑到目标段，构造时直接落位于当前选中，静态首帧即是稳定画面；动画超冲被限制在控件内。绑定值越界（负数或 ≥ 段数）时按有效范围限制显示与命中；键盘步进在两端限制、不回绕。`items` 为空时控件不绘制内容也不响应点击。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("SegmentedControl", 640, 420))
    app.run {
        let period = rememberState<Int64>("period") {0}
        let control = SegmentedControl(["日", "周", "月"], period)
        // 运行时：点击“日、周、月”任一分段，选中背景与绑定下标同步变化。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(items: Array<String>, selected: Bindable<Int64>, key!: ?String = None)`](#init) | 以段标签与选中下标绑定构造分段控件。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(ctx: UiContext, available: Size)`](#measure) | 按最长标签测量等宽段的自然宽度并限制到可用宽度，高度固定 38（[`Widget`](../core/Widget.md) 协议）。 |
| [`layout(_: UiContext, rect: Rect)`](#layout) | 记录分配的矩形作为整个控件的命中与绘制区域（[`Widget`](../core/Widget.md) 协议）。 |
| [`draw(ctx: UiContext)`](#draw) | 绘制字段底面、滑动选中块与各段标签，键盘聚焦时叠加焦点环（[`Widget`](../core/Widget.md) 协议）。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 左键按下选中命中段并获得焦点，聚焦后 Left/Right 步进选中（[`Widget`](../core/Widget.md) 协议）。 |
| [`focusableId()`](#focusableid) | 返回控件注册的键盘焦点标识（[`Widget`](../core/Widget.md) 协议）。 |

## 构造函数

### init

以段标签与选中下标绑定构造分段控件。

```cangjie
public init(items: Array<String>, selected: Bindable<Int64>, key!: ?String = None)
```

**参数**

- `items`: `Array<String>` — 各段标签，按顺序等宽排布；空数组时控件不绘制也不响应点击。
- `selected`: [`Bindable`](../core/Bindable.md)`<Int64>` — 选中段下标的双向绑定；越界值在显示与命中时限制在有效范围。
- `key!`: `?String` — 稳定标识，须在同一次构建内唯一；默认 `None` 按声明顺序自动派生，需要跨结构变化保留状态或从外部寻址时传入。

**异常**

- `IllegalArgumentException` — `key` 传入空字符串时。

## 方法

### measure

每段自然宽度取 96 逻辑像素与“最长标签实际文字宽度 + 两侧各 12 像素留白”中的较大值；控件宽度为等宽段
总和，但不超过父级可用宽度，高度固定 38（[`Widget`](../core/Widget.md) 协议）。空 `items` 仍按一段 96 计。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 用当前字体后端测量标签。
- `available`: `Size` — 父级提供的可用尺寸（逻辑像素）。

**返回值** `Size` — 期望尺寸。

### layout

记录分配的矩形作为整个控件的命中与绘制区域（[`Widget`](../core/Widget.md) 协议）。

```cangjie
public func layout(_: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 分配给控件的框架矩形（逻辑像素）。

### draw

绘制字段底面、滑动选中块与各段标签，键盘聚焦时叠加焦点环（[`Widget`](../core/Widget.md) 协议）。指示块所覆盖
的那段标签用强调底上的文字色，其余用普通文字色。父级分配小于自然宽度时，每个标签在自己的单元格内独立
省略并裁剪，绝不会与相邻段叠画；`items` 为空时不绘制任何内容。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 帧服务上下文。

### handle

左键按下选中命中段并获得焦点，聚焦后 Left/Right 步进选中（[`Widget`](../core/Widget.md) 协议）。段按等宽划分命中；方向键在两端限制不回绕，未聚焦时不处理；指针悬停时申请交互指针形状但不消费事件。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: `UiContext` — 帧服务上下文。
- `event`: `UiEvent` — 本帧派发的输入事件。

**返回值** `Bool` — 点击了段或消费了方向键时为 `true`。

### focusableId

返回控件注册的键盘焦点标识（[`Widget`](../core/Widget.md) 协议）。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 恒为 `Some`，值为构造时确定的控件标识。

## 另请参阅

- [TabView](TabView.md) — 同视觉的页签条，切换整页内容。
- [RadioButton](RadioButton.md) — 逐项铺开的互斥单选。
