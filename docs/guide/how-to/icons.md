# 使用图标组件

`Icon`、`IconButton` 位于 `cui.media`，常规应用直接 `import cui.*`。框架负责媒体加载、颜色语义、DPI、布局和交互。图标可以来自应用文件、内存字节或可选的[源码预置图标](preset-icons.md)。预置资源按单图标子包导入，组件本身不按名称查找资源；回退资源仍由应用指定。

## 从文件与内存使用

文件示例需准备 `assets/search.svg`、`assets/brand.png` 和 `assets/save.svg`，或使用图标工坊随附的素材。内存 SVG 可直接运行；缺失文件会显示空白占位。

```cangjie verify
package docexample
import cui.*

main(): Unit {
    let search = IconSource("assets/search.svg")
    let brand = IconSource("assets/brand.png", renderingMode: IconRenderingMode.Original)
    let memory = IconSource.memory(
        "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\"><circle cx=\"8\" cy=\"8\" r=\"6\"/></svg>".toArray())
    let app = DesktopApp(WindowSpec("Application icons", 640, 420))
    app.run {
        HStack {
            Icon(search).iconSize(20.vp)
            Icon(brand).iconSize(32.vp).alt("工作室标记")
            Icon(memory).foregroundColor(Color.rgb(30, 110, 160))
            IconButton(search, onClick: {=> println("search")}).accessibilityLabel("搜索")
            IconButton("assets/save.svg", label: "保存", onClick: {=> println("save")})
        }
    }
}
```

创建文件来源不读取磁盘。相对路径以进程工作目录为准；发布时把应用自己的 assets 一同交付，或使用应用目录解析后的绝对路径。`IconSource.memory` 复制编码数据一次，后续来源副本共享该不可变快照。将其保存在模型或构建函数外，避免每次重建产生新资源身份。可以将已有 `ImageSource` 直接传给 Icon、IconButton，或包装成 IconSource 以配置颜色模式和规格。

## 原色、模板和样式

默认 `Template` 适合操作图标：图片的 Alpha 决定覆盖度，前景色决定 RGB。黑色图案也能被准确着成白色；不要把普通乘法 tint 当作模板转换。模板素材需要透明背景，不透明背景也会被着成实心块。

`Original` 适合彩色品牌和插画，保留 RGB 并忽略 foregroundColor；`iconOpacity` 对两种模式都有效。默认前景色来自主题；IconButton 使用按钮角色的内容色。`IconStyle` 将尺寸、颜色、透明度、采样和镜像集中在一个可复用值中：

```cangjie verify
package docexample
import cui.*

main(): Unit {
    let mark = IconSource("assets/pixel.png", renderingMode: IconRenderingMode.Original)
    let pixelStyle = IconStyle(size: 48.vp, opacity: 0.8,
        sampling: TextureScaleMode.Nearest, flip: TextureFlip.Horizontal)
    let app = DesktopApp(WindowSpec("Icon styling", 640, 420))
    app.run {
        HStack {
            Icon(mark, style: pixelStyle)
            IconButton(mark, label: "工作室", iconStyle: pixelStyle, onClick: {=> ()})
                .iconGap(12.vp)
        }
    }
}
```

Icon 的自然占位为正方形，默认 18 vp，居中等比容纳图片。约束小于首选大小时缩小占位，不溢出父框；零尺寸不解码。非方形源保留比例；需要 Cover、任意宽高、圆角图片等照片布局时使用 ImageView。背景、边框和圆角属于容器或按钮表面，不改变图标内容色的语义。

IconButton 默认最小自然点击区域为 38 vp，图标变大时自然尺寸随之增长。父布局仍可缩小该区域，因此应用应主动保证目标平台所需的可点击尺寸。`iconSize(18.vp)` 控制图形大小，不能替代点击区域设计。文字随字体度量参与测量，受约束时裁剪到按钮内部。

## 清晰度与规格

| 场景 | 推荐资源 | 实践 |
|---|---|---|
| 16 vp 紧凑工具栏 | 16 单位光学校正 SVG | 简化细节、适当加粗、留出透明边距 |
| 20／24 vp 常规动作 | 24 单位 SVG | 统一笔画、端点和视觉重心 |
| 32／48／64 vp 展示 | SVG 或充足分辨率 PNG | 保持轮廓，不盲目堆细节 |
| 彩色品牌 | SVG 或 1×／2×／3×／4× PNG | Original；透明背景，规格共用构图 |
| 像素画 | 原始小位图 | Nearest，优先整数倍显示 |

SVG 按渲染器**实际逻辑到栅格比例**生成缓存尺寸，包含超采样；不会再次重复乘 displayScale。规格选择依据同一目标栅格尺寸，取最小足够项，否则取最大项。超采样可能使 24 vp 图标选中大于常规 2× 的资源。

