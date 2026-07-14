/*
 * 画廊数据与视图。卡片是强类型的 `GalleryItem`，网格用 `LazyGrid(id, data, columns, itemHeight){ item => ... }`
 * 一行构建器搭出——数据保持类型化，行按视口窗口化，卡片可为任意控件（这里是色块＋标题＋副标题的面板）。
 */
package cui_gallery

import cui.{Color, FontSizes, LazyGrid, Label, LengthUnits, Panel, Spacer, VStack}

// 一张作品卡片的类型化数据。
struct GalleryItem {
    let title: String
    let subtitle: String
    let color: Color

    init(title: String, subtitle: String, color: Color) {
        this.title = title
        this.subtitle = subtitle
        this.color = color
    }
}

func seedGallery(): Array<GalleryItem> {
    let palette = [
        Color.rgb(99, 102, 241),
        Color.rgb(236, 72, 153),
        Color.rgb(34, 197, 94),
        Color.rgb(249, 115, 22),
        Color.rgb(14, 165, 233),
        Color.rgb(168, 85, 247)
    ]
    let categories = ["视觉", "动效", "排版", "插画", "摄影", "三维"]
    Array<GalleryItem>(60) {
        i => GalleryItem("作品 ${i + 1}", "分类 · ${categories[i % categories.size]}", palette[i % palette.size])
    }
}

func galleryView(items: Array<GalleryItem>): Unit {
    VStack {
        VStack {
            Label("作品画廊").fontSize(FontSizes.TITLE)
            Label("LazyGrid 虚拟化网格：${items.size} 张卡片，仅渲染视口附近的行").muted().fontSize(FontSizes.CAPTION)
        }.spacing(3.vp).hug()
        Panel {
            LazyGrid("gallery.grid", items, 4, 180.0, spacing: 14.0, columnSpacing: 14.0) {
                item => galleryCard(item)
            }
        }.contentPadding(14.vp).flex()
    }.spacing(14.vp).padding(18.vp)
}

private func galleryCard(item: GalleryItem): Unit {
    Panel {
        VStack {
            Spacer().height(84.vp).fillWidth().background(item.color, 10.0)
            Label(item.title).fontSize(FontSizes.CONTROL)
            Label(item.subtitle).muted().fontSize(FontSizes.CAPTION)
        }.spacing(8.vp).hug()
    }.contentPadding(12.vp)
}
