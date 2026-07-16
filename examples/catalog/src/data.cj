/*
 * 商品目录示例的类型化数据（纯函数、确定性）。
 *
 * 目录由 词 × 系列 无重复组合而成，价格与评分用与下标相关的简单算式派生——确定性便于示例运行与快照复现。
 */
package cui_catalog

import std.collection.ArrayList

// 商品分类名（下标即 Product.category）。
let CATEGORIES: Array<String> = ["电子", "家居", "服饰", "图书", "运动"]

// 过滤条选项：全部 + 各分类。下标 0 表示“全部”，其余为 CATEGORIES 下标 + 1。
let CATEGORY_FILTERS: Array<String> = ["全部", "电子", "家居", "服饰", "图书", "运动"]

// 一件商品的类型化数据。
struct Product {
    let name: String
    let category: Int64
    let price: Int64
    let rating: Int64 // 十分之一制：47 表示 4.7 分

    init(name: String, category: Int64, price: Int64, rating: Int64) {
        this.name = name
        this.category = category
        this.price = price
        this.rating = rating
    }
}

private let PRODUCT_WORDS: Array<Array<String>> = [
    ["无线耳机", "机械键盘", "蓝牙音箱", "智能手表", "移动电源", "USB 集线器", "网络摄像头", "桌面显示器"],
    ["陶瓷花瓶", "香薰蜡烛", "布艺收纳箱", "羊毛毯", "北欧落地灯", "亚麻抱枕", "陶瓷餐具组", "静音挂钟"],
    ["纯棉 T 恤", "水洗牛仔外套", "羊绒围巾", "透气运动袜", "帆布板鞋", "粗针织帽", "头层牛皮腰带", "法兰绒衬衫"],
    ["科幻小说", "历史随笔集", "家常菜谱", "儿童绘本", "编程进阶指南", "现代诗选", "旅行手记", "长篇漫画集"],
    ["防滑瑜伽垫", "可调哑铃", "竞速跳绳", "碳纤登山杖", "保温运动水壶", "加压护腕", "高清泳镜", "智能健身环"]
]

private let SERIES: Array<String> = ["", " Pro", " Lite", " Max"]

// 生成一份确定性的商品目录：140 项，5 个分类各 28 项，名称在分类内不重复。
func buildCatalog(): Array<Product> {
    let result = ArrayList<Product>()
    for (i in 0..140) {
        let cat = i % 5
        let k = i / 5 // 0..27，(k % 8, k / 8) 唯一决定 (词, 系列)
        let name = "${PRODUCT_WORDS[cat][k % 8]}${SERIES[k / 8]}"
        let price = 29 + (i * 37) % 471 // 29..499 元
        let rating = 35 + (i * 13) % 16 // 3.5..5.0 分
        result.add(Product(name, cat, price, rating))
    }
    result.toArray()
}

// 评分显示文案，如 47 → “评分 4.7”。
func ratingText(rating: Int64): String {
    "评分 ${rating / 10}.${rating % 10}"
}
