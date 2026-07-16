/*
 * 目录视图层：标题 + 分类过滤条 + 商品网格 + 分页底栏。
 *
 *  - 顶部标题给出总量与“切换分类回到第一页”的提示。
 *  - 分类过滤条用 `SegmentedControl` 绑定 `model.category`；网格用 `Grid(2)` 排布当前页 8 张商品卡片。
 *  - 底栏左侧显示当前区间（第 X–Y 项 / 共 N 项），右侧是 `Pagination` 页导航——两者都由同一份状态派生。
 */
package cui_catalog

import cui.{CrossAxisAlignment, FontSizes, Grid, HStack, Label, LengthUnits, Pagination, Panel, SegmentedControl, Spacer,
    VStack}

func catalogView(model: CatalogModel): Unit {
    let items = model.filtered()
    let total = items.size
    let pageCount = catalogPageCount(total, PAGE_SIZE)
    let page = catalogClampPage(model.page.value, pageCount)
    let pageItems = catalogPageSlice(items, page, PAGE_SIZE)
    VStack {
        catalogHeader(total)
        SegmentedControl(CATEGORY_FILTERS, model.category)
        Panel {
            productGrid(pageItems)
        }.contentPadding(16.vp).flex()
        catalogFooter(model, total, page, pageCount)
    }.spacing(14.vp).padding(18.vp)
}

func catalogHeader(total: Int64): Unit {
    VStack {
        Label("商品目录").fontSize(FontSizes.TITLE)
        Label("分页浏览 ${total} 件商品；切换分类会回到第一页").muted().fontSize(FontSizes.CAPTION)
    }.spacing(3.vp).hug()
}

func productGrid(items: Array<Product>): Unit {
    Grid(2) {
        for (p in items) {
            productCard(p)
        }
    }.spacing(12.vp, 12.vp)
}

private func productCard(p: Product): Unit {
    Panel {
        VStack {
            HStack {
                // 分类色块缩略图：以分类色填充，占约三分之一宽（文字区权重更高），扫一眼即知品类。
                Spacer().height(44.vp).background(categoryColor(p.category), 4.0)
                VStack {
                    Label(p.name).fontSize(FontSizes.CONTROL)
                    Label(CATEGORIES[p.category]).muted().fontSize(FontSizes.CAPTION)
                }.spacing(3.vp).hug().flex(2.0)
            }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
            HStack {
                Label("¥${p.price}").foregroundColor(CATALOG_PRICE).fontSize(FontSizes.BODY)
                Spacer()
                Label(ratingText(p.rating)).muted().fontSize(FontSizes.CAPTION)
            }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
        }.spacing(10.vp)
    }.contentPadding(14.vp)
}

func catalogFooter(model: CatalogModel, total: Int64, page: Int64, pageCount: Int64): Unit {
    HStack {
        Label(rangeLabel(total, page)).muted().fontSize(FontSizes.CAPTION)
        Spacer()
        Pagination(pageCount, model.page)
    }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

func rangeLabel(total: Int64, page: Int64): String {
    if (total <= 0) {
        "暂无商品"
    } else {
        "显示第 ${catalogRangeStart(total, page, PAGE_SIZE)}–${catalogRangeEnd(total, page, PAGE_SIZE)} 项 · 共 ${total} 项"
    }
}
