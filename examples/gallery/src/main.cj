/*
 * CUI 示例：作品画廊。
 *
 * 用一面卡片墙演示 `LazyGrid`——数据驱动、按行虚拟化的等宽网格：几十张卡片只渲染视口附近的行，
 * 一行是一个 `Grid`，骑在纵向 `LazyColumn` 上，无需单独的横向滚动。构建方式即数据加一个单元格构建器。
 */
package cui_gallery

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let items = seedGallery()
    let app = DesktopApp(WindowSpec("CUI 作品画廊", 820, 640, scale: 1.5))
    app.setMinimumSize(560, 480)
    app.run {
        galleryView(items)
    }
    return 0
}
