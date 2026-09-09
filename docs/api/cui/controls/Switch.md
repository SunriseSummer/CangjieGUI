[cui](../../index.md) › [cui.controls](index.md) › Switch

# Switch

位于 `cui.controls` 包的公开类

绑定布尔状态的桌面开关：滑轨带圆钮，点击（或聚焦后 Enter/Space）取反 `checked`，圆钮以弹簧动画滑向新位置。适合即时生效的开/关设置；需要“勾选”语义时用 [`Checkbox`](Checkbox.md)。

## 声明

```cangjie
public class Switch <: Widget
```

## 继承

`Switch <: Widget` — 实现 [`Widget`](../core/Widget.md) 组件协议。

## 说明

圆钮位置与轨道颜色共用同一只 [`Spring`](../core/Spring.md)（0 为关、1 为开），两者同步平滑过渡。弹簧跨构建保留，并以当前状态起步，静态首帧即已稳定、无入场动画。

指针交互采用按下-释放语义：按下获得焦点与按压，释放仍落在控件内才真正取反——把指针拖出控件再松开即取消这次操作。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Switch", 640, 420))
    app.run {
        let compact = rememberState("compact") {false}
        let toggle = Switch("紧凑模式", compact)
        // 运行时：点击开关或聚焦后按空格，轨道与绑定布尔值同步切换。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(label: String, checked: Bindable<Bool>)`](#init) | 以标签与布尔绑定构造开关。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`key(value: String)`](#key) | 设置显式焦点与按下状态标识；默认标识按构建顺序唯一。 |
| [`measure(ctx: UiContext, available: Size)`](#measure) | 返回 40 逻辑像素轨道加 12 间距加标签宽的宽度（封顶于可用宽度），高度为 `max(38, 有效文字行高 + 12)`。 |
| [`layout(_: UiContext, rect: Rect)`](#layout) | 记录控件框架。 |
| [`draw(ctx: UiContext)`](#draw) | 按弹簧进度绘制轨道渐变色与滑动圆钮，随后是标签与键盘焦点环。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 按下并在控件内松开时取反 `checked`；聚焦后 Enter/Space 同效。 |
| [`focusableId()`](#focusableid) | 返回开关的焦点标识。 |

## 构造函数

### init

以标签与布尔绑定构造开关。

```cangjie
public init(label: String, checked: Bindable<Bool>)
```

**参数**

- `label`: `String` — 画在轨道右侧的说明文字。
- `checked`: [`Bindable`](../core/Bindable.md)`<Bool>` — 开关状态的双向绑定，激活即取反。

## 方法

### key

设置显式焦点与按下状态标识；默认标识按构建顺序唯一。当标识必须跨树形变化存活（控件在容器间移动）时才需要显式指定。

```cangjie
public func key(value: String): Switch
```

**参数**

- `value`: `String` — 新的控件标识，须非空。

**返回值** `Switch` — 返回自身以便链式调用。

**异常**

- `IllegalArgumentException` — `value` 为空字符串时。

### measure

返回 40 逻辑像素轨道加 12 间距加标签宽的宽度（封顶于可用宽度），高度为 `max(38, 有效文字行高 + 12)`。[`Widget`](../core/Widget.md) 协议方法。

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

按弹簧进度绘制轨道渐变色与滑动圆钮，随后是标签与键盘焦点环。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

按下并在控件内松开时取反 `checked`；聚焦后 Enter/Space 同效。按下即获得焦点与按压，释放在控件外则取消。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 是否已消费该事件；`true` 表示调用方不应再继续分发。

### focusableId

返回开关的焦点标识。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 该控件用于参与键盘焦点导航的标识。

## 另请参阅

- [Checkbox](Checkbox.md) — 勾选语义的布尔输入。
- [Chip](Chip.md) — 可选中的标签胶囊，同样绑定布尔状态。
