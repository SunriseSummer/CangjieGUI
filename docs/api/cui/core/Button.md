[cui](../../index.md) › [cui.core](index.md) › Button

# Button

位于 `cui.core` 包的公开类

带按主题显示的背景与边框与居中标题的按压按钮，在按钮内部按下并松开时触发 `onClick`。可聚焦：获得键盘焦点后 Enter 与空格同样触发；[`ButtonRole`](ButtonRole.md) 选择语义配色，`style` 完全覆盖表面。

## 声明

```cangjie
public class Button <: Widget
```

## 继承

Button <: [`Widget`](Widget.md)

## 说明

点击识别是"按下-释放"式的：主键在按钮内按下时获得焦点与按压，在按钮内松开才算一次点击，拖出按钮后松开则取消。焦点与按下状态标识默认按构建位置自动生成、每次构建唯一；需要在树形变化中保持标识时用 [`key`](#key) 固定。Normal 角色的表面随按下/悬停切换主题填充色（重叠布局中只有位于最上层的控件高亮）；焦点环只在焦点经键盘到达时绘制（`:focus-visible` 约定），指针点击不会留下键盘样式的描边。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Button", 640, 420))
    app.run {
        let saved = rememberState<Int64>("saved") {0}
        VStack(spacing: 12.vp) {
            Button("保存", {=> saved.value = saved.value + 1}, role: ButtonRole.Primary)
            Label("已保存 ${saved.value} 次").muted()
        }.padding(24.0)
        // 运行时：点击主按钮或聚焦后按 Enter/空格，计数标签随状态更新。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 创建按钮：标题、点击回调，以及可选的角色、表面与字号。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`key(value: String)`](#key) | 设置显式的焦点与按下状态标识。 |
| [`role(value: ButtonRole)`](#role) | 应用语义按钮配色。 |
| [`style(value: SurfaceStyle)`](#style) | 覆盖主题推导的按钮表面。 |
| [`fontSize(value: Length)`](#fontsize) | 设置标题字号。 |
| [`fontSize(value: Float32)`](#fontsize) | 设置标题字号。 |
| [`measure(...)`](#measure) | 按标题文本宽度加内边距测量：宽度下限 72、不超过可用宽度，高度为固定控件高 38 逻辑像素。 |
| [`layout(...)`](#layout) | 记录分配的帧矩形，供绘制与命中测试使用。 |
| [`draw(...)`](#draw) | 绘制主题表面与居中标题，按下/悬停时切换填充色，键盘聚焦时叠加焦点环。 |
| [`handle(...)`](#handle) | 实现按下-释放点击识别与键盘激活，并接收悬停。 |
| [`focusableId()`](#focusableid) | 返回本按钮注册的焦点标识，使其进入 Tab 遍历。 |

## 构造函数

### init

创建按钮：标题、点击回调，以及可选的角色、表面与字号。构造时注册焦点项，并把自身注册进包围它的界面构建函数。

```cangjie
public init(
    title: String,
    onClick: () -> Unit,
    role!: ButtonRole = ButtonRole.Normal,
    style!: ?SurfaceStyle = None,
    fontSize!: Length = Length(FontSizes.CONTROL, LengthUnit.Fp)
)
```

**参数**

- `title`: `String` — 居中绘制的按钮标题，也参与默认标识的生成。
- `onClick`: `() -> Unit` — 点击回调：按钮内松开主键，或聚焦状态下按 Enter/空格时调用。
- `role!`: [`ButtonRole`](ButtonRole.md) — 语义配色：`Primary` 强调、`Danger` 危险动作；默认 `ButtonRole.Normal`，使用常规表面并叠加按下/悬停反馈。
- `style!`: `?SurfaceStyle` — 完全覆盖主题推导的表面（含按下/悬停反馈）；默认 `None`，按 `role` 从主题取表面。
- `fontSize!`: [`Length`](Length.md) — 标题字号；默认 `Length(FontSizes.CONTROL, LengthUnit.Fp)`（15 fp，随用户字体缩放）。

## 方法

### key

设置显式的焦点与按下状态标识。默认标识已按构建位置唯一，只在标识必须跨树形变化存活（例如在容器间移动的按钮）时才需要设置；旧标识在本帧焦点序里被原位替换。返回 `this` 便于链式调用。

```cangjie
public func key(value: String): Button
```

**参数**

- `value`: `String` — 新标识，须非空。

**返回值** `Button` — `this`。

**异常**

- `IllegalArgumentException` — `value` 为空字符串时。

### role

应用语义按钮配色。返回 `this` 便于链式调用。

```cangjie
public func role(value: ButtonRole): Button
```

**参数**

- `value`: `ButtonRole` — 语义角色；非 `Normal` 的角色使用主题的强调文字色绘制标题。

**返回值** `Button` — `this`。

### style

覆盖主题推导的按钮表面。设置后按下/悬停不再切换填充色。返回 `this` 便于链式调用。

```cangjie
public func style(value: SurfaceStyle): Button
```

**参数**

- `value`: `SurfaceStyle` — 完整的表面样式（填充、描边、圆角）。

**返回值** `Button` — `this`。

### fontSize

设置标题字号。`Float32` 重载按字体像素（fp）解释，随用户字体缩放。返回 `this` 便于链式调用。

```cangjie
public func fontSize(value: Length): Button
```

```cangjie
public func fontSize(value: Float32): Button
```

**参数**

- `value`: [`Length`](Length.md) 或 `Float32` — 标题字号；`Length` 形式可写 `15.fp`，`Float32` 形式等价于 `Length(value, LengthUnit.Fp)`。

**返回值** `Button` — `this`。

### measure

按标题文本宽度加内边距测量：宽度下限 72、不超过可用宽度，高度为固定控件高 38 逻辑像素。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 本轮测量使用的 UI 上下文。
- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 按钮的首选尺寸，逻辑像素。

### layout

记录分配的帧矩形，供绘制与命中测试使用。

```cangjie
public func layout(_: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

绘制主题表面与居中标题，按下/悬停时切换填充色，键盘聚焦时叠加焦点环。非 `Normal` 角色的标题使用主题的强调文字色。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

实现按下-释放点击识别与键盘激活，并接收悬停。按钮内按下获得焦点与按压并消费事件；随后在按钮内松开触发 `onClick`（按钮外松开只结束按压）；聚焦状态下 Enter 或空格直接触发；悬停时请求交互光标（[`CursorShape`](CursorShape.md)）。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 事件被本按钮消费时为 `true`。

### focusableId

返回本按钮注册的焦点标识，使其进入 Tab 遍历。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 恒为 `Some(当前标识)`。

## 另请参阅

- [IconButton](IconButton.md) — 以图标为面的按钮，激活方式相同。
- [ButtonRole](ButtonRole.md) — 语义配色角色。
- [Theme](Theme.md) — 按角色推导按钮表面的主题。
