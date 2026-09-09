# ImageView

`cui.media` 的静态图像组件。可直接通过 `import cui.*` 使用。

```cangjie
public class ImageView <: Widget & Resource
```

支持 BMP、PNG、JPEG、GIF 静态图、SVG 子集、ICO、CUR、QOI、TGA、PNM、PCX、XPM 等 SDL_image 可用格式；以发行库实际启用的解码器为准。当前交付不要求 WebP、TIFF、AVIF、JPEG XL 的可选解码库，不播放动画。

默认高度 96 vp，宽度占满可用空间，`Contain` 保持比例；旧构造参数保持兼容。推荐 `.size(240.vp, 150.vp)` 设置组件尺寸，`.decodeSize(480, 300)` 独立控制缓存像素。后者对 SVG 按尺寸栅格化，对位图在完整解码后缩小，不能限制解码器临时内存。SVG 如用于高 DPI，按实际像素密度选择解码尺寸；尺寸变化后应重建组件或更新 decodeSize。

来源与解码参数组成缓存键。样式、位置、对齐与裁剪不复制纹理；内存来源在创建时复制字节，应在构建函数外保留复用。无特效的图像沿用普通纹理绘制；定制样式进入不可变渲染命令。样式独立采用标准 Alpha 混合，颜色/透明度不会污染共享纹理，混合和采样方式均会恢复。

缓存按 UI 线程及渲染器隔离，默认 256 项、估算 128 MiB。单个超预算项可独占缓存，避免连续解码。失败同样缓存，可通过 `loadError()` 读取错误；覆盖文件后调用 `invalidateImage(path)`，或对内存来源调用同名重载。UI 线程内的刷新同时触发保留绘制失效，包括此前画空白或已被容量淘汰的失败条目。跨线程应通过 `DesktopApp.post` 把刷新交给所属 UI 线程。

首次加载同步发生在绘制时；`intrinsicSize()` 显式允许在测量阶段加载，默认测量不访问磁盘。`preloadImage` 可在显示前预热。`close()` 仅停止这个视图绘制，共享纹理由缓存释放。

## 示例

```cangjie verify
package docexample
import cui.*
main(): Unit {
    let app = DesktopApp(WindowSpec("图像", 500, 360))
    app.run {
        ImageView("assets/cover.jpg")
            .size(320.vp, 200.vp)
            .fit(ImageFit.Cover)
            .imageAlignment(Alignment.Top)
            .decodeSize(640, 400)
            .cornerRadius(16.vp)
            .imageBorder(Color.rgb(220, 224, 228))
            .alt("封面照片")
            .padding(24.vp)
    }
}
```

组件专用链式接口应放在返回通用 `Widget` 的 `.padding`、`.width` 等修饰符之前。`sourceRect` 使用解码后的像素坐标；`Original` 把一个解码像素视为一个逻辑单位。圆角作用于实际图片矩形；背景和边框作用于整个布局框。`imageOpacity` 只影响图像，装饰单独着色。

`errorPlaceholder` 在失败且备用图也不可用时绘制，回调仅用于绘制，不应修改状态；异常会向上传播且裁剪栈仍会恢复。未设置占位或备用图时画空白。`alt` 默认为空（装饰图），非空时创建 Image 语义节点。

## 接口

### init

从文件创建图像视图，可通过命名参数设置首选尺寸。

```cangjie
public init(path: String, fit!: ImageFit = ImageFit.Contain, preferredWidth!: ?Length = None,
        preferredHeight!: Length = Length(96.0, LengthUnit.Vp))
```

### init

从可复用来源创建图像视图，尺寸规则与文件构造相同。

```cangjie
public init(source: ImageSource, fit!: ImageFit = ImageFit.Contain, preferredWidth!: ?Length = None,
        preferredHeight!: Length = Length(96.0, LengthUnit.Vp))
```

### fit

设置图像在布局框内的适配方式。

```cangjie
public func fit(value: ImageFit): ImageView
```

### size

设置测量阶段的首选宽高；长度非有限或为负时抛出 `IllegalArgumentException`。父容器仍可拉伸图片，需要固定布局框时在图片专用接口之后追加通用 `.width(...).height(...)` 修饰器。

```cangjie
public func size(width: Length, height: Length): ImageView
```

### imageAlignment

