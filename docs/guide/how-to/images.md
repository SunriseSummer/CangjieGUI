# 静态图像与样式

`ImageView` 使用 SDL3_image 3.4.6 解码静态图片。默认交付覆盖 JPEG、PNG、BMP、GIF 静态图、SVG 子集、QOI、TGA、ICO、PNM、PCX、XPM 等；当前不包含动画，也不要求 WebP、TIFF、AVIF、JPEG XL 的额外解码库。格式是否可用取决于原生库的实际构建。

## 声明、布局与裁剪

先将图片放在应用的 `assets/photo.jpg`；文件路径相对于运行工作目录。无需外部素材的完整解码程序见 [SDL 图像教程](../../../../CangjieSDL/docs/guide/how-to/images-textures-screenshot.md)。

```cangjie verify
package docexample
import cui.*
main(): Unit {
    let app = DesktopApp(WindowSpec("静态图像", 600, 420))
    app.run {
        ImageView("assets/photo.jpg")
            .size(320.vp, 200.vp)
            .fit(ImageFit.Cover)
            .imageAlignment(Alignment.Top)
            .cornerRadius(16.vp)
            .imageBorder(Color.rgb(220, 225, 230))
            .alt("产品照片")
            .width(320.vp).height(200.vp)
            .padding(24.vp)
    }
}
```

图片专用接口放在返回通用 Widget 的 padding、width 等修饰符之前。`size` 设置首选尺寸，不需要 Some；preferredWidth/preferredHeight 构造参数含义相同。首选尺寸参与测量，父容器仍可拉伸图片；需要固定盒子时，像上例一样再使用 `.width(...).height(...)`。默认不读取原图尺寸，测量时请求可用宽度和 96 vp 高度，避免访问磁盘。`aspectRatio(1.5)` 按宽高比预留空间；`intrinsicSize()` 则显式允许在测量中加载，按解码像素尺寸测量。

| ImageFit | 效果 |
|---|---|
| Contain | 完整显示，保留比例，可能留白。 |
| Cover | 填满区域，保留比例，按 imageAlignment 裁剪。 |
| Stretch | 填满区域，允许变形。 |
| Original | 一个解码像素对应一个逻辑单位，溢出裁剪。 |
| ScaleDown | 完整显示，只缩小，不放大。 |

`sourceRect` 用解码后的像素坐标指定局部区域，会与实际图像范围求交。透明度、着色、镜像及采样都是逐次绘制参数，不生成新的纹理副本。圆角通过有界缓存的抗锯齿网格实现，样式采用独立的标准 Alpha 合成并在绘制后恢复原纹理的混合与采样状态；背景和边框可用 imageBackground/imageBorder 独立设置。

## 来源、缓存与失效

`ImageSource(path)` 描述文件；`ImageSource.memory(bytes, typeHint: "PNG")` 创建编码字节快照。内存来源应在界面构建外创建并复用，避免每次重建复制数据、产生新缓存身份。普通文件来源按相同路径共享缓存。

`decodeSize(640, 400)` 控制缓存像素边界，独立于显示尺寸。位图在完整解码并通过像素预算检查后按比例缩小，因此减少驻留纹理内存但不限制解码峰值；SVG 直接按指定像素尺寸栅格化。需要自定义解码像素上限时，使用 `decodeOptions(ImageLoadOptions(width: 640, maxPixels: 16000000))`；与预热使用同一组选项即可命中同一缓存。高 DPI 图标应提供足够像素，例如 40 vp 图标可用 decodeSize(120)。本版 SVG 是 SDL_image 的静态子集，不提供浏览器级 SVG 布局或交互。

缓存按线程和渲染器隔离，具有 256 项和估算 128 MiB 的双预算，并缓存失败以避免逐帧访问坏文件。首次加载是同步操作；preloadImage 可在显示前预热。通过 imageCacheStats 观察命中、失败、淘汰和估算内存。

文件被覆盖后，在所属 UI 线程调用 invalidateImage(path)，这会清除所有尺寸变体并使保留绘制失效，即使此前的失败条目已被容量淘汰；内存来源使用 invalidateImage(source)。后台任务通过 DesktopApp.post 回到 UI 线程刷新，不能跨线程使用或销毁纹理。clearImageCache 清空并重置统计。

存活的 ImageView 会保留已解析的失败诊断，即使全局缓存随后淘汰该失败条目也不反复访问文件。调用 invalidateImage、clearImageCache 或更新 decodeOptions/decodeSize 后，下一次需要图片时重新解析。

## 失败与可访问性

`status()` 和 `loadError()` 不触发 I/O，分别返回主图状态和失败诊断。fallback(ImageSource(...)) 设置备用图片，备用图片成功不会掩盖主图失败状态。errorPlaceholder 接收 UiContext、布局矩形、错误信息，可绘制自定义占位；回调不得改写状态，异常按普通绘制异常传播，裁剪栈仍恢复。

错误占位回调先录制为绘制命令，完整结束后再回放。回调抛异常或留下未配对的裁剪时，不改变调用者的裁剪栈。回调可发出绘制命令，但不应开始/结束场景、抓取画面、修改纹理状态或修改应用状态。

`alt("图片内容说明")` 建立 Image 可访问性语义，默认空文本视为装饰图。不要把文件名或解码错误直接当作面向用户的内容描述。

## 示例

运行 `examples/images` 的“图像工作室”可比较文件/内存来源、格式、五种适配方式、透明度、镜像、圆角、着色、局部取景与错误占位。`examples/calendar` 使用 PNG 保存和简短的尺寸 API。


精确签名见 [ImageView](../../api/cui/media/ImageView.md)。
