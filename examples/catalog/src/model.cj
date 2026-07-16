/*
 * 目录状态：当前分类、当前页，以及过滤 / 分页的纯函数派生。
 *
 * 过滤结果与分页切片都是当前状态的纯函数（每帧现算，无需缓存）。切换分类会改变总页数，因此用
 * `State.observe` 在分类变化时把页码归零——这正是分页与过滤共存时必须处理的经典问题。
 */
package cui_catalog

import std.collection.ArrayList
import cui.{State, StateObservation}

// 每页商品数（2 列 × 4 行）。
let PAGE_SIZE: Int64 = 8

class CatalogModel {
    let all: Array<Product> = buildCatalog()
    let category = State<Int64>(0)
    let page = State<Int64>(0)
    // 随模型整个生命周期持有，保证归零观察器持续生效。
    private let categoryObservation: StateObservation<Int64>

    init() {
        let cursor = this.page
        // 切换分类时回到第一页——分类过滤会改变总页数，必须重置分页游标。仅在值真正变化时重置：
        // State 对等值赋值同样通知（如重复点击当前分段、焦点态在边界按方向键），不加守卫会平白跳回首页。
        this.categoryObservation = this.category.observe({prev, cur => if (prev != cur) {
            cursor.value = 0
        }})
    }

    // 当前分类下的商品（分类 0 表示全部）。
    func filtered(): Array<Product> {
        catalogFiltered(all, category.value)
    }
}

// 按分类过滤：category 0 返回全部，否则匹配 CATEGORIES 下标 category - 1。
func catalogFiltered(all: Array<Product>, category: Int64): Array<Product> {
    if (category <= 0) {
        return all
    }
    let cat = category - 1
    let result = ArrayList<Product>()
    for (p in all) {
        if (p.category == cat) {
            result.add(p)
        }
    }
    result.toArray()
}

// 向上取整的总页数；空目录也保留一页（空页），避免出现 0 页。
func catalogPageCount(itemCount: Int64, pageSize: Int64): Int64 {
    if (itemCount <= 0) {
        return 1
    }
    (itemCount + pageSize - 1) / pageSize
}

// 第 page 页（0 基）的商品切片；越界页返回空切片。
func catalogPageSlice(items: Array<Product>, page: Int64, pageSize: Int64): Array<Product> {
    let start = max(0, page) * pageSize
    if (start >= items.size) {
        return []
    }
    let end = min(items.size, start + pageSize)
    let result = ArrayList<Product>()
    var i = start
    while (i < end) {
        result.add(items[i])
        i += 1
    }
    result.toArray()
}

// 把页码夹到 [0, pageCount - 1]。
func catalogClampPage(page: Int64, pageCount: Int64): Int64 {
    if (page < 0) {
        0
    } else if (page >= pageCount) {
        pageCount - 1
    } else {
        page
    }
}

// 显示区间的 1 基起点（无结果时为 0）。
func catalogRangeStart(total: Int64, page: Int64, pageSize: Int64): Int64 {
    if (total <= 0) {
        0
    } else {
        page * pageSize + 1
    }
}

// 显示区间的 1 基终点，末页封顶到总数。
func catalogRangeEnd(total: Int64, page: Int64, pageSize: Int64): Int64 {
    min(total, (page + 1) * pageSize)
}