设置裁剪时保留的区域，或较小图像在布局框中的位置。

```cangjie
public func imageAlignment(value: Alignment): ImageView
```

### aspectRatio

按宽高比预留空间，测量时不解码；比值非有限或非正时抛出 `IllegalArgumentException`。

```cangjie
public func aspectRatio(value: Float32): ImageView
```

### intrinsicSize

允许测量时加载，按解码像素尺寸报告自然大小，必要时等比缩小到可用空间。

```cangjie
public func intrinsicSize(): ImageView
```

### decodeSize

设置独立于布局的解码像素边界。SVG 按边界栅格化，位图完整解码后缩小；零表示该轴不约束。非法尺寸抛出 `IllegalArgumentException`。

```cangjie
public func decodeSize(width: Int32, height: Int32): ImageView
```

### decodeSize

限制解码宽度，保留原图比例。

```cangjie
public func decodeSize(width: Int32): ImageView
```

### decodeOptions

设置含像素预算的完整解码策略，不改变布局尺寸。

```cangjie
public func decodeOptions(value: ImageLoadOptions): ImageView
```

### sourceRect

按解码像素选择源区域，并与图像范围求交；非法坐标抛出 `IllegalArgumentException`。

```cangjie
public func sourceRect(value: Rect): ImageView
```

### tint

乘算图像 RGB 与 Alpha，不影响共享同一纹理的其他视图。

```cangjie
public func tint(value: Color): ImageView
```

### imageOpacity

设置 0..1 内的图像透明度；非法值抛出 `IllegalArgumentException`。背景与边框独立着色。

```cangjie
public func imageOpacity(value: Float32): ImageView
```

### cornerRadius

设置图像的抗锯齿圆角；半径非有限或为负时抛出 `IllegalArgumentException`。

```cangjie
public func cornerRadius(value: Length): ImageView
```

### sampling

选择线性平滑采样或适合像素画的最近邻采样。

```cangjie
public func sampling(value: TextureScaleMode): ImageView
```

### flip

镜像图像，不改变外围布局。

```cangjie
public func flip(value: TextureFlip): ImageView
```

### imageBackground

绘制布局框背景，包含图像透明区域和 Contain 留白。

```cangjie
public func imageBackground(value: Color): ImageView
```

### imageBorder

在布局框内部绘制边框；宽度非有限或为负时抛出 `IllegalArgumentException`。

```cangjie
public func imageBorder(color: Color, width!: Float32 = 1.0): ImageView
```

### fallback

主来源失败时绘制备用来源；状态与诊断仍描述主来源。

```cangjie
public func fallback(value: ImageSource): ImageView
```

### errorPlaceholder

录制布局框内的失败占位绘制；回调只绘制，不修改应用状态。

```cangjie
public func errorPlaceholder(paint: (UiContext, Rect, String) -> Unit): ImageView
```

### alt

设置图像的无障碍描述；空字符串表示装饰性图像。

```cangjie
public func alt(value: String): ImageView
```

### status

查询主图最近的解析状态，不执行 I/O。

```cangjie
public func status(): ImageStatus
```

### loadError

查询缓存诊断；加载前或失效后返回 `None`，不触发加载。

```cangjie
public func loadError(): ?String
```

### measure



```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

### layout



```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

### draw



```cangjie
public func draw(ctx: UiContext): Unit
```

### handle



```cangjie
public func handle(_: UiContext, _: UiEvent): Bool
```

### isClosed

查询当前视图是否已停用。

```cangjie
public func isClosed(): Bool
```

### close

停止绘制当前视图；共享纹理仍由有界缓存管理。

```cangjie
public func close(): Unit
```

参见 [ImageSource](ImageSource.md)、[ImageFit](ImageFit.md)、[ImageStatus](ImageStatus.md)、[缓存与预热](functions.md)。

存活的 ImageView 会保留已解析的失败诊断，即使全局缓存随后淘汰该失败条目也不反复访问文件。调用 invalidateImage、clearImageCache 或更新 decodeOptions/decodeSize 后，下一次需要图片时重新解析。

错误占位回调先录制为绘制命令，完整结束后再回放。回调抛异常或留下未配对的裁剪时，不改变调用者的裁剪栈。回调可发出绘制命令，但不应开始/结束场景、抓取画面、修改纹理状态或修改应用状态。
