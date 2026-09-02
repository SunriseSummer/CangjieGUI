[cui](../../index.md) › [cui.controls](index.md) › TabView

# TabView

位于 `cui.controls` 包的公开类

顶部页签条加整页内容区的页签容器，同一时刻只有选中页参与布局、绘制与事件。界面构建函数里每个顶层组件即一页，按声明顺序与 `labels` 对应；页签条与 [`SegmentedControl`](SegmentedControl.md) 同视觉——滑动指示块标记当前页，点击切换，聚焦后 Left/Right 步进。

## 声明

```cangjie
public class TabView <: Widget
```

## 继承

- [`Widget`](../core/Widget.md)

## 说明

页签条是一个焦点项，在页面构建之前注册，因此 Tab 先到达页签条、再进入页内控件，与视觉顺序（条在内容之上）一致。构建时会注销非活动页注册的焦点项，Tab 不会落入不可见页的死角；切换页签后由下一帧重建重新注册。

页签条占顶部 38 逻辑像素，页面区在其下方隔 8 逻辑像素铺满剩余空间。页签始终等宽；标签超过各自单元格
时独立省略并裁剪，不会覆盖相邻页签。选中页在同一帧的布局与绘制/事件之间变化时（点击切换页签，或代码
写入绑定），新页面按需补布局，不会以过期框架绘制。`labels` 数与页面数可以不同：显示与命中按 `labels`
限制，取页按页面数限制。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("TabView", 640, 420))
    app.run {
        let tab = rememberState<Int64>("tab") {0}
        let view = TabView(["收件箱", "已归档"], tab) {
            Label("34 封未读邮件")
            Label("归档为空")
        }
        // 运行时：点击页签或用方向键切换页面，只有活动页内容可见。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(labels: Array<String>, selected: Bindable<Int64>, key!: ?String = None, body!: () -> Unit)`](#init) | 以页签标签、选中下标绑定与页面构建器构造页签容器。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(_: UiContext, available: Size)`](#measure) | 占满全部可用尺寸（[`Widget`](../core/Widget.md) 协议）。 |
| [`layout(ctx: UiContext, rect: Rect)`](#layout) | 记录框架并为活动页布局（[`Widget`](../core/Widget.md) 协议）。 |
| [`draw(ctx: UiContext)`](#draw) | 绘制页签条与活动页（[`Widget`](../core/Widget.md) 协议）。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 页签条点击与方向键切页，其余事件转发给活动页（[`Widget`](../core/Widget.md) 协议）。 |
| [`isFlexible()`](#isflexible) | 恒为 `true`：参与父栈的剩余空间分配（[`Widget`](../core/Widget.md) 协议）。 |
| [`focusableId()`](#focusableid) | 返回页签条的键盘焦点标识（[`Widget`](../core/Widget.md) 协议）。 |
| [`focusableIds()`](#focusableids) | 返回页签条与所有页面（含隐藏页）的焦点项（[`Widget`](../core/Widget.md) 协议）。 |

## 构造函数

### init

以页签标签、选中下标绑定与页面构建器构造页签容器。

```cangjie
public init(labels: Array<String>, selected: Bindable<Int64>, key!: ?String = None, body!: () -> Unit)
```

**参数**

- `labels`: `Array<String>` — 页签标签，按顺序等宽排布。
- `selected`: [`Bindable`](../core/Bindable.md)`<Int64>` — 选中页下标的双向绑定；越界值限制在有效范围。
- `key!`: `?String` — 稳定标识，须在同一次构建内唯一；默认 `None` 按声明顺序自动派生。
- `body!`: `() -> Unit` — 页面界面构建函数：其中每个顶层组件即一页，按声明顺序与 `labels` 对应。

**异常**

- `IllegalArgumentException` — `key` 传入空字符串时。

## 方法

### measure

占满全部可用尺寸（[`Widget`](../core/Widget.md) 协议）。

```cangjie
public func measure(_: UiContext, available: Size): Size
```

**参数**

- `available`: `Size` — 父级提供的可用尺寸（逻辑像素）。

**返回值** `Size` — 与 `available` 相同。

### layout

记录框架并为活动页布局（[`Widget`](../core/Widget.md) 协议）。活动页的框架为页签条（38 逻辑像素）之下、隔 8 逻辑像素后的剩余区域。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 帧服务上下文。
- `rect`: `Rect` — 分配给容器的框架矩形（逻辑像素）。

### draw

绘制页签条与活动页（[`Widget`](../core/Widget.md) 协议）。页签条为字段底面加滑动指示块，键盘聚焦时叠加
焦点环；每个标签在自己的等宽单元格内省略并裁剪；`labels` 为空时不绘制页签条。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: `UiContext` — 帧服务上下文。

### handle

页签条点击与方向键切页，其余事件转发给活动页（[`Widget`](../core/Widget.md) 协议）。左键按下页签条内切到命中页签并获得焦点；页签条聚焦后 Left/Right 步进（两端限制不回绕）；未消费的事件交给活动页处理。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: `UiContext` — 帧服务上下文。
- `event`: `UiEvent` — 本帧派发的输入事件。

**返回值** `Bool` — 页签条消费了事件，或活动页消费了事件时为 `true`。

### isFlexible

恒为 `true`：参与父栈的剩余空间分配（[`Widget`](../core/Widget.md) 协议）。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 恒为 `true`。

### focusableId

返回页签条的键盘焦点标识（[`Widget`](../core/Widget.md) 协议）。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 恒为 `Some`，值为页签条的控件标识。

### focusableIds

返回页签条与所有页面（含隐藏页）的焦点项（[`Widget`](../core/Widget.md) 协议）。整个 TabView 被 `.enabled(false)` 禁用时，会据此一并移出 Tab 遍历；隐藏页的焦点项即使当前不在遍历序列中，后续帧重建时也会重新注册。

```cangjie
public func focusableIds(): Array<String>
```

**返回值** `Array<String>` — 页签条标识在前，随后按声明顺序拼接各页的焦点项。

## 另请参阅

- [SegmentedControl](SegmentedControl.md) — 同视觉的分段单选，不承载页面。
- [Accordion](Accordion.md) — 纵向逐节展开的分区容器。
