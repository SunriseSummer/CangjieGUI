[cui](../../index.md) › [cui.core](index.md) › IconButton

# IconButton

位于 `cui.core` 包的公开类

以图标为面、可选带文字标签的按钮，激活方式与 [`Button`](Button.md) 完全相同。按钮内松开主键或聚焦时按 Enter/空格触发 `onClick`；`role` 与 `style` 以同样的方式为表面着色。

## 声明

```cangjie
public class IconButton <: Widget
```

## 继承

IconButton <: [`Widget`](Widget.md)

## 说明

同一视图里的多个纯图标按钮靠"按构建位置生成的默认标识"保持互不混淆——若共用标识，一个按钮会拦截本属于另一个的松开事件；标识必须跨树形变化存活时用 [`key`](#key) 固定。无标签时按钮是 38×38 逻辑像素的方形；[`label`](#label) 会在图标右侧加一行文字并按文字宽度扩展。焦点环只在焦点经键盘到达时绘制，与 Button 同一约定。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("IconButton", 640, 420))
    app.run {
        let removed = rememberState<Int64>("removed") {0}
        VStack(spacing: 10.vp) {
            Label("已删除 ${removed.value} 项")
            IconButton(IconName.Trash, role: ButtonRole.Danger) {
                => removed.value = removed.value + 1
            }
        }.padding(24.0)
        // 运行时：点击危险角色的删除图标按钮，计数标签随之更新。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 创建图标按钮：图标名、点击回调，以及可选的文字标签、角色与表面。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`key(value: String)`](#key) | 设置显式的焦点与按下状态标识。 |
| [`label(value: String)`](#label) | 在图标右侧加一行文字标签。 |
| [`role(value: ButtonRole)`](#role) | 应用语义按钮配色。 |
| [`style(value: SurfaceStyle)`](#style) | 覆盖主题推导的按钮表面。 |
| [`measure(...)`](#measure) | 无标签时测量为 38×38 逻辑像素的方形；有标签时按文字宽度加图标与内边距扩展，宽度下限 76。 |
| [`layout(...)`](#layout) | 记录分配的帧矩形，供绘制与命中测试使用。 |
| [`draw(...)`](#draw) | 绘制表面、图标与可选标签，按下/悬停时切换填充色，键盘聚焦时叠加焦点环。 |
| [`handle(...)`](#handle) | 实现与 Button 相同的按下-释放点击识别与键盘激活，并接收悬停。 |
| [`focusableId()`](#focusableid) | 返回本按钮注册的焦点标识，使其进入 Tab 遍历。 |

## 构造函数

### init

创建图标按钮：图标名、点击回调，以及可选的文字标签、角色与表面。构造时注册焦点项，并把自身注册进包围它的界面构建函数。

```cangjie
public init(
    icon: IconName,
    label!: ?String = None,
    role!: ButtonRole = ButtonRole.Normal,
    style!: ?SurfaceStyle = None,
    onClick!: () -> Unit
)
```

**参数**

- `icon`: `IconName` — 按钮面上的矢量图标。
- `label!`: `?String` — 图标右侧的文字标签；默认 `None`，按钮为纯图标方形。
- `role!`: [`ButtonRole`](ButtonRole.md) — 语义配色；默认 `ButtonRole.Normal`。
- `style!`: `?SurfaceStyle` — 完全覆盖主题推导的表面；默认 `None`，按 `role` 从主题取表面。
- `onClick!`: `() -> Unit` — 点击回调；命名参数在末位，可写成尾随 lambda。

## 方法

### key

设置显式的焦点与按下状态标识。默认标识已按构建位置唯一，只在标识必须跨树形变化存活时才需要设置。返回 `this` 便于链式调用。

```cangjie
public func key(value: String): IconButton
```

**参数**

- `value`: `String` — 新标识，须非空。

**返回值** `IconButton` — `this`。

**异常**

- `IllegalArgumentException` — `value` 为空字符串时。

### label

在图标右侧加一行文字标签。返回 `this` 便于链式调用。

```cangjie
public func label(value: String): IconButton
```

**参数**

- `value`: `String` — 标签文字，以控件字号绘制。

**返回值** `IconButton` — `this`。

### role

应用语义按钮配色。非 `Normal` 角色的图标与标签使用主题的强调文字色。返回 `this` 便于链式调用。

```cangjie
public func role(value: ButtonRole): IconButton
```

**参数**

- `value`: `ButtonRole` — 语义角色。

**返回值** `IconButton` — `this`。

### style

覆盖主题推导的按钮表面。设置后按下/悬停不再切换填充色。返回 `this` 便于链式调用。

```cangjie
public func style(value: SurfaceStyle): IconButton
```

**参数**

- `value`: `SurfaceStyle` — 完整的表面样式。

**返回值** `IconButton` — `this`。

### measure

无标签时测量为 38×38 逻辑像素的方形；有标签时按文字宽度加图标与内边距扩展，宽度下限 76。文字按绘制所用的同一字号测量，两端不会漂移。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 本轮测量使用的 UI 上下文。
- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 按钮的首选尺寸，宽度不超过可用宽度。

### layout

记录分配的帧矩形，供绘制与命中测试使用。

```cangjie
public func layout(_: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

绘制表面、图标与可选标签，按下/悬停时切换填充色，键盘聚焦时叠加焦点环。纯图标时图标居中，带标签时图标靠左、文字随后。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

实现与 Button 相同的按下-释放点击识别与键盘激活，并接收悬停。按钮内按下获得焦点与按压；随后在按钮内松开触发 `onClick`；聚焦状态下 Enter 或空格直接触发。

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

- [Button](Button.md) — 文字标题按钮，同一套激活协议。
- [Icon](Icon.md) — 非交互的矢量图标。
- [Tooltip](Tooltip.md) — 给纯图标按钮补充悬停说明的常用包装。
