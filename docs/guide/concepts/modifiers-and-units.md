[CUI 指南](../index.md) › 修饰器与单位

# 尺寸单位与修饰器顺序

## 先用一句话说明

每个修饰器都会包住前一步结果，因此交换顺序可能改变控件占用空间、背景范围和事件区域。

先读[布局约束、滚动与虚拟化](layout-and-scrolling.md)：父容器给出可用空间，子控件在约束内报告尺寸。修饰器不是最后统一应用的一袋属性；`.padding()`、`.width()`、`.background()` 等调用按书写顺序形成包装层。

## 为什么重要

桌面界面最常见的“明明写了宽度却不生效”“背景没有包住内边距”“按钮放大后焦点环仍很小”，往往不是容器错误，而是修饰器顺序表达了另一层关系。只背每个方法的定义不能预测组合结果，读者需要把链看成从左到右逐层包裹的树。

单位也承担不同职责。`vp` 随显示缩放，适合间距、控件尺寸和圆角；`fp` 还考虑用户字体缩放，适合与字号相关的长度；`px` 表示物理像素，适合必须贴合设备像素的细节。单位不能代替响应式布局：五块业务内容放不下一行时，应重排或滚动，而不是把所有值换成更小的 px。

缩放不是应用需要手工协调的缓存事件。宿主更新 `displayScale`/`fontScale` 后，框架会推进帧稳定的 UI 环境
generation；相同约束下的 Element、Stack 和文本布局都会自动重测，Element-owned 布局/语义提交与 paint
commands 再按 Measure→Layout→Paint 失效。
因此不要为了 DPI 或无障碍字号变化修改业务 key、清空 State，或给每个 `RetainedSubtree` 人工维护 revision。

## 工作模型

读一条链时先圈出原始控件，再向外读每个包装层：

1. `Label("状态")` 先测量文字；
2. `.padding(12.vp)` 让包装层在文字四周增加空间；
3. `.background(color)` 绘制当前包装层的整个框；
4. `.maxWidth(240.vp)` 再限制外层能获得的宽度。

若把 background 放在 padding 前面，背景层只围住文字，padding 成为背景之外的透明空间。这两种都可能正确：卡片通常希望背景包含内边距；文字高亮可能只希望底色贴着文字。

`width`/`height` 请求精确尺寸，但仍受父级可用空间限制；`min`/`max` 表达边界；`fillWidth` 接受父级提供的整行；`.flex()` 让栈把剩余空间按权重分给该项。固定值解决局部几何，flex 解决兄弟间剩余空间分配，两者不应互相冒充。

## 复用修饰器管线

当多个组件需要同一组包装层时，可把它们组合成一个 [`Modifier`](../../api/cui/core/Modifier.md)，再通过 `.modifier(...)` 应用。`then` 严格按源码顺序组合，所以它与直接链式调用具有同一套布局、绘制和事件语义：

```cangjie
let cardStyle = Modifier.padding(16.vp)
    .then(Modifier.background(Color.rgb(235, 241, 255), 10.vp))
    .then(Modifier.fillWidth())

let title = Label("构建状态").modifier(cardStyle)
let summary = Label("全部检查通过").modifier(cardStyle)
```

从代数上看，`Modifier()` 是恒等变换，`then` 满足结合律；因此设计系统可以安全地从小令牌逐层组合样式包，无须额外组件生命周期。结合律只允许改变括号，不允许交换顺序：`a.then(b).then(c)` 与 `a.then(b.then(c))` 等价，但 `a.then(b)` 通常不等于 `b.then(a)`。`Modifier.custom` 可接入应用自定义的 `Widget -> Widget` 变换。

