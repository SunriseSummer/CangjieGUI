[cui](../../index.md) › [cui.controls](index.md) › Checkbox

# Checkbox

位于 `cui.controls` 包的公开类

带文本标签的勾选框，双向绑定一个 `Bindable<Bool>`。框内按下并抬起（或聚焦后 Enter/Space）翻转绑定值；勾选填充块以弹簧动画从中心放大。

## 声明

```cangjie
public class Checkbox <: Widget
```

## 继承

- [`Widget`](../core/Widget.md) — 组件协议（measure/layout/draw/handle 与焦点遍历）。

## 说明

绑定接受 [`Bindable`](../core/Bindable.md)：既可以是 [`State`](../core/State.md)`<Bool>`，也可以是指向模型字段的 [`Binding`](../core/Binding.md)。默认焦点标识由标签派生并按构建顺序去重；要跨结构变化保持交互状态或给测试一个稳定定位点，用 [`key`](#key) 指定显式标识。翻转在抬起时提交：按下后把指针移出框内再松开不改变值。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Checkbox", 640, 420))
    app.run {
        let agreed = rememberState<Bool>("agreed") {false}
        let consent = Checkbox("同意服务条款", agreed)
        // 运行时：点击复选框或聚焦后按空格，标签旁的选中状态随绑定值更新。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(label: String, checked: Bindable<Bool>)`](#init) | 由标签与布尔绑定构造勾选框。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`key(value: String)`](#key) | 设置显式的焦点与按下状态标识并返回自身，便于链式声明。 |
| [`measure(ctx: UiContext, available: Size)`](#measure) | 宽为标签文本宽加 34 逻辑像素（勾选框与间距），高度为 `max(38, 有效文字行高 + 12)`，宽不超过可用宽。 |
| [`layout(_: UiContext, rect: Rect)`](#layout) | 记录分配到的框架。 |
| [`draw(ctx: UiContext)`](#draw) | 画勾选框、按弹簧动画缩放的强调色填充与标签文本；键盘聚焦时画焦点环。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 框内按下并抬起翻转绑定值；聚焦时 Enter/Space 同效。 |
| [`focusableId()`](#focusableid) | 返回本控件的焦点 id。 |

## 构造函数

### init

由标签与布尔绑定构造勾选框。

```cangjie
public init(label: String, checked: Bindable<Bool>)
```

**参数**

- `label`: `String` — 勾选框右侧的说明文本，同时是默认控件标识的来源。
- `checked`: `Bindable<Bool>` — 双向绑定的勾选状态；控件翻转它，外部赋值即刻反映到界面。

## 方法

### key

设置显式的焦点与按下状态标识并返回自身，便于链式声明。默认标识每次构建自动派生；显式 key 让状态跨结构变化保持稳定。

```cangjie
public func key(value: String): Checkbox
```

**参数**

- `value`: `String` — 稳定的控件标识，须非空。

**返回值** `Checkbox` — 本实例，支持 `Checkbox(...).key("...")` 链式写法。

**异常**

- `IllegalArgumentException` — `value` 为空串时。

### measure

宽为标签文本宽加 34 逻辑像素（勾选框与间距），高度为 `max(38, 有效文字行高 + 12)`，宽不超过可用宽。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮测量使用的 UI 上下文。
- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 组件请求的尺寸；方法接收 `available` 时，该尺寸在父级给出的可用约束内计算。

### layout

记录分配到的框架。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

画勾选框、按弹簧动画缩放的强调色填充与标签文本；键盘聚焦时画焦点环。填充随勾选状态从中心放大或收缩，边框颜色同步向强调色过渡。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

框内按下并抬起翻转绑定值；聚焦时 Enter/Space 同效。按下即取得焦点与按压所有权，抬起点在框外则放弃本次翻转。

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

## 另请参阅

- [Switch](Switch.md) — 同为布尔绑定的开关样式。
- [Chip](Chip.md) — 胶囊外形的布尔过滤标签。
- [RadioButton](RadioButton.md) — 多选一的单选按钮。