```cangjie verify
package docexample
import cui.*

main(): Unit {
    let brand = IconSource.variants([
        IconVariant("assets/brand-24.png", 24),
        IconVariant("assets/brand-48.png", 48),
        IconVariant("assets/brand-72.png", 72),
        IconVariant("assets/brand-96.png", 96)
    ], renderingMode: IconRenderingMode.Original)
    let app = DesktopApp(WindowSpec("Density variants", 640, 420))
    app.run { Icon(brand).iconSize(24.vp) }
}
```

规格表里的 pixels 表示正方形位图文件的实际画布边长。传入空表、重复边长或非正边长会抛 IllegalArgumentException。规格数组被复制，后续修改原数组不改变来源。光学校正稿按**逻辑用途**选择，不应与 DPI 位图规格混为一谈。ICO 可以作为静态图像加载，但当前不保证按请求尺寸选择其内嵌子图；需要可预测选择时用显式规格表。

最大规格应覆盖应用实际使用的最大逻辑尺寸与栅格倍率；例如 48 vp 在 4× 栅格上需要 192 px，图标工坊因此额外提供 144／192 px。Nearest 只控制纹理采样，窗口超采样后的整体缩小仍可能柔化像素画边缘；严格像素呈现应使用物理像素整数倍，并令 WindowSpec 的 supersample 为 1。

SVG 支持范围由 SDL3_image 决定，不是浏览器完整 SVG；建议导出自包含路径、显式颜色和 viewBox，避免依赖外部字体、CSS currentColor 或外部文件。PNG 通常是复杂图案的稳妥交付格式。图标继承现有静态格式支持，不引入动画，也不要求可选 WebP／TIFF／AVIF DLL。

## 缓存、故障与预热

图标和 ImageView 共用线程／渲染器隔离的有界缓存（默认 256 项、估算 128 MiB）。原色图标在来源与解码策略一致时可共享图像纹理；模板另缓存白色 RGB／原 Alpha 表面生成的纹理。前景色、透明度、镜像不会复制纹理或进入缓存键。

图标目标栅格边长限制为 2048，解码像素预算为 4,194,304。普通位图先解码再缩小，所以该预算不限制解码器的瞬时分配；不要把超大照片当图标。构造和测量不加载，首次绘制可能同步解码。可以在所属 UI 线程用 `preloadIcon(renderer, source, pixels: 48)` 提前预热明确规格；pixels 须在 1..2048。避免在 draw 中每帧预热。

缺失／损坏资源按失败缓存，默认保持空白占位，可用 `.fallback(applicationSource)` 提供单层回退。`status()`、`loadError()` 反映主来源，不会因回退成功而掩盖故障；查询自身不触发 I/O。稳定视图保留失败结果，即便全局负缓存已被容量淘汰也不每帧重试。覆盖文件后，在所属 UI 线程调用 `invalidateIcon(source)`，即可失效全部规格及两种颜色模式，并唤醒保留绘制。`invalidateImage(source.image)` 刷新对应单一来源；多规格请使用 invalidateIcon。

`Icon.close()` 只退休当前组件，纹理由缓存管理。组件关闭后仍可安全查询状态；不要关闭从缓存共享的底层纹理。缓存切换渲染器时会重新上传，图标来源本身不持有 GPU 对象。

## 控件、自绘与无障碍

TreeNode 的 `icon` 和 `RichSpan.icon` 都接受 IconSource，可以共享同一份应用资源及颜色意图。行内图标保留原有行高和基线协议。自绘 Widget 使用 `paintIcon(ctx, source, bounds, color, style: ...)`，不要在 draw 中构造 Icon；该入口按 bounds 绘制，忽略 style.size，调用方负责裁剪和语义。

独立且有信息含义的 Icon 设置 `.alt("...")`；装饰性图标保持默认无语义。IconButton 中的图标不产生重复的图像节点；纯图标按钮提供 `.accessibilityLabel("...")`，可见 label 是默认操作名。工具提示可作为补充，但不能代替可访问名称。禁用状态使用统一 `.enabled(false)`，会移出 Tab 环并拒绝无障碍激活。

## 从旧接口迁移

这是有意的公开 API 调整：删除 CangjieSDL 的 IconName／drawIcon；Icon 和 IconButton 从 cui.core 移至 cui.media。`import cui.*` 继续使用同名组件，直接导入旧包时需更换包名。应用将旧的枚举值改成自己的路径、ImageSource 或 IconSource。IconButton 的 label 现在直接使用 String，省去 Some 包装；图形尺寸和颜色改用 IconStyle 或相应链式方法。

包依赖发生变化，首次迁移后在应用目录执行 `cjpm clean`，再执行 `cjpm build`／`cjpm test`。旧 `.dep-cache` 可能保留 controls 不依赖 media 的关系，导致不可访问符号或漏链；清理的是应用构建产物，不是媒体文件。

`DatePicker`、`TimePicker` 使用日历、时钟预置资源，因此导入 `cui.controls` 会间接带入这两枚图标；完整依赖边界见[预置图标](preset-icons.md)。应用文件素材仍需随程序交付。

## 后续实践

运行[图标工坊](../../../examples/icons/README.md)，对比文件、内存和多规格资源；再用[预置图标](preset-icons.md)替换一个操作按钮的来源。
