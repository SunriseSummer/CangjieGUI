[CUI 指南](../index.md) › 修饰器与单位

# 尺寸单位与修饰器顺序

## 核心结论

每个修饰器都会包住前一步得到的组件，所以顺序会改变尺寸、背景范围、绘制层次和事件区域。长度单位解决缩放问题，不会自动解决内容如何排列。

## 从内向外读修饰器

以 `Label("状态").padding(12.vp).background(color).maxWidth(240.vp)` 为例：

1. Label 先测量文字。
2. padding 在文字四周增加空间。
3. background 绘制包含内边距的整个区域。
4. maxWidth 限制最外层最大宽度。

如果把 background 放在 padding 前面，背景只包住文字，padding 会成为背景外的透明空间。这两种顺序都合法，但表达的视觉关系不同。

## 完整示例

```cangjie verify role=complete profile=gui-visual
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("修饰器顺序", 520, 280))
    app.run {
        let cardStyle = Modifier.padding(16.vp)
            .then(Modifier.background(Color.rgb(235, 241, 255), 10.vp))
            .then(Modifier.fillWidth())

        VStack(spacing: 16.vp) {
            Label("背景包含内边距")
                .padding(16.vp)
                .background(Color.rgb(235, 241, 255), 10.vp)

            Label("内边距位于背景外")
                .background(Color.rgb(235, 241, 255), 10.vp)
                .padding(16.vp)

            Label("复用 Modifier").modifier(cardStyle)
        }.padding(20.vp)
    }
}
```

`Modifier` 保存的是有序组件变换，不是无序样式表。`then` 按书写顺序应用；`Modifier()` 表示不做任何修改。多个组件需要相同包装层时，可以复用同一个 Modifier。

## 选择长度单位

| 单位 | 含义 | 常见用途 |
|---|---|---|
| `vp` | 随显示缩放变化的虚拟像素 | 控件尺寸、间距、圆角 |
| `fp` | 在显示缩放之外继续考虑用户字体缩放 | 与文字有关的尺寸和间距 |
| `px` | 物理像素 | 必须贴合设备像素的细线或图像细节 |

常规界面优先使用 `vp` 和内建 `Spacing`。字体附近需要跟随无障碍字号时使用 `fp`。不要为了让拥挤界面“勉强放下”而全面改用 `px`；内容放不下时，应调整布局、换行、滚动或信息层级。

显示缩放或字体缩放变化后，CUI 会自动使相关测量、布局和绘制失效。应用无需修改业务键、清空状态或手工刷新每个组件。

## 尺寸修饰器怎样配合

- `width`、`height` 请求精确尺寸，但仍受父级可用空间约束。
- `minWidth`、`maxWidth`、`minHeight`、`maxHeight` 表达尺寸边界。
- `fillWidth`、`fillHeight` 接受父级提供的全部空间。
- `flex` 让组件按权重参与栈的剩余空间分配。

`fillWidth` 和 `flex` 不是同一个概念：前者使用已经提供的宽度，后者决定兄弟组件如何分配剩余空间。

优先用容器表达内容关系，再添加局部边界。大量固定宽高会把某个窗口尺寸变成隐含前提。

## 可见、禁用与绘制外溢

`visible(false)` 会把组件移出布局、绘制和事件处理；`enabled(false)` 保留位置和禁用外观，但阻止交互并移出 Tab 顺序。两者表达不同的产品状态。

阴影、光晕或自定义描边可能画到布局矩形外。内建阴影会自动声明范围；自定义绘制应使用 `.paintOutset(...)` 或覆盖 `paintOutset()`，告诉增量绘制和滚动裁剪可能受影响的最大区域。

范围必须覆盖实际外溢，但不应随意放大。太小会产生裁剪或残影，太大会增加需要重绘的区域。

## 选择顺序

设计一个组件样式时，建议按以下顺序决定：

1. 先选择 VStack、HStack、Grid、FlowRow、SplitView 或滚动容器。
2. 再决定哪个区域应收缩、填满或参与 flex。
3. 使用 min/max 表达可接受边界。
4. 添加 padding、背景、边框和阴影，并从内向外检查顺序。
5. 在小、常用和大窗口以及不同字体缩放下验证。

## 常见错误

- 把链式修饰器当成无序属性集合。
- 认为 `vp` 会自动让布局响应式。
- 混淆 `fillWidth` 和 `flex`。
- 用 `enabled(false)` 代替隐藏组件。
- 用大量固定尺寸弥补错误的容器选择。
- 自定义绘制超出矩形，却没有声明 `paintOutset`。

## 相关 API

- [`Widget`](../../api/cui/core/Widget.md) — 尺寸、表面、可见性和交互修饰器。
- [`Modifier`](../../api/cui/core/Modifier.md) — 可复用的有序修饰器。
- [`Length`](../../api/cui/core/Length.md)、[`LengthUnit`](../../api/cui/core/LengthUnit.md)、[`LengthInsets`](../../api/cui/core/LengthInsets.md)
- [`Flexible`](../../api/cui/core/Flexible.md) — 栈中的剩余空间分配。
- [`PaintOutset`](../../api/cui/core/PaintOutset.md) — 布局矩形外的绘制范围。

## 下一步

在[选择布局容器](../how-to/choose-layout.md)中把内容关系映射到具体容器；在[应用主题](../how-to/theme-an-app.md)中统一颜色、圆角和间距。
