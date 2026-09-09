<!-- kind: tutorial; audience: component-author; prerequisites: resources-media -->

# 构建可验证的媒体预览面板

## 你将完成

你会让程序自己生成一张 BMP、在窗口中按指定盒子显示，并在程序结束后清理临时文件。练习约需 20 分钟，不依赖外部图片，适合用 `--snapshot` 做稳定回归。

## 开始之前

先完成[第一个窗口](../getting-started/first-window.md)，并读[资源与媒体](../concepts/resources-and-media.md)。准备好 SDL 运行库和一个允许写入的工作目录。你不需要自备图片，也不需要联网；完整程序会自己生成测试输入。

## 工作方式

这条媒体链分成三个阶段：`Surface` 在窗口启动前生成文件，`ImageView` 在构建时声明如何显示路径，`finally` 在事件循环结束后删除临时文件。一次性 I/O 不进入构建闭包，跨帧纹理由 CUI 缓存复用，临时文件仍由创建它的程序负责清理。

## 操作步骤

### 第一步：生成确定的输入

从网络或用户目录读取图片会把网络、权限和文件变化带进测试。这里用 `Surface.create` 生成 160×90 图像：蓝色底、左侧黄色条。输入固定，快照出现差异时才更可能是布局或渲染变化。

### 第二步：为图像指定盒子和适配方式

`ImageFit.Cover` 会填满 240×150 盒，必要时裁切边缘；`Contain` 会完整显示图像，必要时留空。用通用 `.width(240.vp).height(150.vp)` 约束盒子尺寸。`ImageView.size` 和 `preferredWidth/preferredHeight` 只设置测量偏好，父容器仍可能拉伸它们，不能据此保证固定盒子。

### 第三步：运行完整程序

先在普通模式启动并关闭一次，确认工作目录可写；再运行快照模式。两种启动都必须经过 `finally`，否则测试通过后会在项目根残留输入文件。

## 完整程序

```cangjie verify role=complete profile=gui-visual
package docexample

import cui.*

let PREVIEW_PATH = "target/guide-media/cui-guide-preview.bmp"

func writePreview(): Unit {
    try (surface = Surface.create(160, 90)) {
        surface.clear(Color.rgb(52, 120, 246))
        var y: Int32 = 0
        while (y < 90) {
            var x: Int32 = 0
            while (x < 48) {
                surface.writePixel(x, y, Color.rgb(246, 179, 52))
                x += 1
            }
            y += 1
        }
        surface.saveBmp(PREVIEW_PATH)
    }
}

main(): Unit {
    FileSystem.createDirectory("target/guide-media")
    if (FileSystem.exists(PREVIEW_PATH)) {
        throw IllegalStateException("预览文件已存在，请先确认并移走该文件：${PREVIEW_PATH}")
    }
    try {
        writePreview()
        let app = DesktopApp(WindowSpec("媒体预览", 460, 330))
        app.run {
            VStack(spacing: 12.vp) {
                Label("构建产物").bold()
                ImageView(PREVIEW_PATH, fit: ImageFit.Cover).width(240.vp).height(150.vp)
                HStack(spacing: 8.vp) {
                    Badge("BMP", kind: BadgeKind.Info)
                    Label("160×90 → 240×150 Cover").muted()
                }.height(34.vp)
            }.padding(24.vp)
        }
    } finally {
        if (FileSystem.exists(PREVIEW_PATH)) {
            FileSystem.remove(PREVIEW_PATH)
        }
    }
}
```

## 可以继续修改

### 第四步：比较 Cover 与 Contain

在一个 `HStack` 中并排声明两个 ImageView，用 `.width(180.vp).height(180.vp)` 为它们约束相同盒子，一个使用 `ImageFit.Cover`，另一个使用 `ImageFit.Contain`。左图会填满正方形并裁掉宽边，右图完整显示宽图并在上下留空。保持相同盒子，才能只比较适配方式。如果列表中反复显示同一路径，CUI 的纹理缓存会复用解码结果；不要在每次构建时生成不同文件名来绕过缓存。

## 确认结果

执行 `cjpm run --run-args="--snapshot media.bmp"`。进程应自动退出并产生非空的 `media.bmp`；快照中能看见标题、蓝黄预览和状态摘要。退出后 `target/guide-media/cui-guide-preview.bmp` 应已删除，目录保留。若同名输入文件已存在，程序会在生成和清理前报错，避免覆盖已有内容。普通交互运行时关闭窗口，也应走同一清理路径。

普通运行时还要拖动窗口边缘，确认图片盒保持 240×150，外层卡片仍有合理间距。快照模式只覆盖初始画面；Cover/Contain 的裁切差异最好人工查看一次，并在后续稳定环境里保存基准图。

## 如果没有成功

- 在构建函数中每帧写图：磁盘和解码工作会不断重复。
- 只给高度、不限定宽度：卡片宽度随父布局变化，快照难以比较。
- 把 `close()` 当成清空全局缓存：它只退役该视图，纹理仍归缓存管理。
- 忘记 `finally`：异常或窗口启动失败后会残留临时文件。

图片空白时，先在窗口启动前打印 `FileSystem.exists(PREVIEW_PATH)`，再用独立查看器打开生成文件；不要先改布局。无法写文件时换到可写工作目录。退出后文件仍存在时，确认窗口运行和生成调用都位于同一个 `try/finally` 中。更多分支见[媒体性能排障](../troubleshooting/media-performance.md)。

## 相关 API

[ImageView](../../api/cui/media/ImageView.md) 声明图片视图，[ImageFit](../../api/cui/media/ImageFit.md) 决定裁切或留白，[媒体函数](../../api/cui/media/functions.md) 管理缓存。`Surface`、`Color` 和 `FileSystem` 由 `cui.*` 入口重导出供完整示例使用。

## 下一步

需要直接绘图时继续[自绘控件](../how-to/custom-canvas.md)，需要控制运动时读[动画与帧预算](../concepts/animation-and-frame-budget.md)。发布前再用[快照与性能记录](../how-to/snapshot-and-profile.md)区分视觉、交互和帧耗时证据。
