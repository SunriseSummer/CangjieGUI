/*
 * CUI 示例：商品目录分页浏览。
 *
 * 演示 `Pagination` 分页导航：140 件商品按每页 8 件分页，底栏页导航显示首末页、当前页附近的页码与省略号，
 * 上一页/下一页在两端自动禁用。配合 `SegmentedControl` 分类过滤——切换分类改变总页数并回到第一页，
 * 展示分页与过滤共存时的正确处理。
 */
package cui_catalog

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = CatalogModel()
    let app = DesktopApp(WindowSpec("CUI 商品目录", 720, 800, scale: 1.2), theme: catalogTheme())
    app.setMinimumSize(560, 600)
    app.run {
        catalogView(model)
    }
    return 0
}