如果修饰器来自运行时数组，不要手写一个从空 `Modifier()` 开始的超长左折叠；使用 `Modifier.concat(parts)`。它与
[Compose 官方 `Modifier` 契约](https://developer.android.com/reference/kotlin/androidx/compose/ui/Modifier)
一样保持“前项先应用、顺序有意义”的契约，但会对宽数组做内部平衡重括号。空/单项和 ≤8 项走最小路径；这不是
让普通三五步链改写成数组，也不是无序样式表。

自定义 Canvas、辉光或滤镜若绘制到 layout 矩形之外，用 `.paintOutset(24.0)` 或非对称
`PaintOutset(left: ..., right: ...)` 声明。它不改变布局，只扩大允许绘制、damage 和 ScenePatch 相交的保守域；
滚动方向仍由 viewport 精确裁剪。普通 shadow modifier 会自动推导，无需重复声明。多个声明逐边取最大值，
满足结合、交换和幂等，不会因 wrapper 分组不同而漏掉 halo。

## 选择与取舍

- 界面结构先用栈、网格、分栏和滚动表达，再添加局部尺寸。
- 常规间距用 `Spacing` 或 vp；字体附近的垂直节奏可用 fp；一像素描边才考虑 px。
- 背景、边框、阴影的半径要一致，否则边缘会显得错位。
- `visible(false)` 会让节点不占布局；`enabled(false)` 保留布局但阻止输入并显示禁用层。二者表达不同产品含义。
- 先在最小、常用、较大窗口检查，再决定是否需要 min/max；不要只看设计稿尺寸。

## 应用这个模型

这两个卡片代码只有顺序不同。第一种背景包住内边距；第二种内边距在背景之外：

```cangjie role=contrast
let cardA = Label("背景包含留白")
    .padding(16.vp)
    .background(Color.rgb(235, 241, 255), radius: 10.vp)

let cardB = Label("背景贴近文字")
    .background(Color.rgb(235, 241, 255), radius: 10.vp)
    .padding(16.vp)
```

下面从外向内追踪一个工作区：窗口把剩余宽度交给 `.flex()` 的编辑区，编辑区把文字限制在 720 vp，Panel 再提供内容内边距。调整窗口时，工具栏保持内容宽度，编辑区吸收变化：

```cangjie role=trace
HStack(spacing: 12.vp) {
    VStack { Label("工具"); Button("保存", {=> save()}) }
        .width(180.vp)
    Panel {
        TextArea(draft).maxWidth(720.vp).fillWidth()
    }.contentPadding(16.vp).flex()
}
```

`save` 和 `draft` 来自应用模型；该片段只追踪约束。不要把 `.width(180.vp)` 加到整个根 HStack，那会把工作区也锁死。

## 常见误解

- **“链式修饰器与 CSS 属性一样无序。”** 这里每一步产生包装层，顺序是公开可见语义。
- **“vp 会自动让所有布局响应式。”** 它解决缩放，不决定内容如何换行、分栏或滚动。
- **“fillWidth 和 flex 完全相同。”** fill 使用父级给出的宽度，flex 参与栈的剩余空间分配。
- **“enabled(false) 应移除控件。”** 禁用保留位置和可见反馈；移除或隐藏是另一项决定。
- **“固定尺寸越多越稳定。”** 固定尺寸会把偶然窗口变成隐含前提，应优先表达关系和边界。
- **“复用 Modifier 会把链变成无序样式表。”** 它复用的是有序包装管线；`then` 不交换任何步骤。

## 相关 API

- [`Widget`](../../api/cui/core/Widget.md) — 通用尺寸、内边距、表面和状态修饰器。
- [`Modifier`](../../api/cui/core/Modifier.md) — 可复用、有序、满足恒等与结合律的组件变换。
- [`Length`](../../api/cui/core/Length.md) 与 [`LengthUnit`](../../api/cui/core/LengthUnit.md) — px/vp/fp 的精确契约。
- [`Flexible`](../../api/cui/core/Flexible.md) — 栈中的剩余空间分配。

## 下一步

在[选择布局容器](../how-to/choose-layout.md)中把内容关系与约束结合；在[应用主题](../how-to/theme-an-app.md)中统一背景、边框、圆角和间距令牌。
