[cui](../../index.md) › [cui.core](index.md) › Theme

# Theme

位于 `cui.core` 包的公开结构体

组件共用的外观设置：按用途提供背景、面板、输入框、文字、强调色和危险色，并保存统一的圆角与描边宽度（逻辑像素）。组件按用途取色，而不是各自写死颜色；替换上下文中的 `Theme` 就能让整棵界面一起换肤。[`light`](#light) 与 [`dark`](#dark) 是内置浅色和深色主题。本类型不可变；要修改某一项，需要构造一个新值。

## 声明

```cangjie
public struct Theme
```

## 说明

表面构建方法（[`panelSurface`](#panelsurface)、[`fieldSurface`](#fieldsurface)、[`buttonSurface`](#buttonsurface) 等）从角色色派生完整的 `SurfaceStyle`，控件因此共享同一外观。构造函数的每个参数都是命名参数——调色板是一打同类型的颜色，命名构造才能让每行主题定义可读且不会错位。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let theme = Theme.dark()
    println(Int64(theme.radius)) // 面板级圆角
    let primary = theme.buttonSurface(ButtonRole.Primary) // 主按钮表面取 accent
    println(primary.fill.r == theme.accent.r)
    // 输出: 14
    // true
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 以命名参数构造完整调色板；浮起、软强调、阴影与几何各项可选。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`static light()`](#light) | 返回内置浅色主题。 |
| [`static dark()`](#dark) | 返回内置深色主题。 |
| [`panelSurface()`](#panelsurface) | 返回标准面板表面：`panel` 填充、`panelEdge` 描边、`radius` 圆角与柔和阴影。 |
| [`raisedSurface()`](#raisedsurface) | 返回浮起表面：`panelRaised` 填充，阴影偏移比面板更深一档。 |
| [`fieldSurface(active: Bool)`](#fieldsurface) | 返回输入域表面；激活时改用 `fieldActive` 填充、`accent` 描边并加淡淡的强调辉光。 |
| [`buttonSurface(role: ButtonRole)`](#buttonsurface) | 按按钮角色返回表面：`Primary` 用 `accent`，`Danger` 用 `danger`，`Normal` 用 `panelRaised`。 |
| [`selectedSurface()`](#selectedsurface) | 返回选中态表面：`accent` 填充与描边、控件圆角、无阴影。 |

**字段**

| 成员 | 说明 |
|---|---|
| [`bg`](#bg) | 窗口底色，整棵树最底层的背景。 |
| [`panel`](#panel) | 面板与卡片底色。 |
| [`panelEdge`](#paneledge) | 面板与控件的描边色。 |
| [`text`](#text) | 主文字颜色。 |
| [`mutedText`](#mutedtext) | 次要文字颜色。 |
| [`accent`](#accent) | 强调色：主按钮、选中态与键盘焦点环。 |
| [`accentText`](#accenttext) | 落在强调色表面上的文字颜色。 |
| [`danger`](#danger) | 危险与破坏性操作色。 |
| [`field`](#field) | 输入域底色。 |
| [`fieldActive`](#fieldactive) | 激活（聚焦）输入域的底色。 |
| [`panelRaised`](#panelraised) | 浮起表面（按钮、弹层）的底色。 |
| [`accentSoft`](#accentsoft) | 强调色的浅色变体，软底与选中背景。 |
| [`shadow`](#shadow) | 阴影颜色，透明度含在其中。 |
| [`radius`](#radius) | 面板级圆角半径，逻辑像素。 |
| [`smallRadius`](#smallradius) | 小元素圆角半径，逻辑像素。 |
| [`controlRadius`](#controlradius) | 控件圆角半径，逻辑像素。 |
| [`borderWidth`](#borderwidth) | 描边宽度，逻辑像素。 |

## 构造函数

### init

以命名参数构造完整调色板；浮起、软强调、阴影与几何各项可选。前十个颜色角色必填。

```cangjie
public init(
    bg!: Color,
    panel!: Color,
    panelEdge!: Color,
    text!: Color,
    mutedText!: Color,
    accent!: Color,
    accentText!: Color,
    danger!: Color,
    field!: Color,
    fieldActive!: Color,
    panelRaised!: Color = Color.rgb(255, 255, 255),
    accentSoft!: Color = Color.rgb(224, 240, 255),
    shadow!: Color = Color.rgba(16, 24, 40, 34),
    radius!: Float32 = 12.0,
    smallRadius!: Float32 = 7.0,
    controlRadius!: Float32 = 9.0,
    borderWidth!: Float32 = 1.0
)
```

**参数**

- `bg!`: `Color` — 窗口底色。
- `panel!`: `Color` — 面板与卡片底色。
- `panelEdge!`: `Color` — 描边色。
- `text!`: `Color` — 主文字色。
- `mutedText!`: `Color` — 次要文字色。
- `accent!`: `Color` — 强调色。
- `accentText!`: `Color` — 强调色表面上的文字色。
- `danger!`: `Color` — 危险操作色。
- `field!`: `Color` — 输入域底色。
- `fieldActive!`: `Color` — 激活输入域底色。
- `panelRaised!`: `Color` — 浮起表面底色；默认 `Color.rgb(255, 255, 255)`。
- `accentSoft!`: `Color` — 强调浅色变体；默认 `Color.rgb(224, 240, 255)`。
- `shadow!`: `Color` — 阴影色；默认 `Color.rgba(16, 24, 40, 34)`。
- `radius!`: `Float32` — 面板圆角，逻辑像素；默认 `12.0`。
- `smallRadius!`: `Float32` — 小元素圆角；默认 `7.0`。
- `controlRadius!`: `Float32` — 控件圆角；默认 `9.0`。
- `borderWidth!`: `Float32` — 描边宽度；默认 `1.0`。

## 方法

### light

返回内置浅色主题。冷灰底、白面板、蓝强调，圆角 14 / 8 / 10 逻辑像素。

```cangjie
public static func light(): Theme
```

**返回值** `Theme` — 浅色调色板。

### dark

返回内置深色主题。深蓝灰底、亮蓝强调，圆角与浅色主题一致。

```cangjie
public static func dark(): Theme
```

**返回值** `Theme` — 深色调色板。

### panelSurface

返回标准面板表面：`panel` 填充、`panelEdge` 描边、`radius` 圆角与柔和阴影。

```cangjie
public func panelSurface(): SurfaceStyle
```

**返回值** `SurfaceStyle` — 面板外观（阴影垂直偏移 2）。

### raisedSurface

返回浮起表面：`panelRaised` 填充，阴影偏移比面板更深一档。

```cangjie
public func raisedSurface(): SurfaceStyle
```

**返回值** `SurfaceStyle` — 浮起外观（阴影垂直偏移 3）。

### fieldSurface

返回输入域表面；激活时改用 `fieldActive` 填充、`accent` 描边并加淡淡的强调辉光。未激活时为 `field` 填充、`panelEdge` 描边、无阴影。

```cangjie
public func fieldSurface(active: Bool): SurfaceStyle
```

**参数**

- `active`: `Bool` — 输入域是否处于激活（聚焦）状态。

**返回值** `SurfaceStyle` — 输入域外观，圆角取 `controlRadius`。

### buttonSurface

按按钮角色返回表面：`Primary` 用 `accent`，`Danger` 用 `danger`，`Normal` 用 `panelRaised`。三种角色都取 `controlRadius` 圆角，投影浓淡随角色区分。

```cangjie
public func buttonSurface(role: ButtonRole): SurfaceStyle
```

**参数**

- `role`: [`ButtonRole`](ButtonRole.md) — 按钮的语义角色。

**返回值** `SurfaceStyle` — 对应角色的按钮外观。

### selectedSurface

返回选中态表面：`accent` 填充与描边、控件圆角、无阴影。列表行、分段控件等选中高亮共用它。

```cangjie
public func selectedSurface(): SurfaceStyle
```

**返回值** `SurfaceStyle` — 选中态外观。

## 字段

### bg

窗口底色，整棵树最底层的背景。

```cangjie
public let bg: Color
```

### panel

面板与卡片底色。

```cangjie
public let panel: Color
```

### panelEdge

面板与控件的描边色。

```cangjie
public let panelEdge: Color
```

### text

主文字颜色。

```cangjie
public let text: Color
```

### mutedText

次要文字颜色。说明文字、占位符与辅助信息用它与主文字拉开层级。

```cangjie
public let mutedText: Color
```

### accent

强调色：主按钮、选中态与键盘焦点环。

```cangjie
public let accent: Color
```

### accentText

落在强调色表面上的文字颜色。

```cangjie
public let accentText: Color
```

### danger

危险与破坏性操作色。

```cangjie
public let danger: Color
```

### field

输入域底色。

```cangjie
public let field: Color
```

### fieldActive

激活（聚焦）输入域的底色。

```cangjie
public let fieldActive: Color
```

### panelRaised

浮起表面（按钮、弹层）的底色。

```cangjie
public let panelRaised: Color
```

### accentSoft

强调色的浅色变体，软底与选中背景。

```cangjie
public let accentSoft: Color
```

### shadow

阴影颜色，透明度含在其中。

```cangjie
public let shadow: Color
```

### radius

面板级圆角半径，逻辑像素。

```cangjie
public let radius: Float32
```

### smallRadius

小元素圆角半径，逻辑像素。

```cangjie
public let smallRadius: Float32
```

### controlRadius

控件圆角半径，逻辑像素。按钮、输入域与选中态表面取它。

```cangjie
public let controlRadius: Float32
```

### borderWidth

描边宽度，逻辑像素。

```cangjie
public let borderWidth: Float32
```

## 另请参阅

- [UiContext](UiContext.md) — 主题的运行期挂载点（`ctx.theme`）。
- [Spacing](Spacing.md) / [Radii](Radii.md) / [Motion](Motion.md) — 同属设计令牌的间距、圆角与动效尺度。
