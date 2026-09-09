[cui](../../index.md) › [cui.media](index.md) › ImageFit

# ImageFit

位于 `cui.media` 包的公开枚举

图像像素装进分配框的方式，供 [`ImageView`](ImageView.md) 使用：拉伸填满、等比包含或等比覆盖。

## 声明

```cangjie
public enum ImageFit
```

## 示例

```cangjie verify
package docexample

import cui.*

let IMAGE_PATH = "cui-doc-landscape.bmp"

func writeSampleImage(): Unit {
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
        surface.saveBmp(IMAGE_PATH)
    }
}

main(): Unit {
    try {
        writeSampleImage()
        let app = DesktopApp(WindowSpec("ImageFit", 760, 260))
        app.run {
            HStack(spacing: 12.vp) {
                VStack(spacing: 6.vp) {
                    Label("Contain")
                    ImageView(IMAGE_PATH, fit: ImageFit.Contain).width(220.0).height(150.0)
                }
                VStack(spacing: 6.vp) {
                    Label("Cover")
                    ImageView(IMAGE_PATH, fit: ImageFit.Cover).width(220.0).height(150.0)
                }
                VStack(spacing: 6.vp) {
                    Label("Stretch")
                    ImageView(IMAGE_PATH, fit: ImageFit.Stretch).width(220.0).height(150.0)
                }
            }.padding(24.0)
            // 运行时：程序生成的横向双色图会展示 Contain、Cover 与 Stretch 的缩放差异。
        }
    } finally {
        if (FileSystem.exists(IMAGE_PATH)) {
            FileSystem.remove(IMAGE_PATH)
        }
    }
}
```

## 成员概览

**枚举值**

| 成员 | 说明 |
|---|---|
| `Stretch` | 拉伸到正好填满框（不保纵横比）。 |
| `Contain` | 等比缩放到完整装进框内并居中（可能留边）。 |
| `Cover` | 等比缩放到盖满整个框并居中（超出部分裁掉）。 |

## 另请参阅

- [`ImageView`](ImageView.md) — 消费本枚举的图像组件。

### Original

保持解码像素大小，超出部分按 imageAlignment 裁剪，不放大或缩小。

### ScaleDown

在 Original 与 Contain 中选择不放大的显示尺寸，适合小图标和低分辨率素材。
